import SwiftUI

/// End-of-game confetti: the game's own shapes drifting down behind the
/// wrap-up card. Pure Canvas, no particle framework.
struct ConfettiView: View {
    var tints: [Card.Tint] = Card.Tint.allCases

    private struct Particle {
        let x: CGFloat          // horizontal position, 0...1
        let size: CGFloat
        let speed: Double       // fall duration divisor
        let phase: Double
        let wobble: Double
        let spin: Double
        let tint: Card.Tint
        let symbol: Card.Symbol
        let opacity: Double
    }

    private let particles: [Particle]
    private let start = Date()

    init(tints: [Card.Tint] = Card.Tint.allCases) {
        self.tints = tints
        particles = (0..<40).map { _ in
            Particle(
                x: .random(in: 0...1),
                size: .random(in: 10...26),
                speed: .random(in: 0.08...0.18),
                phase: .random(in: 0...1),
                wobble: .random(in: 1.2...2.6),
                spin: .random(in: -2...2),
                tint: tints.randomElement()!,
                symbol: Card.Symbol.allCases.randomElement()!,
                opacity: .random(in: 0.5...0.95)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let progress = (t * p.speed + p.phase).truncatingRemainder(dividingBy: 1)
                    let y = progress * (size.height + 2 * p.size) - p.size
                    let x = p.x * size.width + sin(t * p.wobble + p.phase * 10) * 18

                    let rect = CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size)
                    let path = ElementaryShape(symbol: p.symbol).path(in: rect)

                    var layer = context
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(t * p.spin + p.phase * .pi * 2))
                    layer.opacity = p.opacity
                    layer.fill(path, with: .color(p.tint.color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
