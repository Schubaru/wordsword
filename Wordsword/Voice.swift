import AVFoundation
import Speech
import SwiftUI

// MARK: - What one hold produced

/// Why voice couldn't run. Every case is something the user can act on in one tap.
enum VoiceBlock: Equatable {
    case needsPermission   // we just asked; the system alert ate this hold
    case micOff            // microphone denied in Settings
    case speechOff         // speech recognition denied in Settings
    case unavailable       // no recognizer for this locale/device, or the engine wouldn't start

    var message: String {
        switch self {
        case .needsPermission: "You're set — hold again to speak."
        case .micOff:          "The mic is off for wordsword."
        case .speechOff:       "Speech recognition is off."
        case .unavailable:     "Voice isn't available right now."
        }
    }
    /// Only the two Settings-level denials are worth sending someone to Settings for.
    var offersSettings: Bool { self == .micOff || self == .speechOff }
}

enum VoiceOutcome: Equatable {
    case cancelled                     // released before the mic committed — it was a tap
    case word(String)                  // one clean word: straight to the definition
    case uncertain(String, [String])   // into the input, with these to pick from
    case nothing                       // mic was live, nothing usable came back
    case blocked(VoiceBlock)
}

// MARK: - Turning speech into a word

/// People don't say "ephemeral". They say "what does ephemeral mean". This strips the question
/// off the word — and when it can't get down to one word, says so instead of guessing.
enum VoiceText {
    /// Longest first, so "what is the meaning of" wins over "what is".
    private static let lead = [
        "what is the meaning of", "what does the word", "how do you spell", "can you define",
        "tell me what", "the meaning of", "definition of", "look up the word", "define the word",
        "meaning of", "what does", "what is", "what's", "whats", "look up", "lookup",
        "define", "spell", "the word", "the", "a", "an",
    ].sorted { $0.count > $1.count }

    private static let tail = [
        "means mean", "definition", "meaning", "for me", "please", "again", "means", "mean",
    ].sorted { $0.count > $1.count }

    struct Parse: Equatable {
        var text: String
        var tokens: [String]
        /// Exactly one word left standing — the only case confident enough to skip the input.
        var word: String? { tokens.count == 1 ? tokens[0] : nil }
    }

    /// Lowercase, letters (plus hyphen and apostrophe) only, single spaces.
    static func clean(_ raw: String) -> String {
        let keep = CharacterSet.letters.union(CharacterSet(charactersIn: "-'"))
        let flattened = raw.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        let mapped = String(String.UnicodeScalarView(flattened.unicodeScalars.map { keep.contains($0) ? $0 : " " }))
        return mapped.split(separator: " ").joined(separator: " ")
    }

    static func parse(_ raw: String) -> Parse {
        var t = clean(raw)
        var trimming = true
        while trimming {
            trimming = false
            for p in lead where t.hasPrefix(p + " ") {          // never strip down to nothing
                t = String(t.dropFirst(p.count + 1)); trimming = true; break
            }
        }
        trimming = true
        while trimming {
            trimming = false
            for s in tail where t.hasSuffix(" " + s) {
                t = String(t.dropLast(s.count + 1)); trimming = true; break
            }
        }
        // A whole utterance of filler ("define", "what does") leaves nothing — that's a miss, not a word.
        if lead.contains(t) || tail.contains(t) { t = "" }
        return Parse(text: t, tokens: t.split(separator: " ").map(String.init))
    }

    #if DEBUG
    /// The parser is the one piece here with real branching, so it carries its own check.
    static func selfCheck() {
        assert(parse("ephemeral").word == "ephemeral")
        assert(parse("What does ephemeral mean?").word == "ephemeral")
        assert(parse("what's the meaning of halcyon").word == "halcyon")
        assert(parse("define the word sanguine, please").word == "sanguine")
        assert(parse("the ephemeral").word == "ephemeral")
        assert(parse("well-meaning").word == "well-meaning")
        assert(parse("define").tokens.isEmpty)
        assert(parse("   ").tokens.isEmpty)
        assert(parse("cognitive dissonance").word == nil)
        assert(parse("cognitive dissonance").tokens == ["cognitive", "dissonance"])
    }
    #endif
}

// MARK: - The mic

