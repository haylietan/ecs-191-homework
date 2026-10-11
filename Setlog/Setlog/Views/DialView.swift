import SwiftUI

struct DialView: View {
    @Environment(SetlogStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let today = store.clips(on: now)
            ScrollView {
                VStack(spacing: 14) {
                    RoomStatusBar(room: store.selectedRoom)
                    ChronographCard(now: now, todayClips: today)
                    HourlyPromptCard(now: now, clip: store.clip(at: now))
                    momentsHeader
                    let items = feed(now: now, today: today)
                    if items.isEmpty {
                        Text("Quiet room so far. Your first take sets the tone.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .setlogCard()
                    }
                    ForEach(items) { item in
                        switch item {
                        case .mine(let clip): MyMomentCard(clip: clip, url: store.fileURL(for: clip))
                        case .friend(let moment): FriendMomentCard(moment: moment)
                        }
                    }
                    footer(now: now)
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var momentsHeader: some View {
        HStack {
            Text("Recent Room Moments").font(.grotesk(15, .semibold)).foregroundStyle(Theme.ink)
            Chip(text: "Today", size: 10)
            Spacer()
            Label("Live Loop", systemImage: "arrow.triangle.2.circlepath")
                .font(.grotesk(12, .medium))
                .foregroundStyle(Theme.roseDeep)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func footer(now: Date) -> some View {
        let next = Fmt.hour((Calendar.current.component(.hour, from: now) + 1) % 24)
        return HStack(spacing: 6) {
            Circle().fill(Theme.rose).frame(width: 4, height: 4)
            Text("Earlier hours archived · Syncing at \(next)")
            Circle().fill(Theme.rose).frame(width: 4, height: 4)
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.muted)
        .padding(.vertical, 6)
    }

    private func feed(now: Date, today: [Clip]) -> [FeedItem] {
        let hour = Calendar.current.component(.hour, from: now)
        let room = store.selectedRoom
        let mine = today.filter { $0.roomIDs.contains(room.id) }.suffix(2).map(FeedItem.mine)
        let friends = FriendMoment.samples(for: room).filter { $0.hour < hour }.suffix(3).map(FeedItem.friend)
        return (mine + friends).sorted { $0.sortKey > $1.sortKey }
    }
}

private enum FeedItem: Identifiable {
    case mine(Clip)
    case friend(FriendMoment)

    var id: String {
        switch self {
        case .mine(let clip): clip.id.uuidString
        case .friend(let moment): moment.id
        }
    }

    var sortKey: Int {
        switch self {
        case .mine(let clip): clip.hour * 60 + Calendar.current.component(.minute, from: clip.recordedAt)
        case .friend(let moment): moment.hour * 60 + moment.minute
        }
    }
}

// MARK: - Room status

struct RoomStatusBar: View {
    let room: Room

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                PulsingDot()
                Text(room.name).font(.grotesk(13, .medium)).foregroundStyle(Theme.ink)
                Text("\(room.members.count + 1)")
                    .font(.grotesk(10, .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.canvas, in: Capsule())
                    .overlay(Capsule().stroke(Theme.outline))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(Theme.outline))

            Spacer()

            HStack(spacing: -7) {
                ForEach(room.members) { AvatarView(friend: $0, size: 26) }
                AvatarView(friend: nil, size: 26)
            }
        }
    }
}

struct PulsingDot: View {
    var color = Theme.rose
    var size: CGFloat = 8
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(pulse ? 0.45 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

// MARK: - 24h chronograph

struct ChronographCard: View {
    let now: Date
    let todayClips: [Clip]

    private var hour: Int { Calendar.current.component(.hour, from: now) }
    private var minute: Int { Calendar.current.component(.minute, from: now) }
    private var captured: Set<Int> { Set(todayClips.map(\.hour)) }

    var body: some View {
        let remaining = (hour..<24).filter { !captured.contains($0) }.count
        let logged = Int(todayClips.reduce(0) { $0 + $1.duration }.rounded())

        VStack(spacing: 6) {
            HStack {
                Label {
                    Text("CHRONOGRAPH 24H").font(.grotesk(11, .semibold)).tracking(1)
                } icon: {
                    Image(systemName: "circle.dashed").foregroundStyle(Theme.rose)
                }
                .foregroundStyle(Theme.muted)
                Spacer()
                Chip(text: "\(captured.count) of \(hour + 1) captured", style: .well, size: 11)
            }

            ZStack {
                dial
                VStack(spacing: 2) {
                    Text(Fmt.hm.string(from: now))
                        .font(.grotesk(36, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("HOUR \(hour) \(captured.contains(hour) ? "CAPTURED" : "ACTIVE")")
                        .font(.grotesk(11, .bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.roseDeep)
                    Chip(text: "\(logged)s logged today", icon: "record.circle", style: .well, size: 10)
                        .padding(.top, 4)
                }
            }
            .frame(width: 210, height: 210)
            .padding(.vertical, 4)

            HStack {
                HStack(spacing: 5) {
                    Circle().fill(Theme.rose).frame(width: 6, height: 6)
                    Text("\(remaining) slots remaining")
                }
                .foregroundStyle(Theme.muted)
                Spacer()
                Text("Next slot in \(60 - minute)m").foregroundStyle(Theme.roseDeep).fontWeight(.medium)
            }
            .font(.system(size: 12))
        }
        .setlogCard()
    }

    private var dial: some View {
        let ringInset: CGFloat = 14
        return ZStack {
            Circle()
                .stroke(Theme.border.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))

            ForEach(0..<24, id: \.self) { h in
                let isCaptured = captured.contains(h)
                let isCurrent = h == hour
                Circle()
                    .trim(from: (Double(h) + 0.12) / 24, to: (Double(h) + 0.88) / 24)
                    .stroke(
                        isCaptured ? Theme.rose : (isCurrent ? Theme.roseDeep.opacity(0.35) : Theme.border.opacity(h < hour ? 1 : 0.55)),
                        style: StrokeStyle(lineWidth: isCaptured ? 9 : 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(ringInset)
            }

            ForEach([0, 6, 12, 18], id: \.self) { h in
                let angle = Double(h) / 24 * 2 * .pi - .pi / 2
                Text(String(format: "%02d", h))
                    .font(.grotesk(9, .semibold))
                    .foregroundStyle(Theme.muted.opacity(0.7))
                    .offset(x: cos(angle) * 72, y: sin(angle) * 72)
            }

            GeometryReader { geo in
                let radius = geo.size.width / 2 - ringInset
                let fraction = (Double(hour) + Double(minute) / 60) / 24
                let angle = fraction * 2 * .pi - .pi / 2
                PulsingDot(color: Theme.roseDeep, size: 11)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .position(x: geo.size.width / 2 + cos(angle) * radius, y: geo.size.height / 2 + sin(angle) * radius)
            }
        }
    }
}

// MARK: - Hourly prompt

struct HourlyPromptCard: View {
    @Environment(SetlogStore.self) private var store
    let now: Date
    let clip: Clip?

    private static let prompts = [
        "Who's still up with you?", "Late-night window glow", "The 2 a.m. snack", "Dreaming or scrolling?",
        "What does the quiet sound like?", "Sunrise or snooze?", "First light on your street", "Morning ritual, unedited",
        "Bike ride to class, as-is", "CoHo coffee number one?", "Notes margin doodles", "What's on the desk?",
        "Silo lunch, honestly", "Post-lunch slump spot", "Between classes on the Quad", "Shields study break or boba run?",
        "Afternoon light check", "Where did the hour go?", "Golden hour in the Arboretum", "Dinner at the DC or downtown?",
        "Evening walk sounds", "What are you winding down with?", "Night routine, no filter", "Last look at today",
    ]

    var body: some View {
        let hour = Calendar.current.component(.hour, from: now)
        let minutesLeft = 60 - Calendar.current.component(.minute, from: now)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    if clip == nil {
                        PulsingDot()
                    } else {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.sage)
                    }
                    Text("\(Fmt.hour(hour)) SLOT \(clip == nil ? "OPEN" : "CAPTURED")")
                        .font(.grotesk(12, .bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.roseDeep)
                }
                Spacer()
                Chip(text: clip == nil ? "\(minutesLeft)m left" : "next in \(minutesLeft)m", style: .well, size: 11)
            }

            if let clip {
                Text(clip.note.isEmpty ? "Taken at \(Fmt.hm.string(from: clip.recordedAt))" : "“\(clip.note)”")
                    .font(.grotesk(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("One take, kept as it is. The next slot opens at \(Fmt.hour((hour + 1) % 24)).")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            } else {
                Text(Self.prompts[hour]).font(.grotesk(17, .semibold)).foregroundStyle(Theme.ink)
                Text("Catch your 2-second glimpse before the hour slides away.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            Button {
                if clip == nil {
                    store.tab = .take
                } else {
                    store.reelDate = now
                    store.tab = .reel
                }
            } label: {
                Label(clip == nil ? "Log 2s Clip" : "Watch Today's Vlog", systemImage: clip == nil ? "video.fill" : "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
        }
        .setlogCard()
    }
}

// MARK: - Moment cards

private struct MomentCardShell<Media: View>: View {
    let avatar: Friend?
    let name: String
    let handle: String
    let place: String
    let hour: Int
    let time: String
    let caption: String
    let footerLeft: String
    let footerRight: String
    @ViewBuilder let media: Media

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                AvatarView(friend: avatar, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(name).font(.grotesk(13, .semibold)).foregroundStyle(Theme.ink)
                        Text(handle).font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    Text(place).font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Chip(text: "\(Fmt.hour(hour)) Hour", style: .well, size: 10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Rectangle().fill(Theme.outline).frame(height: 1)

            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay { media }
                .clipped()
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        PulsingDot(size: 6)
                        Text("\(time) \(Fmt.zone)")
                    }
                    .font(.grotesk(11, .medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.9), in: Capsule())
                    .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    Text("2.0s")
                        .font(.grotesk(11, .bold))
                        .foregroundStyle(Theme.roseDeep)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.9), in: Capsule())
                        .padding(8)
                }
                .overlay(alignment: .bottomLeading) {
                    if !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                            .padding(8)
                    }
                }

            HStack {
                Label(footerLeft, systemImage: "eye")
                Spacer()
                Text(footerRight).opacity(0.8)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.canvas.opacity(0.6))
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.outline))
    }
}

struct FriendMomentCard: View {
    let moment: FriendMoment

    var body: some View {
        MomentCardShell(
            avatar: moment.friend,
            name: moment.friend.name,
            handle: moment.friend.handle,
            place: moment.place,
            hour: moment.hour,
            time: String(format: "%02d:%02d", moment.hour, moment.minute),
            caption: moment.caption,
            footerLeft: "Viewed by \(moment.viewers) friends quietly",
            footerRight: "No public feed"
        ) {
            ZStack {
                LinearGradient(colors: moment.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: moment.symbol)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}

struct MyMomentCard: View {
    let clip: Clip
    let url: URL

    var body: some View {
        let rooms = clip.roomIDs.count
        MomentCardShell(
            avatar: nil,
            name: "You",
            handle: "@haylietan",
            place: clip.orientation == .landscape ? "Landscape take" : "Portrait take",
            hour: clip.hour,
            time: Fmt.hm.string(from: clip.recordedAt),
            caption: clip.note,
            footerLeft: "Sent to \(rooms) room\(rooms == 1 ? "" : "s")",
            footerRight: "Looping quietly"
        ) {
            LoopingVideoView(url: url)
        }
    }
}
