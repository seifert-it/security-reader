import SwiftUI

enum RetroTheme {
    static let paper = Color(red: 0.94, green: 0.92, blue: 0.86)
    static let paperDark = Color(red: 0.86, green: 0.84, blue: 0.77)
    static let ink = Color(red: 0.04, green: 0.25, blue: 0.25)
    static let teal = Color(red: 0.08, green: 0.39, blue: 0.38)
    static let mint = Color(red: 0.42, green: 0.68, blue: 0.62)
    static let amber = Color(red: 0.86, green: 0.54, blue: 0.16)
    static let red = Color(red: 0.69, green: 0.18, blue: 0.16)
}

struct PixelBorder: ViewModifier {
    var active = false
    func body(content: Content) -> some View {
        content
            .background(active ? RetroTheme.mint.opacity(0.18) : RetroTheme.paper.opacity(0.45))
            .overlay(Rectangle().stroke(active ? RetroTheme.teal : RetroTheme.ink.opacity(0.22), lineWidth: active ? 2 : 1))
    }
}

extension View {
    func pixelBorder(active: Bool = false) -> some View { modifier(PixelBorder(active: active)) }
}

struct BrandLogo: View {
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "Logo_seifert-it", withExtension: "jpg"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Text("SEIFERT-IT").font(.system(.title2, design: .monospaced).weight(.bold))
            }
        }
    }
}
