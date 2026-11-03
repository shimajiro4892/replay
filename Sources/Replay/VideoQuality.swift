import Foundation

/// A short description of a video's quality, such as `1080p60 · AV1`.
enum VideoQuality {
    static func label(width: Int?, height: Int?, frameRate: Double?, codec: String?) -> String? {
        var parts: [String] = []
        if let width, let height, width > 0, height > 0 {
            // Name portrait videos (Shorts) by their short side too.
            var resolution = "\(min(width, height))p"
            if let frameRate, frameRate >= 48 {
                resolution += "\(Int(frameRate.rounded()))"
            }
            parts.append(resolution)
        }
        if let codec = codecName(codec) {
            parts.append(codec)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Maps a yt-dlp `vcodec` (`avc1.640028`) or a FourCC (`avc1`) to a name.
    static func codecName(_ codec: String?) -> String? {
        guard let codec = codec?.lowercased(), !codec.isEmpty, codec != "none", codec != "na" else { return nil }
        if codec.hasPrefix("avc") || codec.hasPrefix("h264") { return "H.264" }
        if codec.hasPrefix("hvc") || codec.hasPrefix("hev") || codec.hasPrefix("h265") { return "HEVC" }
        if codec.hasPrefix("av01") || codec == "av1" { return "AV1" }
        if codec.hasPrefix("vp09") || codec.hasPrefix("vp9") { return "VP9" }
        if codec.hasPrefix("vp8") { return "VP8" }
        return nil
    }
}

#if canImport(AVFoundation)
import AVFoundation

extension VideoQuality {
    /// Reads the quality of a downloaded file from its first video track.
    static func probe(fileURL: URL) async -> String? {
        let asset = AVURLAsset(url: fileURL)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (size, transform, frameRate, descriptions) = try? await track.load(
                .naturalSize, .preferredTransform, .nominalFrameRate, .formatDescriptions
              ) else { return nil }
        let displayed = size.applying(transform)
        let codec = descriptions.first.map { fourCC(CMFormatDescriptionGetMediaSubType($0)) }
        return label(
            width: Int(abs(displayed.width).rounded()),
            height: Int(abs(displayed.height).rounded()),
            frameRate: Double(frameRate),
            codec: codec
        )
    }

    private static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}
#endif
