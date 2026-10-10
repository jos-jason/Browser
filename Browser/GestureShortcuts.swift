//
//  GestureShortcuts.swift
//  Browser
//
//  Created by JJ vollum on 10/6/26.
//

import SwiftUI

// MARK: - Gesture Shortcut

/// A drawable gesture mapped to a website. `samples` are example drawings
/// the recognizer matches against — more samples means better accuracy.
nonisolated struct GestureShortcut: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var label: String
    var url: URL
    var samples: [[QPoint]]

    var isBuiltIn: Bool { DefaultGestures.all.contains { $0.id == id } }

    /// Derive a short site name ("YouTube" → "Youtube") from a URL's host
    static func label(for url: URL) -> String {
        url.host?
            .replacingOccurrences(of: "www.", with: "")
            .components(separatedBy: ".").first?
            .capitalized ?? url.absoluteString
    }

    static func normalizedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let full = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: full), url.host != nil else { return nil }
        return url
    }

    static func builtIn(_ id: String) -> GestureShortcut? {
        guard let d = DefaultGestures.all.first(where: { $0.id == id }) else { return nil }
        return GestureShortcut(id: d.id, name: d.name, label: d.label, url: URL(string: d.url)!, samples: d.samples)
    }
}

// MARK: - Gesture Store

/// Persists gestures as JSON in Application Support. The same JSON format
/// is used for import/export so gesture sets can be shared between devices.
nonisolated enum GestureStore {

    private struct FileFormat: Codable {
        var version: Int
        var gestures: [GestureShortcut]
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("gestures.json")
    }

    static func load() -> [GestureShortcut] {
        if let data = try? Data(contentsOf: fileURL), let gestures = decode(data) {
            return gestures
        }
        return migratedDefaults()
    }

    static func save(_ gestures: [GestureShortcut]) {
        guard let data = encode(gestures) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func encode(_ gestures: [GestureShortcut]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(FileFormat(version: 1, gestures: gestures))
    }

    static func decode(_ data: Data) -> [GestureShortcut]? {
        try? JSONDecoder().decode(FileFormat.self, from: data).gestures
    }

    /// Writes the current gestures to a temporary file for sharing
    static func exportFile(_ gestures: [GestureShortcut]) -> URL? {
        guard let data = encode(gestures) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Browser Gestures.json")
        return (try? data.write(to: url, options: .atomic)) != nil ? url : nil
    }

    /// Imported gestures replace ones with the same id and are appended otherwise
    static func merge(_ imported: [GestureShortcut], into existing: [GestureShortcut]) -> [GestureShortcut] {
        var result = existing
        for gesture in imported {
            if let i = result.firstIndex(where: { $0.id == gesture.id }) {
                result[i] = gesture
            } else {
                result.append(gesture)
            }
        }
        return result
    }

    /// Fit a drawing into a 0...1 box and round it, so saved samples are
    /// compact and independent of screen size.
    static func compact(_ points: [CGPoint]) -> [QPoint] {
        guard let first = points.first else { return [] }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let size = max(maxX - minX, maxY - minY, 1)
        return points.map {
            QPoint(x: (Double(($0.x - minX) / size) * 1000).rounded() / 1000,
                   y: (Double(($0.y - minY) / size) * 1000).rounded() / 1000)
        }
    }

    /// First launch: built-in gestures, keeping any URLs customized in the older UserDefaults format
    private static func migratedDefaults() -> [GestureShortcut] {
        DefaultGestures.all.compactMap { d in
            guard var gesture = GestureShortcut.builtIn(d.id) else { return nil }
            let key = "gestureURL_\(d.id)"
            if let saved = UserDefaults.standard.string(forKey: key), let url = URL(string: saved) {
                gesture.url = url
                gesture.label = GestureShortcut.label(for: url)
            }
            return gesture
        }
    }
}

extension QRecognizer {
    init(gestures: [GestureShortcut]) {
        self.init()
        for gesture in gestures {
            for sample in gesture.samples {
                addTemplate(id: gesture.id, points: sample)
            }
        }
    }
}

// MARK: - Gesture Thumbnail

/// Small preview of a gesture's drawing, used in lists and the recognition popup
struct GestureThumbnail: View {
    let points: [QPoint]
    var color: Color = Color.tealAccent
    var lineWidth: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            guard points.count >= 2 else { return }
            var minX = Double.infinity, minY = Double.infinity
            var maxX = -Double.infinity, maxY = -Double.infinity
            for p in points {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
            let inset = lineWidth + 1
            let available = Double(min(size.width, size.height) - inset * 2)
            let scale = available / max(maxX - minX, maxY - minY, 0.0001)
            let offsetX = (Double(size.width) - (maxX - minX) * scale) / 2
            let offsetY = (Double(size.height) - (maxY - minY) * scale) / 2

            var path = Path()
            for (i, p) in points.enumerated() {
                let pt = CGPoint(x: (p.x - minX) * scale + offsetX, y: (p.y - minY) * scale + offsetY)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Gesture Editor

/// Create or edit a gesture: set its name and site, and draw samples to teach the recognizer.
struct GestureEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let original: GestureShortcut
    /// All other gestures, used to warn when a new drawing looks like one of them
    let otherGestures: [GestureShortcut]
    let onSave: (GestureShortcut) -> Void
    let onDelete: (() -> Void)?

    @State private var name: String
    @State private var urlText: String
    @State private var samples: [[QPoint]]
    @State private var warning: String? = nil
    @State private var padPoints: [CGPoint] = []

    init(gesture: GestureShortcut, isNew: Bool, otherGestures: [GestureShortcut],
         onSave: @escaping (GestureShortcut) -> Void, onDelete: (() -> Void)?) {
        self.original = gesture
        self.otherGestures = otherGestures
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: gesture.name)
        _urlText = State(initialValue: isNew ? "" : gesture.url.absoluteString)
        _samples = State(initialValue: gesture.samples)
    }

    private var parsedURL: URL? { GestureShortcut.normalizedURL(from: urlText) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedURL != nil && !samples.isEmpty
    }

    private let fieldBackground = Color(red: 0.94, green: 0.92, blue: 0.88)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        section("Name") {
                            TextField("e.g. Star", text: $name)
                                .font(.system(size: 17, design: .rounded))
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 10).fill(fieldBackground))
                        }

                        section("Opens") {
                            TextField("https://example.com", text: $urlText)
                                .font(.system(size: 17, design: .rounded))
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 10).fill(fieldBackground))
                        }

                        section("Draw it") {
                            drawingPad
                            Text(samples.count < 3
                                 ? "Draw the gesture a few times the way you naturally would — 3 or more samples makes it much more reliable."
                                 : "\(samples.count) samples. Add more any time to improve accuracy.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Color.darkText.opacity(0.5))

                            if let warning {
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.orange)
                            }
                        }

                        if !samples.isEmpty {
                            section("Samples") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                                            GestureThumbnail(points: sample)
                                                .frame(width: 56, height: 56)
                                                .padding(6)
                                                .background(RoundedRectangle(cornerRadius: 10).fill(fieldBackground))
                                                .overlay(alignment: .topTrailing) {
                                                    Button {
                                                        samples.remove(at: index)
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 18))
                                                            .foregroundStyle(Color.darkText.opacity(0.5), Color.creamBackground)
                                                    }
                                                    .offset(x: 6, y: -6)
                                                }
                                        }
                                    }
                                    .padding(.top, 8)
                                    .padding(.trailing, 8)
                                }
                            }
                        }

                        VStack(spacing: 12) {
                            if original.isBuiltIn, let defaults = GestureShortcut.builtIn(original.id) {
                                Button("Reset to Default") {
                                    name = defaults.name
                                    urlText = defaults.url.absoluteString
                                    samples = defaults.samples
                                    warning = nil
                                }
                                .foregroundStyle(Color.tealAccent)
                            }
                            if let onDelete {
                                Button("Delete Gesture", role: .destructive) {
                                    onDelete()
                                    dismiss()
                                }
                            }
                        }
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(original.name.isEmpty ? "New Gesture" : original.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.darkText.opacity(0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let url = parsedURL else { return }
                        var gesture = original
                        gesture.name = name.trimmingCharacters(in: .whitespaces)
                        if url != original.url || gesture.label.isEmpty {
                            gesture.label = GestureShortcut.label(for: url)
                        }
                        gesture.url = url
                        gesture.samples = samples
                        onSave(gesture)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? Color.tealAccent : Color.darkText.opacity(0.3))
                }
            }
        }
    }

    private var drawingPad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(fieldBackground)

            if padPoints.isEmpty {
                Text("Draw here")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.darkText.opacity(0.3))
            }

            Canvas { context, _ in
                guard padPoints.count >= 2 else { return }
                var path = Path()
                path.addLines(padPoints)
                context.stroke(path, with: .color(Color.tealAccent),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .allowsHitTesting(false)
        }
        .frame(height: 240)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    padPoints.append(value.location)
                }
                .onEnded { _ in
                    addSample(padPoints)
                    withAnimation(.easeOut(duration: 0.3)) {
                        padPoints = []
                    }
                }
        )
    }

    private func addSample(_ points: [CGPoint]) {
        guard points.count >= 10 else { return }
        let sample = GestureStore.compact(points)

        // Warn if this drawing would be mistaken for a different gesture
        let others = QRecognizer(gestures: otherGestures)
        let ownSamples = QRecognizer(gestures: [GestureShortcut(id: original.id, name: "", label: "", url: original.url, samples: samples)])
        if let clash = others.recognize(sample),
           let other = otherGestures.first(where: { $0.id == clash.id }) {
            let ownDistance = ownSamples.rank(sample).first?.distance ?? .infinity
            if clash.distance < ownDistance {
                warning = "That looks a lot like \(other.name). Try making it more distinct so they don't get mixed up."
            } else {
                warning = nil
            }
        } else {
            warning = nil
        }
        samples.append(sample)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.darkText.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1)
            content()
        }
    }
}

