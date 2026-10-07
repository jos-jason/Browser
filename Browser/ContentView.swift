//
//  ContentView.swift
//  Browser
//
//  Created by JJ vollum on 7/25/26.
//

import SwiftUI
import WebKit
import Photos
import UniformTypeIdentifiers

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
    var canGoForward = false

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
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

// MARK: - Browser Tab

@Observable
class BrowserTab: Identifiable {
    let id = UUID()
    var currentURL: URL
    var title: String = ""
    /// Why the last page failed to load (nil when it loaded fine)
    var loadError: String?
    /// The address that failed, so the user can correct it
    var failedURL: URL?

    /// Blank or error pages get the address bar opened automatically
    var needsAddressBar: Bool {
        loadError != nil || currentURL.absoluteString == "about:blank"
    }
    var snapshot: UIImage?
    let navigator: WebViewNavigator
    let webView: WKWebView
    let delegate: BrowserTabDelegate
    private var urlObservation: NSKeyValueObservation?

    init(url: URL, contentBlocker: ContentBlocker) {
        self.currentURL = url
        self.navigator = WebViewNavigator()

        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        if contentBlocker.isEnabled, let ruleList = contentBlocker.ruleList {
            config.userContentController.add(ruleList)
        }
        let wk = WKWebView(frame: .zero, configuration: config)
        wk.allowsBackForwardNavigationGestures = true
        self.webView = wk
        self.navigator.webView = wk

        let del = BrowserTabDelegate()
        self.delegate = del
        wk.navigationDelegate = del
        wk.uiDelegate = del

        // Set back-reference so delegate can update this tab
        del.tab = self

        // Catch URL changes that don't trigger a navigation (e.g. YouTube, Reddit page changes)
        urlObservation = wk.observe(\.url, options: [.new]) { [weak self] webView, _ in
            MainActor.assumeIsolated {
                if let url = webView.url { self?.currentURL = url }
            }
        }

        wk.load(URLRequest(url: url))
    }

    func captureSnapshot() {
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { image, _ in
            if let image {
                self.snapshot = image
            }
        }
    }
}

