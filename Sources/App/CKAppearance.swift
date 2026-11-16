import SwiftUI
import UIKit

/// One-time UIKit appearance setup: serif navigation titles, ivory bars with hairline edges.
/// Colours are rebuilt here as dynamic UIColors (same hex values as `CK.Palette`) so bars
/// follow light and dark mode without relying on a Color to UIColor conversion.
enum CKAppearance {
    private static var didConfigure = false

    static func configure() {
        guard !didConfigure else { return }
        didConfigure = true

        let ivory = dynamic(light: 0xFAF7F0, dark: 0x141614)
        let hairline = dynamic(light: 0xDDD6C8, dark: 0x343935)
        let ink = dynamic(light: 0x1F2421, dark: 0xF2EFE8)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: serif(17, .semibold),
            .foregroundColor: ink
        ]
        let largeAttributes: [NSAttributedString.Key: Any] = [
            .font: serif(34, .semibold),
            .foregroundColor: ink
        ]

        let standard = UINavigationBarAppearance()
        let scrollEdge = UINavigationBarAppearance()

        if usesSystemGlass {
            // Newest OS: keep the system bar material and only set the type.
            standard.configureWithDefaultBackground()
            scrollEdge.configureWithDefaultBackground()
        } else {
            standard.configureWithOpaqueBackground()
            standard.backgroundColor = ivory
            standard.shadowColor = hairline
            scrollEdge.configureWithOpaqueBackground()
            scrollEdge.backgroundColor = ivory
            scrollEdge.shadowColor = .clear
        }
        for appearance in [standard, scrollEdge] {
            appearance.titleTextAttributes = titleAttributes
            appearance.largeTitleTextAttributes = largeAttributes
        }
        UINavigationBar.appearance().standardAppearance = standard
        UINavigationBar.appearance().compactAppearance = standard
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge

        if !usesSystemGlass {
            let tab = UITabBarAppearance()
            tab.configureWithOpaqueBackground()
            tab.backgroundColor = ivory
            tab.shadowColor = hairline
            UITabBar.appearance().standardAppearance = tab
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
    }

    private static var usesSystemGlass: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
    }

    private static func serif(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }
}
