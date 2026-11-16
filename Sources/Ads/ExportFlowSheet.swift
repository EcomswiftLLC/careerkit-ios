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
        case adProblem(title: String, message: String, offerPrivacyOptions: Bool)
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
        case unavailable(String)
        case timedOut
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

            Text("Export your resume")
                .font(CK.Font.title(titleSize))
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
        case .adProblem(let title, let message, let offerPrivacyOptions):
            problemContent(title: title, message: message, offerPrivacyOptions: offerPrivacyOptions)
        case .destination:
            destinationContent
        case .finished:
            finishedContent
        }
    }

    // MARK: (a) Explanation

    private var explanationContent: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            Text("Watch one short video to unlock one export of this document. Creating, editing and previewing stay free.")
                .font(CK.Font.body)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: CK.Space.s) {
                Button(action: startAdFlow) {
                    Text("Watch an Ad to Export Free").multilineTextAlignment(.center)
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

    // MARK: (c) Ad unavailable or failed

    private func problemContent(title: String, message: String, offerPrivacyOptions: Bool) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
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

            VStack(spacing: CK.Space.s) {
                Button(action: startAdFlow) { Text("Try again") }
                    .buttonStyle(.ckPrimary)
                if offerPrivacyOptions {
                    Button { ads.presentPrivacyOptions() } label: { Text("Review privacy choices") }
                        .buttonStyle(.ckSecondary)
                }
                Button { dismiss() } label: { Text("Close") }
                    .buttonStyle(.ckSecondary)
            }
        }
    }

    // MARK: (d) Unlocked, choose destination

    private var destinationContent: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            HStack(spacing: CK.Space.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CK.Palette.forest)
                    .accessibilityHidden(true)
                Text("Export unlocked")
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
                    Text("We could not prepare your PDF. Your unlocked export is still available.")
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
            VStack(alignment: .leading, spacing: CK.Space.s) {
                Text("Your export is done")
                    .font(CK.Font.headline())
                    .foregroundStyle(CK.Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Each export uses one short video. To export this document again, you will be asked to watch another one.")
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ckCard()

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
        if gate.hasGrant(for: documentID) { enterDestination() }
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
        guard !Task.isCancelled else { return }

        rewarded.expireIfStale()
        if rewarded.state != .ready { rewarded.load() }

        let outcome = await waitForAd()
        // Only present if the person is still waiting on this screen. They tapped the button; nothing else may start a video.
        guard !Task.isCancelled, phase == .loadingAd else { return }

        switch outcome {
        case .ready:
            let earned = await rewarded.present()
            if earned {
                gate.grant(for: documentID)
                enterDestination()
            } else if rewarded.lastPresentationFailed {
                go(.adProblem(
                    title: String(localized: "Video could not play"),
                    message: String(localized: "Something stopped the video from playing, so this export is still locked. Please try again."),
                    offerPrivacyOptions: false
                ))
            } else {
                go(.adProblem(
                    title: String(localized: "Video not finished"),
                    message: String(localized: "The video was closed before it finished, so this export is still locked. Watch the whole video to unlock it."),
                    offerPrivacyOptions: false
                ))
            }
        case .unavailable(let message):
            go(.adProblem(
                title: String(localized: "Video not available"),
                message: message,
                offerPrivacyOptions: !ads.canRequestAds && ads.privacyOptionsRequired
            ))
        case .timedOut:
            go(.adProblem(
                title: String(localized: "Video not available"),
                message: String(localized: "The video is taking too long to load. Check your internet connection and try again."),
                offerPrivacyOptions: false
            ))
        }
    }

    private func waitForAd() async -> AdWait {
        let deadline = Date().addingTimeInterval(20)
        while !Task.isCancelled {
            switch rewarded.state {
            case .ready:
                return .ready
            case .unavailable(let message):
                return .unavailable(message)
            case .idle:
                rewarded.load()
            case .loading, .presenting:
                break
            }
            if Date() >= deadline { return .timedOut }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return .timedOut
    }

    private func enterDestination() {
        notice = nil
        go(.destination)
        AccessibilityNotification.Announcement(String(localized: "Export unlocked")).post()
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
            show(notice: String(localized: "Nothing was exported. Your unlocked export is still available."))
        case .failed:
            show(notice: String(localized: "Something went wrong, so nothing was exported. Your unlocked export is still available. Please try again."))
        }
    }

    private func show(notice message: String) {
        notice = message
        AccessibilityNotification.Announcement(message).post()
    }
}
