import AVFoundation
import Observation
import SwiftUI

/// Plays a day's takes back-to-back, looping, and tracks which one is on screen.
@MainActor @Observable
final class ReelPlayer {
    struct Item: Equatable {
        let clip: Clip
        let url: URL
    }

    let player = AVPlayer()
    private(set) var items: [Item] = []
    private(set) var index = 0
    private(set) var progress: Double = 0
    private(set) var isPlaying = false
    var isMuted = false {
        didSet { player.isMuted = isMuted }
    }

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    var current: Item? { items.indices.contains(index) ? items[index] : nil }

    init() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, let duration = self.player.currentItem?.duration.seconds,
                      duration.isFinite, duration > 0 else { return }
                self.progress = min(1, time.seconds / duration)
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] note in
            let item = note.object as? AVPlayerItem
            MainActor.assumeIsolated {
                guard let self, item === self.player.currentItem else { return }
                self.play(at: (self.index + 1) % max(1, self.items.count))
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func load(_ newItems: [Item]) {
        guard newItems != items else { return }
        items = newItems
        if newItems.isEmpty {
            player.replaceCurrentItem(with: nil)
            isPlaying = false
        } else {
            play(at: 0)
        }
    }

    func play(at i: Int) {
        guard items.indices.contains(i) else { return }
        index = i
        progress = 0
        player.replaceCurrentItem(with: AVPlayerItem(url: items[i].url))
        player.play()
        isPlaying = true
    }

    func togglePlay() {
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    func pause() {
        player.pause()
        isPlaying = false
    }
}

struct ReelView: View {
    @Environment(SetlogStore.self) private var store
    @State private var reel = ReelPlayer()
    @State private var flash: String?
    @State private var busy = false
    @State private var shareItem: ShareItem?
    @State private var errorMessage: String?

    var body: some View {
        let clips = store.clips(on: store.reelDate)
        ScrollView {
            VStack(spacing: 14) {
                dayPicker
                if clips.isEmpty {
                    emptyState
                } else {
                    stage(clips: clips)
                    presence(clips: clips)
                    chapters(clips: clips)
                    actions
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .task(id: clips.map(\.id)) {
            reel.load(clips.map { ReelPlayer.Item(clip: $0, url: store.fileURL(for: $0)) })
        }
        .onDisappear { reel.pause() }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url).presentationDetents([.medium, .large]) }
        .alert("Vlog", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Sections

    private var dayPicker: some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(store.reelDate)
        return HStack {
            Button { shiftDay(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 1) {
                Text(isToday ? "Today" : Fmt.monthDay.string(from: store.reelDate))
                    .font(.grotesk(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(Fmt.weekday.string(from: store.reelDate))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { shiftDay(1) } label: { Image(systemName: "chevron.right") }
                .disabled(isToday)
                .opacity(isToday ? 0.3 : 1)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Theme.muted)
        .setlogCard(padding: 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "movieclapper").font(.system(size: 34, weight: .light)).foregroundStyle(Theme.rose)
            Text("No takes on this day").font(.grotesk(17, .semibold)).foregroundStyle(Theme.ink)
            Text("Each hour you log adds two seconds to the day's vlog.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            if Calendar.current.isDateInToday(store.reelDate) {
                Button { store.tab = .take } label: { Label("Log a 2s Take", systemImage: "video.fill") }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 30)
        .setlogCard()
    }

    private func stage(clips: [Clip]) -> some View {
        let total = Int(clips.reduce(0) { $0 + $1.duration }.rounded())
        let current = reel.current?.clip
        return ZStack {
            Theme.night
            PlayerSurface(player: reel.player, gravity: current?.orientation == .landscape ? .resizeAspect : .resizeAspectFill)

            LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    reel.togglePlay()
                    showFlash(reel.isPlaying ? "pause.fill" : "play.fill")
                }

            if let flash {
                Image(systemName: flash)
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 64, height: 64)
                    .background(.white.opacity(0.9), in: Circle())
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.outline))
        .overlay(alignment: .top) {
            VStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { i, _ in
                        GeometryReader { geo in
                            Capsule().fill(.white.opacity(0.35))
                            Capsule().fill(.white)
                                .frame(width: geo.size.width * (i < reel.index ? 1 : i == reel.index ? reel.progress : 0))
                        }
                        .frame(height: 3)
                    }
                }
                HStack {
                    Chip(text: "My Vlog (\(total)s)", dot: true, style: .glass, size: 12)
                    Spacer()
                    Button { reel.isMuted.toggle() } label: {
                        Image(systemName: reel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.9), in: Circle())
                    }
                }
            }
            .padding(14)
        }
        .overlay(alignment: .bottomLeading) {
            if let current {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Fmt.hm.string(from: current.recordedAt)) \(Fmt.zone) · Take \(String(format: "%02d/%02d", reel.index + 1, clips.count))")
                        .font(.grotesk(12, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                    Text(current.note.isEmpty ? "\(Fmt.hour(current.hour)) hour" : current.note)
                        .font(.grotesk(22, .semibold))
                        .foregroundStyle(.white)
                    Text("You · 2s clip · \(current.orientation == .landscape ? "landscape" : "portrait")")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
                .allowsHitTesting(false)
            }
        }
    }

    private func presence(clips: [Clip]) -> some View {
        let roomIDs = Set(clips.flatMap(\.roomIDs))
        let rooms = Room.all.filter { roomIDs.contains($0.id) }
        let members = Array(Set(rooms.flatMap(\.members))).sorted { $0.name < $1.name }
        return HStack {
            HStack(spacing: -7) {
                ForEach(members.prefix(4)) { AvatarView(friend: $0, size: 26) }
            }
            Text(rooms.isEmpty ? "Only you" : "Shared with \(rooms.map(\.name).joined(separator: ", "))")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Spacer()
            Text("\(clips.count) takes · 0 retakes")
                .font(.grotesk(11, .semibold))
                .foregroundStyle(Theme.roseDeep)
        }
        .padding(.horizontal, 4)
    }

    private func chapters(clips: [Clip]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DAILY CHAPTERS").font(.grotesk(11, .semibold)).tracking(1).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(reel.index + 1) of \(clips.count) clips").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(clips.enumerated()), id: \.element.id) { i, clip in
                            chapter(clip: clip, active: i == reel.index)
                                .id(clip.id)
                                .onTapGesture { reel.play(at: i) }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: reel.index) { _, i in
                    guard clips.indices.contains(i) else { return }
                    withAnimation { proxy.scrollTo(clips[i].id, anchor: .center) }
                }
            }
        }
        .setlogCard(padding: 14)
    }

    private func chapter(clip: Clip, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ClipThumbnail(url: store.fileURL(for: clip))
                .frame(width: 92, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.outline, lineWidth: active ? 3 : 1))
                .overlay(alignment: .topLeading) {
                    if active {
                        Text("NOW")
                            .font(.grotesk(9, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.roseDeep, in: Capsule())
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(Fmt.hour(clip.hour))
                        .font(.grotesk(10, .semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.9), in: Capsule())
                        .padding(6)
                }
            Text(clip.note.isEmpty ? "Untitled" : clip.note)
                .font(.system(size: 11))
                .foregroundStyle(active ? Theme.ink : Theme.muted)
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                run {
                    let url = try await store.exportReel(for: store.reelDate)
                    try await PhotoSaver.saveVideo(at: url)
                    showFlash("checkmark")
                }
            } label: {
                if busy {
                    ProgressView()
                } else {
                    Label("Save Day Vlog", systemImage: "arrow.down.to.line")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                run { shareItem = ShareItem(url: try await store.exportReel(for: store.reelDate)) }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up").padding(.horizontal, 14)
            }
            .buttonStyle(GhostButtonStyle())
        }
        .disabled(busy)
    }

    // MARK: Helpers

    private func shiftDay(_ delta: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: delta, to: store.reelDate),
              date <= .now else { return }
        store.reelDate = date
    }

    private func showFlash(_ symbol: String) {
        withAnimation(.spring(duration: 0.2)) { flash = symbol }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation { flash = nil }
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        Task {
            do { try await work() } catch { errorMessage = error.localizedDescription }
            busy = false
        }
    }
}
