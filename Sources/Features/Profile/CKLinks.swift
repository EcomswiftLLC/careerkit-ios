import Foundation

/// Every outbound link and address in one place.
enum CKLinks {
    static let privacy = URL(string: "https://ecomswiftllc.github.io/careerkit/privacy")!
    static let terms = URL(string: "https://ecomswiftllc.github.io/careerkit/terms")!
    static let productPage = URL(string: "https://ecomswiftllc.github.io/careerkit")!
    static let supportEmail = "support@ecomswiftllc.com"

    /// App Store write-a-review page when `CKAppStoreID` exists in Info.plist, otherwise the product page.
    /// The id is the numeric Apple ID of the app in App Store Connect. The in-app purchases use StoreKit (see
    /// `Sources/Purchases`), but the review link is a plain URL, so this file does not need StoreKit.
    static var reviewURL: URL {
        if let id = Bundle.main.object(forInfoDictionaryKey: "CKAppStoreID") as? String,
           !id.trimmingCharacters(in: .whitespaces).isEmpty,
           let url = URL(string: "https://apps.apple.com/app/id\(id)?action=write-review") {
            return url
        }
        return productPage
    }

    static func mailto(subject: String, body: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        var items = [URLQueryItem(name: "subject", value: subject)]
        if let body { items.append(URLQueryItem(name: "body", value: body)) }
        components.queryItems = items
        return components.url
    }

    static var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
