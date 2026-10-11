import AVFoundation
import Observation
import UIKit

/// Records exactly one fixed-length take at a time. There's no stop button and
/// no retake: once the shutter is pressed, the full 2 seconds are captured.
@Observable
final class CameraService: NSObject {
    enum Status { case idle, ready, denied, simulated }

    static let clipLength: Double = 2.0

    var status: Status = .idle
    var isRecording = false
    var progress: Double = 0
    var position: AVCaptureDevice.Position = .back
    var flashOn = false
    /// Follows how the phone is physically held, so takes can be portrait or landscape.
    var orientation: CaptureOrientation = .portrait

    let session = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer

    @ObservationIgnored private let movieOutput = AVCaptureMovieFileOutput()
    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "setlog.camera.session")
    @ObservationIgnored private var videoInput: AVCaptureDeviceInput?
    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored private var rotationObservations: [NSKeyValueObservation] = []
    @ObservationIgnored private var isConfigured = false
    @ObservationIgnored private var completion: ((Result<URL, Error>) -> Void)?
    @ObservationIgnored private var progressTimer: Timer?

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
    }

    // MARK: Lifecycle

    func start() {
        #if targetEnvironment(simulator)
        status = .simulated
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestMicrophoneThenConfigure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.requestMicrophoneThenConfigure() } else { self.status = .denied }
                }
            }
        default:
            status = .denied
        }
        #endif
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning, self.completion == nil { self.session.stopRunning() }
        }
    }

    private func requestMicrophoneThenConfigure() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            self.sessionQueue.async { self.configure() }
        }
    }

    private func configure() {
        if isConfigured {
            if !session.isRunning { session.startRunning() }
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .high
        if let device = Self.camera(for: position),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
           let mic = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        movieOutput.maxRecordedDuration = CMTime(seconds: Self.clipLength, preferredTimescale: 600)
        session.commitConfiguration()
        isConfigured = true
        session.startRunning()

        let device = videoInput?.device
        DispatchQueue.main.async {
            self.status = device == nil ? .simulated : .ready
            if let device { self.makeRotationCoordinator(for: device) }
        }
    }

    private static func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private func makeRotationCoordinator(for device: AVCaptureDevice) {
        rotationObservations.removeAll()
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        previewLayer.connection?.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        rotationObservations = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] c, _ in
                let angle = c.videoRotationAngleForHorizonLevelPreview
                DispatchQueue.main.async { self?.previewLayer.connection?.videoRotationAngle = angle }
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] c, _ in
                let angle = c.videoRotationAngleForHorizonLevelCapture
                DispatchQueue.main.async {
                    self?.orientation = (angle == 90 || angle == 270) ? .portrait : .landscape
                }
            },
        ]
    }

    // MARK: Controls

    func flip() {
        guard !isRecording else { return }
        let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        if newPosition == .front { flashOn = false }
        guard status == .ready else {
            position = newPosition
            return
        }
        sessionQueue.async {
            guard let device = Self.camera(for: newPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            self.session.beginConfiguration()
            let old = self.videoInput
            if let old { self.session.removeInput(old) }
            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.videoInput = input
            } else if let old {
                self.session.addInput(old)
            }
            self.session.commitConfiguration()
            let current = self.videoInput?.device
            DispatchQueue.main.async {
                if let current {
                    self.position = current.position
                    self.makeRotationCoordinator(for: current)
                }
            }
        }
    }

    /// The simulator has no orientation-aware camera, so the pill toggles it by hand.
    func toggleSimulatedOrientation() {
        guard status == .simulated, !isRecording else { return }
        orientation = orientation == .portrait ? .landscape : .portrait
    }

    // MARK: Recording

    func record(completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isRecording, status == .ready || status == .simulated else { return }
        isRecording = true
        progress = 0
        self.completion = completion
        startProgress()

        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")

        if status == .simulated {
            let landscape = orientation == .landscape
            let lens = position == .front ? "front" : "back"
            let started = Date()
            Task {
                do {
                    try await SimulatedClipWriter.write(
                        to: url,
                        title: Fmt.hm.string(from: started),
                        subtitle: "Simulator · \(lens) camera",
                        palette: SimulatedClipWriter.palettes.randomElement() ?? SimulatedClipWriter.palettes[0],
                        landscape: landscape
                    )
                    let remaining = Self.clipLength - Date().timeIntervalSince(started)
                    if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
                    self.finish(.success(url))
                } catch {
                    self.finish(.failure(error))
                }
            }
            return
        }

        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90
        let mirrored = position == .front
        let torch = flashOn && position == .back
        sessionQueue.async {
            if let connection = self.movieOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = mirrored
                }
            }
            self.setTorch(torch)
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    private func startProgress() {
        let start = Date()
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.progress = min(1, Date().timeIntervalSince(start) / Self.clipLength)
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        DispatchQueue.main.async {
            self.progressTimer?.invalidate()
            self.progressTimer = nil
            self.progress = 0
            self.isRecording = false
            let completion = self.completion
            self.completion = nil
            completion?(result)
        }
    }

    private func setTorch(_ on: Bool) {
        guard let device = videoInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        sessionQueue.async { self.setTorch(false) }
        // Hitting maxRecordedDuration reports an "error" even though the take is complete.
        if let error, ((error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) != true {
            finish(.failure(error))
        } else {
            finish(.success(outputFileURL))
        }
    }
}