/// Hold-to-speak. `hold` runs 0 → 1 across the press so the whole transition can follow the finger
/// instead of snapping after a timer; the mic commits when it reaches 1.
@MainActor @Observable final class VoiceListener {
    static let samples = 56
    /// How long the hold takes to become voice. Long enough not to fire on a tap, short enough that
    /// nobody waits in silence — the UI is already moving from the first millisecond.
    static let arm: Duration = .milliseconds(600)
    private static let micLead: Duration = .milliseconds(200)   // past tap range: start early so no syllable is clipped
    private static let settle: Duration = .milliseconds(600)    // grace for the final transcript after release
    private static let cap: Duration = .seconds(15)             // nobody holds this long on purpose

    var hold: CGFloat = 0
    private(set) var live = false                 // mic actually running and committed
    private(set) var heard = ""                   // the live hypothesis
    private(set) var settled = false              // the recognizer called it final
    private(set) var levels = [CGFloat](repeating: 0, count: VoiceListener.samples)

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var final: SFSpeechRecognitionResult?
    private var block: VoiceBlock?
    private var armTask: Task<Void, Never>?
    private var capTask: Task<Void, Never>?
    private var tapped = false
    private var sessionActive = false

    init() {
        #if DEBUG
        VoiceText.selfCheck()
        #endif
    }

    // MARK: press

    func begin() {
        guard armTask == nil, !live else { return }
        final = nil; block = nil; heard = ""; settled = false
        withAnimation(.linear(duration: 0.6)) { hold = 1 }
        armTask = Task { [weak self] in
            try? await Task.sleep(for: Self.micLead)
            guard let self, !Task.isCancelled else { return }
            if let b = await self.start() {
                self.block = b
                withAnimation(Motion.state) { self.hold = 0 }
                return
            }
            try? await Task.sleep(for: Self.arm - Self.micLead)
            guard !Task.isCancelled else { return }
            self.live = true
            self.capTask = Task { [weak self] in
                try? await Task.sleep(for: Self.cap)
                guard !Task.isCancelled else { return }
                self?.request?.endAudio()          // stop capturing, keep what we have
            }
        }
    }

    /// Finger up. Returns what the hold produced.
    func end() async -> VoiceOutcome {
        armTask?.cancel(); armTask = nil
        capTask?.cancel(); capTask = nil

        if let b = block { block = nil; stop(); collapse(); return .blocked(b) }
        guard live else { stop(); collapse(); return .cancelled }

        // The transcript is already on screen, so this reads as the words settling, not as waiting.
        request?.endAudio()
        var waited = 0
        while final == nil, waited < 12 { try? await Task.sleep(for: .milliseconds(50)); waited += 1 }
        settled = true

        let result = final
        let text = result?.bestTranscription.formattedString ?? heard
        let confidence = result.map(Self.meanConfidence) ?? 0
        let alternates = (result?.transcriptions.dropFirst().prefix(3) ?? []).map(\.formattedString)
        stop(); collapse()

        let p = VoiceText.parse(text)
        guard !p.tokens.isEmpty else { return .nothing }
        // One word, and the recognizer isn't hedging (it reports 0 when it doesn't score at all).
        if let w = p.word, confidence == 0 || confidence >= 0.3 { return .word(w) }

        var picks = p.tokens
        picks += alternates.flatMap { VoiceText.parse($0).tokens }
        picks = picks.filter { $0.count >= 3 && $0 != p.text }
        var seen = Set<String>()
        return .uncertain(p.text, picks.filter { seen.insert($0).inserted }.prefix(6).map { $0 })
    }

    /// Phone call, app backgrounded, view gone: drop everything, navigate nowhere.
    func abort() {
        armTask?.cancel(); armTask = nil
        capTask?.cancel(); capTask = nil
        block = nil
        stop(); collapse()
    }

    /// VoiceOver can't long-press, so it gets a hands-free listen: speak, stop when you stop.
    func listenHandsFree() async -> VoiceOutcome {
        begin()
        var elapsed = 0, quiet = 0
        var last = ""
        while elapsed < 8_000 {
            try? await Task.sleep(for: .milliseconds(200))
            elapsed += 200
            if block != nil { break }
            if heard != last { last = heard; quiet = 0 } else if !heard.isEmpty { quiet += 200 }
            if quiet >= 1_400 { break }
        }
        return await end()
    }

    // MARK: engine

