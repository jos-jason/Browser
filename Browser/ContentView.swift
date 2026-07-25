//
//  ContentView.swift
//  Browser
//
//  Created by JJ vollum on 7/25/26.
//

import SwiftUI
import WebKit

// MARK: - Color Palette

extension Color {
    static let creamBackground = Color(red: 0.96, green: 0.94, blue: 0.91)
    static let tealAccent = Color(red: 0.35, green: 0.67, blue: 0.64)
    static let darkText = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let settingsAccent = Color(red: 0.847, green: 0.541, blue: 0.102)
}

// MARK: - WebView

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
}

// MARK: - Gapped Border with Dots

struct GappedBorderWithDots: View {
    let cornerRadius: CGFloat
    let gap1Start: CGFloat
    let gap2Start: CGFloat
    let gapSize: CGFloat
    let lineWidth: CGFloat
    let borderColor: Color
    let fillColor: Color
    var drawDots: Bool = true

    var body: some View {
        Canvas { context, canvasSize in
            let fullRect = CGRect(origin: .zero, size: canvasSize)
            let lw = lineWidth

            // Inset the border rect by half the line width so the stroke isn't clipped
            let rect = fullRect.insetBy(dx: lw / 2, dy: lw / 2)
            let cr = cornerRadius - lw / 2

            // 1. Draw the fill
            let fillRect = rect.insetBy(dx: lw / 2, dy: lw / 2)
            let fillPath = Path(roundedRect: fillRect, cornerRadius: max(cr - lw / 2, 0))
            context.fill(fillPath, with: .color(fillColor))

            // Perimeter helpers
            let r = min(cr, min(rect.width, rect.height) / 2)
            let straightH = rect.width - 2 * r
            let straightV = rect.height - 2 * r
            let cornerArc = CGFloat.pi * r / 2
            let perimeter = 2 * straightH + 2 * straightV + 4 * cornerArc

            let gaps: [(start: CGFloat, end: CGFloat)] = [
                (gap1Start * perimeter, (gap1Start + gapSize) * perimeter),
                (gap2Start * perimeter, (gap2Start + gapSize) * perimeter)
            ]

            // 2. Draw the gapped border
            let steps = 500
            var borderPath = Path()
            var isDrawing = false

            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let dist = t * perimeter
                let p = Self.pointOn(rect: rect, r: r, dist: dist, straightH: straightH, straightV: straightV, cornerArc: cornerArc, perimeter: perimeter)

                let inGap = gaps.contains { dist >= $0.start && dist <= $0.end }

                if !inGap {
                    if !isDrawing {
                        borderPath.move(to: p)
                        isDrawing = true
                    } else {
                        borderPath.addLine(to: p)
                    }
                } else {
                    isDrawing = false
                }
            }

            context.stroke(borderPath, with: .color(borderColor), lineWidth: lw)

            // 3. Optionally draw dots in each gap
            if drawDots {
                Self.drawGapDots(context: &context, gaps: gaps, rect: rect, r: r, straightH: straightH, straightV: straightV, cornerArc: cornerArc, perimeter: perimeter, borderColor: borderColor)
            }
        }
    }

    static func drawGapDots(context: inout GraphicsContext, gaps: [(start: CGFloat, end: CGFloat)], rect: CGRect, r: CGFloat, straightH: CGFloat, straightV: CGFloat, cornerArc: CGFloat, perimeter: CGFloat, borderColor: Color) {
        let dotSizes: [CGFloat] = [2.2, 1.5, 0.8]
        let dotSpacing: CGFloat = 8.0

        for gap in gaps {
            for (i, dotR) in dotSizes.enumerated() {
                let offset = dotSpacing * CGFloat(i + 1)
                let opacity = 0.8 - Double(i) * 0.25

                let d1 = gap.start + offset
                let p1 = pointOn(rect: rect, r: r, dist: d1, straightH: straightH, straightV: straightV, cornerArc: cornerArc, perimeter: perimeter)
                context.fill(
                    Path(ellipseIn: CGRect(x: p1.x - dotR, y: p1.y - dotR, width: dotR * 2, height: dotR * 2)),
                    with: .color(borderColor.opacity(opacity))
                )

                let d2 = gap.end - offset
                let p2 = pointOn(rect: rect, r: r, dist: d2, straightH: straightH, straightV: straightV, cornerArc: cornerArc, perimeter: perimeter)
                context.fill(
                    Path(ellipseIn: CGRect(x: p2.x - dotR, y: p2.y - dotR, width: dotR * 2, height: dotR * 2)),
                    with: .color(borderColor.opacity(opacity))
                )
            }
        }
    }

    static func pointOn(rect: CGRect, r: CGFloat, dist: CGFloat, straightH: CGFloat, straightV: CGFloat, cornerArc: CGFloat, perimeter: CGFloat) -> CGPoint {
        var d = dist.truncatingRemainder(dividingBy: perimeter)
        if d < 0 { d += perimeter }

        // Top edge
        if d <= straightH {
            return CGPoint(x: rect.minX + r + d, y: rect.minY)
        }
        d -= straightH
        // Top-right corner
        if d <= cornerArc {
            let angle = -.pi / 2 + (d / r)
            return CGPoint(x: rect.maxX - r + r * cos(angle), y: rect.minY + r + r * sin(angle))
        }
        d -= cornerArc
        // Right edge
        if d <= straightV {
            return CGPoint(x: rect.maxX, y: rect.minY + r + d)
        }
        d -= straightV
        // Bottom-right corner
        if d <= cornerArc {
            let angle = d / r
            return CGPoint(x: rect.maxX - r + r * cos(angle), y: rect.maxY - r + r * sin(angle))
        }
        d -= cornerArc
        // Bottom edge
        if d <= straightH {
            return CGPoint(x: rect.maxX - r - d, y: rect.maxY)
        }
        d -= straightH
        // Bottom-left corner
        if d <= cornerArc {
            let angle = .pi / 2 + (d / r)
            return CGPoint(x: rect.minX + r + r * cos(angle), y: rect.maxY - r + r * sin(angle))
        }
        d -= cornerArc
        // Left edge
        if d <= straightV {
            return CGPoint(x: rect.minX, y: rect.maxY - r - d)
        }
        d -= straightV
        // Top-left corner
        let angle = .pi + (d / r)
        return CGPoint(x: rect.minX + r + r * cos(angle), y: rect.minY + r + r * sin(angle))
    }
}

