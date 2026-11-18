import SwiftUI

/// The choices shown when an export needs an export pack, Premium or a video.
/// Prices come from the store. Nothing here can unlock an export by itself: it only reports taps.
/// When the store has no products to sell (`catalogState == .noProducts`) it does not talk about buying at all: no
/// pack, no Premium, no Restore purchases. It says so plainly and keeps the video, and the free export when no video
/// is configured.
struct ExportPaywallContent: View {
    @ObservedObject var store: ExportStore
    /// Whether the "watch a video" choice is shown.
    let offersVideo: Bool
    /// A short result of the last action (pending approval, could not buy, nothing to restore).
    let status: String?
    let onBuy: (String) -> Void
    let onWatchVideo: () -> Void
    /// The free export for a store with no products. Only shown when no video can be offered at all.
    let onExportWithoutVideo: () -> Void
    let onRestore: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            Text(store.offersPurchases
                 ? String(localized: "Editing and previewing are free. Saving, sharing or printing a file uses one export.")
                 : String(localized: "Editing and previewing are free. You can still save, share or print without buying anything."))
                .font(CK.Font.body)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)

            choices

            if let status = status {
                Text(status)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CK.Space.m)
                    .background(RoundedRectangle(cornerRadius: CK.Radius.chip + 4, style: .continuous).fill(CK.Palette.stone))
                    .accessibilityIdentifier("export.paywall.status")
            }

            VStack(spacing: CK.Space.s) {
                if offersVideo {
                    Button(action: onWatchVideo) {
                        Text("Watch a short video to export once").multilineTextAlignment(.center)
                    }
                    .buttonStyle(.ckSecondary)
                    .disabled(store.isBusy)
                    .accessibilityIdentifier("export.paywall.video")
                } else if store.allowsExportWithoutVideo {
                    Button(action: onExportWithoutVideo) {
                        Text("Export without video").multilineTextAlignment(.center)
                    }
                    .buttonStyle(.ckPrimary)
                    .accessibilityIdentifier("export.paywall.free")
                }

                if store.offersPurchases {
                    Button(action: onRestore) {
                        HStack(spacing: CK.Space.s) {
                            if store.isRestoring { ProgressView() }
                            Text("Restore purchases")
                        }
                        .font(CK.Font.label)
                        .foregroundStyle(CK.Palette.forest)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isBusy)
                    .accessibilityIdentifier("export.paywall.restore")
                }

                Button(action: onNotNow) {
                    Text("Not now")
                        .font(CK.Font.label)
                        .foregroundStyle(CK.Palette.graphite)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("export.paywall.notnow")
            }

            if store.offersPurchases {
                Text("Export packs are used up one export at a time. Premium is a single purchase with no limit, and Restore purchases brings it back on a new device.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Choices

    @ViewBuilder
    private var choices: some View {
        switch store.catalogState {
        case .idle, .loading:
            HStack(spacing: CK.Space.m) {
                ProgressView()
                Text("Checking prices")
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ckCard()
            .accessibilityElement(children: .combine)

        case .noProducts:
            VStack(alignment: .leading, spacing: CK.Space.m) {
                Text("Purchases are not available right now")
                    .ckHeadlineFont(19)
                    .foregroundStyle(CK.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("You can try again later. Nothing was charged.")
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await store.loadProducts() }
                } label: {
                    Text("Try again")
                }
                .buttonStyle(.ckSecondary)
                .accessibilityIdentifier("export.paywall.retry")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ckCard()

        case .unavailable:
            VStack(alignment: .leading, spacing: CK.Space.m) {
                Text("Prices are not available")
                    .ckHeadlineFont(19)
                    .foregroundStyle(CK.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("The App Store could not be reached. Check your connection and try again. Nothing was charged.")
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await store.loadProducts() }
                } label: {
                    Text("Try again")
                }
                .buttonStyle(.ckSecondary)
                .accessibilityIdentifier("export.paywall.retry")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ckCard()

        case .ready:
            VStack(spacing: CK.Space.s + 2) {
                if let pack = store.pack {
                    optionRow(
                        product: pack,
                        title: String(localized: "3 exports"),
                        detail: String(localized: "A one-time purchase. Each file you save, share or print uses one."),
                        symbol: "doc.on.doc",
                        emphasised: true,
                        accessibilityLabel: String(localized: "3 exports, \(pack.displayPrice)")
                    )
                }
                if let premium = store.premium {
                    optionRow(
                        product: premium,
                        title: String(localized: "Premium"),
                        detail: String(localized: "Unlimited exports in every file type. One purchase, no subscription."),
                        symbol: "infinity",
                        emphasised: false,
                        accessibilityLabel: String(localized: "Premium, unlimited exports, \(premium.displayPrice)")
                    )
                }
            }
        }
    }

    private func optionRow(product: StoreProduct, title: String, detail: String, symbol: String, emphasised: Bool, accessibilityLabel: String) -> some View {
        let busyHere = store.busyProductID == product.id
        return Button {
            onBuy(product.id)
        } label: {
            HStack(alignment: .center, spacing: CK.Space.m) {
                ZStack {
                    Circle().fill(CK.Palette.forest.opacity(emphasised ? 0.14 : 0.08))
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CK.Palette.forest)
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .ckHeadlineFont(18)
                        .foregroundStyle(CK.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: CK.Space.s)

                if busyHere {
                    ProgressView()
                } else {
                    // The price may wrap at large text sizes or in long currency formats, so it is never cut off.
                    Text(verbatim: product.displayPrice)
                        .font(CK.Font.label)
                        .foregroundStyle(emphasised ? CK.Palette.onForest : CK.Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, CK.Space.m)
                        .padding(.vertical, CK.Space.s - 2)
                        .frame(minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(emphasised ? CK.Palette.forest : CK.Palette.stone)
                        )
                        .layoutPriority(1)
                }
            }
            .padding(CK.Space.m)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous)
                    .strokeBorder(emphasised ? CK.Palette.forest : CK.Palette.hairline, lineWidth: emphasised ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isBusy)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text("Opens the App Store purchase sheet"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("export.paywall.buy.\(product.id)")
    }
}
