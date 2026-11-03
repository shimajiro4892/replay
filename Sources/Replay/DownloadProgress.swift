import Foundation

/// One `WL_PROGRESS` line printed by yt-dlp's `--progress-template`.
struct DownloadProgressLine: Equatable {
    let fraction: Double
    let speed: String
    let eta: String
    let formatID: String?

    /// Parses `WL_PROGRESS\t<percent>\t<speed>\t<eta>\t<format_id>`.
    static func parse(_ line: String) -> DownloadProgressLine? {
        guard line.hasPrefix("WL_PROGRESS\t") else { return nil }
        let fields = line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
        let numeric = (fields.count > 1 ? fields[1] : "").replacingOccurrences(of: "%", with: "")
        let fraction = min(max((Double(numeric) ?? 0) / 100, 0), 1)
        return DownloadProgressLine(
            fraction: fraction,
            speed: fields.count > 2 ? meaningful(fields[2]) : "",
            eta: fields.count > 3 ? meaningful(fields[3]) : "",
            formatID: fields.count > 4 && !meaningful(fields[4]).isEmpty ? fields[4] : nil
        )
    }

    private static func meaningful(_ value: String) -> String {
        value == "NA" || value.hasPrefix("Unknown") ? "" : value
    }
}

/// Combines the per-format progress that yt-dlp reports into one overall
/// fraction. A merged download such as `bv*+ba` fetches the video and the
/// audio one after the other, and yt-dlp restarts its percentage at 0 for
/// each, so the raw value would jump backwards halfway through.
struct DownloadProgressTracker {
    private(set) var formatIDs: [String] = []
    /// Quality of the format being downloaded, shown before the percentage.
    private(set) var quality: String?
    private var weights: [Double] = []
    private var fractions: [String: Double] = [:]
    private var reported: Double = 0

    /// - Parameters:
    ///   - formatID: yt-dlp's selected `format_id`, for example `"399+140"`.
    ///   - sizes: expected byte sizes of each requested format, in order.
    ///     Formats are weighted by size when every size is known and equally
    ///     otherwise.
    mutating func begin(formatID: String?, sizes: [Double?], quality: String? = nil) {
        self.quality = quality
        let ids = (formatID ?? "")
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        formatIDs = ids
        let knownSizes = sizes.compactMap { $0 }.filter { $0 > 0 }
        if ids.count > 1, sizes.count == ids.count, knownSizes.count == ids.count {
            weights = knownSizes
        } else {
            weights = Array(repeating: 1, count: ids.count)
        }
        fractions = [:]
        reported = 0
    }

    /// Returns the overall fraction to show, or `nil` when the line belongs to
    /// a side download (subtitles, thumbnails) rather than the media itself.
    mutating func update(with line: DownloadProgressLine) -> Double? {
        // yt-dlp assigns a format_id to every media format. Subtitle and
        // thumbnail downloads report `NA`, and they run before `before_dl`
        // announces the formats, so they would otherwise flash 0–100%.
        guard let formatID = line.formatID else { return nil }
        guard !formatIDs.isEmpty else {
            // No format list was announced; fall back to yt-dlp's own value.
            return line.fraction
        }
        guard let index = formatIDs.firstIndex(of: formatID) else { return nil }
        // yt-dlp downloads the requested formats in order, so every earlier
        // format has finished once a later one reports progress.
        for earlier in formatIDs[..<index] {
            fractions[earlier] = 1
        }
        fractions[formatID] = max(fractions[formatID] ?? 0, line.fraction)

        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return reported }
        let completedWeight = zip(formatIDs, weights)
            .reduce(0) { $0 + $1.1 * (fractions[$1.0] ?? 0) }
        reported = max(reported, min(completedWeight / totalWeight, 1))
        return reported
    }

    func label(fraction: Double, speed: String, eta: String) -> String {
        Self.label(fraction: fraction, speed: speed, eta: eta, quality: quality)
    }

    static func label(fraction: Double, speed: String, eta: String, quality: String? = nil) -> String {
        let percent = String(format: "%.1f%%", fraction * 100)
        return [quality ?? "", percent, speed, eta.isEmpty ? "" : "ETA \(eta)"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
