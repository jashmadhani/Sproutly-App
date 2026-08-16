//
//  PaywallView.swift
//  Sproutly
//

import SwiftUI

// Shown only when someone reaches for something locked — never at launch, never
// as a nag. Tone matches the rest of the app: this is not the place to start
// using urgency language.
struct PaywallView: View {
    let reason: PaywallReason

    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Drives the one-shot entrance of the Pro mark. Held here rather than in
    /// `header` so it survives the body re-evaluations that follow a purchase.
    @State private var markHasAppeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var priceText: String? {
        purchases.product?.displayPrice
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(nightMode: theme.isNightMode)

                ScrollView {
                    VStack(spacing: 26) {
                        header
                        featureList
                        purchaseButton
                        legalRow
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .font(.body.weight(.medium))
                        .foregroundStyle(theme.text)
                }
            }
            .task {
                // Set before the await so the mark animates on the first frame
                // rather than waiting on a StoreKit round trip.
                markHasAppeared = true
                if purchases.product == nil {
                    await purchases.loadProduct()
                }
            }
            .onChange(of: purchases.isPro) { _, isPro in
                // Dismiss the moment the unlock lands, including when it arrives
                // from a restore or a pending purchase resolving.
                if isPro { dismiss() }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            // The app's own mark in a gold colorway, not a generic glyph: this
            // screen is about upgrading *this* app, so the parent should see the
            // icon they already know from their home screen. SproutMarkPro is
            // the same vector with the two blue accents swapped to gold — gold
            // appears nowhere else in the app, whereas blue is on every free
            // feature row, so reusing blue would make Pro read as more of the same.
            ZStack {
                Circle()
                    .fill(theme.proHaloGradient)
                    .frame(width: 104, height: 104)
                    .blur(radius: 8)

                Image("SproutMarkPro")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(theme.proGoldGradient, lineWidth: 2.5)
                    .frame(width: 84, height: 84)
            }
            .shadow(color: theme.proGold.opacity(0.28), radius: 10, y: 4)
            // Settles rather than bounces. A paywall that springs at the parent
            // reads as a sales tactic; this is just the screen arriving.
            .scaleEffect(markHasAppeared || reduceMotion ? 1 : 0.94)
            .opacity(markHasAppeared || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72),
                       value: markHasAppeared)
            .accessibilityHidden(true)

            Text("Sproutly Pro")
                .font(.sproutlyDisplay(28))
                .foregroundStyle(theme.text)

            Text(reason.headline)
                .font(Theme.sproutlyBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.top, 12)
    }

    private var featureList: some View {
        ProFeatureListView()
            .warmCard(nightMode: theme.isNightMode)
    }

    private var loadFailed: Bool {
        if case .failed = purchases.state, purchases.product == nil { return true }
        return false
    }

    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button {
                if loadFailed {
                    Task { await purchases.loadProduct() }
                } else {
                    Task { await purchases.purchase() }
                }
            } label: {
                Group {
                    if loadFailed {
                        Text("Try Again")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else if purchases.state == .purchasing || priceText == nil {
                        ProgressView().tint(.white)
                    } else {
                        // The price carries the weight rather than sitting inside a
                        // sentence — at $9.99 the number is the reassurance, not the
                        // obstacle, so it should be the thing the eye lands on.
                        HStack(spacing: 10) {
                            Text("Unlock everything")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.94))

                            Text(priceText ?? "")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.heavy)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.ctaGradient)

                        // A single lit top edge. Cheaper than a full bevel and it
                        // survives both colour schemes without looking plastic.
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.32), .white.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .shadow(color: theme.ctaShadow, radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(purchases.state == .purchasing || (purchases.product == nil && !loadFailed))

            Text("One payment, yours forever. No subscription.")
                .font(Theme.sproutlyMeta)
                .foregroundStyle(theme.textSecondary)

            if case .failed(let message) = purchases.state {
                Text(message)
                    .font(Theme.sproutlyMeta)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
    }

    // Restore is required by App Review, and the legal links belong here rather
    // than buried in Settings.
    private var legalRow: some View {
        VStack(spacing: 14) {
            Button("Restore Purchases") {
                Task { await purchases.restore() }
            }
            .font(Theme.sproutlyCardTitle)
            .foregroundStyle(theme.blue)
            .disabled(purchases.state == .purchasing)

            HStack(spacing: 18) {
                Link("Privacy Policy", destination: AppLinks.privacyPolicy)
                Link("Terms of Use", destination: AppLinks.termsOfUse)
            }
            .font(Theme.sproutlyMeta)
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.center)
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Reason

// The paywall names what the parent just reached for, so it reads as an answer
// rather than an interruption.
enum PaywallReason: Identifiable {
    var id: String { headline }

    case secondChild
    case photo
    case report
    case shareCard
    case customMilestone
    case appIcon

    var headline: String {
        switch self {
        case .secondChild:
            return "Track a second child, with their own milestones and their own story."
        case .photo:
            return "Keep a photo with every milestone you record."
        case .report:
            return "Bring a clear summary to your next pediatrician visit."
        case .shareCard:
            return "Share this moment with the people who love them."
        case .customMilestone:
            return "Record your own moments, not just the standard ones."
        case .appIcon:
            return "Choose the Sproutly icon that feels like yours."
        }
    }

    struct Feature {
        let icon: String
        let title: String
        let detail: String
    }

    static let allFeatures: [Feature] = [
        Feature(
            icon: "figure.2.and.child.holdinghands",
            title: "Every child",
            detail: "Siblings and twins, each tracked separately"
        ),
        Feature(
            icon: "photo",
            title: "Photos on milestones",
            detail: "Kept privately on your device"
        ),
        Feature(
            icon: "doc.text",
            title: "Report for your visit",
            detail: "A summary to hand to your pediatrician"
        ),
        Feature(
            icon: "square.and.arrow.up",
            title: "Shareable moments",
            detail: "Cards for family and friends"
        ),
        Feature(
            icon: "heart",
            title: "Your own moments",
            detail: "Record anything, at any age"
        ),
        Feature(
            icon: "app.badge",
            title: "Choose your app icon",
            detail: "Five looks, including one for siblings"
        )
    ]
}

// MARK: - Links

enum AppLinks {
    // Served as a static page from the portfolio site. App Review follows this
    // link from the paywall, so it must stay reachable for as long as the app
    // is on sale — it is not a marketing page that can be retired.
    static let privacyPolicy = URL(string: "https://jash.madhani.in/sproutly/privacy/")!
    // Apple's standard EULA, which is the default terms for any app that does
    // not supply its own.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
