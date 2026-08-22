import SwiftUI

// Tokens from DESIGN.md (OKLCH → sRGB). Light / dark resolved by the system.
extension Color {
    private static func dyn(_ light: UInt32, _ dark: UInt32, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark).withAlphaComponent(darkAlpha) : UIColor(hex: light) })
    }
    static let page        = dyn(0xFFFFFF, 0x0B0D12)   // the paper
    static let sheet       = dyn(0xFFFFFF, 0x151922)   // a sheet lying on the paper (Natural-style stacked surface)
    static let ink         = dyn(0x151B24, 0xE9EBEF)
    static let ink2        = dyn(0x575E69, 0xA1A5AB)
    static let pen         = dyn(0x000000, 0xFFFFFF)   // primary: black on paper, inverted in dark
    static let highlighter = dyn(0xFFE244, 0xD6B529, darkAlpha: 0.5)   // unused since the headword swipe was removed (it fought the word for legibility)
    static let rule        = dyn(0xDADEE5, 0x1C1F24)   // hairline dividers
    static let paperRule   = dyn(0xE4E7EC, 0x1B2536)   // college-rule lines (decorative, under everything)
    static let margin      = dyn(0xF0837A, 0x6E3A38)   // the red margin line
    static let penWash: Color = .pen.opacity(0.10)
    static let shadow: Color = .black.opacity(0.10)
    /// Text/icons sitting ON pen: white on the black button, near-black on the inverted dark-mode one.
    static let onPen       = dyn(0xFFFFFF, 0x0B1220)
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Font {
    static let headword = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let ghost    = Font.system(size: 38, weight: .bold, design: .rounded)   // the home input: giant, no box
    static let logo     = Font.system(.title2, design: .rounded).weight(.bold)
    static let define   = Font.system(.title3, design: .serif)          // it's a book
    static let pos      = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let pron     = Font.system(.footnote, design: .rounded).weight(.semibold)   // SANG-gwin
}

// MARK: - Motion (DESIGN.md: feedback 120 · state 220 · reveal 350; no bounce)
enum Motion {
    static let feedback = Animation.smooth(duration: 0.12)
    static let state    = Animation.smooth(duration: 0.22)
    static let reveal   = Animation.smooth(duration: 0.35)
    /// Sheets settling after a drag: critically damped, no overshoot.
    static let sheet    = Animation.spring(response: 0.42, dampingFraction: 0.9)
    /// A sheet clearing out before the keyboard arrives: ease-out-quint, gone by 150ms.
    static let sheetExit = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.18)
    /// The sword slash: ease-out-expo, decisive.
    static let slash    = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.42)
}

extension View {
    /// Liquid Glass on the iOS 26 SDK; material glass on older toolchains.
    @ViewBuilder func glassy(_ shape: some InsettableShape = Capsule()) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) { self.glassEffect(.regular, in: shape) }
        else { self.background(.ultraThinMaterial, in: shape) }
        #else
        self.background(.ultraThinMaterial, in: shape)
        #endif
    }

    /// Ruled-paper hairline under a row.
    func ruled() -> some View {
        overlay(alignment: .bottom) { Rectangle().fill(Color.rule).frame(height: 1) }
    }

    /// A sheet lying on the paper: white surface, soft lifted shadow, hairline edge (so it still reads in dark mode).
    func sheetSurface(radius: CGFloat = 28, corners: UIRectCorner = .allCorners) -> some View {
        background {
            UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: corners.contains(.topLeft) ? radius : 0, bottomLeading: corners.contains(.bottomLeft) ? radius : 0,
                bottomTrailing: corners.contains(.bottomRight) ? radius : 0, topTrailing: corners.contains(.topRight) ? radius : 0),
                style: .continuous)
            .fill(Color.sheet)
            .overlay {
                UnevenRoundedRectangle(cornerRadii: .init(
                    topLeading: corners.contains(.topLeft) ? radius : 0, bottomLeading: corners.contains(.bottomLeft) ? radius : 0,
                    bottomTrailing: corners.contains(.bottomRight) ? radius : 0, topTrailing: corners.contains(.topRight) ? radius : 0),
                    style: .continuous)
                .strokeBorder(Color.rule, lineWidth: 1)
            }
            .shadow(color: .shadow, radius: 24, y: -2)
        }
    }
}