// Delegate owned by BrowserTab so it's active from the moment the web view is created
class BrowserTabDelegate: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    weak var tab: BrowserTab?
    /// HTTP status of the main page being loaded, checked once it commits
    private var pendingHTTPStatus: Int?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let tab else { return }
        tab.navigator.canGoBack = webView.canGoBack
        tab.navigator.canGoForward = webView.canGoForward
        tab.currentURL = webView.url ?? tab.currentURL
        tab.title = webView.title ?? ""
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard let tab else { return }
        tab.navigator.canGoBack = webView.canGoBack
        tab.navigator.canGoForward = webView.canGoForward
        tab.currentURL = webView.url ?? tab.currentURL

        // The site answered, but with an error page (404, 500, ...)
        if let status = pendingHTTPStatus, status >= 400 {
            tab.loadError = "The site returned an error (\(status) \(HTTPURLResponse.localizedString(forStatusCode: status).capitalized))."
            tab.failedURL = webView.url
        } else {
            tab.loadError = nil
            tab.failedURL = nil
        }
        pendingHTTPStatus = nil
    }

    // Couldn't reach the page at all (no internet, bad address, ...)
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        recordFailure(error, in: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        recordFailure(error, in: webView)
    }

    private func recordFailure(_ error: Error, in webView: WKWebView) {
        guard let tab else { return }
        let nsError = error as NSError
        // Not real failures: a navigation that was replaced/cancelled, or one that became a download
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }

        tab.loadError = nsError.localizedDescription
        tab.failedURL = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? webView.url
    }

    // Upgrade http:// to https:// to satisfy App Transport Security
    private func upgradeToHTTPS(_ url: URL) -> URL {
        if url.scheme == "http", var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            components.scheme = "https"
            return components.url ?? url
        }
        return url
    }

    // Some sites (e.g. audible.com) run a browser-compatibility check that fails
    // silently when the UA lacks the "Safari/" token WKWebView omits by default,
    // which stops parts of the page (like the header nav) from rendering at all.
    // Scoped to just those domains, since presenting as full Safari everywhere
    // can make other sites' fraud/session heuristics (e.g. Amazon's "keep me
    // signed in") distrust the session and stop persisting login.
    private static let safariSpoofDomains = ["audible.com"]

    private static let spoofedSafariUA: String = {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(osVersion.majorVersion)_\(osVersion.minorVersion)"
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(versionString) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(osVersion.majorVersion).\(osVersion.minorVersion) Mobile/15E148 Safari/604.1"
    }()

    private func desiredUserAgent(for host: String?) -> String? {
        guard let host else { return nil }
        let needsSpoof = Self.safariSpoofDomains.contains { host == $0 || host.hasSuffix(".\($0)") }
        return needsSpoof ? Self.spoofedSafariUA : nil
    }

    // Handle regular navigation — upgrade insecure URLs
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // webView.load(_:) always targets the main frame, so cancel-and-reissue
        // tricks below must only run for main-frame navigations — doing this for
        // a subframe/iframe request (e.g. an ad iframe) would blow away the whole
        // page and replace it with that iframe's URL.
        guard navigationAction.targetFrame?.isMainFrame == true else {
            decisionHandler(.allow)
            return
        }

        if url.scheme == "http" {
            decisionHandler(.cancel)
            webView.load(URLRequest(url: upgradeToHTTPS(url)))
            return
        }

        // customUserAgent only takes effect starting with the *next* navigation,
        // not the one currently being decided — so when it needs to change,
        // cancel this navigation and reissue it once the UA is set.
        // Note: the getter reads back "" (not nil) once any value has ever been
        // set, so nil and "" must be treated as equivalent here, or this becomes
        // an infinite cancel/reload loop for every non-spoofed site.
        let currentUA = webView.customUserAgent.flatMap { $0.isEmpty ? nil : $0 }
        let desiredUA = desiredUserAgent(for: url.host)
        if currentUA != desiredUA {
            webView.customUserAgent = desiredUA
            decisionHandler(.cancel)
            webView.load(URLRequest(url: url))
            return
        }

        decisionHandler(.allow)
    }

    // Convert non-renderable responses (e.g. Content-Disposition: attachment) into downloads
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame {
            pendingHTTPStatus = (navigationResponse.response as? HTTPURLResponse)?.statusCode
        }
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    // A navigation action became a download
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    // A navigation response became a download
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    // Handle window.open() and target="_blank" links
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: upgradeToHTTPS(url)))
        }
        return nil
    }

    // MARK: - WKDownloadDelegate

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let destination = tempDir.appendingPathComponent(suggestedFilename)
        // Remove any existing file at the destination
        try? FileManager.default.removeItem(at: destination)
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = download.originalRequest?.url else { return }

        // Build the file path from the suggested filename used during download
        let suggestedFilename = url.lastPathComponent
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)

        // Check if the file is an image by its UTI
        guard FileManager.default.fileExists(atPath: tempFile.path) else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }

            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: tempFile, options: nil)
            } completionHandler: { success, _ in
                // Clean up temp file regardless of outcome
                try? FileManager.default.removeItem(at: tempFile)
            }
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        // Download failed — nothing to do
    }
}

// MARK: - Tab Manager

@Observable
class TabManager {
    static let maxTabs = 20

    var tabs: [BrowserTab] = []
    var activeTabID: UUID?
    var showTabSwitcher = false

    var activeTab: BrowserTab? {
        guard let id = activeTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    var tabCount: Int { tabs.count }
    var canAddTab: Bool { tabs.count < Self.maxTabs }

    func addTab(url: URL, contentBlocker: ContentBlocker) {
        guard canAddTab else { return }
        let tab = BrowserTab(url: url, contentBlocker: contentBlocker)
        tabs.append(tab)
        activeTabID = tab.id
    }

    func closeTab(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)

        if activeTabID == tab.id {
            if tabs.isEmpty {
                activeTabID = nil
            } else {
                let newIndex = min(index, tabs.count - 1)
                activeTabID = tabs[newIndex].id
            }
        }
    }

