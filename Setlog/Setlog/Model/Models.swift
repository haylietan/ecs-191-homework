import SwiftUI

enum CaptureOrientation: String, Codable {
    case portrait, landscape
}

/// One 2-second take. There is at most one per hour slot, and it can never be retaken.
struct Clip: Identifiable, Codable, Hashable {
    let id: UUID
    let fileName: String
    let recordedAt: Date
    let dayKey: String
    let hour: Int
    var note: String
    var roomIDs: [String]
    var orientation: CaptureOrientation
    var duration: Double
}

struct Friend: Identifiable, Hashable {
    let id: String
    let name: String
    let handle: String
    let tint: Color

    var initial: String { String(name.prefix(1)) }

    static let minji = Friend(id: "minji", name: "Minji", handle: "@minji", tint: Color(hex: 0xD9A2AC))
    static let junho = Friend(id: "junho", name: "Junho", handle: "@junho", tint: Color(hex: 0x8FAE90))
    static let seoyeon = Friend(id: "seoyeon", name: "Seoyeon", handle: "@seoyeon", tint: Color(hex: 0xC9A39B))
    static let daniel = Friend(id: "daniel", name: "Daniel", handle: "@dan.k", tint: Color(hex: 0xA3949A))
    static let emily = Friend(id: "emily", name: "Emily", handle: "@em.ily", tint: Color(hex: 0xE2A9A0))
    static let sofia = Friend(id: "sofia", name: "Sofia", handle: "@sofiaaa", tint: Color(hex: 0xB89BB0))
    static let chloe = Friend(id: "chloe", name: "Chloe", handle: "@chlo", tint: Color(hex: 0xD6B48F))
    static let ethan = Friend(id: "ethan", name: "Ethan", handle: "@ethan.n", tint: Color(hex: 0x8FA3B5))
    static let kevin = Friend(id: "kevin", name: "Kevin", handle: "@kev", tint: Color(hex: 0x9CB59A))
}

/// A small, private audience. Takes are only ever seen by the rooms you send them to.
struct Room: Identifiable, Hashable {
    let id: String
    let number: Int
    let shortName: String
    let name: String
    let members: [Friend]

    var label: String { "Room \(String(format: "%02d", number)) · \(shortName)" }

    static let all: [Room] = [
        Room(id: "housemates", number: 1, shortName: "262", name: "262 housemates", members: [.minji, .emily, .daniel]),
        Room(id: "baddies", number: 2, shortName: "Baddies", name: "7 baddies 5 porche", members: [.minji, .seoyeon, .emily, .sofia, .chloe, .junho]),
        Room(id: "saja", number: 3, shortName: "Saja", name: "saja boys", members: [.junho, .daniel, .ethan, .kevin]),
    ]

    static func with(id: String) -> Room? { all.first { $0.id == id } }
}

/// Placeholder content for friends' takes until there is a backend.
struct FriendMoment: Identifiable {
    let friend: Friend
    let hour: Int
    let minute: Int
    let place: String
    let caption: String
    let symbol: String
    let colors: [Color]
    let viewers: Int

    var id: String { "\(friend.id)-\(hour)" }

    private static let templates: [(place: String, caption: String, symbol: String, colors: [UInt32])] = [
        ("Coffee House · MU", "CoHo iced latte hits just right", "cup.and.saucer.fill", [0xE8C9B8, 0xB98B78]),
        ("Unitrans · A Line", "Bus to campus, playlist on repeat", "bus.fill", [0xD3C2C5, 0x8E7F86]),
        ("Wellman Hall", "Lecture in 5, still finding a seat", "pencil.and.ruler.fill", [0xF9D8D2, 0xE2B4BD]),
        ("UC Davis Arboretum", "Golden hour walk by the waterway", "leaf.fill", [0xCFEACE, 0x8FAE90]),
        ("Shields Library", "Midterm grind, send snacks", "books.vertical.fill", [0xEAE8E7, 0xB5A9A6]),
        ("Davis Farmers Market", "Saturday market run", "takeoutbag.and.cup.and.straw.fill", [0xFFD9E0, 0xD9A2AC]),
        ("The Quad", "Biking past the cows (again)", "bicycle", [0xC9D6E3, 0x8A9DB0]),
        ("The 262 house", "Face mask + drama night", "moon.stars.fill", [0xD8CCE0, 0x8E7F9E]),
    ]

    private static let hours = [8, 10, 11, 13, 14, 16, 18, 20, 22]

    static func samples(for room: Room) -> [FriendMoment] {
        hours.enumerated().map { i, hour in
            let template = templates[(i + room.number) % templates.count]
            return FriendMoment(
                friend: room.members[i % room.members.count],
                hour: hour,
                minute: (i * 13 + room.number * 7) % 60,
                place: template.place,
                caption: template.caption,
                symbol: template.symbol,
                colors: template.colors.map(Color.init(hex:)),
                viewers: max(1, room.members.count - (i % 2))
            )
        }
    }
}

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }
}

enum SetlogError: LocalizedError {
    case slotTaken, noClips, exportFailed, photosDenied

    var errorDescription: String? {
        switch self {
        case .slotTaken: "This hour already has its take. One take only."
        case .noClips: "No takes logged for this day yet."
        case .exportFailed: "Couldn't stitch the vlog. Try again."
        case .photosDenied: "Allow photo library access in Settings to save vlogs."
        }
    }
}