/// The page every screen sits on: college-ruled paper in the app's tokens.
struct PaperBackground: View {
    var spacing: CGFloat = 28
    var topInset: CGFloat = 0
    var body: some View { Paper(page: .page, rule: .paperRule, margin: .margin, spacing: spacing, topInset: topInset) }
}

extension View {
    /// Writes this line on the paper: the row is `lines` rules tall and the text's baseline sits on the
    /// rule that closes it, so descenders cross the line the way they do in a notebook. Rows tile, so a
    /// column of them stays on the grid — as long as the paper's rules are phased to the column's top.
    func onRule(_ lines: Int = 1, spacing: CGFloat) -> some View {
        alignmentGuide(.bottom) { $0[.lastTextBaseline] }
            // minHeight, not height: a line that wraps (a long hint, a translation) takes the room it
            // needs and pushes the rest of the block down a little rather than being cut off.
            .frame(minHeight: CGFloat(lines) * spacing, alignment: .bottom)
    }
}

/// The one full-width primary action, used by every CTA in onboarding, the account flow and the
/// account prompts. Same shape everywhere so "this is the button that moves me forward" is learned
/// once. `.filled` is the primary; the outlined variant is the alternative beside it.
struct CTAStyle: ButtonStyle {
    enum Weight { case filled, outlined, quiet }
    var weight: Weight = .filled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(weight == .filled ? Color.onPen : (weight == .quiet ? Color.ink2 : Color.ink))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                switch weight {
                case .filled:   Capsule().fill(Color.pen)
                case .outlined: Capsule().fill(configuration.isPressed ? Color.ink.opacity(0.06) : Color.sheet)
                                    .overlay { Capsule().strokeBorder(Color.rule, lineWidth: 1) }
                case .quiet:    Color.clear
                }
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(Motion.feedback, value: configuration.isPressed)
    }
}

/// Press feedback: 0.96 scale, 120ms. Used for every chip/pill so the vocabulary is consistent.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Motion.feedback, value: configuration.isPressed)
    }
}

/// A slightly wobbly hand-drawn stroke — the highlighter/underline doodle.
/// `progress` 0…1 draws it left→right (the reveal). Deterministic wobble so it doesn't jitter on redraw.
struct DoodleStroke: Shape {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func path(in r: CGRect) -> Path {
        var p = Path()
        let y = r.midY
        p.move(to: CGPoint(x: r.minX, y: y + 1))
        let steps = 6
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = r.minX + r.width * t
            let wobble = sin(t * .pi * 3) * r.height * 0.12
            p.addQuadCurve(to: CGPoint(x: x, y: y + wobble),
                           control: CGPoint(x: x - r.width / CGFloat(steps) / 2, y: y - wobble))
        }
        return p.trimmedPath(from: 0, to: progress)
    }
}

/// The wordmark: "wordsword" with the pen underline. Used on home and onboarding.
struct Wordmark: View {
    var font: Font = .logo
    var body: some View {
        Text("wordsword")
            .font(font).foregroundStyle(Color.ink)
            .overlay(alignment: .bottom) {
                DoodleStroke(progress: 1).stroke(Color.pen, style: .init(lineWidth: 2, lineCap: .round))
                    .frame(height: 6).offset(y: 5)
            }
    }
}

// MARK: - Grouped-list containers
/// Where a row sits in its section. The section outline is drawn one row at a time — verticals on
/// every row, the rounded cap only on the ends — so a group of rows reads as one sheet with an
/// edge instead of white-on-white. Row boundaries keep the system's inset separator.
enum SheetRowEdge {
    case only, first, middle, last
    static func at(_ i: Int, of n: Int) -> SheetRowEdge { n <= 1 ? .only : i == 0 ? .first : i == n - 1 ? .last : .middle }
}

