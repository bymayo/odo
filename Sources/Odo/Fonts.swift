import SwiftUI
import CoreText

/// Switzer, Odo's typeface. The files ship in Odo.app/Contents/Resources/Fonts
/// (Scripts/fetch-fonts.sh downloads them; they aren't in the repo). Anywhere
/// they're missing, such as `swift run`, text falls back to the system font.
enum Fonts {
    private(set) static var available = false
    /// General Sans Semibold, used only for the ODO wordmark (as on the website)
    private(set) static var wordmarkAvailable = false

    /// Registers the bundled fonts for this process. Call once, before any UI.
    static func register(from directory: URL? = Bundle.main.resourceURL?.appendingPathComponent("Fonts")) {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        let fonts = files.filter { ["otf", "ttf"].contains($0.pathExtension.lowercased()) }
        guard !fonts.isEmpty else { return }
        CTFontManagerRegisterFontURLs(fonts as CFArray, .process, false, nil)
        available = NSFont(name: "Switzer-Regular", size: 12) != nil
        wordmarkAvailable = NSFont(name: "GeneralSans-Semibold", size: 12) != nil
    }

    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .medium: return "Switzer-Medium"
        case .semibold: return "Switzer-Semibold"
        case .bold: return "Switzer-Bold"
        case .heavy: return "Switzer-Extrabold"
        case .black: return "Switzer-Black"
        default: return "Switzer-Regular"
        }
    }
}

extension Font {
    /// Switzer at a fixed size; the system font when Switzer isn't installed
    static func odo(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard Fonts.available else { return .system(size: size, weight: weight) }
        return .custom(Fonts.name(for: weight), fixedSize: size)
    }
}

/// The app's name as set on odo.bymayo.co.uk: ODO in General Sans Semibold,
/// capitals, tracked out by 0.01em. Use it wherever the name stands as a logo.
struct Wordmark: View {
    var size: CGFloat
    var color: Color = Theme.ink

    var body: some View {
        Text("ODO")
            .font(Fonts.wordmarkAvailable
                  ? .custom("GeneralSans-Semibold", fixedSize: size)
                  : .odo(size: size, weight: .semibold))
            .tracking(size * 0.01)
            .foregroundColor(color)
            .accessibilityLabel("Odo")
    }
}
