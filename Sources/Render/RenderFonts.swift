import UIKit

/// Turns a `FontChoice` into a concrete `UIFont` without ever failing.
/// Unknown or missing families fall back to the system font (serif design for serif choices).
enum RenderFonts {
    private static let installedFamilies: Set<String> = Set(UIFont.familyNames)
    private static let cacheLock = NSLock()
    private static var nameCache: [String: String] = [:]

    static func font(_ choice: FontChoice, size: CGFloat, bold: Bool = false, italic: Bool = false) -> UIFont {
        let safeSize: CGFloat = max(1, size)
        switch choice {
        case .sfPro:
            // The system font already falls back to PingFang for Chinese.
            return systemFont(size: safeSize, bold: bold, italic: italic, serif: false)
        case .newYork:
            return withCJKCascade(systemFont(size: safeSize, bold: bold, italic: italic, serif: true), serif: true, bold: bold)
        default:
            if let family = choice.familyName,
               let found = familyFont(family: family, size: safeSize, bold: bold, italic: italic) {
                return withCJKCascade(found, serif: choice.isSerif, bold: bold)
            }
            return withCJKCascade(systemFont(size: safeSize, bold: bold, italic: italic, serif: choice.isSerif),
                                  serif: choice.isSerif, bold: bold)
        }
    }

    // MARK: Chinese fallback

    /// Template fonts (Georgia, Didot, Futura...) have no Chinese glyphs. An explicit cascade list makes Core Text
    /// draw those characters in a matching Chinese face instead of leaving the choice to the system: Songti for
    /// serif templates when the device has it, PingFang otherwise. Latin text keeps the template font.
    static func withCJKCascade(_ font: UIFont, serif: Bool, bold: Bool) -> UIFont {
        let names: [String] = cascadeNames(serif: serif, bold: bold)
        guard !names.isEmpty else { return font }
        let cascade: [UIFontDescriptor] = names.map { UIFontDescriptor(fontAttributes: [UIFontDescriptor.AttributeName.name: $0]) }
        let descriptor: UIFontDescriptor = font.fontDescriptor.addingAttributes([UIFontDescriptor.AttributeName.cascadeList: cascade])
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    /// Installed Chinese faces in order of preference. Names that are not installed are left out.
    static func cascadeNames(serif: Bool, bold: Bool) -> [String] {
        switch (serif, bold) {
        case (true, true): return cascadeSerifBold
        case (true, false): return cascadeSerifRegular
        case (false, true): return cascadeSansBold
        case (false, false): return cascadeSansRegular
        }
    }

    private static func installed(_ names: [String]) -> [String] {
        return names.filter { UIFont(name: $0, size: 12) != nil }
    }

    private static let cascadeSansRegular: [String] = installed(["PingFangSC-Regular", "STHeitiSC-Light", "HiraginoSans-W3"])
    private static let cascadeSansBold: [String] = installed(["PingFangSC-Semibold", "STHeitiSC-Medium", "HiraginoSans-W6"])
    private static let cascadeSerifRegular: [String] = installed(["STSongti-SC-Regular", "PingFangSC-Regular", "STHeitiSC-Light"])
    private static let cascadeSerifBold: [String] = installed(["STSongti-SC-Bold", "PingFangSC-Semibold", "STHeitiSC-Medium"])

    // MARK: System fonts

    private static func systemFont(size: CGFloat, bold: Bool, italic: Bool, serif: Bool) -> UIFont {
        let weight: UIFont.Weight = bold ? UIFont.Weight.bold : UIFont.Weight.regular
        let base: UIFont = UIFont.systemFont(ofSize: size, weight: weight)
        var descriptor: UIFontDescriptor = base.fontDescriptor
        if serif, let designed = descriptor.withDesign(UIFontDescriptor.SystemDesign.serif) {
            descriptor = designed
        }
        if italic {
            var traits: UIFontDescriptor.SymbolicTraits = descriptor.symbolicTraits
            traits.insert(UIFontDescriptor.SymbolicTraits.traitItalic)
            if let withItalic = descriptor.withSymbolicTraits(traits) {
                descriptor = withItalic
            }
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    // MARK: Named families

    private static func familyFont(family: String, size: CGFloat, bold: Bool, italic: Bool) -> UIFont? {
        guard installedFamilies.contains(family) else { return nil }
        let key: String = family + "|" + (bold ? "b" : "r") + (italic ? "i" : "u")

        cacheLock.lock()
        let cached: String? = nameCache[key]
        cacheLock.unlock()

        if let name = cached, let font = UIFont(name: name, size: size) {
            return font
        }
        guard let picked = pickFontName(family: family, bold: bold, italic: italic),
              let font = UIFont(name: picked, size: size) else {
            return nil
        }
        cacheLock.lock()
        nameCache[key] = picked
        cacheLock.unlock()
        return font
    }

    private static func pickFontName(family: String, bold: Bool, italic: Bool) -> String? {
        let names: [String] = UIFont.fontNames(forFamilyName: family)
        var best: String? = nil
        var bestScore: Int = Int.min
        let unwanted: [String] = ["light", "thin", "heavy", "black", "condensed", "compressed", "ultra", "extra", "demi", "medium", "semi"]

        for name in names {
            guard let probe = UIFont(name: name, size: 12) else { continue }
            let traits: UIFontDescriptor.SymbolicTraits = probe.fontDescriptor.symbolicTraits
            let isBold: Bool = traits.contains(UIFontDescriptor.SymbolicTraits.traitBold)
            let isItalic: Bool = traits.contains(UIFontDescriptor.SymbolicTraits.traitItalic)
            var score: Int = 0
            if isBold == bold { score += 100 }
            if isItalic == italic { score += 100 }
            let lower: String = name.lowercased()
            for word in unwanted where lower.contains(word) {
                score -= 30
            }
            if bold && lower.hasSuffix("bold") { score += 10 }
            if !bold && !italic && (lower.contains("regular") || lower.contains("roman") || !lower.contains("-")) {
                score += 10
            }
            let better: Bool
            if score > bestScore {
                better = true
            } else if score == bestScore, let current = best {
                better = name.count < current.count
            } else {
                better = false
            }
            if better {
                best = name
                bestScore = score
            }
        }
        return best
    }
}
