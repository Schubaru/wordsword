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
    static let highlighter = dyn(0xFFE244, 0xD6B529, darkAlpha: 0.5)   // yellow: the first of the four highlighters — Linking words' easiest group
    /// The rest of the pencil case. Only ever marks a solved group in Linking words; in dark mode each
    /// sits at half strength over `sheet` so `ink` on it stays past 4.5:1.
    static let highlighterGreen = dyn(0xB7F0A2, 0x6FB04A, darkAlpha: 0.5)
    static let highlighterBlue  = dyn(0xA6DCFF, 0x4A9BE0, darkAlpha: 0.5)
    static let highlighterPink  = dyn(0xFFB7DC, 0xD05C9A, darkAlpha: 0.5)
    static let rule        = dyn(0xDADEE5, 0x1C1F24)   // hairline dividers
    static let edge        = dyn(0xC3C8D1, 0x343B48)   // the outline on grouped-list sections: white-on-white needs a real edge
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
    /// The word of the day coming down, the way a notification does: a hair past, then settled.
    static let drop     = Animation.spring(response: 0.55, dampingFraction: 0.8)
    /// …and going back up: ease-out-quint, so a flick carries straight on out of the top.
    static let lift     = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.32)
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

/// The wordmark: "wordsword" with the pen underline. Used on the splash and onboarding; Home wears the knight.
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
/// edge instead of white-on-white. No dividers between rows: whitespace separates them, as on Home.
/// Lists using these rows are `.grouped`, not `.insetGrouped`: the inset style clips every section
/// to its rounded shape, which would cut the shadow off, so the card is drawn here instead.
enum SheetRowEdge {
    case only, first, middle, last
    static func at(_ i: Int, of n: Int) -> SheetRowEdge { n <= 1 ? .only : i == 0 ? .first : i == n - 1 ? .last : .middle }
}

extension SheetRowEdge {
    /// Matches iOS 26's inset-grouped section corner, so these cards sit beside system ones.
    fileprivate static let radius: CGFloat = 26
    /// Gap between the screen edge and the card. Matches the list's own margin, so section
    /// headers and footers line up with the card edge before `.sheetSectionLabel()` nudges them in.
    fileprivate static let cardInset: CGFloat = 16
    /// Text inset inside the card.
    fileprivate static let inner: CGFloat = 20

    fileprivate var closesTop: Bool { self == .only || self == .first }
    fileprivate var closesBottom: Bool { self == .only || self == .last }

    /// Space inside the row but outside the card. List cells clip to their bounds, so the shadow
    /// has to fall inside the first and last rows; this is its room.
    fileprivate var room: EdgeInsets {
        EdgeInsets(top: closesTop ? 10 : 0, leading: Self.cardInset, bottom: closesBottom ? 16 : 0, trailing: Self.cardInset)
    }

    /// Row content inset: the shadow's room plus the padding inside the card. Set explicitly on
    /// every row so tappable rows (which zero their list insets to let the press wash reach the
    /// card edges) stay aligned with plain ones.
    fileprivate var insets: EdgeInsets {
        EdgeInsets(top: room.top + 11, leading: room.leading + Self.inner,
                   bottom: room.bottom + 11, trailing: room.trailing + Self.inner)
    }

    fileprivate var shape: UnevenRoundedRectangle {
        let top = closesTop, bottom = closesBottom
        return UnevenRoundedRectangle(cornerRadii: .init(
            topLeading: top ? Self.radius : 0, bottomLeading: bottom ? Self.radius : 0,
            bottomTrailing: bottom ? Self.radius : 0, topTrailing: top ? Self.radius : 0), style: .continuous)
    }
}

private struct SheetRowSurface: View {
    let edge: SheetRowEdge
    var body: some View {
        ZStack {
            // The shadow and the outline are both cast by the card shape continued past any side
            // that runs into a neighbouring row and clipped back to the row there — so a section
            // reads as one card with one unbroken edge and one shadow.
            edge.shape.fill(Color.sheet)
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .padding(.top, edge.closesTop ? 0 : -40).padding(.bottom, edge.closesBottom ? 0 : -40)
            edge.shape.fill(Color.sheet)
                .overlay {
                    edge.shape.strokeBorder(Color.edge, lineWidth: 1)
                        .padding(.top, edge.closesTop ? 0 : -2)
                        .padding(.bottom, edge.closesBottom ? 0 : -2)
                }
        }
        .padding(edge.room)
        .clipped()
    }
}

/// A tappable grouped-list row. SwiftUI drops the system highlight once a row carries a custom
/// background, so the press wash is drawn here — clipped to the row's own corners so it can't
/// spill outside the section outline.
struct SheetRowButtonStyle: ButtonStyle {
    let edge: SheetRowEdge
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(edge.insets)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                edge.shape.fill(Color.ink.opacity(configuration.isPressed ? 0.05 : 0))
                    .padding(edge.room)
            }
            .animation(Motion.feedback, value: configuration.isPressed)
    }
}

extension View {
    /// A grouped-list row that reads as a sheet lying on the paper: white fill, hairline edge.
    /// Pass where the row sits in its section so the outline closes at the ends.
    func sheetRow(_ edge: SheetRowEdge = .only) -> some View {
        listRowBackground(SheetRowSurface(edge: edge)).listRowInsets(edge.insets)
            .listRowSeparator(.hidden).listSectionSeparator(.hidden)
    }

    /// The same row, tappable: the button label fills the row so its press wash does too.
    func sheetRowButton(_ edge: SheetRowEdge = .only) -> some View {
        buttonStyle(SheetRowButtonStyle(edge: edge))
            .listRowInsets(EdgeInsets())
            .listRowBackground(SheetRowSurface(edge: edge))
            .listRowSeparator(.hidden).listSectionSeparator(.hidden)
    }

