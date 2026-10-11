import SwiftUI

struct CaptureView: View {
    @Environment(SetlogStore.self) private var store
    let camera: CameraService

    @State private var note = ""
    @State private var selectedRooms: Set<String> = []
    @State private var saving = false
    @State private var toast: String?
    @State private var errorMessage: String?
    @FocusState private var noteFocused: Bool

    private static let noteLimit = 40

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let taken = store.clip(at: now)
            VStack(spacing: 12) {
                slotRow(now: now)
                roomChips
                viewfinder(now: now, taken: taken)
                noteField(disabled: taken != nil)
                controls(taken: taken)
                caption(taken: taken)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .onAppear {
            camera.start()
            if selectedRooms.isEmpty { selectedRooms = [store.selectedRoomID] }
        }
        .onDisappear { camera.stop() }
        .alert("Couldn't save take", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Rows

    private func slotRow(now: Date) -> some View {
        HStack(spacing: 8) {
            Chip(text: "\(Fmt.hour(Calendar.current.component(.hour, from: now))) SLOT", dot: true, size: 13)
            Chip(text: "ONE TAKE ONLY", icon: "bolt", style: .soft, size: 13)
            Spacer(minLength: 0)
            Label("2.0s LIMIT", systemImage: "lock")
                .font(.grotesk(13, .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
    }

    private var roomChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Room.all) { room in
                    let selected = selectedRooms.contains(room.id)
                    Button {
                        if selected { selectedRooms.remove(room.id) } else { selectedRooms.insert(room.id) }
                    } label: {
                        HStack(spacing: 5) {
                            Text(room.name)
                            if selected { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                        }
                        .font(.grotesk(14, .semibold))
                        .foregroundStyle(selected ? .white : Theme.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(selected ? Theme.rose : .white, in: Capsule())
                        .overlay(Capsule().stroke(Theme.outline))
                    }
                    .buttonStyle(.plain)
                    .disabled(camera.isRecording)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func viewfinder(now: Date, taken: Clip?) -> some View {
        ZStack {
            switch camera.status {
            case .ready:
                CameraPreviewView(previewLayer: camera.previewLayer)
            case .denied:
                deniedPlaceholder
            case .simulated, .idle:
                SimulatedFinder(landscape: camera.orientation == .landscape)
            }

            if camera.status == .ready {
                Circle().stroke(.white.opacity(0.7), lineWidth: 1).frame(width: 64, height: 64)
                Circle().fill(.white.opacity(0.8)).frame(width: 5, height: 5)
            }

            if let taken {
                lockedOverlay(taken: taken, now: now)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .top) {
            if camera.isRecording {
                GeometryReader { geo in
                    Capsule().fill(Theme.rose)
                        .frame(width: geo.size.width * camera.progress, height: 4)
                }
                .frame(height: 4)
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
        }
        .overlay(alignment: .topLeading) {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                HStack(spacing: 6) {
                    Circle().fill(camera.isRecording ? Color.red.opacity(0.8) : Theme.rose).frame(width: 8, height: 8)
                    Text("\(Fmt.hms.string(from: ctx.date)) \(Fmt.zone)").monospacedDigit()
                }
                .font(.grotesk(14, .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(.white.opacity(0.9), in: Capsule())
            }
            .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: camera.toggleSimulatedOrientation) {
                Label(camera.orientation == .portrait ? "PORTRAIT" : "LANDSCAPE",
                      systemImage: camera.orientation == .portrait ? "iphone" : "iphone.landscape")
                    .font(.grotesk(13, .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(.white.opacity(0.9), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .overlay(alignment: .bottomLeading) {
            Chip(text: "2.0s · HD", icon: "video", style: .glass, size: 12).padding(14)
        }
        .overlay(alignment: .bottomTrailing) {
            Chip(text: "1× · \(camera.position == .front ? "FRONT" : "BACK")", style: .glass, size: 12).padding(14)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Label(toast, systemImage: "paperplane.fill")
                    .font(.grotesk(13, .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().stroke(Theme.outline))
                    .padding(.bottom, 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(3)
        .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous).stroke(Theme.outline, lineWidth: 2))
    }

    private var deniedPlaceholder: some View {
        ZStack {
            Theme.well
            VStack(spacing: 10) {
                Image(systemName: "video.slash").font(.system(size: 32)).foregroundStyle(Theme.roseDeep)
                Text("Camera access is off").font(.grotesk(16, .semibold)).foregroundStyle(Theme.ink)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private func lockedOverlay(taken: Clip, now: Date) -> some View {
        let minutesLeft = 60 - Calendar.current.component(.minute, from: now)
        return ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Theme.canvas.opacity(0.55)
            VStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.system(size: 26)).foregroundStyle(Theme.roseDeep)
                Text("\(Fmt.hour(taken.hour)) take is in")
                    .font(.grotesk(20, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("One take only, no retakes.\nThe next slot opens in \(minutesLeft)m.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.muted)
                Button {
                    store.reelDate = now
                    store.tab = .reel
                } label: {
                    Label("Today's Vlog", systemImage: "play.fill").padding(.horizontal, 16)
                }
                .buttonStyle(GhostButtonStyle())
                .padding(.top, 4)
            }
            .padding()
        }
    }

    private func noteField(disabled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "text.badge.plus").foregroundStyle(Theme.rose)
            TextField("Fleeting thought (optional)…", text: $note)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink)
                .focused($noteFocused)
                .submitLabel(.done)
                .onChange(of: note) { _, value in
                    if value.count > Self.noteLimit { note = String(value.prefix(Self.noteLimit)) }
                }
            Text("\(note.count)/\(Self.noteLimit)")
                .font(.grotesk(12, .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(.white, in: RoundedRectangle(cornerRadius: 23))
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(Theme.outline, lineWidth: noteFocused ? 2 : 1))
        .disabled(disabled || camera.isRecording)
        .opacity(disabled ? 0.5 : 1)
    }

    private func controls(taken: Clip?) -> some View {
        let canShoot = taken == nil && !selectedRooms.isEmpty && !saving && camera.status != .denied
        return HStack {
            roundControl(icon: camera.flashOn ? "bolt.fill" : "bolt.slash", label: camera.flashOn ? "ON" : "OFF") {
                camera.flashOn.toggle()
            }
            .disabled(camera.position == .front || camera.isRecording)

            Spacer()

            ZStack {
                Circle().stroke(Theme.border, lineWidth: 6).frame(width: 92, height: 92)
                Circle()
                    .trim(from: 0, to: camera.progress)
                    .stroke(Theme.roseDeep, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 92, height: 92)
                Circle().fill(Theme.rose).frame(width: 74, height: 74)
                    .scaleEffect(camera.isRecording ? 0.86 : 1)
                    .animation(.spring(duration: 0.25), value: camera.isRecording)
                if saving {
                    ProgressView().tint(.white)
                } else {
                    Circle().stroke(.white, lineWidth: 3).frame(width: 28, height: 28)
                }
            }
            .opacity(canShoot || camera.isRecording ? 1 : 0.45)
            .contentShape(Circle())
            // Fire on touch-down so "hold" and "tap" both start the full 2s take.
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in
                if canShoot { shoot() }
            })
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Record 2 second take")
            .accessibilityAction { if canShoot { shoot() } }

            Spacer()

            roundControl(icon: "arrow.triangle.2.circlepath.camera", label: "FLIP") { camera.flip() }
                .disabled(camera.isRecording)
        }
        .padding(.horizontal, 26)
    }

    private func roundControl(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 19, weight: .medium))
                Text(label).font(.grotesk(11, .semibold))
            }
            .foregroundStyle(Theme.ink)
            .frame(width: 62, height: 62)
            .background(.white, in: Circle())
            .overlay(Circle().stroke(Theme.outline))
        }
        .buttonStyle(.plain)
    }

    private func caption(taken: Clip?) -> some View {
        VStack(spacing: 3) {
            Text(headline(taken: taken))
                .font(.grotesk(14, .bold))
                .tracking(1)
                .foregroundStyle(Theme.ink)
            Text("No filters. No editing. Real life in 2 seconds.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
        }
    }

    private func headline(taken: Clip?) -> String {
        if camera.isRecording { return String(format: "RECORDING · %.1fs", camera.progress * CameraService.clipLength) }
        if saving { return "SENDING…" }
        if taken != nil { return "SLOT CAPTURED" }
        if selectedRooms.isEmpty { return "PICK A ROOM TO SEND TO" }
        return "HOLD OR TAP FOR 2.0S"
    }

    // MARK: Actions

    private func shoot() {
        guard !camera.isRecording else { return }
        noteFocused = false
        let startedAt = Date()
        let rooms = Room.all.map(\.id).filter(selectedRooms.contains)
        let orientation = camera.orientation
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        camera.record { result in
            switch result {
            case .failure(let error):
                errorMessage = error.localizedDescription
            case .success(let url):
                saving = true
                Task {
                    do {
                        try await store.addClip(
                            from: url,
                            recordedAt: startedAt,
                            note: note,
                            roomIDs: rooms,
                            orientation: orientation
                        )
                        note = ""
                        let names = rooms.compactMap { Room.with(id: $0)?.name }.joined(separator: ", ")
                        showToast("Sent to \(names)")
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    saving = false
                }
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toast = nil }
        }
    }
}

/// Stand-in viewfinder when there's no camera (Simulator).
private struct SimulatedFinder: View {
    let landscape: Bool

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xF9D8D2), Color(hex: 0xE2B4BD), Color(hex: 0xC9A39B)],
                    startPoint: UnitPoint(x: 0.5 + 0.5 * cos(t / 3), y: 0),
                    endPoint: UnitPoint(x: 0.5 - 0.5 * cos(t / 3), y: 1)
                )
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 34, weight: .light))
                        .rotationEffect(.degrees(landscape ? 90 : 0))
                    Text("Simulated camera")
                        .font(.grotesk(15, .semibold))
                    Text("Takes are rendered as real 2s clips.\nTap the orientation pill to switch.")
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
            }
        }
    }
}
