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
}

private struct ExportedFile {
    let url: URL
    let directory: URL
    let data: Data
}

/// The whole export experience for one document: explanation, one opt-in video, then Share, Save to Files or Print.
/// When no video can be provided after the person asked for one, the export continues without a video
/// (see `ExportFallbackPolicy`), so there is never a dead end.
/// Needs `ExportGate` in the environment (injected at the app root).
@MainActor
struct ExportFlowSheet: View {
    let documentID: UUID
    let fileName: String
    let renderedProvider: () -> RenderedDocument

    init(documentID: UUID, fileName: String, renderedProvider: @escaping () -> RenderedDocument) {
        self.documentID = documentID
        self.fileName = fileName
        self.renderedProvider = renderedProvider
    }

    private enum Phase: Equatable {
        case explanation
        case loadingAd
        case noVideo(RewardedUnavailableReason)
        case notFinished
        case destination
        case finished
    }

    private enum FileState: Equatable {
        case preparing
        case ready(url: URL, data: Data)
        case failed
    }

    private enum AdWait {
        case ready
        case unavailable(RewardedUnavailableReason)
    }

    @EnvironmentObject private var gate: ExportGate
    @ObservedObject private var ads = AdsManager.shared
    @StateObject private var rewarded = RewardedAdController(preload: false)
    @StateObject private var runner = ExportActionRunner()
    @StateObject private var session = ExportSession()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 26

    @State private var phase: Phase = .explanation
    @State private var fileState: FileState = .preparing
    @State private var notice: String?
    @State private var destinationBusy = false
    @State private var didAppear = false
    @State private var unlockedWithoutVideo = false

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CK.Space.l) {
                header
                content
            }
            .padding(.horizontal, CK.Space.l)
            .padding(.top, CK.Space.xl)
            .padding(.bottom, CK.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CK.Palette.ivory.ignoresSafeArea())
        .presentationDetents([.medium, .large])
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

            Text("Export as PDF")
                .ckTitleFont(titleSize)
                .foregroundStyle(CK.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .explanation:
            explanationContent
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

    // MARK: (a) Explanation

    private var explanationContent: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            Text("Watch one short video to export this document once. After the video, the export stays unlocked for 24 hours, so you can finish later. Creating, editing and previewing stay free.")
                .font(CK.Font.body)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: CK.Space.s) {
                Button(action: startAdFlow) {
                    Text("Watch an ad to export").multilineTextAlignment(.center)
                }
                .buttonStyle(.ckPrimary)

                Button { dismiss() } label: {
                    Text("Not now")
                }
                .buttonStyle(.ckSecondary)
            }

            Text("The video only starts after you tap the button above.")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    // MARK: (c) No video could be provided: export without one

    private func noVideoContent(_ reason: RewardedUnavailableReason) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            messageCard(title: String(localized: "No video right now"), message: reason.exportMessage)

            VStack(spacing: CK.Space.s) {
                Button(action: exportWithoutVideo) {
                    Text("Export without video").multilineTextAlignment(.center)
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
        unlockedWithoutVideo ? String(localized: "Ready to export") : String(localized: "Export unlocked")
    }

    private var destinationContent: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            HStack(spacing: CK.Space.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CK.Palette.forest)
                    .accessibilityHidden(true)
                Text(unlockedTitle)
                    .font(CK.Font.label)
                    .foregroundStyle(CK.Palette.ink)
                Spacer(minLength: 0)
            }
            .ckCard()
            .accessibilityElement(children: .combine)

            switch fileState {
            case .preparing:
                HStack(spacing: CK.Space.m) {
                    ProgressView()
                    Text("Preparing your PDF")
                        .font(CK.Font.body)
                        .foregroundStyle(CK.Palette.graphite)
                }
                .accessibilityElement(children: .combine)

            case .failed:
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    Text("We could not prepare your PDF. Your export is still available.")
                        .font(CK.Font.body)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: prepareFile) { Text("Try again") }
                        .buttonStyle(.ckPrimary)
                }

            case .ready(let url, let data):
                VStack(alignment: .leading, spacing: CK.Space.s) {
                    Text("Choose where to send your PDF.")
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

                    Button {
                        perform { done in
                            runner.printPDF(data: data, jobName: url.deletingPathExtension().lastPathComponent, completion: done)
                        }
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                    .buttonStyle(.ckSecondary)
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
                message: String(localized: "To export this document again, tap Export. Each new export starts with one short video when one is available.")
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
        // A valid grant from earlier (for example a cancelled share) skips straight to the destination step.
        if gate.hasGrant(for: documentID) {
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
        go(.explanation)
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
            unlockedWithoutVideo = false
            enterDestination()
        case .offerExportWithoutVideo(let reason):
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

    /// The fallback: no video could be provided after the person asked for one, so this one export is granted.
    private func exportWithoutVideo() {
        session.adTask?.cancel()
        session.adTask = nil
        gate.grant(for: documentID)
        unlockedWithoutVideo = true
        enterDestination()
    }

    private func enterDestination() {
        notice = nil
        go(.destination)
        AccessibilityNotification.Announcement(unlockedTitle).post()
        prepareFile()
    }

    // MARK: Rendering and destinations

    private func prepareFile() {
        session.renderTask?.cancel()
        fileState = .preparing
        let box = ProviderBox(provider: renderedProvider)
        let baseName = ExportFileName.sanitized(fileName)
        let session = self.session
        session.renderTask = Task {
            let result: Result<ExportedFile, Error> = await Task.detached(priority: .userInitiated) { () -> Result<ExportedFile, Error> in
                do {
                    let document = box.provider()
                    guard !document.pdfData.isEmpty else { throw ExportFileError.emptyDocument }
                    let written = try ExportFileWriter.write(pdfData: document.pdfData, baseName: baseName)
                    return .success(ExportedFile(url: written.url, directory: written.directory, data: document.pdfData))
                } catch {
                    return .failure(error)
                }
            }.value

            switch result {
            case .success(let file):
                session.directories.append(file.directory)
                if Task.isCancelled { return }
                fileState = .ready(url: file.url, data: file.data)
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
        switch outcome {
        case .completed:
            // The grant is used up only now that the system reported a finished export.
            gate.consume(for: documentID)
            go(.finished)
        case .cancelled:
            show(notice: String(localized: "Nothing was exported. Your export is still available."))
        case .failed:
            show(notice: String(localized: "Something went wrong, so nothing was exported. Your export is still available. Please try again."))
        }
    }

    private func show(notice message: String) {
        notice = message
        AccessibilityNotification.Announcement(message).post()
    }
}