    /// A section header or footer over these cards: lined up with the text inside them.
    func sheetSectionLabel() -> some View { padding(.horizontal, SheetRowEdge.inner) }

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
            // On top, not behind: a card has its own opaque fill, which would hide a wash underneath.
            .overlay { shape.fill(Color.ink.opacity(configuration.isPressed ? 0.06 : 0)).allowsHitTesting(false) }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.feedback, value: configuration.isPressed)
    }
}

// MARK: - Top-bar buttons and the screen header
/// The one top-bar affordance: an icon on glass. Home's library/settings, Define's back, and the back
/// and action on every pushed screen are all this button, so "the round glass thing is a top-bar
/// action" is learned once. 44pt because that's the tap target, whatever the glyph.
struct GlassIcon: View {
    let systemName: String
    let label: String
    let action: () -> Void

    init(_ systemName: String, _ label: String, action: @escaping () -> Void) {
        self.systemName = systemName; self.label = label; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.medium)).foregroundStyle(Color.ink)
                .frame(width: 44, height: 44)
                .glassy(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// A screen's title, written on the paper. The system nav bar floats its title over the ruled grid
/// and gives no way to put it *on* one, so pushed screens carry this instead: glass icon buttons on
/// their own row, then the title two rules tall with its baseline on the rule that closes it — the
/// same grid the home input writes on.
///
/// The paper is phased to the title rather than the title nudged onto the paper, because the offset
/// between them is the top safe area (different on every device) plus the button row. Both ends are
/// measured in the same global space and the difference is the phase, so this lands the same in a
/// pushed screen (paper starts at the screen top) and in a sheet (paper starts at the sheet top).
struct PaperScreen<Trailing: View>: ViewModifier {
    let title: String
    var back = true
    let trailing: Trailing

    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    @State private var paperTop: CGFloat?
    @State private var titleTop: CGFloat?

    /// Rules land at `titleTop + k·rule`, so the title's baseline (two rules down) sits on one.
    private var phase: CGFloat {
        guard let paperTop, let titleTop else { return 0 }
        return (titleTop - paperTop).truncatingRemainder(dividingBy: rule) - rule
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            PaperBackground(spacing: rule, topInset: phase)
            VStack(alignment: .leading, spacing: 0) {
                header
                content
            }
        }
        // The probe has to ignore the safe area the way the paper's canvas does, or it reports the
        // inset frame and the phase comes out one status bar off. In the background, not a layer:
        // a greedy safe-area-ignoring child would stretch the stack under the home indicator.
        .background { probe(PaperTop.self).ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .swipeBack()
        .onPreferenceChange(PaperTop.self) { paperTop = $0 }
        .onPreferenceChange(TitleTop.self) { titleTop = $0 }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if back { GlassIcon("chevron.left", "Back") { dismiss() } }
                Spacer(minLength: 0)
                trailing
            }
            .frame(height: 44)
            Text(title)
                .font(.headword).foregroundStyle(Color.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .onRule(2, spacing: rule)
                .background { probe(TitleTop.self) }
                // `onRule` puts the baseline on the row's bottom edge, so descenders — and whatever
                // the screen puts first — land in the same band as the title. One rule of clearance
                // keeps them apart and still starts the content on a rule.
                .padding(.bottom, rule)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private func probe<K: PreferenceKey>(_ key: K.Type) -> some View where K.Value == CGFloat? {
        GeometryReader { g in Color.clear.preference(key: key, value: g.frame(in: .global).minY) }
    }
}

// One reading each, and it can be zero (a pushed screen's paper starts at the top of the screen) —
// so the value is optional and the first real one wins. A plain CGFloat lets the sibling layers,
// which set nothing, reduce the measurement back to the default.
private struct PaperTop: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) { value = value ?? nextValue() }
}
private struct TitleTop: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) { value = value ?? nextValue() }
}

extension View {
    /// A pushed screen: glass back button, the title on a rule, ruled paper behind.
    func paperScreen(_ title: String) -> some View {
        modifier(PaperScreen(title: title, trailing: EmptyView()))
    }
    /// The same, with one or more `GlassIcon`s trailing the back button.
    func paperScreen<T: View>(_ title: String, back: Bool = true, @ViewBuilder trailing: () -> T) -> some View {
        modifier(PaperScreen(title: title, back: back, trailing: trailing()))
    }
}

/// Hiding the nav bar takes the interactive pop gesture with it, and swipe-back is the one
/// navigation move people make without looking. This hands the same recogniser back, with a
/// delegate that only lets it start when there's something to pop — pulling on the root view
/// controller is what wedges a navigation stack.
private struct SwipeBack: UIViewControllerRepresentable {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var nav: UINavigationController?
        func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool { (nav?.viewControllers.count ?? 0) > 1 }
    }

    final class Probe: UIViewController {
        var coordinator: Coordinator?
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let nav = navigationController, let coordinator else { return }
            coordinator.nav = nav
            nav.interactivePopGestureRecognizer?.delegate = coordinator
            nav.interactivePopGestureRecognizer?.isEnabled = true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> Probe {
        let vc = Probe(); vc.coordinator = context.coordinator; return vc
    }
    func updateUIViewController(_: Probe, context: Context) {}
}

extension View {
    /// Gives swipe-back to a pushed screen that hides the navigation bar.
    func swipeBack() -> some View { background { SwipeBack().frame(width: 0, height: 0) } }
}
