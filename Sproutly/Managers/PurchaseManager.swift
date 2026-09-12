//
//  PurchaseManager.swift
//  Sproutly
//

import Foundation
import StoreKit
import Observation

// Single non-consumable unlock. No tiers, no subscription, no trial — for a
// modest one-time purchase the paywall itself is the trial.
//
// The amount is deliberately not written down anywhere in the app, comments
// included. Pricing is per-territory and set in App Store Connect, and every
// figure a parent sees comes from `product.displayPrice`, which StoreKit has
// already formatted for their store and currency.
@MainActor
@Observable
final class PurchaseManager {

    static let productID = "com.sproutly.app.pro"

    // MARK: - Copy

    // Written once and reused, because the same two situations are reachable from
    // both loading and purchasing and a parent should not get two different
    // sentences for the same condition.
    private static let unavailable = "Sproutly Pro isn't available right now. Please try again later."
    private static let noConnection = "Couldn't reach the App Store. Check your connection and try again."
    private static let somethingWentWrong = "Something went wrong at the App Store's end. Please try again in a moment."

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case failed(String)
    }

    private(set) var isPro = false
    private(set) var product: Product?
    private(set) var state: PurchaseState = .idle

    // Until the first entitlement check completes we don't know either way. Gating
    // on `isPro == false` before then would flash a paywall at a paying customer.
    private(set) var hasCheckedEntitlements = false

    private var updatesTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init() {
        // Started at launch, not from a view: a transaction can arrive while no
        // paywall is on screen (Ask to Buy approval, a redeemed code, a purchase
        // made on another device). The manager lives for the app's lifetime, so
        // this listener is never torn down.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    // MARK: - Loading

    func start() async {
        await refreshEntitlements()
        await loadProduct()
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil {
                // Not thrown — StoreKit returns an empty list rather than an
                // error when the product ID isn't recognized. Silently leaving
                // this unset is what made the paywall spin forever with no
                // explanation; surface it so the button can show a real state.
                state = .failed(Self.unavailable)
            }
        } catch {
            sproutlyLog("could not load product — \(error.localizedDescription)")
            state = .failed(Self.noConnection)
        }
    }

    // The source of truth. Checked on every launch rather than trusting a cached
    // flag, so a refund or a family-sharing revocation is reflected.
    func refreshEntitlements() async {
        var entitled = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                entitled = true
            }
        }

        isPro = entitled
        hasCheckedEntitlements = true
    }

    // MARK: - Gating

    /// Answers "may this parent use a Pro feature?" for the gates that present the
    /// paywall on tap.
    ///
    /// Reading `isPro` directly is wrong at those call sites: it is `false` both
    /// when the parent hasn't bought Pro *and* during the window between launch and
    /// `start()` completing, when the answer simply isn't known yet. A tap landing
    /// in that window showed a paying customer a paywall for something they already
    /// own. Awaiting the check here closes it — `currentEntitlements` is a local
    /// read, so on the common path this returns immediately and the tap is never
    /// swallowed or disabled.
    func isUnlocked() async -> Bool {
        if !hasCheckedEntitlements {
            await refreshEntitlements()
        }
        return isPro
    }

    // MARK: - Purchasing

    func purchase() async {
        guard let product else {
            state = .failed(Self.unavailable)
            return
        }

        state = .purchasing

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                state = .idle

            case .userCancelled:
                // Not an error. Saying nothing is the correct response.
                state = .idle

            case .pending:
                // Ask to Buy, or a payment needing action. The Transaction.updates
                // listener picks it up whenever it resolves.
                state = .idle

            @unknown default:
                state = .idle
            }
        } catch {
            // product.purchase() can throw even after StoreKit has already recorded
            // the transaction (seen with sandbox/local test purchases) — a thrown
            // error here is not proof nothing happened. Re-check before trusting the
            // failure message, otherwise a real purchase gets stuck behind a paywall
            // that never looks again until the app happens to background/foreground.
            await refreshEntitlements()
            if !isPro {
                sproutlyLog("purchase failed — \(error.localizedDescription)")
                state = Self.state(for: error)
            }
        }
    }

    func restore() async {
        state = .purchasing
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            state = isPro
                ? .idle
                : .failed("We couldn't find a previous purchase on this Apple Account.")
        } catch {
            // AppStore.sync() presents an App Store sign-in sheet, and dismissing it
            // throws. Without the mapping below, backing out of that sheet showed the
            // parent a raw system error string for something they chose to do.
            sproutlyLog("restore failed — \(error.localizedDescription)")
            state = Self.state(for: error)
        }
    }

    // MARK: - Error mapping

    /// Turns a StoreKit error into either written copy or silence.
    ///
    /// StoreKit's own `localizedDescription` is written for developers and reads
    /// like a system alert, which is the one register this app is not allowed to
    /// use. The underlying error still reaches `sproutlyLog`, where it is useful.
    ///
    /// Cancelling returns `.idle`, not a failure. Someone who dismisses the sign-in
    /// sheet has said no, and saying nothing back is the correct response — the same
    /// thing the `.userCancelled` branch of `purchase()` already does.
    private static func state(for error: Error) -> PurchaseState {
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .userCancelled:
                return .idle
            case .networkError:
                return .failed(noConnection)
            case .notAvailableInStorefront:
                return .failed("Sproutly Pro isn't available in your App Store region.")
            default:
                return .failed(somethingWentWrong)
            }
        }

        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable:
                return .failed(unavailable)
            case .purchaseNotAllowed:
                return .failed("Purchases are turned off on this device. You can turn them back on in Screen Time settings.")
            default:
                return .failed(somethingWentWrong)
            }
        }

        return .failed(somethingWentWrong)
    }

    // MARK: - Private

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }

        if transaction.productID == Self.productID, transaction.revocationDate == nil {
            isPro = true
        }

        // Every transaction must be finished or StoreKit will keep redelivering it.
        await transaction.finish()
        await refreshEntitlements()
    }
}
