import Foundation

@main
struct VideoQualityCheck {
    static func main() {
        precondition(VideoQuality.label(width: 1920, height: 1080, frameRate: 30, codec: "avc1.640028") == "1080p · H.264")
        precondition(VideoQuality.label(width: 1920, height: 1080, frameRate: 59.94, codec: "av01.0.08M.08") == "1080p60 · AV1")
        // Portrait videos are named by their short side.
        precondition(VideoQuality.label(width: 1080, height: 1920, frameRate: 30, codec: "vp09.00.40.08") == "1080p · VP9")
        precondition(VideoQuality.label(width: 1280, height: 720, frameRate: nil, codec: "hvc1") == "720p · HEVC")
        precondition(VideoQuality.label(width: 640, height: 360, frameRate: 25, codec: "none") == "360p")
        precondition(VideoQuality.label(width: nil, height: nil, frameRate: nil, codec: "avc1") == "H.264")
        precondition(VideoQuality.label(width: nil, height: nil, frameRate: nil, codec: nil) == nil)
        print("video_quality_check=passed")
    }
}
