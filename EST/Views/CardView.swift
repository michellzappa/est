import SwiftUI

/// A square card. Symbol layout by count: 1 centered, 2 side by side,
/// 3 in a triangle (one on top, two below).
struct CardView: View {
    let card: Card
    var isSelected = false
    var isDimmed = false

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            let symbolSide = side * 0.26
            let spacing = side * 0.08

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

                switch card.count {
                case 1:
                    symbol(side: symbolSide)
                case 2:
                    HStack(spacing: spacing) {
                        symbol(side: symbolSide)
                        symbol(side: symbolSide)
                    }
                default:
                    VStack(spacing: spacing * 0.6) {
                        symbol(side: symbolSide)
                        HStack(spacing: spacing) {
                            symbol(side: symbolSide)
                            symbol(side: symbolSide)
                        }
                    }
                }
            }
            .scaleEffect(isSelected ? 1.06 : 1)
            .opacity(isDimmed ? 0.35 : 1)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func symbol(side: CGFloat) -> some View {
        SymbolView(symbol: card.symbol, fill: card.fill, color: card.tint.color)
            .frame(width: side, height: side)
    }
}

struct SymbolView: View {
    let symbol: Card.Symbol
    let fill: Card.Fill
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let lineWidth = max(1.5, proxy.size.width * 0.09)
            let shape = ElementaryShape(symbol: symbol)
            ZStack {
                switch fill {
                case .solid:
                    shape.fill(color)
                case .outline:
                    EmptyView()
                case .striped:
                    Stripes(color: color)
                        .clipShape(shape)
                }
                shape.stroke(color, lineWidth: lineWidth)
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
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

struct Stripes: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let step = max(3, size.width / 7)
            var x = step / 2
            while x < size.width {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(color), lineWidth: max(1, step * 0.3))
                x += step
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
    HStack {
        CardView(card: Card(count: 3, tint: .red, symbol: .triangle, fill: .striped))
        CardView(card: Card(count: 2, tint: .blue, symbol: .circle, fill: .outline), isSelected: true)
        CardView(card: Card(count: 1, tint: .yellow, symbol: .square, fill: .solid))
    }
    .padding()
}
