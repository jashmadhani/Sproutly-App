//
//  PurchaseManager.swift
//  Sproutly
//

import Foundation
import StoreKit
import Observation

// Single non-consumable unlock. No tiers, no subscription, no trial — for a $9.99
// one-time purchase the paywall itself is the trial.
@MainActor
@Observable
final class PurchaseManager {

    static let productID = "com.jashmadhani.Sproutly.pro"

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
                state = .failed("Sproutly Pro isn't available right now. Please try again later.")
            }
        } catch {
            sproutlyLog("could not load product — \(error.localizedDescription)")
            state = .failed("Couldn't reach the App Store. Check your connection and try again.")
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

    // MARK: - Purchasing

    func purchase() async {
        guard let product else {
            state = .failed("Sproutly Pro isn't available right now. Please try again later.")
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
                state = .failed(error.localizedDescription)
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
            state = .failed(error.localizedDescription)
        }
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
