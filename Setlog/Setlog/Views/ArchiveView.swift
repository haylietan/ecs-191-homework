import SwiftUI

struct ArchiveView: View {
    @Environment(SetlogStore.self) private var store
    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay = Date.now
    @State private var shareItem: ShareItem?
    @State private var exporting = false
    @State private var errorMessage: String?

    private let calendar = Calendar.current

    var body: some View {
        let monthClips = store.clips(inMonthOf: month)
        let byDay = Dictionary(grouping: monthClips, by: \.dayKey)
        ScrollView {
            VStack(spacing: 14) {
                monthHeader
                stats(monthClips)
                rhythm(byDay: byDay)
                dayCard
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $shareItem) { ShareSheet(url: $0.url).presentationDetents([.medium, .large]) }
        .alert("Vlog", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Sections

    private var monthHeader: some View {
        let isCurrentMonth = calendar.isDate(month, equalTo: .now, toGranularity: .month)
        return HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 20))
                .foregroundStyle(Theme.roseDeep)
                .frame(width: 46, height: 46)
                .background(Theme.well, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(Fmt.monthYear.string(from: month)).font(.grotesk(21, .bold)).foregroundStyle(Theme.ink)
                Text("Chronicle Capsule").font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Spacer()
            HStack(spacing: 22) {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(isCurrentMonth)
                    .opacity(isCurrentMonth ? 0.3 : 1)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.trailing, 6)
        }
        .setlogCard(padding: 14)
    }

    private func stats(_ clips: [Clip]) -> some View {
        let seconds = Int(clips.reduce(0) { $0 + $1.duration }.rounded())
        return HStack {
            stat(value: "\(seconds)s", label: "logged")
            divider
            stat(value: "\(clips.count)", label: "candid takes")
            divider
            // Retakes don't exist in Setlog; the zero is the point.
            stat(value: "0", label: "retakes", valueColor: Theme.roseDeep)
        }
        .setlogCard(padding: 16)
    }

    private var divider: some View {
        Rectangle().fill(Theme.outline).frame(width: 1, height: 20).frame(maxWidth: .infinity)
    }

    private func stat(value: String, label: String, valueColor: Color = Theme.ink) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value).font(.grotesk(20, .bold)).monospacedDigit().foregroundStyle(valueColor)
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
        }
        .fixedSize()
    }

    private func rhythm(byDay: [String: [Clip]]) -> some View {
        let days = gridDays()
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        return VStack(spacing: 12) {
            HStack {
                Text("MONTHLY RHYTHM").font(.grotesk(12, .bold)).tracking(1).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(byDay.count) / \(daysInMonth) Days Logged").font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                    Text(["M", "T", "W", "T", "F", "S", "S"][i])
                        .font(.grotesk(12, .semibold))
                        .foregroundStyle(Theme.muted)
                }
                ForEach(days, id: \.date) { day in
                    dayCell(day, clips: byDay[DayKey.string(day.date)] ?? [])
                }
            }
        }
        .setlogCard(padding: 18)
    }

    private func dayCell(_ day: GridDay, clips: [Clip]) -> some View {
        let number = calendar.component(.day, from: day.date)
        let isFuture = day.date > .now
        let selected = calendar.isDate(day.date, inSameDayAs: selectedDay)
        let logged = day.inMonth && !clips.isEmpty
        let isToday = calendar.isDateInToday(day.date)

        return Button {
            selectedDay = day.date
        } label: {
            VStack(spacing: 5) {
                Text("\(number)")
                    .font(.grotesk(14, isToday ? .bold : .medium))
                    .foregroundStyle(!day.inMonth || isFuture ? Theme.muted.opacity(0.4) : (isToday ? Theme.roseDeep : (logged ? Theme.ink : Theme.muted.opacity(0.6))))
                if logged {
                    ZStack {
                        Circle().stroke(Theme.border, lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: min(1, Double(clips.count) / 16))
                            .stroke(selected ? Theme.roseDeep : Theme.rose, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 16, height: 16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if logged || selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? Theme.rose.opacity(0.3) : Theme.well)
                }
            }
            .overlay {
                if logged || selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.outline, lineWidth: selected ? 2 : 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!day.inMonth || isFuture)
    }

    @ViewBuilder
    private var dayCard: some View {
        let clips = store.clips(on: selectedDay)
        let total = Int(clips.reduce(0) { $0 + $1.duration }.rounded())
        let rooms = Set(clips.flatMap(\.roomIDs)).count

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Circle().fill(Theme.roseDeep).frame(width: 7, height: 7)
                        Text("\(Fmt.monthDay.string(from: selectedDay)) · \(Fmt.weekday.string(from: selectedDay))")
                            .font(.grotesk(17, .bold))
                            .foregroundStyle(Theme.ink)
                    }
                    Text(clips.isEmpty
                         ? "No takes this day"
                         : "\(clips.count) Hours Captured · \(rooms) Room\(rooms == 1 ? "" : "s") Joined")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                if !clips.isEmpty {
                    Text("\(total)s Vlog")
                        .font(.grotesk(13, .semibold))
                        .foregroundStyle(Theme.roseDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.rose.opacity(0.3), in: Capsule())
                        .overlay(Capsule().stroke(Theme.outline))
                }
            }

            if clips.isEmpty {
                Text("Nothing archived here. The days you log become two-second-per-hour capsules you can replay.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.well, in: RoundedRectangle(cornerRadius: 12))
            } else {
                mosaic(clips)

                HStack(spacing: 10) {
                    Button {
                        store.reelDate = selectedDay
                        store.tab = .reel
                    } label: {
                        Label("Play Vlog", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button(action: share) {
                        Group {
                            if exporting { ProgressView() } else { Image(systemName: "square.and.arrow.up") }
                        }
                        .frame(width: 24)
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(exporting)
                }
            }
        }
        .setlogCard(padding: 18)
    }

    private func mosaic(_ clips: [Clip]) -> some View {
        let picks = Array(clips.prefix(4))
        return HStack(spacing: 2) {
            ForEach(picks) { clip in
                ClipThumbnail(url: store.fileURL(for: clip))
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.outline))
        .overlay {
            LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay(alignment: .bottom) {
            HStack {
                Text("\(clips.count) candid takes stitched")
                Spacer()
                Text(streakLabel(clips))
            }
            .font(.grotesk(14, .semibold))
            .foregroundStyle(.white)
            .padding(14)
        }
    }

    // MARK: Helpers

    private func streakLabel(_ clips: [Clip]) -> String {
        let hours = Set(clips.map(\.hour))
        var best = 0, run = 0
        for h in 0..<24 {
            run = hours.contains(h) ? run + 1 : 0
            best = max(best, run)
        }
        return best >= 12 ? "Full unbroken day" : "\(best)h longest streak"
    }

    private struct GridDay {
        let date: Date
        let inMonth: Bool
    }

    /// Monday-first weeks covering the visible month, padded with neighbouring days.
    private func gridDays() -> [GridDay] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month) // 1 = Sunday
        let leading = (weekday + 5) % 7
        let totalCells = Int((Double(leading + range.count) / 7).rounded(.up)) * 7
        return (0..<totalCells).compactMap { i in
            guard let date = calendar.date(byAdding: .day, value: i - leading, to: month) else { return nil }
            return GridDay(date: date, inMonth: i >= leading && i < leading + range.count)
        }
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month), next <= .now else { return }
        month = next
        selectedDay = calendar.isDate(next, equalTo: .now, toGranularity: .month) ? .now : next
    }

    private func share() {
        exporting = true
        Task {
            do {
                shareItem = ShareItem(url: try await store.exportReel(for: selectedDay))
            } catch {
                errorMessage = error.localizedDescription
            }
            exporting = false
        }
    }
}
