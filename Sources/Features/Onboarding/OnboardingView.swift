import SwiftUI

struct CKOnboardingPage: Identifiable {
    let index: Int
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var id: Int { index }

    static let all: [CKOnboardingPage] = [
        CKOnboardingPage(
            index: 0,
            title: "Welcome to CareerKit",
            message: "Build a clean, well-organised resume on your phone. There is no account to create, and your documents stay on this device."
        ),
        CKOnboardingPage(
            index: 1,
            title: "Create a professional resume",
            message: "Work through guided sections for experience, education and skills. The page updates as you type, so you always see what you will send."
        ),
        CKOnboardingPage(
            index: 2,
            title: "Choose from 30 professionally designed templates",
            message: "Filter by industry, career level and style. Every template is free, and you can change templates later without retyping anything."
        ),
        CKOnboardingPage(
            index: 3,
            title: "Customize fonts, colors and layout",
            message: "Adjust type, accent color, margins and spacing until the page suits you."
        ),
        CKOnboardingPage(
            index: 4,
            title: "Build a stronger job application with matching cover letters",
            message: "Ten cover letter templates share the look of your resume, so the two documents read as one set."
        )
    ]
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0

    private let pages = CKOnboardingPage.all
    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $page) {
                ForEach(pages) { item in
                    CKOnboardingPageView(page: item, isActive: page == item.index, isLast: item.index == pages.count - 1)
                        .tag(item.index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .ckScreen()
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                finish()
            } label: {
                Text("Skip")
                    .font(CK.Font.label)
                    .foregroundStyle(CK.Palette.graphite)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isLast ? 0 : 1)
            .disabled(isLast)
            .accessibilityHidden(isLast)
        }
        .padding(.horizontal, CK.Space.l)
        .frame(height: 52)
    }

    private var footer: some View {
        VStack(spacing: CK.Space.l) {
            HStack(spacing: 6) {
                ForEach(pages) { item in
                    Capsule(style: .continuous)
                        .fill(item.index == page ? CK.Palette.forest : CK.Palette.hairline)
                        .frame(width: item.index == page ? 22 : 8, height: 8)
                }
            }
            .animation(reduceMotion ? nil : Animation.easeInOut(duration: 0.25), value: page)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Page \(page + 1) of \(pages.count)"))

            Button {
                if isLast {
                    finish()
                } else {
                    withAnimation(reduceMotion ? nil : Animation.easeInOut(duration: 0.35)) {
                        page += 1
                    }
                }
            } label: {
                Text(isLast ? "Get started" : "Continue")
            }
            .buttonStyle(.ckPrimary)
        }
        .padding(.horizontal, CK.Space.l)
        .padding(.bottom, CK.Space.l)
        .padding(.top, CK.Space.s)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private func finish() {
        appState.selectedTab = .home
        appState.hasCompletedOnboarding = true
    }
}

private struct CKOnboardingPageView: View {
    let page: CKOnboardingPage
    let isActive: Bool
    let isLast: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CK.Space.l) {
                CKOnboardingArt(index: page.index, isActive: isActive)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: CK.Space.s + 4) {
                    Text(page.title)
                        .ckTitle(30)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(page.message)
                        .font(CK.Font.body)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isLast { modelNote }
            }
            .padding(.horizontal, CK.Space.l)
            .padding(.vertical, CK.Space.s)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    /// Plain statement of how the app is paid for, shown on the last page.
    private var modelNote: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            Text("CareerKit is free. Exporting a finished document needs one short rewarded video. Everything else has no ad wall.")
                .font(CK.Font.label)
                .foregroundStyle(CK.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Ads come from Google AdMob and follow the consent choices you make. You can change them later in Profile.")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CK.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.stone)
        )
        .accessibilityElement(children: .combine)
    }
}
