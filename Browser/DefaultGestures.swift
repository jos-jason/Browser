//
//  DefaultGestures.swift
//  Browser
//
//  Built-in gesture templates. Each is one or more example drawings in a
//  unit box (y points down, like the screen). Users can add their own
//  samples on top of these to teach the recognizer their drawing style.
//

import Foundation

nonisolated enum DefaultGestures {

    struct Definition {
        let id: String
        let name: String
        let label: String
        let url: String
        let samples: [[QPoint]]
    }

    static let all: [Definition] = [
        Definition(id: "circle", name: "Circle", label: "Google", url: "https://www.google.com",
                   samples: [ellipse(rx: 0.5, ry: 0.5), ellipse(rx: 0.5, ry: 0.38)]),
        Definition(id: "triangle", name: "Triangle", label: "YouTube", url: "https://www.youtube.com",
                   samples: [polyline([(0.5, 0), (1, 0.87), (0, 0.87), (0.5, 0)]),
                             polyline([(0.5, 0), (1, 0.7), (0, 0.7), (0.5, 0)])]),
        Definition(id: "square", name: "Square", label: "Reddit", url: "https://www.reddit.com",
                   samples: [polyline([(0, 0), (1, 0), (1, 1), (0, 1), (0, 0)]),
                             polyline([(0, 0), (1, 0), (1, 0.75), (0, 0.75), (0, 0)]),
                             polyline([(0.1, 0), (1, 0.1), (0.9, 1), (0, 0.9), (0.1, 0)])]),
        Definition(id: "zigzag", name: "Zigzag", label: "Wikipedia", url: "https://www.wikipedia.org",
                   samples: [polyline([(0.65, 0), (0.2, 0.5), (0.8, 0.5), (0.35, 1)]),
                             polyline([(0, 0), (0.25, 0.6), (0.5, 0), (0.75, 0.6), (1, 0)])]),
        Definition(id: "checkmark", name: "Checkmark", label: "GitHub", url: "https://www.github.com",
                   samples: [polyline([(0, 0.55), (0.35, 0.95), (1, 0)]),
                             polyline([(0, 0.5), (0.3, 1), (0.9, 0)])]),
    ]

    // MARK: - Shape builders

    static func polyline(_ vertices: [(Double, Double)], pointsPerSegment: Int = 16) -> [QPoint] {
        var pts: [QPoint] = []
        for i in 1..<vertices.count {
            let a = vertices[i - 1], b = vertices[i]
            for s in 0..<pointsPerSegment {
                let t = Double(s) / Double(pointsPerSegment)
                pts.append(QPoint(x: a.0 + (b.0 - a.0) * t, y: a.1 + (b.1 - a.1) * t))
            }
        }
        let last = vertices[vertices.count - 1]
        pts.append(QPoint(x: last.0, y: last.1))
        return pts
    }

    static func ellipse(rx: Double, ry: Double, count: Int = 64) -> [QPoint] {
        (0...count).map { i in
            let a = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(count)
            return QPoint(x: 0.5 + rx * cos(a), y: 0.5 + ry * sin(a))
        }
    }
}