struct DotOverlay: View {
    let cornerRadius: CGFloat
    let gap1Start: CGFloat
    let gap2Start: CGFloat
    let gapSize: CGFloat
    let dotColor: Color
    var inset: CGFloat = 0

    var body: some View {
        Canvas { context, canvasSize in
            // The canvas is larger than the search bar by `inset` on each side.
            // Inset to match the search bar, then further by half the border width
            // so dots align with the border path.
            let borderWidth: CGFloat = 2.5
            let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: inset + borderWidth / 2, dy: inset + borderWidth / 2)
            let r = min(cornerRadius - borderWidth / 2, min(rect.width, rect.height) / 2)
            let straightH = rect.width - 2 * r
            let straightV = rect.height - 2 * r
            let cornerArc = CGFloat.pi * r / 2
            let perimeter = 2 * straightH + 2 * straightV + 4 * cornerArc

            let gaps: [(start: CGFloat, end: CGFloat)] = [
                (gap1Start * perimeter, (gap1Start + gapSize) * perimeter),
                (gap2Start * perimeter, (gap2Start + gapSize) * perimeter)
            ]

            GappedBorderWithDots.drawGapDots(
                context: &context,
                gaps: gaps,
                rect: rect,
                r: r,
                straightH: straightH,
                straightV: straightV,
                cornerArc: cornerArc,
                perimeter: perimeter,
                borderColor: dotColor
            )
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var searchText = ""
    @State private var isShowingWeb = false
    @State private var isShowingSettings = false
    @State private var webURL: URL?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()
                .onTapGesture {
                    isSearchFocused = false
                }

            VStack {
                // Top bar with settings button
                HStack {
                    Spacer()
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(Color.settingsAccent)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                            )
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Center content
                VStack(spacing: 24) {
                    // Search bar
                    HStack(spacing: 0) {
                        TextField("Search or enter URL...", text: $searchText)
                            .focused($isSearchFocused)
                            .padding(14)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.webSearch)
                            .submitLabel(.go)
                            .onSubmit { go() }
                    }
                    .background(
                        GappedBorderWithDots(
                            cornerRadius: 12,
                            gap1Start: 0.05,
                            gap2Start: 0.55,
                            gapSize: 0.10,
                            lineWidth: 2.5,
                            borderColor: Color.darkText.opacity(0.75),
                            fillColor: Color(red: 0.94, green: 0.92, blue: 0.88),
                            drawDots: false
                        )
                    )
                    .overlay(
                        DotOverlay(
                            cornerRadius: 12,
                            gap1Start: 0.05,
                            gap2Start: 0.55,
                            gapSize: 0.10,
                            dotColor: Color.darkText.opacity(0.75),
                            inset: 6
                        )
                        .padding(-6)
                        .allowsHitTesting(false)
                    )
                    .padding(.horizontal, 20)

                    // Go button
                    Button { go() } label: {
                        Text("Go!")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 120, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.50, green: 0.78, blue: 0.78),
                                                Color(red: 0.62, green: 0.88, blue: 0.87)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                }
                .offset(y: -UIScreen.main.bounds.height / 8)

                Spacer()
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $isShowingWeb) {
            if let webURL {
                BrowserView(url: webURL, isPresented: $isShowingWeb)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }

    private func go() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.contains(".") && !trimmed.contains(" ") {
            let urlString = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
            if let url = URL(string: urlString) {
                webURL = url
                isShowingWeb = true
                return
            }
        }

        // Treat as a search query
        let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        if let url = URL(string: "https://www.google.com/search?q=\(query)") {
            webURL = url
            isShowingWeb = true
        }
    }
}

// MARK: - Browser View

struct BrowserView: View {
    let url: URL
    @Binding var isPresented: Bool
    @State private var currentURL: URL?

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.tealAccent)
                    }

                    Spacer()

                    Text(url.host ?? "")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.darkText)
                        .lineLimit(1)

                    Spacer()

                    // Invisible balance
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .hidden()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.creamBackground)

                WebView(url: url)
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.tealAccent)

                    Text("Settings")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.darkText)

                    Text("Nothing here yet.")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(Color.darkText.opacity(0.6))

                    Spacer()
                }
                .padding(.top, 40)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.tealAccent)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
