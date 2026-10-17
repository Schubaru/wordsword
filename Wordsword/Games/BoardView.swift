import SwiftUI

/// The crossword: a tile for every letter of every board word, blank until the word is found or a
/// hint shows the letter. Found tiles write in one after another (the tag stagger).
struct BoardView: View {
    let level: Level
    let tile: CGFloat
    let gap: CGFloat
    let picking: Bool
    let letter: (Level.Cell) -> Character?
    let revealed: (Level.Cell) -> Bool
    let delay: (Level.Cell) -> Double
    let onTap: (Level.Cell) -> Void

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<level.rows, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(0..<level.cols, id: \.self) { c in
                        let cell = Level.Cell(row: r, col: c)
                        if level.grid[cell] != nil {
                            Tile(size: tile, letter: letter(cell), revealed: revealed(cell), picking: picking,
                                 delay: delay(cell)) { onTap(cell) }
                        } else {
                            Color.clear.frame(width: tile, height: tile)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Board, \(level.targets.count) words")
    }
}

private struct Tile: View {
    let size: CGFloat
    let letter: Character?
    let revealed: Bool
    let picking: Bool
    let delay: Double
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let known = letter != nil
        let shape = RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
        let offered = picking && !known
        Button(action: action) {
            ZStack {
                shape.fill(revealed || offered ? Color.penWash : Color.sheet)
                shape.strokeBorder(offered ? Color.pen : Color.rule, lineWidth: 1)
                if let letter {
                    Text(String(letter).uppercased())
                        .font(.system(size: size * 0.58, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .animation(reduceMotion ? .linear(duration: 0.01) : Motion.state.delay(delay), value: known)
            .animation(Motion.feedback, value: offered)
        }
        .buttonStyle(SurfacePressStyle(shape: shape))
        .accessibilityLabel(letter.map { String($0).uppercased() } ?? "blank")
        .accessibilityHint(offered ? "Reveals this letter" : (known ? "Opens the word" : ""))
    }
}