// MARK: - Sparkle Point

private struct SparklePoint: Identifiable {
    let id = UUID()
    let position: CGPoint
    let radius: CGFloat
    let opacity: Double
    let offset: CGPoint
}

// MARK: - Gesture Canvas View

struct GestureCanvasView: View {
    let shortcuts: [GestureShortcut]
    let onNavigate: (URL) -> Void

    @State private var points: [CGPoint] = []
    @State private var isDrawing = false
    @State private var trailOpacity: Double = 1.0
    @State private var recognizer = QRecognizer()

    // Turquoise sparkle color
    private let trailColor = Color(red: 0.35, green: 0.72, blue: 0.68)
    private let sparkleColor = Color(red: 0.5, green: 0.85, blue: 0.82)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Invisible touch area
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                if !isDrawing {
                                    points = []
                                    trailOpacity = 1.0
                                    isDrawing = true
                                }
                                points.append(value.location)
                            }
                            .onEnded { _ in
                                isDrawing = false
                                // Attempt recognition
                                // Ignore taps and tiny scribbles
                                if points.count >= 15, let match = recognizer.recognize(points.map(QPoint.init)) {
                                    if let shortcut = shortcuts.first(where: { $0.id == match.id }) {
                                        // Navigate immediately
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            trailOpacity = 0
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            onNavigate(shortcut.url)
                                            resetState()
                                        }
                                    } else {
                                        fadeOutTrail()
                                    }
                                } else {
                                    fadeOutTrail()
                                }
                            }
                    )

                // Trail canvas
                if !points.isEmpty {
                    Canvas { context, size in
                        guard points.count >= 2 else { return }

                        // Draw main trail
                        var path = Path()
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                        context.opacity = trailOpacity
                        context.stroke(
                            path,
                            with: .color(trailColor),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                        // Draw sparkle dots along the path
                        drawSparkles(context: &context, points: points)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .onAppear { recognizer = QRecognizer(gestures: shortcuts) }
        .onChange(of: shortcuts) { recognizer = QRecognizer(gestures: shortcuts) }
    }

    private func drawSparkles(context: inout GraphicsContext, points: [CGPoint]) {
        // Place sparkle dots every ~25 points along the path
        var accumulatedDist: CGFloat = 0
        let sparkleInterval: CGFloat = 25

        for i in 1..<points.count {
            let dx = points[i].x - points[i-1].x
            let dy = points[i].y - points[i-1].y
            let segDist = hypot(dx, dy)
            accumulatedDist += segDist

            if accumulatedDist >= sparkleInterval {
                accumulatedDist = 0

                // Direction perpendicular to the stroke
                let len = max(segDist, 0.01)
                let perpX = -dy / len
                let perpY = dx / len

                // Use a deterministic "random" based on index
                let seed1 = CGFloat((i * 7 + 13) % 17) / 17.0
                let seed2 = CGFloat((i * 11 + 3) % 13) / 13.0

                let offsetDist = (seed1 - 0.5) * 8
                let sparkX = points[i].x + perpX * offsetDist
                let sparkY = points[i].y + perpY * offsetDist
                let radius = 1.0 + seed2 * 2.5
                let opacity = 0.3 + seed1 * 0.5

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: sparkX - radius,
                        y: sparkY - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(sparkleColor.opacity(opacity))
                )

                // Second smaller sparkle on the other side sometimes
                if seed2 > 0.4 {
                    let offset2 = -offsetDist * 0.7
                    let s2x = points[i].x + perpX * offset2
                    let s2y = points[i].y + perpY * offset2
                    let r2 = 0.8 + seed1 * 1.5

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: s2x - r2,
                            y: s2y - r2,
                            width: r2 * 2,
                            height: r2 * 2
                        )),
                        with: .color(sparkleColor.opacity(opacity * 0.7))
                    )
                }
            }
        }
    }

    private func fadeOutTrail() {
        withAnimation(.easeOut(duration: 0.5)) {
            trailOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            resetState()
        }
    }

    private func resetState() {
        points = []
        isDrawing = false
        trailOpacity = 1.0
    }
}
