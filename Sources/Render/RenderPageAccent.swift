import UIKit

/// Page-level decoration drawn under the content. Vector fills only, so it never changes the text a reader extracts.
enum RenderPageAccent {
    /// Thickness of the bars and strips, in points.
    static let barThickness: CGFloat = 10
    static let edgeThickness: CGFloat = 9
    /// Distance of the frame from the page edge.
    static let frameInset: CGFloat = 16

    static func draw(_ accent: PageAccent, page: CGSize, color: UIColor) {
        switch accent {
        case .none:
            return
        case .topBar:
            RenderDraw.fill(CGRect(x: 0, y: 0, width: page.width, height: barThickness), color)
        case .bottomBar:
            RenderDraw.fill(CGRect(x: 0, y: page.height - barThickness, width: page.width, height: barThickness), color)
        case .leftEdge:
            RenderDraw.fill(CGRect(x: 0, y: 0, width: edgeThickness, height: page.height), color)
        case .frame:
            let outer = CGRect(x: frameInset, y: frameInset, width: page.width - 2 * frameInset, height: page.height - 2 * frameInset)
            RenderDraw.stroke(outer, color, width: 0.9)
            RenderDraw.stroke(outer.insetBy(dx: 3, dy: 3), color, width: 0.4)
        }
    }
}
