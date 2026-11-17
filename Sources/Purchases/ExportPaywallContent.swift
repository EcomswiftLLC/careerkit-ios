import SwiftUI

/// The choices shown when an export needs an export pack, Premium or a video.
/// Prices come from the store. Nothing here can unlock an export by itself: it only reports taps.
struct ExportPaywallContent: View {
    @ObservedObject var store: ExportStore
    /// Whether the "watch a video" choice is shown.
    let offersVideo: Bool
    /// A short result of the last action (pending approval, could not buy, nothing to restore).
    let status: String?
    let onBuy: (String) -> Void
    let onWatchVideo: () -> Void
    let onRestore: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            Text("Editing and previewing are free. Saving, sharing or printing a file uses one export.")
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
                }

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

            Text("Export packs are used up one export at a time. Premium is a single purchase with no limit, and Restore purchases brings it back on a new device.")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
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

        case .unavailable:
            VStack(alignment: .leading, spacing: CK.Space.m) {
                Text("Prices are not available")
                    .font(CK.Font.headline())
                    .foregroundStyle(CK.Palette.ink)
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
                        .font(CK.Font.headline(18))
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
                    Text(verbatim: product.displayPrice)
                        .font(CK.Font.label)
                        .foregroundStyle(emphasised ? CK.Palette.onForest : CK.Palette.ink)
                        .padding(.horizontal, CK.Space.m)
                        .frame(minHeight: 36)
                        .background(
                            Capsule().fill(emphasised ? CK.Palette.forest : CK.Palette.stone)
                        )
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
