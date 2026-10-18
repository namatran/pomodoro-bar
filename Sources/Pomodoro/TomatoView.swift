import SwiftUI

/// Placeholder pet: a flat tomato drawn on a 100×100 grid, until real doodles exist.
struct TomatoView: View {
    private static let red = Color(red: 0.93, green: 0.31, blue: 0.25)
    private static let leaf = Color(red: 0.32, green: 0.62, blue: 0.32)
    private static let stem = Color(red: 0.22, green: 0.45, blue: 0.23)
    private static let ink = Color(red: 0.12, green: 0.10, blue: 0.10)

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 100, y: size.height / 100)

            ctx.fill(Path(ellipseIn: CGRect(x: 6, y: 18, width: 88, height: 78)), with: .color(Self.red))
            ctx.fill(Path(ellipseIn: CGRect(x: 20, y: 30, width: 16, height: 9)), with: .color(.white.opacity(0.35)))

            // Five leaves fanned around the stem.
            for i in 0..<5 {
                var petal = ctx
                petal.translateBy(x: 50, y: 22)
                petal.rotate(by: .degrees(Double(i) * 72 - 90))
                petal.fill(Path(ellipseIn: CGRect(x: 0, y: -3.5, width: 14, height: 7)), with: .color(Self.leaf))
            }
            ctx.fill(Path(roundedRect: CGRect(x: 48, y: 8, width: 4, height: 12), cornerRadius: 2), with: .color(Self.stem))

            // Face.
            ctx.fill(Path(ellipseIn: CGRect(x: 34, y: 50, width: 8, height: 11)), with: .color(Self.ink))
            ctx.fill(Path(ellipseIn: CGRect(x: 58, y: 50, width: 8, height: 11)), with: .color(Self.ink))
            ctx.fill(Path(ellipseIn: CGRect(x: 23, y: 63, width: 12, height: 7)), with: .color(.pink.opacity(0.45)))
            ctx.fill(Path(ellipseIn: CGRect(x: 65, y: 63, width: 12, height: 7)), with: .color(.pink.opacity(0.45)))
            var smile = Path()
            smile.move(to: CGPoint(x: 44, y: 66))
            smile.addQuadCurve(to: CGPoint(x: 56, y: 66), control: CGPoint(x: 50, y: 73))
            ctx.stroke(smile, with: .color(Self.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }
}
