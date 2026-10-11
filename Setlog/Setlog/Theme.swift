import SwiftUI
import UIKit

// "Blush Chrono" design system: warm blush canvas, white cards with hairline
// rose-peach borders, dusty rose accents, warm charcoal type.

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

enum Theme {
    static let canvas = Color(hex: 0xFFF5F5)
    /// Slightly deeper blush behind the scrolling content, so white cards lift off the page.
    static let page = Color(hex: 0xF2DCDB)
    static let card = Color.white
    static let well = Color(hex: 0xFFF0F0)
    static let border = Color(hex: 0xF7D6D0)
    /// Solid black hairline used for every card, chip, button and divider outline.
    static let outline = Color.black
    static let rose = Color(hex: 0xE2B4BD)
    static let roseDeep = Color(hex: 0x79545C)
    static let ink = Color(hex: 0x4A4A4A)
    static let muted = Color(hex: 0x7D7575)
    static let sage = Color(hex: 0xADC7AD)
    static let night = Color(hex: 0x2B2729)
}

extension Font {
    /// Headline / data face. Space Grotesk in the spec; the system face keeps the app dependency-free.
    static func grotesk(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Shared building blocks

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.outline, lineWidth: 1))
    }
}

extension View {
    func setlogCard(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct Chip: View {
    enum Style { case outline, well, soft, filled, glass }

    var text: String
    var icon: String? = nil
    var dot = false
    var style: Style = .outline
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 5) {
            if dot {
                Circle().fill(style == .filled ? .white : Theme.rose).frame(width: 7, height: 7)
            }
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: size - 1, weight: .semibold))
                    .foregroundStyle(style == .filled ? .white : Theme.roseDeep)
            }
            Text(text)
                .font(.grotesk(size, .medium))
                .monospacedDigit()
                .foregroundStyle(style == .filled ? .white : Theme.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(background, in: Capsule())
        .overlay(Capsule().stroke(hasBorder ? Theme.outline : .clear, lineWidth: 1))
    }

    private var hasBorder: Bool { style == .outline || style == .well || style == .glass }

    private var background: AnyShapeStyle {
        switch style {
        case .outline: AnyShapeStyle(Color.white)
        case .well: AnyShapeStyle(Theme.canvas)
        case .soft: AnyShapeStyle(Theme.rose.opacity(0.35))
        case .filled: AnyShapeStyle(Theme.rose)
        case .glass: AnyShapeStyle(Color.white.opacity(0.88))
        }
    }
}

struct AvatarView: View {
    let friend: Friend?
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(friend?.tint ?? Theme.border)
            Text(friend?.initial ?? "You")
                .font(.grotesk(friend == nil ? size * 0.34 : size * 0.45, .bold))
                .foregroundStyle(friend == nil ? Theme.muted : .white)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(.white, lineWidth: 2))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.grotesk(15, .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.rose.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.grotesk(15, .semibold))
            .foregroundStyle(Theme.ink)
            .frame(minWidth: 48)
            .frame(height: 48)
            .padding(.horizontal, 4)
            .background(configuration.isPressed ? Theme.well : .white, in: Capsule())
            .overlay(Capsule().stroke(Theme.outline, lineWidth: 1))
    }
}

enum Fmt {
    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    static let hm = make("HH:mm")
    static let hms = make("HH:mm:ss")
    static let monthYear = make("MMMM yyyy")
    static let monthDay = make("MMM d")
    static let weekday = make("EEEE")

    static func hour(_ h: Int) -> String { String(format: "%02d:00", h) }

    static var zone: String { TimeZone.current.abbreviation() ?? "LOCAL" }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
