// The app's seeded randomness, bit for bit: SplitMix64 (WordWheelLevels.swift) and Swift's
// `shuffled(using:)` — Fisher–Yates over `next(upperBound:)` (Lemire's multiply-high with rejection).
// Scripts/check-web-games.mjs holds this to the app's own output for 800 days.
const M = (1n << 64n) - 1n;

export class SplitMix64 {
  constructor(seed) { this.state = BigInt(seed) & M; }
  next() {
    this.state = (this.state + 0x9E3779B97F4A7C15n) & M;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & M;
    z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & M;
    return z ^ (z >> 31n);
  }
  /// A uniform integer in 0..<bound, as Swift's RandomNumberGenerator.next(upperBound:) draws it.
  below(bound) {
    const b = BigInt(bound);
    let m = this.next() * b;
    if ((m & M) < b) {
      const t = ((1n << 64n) - b) % b;
      while ((m & M) < t) m = this.next() * b;
    }
    return Number(m >> 64n);
  }
}

/// Swift's MutableCollection.shuffle(using:), on a copy.
export function shuffled(array, rng) {
  const a = array.slice();
  for (let i = 0, left = a.length; left > 1; i++, left--) {
    const j = i + rng.below(left);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
