import SwiftUI

/// Icon, title and optional detail used by every settings row.
struct CKSettingsRow: View {
    let systemImage: String
    let title: String
    var detail: String? = nil
    var showsChevron = false
    var trailingSymbol: String? = nil
    var tint: Color = CK.Palette.forest
    var isDestructive = false
    var isBusy = false

    var body: some View {
        HStack(spacing: CK.Space.m) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.opacity(0.10))
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CK.Font.body)
                    .foregroundStyle(isDestructive ? CK.Palette.danger : CK.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if isBusy {
                ProgressView()
                    .accessibilityHidden(true)
            } else if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CK.Palette.graphite)
                    .accessibilityHidden(true)
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CK.Palette.graphite)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
