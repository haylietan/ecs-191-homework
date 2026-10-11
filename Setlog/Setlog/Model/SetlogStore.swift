import AVFoundation
import Observation
import SwiftUI

enum AppTab: Hashable {
    case dial, take, reel, archive
}

@MainActor @Observable
final class SetlogStore {
    private(set) var clips: [Clip] = []
    var selectedRoomID = Room.all[0].id
    /// The Vlog tab is the home page.
    var tab: AppTab = .reel
    var reelDate: Date = .now
    private(set) var isSeeding = false

    var selectedRoom: Room { Room.with(id: selectedRoomID) ?? Room.all[0] }

    static let clipsDirectory: URL = {
        let url = URL.documentsDirectory.appending(path: "Clips", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let indexURL = URL.documentsDirectory.appending(path: "clips.json")

    init() {
        load()
    }

    // MARK: Queries

    func fileURL(for clip: Clip) -> URL {
        Self.clipsDirectory.appending(path: clip.fileName)
    }

    func clips(on date: Date) -> [Clip] {
        let key = DayKey.string(date)
        return clips.filter { $0.dayKey == key }.sorted { $0.hour < $1.hour }
    }

    /// The take for the hour slot containing `date`, if one exists.
    func clip(at date: Date) -> Clip? {
        let key = DayKey.string(date)
        let hour = Calendar.current.component(.hour, from: date)
        return clips.first { $0.dayKey == key && $0.hour == hour }
    }

    func clips(inMonthOf date: Date) -> [Clip] {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return clips.filter { Calendar.current.dateComponents([.year, .month], from: $0.recordedAt) == comps }
    }

    // MARK: Mutations

    /// Moves a freshly recorded file into the archive. Throws if the hour already has a take.
    @discardableResult
    func addClip(from tempURL: URL, recordedAt: Date, note: String, roomIDs: [String], orientation: CaptureOrientation) async throws -> Clip {
        guard clip(at: recordedAt) == nil else {
            try? FileManager.default.removeItem(at: tempURL)
            throw SetlogError.slotTaken
        }
        let id = UUID()
        let ext = tempURL.pathExtension.isEmpty ? "mov" : tempURL.pathExtension
        let fileName = "\(id.uuidString).\(ext)"
        let destination = Self.clipsDirectory.appending(path: fileName)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        let duration = (try? await AVURLAsset(url: destination).load(.duration).seconds) ?? CameraService.clipLength

        guard clip(at: recordedAt) == nil else {
            try? FileManager.default.removeItem(at: destination)
            throw SetlogError.slotTaken
        }
        let clip = Clip(
            id: id,
            fileName: fileName,
            recordedAt: recordedAt,
            dayKey: DayKey.string(recordedAt),
            hour: Calendar.current.component(.hour, from: recordedAt),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            roomIDs: roomIDs,
            orientation: orientation,
            duration: duration
        )
        clips.append(clip)
        clips.sort { $0.recordedAt < $1.recordedAt }
        save()
        return clip
    }

    /// Stitches every take from a day into one video, in hour order.
    func exportReel(for date: Date) async throws -> URL {
        let dayClips = clips(on: date)
        guard let first = dayClips.first else { throw SetlogError.noClips }
        let output = URL.temporaryDirectory.appending(path: "Setlog-\(first.dayKey)-\(dayClips.count).mp4")
        if FileManager.default.fileExists(atPath: output.path()) { return output }
        try await ReelComposer.export(urls: dayClips.map(fileURL(for:)), to: output)
        return output
    }

    // MARK: Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(clips).write(to: Self.indexURL, options: .atomic)
        } catch {
            print("Setlog: failed to save index: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = (try? decoder.decode([Clip].self, from: data)) ?? []
        clips = decoded.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path()) }
    }

    // MARK: Demo data

    #if DEBUG
    /// Long-press the SETLOG wordmark to fill the archive with simulated takes.
    func seedDemoDays() async {
        guard !isSeeding else { return }
        isSeeding = true
        defer { isSeeding = false }

        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        var generator = SystemRandomNumberGenerator()

        for offset in 0...12 where offset == 0 || offset % 4 != 3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let pool = Array(8...23).filter { offset > 0 || $0 < currentHour }
            let hours = pool.shuffled(using: &generator).prefix(Int.random(in: 4...9)).sorted()
            for (i, hour) in hours.enumerated() {
                guard let date = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...50), second: 0, of: day),
                      clip(at: date) == nil else { continue }
                let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
                let landscape = i % 4 == 3
                do {
                    try await SimulatedClipWriter.write(
                        to: url,
                        title: Fmt.hm.string(from: date),
                        subtitle: "\(Fmt.weekday.string(from: date)) · demo take",
                        palette: SimulatedClipWriter.palettes[(hour + offset) % SimulatedClipWriter.palettes.count],
                        landscape: landscape
                    )
                    let rooms = Room.all.map(\.id).filter { _ in Bool.random() }
                    try await addClip(
                        from: url,
                        recordedAt: date,
                        note: SimulatedClipWriter.notes.randomElement() ?? "",
                        roomIDs: rooms.isEmpty ? [selectedRoomID] : rooms,
                        orientation: landscape ? .landscape : .portrait
                    )
                } catch {
                    print("Setlog: demo seed failed: \(error)")
                }
            }
        }
    }
    #endif
}