    func switchTo(_ tab: BrowserTab) {
        // Capture snapshot of current tab before switching
        activeTab?.captureSnapshot()
        activeTabID = tab.id
        showTabSwitcher = false
    }

    func captureAllSnapshots() {
        for tab in tabs {
            tab.captureSnapshot()
        }
    }
}

// MARK: - Tab Web View

struct TabWebView: UIViewRepresentable {
    let tab: BrowserTab

    func makeUIView(context: Context) -> WKWebView {
        return tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Navigation is handled by the BrowserTab's delegate
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
    @AppStorage("gestureShortcutsEnabled") private var gestureShortcutsEnabled = true
    @State private var gestureShortcuts: [GestureShortcut] = GestureStore.load()

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

            // Gesture drawing canvas — fills the whole screen but is invisible
            if gestureShortcutsEnabled {
                VStack {
                    // Leave space for the top bar + search area so drawing only happens below
                    Spacer()
                        .frame(height: screenHeight / 2 + 20)

                    GestureCanvasView(
                        shortcuts: gestureShortcuts,
                        onNavigate: { url in
                            webItem = IdentifiableURL(url: url)
                        }
                    )
                }
                .ignoresSafeArea(.keyboard)
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
        .sheet(isPresented: $isShowingSettings, onDismiss: {
            gestureShortcuts = GestureStore.load()
        }) {
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
    let initialURL: URL
    let contentBlocker: ContentBlocker
    var onDismiss: () -> Void

    @State private var tabManager = TabManager()
    @State private var searchText = ""
    @State private var showFullURL = false
    @State private var didCopyURL = false
    @State private var urlBarText = ""
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isURLBarFocused: Bool
    @AppStorage("searchEngine") private var searchEngine: String = SearchEngine.brave.rawValue
    @AppStorage("researchMode") private var researchMode = false

    init(url: URL, contentBlocker: ContentBlocker, onDismiss: @escaping () -> Void) {
        self.initialURL = url
        self.contentBlocker = contentBlocker
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            if let activeTab = tabManager.activeTab {
                VStack(spacing: 0) {
                    topToolbar(tab: activeTab)
                        .zIndex(1) // URL panel slides out from underneath

                    if showFullURL {
                        fullURLPanel(tab: activeTab)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    TabWebView(tab: activeTab)
                        .id(activeTab.id)

                    if researchMode {
                        tabStrip()
                    }
                }
            }
        }
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.addTab(url: initialURL, contentBlocker: contentBlocker)
            }
        }
        // Open the address bar on blank/error pages (also re-checked when switching tabs)
        .onChange(of: tabManager.activeTab.map { "\($0.id)|\($0.needsAddressBar)|\($0.failedURL?.absoluteString ?? "")" }) {
            guard let tab = tabManager.activeTab, tab.needsAddressBar else { return }
            urlBarText = tab.failedURL.map(Self.readableURL)
                ?? (tab.currentURL.absoluteString == "about:blank" ? "" : Self.readableURL(tab.currentURL))
            withAnimation(.easeInOut(duration: 0.2)) {
                showFullURL = true
            }
            isURLBarFocused = true
        }
        .overlay {
            if researchMode && tabManager.showTabSwitcher {
                tabSwitcherOverlay()
            }
        }
    }

    // MARK: - Top Toolbar

    @ViewBuilder
    private func topToolbar(tab: BrowserTab) -> some View {
        HStack(spacing: 12) {
            Button {
                if tab.navigator.canGoBack {
                    tab.navigator.goBack()
                } else if tabManager.tabCount == 1 {
                    onDismiss()
                } else {
                    tabManager.closeTab(tab)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.darkText.opacity(0.6))
            }

            if tab.navigator.canGoBack || tabManager.tabCount > 1 {
                Button {
                    if tabManager.tabCount == 1 {
                        onDismiss()
                    } else {
                        tabManager.closeTab(tab)
                        if tabManager.tabs.isEmpty {
                            onDismiss()
                        }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.darkText.opacity(0.6))
                }
            }

            if tab.navigator.canGoForward {
                Button {
                    tab.navigator.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.darkText.opacity(0.6))
                }
            }

            Button {
                tab.webView.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.darkText.opacity(0.6))
            }

            Spacer()

            // Tap the domain to see the full URL
            Button {
                if !showFullURL {
                    urlBarText = Self.readableURL(tab.currentURL)
                } else {
                    isURLBarFocused = false
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFullURL.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(tab.currentURL.host ?? "")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(showFullURL ? 180 : 0))
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.darkText.opacity(0.6))
            }

