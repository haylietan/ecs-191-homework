import SwiftUI

struct RootView: View {
    @Environment(SetlogStore.self) private var store
    @State private var camera = CameraService()

    var body: some View {
        VStack(spacing: 0) {
            SetlogHeader()
            Group {
                switch store.tab {
                case .dial: DialView()
                case .take: CaptureView(camera: camera)
                case .reel: ReelView()
                case .archive: ArchiveView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.page)
            SetlogTabBar()
        }
        .background(Theme.canvas.ignoresSafeArea())
        #if DEBUG
        .task { await applyLaunchArguments() }
        #endif
    }

    #if DEBUG
    /// Simulator conveniences: `-SetlogSeed YES` fills the archive, `-SetlogTab reel` opens a tab.
    private func applyLaunchArguments() async {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "SetlogTab") {
        case "take": store.tab = .take
        case "dial": store.tab = .dial
        case "archive": store.tab = .archive
        default: break
        }
        if defaults.bool(forKey: "SetlogSeed") { await store.seedDemoDays() }
    }
    #endif
}

struct SetlogHeader: View {
    @Environment(SetlogStore.self) private var store

    var body: some View {
        @Bindable var store = store
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(Theme.rose).frame(width: 9, height: 9)
                Text("SETLOG")
                    .font(.grotesk(18, .bold))
                    .fixedSize()
                    .foregroundStyle(Theme.ink)
                if store.isSeeding {
                    ProgressView().controlSize(.mini)
                }
            }
            #if DEBUG
            .onLongPressGesture { Task { await store.seedDemoDays() } }
            #endif

            Menu {
                Picker("Room", selection: $store.selectedRoomID) {
                    ForEach(Room.all) { room in
                        Text("\(room.label) — \(room.name)").tag(room.id)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(Theme.rose).frame(width: 6, height: 6)
                    Text(store.selectedRoom.label)
                        .font(.grotesk(13, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 11)
                .frame(height: 32)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(Theme.outline))
            }

            Spacer(minLength: 0)

            Chip(text: Fmt.zone, size: 11)
            MiniClockBadge()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Theme.canvas)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.outline).frame(height: 1)
        }
    }
}

/// The dark round badge in the header: a tiny 24h dial of how far the day has gone.
struct MiniClockBadge: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: context.date)
            let hour = Double(comps.hour ?? 0)
            let minute = Double(comps.minute ?? 0)
            ZStack {
                Circle().fill(Theme.night)
                Circle()
                    .trim(from: 0, to: (hour * 60 + minute) / 1440)
                    .stroke(Theme.rose, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                Capsule().fill(.white)
                    .frame(width: 2, height: 8)
                    .offset(y: -4)
                    .rotationEffect(.degrees((hour.truncatingRemainder(dividingBy: 12) + minute / 60) * 30))
                Capsule().fill(.white.opacity(0.75))
                    .frame(width: 1.5, height: 11)
                    .offset(y: -5.5)
                    .rotationEffect(.degrees(minute * 6))
                Circle().fill(.white).frame(width: 3, height: 3)
            }
            .frame(width: 34, height: 34)
        }
        .accessibilityLabel("Day progress")
    }
}

struct SetlogTabBar: View {
    @Environment(SetlogStore.self) private var store

    var body: some View {
        HStack(spacing: 0) {
            item(.reel, title: "Vlog", icon: "movieclapper")
            takeItem
            item(.dial, title: "Dial", icon: "circle.lefthalf.filled")
            item(.archive, title: "Archive", icon: "calendar")
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(Theme.canvas.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.outline).frame(height: 1)
        }
    }

    private func item(_ tab: AppTab, title: String, icon: String) -> some View {
        let selected = store.tab == tab
        return Button {
            store.tab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: selected ? .semibold : .regular))
                    .frame(height: 34)
                Text(title).font(.grotesk(12, selected ? .bold : .medium))
            }
            .foregroundStyle(selected ? Theme.roseDeep : Theme.muted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var takeItem: some View {
        let selected = store.tab == .take
        return Button {
            store.tab = .take
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(selected ? Theme.rose : Theme.rose.opacity(0.3))
                    Image(systemName: "record.circle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(selected ? .white : Theme.roseDeep)
                }
                .frame(width: 34, height: 34)
                Text("2s Take").font(.grotesk(12, selected ? .bold : .medium))
                    .foregroundStyle(selected ? Theme.ink : Theme.muted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
