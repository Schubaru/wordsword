import SwiftUI

/// The wheel: a round sheet lying on the paper, letters around its rim, and the pen line that
/// follows the finger from letter to letter. Letters are keyed by their index in the level, so a
/// shuffle moves them around the rim instead of relabelling them.
struct WheelView: View {
    let letters: [Character]
    let order: [Int]                 // slot → letter index
    let selection: [Int]             // letter indices, in connection order
    let onEnter: (Int) -> Void
    let onRelease: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var finger: CGPoint?

    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            let centre = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let n = max(letters.count, 1)
            let r = d * 0.35
            let chord = 2 * r * sin(.pi / CGFloat(n))
            let dia = min(d * 0.27, chord * 0.86)
            let hit = max(dia * 0.5 + 6, 24)
            let pos = { (slot: Int) -> CGPoint in
                let a = -CGFloat.pi / 2 + 2 * .pi * CGFloat(slot) / CGFloat(n)
                return CGPoint(x: centre.x + r * cos(a), y: centre.y + r * sin(a))
            }
            let slotOf = { (i: Int) in order.firstIndex(of: i) ?? i }

            ZStack {
                Circle()
                    .fill(Color.sheet)
                    .overlay(Circle().strokeBorder(Color.rule, lineWidth: 1))
                    .shadow(color: .shadow, radius: 24, y: 8)
                    .frame(width: d, height: d)
                Polyline(points: selection.map { pos(slotOf($0)) } + (finger.map { [$0] } ?? []))
                    .doodle(.pen, width: max(4, dia * 0.11))
                    .allowsHitTesting(false)
                ForEach(letters.indices, id: \.self) { i in
                    let on = selection.contains(i)
                    Text(String(letters[i]).uppercased())
                        .font(.system(size: dia * 0.52, weight: .bold, design: .rounded))
                        .foregroundStyle(on ? Color.onPen : Color.ink)
                        .frame(width: dia, height: dia)
                        .background(Circle().fill(on ? Color.pen : Color.sheet))
                        .scaleEffect(on ? 1.08 : 1)
                        .position(pos(slotOf(i)))
                        .animation(reduceMotion ? nil : Motion.feedback, value: on)
                        .animation(reduceMotion ? nil : Motion.state, value: order)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        finger = v.location
                        for slot in 0..<n where hypot(pos(slot).x - v.location.x, pos(slot).y - v.location.y) <= hit {
                            onEnter(order[slot]); break
                        }
                    }
                    .onEnded { _ in finger = nil; onRelease() }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Straight segments through the connected letters, ending at the fingertip.
struct Polyline: Shape {
    var points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for q in points.dropFirst() { p.addLine(to: q) }
        return p
    }
}
