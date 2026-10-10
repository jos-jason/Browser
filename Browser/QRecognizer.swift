//
//  QRecognizer.swift
//  Browser
//
//  $Q Super-Quick Recognizer (Vatavu, Anthony & Wobbrock, 2018).
//  A template-matching gesture recognizer: each gesture is a "point cloud"
//  and a drawing is matched to the closest stored template. It is invariant
//  to position, size, stroke direction and start point, needs no training
//  step, and runs in well under a millisecond on a phone.
//

import Foundation
import CoreGraphics

nonisolated struct QPoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ p: CGPoint) {
        self.x = Double(p.x)
        self.y = Double(p.y)
    }
}

nonisolated struct QRecognizer: Sendable {

    // Algorithm constants from the $Q paper
    static let sampleCount = 32
    private static let maxIntCoord = 1024
    private static let lutSize = 64
    private static let lutScale = maxIntCoord / lutSize

    /// Average weighted squared distance above which a drawing is rejected.
    /// Points live roughly in [-1, 1], so 0 is a perfect match.
    var rejectThreshold: Double = 0.03

    /// How much stroke curvature counts versus position ($P+ style).
    /// Lets sharp corners (square, triangle) be told apart from smooth curves (circle).
    static let angleWeight: Double = 1.0

    struct Match: Sendable {
        let id: String
        /// Lower is better. Normalized so it's comparable across gestures.
        let distance: Double
    }

    private struct Cloud: Sendable {
        let id: String
        let points: [QPoint]
        let angles: [Double]
        let intX: [Int]
        let intY: [Int]
        let lut: [[Int]]
    }

    private var templates: [Cloud] = []

    init() {}

    /// Register one sample drawing for the gesture `id`. A gesture can have many samples.
    mutating func addTemplate(id: String, points: [QPoint]) {
        guard let cloud = Self.makeCloud(id: id, points: points) else { return }
        templates.append(cloud)
    }

    var isEmpty: Bool { templates.isEmpty }

    /// Best match for a drawing, or nil if nothing is close enough.
    func recognize(_ points: [QPoint]) -> Match? {
        guard let best = rank(points).first, best.distance <= rejectThreshold else { return nil }
        return best
    }

    /// All gestures ordered from best to worst match (one entry per gesture id).
    func rank(_ points: [QPoint]) -> [Match] {
        guard let candidate = Self.makeCloud(id: "", points: points) else { return [] }
        var bestPerID: [String: Double] = [:]
        for template in templates {
            let soFar = bestPerID[template.id] ?? .infinity
            let d = Self.cloudMatch(candidate, template, minSoFar: soFar)
            if d < soFar { bestPerID[template.id] = d }
        }
        let n = Double(Self.sampleCount)
        let weightSum = n * (n + 1) / 2
        return bestPerID
            .map { Match(id: $0.key, distance: $0.value / weightSum) }
            .sorted { $0.distance < $1.distance }
    }

    // MARK: - Normalization

    /// Returns nil for drawings that are too small to classify (e.g. a tap).
    static func normalize(_ raw: [QPoint]) -> [QPoint]? {
        guard raw.count >= 2, pathLength(raw) > 0 else { return nil }
        var pts = resample(raw, n: sampleCount)

        // Scale uniformly so the larger side spans 0...1 (keeps aspect ratio)
        var minX = Double.infinity, minY = Double.infinity
        var maxX = -Double.infinity, maxY = -Double.infinity
        for p in pts {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let size = max(maxX - minX, maxY - minY)
        guard size > 0 else { return nil }
        pts = pts.map { QPoint(x: ($0.x - minX) / size, y: ($0.y - minY) / size) }

        // Center on the centroid
        let cx = pts.reduce(0) { $0 + $1.x } / Double(pts.count)
        let cy = pts.reduce(0) { $0 + $1.y } / Double(pts.count)
        return pts.map { QPoint(x: $0.x - cx, y: $0.y - cy) }
    }

    private static func makeCloud(id: String, points raw: [QPoint]) -> Cloud? {
        guard let pts = normalize(raw) else { return nil }
        let intX = pts.map { clampInt(Int((($0.x + 1) / 2 * Double(maxIntCoord - 1)).rounded())) }
        let intY = pts.map { clampInt(Int((($0.y + 1) / 2 * Double(maxIntCoord - 1)).rounded())) }

        // Lookup table: for each grid cell, the index of the nearest point
        var lut = Array(repeating: Array(repeating: 0, count: lutSize), count: lutSize)
        for x in 0..<lutSize {
            for y in 0..<lutSize {
                var best = -1
                var bestDist = Int.max
                for i in 0..<pts.count {
                    let row = Int((Double(intX[i]) / Double(lutScale)).rounded())
                    let col = Int((Double(intY[i]) / Double(lutScale)).rounded())
                    let d = (row - x) * (row - x) + (col - y) * (col - y)
                    if d < bestDist {
                        bestDist = d
                        best = i
                    }
                }
                lut[x][y] = best
            }
        }
        return Cloud(id: id, points: pts, angles: turningAngles(pts), intX: intX, intY: intY, lut: lut)
    }

    /// Absolute turning angle at each point, scaled to 0...1 (0 = straight, 1 = full reversal).
    /// Using the absolute value keeps it independent of drawing direction.
    private static func turningAngles(_ pts: [QPoint]) -> [Double] {
        var angles = Array(repeating: 0.0, count: pts.count)
        guard pts.count >= 3 else { return angles }
        for i in 1..<(pts.count - 1) {
            let a = atan2(pts[i].y - pts[i - 1].y, pts[i].x - pts[i - 1].x)
            let b = atan2(pts[i + 1].y - pts[i].y, pts[i + 1].x - pts[i].x)
            var d = abs(b - a)
            if d > .pi { d = 2 * .pi - d }
            angles[i] = d / .pi
        }
        return angles
    }

    private static func clampInt(_ v: Int) -> Int { min(max(v, 0), maxIntCoord - 1) }

    private static func resample(_ points: [QPoint], n: Int) -> [QPoint] {
        let interval = pathLength(points) / Double(n - 1)
        var src = points
        var result = [src[0]]
        var accumulated = 0.0
        var i = 1
        while i < src.count {
            let d = distance(src[i - 1], src[i])
            if accumulated + d >= interval && d > 0 {
                let t = (interval - accumulated) / d
                let q = QPoint(x: src[i - 1].x + t * (src[i].x - src[i - 1].x),
                               y: src[i - 1].y + t * (src[i].y - src[i - 1].y))
                result.append(q)
                src.insert(q, at: i)
                accumulated = 0
            } else {
                accumulated += d
            }
            i += 1
        }
        // Rounding can leave us one short
        while result.count < n { result.append(points[points.count - 1]) }
        return Array(result.prefix(n))
    }

    // MARK: - Matching

    private static func cloudMatch(_ candidate: Cloud, _ template: Cloud, minSoFar: Double) -> Double {
        let n = candidate.points.count
        let step = Int(Double(n).squareRoot())
        var minSoFar = minSoFar

        let lb1 = lowerBound(candidate, template, step: step)
        let lb2 = lowerBound(template, candidate, step: step)

        var j = 0
        for start in stride(from: 0, to: n, by: step) {
            if lb1[j] < minSoFar {
                minSoFar = min(minSoFar, cloudDistance(candidate, template, start: start, minSoFar: minSoFar))
            }
            if lb2[j] < minSoFar {
                minSoFar = min(minSoFar, cloudDistance(template, candidate, start: start, minSoFar: minSoFar))
            }
            j += 1
        }
        return minSoFar
    }

    private static func cloudDistance(_ c1: Cloud, _ c2: Cloud, start: Int, minSoFar: Double) -> Double {
        let pts1 = c1.points, pts2 = c2.points
        let n = pts1.count
        var unmatched = Array(0..<n)
        var i = start
        var weight = Double(n)
        var sum = 0.0
        repeat {
            var bestIndex = 0
            var bestDist = Double.infinity
            for (k, j) in unmatched.enumerated() {
                let da = c1.angles[i] - c2.angles[j]
                let d = sqrDistance(pts1[i], pts2[j]) + angleWeight * da * da
                if d < bestDist {
                    bestDist = d
                    bestIndex = k
                }
            }
            unmatched.remove(at: bestIndex)
            sum += weight * bestDist
            if sum >= minSoFar { return sum }  // early abandoning
            weight -= 1
            i = (i + 1) % n
        } while i != start
        return sum
    }

    private static func lowerBound(_ a: Cloud, _ b: Cloud, step: Int) -> [Double] {
        let n = a.points.count
        var lb = Array(repeating: 0.0, count: n / step + 1)
        var sat = Array(repeating: 0.0, count: n)
        for i in 0..<n {
            let x = min(Int((Double(a.intX[i]) / Double(lutScale)).rounded()), lutSize - 1)
            let y = min(Int((Double(a.intY[i]) / Double(lutScale)).rounded()), lutSize - 1)
            let index = b.lut[x][y]
            let d = sqrDistance(a.points[i], b.points[index])
            sat[i] = i == 0 ? d : sat[i - 1] + d
            lb[0] += Double(n - i) * d
        }
        var j = 1
        for i in stride(from: step, to: n, by: step) {
            lb[j] = lb[0] + Double(i) * sat[n - 1] - Double(n) * sat[i - 1]
            j += 1
        }
        return lb
    }

    // MARK: - Geometry

    private static func pathLength(_ pts: [QPoint]) -> Double {
        var length = 0.0
        for i in 1..<pts.count { length += distance(pts[i - 1], pts[i]) }
        return length
    }

    private static func distance(_ a: QPoint, _ b: QPoint) -> Double {
        sqrDistance(a, b).squareRoot()
    }

    private static func sqrDistance(_ a: QPoint, _ b: QPoint) -> Double {
        let dx = a.x - b.x, dy = a.y - b.y
        return dx * dx + dy * dy
    }
}