            Spacer()

            if researchMode {
                // Tab count button
                Button {
                    tabManager.captureAllSnapshots()
                    tabManager.showTabSwitcher.toggle()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.darkText.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        Text("\(tabManager.tabCount)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.darkText.opacity(0.6))
                    }
                }
            }

            ShareLink(item: tab.currentURL) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.darkText.opacity(0.6))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.white)
    }

    // MARK: - Full URL Panel

    /// Full URL with %20 etc. decoded so it's readable
    private static func readableURL(_ url: URL) -> String {
        url.absoluteString.removingPercentEncoding ?? url.absoluteString
    }

    @ViewBuilder
    private func fullURLPanel(tab: BrowserTab) -> some View {
        VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 10) {
            searchBar(text: $urlBarText, focus: $isURLBarFocused) {
                if navigate(tab: tab, input: urlBarText) {
                    isURLBarFocused = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFullURL = false
                    }
                }
            }

            Button {
                UIPasteboard.general.string = tab.currentURL.absoluteString
                didCopyURL = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    didCopyURL = false
                }
            } label: {
                Image(systemName: didCopyURL ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.tealAccent)
                    .frame(width: 24, height: 24)
            }
        }

            if let error = tab.loadError {
                Label {
                    Text("Couldn't open this page. \(error)")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.orange)
                .padding(.leading, 4)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(.white)
        .overlay(alignment: .bottom) {
            Divider()
        }
        // Keep the URL current as the page changes, unless the user is editing it
        .onChange(of: tab.currentURL) {
            if !isURLBarFocused && tab.loadError == nil {
                urlBarText = Self.readableURL(tab.currentURL)
            }
        }
    }

    // MARK: - Tab Strip

    @ViewBuilder
    private func tabStrip() -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabManager.tabs) { tab in
                        tabPill(tab: tab)
                            .id(tab.id)
                    }

                    if tabManager.canAddTab {
                        Button {
                            let engine = SearchEngine(rawValue: searchEngine) ?? .brave
                            let homeURL = engine.searchURL(for: "")
                                ?? URL(string: "https://search.brave.com")!
                            tabManager.addTab(url: homeURL, contentBlocker: contentBlocker)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.tealAccent)
                                .frame(width: 32, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.tealAccent.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: tabManager.activeTabID) { _, newID in
                if let newID {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 40)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
    }

    @ViewBuilder
    private func tabPill(tab: BrowserTab) -> some View {
        let isActive = tab.id == tabManager.activeTabID

        Button {
            tabManager.switchTo(tab)
        } label: {
            HStack(spacing: 4) {
                Text(tab.title.isEmpty ? (tab.currentURL.host ?? "New Tab") : tab.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(isActive ? Color.white : Color.darkText.opacity(0.7))
                    .frame(maxWidth: 100)

                if tabManager.tabCount > 1 {
                    Button {
                        tabManager.closeTab(tab)
                        if tabManager.tabs.isEmpty {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isActive ? Color.white.opacity(0.7) : Color.darkText.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.tealAccent : Color.white.opacity(0.8))
            )
        }
    }

    // MARK: - Tab Switcher Overlay

    @ViewBuilder
    private func tabSwitcherOverlay() -> some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Tabs")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.darkText)

                    Spacer()

                    if tabManager.canAddTab {
                        Button {
                            let engine = SearchEngine(rawValue: searchEngine) ?? .brave
                            let homeURL = engine.searchURL(for: "")
                                ?? URL(string: "https://search.brave.com")!
                            tabManager.addTab(url: homeURL, contentBlocker: contentBlocker)
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.tealAccent)
                        }
                    }

                    Button {
                        tabManager.showTabSwitcher = false
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.tealAccent)
                    }
                }
                .padding()



                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(tabManager.tabs) { tab in
                            tabCard(tab: tab)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                // Bottom search bar
                tabSwitcherSearchBar()
            }
        }
    }

    @ViewBuilder
    private func tabSwitcherSearchBar() -> some View {
        HStack(spacing: 0) {
            TextField("Search or enter URL...", text: $searchText)
                .focused($isSearchFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .onSubmit { goInNewTab() }

            Button { goInNewTab() } label: {
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
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
    }

    private func goInNewTab() {
        isSearchFocused = false
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard tabManager.canAddTab else { return }

        var targetURL: URL?

        if trimmed.contains(".") && !trimmed.contains(" ") {
            let urlString = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
            targetURL = URL(string: urlString)
        }

        if targetURL == nil {
            let engine = SearchEngine(rawValue: searchEngine) ?? .brave
            targetURL = engine.searchURL(for: trimmed)
        }

        if let url = targetURL {
            tabManager.addTab(url: url, contentBlocker: contentBlocker)
            searchText = ""
        }
    }

    @ViewBuilder
    private func tabCard(tab: BrowserTab) -> some View {
        let isActive = tab.id == tabManager.activeTabID

        Button {
            tabManager.switchTo(tab)
        } label: {
            VStack(spacing: 0) {
                // Tab title bar
                HStack {
                    Text(tab.title.isEmpty ? (tab.currentURL.host ?? "New Tab") : tab.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.darkText)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isActive ? Color.tealAccent.opacity(0.1) : Color(red: 0.97, green: 0.96, blue: 0.94))

                // Snapshot preview
                if let snapshot = tab.snapshot {
                    Image(uiImage: snapshot)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 140)
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.title3)
                                    .foregroundStyle(Color.darkText.opacity(0.2))
                                Text(tab.currentURL.host ?? "")
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color.darkText.opacity(0.3))
                            }
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.tealAccent : Color.darkText.opacity(0.15),
                            lineWidth: isActive ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
            .overlay(alignment: .topTrailing) {
                Button {
                    tabManager.closeTab(tab)
                    if tabManager.tabs.isEmpty {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.darkText.opacity(0.4))
                        .background(Circle().fill(Color.white))
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    // MARK: - Bottom Search Bar

    /// The app's search bar style: text field + Go! button inside the gapped dotted border.
    /// Long text (full URLs) wraps onto multiple lines instead of being cut off.
    private func searchBar(text: Binding<String>, focus: FocusState<Bool>.Binding,
                           onGo: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            TextField("Search or enter URL...", text: text, axis: .vertical)
                .lineLimit(1...5)
                .focused(focus)
                // A wrapping field types a newline on Return — treat it as Go instead
                .onChange(of: text.wrappedValue) { _, newValue in
                    if newValue.contains("\n") {
                        text.wrappedValue = newValue.replacingOccurrences(of: "\n", with: "")
                        onGo()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .onSubmit(onGo)

            Button(action: onGo) {
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
    }

    // MARK: - Navigation

    /// Loads a URL or search query in the tab. Returns false if there was nothing to load.
    @discardableResult
    private func navigate(tab: BrowserTab, input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var targetURL: URL?

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            // Full URL, possibly with readable spaces from the top bar — re-encode them
            targetURL = URL(string: trimmed, encodingInvalidCharacters: true)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            targetURL = URL(string: "https://\(trimmed)")
        }

        if targetURL == nil {
            let engine = SearchEngine(rawValue: searchEngine) ?? .brave
            targetURL = engine.searchURL(for: trimmed)
        }

        guard let url = targetURL else { return false }
        tab.webView.load(URLRequest(url: url))
        return true
    }
}

// MARK: - App Icon

enum AppIconOption: String, CaseIterable, Identifiable {
    case primary = "Default"
    case dark = "Dark"
    case tinted = "Tinted"
    case alt1 = "Ocean"
    case alt2 = "Sunset"

    var id: String { rawValue }

    /// The alternate icon name registered in Info.plist, or nil for the primary icon
    var alternateIconName: String? {
        switch self {
        case .primary: return nil
        case .dark: return "AppIcon-Dark"
        case .tinted: return "AppIcon-Tinted"
        case .alt1: return "AppIcon-Alt1"
        case .alt2: return "AppIcon-Alt2"
        }
    }

    /// The filename of the preview image in the bundle
    var previewImageName: String {
        switch self {
        case .primary: return "AppIcon-Primary"
        case .dark: return "AppIcon-Dark"
        case .tinted: return "AppIcon-Tinted"
        case .alt1: return "AppIcon-Alt1"
        case .alt2: return "AppIcon-Alt2"
        }
    }

    /// Returns the currently active icon option
    static var current: AppIconOption {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateIconName == name } ?? .primary
    }
}

// MARK: - Settings View

private struct EditingGesture: Identifiable {
    let gesture: GestureShortcut
    let isNew: Bool
    var id: String { gesture.id }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("searchEngine") private var searchEngine: String = SearchEngine.brave.rawValue
    @AppStorage("researchMode") private var researchMode = false
    @AppStorage("gestureShortcutsEnabled") private var gestureShortcutsEnabled = true
    @AppStorage("gestureQuickNavigate") private var gestureQuickNavigate = false
    @State private var currentIcon: AppIconOption = AppIconOption.current
    @State private var gestureShortcuts: [GestureShortcut] = GestureStore.load()
    @State private var editingGesture: EditingGesture? = nil
    @State private var isImportingGestures = false
    @State private var gestureImportMessage: String? = nil
    var contentBlocker: ContentBlocker

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                ScrollView {
                VStack(spacing: 32) {
                    // App Icon picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("App Icon")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.darkText.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(AppIconOption.allCases) { icon in
                                    Button {
                                        setAppIcon(icon)
                                    } label: {
                                        VStack(spacing: 8) {
                                            if let uiImage = UIImage(named: icon.previewImageName) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 64, height: 64)
                                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                            } else {
                                                RoundedRectangle(cornerRadius: 14)
                                                    .fill(Color.darkText.opacity(0.1))
                                                    .frame(width: 64, height: 64)
                                                    .overlay {
                                                        Image(systemName: "app.fill")
                                                            .foregroundStyle(Color.darkText.opacity(0.3))
                                                    }
                                            }

                                            Text(icon.rawValue)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color.darkText)
                                        }
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(currentIcon == icon
                                                      ? Color.tealAccent.opacity(0.1)
                                                      : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(currentIcon == icon
                                                        ? Color.tealAccent
                                                        : Color.clear, lineWidth: 2)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)

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

                    // Research mode toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Browsing")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.darkText.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Research Mode")
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.darkText)
                                Text("Open up to 20 tabs")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color.darkText.opacity(0.5))
                            }

                            Spacer()

                            Toggle("", isOn: $researchMode)
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

                    // Gesture shortcuts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gesture Shortcuts")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.darkText.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1)

                        // Enable/disable toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gesture Shortcuts")
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.darkText)
                                Text("Draw shapes to open sites")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color.darkText.opacity(0.5))
                            }

                            Spacer()

                            Toggle("", isOn: $gestureShortcutsEnabled)
                                .tint(Color.tealAccent)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.94, green: 0.92, blue: 0.88))
                        )

                        if gestureShortcutsEnabled {
                            // Quick navigate toggle
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Quick Navigate")
                                        .font(.system(size: 17, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.darkText)
                                    Text("Skip confirmation, go immediately")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(Color.darkText.opacity(0.5))
                                }

                                Spacer()

                                Toggle("", isOn: $gestureQuickNavigate)
                                    .tint(Color.tealAccent)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 0.94, green: 0.92, blue: 0.88))
                            )

                            // Gesture list — tap to edit, draw samples, or change the site
                            VStack(spacing: 0) {
                                ForEach(gestureShortcuts) { shortcut in
                                    Button {
                                        editingGesture = EditingGesture(gesture: shortcut, isNew: false)
                                    } label: {
                                        HStack(spacing: 12) {
                                            GestureThumbnail(points: shortcut.samples.first ?? [])
                                                .frame(width: 26, height: 26)
                                                .frame(width: 28)

                                            Text(shortcut.name)
                                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color.darkText)

                                            Spacer()

                                            Text(shortcut.label)
                                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                                .foregroundStyle(Color.darkText.opacity(0.6))

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Color.darkText.opacity(0.3))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)

                                    Divider()
                                        .padding(.leading, 56)
                                }

                                Button {
                                    let blank = GestureShortcut(id: UUID().uuidString, name: "", label: "",
                                                                url: URL(string: "https://example.com")!, samples: [])
                                    editingGesture = EditingGesture(gesture: blank, isNew: true)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .semibold))
                                            .frame(width: 28)
                                        Text("Add Gesture")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                        Spacer()
                                    }
                                    .foregroundStyle(Color.tealAccent)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 0.94, green: 0.92, blue: 0.88))
                            )

                            // Share gesture sets as JSON
                            HStack(spacing: 20) {
                                if let exportURL = GestureStore.exportFile(gestureShortcuts) {
                                    ShareLink(item: exportURL) {
                                        Label("Export", systemImage: "square.and.arrow.up")
                                    }
                                }
                                Button {
                                    isImportingGestures = true
                                } label: {
                                    Label("Import", systemImage: "square.and.arrow.down")
                                }
                                Spacer()
                            }
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.tealAccent)
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.25), value: gestureShortcutsEnabled)

                }
                .padding(.top, 24)
                .padding(.bottom, 32)
                }
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
            .sheet(item: $editingGesture) { editing in
                GestureEditorView(
                    gesture: editing.gesture,
                    isNew: editing.isNew,
                    otherGestures: gestureShortcuts.filter { $0.id != editing.gesture.id },
                    onSave: { saved in
                        if let i = gestureShortcuts.firstIndex(where: { $0.id == saved.id }) {
                            gestureShortcuts[i] = saved
                        } else {
                            gestureShortcuts.append(saved)
                        }
                        GestureStore.save(gestureShortcuts)
                    },
                    onDelete: editing.isNew ? nil : {
                        gestureShortcuts.removeAll { $0.id == editing.gesture.id }
                        GestureStore.save(gestureShortcuts)
                    }
                )
            }
            .fileImporter(isPresented: $isImportingGestures, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), let imported = GestureStore.decode(data) {
                    gestureShortcuts = GestureStore.merge(imported, into: gestureShortcuts)
                    GestureStore.save(gestureShortcuts)
                    gestureImportMessage = "Imported \(imported.count) gesture\(imported.count == 1 ? "" : "s")."
                } else {
                    gestureImportMessage = "That file isn't a valid gesture set."
                }
            }
            .alert(
                gestureImportMessage ?? "",
                isPresented: Binding(
                    get: { gestureImportMessage != nil },
                    set: { if !$0 { gestureImportMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func setAppIcon(_ icon: AppIconOption) {
        guard currentIcon != icon else { return }
        UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
            if error == nil {
                currentIcon = icon
            }
        }
    }
}

#Preview {
    ContentView()
}
