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

    private var priceText: String {
        purchases.product?.displayPrice ?? "…"
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
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .task {
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
            ZStack {
                Circle()
                    .fill(theme.blue.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(theme.blue)
            }

            Text("Sproutly Pro")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(theme.text)

            Text(reason.headline)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.top, 12)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(PaywallReason.allFeatures, id: \.title) { feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 17))
                        .foregroundStyle(theme.blue)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.text)
                        Text(feature.detail)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(nightMode: theme.isNightMode)
    }

    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchases.purchase() }
            } label: {
                Group {
                    if purchases.state == .purchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Unlock for \(priceText)")
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.green)
                )
            }
            .buttonStyle(.plain)
            .disabled(purchases.state == .purchasing || purchases.product == nil)

            Text("One payment, yours forever. No subscription.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            if case .failed(let message) = purchases.state {
                Text(message)
                    .font(.caption)
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
            .font(.subheadline)
            .foregroundStyle(theme.blue)
            .disabled(purchases.state == .purchasing)

            HStack(spacing: 18) {
                Link("Privacy Policy", destination: AppLinks.privacyPolicy)
                Link("Terms of Use", destination: AppLinks.termsOfUse)
            }
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(.bottom, 12)
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
            icon: "heart.fill",
            title: "Your own moments",
            detail: "Record anything, at any age"
        )
    ]
}

// MARK: - Links

enum AppLinks {
    // TODO: point these at the hosted pages before submitting.
    static let privacyPolicy = URL(string: "https://jashmadhani.github.io/Sproutly/privacy")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
