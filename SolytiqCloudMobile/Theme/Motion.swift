import SwiftUI

/// Motion tokens ported 1:1 from the "Luminous List" handoff
/// (`Design-Handoff.html` → Animation & Interaction). The prototype uses two
/// signature easing curves everywhere instead of ad-hoc transitions, and the
/// handoff's native-engineer notes call these out explicitly:
///
/// * Overshoot spring — `cubic-bezier(0.34, 1.56, 0.64, 1)` — card/section
///   entrances, checkbox pops, tab selection, button press. The `1.56` control
///   point is what produces the springy overshoot, which `timingCurve`
///   reproduces exactly (control points may exceed 1).
/// * Directional screen slide — `cubic-bezier(0.32, 0.72, 0, 1)` — screen and
///   mode transitions.
///
/// Durations map to the handoff's Animation timing table (springUp/springScale
/// 350–420ms, checkPop 150ms, button-active 120ms, screen slide 260ms, backdrop
/// fade 240ms).
enum SCMotion {
    /// The signature overshoot spring at an explicit duration.
    static func spring(_ duration: Double = 0.42) -> Animation {
        .timingCurve(0.34, 1.56, 0.64, 1, duration: duration)
    }

    /// Card / section entrance (springUp / springScale, ~350–420ms).
    static let springDefault = spring(0.42)
    /// Interactive selection — tab switch, folder collapse, toggles (~300ms).
    static let interactive = spring(0.30)
    /// Checkbox toggle pop (checkPop, 150ms).
    static let checkPop = spring(0.15)
    /// Global button-active press (120ms).
    static let press = spring(0.12)

    /// Directional screen / mode transition (slideFromRight/Left, 260ms).
    static let screenSlide = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.26)
    /// Backdrop / overlay fade (overlayIn, 240ms).
    static let overlay = Animation.easeInOut(duration: 0.24)
}

/// Global button press state from the handoff's "Press & hover states" table:
/// `transform: scale(0.94); opacity: 0.85` on active, 120ms spring. Renders the
/// label plainly (no default tint), so it is a drop-in replacement for
/// `.buttonStyle(.plain)` that adds the standard press feedback.
struct SCPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(SCMotion.press, value: configuration.isPressed)
    }
}

extension View {
    /// Applies the global press-feedback button style (scale 0.94 / opacity
    /// 0.85). Use in place of `.buttonStyle(.plain)` on tappable primitives.
    func scPressStyle() -> some View { buttonStyle(SCPressButtonStyle()) }
}
