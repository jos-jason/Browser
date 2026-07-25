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

// MARK: - Search Engine

enum SearchEngine: String, CaseIterable, Identifiable {
    case brave = "Brave"
    case duckduckgo = "DuckDuckGo"
    case google = "Google"

    var id: String { rawValue }

    func searchURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch self {
        case .brave:
            return URL(string: "https://search.brave.com/search?q=\(encoded)")
        case .duckduckgo:
            return URL(string: "https://duckduckgo.com/?q=\(encoded)")
        case .google:
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        }
    }
}

// MARK: - Content Blocker

@Observable
class ContentBlocker {
    var ruleList: WKContentRuleList?
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "adBlockingEnabled")
        }
    }

    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "adBlockingEnabled") as? Bool ?? true
        compileRules()
    }

    private func compileRules() {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "adBlocker",
            encodedContentRuleList: ContentBlocker.rulesJSON
        ) { ruleList, error in
            if let ruleList {
                self.ruleList = ruleList
            }
        }
    }

    static let rulesJSON = """
    [
        {
            "trigger": { "url-filter": ".*", "resource-type": ["script", "image", "raw"],
                "if-domain": ["*doubleclick.net", "*googlesyndication.com", "*googleadservices.com",
                    "*google-analytics.com", "*adservice.google.com", "*pagead2.googlesyndication.com",
                    "*adnxs.com", "*adsrvr.org", "*adcolony.com", "*amazon-adsystem.com",
                    "*moatads.com", "*scorecardresearch.com", "*quantserve.com",
                    "*outbrain.com", "*taboola.com", "*criteo.com", "*pubmatic.com",
                    "*rubiconproject.com", "*openx.net", "*casalemedia.com",
                    "*sharethis.com", "*addthis.com", "*hotjar.com"]
            },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*",
                "if-domain": ["*facebook.net", "*facebook.com"],
                "resource-type": ["script"],
                "unless-top-url-matches": [".*facebook\\\\.com.*"]
            },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.doubleclick\\\\.net" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.googlesyndication\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.googleadservices\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.google-analytics\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.adnxs\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.amazon-adsystem\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.moatads\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.scorecardresearch\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.outbrain\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.taboola\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.criteo\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.hotjar\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.pubmatic\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*pagead" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.adsrvr\\\\.org" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.quantserve\\\\.com" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*", "resource-type": ["popup"] },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*" },
            "action": { "type": "css-display-none", "selector": ".ad, .ads, .adsbygoogle, [id^='google_ads'], [class*='sponsored'], [data-ad], .ad-banner, .ad-container, #ad-container, .ad-wrapper, .dfp-ad, [id*='taboola'], [id*='outbrain'], .promoted-content" }
        }
    ]
    """
}

// MARK: - WebView

@Observable
class WebViewNavigator {
    weak var webView: WKWebView?
    var canGoBack = false

    func goBack() {
        webView?.goBack()
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    let navigator: WebViewNavigator
    let contentBlocker: ContentBlocker

    func makeCoordinator() -> Coordinator {
        Coordinator(navigator: navigator)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        if contentBlocker.isEnabled, let ruleList = contentBlocker.ruleList {
            config.userContentController.add(ruleList)
        }
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        navigator.webView = webView
        context.coordinator.lastRequestedURL = url
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if url != context.coordinator.lastRequestedURL {
            context.coordinator.lastRequestedURL = url
            uiView.load(URLRequest(url: url))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let navigator: WebViewNavigator
        var lastRequestedURL: URL?

        init(navigator: WebViewNavigator) {
            self.navigator = navigator
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            navigator.canGoBack = webView.canGoBack
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            navigator.canGoBack = webView.canGoBack
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

// MARK: - Identifiable URL wrapper

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Content View

struct ContentView: View {
    @State private var searchText = ""
    @State private var isShowingSettings = false
    @State private var webItem: IdentifiableURL?
    @FocusState private var isSearchFocused: Bool
    @AppStorage("searchEngine") private var searchEngine: String = SearchEngine.brave.rawValue
    @State private var screenHeight: CGFloat = 0
    @State private var contentBlocker = ContentBlocker()

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
                .offset(y: -screenHeight / 8)

                Spacer()
            }
        }
        .ignoresSafeArea(.keyboard)
        .overlay(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        if screenHeight == 0 {
                            screenHeight = geo.size.height
                        }
                    }
            }
        )
        .fullScreenCover(item: $webItem, onDismiss: {
            searchText = ""
        }) { item in
            BrowserView(url: item.url, contentBlocker: contentBlocker) {
                webItem = nil
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(contentBlocker: contentBlocker)
        }
    }

    private func go() {
        isSearchFocused = false
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Direct URL
        if trimmed.contains(".") && !trimmed.contains(" ") {
            let urlString = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
            if let url = URL(string: urlString) {
                webItem = IdentifiableURL(url: url)
                return
            }
        }

        // Search query using selected engine
        let engine = SearchEngine(rawValue: searchEngine) ?? .brave
        if let url = engine.searchURL(for: trimmed) {
            webItem = IdentifiableURL(url: url)
        }
    }
}

// MARK: - Browser View

struct BrowserView: View {
    let url: URL
    let contentBlocker: ContentBlocker
    var onDismiss: () -> Void

