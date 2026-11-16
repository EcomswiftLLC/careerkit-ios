import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var ads: AdsManager
    @Environment(\.openURL) private var openURL

    @State private var path: [AppRoute] = []
    @State private var shareItem: CKShareItem?
    @State private var showDeleteFirst = false
    @State private var showDeleteFinal = false
    @State private var toast: String?

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
            .sheet(item: $shareItem) { item in
                CKShareSheet(items: [item.url])
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
                Text("This removes every resume and cover letter stored in CareerKit on this device.")
            }
            .alert("Delete everything permanently?", isPresented: $showDeleteFinal) {
                Button("Delete everything", role: .destructive) { deleteEverything() }
                Button("Keep my data", role: .cancel) {}
            } message: {
                Text("Your resumes, cover letters and drafts cannot be recovered afterwards unless you saved a backup file.")
            }
            .ckToast($toast)
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
            .listRowBackground(CK.Palette.surface)

            Button(role: .destructive) {
                showDeleteFirst = true
            } label: {
                CKSettingsRow(systemImage: "trash", title: String(localized: "Delete all local data"), tint: CK.Palette.danger, isDestructive: true)
            }
            .listRowBackground(CK.Palette.surface)
        } header: {
            sectionHeader("Your data")
        } footer: {
            Text(dataSummary)
        }
    }

    private var adsAndExportsSection: some View {
        Section {
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
        } header: {
            sectionHeader("Ads and exports")
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
                let body = String(localized: "\n\n\nCareerKit \(CKLinks.appVersionText), iOS \(UIDevice.current.systemVersion)")
                openMail(subject: String(localized: "CareerKit feedback"), body: body)
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
        } header: {
            sectionHeader("About")
        } footer: {
            Text("CareerKit is made by Ecom Swift LLC.")
        }
    }

    private var bannerSection: some View {
        Section {
            BannerAdView()
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
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
        let resumes = store.resumes.count
        let letters = store.coverLetters.count
        let resumeText = resumes == 1 ? String(localized: "1 resume") : String(localized: "\(resumes) resumes")
        let letterText = letters == 1 ? String(localized: "1 cover letter") : String(localized: "\(letters) cover letters")
        return String(localized: "Stored on this device: \(resumeText) and \(letterText). A backup is a single file you can keep anywhere.")
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

    private func exportBackup() {
        do {
            let url = try store.makeBackupFile()
            // A moment's delay lets a closing dialog finish before the share sheet opens.
            CKDeferred.afterDismiss { shareItem = CKShareItem(url: url) }
        } catch {
            toast = String(localized: "The backup could not be created. Free up some space and try again.")
        }
    }

    private func deleteEverything() {
        do {
            try store.deleteAllData()
            appState.displayName = ""
            toast = String(localized: "All local data was deleted.")
        } catch {
            toast = String(localized: "Some data could not be deleted. Restart the app and try again.")
        }
    }
}

/// Icon, title and optional detail used by every settings row.
struct CKSettingsRow: View {
    let systemImage: String
    let title: String
    var detail: String? = nil
    var showsChevron = false
    var trailingSymbol: String? = nil
    var tint: Color = CK.Palette.forest
    var isDestructive = false

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
                if let detail {
                    Text(detail)
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                }
            }
            Spacer(minLength: 0)
            if let trailingSymbol {
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
