import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var ads: AdsManager
    @EnvironmentObject private var exportGate: ExportGate
    @EnvironmentObject private var exportStore: ExportStore
    @Environment(\.openURL) private var openURL

    @State private var path: [AppRoute] = []
    @State private var shareItem: ProfileShareItem?
    @State private var showDeleteFirst = false
    @State private var showDeleteFinal = false
    @State private var showImporter = false
    @State private var isRestoring = false
    @State private var showQuarantineOptions = false
    @State private var showQuarantineDelete = false
    @State private var showResult = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var toast: String?
    /// Temporary files to remove once the share sheet closes (the backup copy).
    @State private var pendingCleanup: [URL] = []
    @StateObject private var bannerSlot = BannerAdSlot()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                profileSection
                documentsSection
                dataSection
                adsAndExportsSection
                legalSection
                supportSection
                aboutSection
                bannerSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .ckScreen()
            .appRouteDestinations()
            .sheet(item: $shareItem, onDismiss: removeSharedTempFiles) { item in
                CKShareSheet(items: item.urls)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog(
                "Delete all local data?",
                isPresented: $showDeleteFirst,
                titleVisibility: .visible
            ) {
                Button("Export a backup first") { exportBackup() }
                Button("Continue", role: .destructive) {
                    CKDeferred.afterDismiss { showDeleteFinal = true }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every resume and cover letter stored in CareerKit on this device, including unreadable files and saved video unlocks. Purchases are kept.")
            }
            .alert("Delete everything permanently?", isPresented: $showDeleteFinal) {
                Button("Delete everything", role: .destructive) { deleteEverything() }
                Button("Keep my data", role: .cancel) {}
            } message: {
                Text("Your resumes, cover letters and drafts cannot be recovered afterwards unless you saved a backup file.")
            }
            .ckToast($toast)
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [UTType.json],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert(resultTitle, isPresented: $showResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: Sections

    private var profileSection: some View {
        Section {
            HStack(spacing: CK.Space.m) {
                ZStack {
                    Circle().fill(CK.Palette.stone)
                    if let initial = appState.greetingName.first {
                        Text(String(initial).uppercased())
                            .font(CK.Font.title(24))
                            .foregroundStyle(CK.Palette.forest)
                    } else {
                        Image(systemName: "person")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(CK.Palette.forest)
                    }
                }
                .frame(width: 60, height: 60)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Your name (optional)", text: $appState.displayName)
                        .font(CK.Font.headline(19))
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .frame(minHeight: 44)
                    Text("Kept on this device. Used only for the greeting on Home.")
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                }
            }
            .listRowBackground(CK.Palette.surface)
        }
    }

    private var documentsSection: some View {
        Section {
            Picker(selection: $appState.defaultPageSize) {
                ForEach(PageSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            } label: {
                CKSettingsRow(systemImage: "doc.plaintext", title: String(localized: "Default paper size"))
            }
            .pickerStyle(.menu)
            .listRowBackground(CK.Palette.surface)

            VStack(alignment: .leading, spacing: CK.Space.s + 2) {
                CKSettingsRow(systemImage: "circle.lefthalf.filled", title: String(localized: "Appearance"))
                Picker("Appearance", selection: $appState.appearance) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, CK.Space.xs)
            .listRowBackground(CK.Palette.surface)
        } header: {
            sectionHeader("Documents and display")
        } footer: {
            Text("The paper size is used for new documents. Existing ones keep their own size.")
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                exportBackup()
            } label: {
                CKSettingsRow(systemImage: "square.and.arrow.up", title: String(localized: "Export backup"), detail: String(localized: "Save a copy of everything"), showsChevron: true)
            }
            .accessibilityHint(Text("Creates one backup file and opens the share sheet"))
            .listRowBackground(CK.Palette.surface)

            Button {
                showImporter = true
            } label: {
                CKSettingsRow(systemImage: "square.and.arrow.down",
                              title: String(localized: "Restore from backup"),
                              detail: String(localized: "Add documents from a backup file"),
                              showsChevron: true,
                              isBusy: isRestoring)
            }
            .disabled(isRestoring)
            .accessibilityHint(Text("Choose a CareerKit backup file. Documents already on this device are kept."))
            .listRowBackground(CK.Palette.surface)

            if !store.quarantinedFiles.isEmpty {
                quarantineRow
            }

            if store.newerVersionFileCount > 0 {
                newerVersionRow
            }

            Button(role: .destructive) {
                showDeleteFirst = true
            } label: {
                CKSettingsRow(systemImage: "trash", title: String(localized: "Delete all local data"), tint: CK.Palette.danger, isDestructive: true)
            }
            .accessibilityHint(Text("Asks you to confirm twice before anything is deleted"))
            .listRowBackground(CK.Palette.surface)
        } header: {
            sectionHeader("Your data")
        } footer: {
            Text(dataSummary)
        }
    }

    private var quarantineRow: some View {
        let count: Int = store.quarantinedFiles.count
        let title: String = String(localized: "\(count) documents could not be opened")
        return Button {
            showQuarantineOptions = true
        } label: {
            CKSettingsRow(systemImage: "exclamationmark.triangle",
                          title: title,
                          detail: String(localized: "Kept aside so nothing is lost. Export or delete the files."),
                          showsChevron: true)
        }
        .accessibilityHint(Text("Shows options to export or delete the unreadable files"))
        .listRowBackground(CK.Palette.surface)
        .confirmationDialog("Unreadable documents", isPresented: $showQuarantineOptions, titleVisibility: .visible) {
            Button("Export the files") { exportQuarantinedFiles() }
            Button("Delete the files", role: .destructive) {
                CKDeferred.afterDismiss { showQuarantineDelete = true }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These files were damaged or could not be read. Export them to keep a copy or to send to support.")
        }
        .alert("Delete the unreadable files?", isPresented: $showQuarantineDelete) {
            Button("Delete files", role: .destructive) { deleteQuarantinedFiles() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They cannot be recovered afterwards. Your other documents are not affected.")
        }
    }

    private var newerVersionRow: some View {
        let count: Int = store.newerVersionFileCount
        let title: String = String(localized: "\(count) documents were made with a newer version of CareerKit")
        return CKSettingsRow(systemImage: "arrow.up.circle",
                             title: title,
                             detail: String(localized: "Update CareerKit from the App Store to open them. They are kept unchanged."))
            .accessibilityElement(children: .combine)
            .listRowBackground(CK.Palette.surface)
    }

    private var adsAndExportsSection: some View {
        Section {
            CKSettingsRow(systemImage: "doc.on.doc", title: String(localized: "Your exports"), detail: exportsDetail)
                .accessibilityElement(children: .combine)
                .listRowBackground(CK.Palette.surface)

            Button {
                restorePurchases()
            } label: {
                CKSettingsRow(systemImage: "arrow.clockwise", title: String(localized: "Restore purchases"), showsChevron: !exportStore.isRestoring, isBusy: exportStore.isRestoring)
            }
            .disabled(exportStore.isBusy)
            .accessibilityHint(Text("Checks the App Store for a Premium purchase on this Apple Account"))
            .listRowBackground(CK.Palette.surface)

            NavigationLink(value: AppRoute.howExportsWork) {
                CKSettingsRow(systemImage: "arrow.down.doc", title: String(localized: "How exports work"))
            }
            .listRowBackground(CK.Palette.surface)

            if ads.privacyOptionsRequired {
                Button {
                    ads.presentPrivacyOptions()
                } label: {
                    CKSettingsRow(systemImage: "hand.raised", title: String(localized: "Ad privacy choices"), showsChevron: true)
                }
                .listRowBackground(CK.Palette.surface)
            }

            Button {
                reportAd()
            } label: {
                CKSettingsRow(systemImage: "flag", title: String(localized: "Report an ad"), showsChevron: true)
            }
            .accessibilityHint(Text("Opens an email to CareerKit support about an ad you saw"))
            .listRowBackground(CK.Palette.surface)
        } header: {
            sectionHeader("Ads and exports")
        }
    }

    /// What the "Your exports" row says: Premium, or how many exports are left from packs.
    private var exportsDetail: String {
        if exportStore.isPremium {
            return String(localized: "Premium is active. Exports have no limit.")
        }
        let count: Int = exportStore.credits
        if count > 0 {
            return String(localized: "\(count) exports left from export packs")
        }
        return String(localized: "No exports left. Each export asks for a pack, Premium or a short video.")
    }

    private func restorePurchases() {
        Task {
            let outcome = await exportStore.restore()
            switch outcome {
            case .premiumActive:
                toast = String(localized: "Premium is active again.")
            case .nothingFound:
                toast = String(localized: "No Premium purchase was found for this Apple Account. Export packs are used up and cannot be restored.")
            case .failed:
                toast = String(localized: "Purchases could not be restored right now. Check your connection and try again.")
            }
        }
    }

    private var legalSection: some View {
        Section {
            linkRow(String(localized: "Privacy policy"), systemImage: "lock.shield", url: CKLinks.privacy)
            linkRow(String(localized: "Terms of use"), systemImage: "doc.text", url: CKLinks.terms)
        } header: {
            sectionHeader("Privacy and legal")
        }
    }

    private var supportSection: some View {
        Section {
            Button {
                openMail(subject: String(localized: "CareerKit support"), body: nil)
            } label: {
                CKSettingsRow(systemImage: "lifepreserver", title: String(localized: "Contact support"), detail: CKLinks.supportEmail, showsChevron: true)
            }
            .listRowBackground(CK.Palette.surface)

            Button {
                openMail(subject: String(localized: "CareerKit feedback"), body: "\n\n\n" + deviceLine)
            } label: {
                CKSettingsRow(systemImage: "text.bubble", title: String(localized: "Send feedback"), showsChevron: true)
            }
            .listRowBackground(CK.Palette.surface)

            linkRow(String(localized: "Rate CareerKit"), systemImage: "star", url: CKLinks.reviewURL)
        } header: {
            sectionHeader("Support")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                CKSettingsRow(systemImage: "info.circle", title: String(localized: "Version"))
                Spacer()
                Text(CKLinks.appVersionText)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
            }
            .accessibilityElement(children: .combine)
            .listRowBackground(CK.Palette.surface)
            if WritingAssist.isAvailable {
                CKSettingsRow(systemImage: "iphone", title: String(localized: "On-device writing help"), detail: String(localized: "Suggestions are made on this device. Your text is not sent anywhere.")).listRowBackground(CK.Palette.surface)
            }
        } header: {
            sectionHeader("About")
        } footer: {
            Text("CareerKit is made by Ecom Swift LLC.")
        }
    }

    /// `CKInlineBanner` adds its own spacing above (and an "Advertisement" label) only while an ad shows,
    /// so it never sits flush against the Support and About rows.
    private var bannerSection: some View {
        Section {
            CKInlineBanner(slot: bannerSlot)
                .listRowInsets(EdgeInsets(top: 0, leading: CK.Space.m, bottom: 0, trailing: CK.Space.m))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    // MARK: Pieces

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(CK.Font.headline(17))
            .foregroundStyle(CK.Palette.ink)
            .textCase(nil)
    }

    private func linkRow(_ title: String, systemImage: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            CKSettingsRow(systemImage: systemImage, title: title, trailingSymbol: "arrow.up.right")
        }
        .listRowBackground(CK.Palette.surface)
    }

    private var dataSummary: String {
        let resumeText: String = CKCountText.resumes(store.resumes.count)
        let letterText: String = CKCountText.coverLetters(store.coverLetters.count)
        return String(localized: "Stored on this device: \(resumeText) and \(letterText). A backup is a single file you can keep anywhere. Restoring adds its documents and keeps the ones already here.")
    }

    private var deviceLine: String {
        return String(localized: "CareerKit \(CKLinks.appVersionText), iOS \(UIDevice.current.systemVersion)")
    }

    // MARK: Actions

    private func openMail(subject: String, body: String?) {
        guard let url = CKLinks.mailto(subject: subject, body: body) else { return }
        openURL(url) { accepted in
            if !accepted {
                toast = String(localized: "No mail app is set up. Write to \(CKLinks.supportEmail) from any mail account.")
            }
        }
    }

    /// Guideline 2.5.18: a way to report an inappropriate ad.
    private func reportAd() {
        let template: String = String(localized: """
        Tell us about the ad:
        - What did it show?
        - Where in CareerKit did you see it?
        - Roughly when did you see it?

        If you can, attach a screenshot of the ad.
        """)
        openMail(subject: String(localized: "Ad report"), body: template + "\n\n" + deviceLine)
    }

    private func presentResult(title: String, message: String) {
        resultTitle = title
        resultMessage = message
        CKDeferred.afterDismiss { showResult = true }
    }

    private func exportBackup() {
        do {
            let url = try store.makeBackupFile()
            // A moment's delay lets a closing dialog finish before the share sheet opens.
            CKDeferred.afterDismiss {
                pendingCleanup = [url]
                shareItem = ProfileShareItem(urls: [url], removeAfterSharing: true)
            }
        } catch {
            toast = String(localized: "The backup could not be created. Free up some space and try again.")
        }
    }

    /// The backup is a temporary copy; once the share sheet is closed it is no longer needed.
    /// Runs after SwiftUI has already cleared `shareItem`, so the files are kept in `pendingCleanup`.
    private func removeSharedTempFiles() {
        let urls: [URL] = pendingCleanup
        pendingCleanup = []
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func exportQuarantinedFiles() {
        store.refreshQuarantine()
        let files: [URL] = store.quarantinedFiles
        guard !files.isEmpty else { return }
        CKDeferred.afterDismiss { shareItem = ProfileShareItem(urls: files, removeAfterSharing: false) }
    }

    private func deleteQuarantinedFiles() {
        do {
            try store.deleteQuarantinedFiles()
            toast = String(localized: "The unreadable files were deleted.")
        } catch {
            toast = String(localized: "Some files could not be deleted. Restart the app and try again.")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            presentResult(title: String(localized: "Backup not restored"), message: CKBackupError.cannotOpenFile.message)
        case .success(let urls):
            guard let url = urls.first else { return }
            isRestoring = true
            Task { @MainActor in
                let read: Result<Data, Error> = await Task.detached(priority: .userInitiated) { () -> Result<Data, Error> in
                    do {
                        return .success(try CKBackupParser.readFile(at: url))
                    } catch {
                        return .failure(error)
                    }
                }.value
                isRestoring = false
                switch read {
                case .success(let data):
                    restore(data)
                case .failure(let error):
                    let message: String = (error as? CKBackupError)?.message ?? CKBackupError.cannotOpenFile.message
                    presentResult(title: String(localized: "Backup not restored"), message: message)
                }
            }
        }
    }

    private func restore(_ data: Data) {
        do {
            let summary: CKRestoreSummary = try store.restoreBackup(from: data)
            if summary.replacedExisting > 0 {
                // An editor left open in another tab must not write the older version back.
                appState.resetNavigation()
            }
            let title: String = summary.restored > 0
                ? String(localized: "Backup restored")
                : String(localized: "Nothing new to restore")
            presentResult(title: title, message: summary.message)
        } catch let error as CKBackupError {
            presentResult(title: String(localized: "Backup not restored"), message: error.message)
        } catch {
            presentResult(title: String(localized: "Backup not restored"), message: CKBackupError.unreadable.message)
        }
    }

    private func deleteEverything() {
        do {
            try CKLocalDataReset.eraseEverything(store: store, exportGate: exportGate, appState: appState)
            toast = String(localized: "All local data was deleted.")
        } catch {
            toast = String(localized: "Some data could not be deleted. Restart the app and try again.")
        }
    }
}

/// One or more files for the share sheet. Backups are temporary and removed when the sheet closes.
struct ProfileShareItem: Identifiable {
    let id = UUID()
    let urls: [URL]
    let removeAfterSharing: Bool
}
