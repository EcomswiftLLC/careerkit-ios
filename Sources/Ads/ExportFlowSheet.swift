import SwiftUI
import UIKit

/// Holds work that must be cancelled and temp files that must be removed when the sheet is really gone.
/// Deliberately not tied to onDisappear: UIKit sheets and full-screen ads can trigger that while the flow is still running.
final class ExportSession: ObservableObject {
    var adTask: Task<Void, Never>?
    var renderTask: Task<Void, Never>?
    var directories: [URL] = []

    deinit {
        adTask?.cancel()
        renderTask?.cancel()
        for directory in directories {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private struct ProviderBox: @unchecked Sendable {
    let provider: () -> RenderedDocument
    let source: ExportSource?
}

private struct ExportedFile {
    let url: URL
    let directory: URL
    let data: Data
}

/// The whole export experience for one document: file type, the export gate, then Share, Save to Files
/// or Print (Print for PDF only).
/// The gate: Premium, a purchased export, or one opt-in video unlocks the export. With none of them, the sheet shows
/// the choices. A missing video or an unreachable store never unlocks anything.
/// An export is used up only after the system reports that the file was really shared, saved or printed.
/// The video grant is per document, not per format: one unlock covers one completed export in any format.
/// Needs `ExportGate` and `ExportStore` in the environment (injected at the app root).
@MainActor
struct ExportFlowSheet: View {
    let documentID: UUID
    let fileName: String
    let renderedProvider: () -> RenderedDocument
    /// The models behind the document. nil means only PDF can be offered (older call sites).
    let source: ExportSource?

    /// PDF only, from an already rendered document.
    init(documentID: UUID, fileName: String, renderedProvider: @escaping () -> RenderedDocument) {
        self.documentID = documentID
        self.fileName = fileName
        self.renderedProvider = renderedProvider
        self.source = nil
    }

    /// Every format in `DocumentExportFormat`.
    init(documentID: UUID, fileName: String, source: ExportSource) {
        self.documentID = documentID
        self.fileName = fileName
        self.source = source
        self.renderedProvider = { DocumentExporter.renderPDF(source) }
    }

    private enum Phase: Equatable {
        case paywall
        case loadingAd
        case noVideo(RewardedUnavailableReason)
        case notFinished
        case destination
        case finished
    }

    private enum FileState: Equatable {
        case preparing
        case ready(url: URL, data: Data, format: DocumentExportFormat)
        case failed
    }

    private enum AdWait {
        case ready
        case unavailable(RewardedUnavailableReason)
    }

    @EnvironmentObject private var gate: ExportGate
    @EnvironmentObject private var exportStore: ExportStore
    @ObservedObject private var ads = AdsManager.shared
    @StateObject private var rewarded = RewardedAdController(preload: false)
    @StateObject private var runner = ExportActionRunner()
    @StateObject private var session = ExportSession()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .paywall
    @State private var fileState: FileState = .preparing
    @State private var notice: String?
    @State private var destinationBusy = false
    @State private var didAppear = false
    /// How this export was unlocked, for the wording on the destination and the finished screens.
    @State private var unlockedBy: ExportAccess = .adGrant
    /// A short result of the last purchase or restore, shown on the paywall.
    @State private var paywallStatus: String?
    /// What the finished screen says about what is left.
    @State private var finishedMessage: String = ""
    @State private var detent: PresentationDetent = .large
    /// The format picked last time, remembered on this device.
    @AppStorage(DocumentExportFormat.storageKey) private var storedFormat: String = DocumentExportFormat.defaultFormat.rawValue

    // MARK: Format

    private var availableFormats: [DocumentExportFormat] {
        source == nil ? [.pdf] : DocumentExportFormat.allCases
    }

    private var format: DocumentExportFormat {
        let wanted: DocumentExportFormat = DocumentExportFormat.stored(storedFormat)
        return availableFormats.contains(wanted) ? wanted : .pdf
    }

    private var showsFormatPicker: Bool {
        guard availableFormats.count > 1 else { return false }
        switch phase {
        case .paywall, .noVideo, .notFinished, .destination:
            return true
        case .loadingAd, .finished:
            return false
        }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CK.Space.l) {
                header
                if showsFormatPicker {
                    formatPicker
                }
                content
            }
            .padding(.horizontal, CK.Space.l)
            .padding(.top, CK.Space.xl)
            .padding(.bottom, CK.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CK.Palette.ivory.ignoresSafeArea())
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CK.Radius.sheet)
        .interactiveDismissDisabled(phase == .loadingAd)
        .onAppear(perform: handleAppear)
        .onDisappear { rewarded.cancelRetries() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            ZStack {
                Circle().fill(CK.Palette.forest.opacity(0.12))
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CK.Palette.forest)
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)

            Text("Export as \(format.noun)")
                .ckTitleFont(26)
                .foregroundStyle(CK.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: File type picker

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            Text("File type")
                .font(CK.Font.label)
                .foregroundStyle(CK.Palette.ink)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: CK.Space.xs) {
                ForEach(availableFormats) { option in
                    formatRow(option)
                }
            }
        }
        .disabled(destinationBusy)
    }

