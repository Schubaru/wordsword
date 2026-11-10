// App Store screenshot panels: a headline over the real app screen, on the app's own ruled paper.
// Usage: swift Scripts/compose-screenshots.swift <raw frames dir> <out dir>
// Raw frames come from the DEBUG snapshot tour (STORE_SHOTS=1, see DebugSnapshots.swift). Writes
// opaque PNGs (App Store rejects alpha) at both required iPhone sizes, 6.3" and 6.9".
import AppKit

let panels: [(raw: String, name: String, headline: String)] = [   // |…| marks the highlighter swipe, \n breaks the line
    ("s-sentence",      "01-define",        "Any word,\nin |plain English|"),
    ("s-haikuzy",       "02-haikuzy",       "A daily haiku,\n|one word missing|"),
    ("s-all-words",     "03-library",       "Every word you\nlook up, |kept|"),
    ("s-chain",         "04-chain",         "Follow one word\n|to the next|"),
    ("s-flashcard",     "05-flashcards",    "Flashcards that\n|make it stick|"),
    ("s-plexicon",      "06-plexicon",      "One word a day,\nand |what it means|"),
    ("s-linking-words", "07-linking-words", "A fresh |puzzle|\nevery day"),
    ("s-word-wheel",    "08-word-wheel",    "Spell words,\n|level after level|"),
    ("s-home",          "09-home",          "Four |word games|,\none search away"),
]
let sizes: [(dir: String, w: Int, h: Int)] = [("6.3", 1206, 2622), ("6.9", 1320, 2868)]

func color(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
let args = CommandLine.arguments
let rawDir = URL(fileURLWithPath: args[1]), outDir = URL(fileURLWithPath: args[2])

for size in sizes {
    let W = CGFloat(size.w), H = CGFloat(size.h)
    let dir = outDir.appendingPathComponent(size.dir)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for p in panels {
        guard let shot = NSImage(contentsOf: rawDir.appendingPathComponent(p.raw + ".png")) else { fatalError("missing \(p.raw)") }
        // RGB with the alpha byte skipped: the file can't carry transparency even by accident.
        let cg = CGContext(data: nil, width: size.w, height: size.h, bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        cg.translateBy(x: 0, y: H); cg.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

        // Paper: white with college rules. No margin line: the screen already carries the app's own.
        color(0xFFFFFF).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
        let rule = W * 0.07
        color(0xE4E7EC).setFill()
        for y in stride(from: rule * 1.5, to: H, by: rule) { NSRect(x: 0, y: y, width: W, height: max(2, W / 600)).fill() }

        // Headline: serif, centered, with one phrase under the yellow highlighter.
        let parts = p.headline.components(separatedBy: "|")
        let plain = parts.joined()
        let serif = NSFont.systemFont(ofSize: W * 0.075, weight: .bold).fontDescriptor.withDesign(.serif)!
        let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineHeightMultiple = 1.05
        let text = NSTextStorage(string: plain, attributes: [.font: NSFont(descriptor: serif, size: W * 0.075)!,
                                                              .foregroundColor: color(0x151B24), .paragraphStyle: para])
        let layout = NSLayoutManager(), box = NSTextContainer(size: NSSize(width: W * 0.8, height: H))
        box.lineFragmentPadding = 0
        layout.addTextContainer(box); text.addLayoutManager(layout)
        let used = layout.usedRect(for: box)
        let origin = NSPoint(x: W * 0.1, y: H * 0.105 - used.height / 2)
        if parts.count == 3 {
            let marked = layout.glyphRange(forCharacterRange: NSRange(location: parts[0].count, length: parts[1].count), actualCharacterRange: nil)
            var lines: [NSRange] = []   // the phrase can wrap, so one band per line it lands on
            layout.enumerateLineFragments(forGlyphRange: marked) { _, _, _, g, _ in lines.append(NSIntersectionRange(g, marked)) }
            for g in lines where g.length > 0 {
                let r = layout.boundingRect(forGlyphRange: g, in: box)
                let band = NSRect(x: origin.x + r.minX - W * 0.012, y: origin.y + r.minY + r.height * 0.42,
                                  width: r.width + W * 0.024, height: r.height * 0.5)
                color(0xFFE244).setFill(); NSBezierPath(roundedRect: band, xRadius: band.height * 0.2, yRadius: band.height * 0.2).fill()
            }
        }
        layout.drawGlyphs(forGlyphRange: layout.glyphRange(for: box), at: origin)

        // The real screen, inset like a phone lying on the page.
        let sw = W * 0.76, sh = sw * shot.size.height / shot.size.width
        let frame = NSRect(x: (W - sw) / 2, y: H * 0.215, width: sw, height: sh)
        let card = NSBezierPath(roundedRect: frame, xRadius: sw * 0.075, yRadius: sw * 0.075)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = color(0x000000, 0.14); shadow.shadowBlurRadius = W * 0.03
        shadow.shadowOffset = NSSize(width: 0, height: W * 0.01); shadow.set()
        color(0xFFFFFF).setFill(); card.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState(); card.addClip()
        shot.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
        color(0xC3C8D1).setStroke(); card.lineWidth = max(2, W / 500); card.stroke()

        NSGraphicsContext.restoreGraphicsState()
        try NSBitmapImageRep(cgImage: cg.makeImage()!).representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(p.name + ".png"))
        print(size.dir, p.name)
    }
}
