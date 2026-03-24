import SwiftUI

/// Deterministic pseudo-random gradient cover based on a seed string (e.g. item ID).
/// Produces soft mesh gradients similar to Zvuk's generated playlist covers.
struct GeneratedCoverView: View {
    let seed: String

    var body: some View {
        let rng = SeededRNG(seed: seed)
        let palette = rng.palette()

        MeshGradient(
            width: 3, height: 3,
            points: rng.meshPoints(),
            colors: palette
        )
        .overlay {
            // Subtle "glow" spot like Zvuk covers
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette[4].opacity(0.6), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .scaleEffect(1.2)
                .offset(x: rng.cgFloat(in: -30...30), y: rng.cgFloat(in: -30...30))
        }
    }
}

// MARK: - Seeded RNG

/// Simple deterministic RNG seeded from a string hash.
private final class SeededRNG {
    private var state: UInt64

    init(seed: String) {
        // FNV-1a hash
        var hash: UInt64 = 14695981039346656037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        self.state = hash
    }

    /// xorshift64
    func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    func double(in range: ClosedRange<Double> = 0...1) -> Double {
        let raw = Double(next() % 10000) / 10000.0
        return range.lowerBound + raw * (range.upperBound - range.lowerBound)
    }

    func cgFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(double(in: Double(range.lowerBound)...Double(range.upperBound)))
    }

    // MARK: - Palette generation

    func palette() -> [Color] {
        // Pick a base hue, then build 9 colors with slight hue/saturation variation
        let baseHue = double()
        let hueSpread = double(in: 0.05...0.18)

        return (0..<9).map { i in
            let hueOffset = double(in: -hueSpread...hueSpread)
            let hue = (baseHue + hueOffset).truncatingRemainder(dividingBy: 1.0)
            let sat = double(in: 0.3...0.6)
            let bri = double(in: 0.65...0.9)
            _ = i // used implicitly via sequential `next()` calls
            return Color(hue: hue < 0 ? hue + 1 : hue, saturation: sat, brightness: bri)
        }
    }

    // MARK: - Mesh points

    func meshPoints() -> [SIMD2<Float>] {
        // 3x3 grid with slight jitter for organic feel
        var points: [SIMD2<Float>] = []
        for row in 0..<3 {
            for col in 0..<3 {
                let baseX = Float(col) / 2.0
                let baseY = Float(row) / 2.0
                let jitter: Float = 0.12
                let jx = (row == 0 || row == 2 || col == 0 || col == 2)
                    ? 0 : Float(double(in: Double(-jitter)...Double(jitter)))
                let jy = (row == 0 || row == 2 || col == 0 || col == 2)
                    ? 0 : Float(double(in: Double(-jitter)...Double(jitter)))
                points.append(SIMD2(baseX + jx, baseY + jy))
            }
        }
        return points
    }
}