    private func formatRow(_ option: DocumentExportFormat) -> some View {
        let selected: Bool = option == format
        return Button {
            select(option)
        } label: {
            HStack(alignment: .center, spacing: CK.Space.m) {
                Image(systemName: option.systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(selected ? CK.Palette.forest : CK.Palette.graphite)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(CK.Font.label)
                        .foregroundStyle(CK.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(option.shortDescription)
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(selected ? CK.Palette.forest : CK.Palette.hairline)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, CK.Space.m)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? CK.Palette.forest.opacity(0.08) : CK.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? CK.Palette.forest : CK.Palette.hairline, lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.displayName))
        .accessibilityValue(Text(option.shortDescription))
        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits.isButton)
        .accessibilityIdentifier("export.format.\(option.rawValue)")
    }

    private func select(_ option: DocumentExportFormat) {
        guard option != format, !destinationBusy else { return }
        storedFormat = option.rawValue
        notice = nil
        // A file that is already prepared is for the old format, so make the new one.
        if phase == .destination {
            prepareFile(as: option)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .paywall:
            paywallContent
        case .loadingAd:
            loadingContent
        case .noVideo(let reason):
            noVideoContent(reason)
        case .notFinished:
            notFinishedContent
        case .destination:
            destinationContent
        case .finished:
            finishedContent
        }
    }

    // MARK: (a) The choices

    private var paywallContent: some View {
        ExportPaywallContent(
            store: exportStore,
            offersVideo: AdsConfiguration.rewardedUnitID != nil,
            status: paywallStatus,
            onBuy: { productID in buy(productID) },
            onWatchVideo: startAdFlow,
            onRestore: restorePurchases,
            onNotNow: { dismiss() }
        )
    }