    @State private var currentURL: URL
    @State private var searchText = ""
    @State private var navigator = WebViewNavigator()
    @FocusState private var isSearchFocused: Bool
    @AppStorage("searchEngine") private var searchEngine: String = SearchEngine.brave.rawValue

    init(url: URL, contentBlocker: ContentBlocker, onDismiss: @escaping () -> Void) {
        self.url = url
        self.contentBlocker = contentBlocker
        self.onDismiss = onDismiss
        _currentURL = State(initialValue: url)
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 12) {
                    Button {
                        if navigator.canGoBack {
                            navigator.goBack()
                        } else {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.darkText.opacity(0.6))
                    }

                    if navigator.canGoBack {
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.darkText.opacity(0.6))
                        }
                    }

                    Spacer()

                    Text(currentURL.host ?? "")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.darkText.opacity(0.6))
                        .lineLimit(1)

                    Spacer()

                    ShareLink(item: currentURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.darkText.opacity(0.6))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.white)

                WebView(url: currentURL, navigator: navigator, contentBlocker: contentBlocker)

                // Bottom search bar
                HStack(spacing: 0) {
                    TextField("Search or enter URL...", text: $searchText)
                        .focused($isSearchFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .onSubmit { goInBrowser() }

                    Button { goInBrowser() } label: {
                        Text("Go!")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
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
                    .padding(.trailing, 3)
                    .padding(.vertical, 3)
                }
                .background(
                    GappedBorderWithDots(
                        cornerRadius: 12,
                        gap1Start: 0.05,
                        gap2Start: 0.55,
                        gapSize: 0.10,
                        lineWidth: 2.5,
                        borderColor: Color.darkText.opacity(0.75),
                        fillColor: Color(red: 0.97, green: 0.96, blue: 0.94),
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white)
            }
        }
    }

    private func goInBrowser() {
        isSearchFocused = false
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.contains(".") && !trimmed.contains(" ") {
            let urlString = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
            if let newURL = URL(string: urlString) {
                currentURL = newURL
                searchText = ""
                return
            }
        }

        let engine = SearchEngine(rawValue: searchEngine) ?? .brave
        if let newURL = engine.searchURL(for: trimmed) {
            currentURL = newURL
            searchText = ""
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("searchEngine") private var searchEngine: String = SearchEngine.brave.rawValue
    var contentBlocker: ContentBlocker

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Search engine picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Search Engine")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.darkText.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1)

                        ForEach(SearchEngine.allCases) { engine in
                            Button {
                                searchEngine = engine.rawValue
                            } label: {
                                HStack {
                                    Text(engine.rawValue)
                                        .font(.system(size: 17, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.darkText)

                                    Spacer()

                                    if searchEngine == engine.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Color.tealAccent)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(searchEngine == engine.rawValue
                                              ? Color.tealAccent.opacity(0.1)
                                              : Color(red: 0.94, green: 0.92, blue: 0.88))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(searchEngine == engine.rawValue
                                                ? Color.tealAccent.opacity(0.4)
                                                : Color.clear, lineWidth: 1.5)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Ad blocking toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.darkText.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1)

                        HStack {
                            Text("Block Ads & Trackers")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.darkText)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { contentBlocker.isEnabled },
                                set: { contentBlocker.isEnabled = $0 }
                            ))
                            .tint(Color.tealAccent)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.94, green: 0.92, blue: 0.88))
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
