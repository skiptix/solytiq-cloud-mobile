import SwiftUI

/// Design tokens ported from the "Luminous List" design system
/// (`colors_and_type.css` / `ui_kits/solytiq-cloud-ios`). Colors are defined
/// as light/dark pairs so the whole app adapts automatically; the prototype
/// itself is light-only, so dark values are derived to stay legible rather
/// than copied from a nonexistent dark spec.
enum SCColor {
    static let page          = Color("scPage", bundle: .main)
    static let card          = Color("scCard", bundle: .main)
    static let cardTinted    = Color("scTinted", bundle: .main)
    static let hover         = Color("scHover", bundle: .main)
    static let border        = Color("scBorder", bundle: .main)
    static let separator     = Color("scSeparator", bundle: .main)

    static let text          = Color("scText", bundle: .main)
    static let text2         = Color("scText2", bundle: .main)
    static let text3         = Color("scText3", bundle: .main)
    static let text4         = Color("scText4", bundle: .main)

    static let primary       = Color("scPrimary", bundle: .main)
    static let primarySoft   = Color("scPrimarySoft", bundle: .main)
    static let primaryBg     = Color("scPrimaryBg", bundle: .main)
    static let primaryBg2    = Color("scPrimaryBg2", bundle: .main)

    static let success       = Color("scSuccess", bundle: .main)
    static let warning       = Color("scWarning", bundle: .main)
    static let danger        = Color("scDanger", bundle: .main)
    static let info          = Color("scInfo", bundle: .main)

    static let workBg        = Color("scWorkBg", bundle: .main)
    static let workFg        = Color("scWorkFg", bundle: .main)
    static let urgentBg      = Color("scUrgentBg", bundle: .main)
    static let urgentFg      = Color("scUrgentFg", bundle: .main)
}

/// Priority + badge colors that don't need to flex with light/dark (they're
/// small accent dots/pills matched 1:1 to the prototype's hex literals).
enum SCPriorityColor {
    static func color(for priority: String?) -> Color {
        switch priority {
        case "High": return Color(hex: "#ea580c")
        case "Medium": return Color(hex: "#f59e0b")
        case "Low": return Color(hex: "#787584")
        default: return Color(hex: "#cccccc")
        }
    }
}

enum SCBadgeColor {
    static func colors(for label: String?) -> (bg: Color, fg: Color) {
        switch label {
        case "Work": return (Color(hex: "#fff5d6"), Color(hex: "#6e5e0d"))
        case "Personal": return (Color(hex: "#F5F3FF"), Color(hex: "#5e4dbb"))
        case "Urgent": return (Color(hex: "#ffdad6"), Color(hex: "#ba1a1a"))
        case "Tip": return (Color(hex: "#eff6ff"), Color(hex: "#1D4ED8"))
        default: return (Color(hex: "#f1ecf6"), Color(hex: "#787584"))
        }
    }
}

/// Corner radii + spacing (Shape/Density tweak concept from the prototype,
/// exposed as a real user-facing Appearance setting instead of a design-time
/// toggle).
struct SCMetrics {
    var radius: CGFloat = 18
    var radiusSmall: CGFloat = 10
    var radiusLarge: CGFloat = 24
    var rowPadding: CGFloat = 11
    var cardPadding: CGFloat = 14

    static let sharp   = SCMetrics(radius: 8,  radiusSmall: 5,  radiusLarge: 12)
    static let rounded = SCMetrics(radius: 18, radiusSmall: 10, radiusLarge: 24)
    static let bubbly  = SCMetrics(radius: 28, radiusSmall: 18, radiusLarge: 36)

    static func density(_ d: AppearanceDensity) -> (row: CGFloat, card: CGFloat) {
        switch d {
        case .compact: return (8, 10)
        case .regular: return (11, 14)
        case .airy: return (16, 18)
        }
    }
}

enum AppearanceShape: String, CaseIterable, Codable, Hashable { case sharp, rounded, bubbly }
enum AppearanceDensity: String, CaseIterable, Codable, Hashable { case compact, regular, airy }

/// User-facing theme preference. `system` follows iOS; `light`/`dark` force a
/// scheme regardless of the device setting. The app defaults to `light` (the
/// "Luminous List" design was authored light-first) and applies the choice at
/// the root via `.preferredColorScheme`.
enum SCColorSchemePreference: String, CaseIterable, Codable, Hashable {
    case system, light, dark

    /// `nil` == follow the system; SwiftUI's `.preferredColorScheme(nil)` means
    /// "don't override".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

/// Adaptive background gradient used by the splash and onboarding screens.
/// The prototype's soft-purple wash reads well on light; on dark it would blow
/// out contrast, so we swap to deep, low-luminance tones that keep the logo and
/// form fields legible.
enum SCGradient {
    static func backdrop(_ scheme: ColorScheme) -> [Color] {
        scheme == .dark
            ? [Color(hex: "#141118"), Color(hex: "#1b1626"), Color(hex: "#241a2e")]
            : [Color(hex: "#ede9ff"), Color(hex: "#fdf8ff"), Color(hex: "#fff0f9")]
    }
}

extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// SF Symbols mapping for the Material Symbols names used throughout the
/// prototype, so screen code can keep the same short names.
enum SFIcon {
    static let map: [String: String] = [
        "home": "house.fill",
        "calendar_month": "calendar",
        "list_alt": "checklist",
        "cloud": "icloud.fill",
        "auto_awesome": "sparkles",
        "add": "plus",
        "add_circle": "plus.circle.fill",
        "search": "magnifyingglass",
        "settings": "gearshape.fill",
        "chevron_right": "chevron.right",
        "chevron_left": "chevron.left",
        "check": "checkmark",
        "check_circle": "checkmark.circle.fill",
        "calendar_today": "calendar",
        "checklist": "checklist",
        "account_tree": "arrow.triangle.branch",
        "delete": "trash",
        "tune": "slider.horizontal.3",
        "flag": "flag.fill",
        "task_alt": "checkmark.circle",
        "event": "calendar.badge.clock",
        "event_available": "calendar.badge.checkmark",
        "drag_indicator": "line.3.horizontal",
        "person": "person.crop.circle.fill",
        "palette": "paintpalette.fill",
        "cloud_sync": "arrow.triangle.2.circlepath.icloud.fill",
        "manage_accounts": "person.badge.key.fill",
        "shield_lock": "lock.shield.fill",
        "workspaces": "square.stack.3d.up.fill",
        "add_road": "road.lanes",
        "timeline": "chart.xyaxis.line",
        "route": "point.topleft.down.curvedto.point.bottomright.up",
        "folder": "folder.fill",
        "login": "arrow.right.circle.fill",
        "waving_hand": "hand.wave.fill",
        "location_on": "mappin.circle.fill",
        "schedule": "clock.fill",
        "edit_note": "square.and.pencil",
        "view_week": "calendar.day.timeline.left",
        "smartphone": "iphone",
        "dns": "server.rack",
        "lock": "lock.fill",
        "arrow_forward": "arrow.right",
        "description": "doc.fill",
        "more_vert": "ellipsis",
    ]
    static func name(_ key: String) -> String { map[key] ?? "circle" }
}