private struct SheetRowOutline: Shape {
    let edge: SheetRowEdge
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let b = rect.insetBy(dx: 0.5, dy: 0)          // hairline sits fully inside the row
        let top = edge == .only || edge == .first
        let bottom = edge == .only || edge == .last
        let yT = top ? b.minY + 0.5 : b.minY
        let yB = bottom ? b.maxY - 0.5 : b.maxY
        var p = Path()
        p.move(to: CGPoint(x: b.minX, y: top ? yT + radius : yT))
        p.addLine(to: CGPoint(x: b.minX, y: bottom ? yB - radius : yB))
        if bottom {
            p.addQuadCurve(to: CGPoint(x: b.minX + radius, y: yB), control: CGPoint(x: b.minX, y: yB))
            p.addLine(to: CGPoint(x: b.maxX - radius, y: yB))
            p.addQuadCurve(to: CGPoint(x: b.maxX, y: yB - radius), control: CGPoint(x: b.maxX, y: yB))
        } else {
            p.move(to: CGPoint(x: b.maxX, y: yB))
        }
        p.addLine(to: CGPoint(x: b.maxX, y: top ? yT + radius : yT))
        if top {
            p.addQuadCurve(to: CGPoint(x: b.maxX - radius, y: yT), control: CGPoint(x: b.maxX, y: yT))
            p.addLine(to: CGPoint(x: b.minX + radius, y: yT))
            p.addQuadCurve(to: CGPoint(x: b.minX, y: yT + radius), control: CGPoint(x: b.minX, y: yT))
        }
        return p
    }
}

extension SheetRowEdge {
    fileprivate static let radius: CGFloat = 10   // UIKit's inset-grouped corner radius
    /// Row content inset. Set explicitly on every row so tappable rows (which zero their list
    /// insets to let the press wash reach the row edges) stay aligned with plain ones.
    static let insets = EdgeInsets(top: 11, leading: 20, bottom: 11, trailing: 20)

    fileprivate var shape: UnevenRoundedRectangle {
        let top = self == .only || self == .first
        let bottom = self == .only || self == .last
        return UnevenRoundedRectangle(cornerRadii: .init(
            topLeading: top ? Self.radius : 0, bottomLeading: bottom ? Self.radius : 0,
            bottomTrailing: bottom ? Self.radius : 0, topTrailing: top ? Self.radius : 0), style: .continuous)
    }
}

private struct SheetRowSurface: View {
    let edge: SheetRowEdge
    var body: some View {
        edge.shape
            .fill(Color.sheet)
            .overlay { SheetRowOutline(edge: edge, radius: SheetRowEdge.radius).stroke(Color.rule, lineWidth: 1) }
    }
}

/// A tappable grouped-list row. SwiftUI drops the system highlight once a row carries a custom
/// background, so the press wash is drawn here — clipped to the row's own corners so it can't
/// spill outside the section outline.
struct SheetRowButtonStyle: ButtonStyle {
    let edge: SheetRowEdge
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(SheetRowEdge.insets)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .background { edge.shape.fill(Color.ink.opacity(configuration.isPressed ? 0.05 : 0)) }
            .animation(Motion.feedback, value: configuration.isPressed)
    }
}

extension View {
    /// A grouped-list row that reads as a sheet lying on the paper: white fill, hairline edge.
    /// Pass where the row sits in its section so the outline closes at the ends.
    func sheetRow(_ edge: SheetRowEdge = .only) -> some View {
        listRowBackground(SheetRowSurface(edge: edge)).listRowInsets(SheetRowEdge.insets)
    }

    /// The same row, tappable: the button label fills the row so its press wash does too, and the
    /// separator keeps the system's text-aligned inset.
    func sheetRowButton(_ edge: SheetRowEdge = .only) -> some View {
        buttonStyle(SheetRowButtonStyle(edge: edge))
            .listRowInsets(EdgeInsets())
            .listRowBackground(SheetRowSurface(edge: edge))
            .alignmentGuide(.listRowSeparatorLeading) { _ in SheetRowEdge.insets.leading }
    }

    /// The same, for rows generated by a `ForEach`.
    func sheetRow(_ i: Int, of n: Int) -> some View { sheetRow(.at(i, of: n)) }
    func sheetRowButton(_ i: Int, of n: Int) -> some View { sheetRowButton(.at(i, of: n)) }
}

/// Press feedback for a tappable surface (a card, not a chip): the same 0.98 nudge as `CTAStyle`
/// plus a light ink wash, so a container that reads as raised also reads as pressable.
struct SurfacePressStyle<S: Shape>: ButtonStyle {
    var shape: S
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background { shape.fill(Color.ink.opacity(configuration.isPressed ? 0.06 : 0)) }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.feedback, value: configuration.isPressed)
    }
}
