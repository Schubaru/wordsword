import Foundation
#if canImport(UIKit)
import AVFoundation
import SwiftUI
#endif

/// How a word is said. Both halves are free and ride along on lookups we already make:
/// - `respelling` — readable phonetics ("SANG-gwin"), converted from the Arpabet Datamuse returns
///   with `md=r`. Near-total coverage, no extra request.
/// - `audio` — a human recording from dictionaryapi.dev when it has one, which is often not.
///   `Speaker` falls back to the system voice, so "hear it" never comes up empty.
struct Pronunciation: Sendable {
    var respelling: String
    var audio: URL?

    /// A respelling identical to the spelling teaches nothing — "sit" → "sit". Show nothing instead.
    static func worthShowing(_ respelling: String?, for word: String) -> String? {
        guard let r = respelling, r.lowercased() != word.lowercased() else { return nil }
        return r
    }
}

/// Arpabet → newspaper respelling. `S AE1 NG G W IH0 N` → `SANG-gwin`:
/// stressed syllable in caps, the rest lowercase, hyphens between.
enum Arpabet {
    static func respell(_ raw: String) -> String? {
        let phones = raw.split(separator: " ").map(String.init)
        guard !phones.isEmpty else { return nil }

        // "AE1" → base "AE", stress 1. Consonants carry no digit.
        var base: [String] = [], stress: [Int] = []
        for p in phones {
            if let d = p.last, d.isNumber { base.append(String(p.dropLast())); stress.append(d.wholeNumberValue ?? 0) }
            else { base.append(p); stress.append(-1) }
        }
        let nuclei = base.indices.filter { vowel[base[$0]] != nil }
        guard !nuclei.isEmpty, base.allSatisfy({ vowel[$0] != nil || consonant[$0] != nil }) else { return nil }

        // Onset-maximal: of the consonants between two vowels, the longest legal onset goes to the
        // second syllable, the rest close the first. NG G W → ng | gw, so "sanguine" breaks SANG-gwin.
        var starts = [0]
        for k in 1..<nuclei.count {
            let run = Array((nuclei[k - 1] + 1)..<nuclei[k])
            var onset = 0
            if run.count >= 2, legalOnsets.contains("\(base[run[run.count - 2]]) \(base[run[run.count - 1]])") { onset = 2 }
            else if let last = run.last, base[last] != "NG" { onset = 1 }
            // ...but a stressed lax vowel has to be closed, or the open syllable reads long:
            // "dynamic" split dy-NA-mik says "nay". Hand one consonant back to be its coda.
            let prev = nuclei[k - 1]
            if stress[prev] == 1, lax.contains(base[prev]), run.count - onset == 0 { onset = max(0, onset - 1) }
            starts.append(nuclei[k] - onset)
        }

        let syllables = starts.indices.map { k -> String in
            let end = k + 1 < starts.count ? starts[k + 1] : base.count
            let n = nuclei[k]
            var out = ""
            for i in starts[k]..<end {
                if i == n {
                    // /aɪ/ is "eye" on its own, "y" once something precedes it: eye-duhl, but dy-NAM-ik.
                    out += base[i] == "AY" && i == starts[k] ? "eye" : (vowel[base[i]] ?? "")
                } else {
                    out += consonant[base[i]] ?? ""
                }
            }
            return out
        }
        guard !syllables.contains(where: \.isEmpty) else { return nil }
        guard syllables.count > 1 else { return syllables[0] }   // nothing to contrast, so no shouting

        var primary = nuclei.firstIndex { stress[$0] == 1 } ?? 0
        if primary >= syllables.count { primary = 0 }
        return syllables.enumerated()
            .map { $0.offset == primary ? $0.element.uppercased() : $0.element }
            .joined(separator: "-")
    }

    private static let vowel = [
        "AA": "ah", "AE": "a", "AH": "uh", "AO": "aw", "AW": "ow", "AY": "y", "EH": "e",
        "ER": "ur", "EY": "ay", "IH": "i", "IY": "ee", "OW": "oh", "OY": "oy", "UH": "oo", "UW": "oo",
    ]
    private static let consonant = [
        "B": "b", "CH": "ch", "D": "d", "DH": "th", "F": "f", "G": "g", "HH": "h", "JH": "j",
        "K": "k", "L": "l", "M": "m", "N": "n", "NG": "ng", "P": "p", "R": "r", "S": "s",
        "SH": "sh", "T": "t", "TH": "th", "V": "v", "W": "w", "Y": "y", "Z": "z", "ZH": "zh",
    ]
    /// Checked vowels: they cannot end a syllable, so they always keep a coda.
    private static let lax: Set<String> = ["AE", "EH", "IH", "AH", "UH"]
    private static let legalOnsets: Set<String> = [
        "B L", "B R", "K L", "K R", "D R", "F L", "F R", "G L", "G R", "P L", "P R", "T R",
        "TH R", "SH R", "S K", "S L", "S M", "S N", "S P", "S T", "S W", "K W", "G W", "T W",
        "D W", "HH W", "S F", "V R", "P Y", "B Y", "K Y", "G Y", "F Y", "HH Y", "M Y", "V Y",
        "D Y", "T Y", "N Y", "L Y", "S Y",
    ]

