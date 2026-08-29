import SwiftUI

/// A square card. Symbol placement by count: 1 centered, 2 side by side,
/// 3 on the vertices of an equilateral triangle centered in the card.
struct CardView: View {
    let card: Card
    var isSelected = false
    var isDimmed = false

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width

            ZStack {
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(
                        color: .black.opacity(isSelected ? 0.35 : 0.15),
                        radius: isSelected ? side * 0.06 : side * 0.03,
                        y: side * 0.02
                    )
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .strokeBorder(
                        isSelected ? card.tint.color : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 3 : 1
                    )

                symbols(side: side)
            }
            .scaleEffect(isSelected ? 1.06 : 1)
            .opacity(isDimmed ? 0.35 : 1)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func symbols(side: CGFloat) -> some View {
        let s = side * 0.23
        let gap = side * 0.10
        ZStack {
            switch card.count {
            case 1:
                symbol(s)
            case 2:
                let dx = (s + gap) / 2
                symbol(s).offset(x: -dx)
                symbol(s).offset(x: dx)
            default:
                // Centers sit on an equilateral triangle around the card
                // center; the bottom pair ends up exactly `gap` apart.
                let r = (s + gap) / sqrt(3.0)
                let dx = r * sin(.pi / 3)
                symbol(s).offset(y: -r)
                symbol(s).offset(x: -dx, y: r / 2)
                symbol(s).offset(x: dx, y: r / 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func symbol(_ side: CGFloat) -> some View {
        SymbolView(symbol: card.symbol, fill: card.fill, tint: card.tint)
            .frame(width: side, height: side)
    }
}

struct SymbolView: View {
    let symbol: Card.Symbol
    let fill: Card.Fill
    let tint: Card.Tint

    var body: some View {
        GeometryReader { proxy in
            let lineWidth = max(1.5, proxy.size.width * 0.09)
            let shape = ElementaryShape(symbol: symbol)
            // Each fill has its own silhouette logic so they never blur
            // together: solid is all fill and no rim, translucent is a pale
            // wash (or pinstripes, per settings) under a strong rim, outline
            // is the rim alone.
            ZStack {
                switch fill {
                case .solid:
                    shape.fill(tint.gradient)
                case .outline:
                    shape.stroke(tint.color, lineWidth: lineWidth)
                case .translucent:
                    if Appearance.shared.fillStyle == .pinstriped {
                        DiagonalStripes(color: tint.color)
                            .clipShape(shape)
                    } else {
                        shape.fill(tint.color.opacity(0.24))
                    }
                    shape.stroke(tint.color, lineWidth: lineWidth)
                }
            }
            .padding(lineWidth / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct ElementaryShape: Shape {
    let symbol: Card.Symbol

    func path(in rect: CGRect) -> Path {
        switch symbol {
        case .circle:
            return Path(ellipseIn: rect)
        case .square:
            return Path(roundedRect: rect, cornerRadius: rect.width * 0.1)
        case .triangle:
            // Equilateral: height = width * sqrt(3)/2, vertically centered
            // in the square frame.
            let height = rect.width * sqrt(3) / 2
            let top = rect.midY - height / 2
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: top))
            path.addLine(to: CGPoint(x: rect.maxX, y: top + height))
            path.addLine(to: CGPoint(x: rect.minX, y: top + height))
            path.closeSubpath()
            return path
        }
    }
}

/// The pinstriped alternative to the shaded fill: 45-degree stripes with
/// round caps, clipped to the symbol.
struct DiagonalStripes: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let step = max(4, size.width / 5.5)
            let lineWidth = step * 0.42
            var d = -size.height + step / 2
            while d < size.width {
                var line = Path()
                line.move(to: CGPoint(x: d, y: size.height))
                line.addLine(to: CGPoint(x: d + size.height, y: 0))
                context.stroke(
                    line,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                d += step
            }
        }
    }
}

/// Horizontal shake used for mismatched selections.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 7
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travel * sin(animatableData * .pi * shakesPerUnit * 2),
                y: 0
            )
        )
    }
}

#Preview {
    VStack {
        HStack {
            CardView(card: Card(count: 3, tint: .red, symbol: .triangle, fill: .translucent))
            CardView(card: Card(count: 2, tint: .blue, symbol: .circle, fill: .outline), isSelected: true)
            CardView(card: Card(count: 1, tint: .yellow, symbol: .square, fill: .solid))
        }
        HStack {
            CardView(card: Card(count: 3, tint: .blue, symbol: .square, fill: .solid))
            CardView(card: Card(count: 3, tint: .yellow, symbol: .circle, fill: .translucent))
            CardView(card: Card(count: 2, tint: .red, symbol: .triangle, fill: .solid))
        }
    }
    .padding()
}
