import AVFoundation
import Photos
import UIKit

/// Stitches a day's takes into a single 9:16 reel. Portrait takes fill the
/// frame; landscape takes are letterboxed on the blush canvas.
enum ReelComposer {
    static let renderSize = CGSize(width: 1080, height: 1920)

    static func export(urls: [URL], to output: URL) async throws {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw SetlogError.exportFailed
        }
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let background = UIColor(hex: 0xFFF5F5).cgColor

        var instructions: [AVMutableVideoCompositionInstruction] = []
        var cursor = CMTime.zero

        for url in urls {
            let asset = AVURLAsset(url: url)
            guard let source = try await asset.loadTracks(withMediaType: .video).first else { continue }
            let range = try await source.load(.timeRange)
            let segment = CMTimeRange(start: range.start, duration: range.duration)
            try videoTrack.insertTimeRange(segment, of: source, at: cursor)
            if let audio = try await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack?.insertTimeRange(segment, of: audio, at: cursor)
            }

            let (naturalSize, transform) = try await source.load(.naturalSize, .preferredTransform)
            let oriented = CGRect(origin: .zero, size: naturalSize).applying(transform)
            let isPortrait = oriented.height >= oriented.width
            let scaleX = renderSize.width / oriented.width
            let scaleY = renderSize.height / oriented.height
            let scale = isPortrait ? max(scaleX, scaleY) : min(scaleX, scaleY)
            let placed = CGSize(width: oriented.width * scale, height: oriented.height * scale)

            let layerTransform = transform
                .concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(
                    translationX: (renderSize.width - placed.width) / 2,
                    y: (renderSize.height - placed.height) / 2
                ))

            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layer.setTransform(layerTransform, at: cursor)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, duration: range.duration)
            instruction.layerInstructions = [layer]
            instruction.backgroundColor = background
            instructions.append(instruction)

            cursor = cursor + range.duration
        }
        guard !instructions.isEmpty else { throw SetlogError.noClips }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = instructions

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw SetlogError.exportFailed
        }
        session.videoComposition = videoComposition
        try? FileManager.default.removeItem(at: output)
        try await session.export(to: output, as: .mp4)
    }
}

enum PhotoSaver {
    static func saveVideo(at url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SetlogError.photosDenied }
        try await PHPhotoLibrary.shared().performChanges {
            _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}

actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var images: [URL: UIImage] = [:]

    func image(for url: URL) async -> UIImage? {
        if let cached = images[url] { return cached }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        guard let cgImage = try? await generator.image(at: CMTime(seconds: 0.6, preferredTimescale: 600)).image else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        images[url] = image
        return image
    }
}
