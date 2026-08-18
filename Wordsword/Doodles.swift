import SwiftUI

// Hand-drawn things. Pure SwiftUI (no UIKit) so the same file renders on macOS for the icon script.
// Everything is drawn in a unit square and scaled by `.frame`, stroke width follows size.

// MARK: - Pen: a slightly grungy stroke (main line + a faint offset overdraw, like a pencil going twice)
extension Shape {
    /// The doodle look: round caps, main line + a faint offset overdraw.
    func doodle(_ color: Color, width: CGFloat) -> some View {
        ZStack {
            self.stroke(color.opacity(0.35), style: .init(lineWidth: width * 0.9, lineCap: .round, lineJoin: .round))
                .offset(x: width * 0.35, y: -width * 0.3)
            self.stroke(color, style: .init(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - College-ruled paper
/// White page, faint blue rules, one red margin line. Draw once with Canvas; cheap to keep on every screen.
struct Paper: View {
    var page: Color = .white
    var rule: Color = Color(red: 0.62, green: 0.75, blue: 0.92)
    var margin: Color = Color(red: 0.93, green: 0.45, blue: 0.42)
    var spacing: CGFloat = 28
    var marginX: CGFloat = 14     // in the gutter, left of all content — a margin you don't write over
    var topInset: CGFloat = 0     // first rule sits one spacing below this (so rules can start under a header)
    var fillsSafeArea = true      // false when the paper is a card's background rather than the screen's

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: false) { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(page))
            var y = topInset + spacing
            var rules = Path()
            while y < size.height {
                rules.move(to: CGPoint(x: 0, y: y)); rules.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            ctx.stroke(rules, with: .color(rule), lineWidth: 1)
            var m = Path()
            m.move(to: CGPoint(x: marginX, y: 0)); m.addLine(to: CGPoint(x: marginX, y: size.height))
            ctx.stroke(m, with: .color(margin), lineWidth: 1.2)
        }
        .ignoresSafeArea(edges: fillsSafeArea ? .all : [])
        .accessibilityHidden(true)
    }
}

// MARK: - Sword (the app icon, the logo mark)
struct SwordShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        // Blade: from crossguard (0.36,0.64) to tip (0.86,0.12), two edges meeting at the tip.
        p.move(to: pt(0.29, 0.58))
        p.addQuadCurve(to: pt(0.86, 0.12), control: pt(0.58, 0.26))
        p.addQuadCurve(to: pt(0.42, 0.71), control: pt(0.70, 0.44))
        p.closeSubpath()
        // Fuller: a line down the middle of the blade.
        p.move(to: pt(0.40, 0.60)); p.addLine(to: pt(0.74, 0.26))
        // Crossguard: perpendicular bar, a little curved like a smile.
        p.move(to: pt(0.24, 0.55))
        p.addQuadCurve(to: pt(0.46, 0.77), control: pt(0.33, 0.68))
        // Grip
        p.move(to: pt(0.355, 0.645)); p.addLine(to: pt(0.22, 0.78))
        p.move(to: pt(0.31, 0.69)); p.addLine(to: pt(0.34, 0.72))     // wrap
        p.move(to: pt(0.27, 0.73)); p.addLine(to: pt(0.30, 0.76))
        // Pommel
        p.addEllipse(in: CGRect(x: r.minX + 0.145 * w, y: r.minY + 0.775 * h, width: 0.085 * w, height: 0.085 * h))
        return p
    }
}

struct SwordDoodle: View {
    var color: Color = .primary
    var weight: CGFloat = 0.045      // stroke width as a fraction of size
    var body: some View {
        GeometryReader { g in
            SwordShape().doodle(color, width: max(1.5, g.size.width * weight))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - The knight
/// Poses: idle · jab (thinking/loading) · cheer (right, done) · slump (wrong). Only the sword arm and the head
/// move, so it can animate between poses with plain SwiftUI transforms.
enum KnightPose { case idle, jab, cheer, slump }

struct KnightDoodle: View {
    var pose: KnightPose = .idle
    var color: Color = .primary
    var accent: Color? = nil          // plume; nil = same as color

    private var swordAngle: Double {   // rotation of the sword arm around the shoulder, degrees (0 = idle ↗)
        switch pose { case .idle: 0; case .jab: 38; case .cheer: -55; case .slump: 118 }
    }
    private var headTilt: Double { pose == .slump ? 14 : (pose == .cheer ? -6 : 0) }
    private var bodyLean: Double { pose == .jab ? 8 : 0 }

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            let w = max(1.4, s * 0.04)
            let shoulder = UnitPoint(x: 0.56, y: 0.44)
            ZStack {
                KnightBody().doodle(color, width: w)
                KnightHead().doodle(color, width: w)
                    .rotationEffect(.degrees(headTilt), anchor: UnitPoint(x: 0.42, y: 0.38))
                KnightPlume().doodle(accent ?? color, width: w * 0.9)
                    .rotationEffect(.degrees(headTilt), anchor: UnitPoint(x: 0.42, y: 0.38))
                KnightSwordArm().doodle(color, width: w)
                    .rotationEffect(.degrees(swordAngle), anchor: shoulder)
                    .offset(x: pose == .slump ? s * 0.15 : 0)   // slump: hang the sword beside the body, tip on the ground
            }
            .rotationEffect(.degrees(bodyLean), anchor: UnitPoint(x: 0.42, y: 0.9))
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private func P(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }

struct KnightHead: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        // Helmet: a slightly squashed round, flat-ish bottom.
        p.move(to: P(r, 0.28, 0.30))
        p.addCurve(to: P(r, 0.56, 0.30), control1: P(r, 0.27, 0.06), control2: P(r, 0.57, 0.06))
        p.addQuadCurve(to: P(r, 0.28, 0.30), control: P(r, 0.42, 0.36))
        // Visor slit
        p.move(to: P(r, 0.31, 0.21)); p.addQuadCurve(to: P(r, 0.53, 0.21), control: P(r, 0.42, 0.235))
        // Breathing holes
        p.move(to: P(r, 0.38, 0.27)); p.addLine(to: P(r, 0.385, 0.275))
        p.move(to: P(r, 0.45, 0.27)); p.addLine(to: P(r, 0.455, 0.275))
        return p
    }
}

struct KnightPlume: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: P(r, 0.44, 0.09))
        p.addQuadCurve(to: P(r, 0.60, 0.02), control: P(r, 0.50, 0.00))
        p.addQuadCurve(to: P(r, 0.50, 0.11), control: P(r, 0.58, 0.10))
        return p
    }
}

