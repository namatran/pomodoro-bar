import AppKit
import SwiftUI

/// The app's icon: the idle tomato on a tile of the site's warm light. `build_app.sh` renders it with `--render-icon`.
struct AppIcon: View {
    static let flag = "--render-icon"
    static let size: CGFloat = 1024

    private static let blushWhite = Color(red: 1, green: 0.965, blue: 0.953)
    private static let peach = Color(red: 1, green: 0.84, blue: 0.78)

    var body: some View {
        // Apple's icon grid: an 824pt tile centred on the 1024pt canvas.
        RoundedRectangle(cornerRadius: 185, style: .continuous)
            .fill(LinearGradient(colors: [Self.blushWhite, Self.peach], startPoint: .top, endPoint: .bottom))
            .overlay {
                TomatoView(state: .idle)
                    .frame(width: 600, height: 600)
                    .offset(y: 20)
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
            }
            .frame(width: 824, height: 824)
            .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
            .frame(width: Self.size, height: Self.size)
    }

    /// Writes the icon as a 1024px PNG when launched as `Pomodoro --render-icon <file.png>`, then exits.
    @MainActor
    static func renderIfAsked() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return }
        let renderer = ImageRenderer(content: AppIcon())
        renderer.scale = 1
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
              (try? png.write(to: URL(fileURLWithPath: args[i + 1]))) != nil
        else {
            FileHandle.standardError.write(Data("Couldn't render the icon\n".utf8))
            exit(1)
        }
        exit(0)
    }
}