    // MARK: (b) Loading

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            HStack(spacing: CK.Space.m) {
                ProgressView()
                Text("Getting your video ready")
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ckCard()
            .accessibilityElement(children: .combine)

            Button(action: cancelAdFlow) { Text("Cancel") }
                .buttonStyle(.ckSecondary)
        }
    }

    // MARK: (c) No video could be provided

    private func noVideoContent(_ reason: RewardedUnavailableReason) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            messageCard(
                title: String(localized: "No video right now"),
                message: reason.exportMessage + " " + String(localized: "You can try again, or use an export pack or Premium.")
            )

            VStack(spacing: CK.Space.s) {
                Button { showPaywall() } label: {
                    Text("See export options").multilineTextAlignment(.center)
                }
                .buttonStyle(.ckPrimary)

                if reason != .notConfigured {
                    Button(action: startAdFlow) { Text("Try the video again") }
                        .buttonStyle(.ckSecondary)
                }
                if ExportFallbackPolicy.offersPrivacyOptions(for: reason, privacyOptionsRequired: ads.privacyOptionsRequired) {
                    Button { ads.presentPrivacyOptions() } label: { Text("Review privacy choices") }
                        .buttonStyle(.ckSecondary)
                }
                Button { dismiss() } label: { Text("Not now") }
                    .buttonStyle(.ckSecondary)
            }
        }
    }

    // MARK: (d) Video closed early

    private var notFinishedContent: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            messageCard(
                title: String(localized: "Video not finished"),
                message: String(localized: "The video was closed before the end, so this export is still locked. You can watch it again from the start.")
            )

            VStack(spacing: CK.Space.s) {
                Button(action: startAdFlow) { Text("Watch again") }
                    .buttonStyle(.ckPrimary)
                Button { showPaywall() } label: { Text("See export options") }
                    .buttonStyle(.ckSecondary)
                Button { dismiss() } label: { Text("Not now") }
                    .buttonStyle(.ckSecondary)
            }
        }
    }

    private func messageCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            Text(title)
                .font(CK.Font.headline())
                .foregroundStyle(CK.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(CK.Font.body)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ckCard()
    }

    // MARK: (e) Unlocked, choose destination

    private var unlockedTitle: String {
        unlockedBy == .adGrant ? String(localized: "Export unlocked") : String(localized: "Ready to export")
    }

    /// One line under the title that says what this export uses.
    private var unlockedDetail: String? {
        switch unlockedBy {
        case .premium:
            return String(localized: "Premium has no limit on exports.")
        case .credit:
            let count: Int = exportStore.credits
            return String(localized: "You have \(count) exports. This one uses 1.")
        case .adGrant, .locked:
            return nil
        }
    }

    private var destinationContent: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            HStack(spacing: CK.Space.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CK.Palette.forest)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(unlockedTitle)
                        .font(CK.Font.label)
                        .foregroundStyle(CK.Palette.ink)
                    if let detail = unlockedDetail {
                        Text(detail)
                            .font(CK.Font.caption)
                            .foregroundStyle(CK.Palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .ckCard()
            .accessibilityElement(children: .combine)

            switch fileState {
            case .preparing:
                HStack(spacing: CK.Space.m) {
                    ProgressView()
                    Text("Preparing your \(format.noun)")
                        .font(CK.Font.body)
                        .foregroundStyle(CK.Palette.graphite)
                }
                .accessibilityElement(children: .combine)

            case .failed:
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    Text("We could not prepare your \(format.noun). Your export is still available.")
                        .font(CK.Font.body)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { prepareFile() } label: { Text("Try again") }
                        .buttonStyle(.ckPrimary)
                }

            case .ready(let url, let data, let readyFormat):
                VStack(alignment: .leading, spacing: CK.Space.s) {
                    Text("Choose where to send your \(readyFormat.noun).")
                        .font(CK.Font.body)
                        .foregroundStyle(CK.Palette.graphite)
                        .padding(.bottom, CK.Space.xs)

                    Button { perform { done in runner.share(url: url, completion: done) } } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.ckPrimary)

                    Button { perform { done in runner.saveToFiles(url: url, completion: done) } } label: {
                        Label("Save to Files", systemImage: "folder")
                    }
                    .buttonStyle(.ckSecondary)

                    if readyFormat.supportsPrint {
                        Button {
                            perform { done in
                                runner.printPDF(data: data, jobName: url.deletingPathExtension().lastPathComponent, completion: done)
                            }
                        } label: {
                            Label("Print", systemImage: "printer")
                        }
                        .buttonStyle(.ckSecondary)
                    } else {
                        Text("To print, choose PDF above. It keeps your page layout exactly.")
                            .font(CK.Font.caption)
                            .foregroundStyle(CK.Palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, CK.Space.xs)
                    }
                }
                .disabled(destinationBusy)
            }

            if let notice = notice {
                Text(notice)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var finishedContent: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            messageCard(
                title: String(localized: "Your export is done"),
                message: finishedMessage
            )

            Button { dismiss() } label: { Text("Done") }
                .buttonStyle(.ckPrimary)
        }
    }

    // MARK: Flow

    private func go(_ next: Phase) {
        if reduceMotion {
            phase = next
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { phase = next }
        }
    }

    private func handleAppear() {
        guard !didAppear else { return }
        didAppear = true
        // Premium, an export from a pack, or a valid video grant from earlier (for example a cancelled share)
        // skips straight to the destination step.
        let access = exportStore.access(for: documentID, gate: gate)
        if access.isOpen {
            unlockedBy = access
            enterDestination()
        } else {
            // Load in the background so the video is ready when the person taps. Nothing plays without that tap.
            rewarded.preload()
        }
    }

    private func startAdFlow() {
        session.adTask?.cancel()
        notice = nil
        go(.loadingAd)
        session.adTask = Task { await runAdFlow() }
    }

    private func cancelAdFlow() {
        session.adTask?.cancel()
        session.adTask = nil
        go(.paywall)
    }

    private func showPaywall() {
        session.adTask?.cancel()
        session.adTask = nil
        notice = nil
        go(.paywall)
    }

    // MARK: Buying

    private func buy(_ productID: String) {
        guard !exportStore.isBusy else { return }
        paywallStatus = nil
        Task {
            let outcome = await exportStore.purchase(productID)
            switch outcome {
            case .purchased:
                let access = exportStore.access(for: documentID, gate: gate)
                if access.isOpen {
                    unlockedBy = access
                    enterDestination()
                } else {
                    setStatus(String(localized: "The purchase went through, but it could not be added yet. Tap Restore purchases in a moment."))
                }
            case .pending:
                setStatus(String(localized: "Your purchase is waiting for approval. The export will be available once it is approved."))
            case .cancelled:
                break
            case .unverified:
                setStatus(String(localized: "The App Store could not confirm this purchase, so nothing was added. Nothing was charged."))
            case .failed:
                setStatus(String(localized: "The purchase did not go through. Check your connection and try again."))
            }
        }
    }

    private func restorePurchases() {
        guard !exportStore.isBusy else { return }
        paywallStatus = nil
        Task {
            let outcome = await exportStore.restore()
            switch outcome {
            case .premiumActive:
                let access = exportStore.access(for: documentID, gate: gate)
                if access.isOpen {
                    unlockedBy = access
                    enterDestination()
                }
            case .nothingFound:
                setStatus(String(localized: "No Premium purchase was found for this Apple Account. Export packs are used up and cannot be restored."))
            case .failed:
                setStatus(String(localized: "Purchases could not be restored right now. Check your connection and try again."))
            }
        }
    }

    private func setStatus(_ message: String) {
        paywallStatus = message
        AccessibilityNotification.Announcement(message).post()
    }

    private func runAdFlow() async {
        if !ads.canRequestAds { await ads.start() }
        guard !Task.isCancelled, phase == .loadingAd else { return }

        let outcome = await obtainVideoOutcome()
        // Only act if the person is still waiting on this screen.
        guard !Task.isCancelled, phase == .loadingAd else { return }

        switch ExportFallbackPolicy.decision(for: outcome) {
        case .unlock:
            gate.grant(for: documentID)
            unlockedBy = exportStore.access(for: documentID, gate: gate)
            enterDestination()
        case .videoUnavailable(let reason):
            go(.noVideo(reason))
            AccessibilityNotification.Announcement(reason.exportMessage).post()
        case .offerWatchAgain:
            go(.notFinished)
        }
    }

    private func obtainVideoOutcome() async -> ExportVideoOutcome {
        rewarded.expireIfStale()
        switch await waitForAd() {
        case .unavailable(let reason):
            return .unavailable(reason)
        case .ready:
            break
        }
        // They tapped the button; nothing else may start a video.
        guard !Task.isCancelled, phase == .loadingAd else { return .closedEarly }
        let earned = await rewarded.present()
        if earned { return .earned }
        return rewarded.lastPresentationFailed ? .unavailable(.couldNotPresent) : .closedEarly
    }

    /// Waits for a loaded video. Retries one plain load failure, then reports why no video is available.
    private func waitForAd() async -> AdWait {
        let deadline = Date().addingTimeInterval(ExportFallbackPolicy.adWaitTimeout)
        var attempts = 0
        switch rewarded.state {
        case .ready:
            return .ready
        case .loading:
            attempts = 1
        case .idle, .unavailable, .presenting:
            attempts = 1
            rewarded.load()
        }
        while !Task.isCancelled {
            switch rewarded.state {
            case .ready:
                return .ready
            case .unavailable:
                let reason = rewarded.unavailableReason ?? .loadFailed
                if ExportFallbackPolicy.shouldRetryLoad(after: reason, attemptsSoFar: attempts) {
                    attempts += 1
                    rewarded.load()
                } else {
                    return .unavailable(reason)
                }
            case .idle:
                rewarded.load()
            case .loading, .presenting:
                break
            }
            if Date() >= deadline { return .unavailable(.timedOut) }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return .unavailable(.timedOut)
    }

    private func enterDestination() {
        notice = nil
        go(.destination)
        AccessibilityNotification.Announcement(unlockedTitle).post()
        prepareFile()
    }

    // MARK: Rendering and destinations

    private func prepareFile() {
        prepareFile(as: format)
    }

    /// Builds the file off the main thread and writes it to a fresh `CareerKitExport-` temp folder.
    /// The folder is removed when the sheet goes away (`ExportSession`) or by `CKTempFiles` at the next launch.
    private func prepareFile(as chosen: DocumentExportFormat) {
        session.renderTask?.cancel()
        fileState = .preparing
        let box = ProviderBox(provider: renderedProvider, source: source)
        let baseName = ExportFileName.sanitized(fileName)
        let session = self.session
        session.renderTask = Task {
            let result: Result<ExportedFile, Error> = await Task.detached(priority: .userInitiated) { () -> Result<ExportedFile, Error> in
                do {
                    let bytes: Data
                    if let source = box.source {
                        bytes = try DocumentExporter.export(source, as: chosen)
                    } else {
                        bytes = box.provider().pdfData
                    }
                    guard !bytes.isEmpty else { throw ExportFileError.emptyDocument }
                    let format: DocumentExportFormat = box.source == nil ? .pdf : chosen
                    let written = try ExportFileWriter.write(data: bytes, baseName: baseName, format: format)
                    return .success(ExportedFile(url: written.url, directory: written.directory, data: bytes))
                } catch {
                    return .failure(error)
                }
            }.value

            switch result {
            case .success(let file):
                session.directories.append(file.directory)
                if Task.isCancelled { return }
                let readyFormat: DocumentExportFormat = box.source == nil ? .pdf : chosen
                fileState = .ready(url: file.url, data: file.data, format: readyFormat)
            case .failure:
                if Task.isCancelled { return }
                fileState = .failed
            }
        }
    }

    private func perform(_ action: (@escaping (ExportOutcome) -> Void) -> Void) {
        guard !destinationBusy else { return }
        destinationBusy = true
        notice = nil
        action { outcome in
            destinationBusy = false
            handle(outcome)
        }
    }

    private func handle(_ outcome: ExportOutcome) {
        // Review prompt bookkeeping (Sources/App/ReviewPrompt.swift). Never shows anything by itself here.
        ReviewPromptCenter.shared.exportFinished(outcome)
        switch outcome {
        case .completed:
            // The export is used up only now that the system reported a finished export.
            let spent = exportStore.settle(outcome, for: documentID, gate: gate)
            finishedMessage = finishedText(after: spent)
            go(.finished)
        case .cancelled:
            show(notice: String(localized: "Nothing was exported. Your export is still available."))
        case .failed:
            show(notice: String(localized: "Something went wrong, so nothing was exported. Your export is still available. Please try again."))
        }
    }

    private func finishedText(after spent: ExportSpend) -> String {
        if exportStore.isPremium {
            return String(localized: "To export again, tap Export. Premium has no limit.")
        }
        if spent == .credit {
            let count: Int = exportStore.credits
            if count > 0 {
                return String(localized: "You have \(count) exports left.")
            }
            return String(localized: "That was your last export. You can get more the next time you export.")
        }
        return String(localized: "To export this document again, tap Export.")
    }

    private func show(notice message: String) {
        notice = message
        AccessibilityNotification.Announcement(message).post()
    }
}
