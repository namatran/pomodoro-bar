import SwiftUI

/// Placeholder pet: a flat tomato drawn on a 100×100 grid, with a face for each state, until real doodles exist.
struct TomatoView: View {
    let state: PetState

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

            ctx.fill(Path(ellipseIn: CGRect(x: 23, y: 63, width: 12, height: 7)), with: .color(.pink.opacity(0.45)))
            ctx.fill(Path(ellipseIn: CGRect(x: 65, y: 63, width: 12, height: 7)), with: .color(.pink.opacity(0.45)))
            drawFace(in: ctx)
        }
    }

    private func drawFace(in ctx: GraphicsContext) {
        let line = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        func stroke(_ points: [CGPoint], control: CGPoint? = nil) {
            var path = Path()
            path.move(to: points[0])
            if let control {
                path.addQuadCurve(to: points[1], control: control)
            } else {
                path.addLines(points)
            }
            ctx.stroke(path, with: .color(Self.ink), style: line)
        }
        func eyes(height: CGFloat, y: CGFloat) {
            ctx.fill(Path(ellipseIn: CGRect(x: 34, y: y, width: 8, height: height)), with: .color(Self.ink))
            ctx.fill(Path(ellipseIn: CGRect(x: 58, y: y, width: 8, height: height)), with: .color(Self.ink))
        }

        switch state {
        case .idle:
            eyes(height: 11, y: 50)
            stroke([CGPoint(x: 44, y: 66), CGPoint(x: 56, y: 66)], control: CGPoint(x: 50, y: 73))
        case .focus:
            // Narrowed eyes under slanted brows, mouth set flat.
            eyes(height: 8, y: 53)
            stroke([CGPoint(x: 31, y: 46), CGPoint(x: 43, y: 50)])
            stroke([CGPoint(x: 69, y: 46), CGPoint(x: 57, y: 50)])
            stroke([CGPoint(x: 45, y: 67), CGPoint(x: 55, y: 67)])
        case .onBreak:
            // Relaxed, closed eyes.
            stroke([CGPoint(x: 33, y: 55), CGPoint(x: 43, y: 55)], control: CGPoint(x: 38, y: 60))
            stroke([CGPoint(x: 57, y: 55), CGPoint(x: 67, y: 55)], control: CGPoint(x: 62, y: 60))
            stroke([CGPoint(x: 46, y: 66), CGPoint(x: 54, y: 66)], control: CGPoint(x: 50, y: 70))
        case .celebrate:
            // ^ ^ eyes and an open grin.
            stroke([CGPoint(x: 33, y: 57), CGPoint(x: 38, y: 51), CGPoint(x: 43, y: 57)])
            stroke([CGPoint(x: 57, y: 57), CGPoint(x: 62, y: 51), CGPoint(x: 67, y: 57)])
            var grin = Path()
            grin.move(to: CGPoint(x: 42, y: 64))
            grin.addLine(to: CGPoint(x: 58, y: 64))
            grin.addQuadCurve(to: CGPoint(x: 42, y: 64), control: CGPoint(x: 50, y: 78))
            ctx.fill(grin, with: .color(Self.ink))
        }
    }
}
