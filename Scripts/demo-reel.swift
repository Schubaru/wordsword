// demo-reel <spec.json>: the landing page's looping define-flow video (docs/define.mp4) and its poster.
//
// Recording: a Simulator capture (`xcrun simctl io <udid> recordVideo --codec=h264`) taken while
// `Screens/testDemoReel` plays the flow; the test writes every tap's host time and point to taps.json,
// and recStart is the host time the recorder printed "Recording started". This cuts the take to the
// spec's segments (each with its own speed, so the typing can run faster than life), draws a touch dot
// at every tap, and crossfades the end into the start so it loops. AVFoundation only: no ffmpeg.
//
//   swiftc -O Scripts/demo-reel.swift -o /tmp/demo-reel && /tmp/demo-reel reel.json
//
// spec: { "src": "take.mov", "taps": "taps.json", "recStart": 1794426…, "tapLag": 0.06,
//         "out": "docs/define.mp4", "poster": "docs/define-poster.jpg", "posterAt": 20.4,
//         "w": 780, "h": 1696, "fps": 30, "kbps": 1800, "fade": 0.5,
//         "segments": [{ "from": 8.3, "to": 14.6, "speed": 2 }, …] }   // times in seconds of the take
import AVFoundation
import AppKit

struct Segment: Decodable { let from: Double; let to: Double; let speed: Double? }
struct Spec: Decodable {
    let src: String, taps: String, recStart: Double, tapLag: Double?, out: String, poster: String, posterAt: Double
    let w: Int, h: Int, fps: Int, kbps: Int, fade: Double, segments: [Segment]
}
struct Tap: Decodable { let t: Double; let x: Double; let y: Double }

let args = CommandLine.arguments
guard args.count == 2 else { FileHandle.standardError.write("usage: demo-reel <spec.json>\n".data(using: .utf8)!); exit(2) }
let specURL = URL(fileURLWithPath: args[1]), base = specURL.deletingLastPathComponent()
func path(_ p: String) -> URL { p.hasPrefix("/") ? URL(fileURLWithPath: p) : base.appendingPathComponent(p) }
let spec = try JSONDecoder().decode(Spec.self, from: Data(contentsOf: specURL))
let taps = try JSONDecoder().decode([Tap].self, from: Data(contentsOf: path(spec.taps)))
    .map { (t: $0.t - spec.recStart + (spec.tapLag ?? 0.06), x: $0.x, y: $0.y) }

let asset = AVURLAsset(url: path(spec.src))
let gen = AVAssetImageGenerator(asset: asset)
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
let srcW = Double(try await asset.loadTracks(withMediaType: .video)[0].load(.naturalSize).width)
let W = Double(spec.w), H = Double(spec.h), k = W / srcW, pt = srcW / 402   // the take is in pixels; taps are in points

func ease(_ p: Double) -> Double { p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2 }

/// Output time → take time, walking the segments at their speeds.
let total = spec.segments.reduce(0) { $0 + ($1.to - $1.from) / ($1.speed ?? 1) }
func source(_ u: Double) -> Double {
    var left = u
    for s in spec.segments {
        let d = (s.to - s.from) / (s.speed ?? 1)
        if left <= d { return s.from + left * (s.speed ?? 1) }
        left -= d
    }
    return spec.segments.last!.to
}

/// One frame of the take at take time s, scaled to the output, with any touch dots on it.
func render(_ s: Double) -> CGImage {
    let ctx = CGContext(data: nil, width: spec.w, height: spec.h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.interpolationQuality = .high
    if let img = try? gen.copyCGImage(at: CMTime(seconds: s, preferredTimescale: 6000), actualTime: nil) {
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
    }
    // A finger: grey enough to read on the black buttons and the white sheet alike. In for 90ms
    // (settling from 1.25x), held while the press lands, out over 300ms.
    for tap in taps {
        let d = s - tap.t
        guard d > -0.09, d < 0.45 else { continue }
        let a = d < 0 ? ease((d + 0.09) / 0.09) : d < 0.15 ? 1 : 1 - ease((d - 0.15) / 0.3)
        let r = 21 * pt * k * (d < 0 ? 1 + 0.25 * (1 - ease((d + 0.09) / 0.09)) : 1)
        let c = CGPoint(x: tap.x * pt * k, y: H - tap.y * pt * k), box = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
        ctx.setFillColor(CGColor(gray: 0.55, alpha: 0.38 * a)); ctx.fillEllipse(in: box)
        ctx.setStrokeColor(CGColor(gray: 0.25, alpha: 0.45 * a)); ctx.setLineWidth(1.5 * pt * k); ctx.strokeEllipse(in: box.insetBy(dx: 0.75 * pt * k, dy: 0.75 * pt * k))
    }
    return ctx.makeImage()!
}

// The poster: what a reduced-motion visitor sees, and what shows before the first frame decodes.
let poster = NSBitmapImageRep(cgImage: render(spec.posterAt))
try poster.representation(using: .jpeg, properties: [.compressionFactor: 0.82])!.write(to: path(spec.poster))

let out = path(spec.out)
try? FileManager.default.removeItem(at: out)
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true   // moov first, so the browser can start before the download ends
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: spec.w, AVVideoHeightKey: spec.h,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: spec.kbps * 1000, AVVideoMaxKeyFrameIntervalKey: spec.fps * 2,
                                      AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
    kCVPixelBufferWidthKey as String: spec.w, kCVPixelBufferHeightKey as String: spec.h,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

// Loop: playback starts `fade` in, and the last `fade` crossfades into the opening, so the wrap is seamless.
let fps = Double(spec.fps), length = total - spec.fade, count = Int((length * fps).rounded())
for i in 0..<count {
    while !input.isReadyForMoreMediaData { usleep(2000) }
    let t = Double(i) / fps + spec.fade
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    let buf = pb!
    CVPixelBufferLockBaseAddress(buf, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: spec.w, height: spec.h, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.draw(render(source(t)), in: CGRect(x: 0, y: 0, width: W, height: H))
    if t >= length {
        ctx.setAlpha(CGFloat(ease((t - length) / spec.fade)))
        ctx.draw(render(source(t - length)), in: CGRect(x: 0, y: 0, width: W, height: H))
    }
    CVPixelBufferUnlockBaseAddress(buf, [])
    adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(spec.fps)))
}
input.markAsFinished()
await writer.finishWriting()
guard writer.status == .completed else { FileHandle.standardError.write("write failed: \(writer.error?.localizedDescription ?? "?")\n".data(using: .utf8)!); exit(1) }
print("\(out.path): \(count) frames, \(spec.w)x\(spec.h), \(String(format: "%.1f", length))s")
