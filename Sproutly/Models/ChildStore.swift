//
//  ChildStore.swift
//  Sproutly
//

import Foundation
import SwiftData
import Observation

// MARK: - Child Store

// Owns the roster of children and which one the app is currently showing.
// Views read `activeChild` rather than querying milestones globally, so a
// sibling's progress can never bleed into another's screen.
@MainActor
@Observable
final class ChildStore {

    private let context: ModelContext

    private(set) var children: [Child] = []
    private(set) var activeChild: Child?

    private static let activeChildKey = "sproutly_active_child_id"

    // MARK: - Init

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    // MARK: - State

    // True until the first child exists — drives whether onboarding is shown.
    var needsOnboarding: Bool { children.isEmpty }

    // The switcher only exists once there is something to switch between. A parent
    // with one child should never see multi-child UI.
    var hasMultipleChildren: Bool { children.count > 1 }

    // MARK: - Loading

    func refresh() {
        let descriptor = FetchDescriptor<Child>(sortBy: [SortDescriptor(\Child.createdAt)])
        children = (try? context.fetch(descriptor)) ?? []

        // Re-resolve the active child: honour the stored id, else fall back to the
        // first child so the app is never left pointing at nothing.
        if let storedID = UserDefaults.standard.string(forKey: Self.activeChildKey),
           let uuid = UUID(uuidString: storedID),
           let match = children.first(where: { $0.id == uuid }) {
            activeChild = match
        } else {
            activeChild = children.first
            persistActiveID()
        }
    }

    // MARK: - Selection

    func select(_ child: Child) {
        activeChild = child
        persistActiveID()
    }

    private func persistActiveID() {
        if let id = activeChild?.id.uuidString {
            UserDefaults.standard.set(id, forKey: Self.activeChildKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.activeChildKey)
        }
    }

    // MARK: - Mutation

    @discardableResult
    func addChild(
        name: String,
        birthDate: Date,
        isPremature: Bool = false,
        gestationalWeeks: Int = 40
    ) -> Child {
        let child = Child(
            name: name,
            birthDate: birthDate,
            isPremature: isPremature,
            gestationalWeeks: gestationalWeeks
        )
        context.insert(child)

        // Every child gets their own copy of the milestone set.
        DataSeeder.seed(for: child, in: context)

        save()
        refresh()
        select(child)
        return child
    }

    func delete(_ child: Child) {
        // Cascade delete rule removes the child's milestones with them.
        context.delete(child)
        save()

        // Clear the stored id first so refresh() falls back cleanly.
        if activeChild?.id == child.id {
            UserDefaults.standard.removeObject(forKey: Self.activeChildKey)
            activeChild = nil
        }
        refresh()
    }

    func save() {
        do {
            try context.save()
        } catch {
            print("⚠️ Sproutly: failed to save — \(error.localizedDescription)")
        }
    }

    // MARK: - Legacy Import

    // Pre-multi-child builds stored one profile in UserDefaults and left milestones
    // unowned. Adopt both into a real Child exactly once. Idempotent.
    func importLegacyProfileIfNeeded() {
        let orphans = (try? context.fetch(
            FetchDescriptor<Milestone>(predicate: #Predicate { $0.child == nil })
        )) ?? []

        // Nothing to rescue, and a child already exists — normal case, do nothing.
        guard !orphans.isEmpty || children.isEmpty else { return }

        let legacy = LegacyProfile.load()

        // No legacy profile and no orphans means a genuinely fresh install.
        guard legacy != nil || !orphans.isEmpty else { return }

        let child: Child
        if let existing = children.first {
            child = existing
        } else {
            child = Child(
                name: legacy?.name ?? "",
                birthDate: legacy?.birthDate ?? Date(),
                isPremature: legacy?.isPremature ?? false,
                gestationalWeeks: legacy?.gestationalWeeks ?? 40
            )
            context.insert(child)
        }

        for milestone in orphans {
            milestone.child = child
        }

        // If the legacy install had no milestones yet, give the child a fresh set.
        if orphans.isEmpty && child.milestones.isEmpty {
            DataSeeder.seed(for: child, in: context)
        }

        LegacyProfile.clear()
        save()
        refresh()
    }
}

// MARK: - Legacy Profile

// Read-only view of the old UserDefaults-backed ChildProfile, kept only so an
// existing install can be migrated. Nothing writes this format any more.
struct LegacyProfile {
    let name: String
    let birthDate: Date
    let isPremature: Bool
    let gestationalWeeks: Int

    private static let keys = ["sproutly_profile", "elitegrowth_profile"]

    static func load() -> LegacyProfile? {
        for key in keys {
            guard let data = UserDefaults.standard.dictionary(forKey: key) else { continue }
            return LegacyProfile(
                name: data["name"] as? String ?? "",
                birthDate: Date(
                    timeIntervalSince1970: data["birthDate"] as? Double
                        ?? Date().timeIntervalSince1970
                ),
                isPremature: data["isPremature"] as? Bool ?? false,
                gestationalWeeks: data["gestationalWeeks"] as? Int ?? 40
            )
        }
        return nil
    }

    static func clear() {
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
