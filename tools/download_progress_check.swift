import Foundation

@main
struct DownloadProgressCheck {
    static func main() {
        // Line parsing, including yt-dlp's placeholders for unknown values.
        let line = DownloadProgressLine.parse("WL_PROGRESS\t 42.5%\t 1.20MiB/s\t00:12\t399")
        precondition(line == DownloadProgressLine(fraction: 0.425, speed: "1.20MiB/s", eta: "00:12", formatID: "399"))
        let unknown = DownloadProgressLine.parse("WL_PROGRESS\t  0.2%\t Unknown B/s\tUnknown\tNA")
        precondition(unknown == DownloadProgressLine(fraction: 0.002, speed: "", eta: "", formatID: nil))
        precondition(DownloadProgressLine.parse("WL_META\t\"title\"") == nil)

        // A merged video+audio download must not jump back to 0 when the
        // audio part starts, and its parts are weighted by size.
        var merged = DownloadProgressTracker()
        merged.begin(formatID: "399+140", sizes: [900, 100])
        precondition(merged.update(with: progress(0.5, "399")) == 0.45)
        precondition(merged.update(with: progress(1.0, "399")) == 0.9)
        precondition(merged.update(with: progress(0.0, "140")) == 0.9)
        precondition(merged.update(with: progress(0.5, "140")) == 0.95)
        precondition(merged.update(with: progress(1.0, "140")) == 1.0)

        // Side downloads such as subtitles are ignored once formats are known.
        precondition(merged.update(with: progress(0.3, nil)) == nil)
        precondition(merged.update(with: progress(0.3, "999")) == nil)

        // A resumed download that skips the finished video part counts it as done.
        var resumed = DownloadProgressTracker()
        resumed.begin(formatID: "399+140", sizes: [900, 100])
        precondition(resumed.update(with: progress(0.5, "140")) == 0.95)

        // Unknown sizes fall back to equal weights.
        var unsized = DownloadProgressTracker()
        unsized.begin(formatID: "399+140", sizes: [nil, 100])
        precondition(unsized.update(with: progress(1.0, "399")) == 0.5)

        // A single format reports its own value but never moves backwards.
        var single = DownloadProgressTracker()
        single.begin(formatID: "18", sizes: [])
        precondition(single.update(with: progress(0.6, "18")) == 0.6)
        precondition(single.update(with: progress(0.4, "18")) == 0.6)

        // Without an announced format list, yt-dlp's value is used as is,
        // but subtitle downloads (no format_id) still never reach the bar.
        var unannounced = DownloadProgressTracker()
        precondition(unannounced.update(with: progress(0.3, nil)) == nil)
        precondition(unannounced.update(with: progress(0.3, "18")) == 0.3)

        precondition(DownloadProgressTracker.label(fraction: 0.4567, speed: "2MiB/s", eta: "00:05") == "45.7% · 2MiB/s · ETA 00:05")
        precondition(DownloadProgressTracker.label(fraction: 1, speed: "", eta: "") == "100.0%")

        print("download_progress_check=passed")
    }

    private static func progress(_ fraction: Double, _ formatID: String?) -> DownloadProgressLine {
        DownloadProgressLine(fraction: fraction, speed: "", eta: "", formatID: formatID)
    }
}