struct KnightBody: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        // Torso: a tunic, wobbly rounded rect.
        p.move(to: P(r, 0.30, 0.36))
        p.addQuadCurve(to: P(r, 0.55, 0.36), control: P(r, 0.42, 0.34))
        p.addQuadCurve(to: P(r, 0.58, 0.68), control: P(r, 0.60, 0.52))
        p.addQuadCurve(to: P(r, 0.27, 0.68), control: P(r, 0.42, 0.72))
        p.addQuadCurve(to: P(r, 0.30, 0.36), control: P(r, 0.25, 0.52))
        // Belt
        p.move(to: P(r, 0.29, 0.56)); p.addQuadCurve(to: P(r, 0.575, 0.56), control: P(r, 0.43, 0.59))
        // Legs + feet
        p.move(to: P(r, 0.36, 0.68)); p.addLine(to: P(r, 0.35, 0.90)); p.addLine(to: P(r, 0.28, 0.91))
        p.move(to: P(r, 0.49, 0.68)); p.addLine(to: P(r, 0.50, 0.90)); p.addLine(to: P(r, 0.58, 0.91))
        // Shield arm (left) + round shield
        p.move(to: P(r, 0.30, 0.42)); p.addQuadCurve(to: P(r, 0.19, 0.55), control: P(r, 0.22, 0.46))
        p.addEllipse(in: CGRect(x: r.minX + 0.08 * r.width, y: r.minY + 0.47 * r.height, width: 0.20 * r.width, height: 0.20 * r.height))
        p.move(to: P(r, 0.13, 0.57)); p.addLine(to: P(r, 0.23, 0.57))
        p.move(to: P(r, 0.18, 0.51)); p.addLine(to: P(r, 0.18, 0.63))
        return p
    }
}

/// Right arm + sword, drawn in idle (sword pointing ↗). Rotated around the shoulder for other poses.
struct KnightSwordArm: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: P(r, 0.56, 0.44)); p.addQuadCurve(to: P(r, 0.68, 0.50), control: P(r, 0.63, 0.44))   // arm
        // Grip → crossguard → blade
        p.move(to: P(r, 0.66, 0.55)); p.addLine(to: P(r, 0.72, 0.46))                                    // grip
        p.move(to: P(r, 0.66, 0.44)); p.addLine(to: P(r, 0.77, 0.51))                                    // crossguard
        p.move(to: P(r, 0.715, 0.465))                                                                    // blade
        p.addLine(to: P(r, 0.94, 0.14))
        p.addLine(to: P(r, 0.75, 0.49))
        p.move(to: P(r, 0.735, 0.465)); p.addLine(to: P(r, 0.90, 0.20))                                  // fuller
        return p
    }
}

// MARK: - The slash: a diagonal wipe used to reveal content (masked), plus the blade line on its edge.
struct SlashMask: Shape {
    var progress: CGFloat
    var lean: CGFloat = 0.45
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func path(in r: CGRect) -> Path {
        let c = progress * (r.width + lean * r.height)
        var p = Path()
        p.move(to: CGPoint(x: r.minX - 1, y: r.minY - 1))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.minY - 1))
        p.addLine(to: CGPoint(x: r.minX + c - lean * r.height, y: r.maxY + 1))
        p.addLine(to: CGPoint(x: r.minX - 1, y: r.maxY + 1))
        p.closeSubpath()
        return p
    }
}

struct SlashEdge: Shape {
    var progress: CGFloat
    var lean: CGFloat = 0.45
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func path(in r: CGRect) -> Path {
        let c = progress * (r.width + lean * r.height)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY - 8))
        p.addLine(to: CGPoint(x: r.minX + c - lean * r.height, y: r.maxY + 8))
        return p
    }
}

extension View {
    /// Reveal `self` with a sword slash: diagonal wipe + a thin blade line that fades as it finishes.
    /// `progress` 0…1. Reduced motion callers should just pass 1.
    func slashReveal(_ progress: CGFloat, edge: Color) -> some View {
        self.mask(SlashMask(progress: progress))
            .overlay {
                SlashEdge(progress: progress)
                    .stroke(edge, style: .init(lineWidth: 2, lineCap: .round))
                    .opacity(progress < 1 ? Double(min(1, (1 - progress) * 3)) : 0)
                    .allowsHitTesting(false)
            }
    }
}
