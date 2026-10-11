import AVFoundation
import SwiftUI
import UIKit

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    fileprivate var looper: AVPlayerLooper?
    fileprivate var loopURL: URL?
}

/// Hosts an `AVPlayer` the caller controls.
struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        view.playerLayer.videoGravity = gravity
    }
}

/// A muted, endlessly looping clip, for feed cards.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspectFill
        configure(view)
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        if view.loopURL != url { configure(view) }
    }

    static func dismantleUIView(_ view: PlayerUIView, coordinator: ()) {
        view.playerLayer.player?.pause()
        view.looper = nil
    }

    private func configure(_ view: PlayerUIView) {
        let player = AVQueuePlayer()
        player.isMuted = true
        view.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        view.loopURL = url
        view.playerLayer.player = player
        player.play()
    }
}

final class PreviewHostView: UIView {
    var hosted: AVCaptureVideoPreviewLayer? {
        didSet {
            if let hosted { layer.addSublayer(hosted) }
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hosted?.frame = bounds
        CATransaction.commit()
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.hosted = previewLayer
        return view
    }

    func updateUIView(_ view: PreviewHostView, context: Context) {}
}

struct ClipThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Theme.well
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .task(id: url) { image = await ThumbnailCache.shared.image(for: url) }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