    #if DEBUG
    /// The whole of the phonetics logic in one runnable check.
    static func selfCheck() {
        let cases = [
            "S AE1 NG G W IH0 N": "SANG-gwin",          // the onset-maximal split
            "W AO1 T ER0": "WAW-tur",
            "AH1 N D ER0": "UHN-dur",                   // "nd" is no onset, so it splits
            "Y UW0 B IH1 K W AH0 T AH0 S": "yoo-BIK-wuh-tuhs",   // lax IH1 keeps the k
            "G AO1 N T": "gawnt",                       // one syllable: never shouted
            "AY1 D AH0 L": "EYE-duhl",         // stressed, so it shouts; "y" only once something precedes it
            "D AY0 N AE1 M IH0 K": "dy-NAM-ik",         // not dy-NA-mik
        ]
        for (pron, want) in cases {
            let got = respell(pron)
            assert(got == want, "respell(\(pron)) = \(got ?? "nil"), wanted \(want)")
        }
        assert(respell("") == nil)
        assert(respell("S T") == nil)                   // no vowel, no syllable
        assert(respell("S QQ1 T") == nil)               // unknown phone, rather than a hole in the word
    }
    #endif
}

#if canImport(UIKit)
/// Says the word out loud. A human recording when dictionaryapi.dev has one; the system voice when
/// it doesn't, which is often — so "hear it" is never a dead button.
///
/// Only ever plays on an explicit tap. Never on appear: `DefineView` re-mounts its headword when a
/// chain is resumed, and a word spoken at someone who didn't ask is worse than silence.
@MainActor @Observable final class Speaker: NSObject {
    static let shared = Speaker()
    /// The word currently sounding, so its button can show it.
    private(set) var speaking: String?

    private var player: AVAudioPlayer?
    private let synth = AVSpeechSynthesizer()

    func say(_ word: String, recording: URL?) {
        stop()
        speaking = word
        Task {
            if let recording, let data = try? await recorded(recording), let p = try? AVAudioPlayer(data: data) {
                guard speaking == word else { return }   // tapped something else while it downloaded
                session(true)
                player = p; p.delegate = self; p.play()
            } else {
                speak(word)
            }
        }
    }

    /// Warm the cache while the definition is being read, so the tap plays instead of waiting.
    func prefetch(_ url: URL?) {
        guard let url else { return }
        Task { _ = try? await recorded(url) }
    }

    private func recorded(_ url: URL) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else { throw URLError(.badServerResponse) }
        return data
    }

    private func speak(_ word: String) {
        session(true)
        let u = AVSpeechUtterance(string: word)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9   // a word alone, said clearly
        synth.delegate = self
        synth.speak(u)
    }

    private func stop() {
        player?.stop(); player = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speaking = nil
        session(false)
    }

    /// Same discipline as `VoiceListener`: duck whatever they're reading to, and hand it straight back.
    private func session(_ active: Bool) {
        let s = AVAudioSession.sharedInstance()
        if active {
            try? s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? s.setActive(true)
        } else {
            try? s.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func finished() { speaking = nil; player = nil; session(false) }
}

extension Speaker: AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully: Bool) {
        Task { @MainActor in finished() }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in finished() }
    }
}

/// How the word is said, sitting under the headword: quiet ink-2 type, the recording one tap away.
struct PronunciationLine: View {
    let word: String
    let respelling: String?
    let audio: URL?

    var body: some View {
        if let r = Pronunciation.worthShowing(respelling, for: word) {
            // Last baseline, not centre: at accessibility sizes the respelling wraps, and a
            // centred speaker strands itself between the two lines instead of trailing the word.
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(r).font(.pron).foregroundStyle(Color.ink2)
                SpeakerButton(word: word, audio: audio)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pronounced \(r)")
            .accessibilityHint("Hear it")
        }
    }
}

/// The speaker on its own, for surfaces whose own tap is already spoken for — the flashcard flips.
struct SpeakerButton: View {
    let word: String
    let audio: URL?
    @State private var speaker = Speaker.shared

    private var playing: Bool { speaker.speaking == word }

    var body: some View {
        Button { speaker.say(word, recording: audio) } label: {
            Image(systemName: playing ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.footnote.weight(.medium))
                .foregroundStyle(playing ? Color.pen : Color.ink2)
                // 44pt of target inside a 20pt footprint: the padding is transparent and the
                // headword above it isn't tappable, so the overlap costs nothing.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .padding(-12)
                .animation(Motion.feedback, value: playing)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Hear \(word)")
    }
}
#endif
