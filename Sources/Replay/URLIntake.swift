import Foundation

enum URLIntake {
    /// Clipboard prompting is intentionally conservative. Replay can accept
    /// any HTTP(S) URL manually (yt-dlp supports many sites), but foreground
    /// clipboard detection should only interrupt for services the app treats
    /// as first-class video sources.
    static func foregroundVideoURL(from rawValue: String) -> URL? {
        webURLs(from: rawValue).first(where: isForegroundVideoService)
    }

    static func isForegroundVideoService(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "youtu.be"
            || host == "youtube.com"
            || host.hasSuffix(".youtube.com")
            || host == "x.com"
            || host.hasSuffix(".x.com")
            || host == "twitter.com"
            || host.hasSuffix(".twitter.com")
    }

    static func resolve(_ incomingURL: URL) -> URL? {
        if isWebURL(incomingURL) { return incomingURL }
        guard incomingURL.isFileURL else { return nil }

        let suffix = incomingURL.pathExtension.lowercased()
        if suffix == "webloc", let data = try? Data(contentsOf: incomingURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dictionary = plist as? [String: Any],
           let value = dictionary["URL"] as? String,
           let url = URL(string: value), isWebURL(url) {
            return url
        }

        if suffix == "url", let text = try? String(contentsOf: incomingURL, encoding: .utf8),
           let line = text.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("URL=") }),
           let url = URL(string: String(line.dropFirst(4))), isWebURL(url) {
            return url
        }

        if let text = try? String(contentsOf: incomingURL, encoding: .utf8),
           let url = webURL(from: text) {
            return url
        }
        return nil
    }

    static func webURL(from rawValue: String) -> URL? {
        webURLs(from: rawValue).first
    }

    static func webURLs(from rawValue: String) -> [URL] {
        let fullRange = NSRange(rawValue.startIndex..<rawValue.endIndex, in: rawValue)
        guard fullRange.length > 0,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let text = rawValue as NSString
        var matches: [(location: Int, url: URL)] = []
        detector.enumerateMatches(in: rawValue, options: [], range: fullRange) { result, _, _ in
            guard let result,
                  let detectedURL = result.url,
                  isWebURL(detectedURL) else { return }
            let matchedText = text.substring(with: result.range)
            let url = hasExplicitScheme(matchedText) ? detectedURL : withHTTPSScheme(detectedURL)
            matches.append((result.range.location, url))
        }

        var seen: Set<String> = []
        return matches.sorted { $0.location < $1.location }.compactMap { match in
            let canonical = canonicalString(for: match.url)
            guard seen.insert(canonical).inserted else { return nil }
            return URL(string: canonical) ?? match.url
        }
    }

    static func canonicalString(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.fragment = nil
        let host = components.host?.lowercased() ?? ""

        if host == "youtu.be" {
            let videoID = components.path.split(separator: "/").first.map(String.init) ?? ""
            return "https://www.youtube.com/watch?v=\(videoID)"
        }
        if host.hasSuffix("youtube.com") {
            let queryID = components.queryItems?.first(where: { $0.name == "v" })?.value
            let pathParts = components.path.split(separator: "/").map(String.init)
            let shortsID = pathParts.first == "shorts" && pathParts.count > 1 ? pathParts[1] : nil
            if let videoID = queryID ?? shortsID {
                return "https://www.youtube.com/watch?v=\(videoID)"
            }
        }

        if host == "twitter.com" || host.hasSuffix(".twitter.com") {
            components.host = "x.com"
        }
        let parts = components.path.split(separator: "/").map(String.init)
        if let statusIndex = parts.firstIndex(of: "status"), statusIndex > 0, parts.count > statusIndex + 1 {
            return "https://x.com/\(parts[statusIndex - 1])/status/\(parts[statusIndex + 1])"
        }
        return components.url?.absoluteString ?? url.absoluteString
    }

    static func youtubeVideoID(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let host = components.host?.lowercased() ?? ""
        if host == "youtu.be" {
            return components.path.split(separator: "/").first.map(String.init)
        }
        guard host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
        if let queryID = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !queryID.isEmpty {
            return queryID
        }
        let pathParts = components.path.split(separator: "/").map(String.init)
        guard pathParts.count > 1,
              ["shorts", "embed", "live"].contains(pathParts[0]),
              !pathParts[1].isEmpty else { return nil }
        return pathParts[1]
    }

    /// NSDataDetector fills in a scheme for bare links such as
    /// `www.example.com`, but the scheme it picks differs between macOS
    /// releases (`http` on macOS 26, `https` on macOS 27). Bare links are
    /// normalized to HTTPS so extraction is the same on every system.
    private static func hasExplicitScheme(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }

    private static func withHTTPSScheme(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.scheme = "https"
        return components.url ?? url
    }

    private static func isWebURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http"
    }
}
