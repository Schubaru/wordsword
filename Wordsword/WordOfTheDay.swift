import Foundation

/// Curated, reader-flavored. Cycles by day of year. Edit freely — order is the schedule.
enum WordOfTheDay {
    static var today: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return words[(day - 1) % words.count]
    }

    static let words = [
        "ephemeral", "sanguine", "laconic", "ineffable", "mellifluous", "petrichor", "sonder", "liminal",
        "halcyon", "vestige", "penumbra", "quixotic", "serendipity", "taciturn", "verdant", "wistful",
        "zephyr", "ebullient", "gossamer", "insouciant", "languid", "luminous", "nascent", "obfuscate",
        "palimpsest", "querulous", "reticent", "sonorous", "tenuous", "ubiquitous", "vicarious", "winsome",
        "aberration", "bucolic", "cacophony", "denouement", "elegy", "furtive", "garrulous", "hubris",
        "iconoclast", "juxtapose", "kismet", "lugubrious", "maudlin", "nebulous", "ostensible", "pernicious",
        "quiescent", "raconteur", "surreptitious", "trepidation", "umbrage", "vociferous", "wanton", "yearn",
        "abscond", "belie", "capricious", "diaphanous", "equanimity", "fastidious", "grandiloquent", "harbinger",
        "idyllic", "jejune", "kaleidoscopic", "lachrymose", "mercurial", "nonchalant", "opulent", "perfunctory",
        "quotidian", "recalcitrant", "sagacious", "torpid", "unctuous", "verisimilitude", "wry", "zeitgeist",
        "acumen", "bombastic", "candor", "desultory", "ennui", "fecund", "gregarious", "histrionic",
        "impetuous", "jocular", "kinetic", "lithe", "moribund", "noisome", "obsequious", "paucity",
        "quandary", "ruminate", "somnolent", "truculent", "usurp", "vapid", "wizened", "abstruse",
        "beguile", "circumspect", "dilatory", "effervescent", "florid", "gambol", "hapless", "impunity",
        "labyrinthine", "melancholy", "nefarious", "oblique", "propitious", "redolent", "sublime", "temerity",
        "unfettered", "voracious", "waft", "ardent", "brusque", "cloying", "doleful", "enigmatic",
    ]
}