    private func start() async -> VoiceBlock? {
        if let b = await authorize() { return b }
        let r = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
        guard let r, r.isAvailable else { return .unavailable }
        recognizer = r

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // On-device when this device can: the audio never leaves. Otherwise Apple's server does it.
        req.requiresOnDeviceRecognition = r.supportsOnDeviceRecognition
        req.taskHint = .search
        request = req

        do {
            let session = AVAudioSession.sharedInstance()
            // .duckOthers, not .interrupt: whatever they're listening to while reading comes back.
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            sessionActive = true
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else { return .unavailable }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                req.append(buffer)
                let level = Self.level(of: buffer)
                Task { @MainActor in self?.push(level) }
            }
            tapped = true
            engine.prepare()
            try engine.start()
        } catch {
            return .unavailable
        }

        task = r.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.heard = result.bestTranscription.formattedString
                    if result.isFinal { self.final = result }
                }
                // "No speech detected" arrives as an error; end() reads it as nothing heard.
                if error != nil, self.final == nil { self.final = result }
            }
        }
        return nil
    }

    private func stop() {
        capTask?.cancel(); capTask = nil
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        if engine.isRunning { engine.stop() }
        request?.endAudio(); request = nil
        task?.cancel(); task = nil
        recognizer = nil
        live = false
        // Only hand audio back if we took it: a plain tap runs through here too, and it must not
        // so much as blink whatever the user is listening to while they read.
        if sessionActive {
            sessionActive = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func collapse() {
        withAnimation(Motion.state) { hold = 0 }
        heard = ""; settled = false; final = nil
        levels = [CGFloat](repeating: 0, count: Self.samples)
    }

    private func push(_ level: CGFloat) {
        guard hold > 0 else { return }
        let smoothed = max(level, (levels.last ?? 0) * 0.82)   // decay, so silence flattens the line instead of chattering
        levels.removeFirst()
        levels.append(min(1, smoothed))
    }

    // MARK: permissions

    private func authorize() async -> VoiceBlock? {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: break
        case .notDetermined:
            let ok = await withCheckedContinuation { c in
                SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
            }
            guard ok else { return .speechOff }
            _ = await AVAudioApplication.requestRecordPermission()
            return .needsPermission                          // the alert interrupted this hold; the next one works
        default: return .speechOff
        }
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return nil
        case .undetermined:
            _ = await AVAudioApplication.requestRecordPermission()
            return .needsPermission
        default: return .micOff
        }
    }

    #if DEBUG
    /// Dev-only: pose the UI without a microphone, so every voice state can be screenshotted
    /// on a simulator. Never called outside DebugSnapshots.
    func debugPose(hold: CGFloat, heard: String = "", settled: Bool = false, loud: Bool = false) {
        withAnimation(Motion.state) { self.hold = hold }
        self.heard = heard
        self.settled = settled
        levels = (0..<Self.samples).map { i in
            guard loud else { return 0 }
            let t = Double(i) / Double(Self.samples - 1)
            return CGFloat(0.25 + 0.7 * abs(sin(t * 9.1)) * (0.45 + 0.55 * abs(sin(t * 2.3))))
        }
    }
    #endif

    // MARK: audio maths

    /// RMS → 0…1 on a dB curve, so a normal speaking voice fills most of the range.
    private static func level(of buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(buffer.frameLength))
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return CGFloat(min(1, max(0, (db + 50) / 40)))
    }

    private static func meanConfidence(_ r: SFSpeechRecognitionResult) -> Float {
        let segments = r.bestTranscription.segments
        guard !segments.isEmpty else { return 0 }
        return segments.map(\.confidence).reduce(0, +) / Float(segments.count)
    }
}

// MARK: - The rule line that listens

/// The hairline under the input, drawn in pen instead of paper-rule. Silence is a dead-flat line —
/// the same rule that was already there — so speaking is literally the page coming alive.
/// `draw` trims it in as the hold arms; `levels` is the rolling mic history, newest at the right.
struct ListeningRule: Shape {
    var levels: [CGFloat]
    var draw: CGFloat

    func path(in r: CGRect) -> Path {
        let n = levels.count
        guard n > 1 else { return Path() }
        let mid = r.midY, amp = r.height / 2
        var p = Path()
        for i in 0..<n {
            let t = CGFloat(i) / CGFloat(n - 1)
            // Taper at both ends so the line resolves into the rule instead of stopping dead.
            let window = sin(t * .pi)
            let y = mid + levels[i] * amp * window * (i.isMultiple(of: 2) ? 1 : -1)
            let pt = CGPoint(x: r.minX + r.width * t, y: y)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p.trimmedPath(from: 0, to: max(0, min(1, draw)))
    }
}
