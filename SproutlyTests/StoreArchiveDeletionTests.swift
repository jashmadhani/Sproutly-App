//
//  StoreArchiveDeletionTests.swift
//  SproutlyTests
//

import XCTest
@testable import Sproutly

/// "Delete All Data" walks the live object graph, but `archiveExistingStore` moves
/// data aside at the filesystem level, below SwiftData. An archive was therefore
/// invisible to the wipe: a parent could delete everything and leave behind a
/// complete readable copy of every child's name, birth date, milestones, notes and
/// photos. The privacy policy says neither delete action leaves a copy behind.
///
/// This class of bug returns whenever a new on-disk artifact is added, which is why
/// the test exists rather than only the fix.
final class StoreArchiveDeletionTests: XCTestCase {

    private var appSupport: URL!
    private var created: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        appSupport = try XCTUnwrap(
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        )
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        created = []
    }

    override func tearDownWithError() throws {
        for url in created {
            try? FileManager.default.removeItem(at: url)
        }
        created = []
        try super.tearDownWithError()
    }

    /// Records the URL so tearDown removes it even when the assertion fails.
    private func track(_ url: URL) -> URL {
        created.append(url)
        return url
    }

    private func makeFile(named name: String) throws -> URL {
        let url = track(appSupport.appendingPathComponent(name))
        try Data("archived".utf8).write(to: url)
        return url
    }

    private func makeDirectory(named name: String, withFile file: String) throws -> URL {
        let url = track(appSupport.appendingPathComponent(name, isDirectory: true))
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data("photo".utf8).write(to: url.appendingPathComponent(file))
        return url
    }

    func testDeleteStoreArchivesRemovesArchivedStoreAndItsSiblings() throws {
        let stamp = Int(Date().timeIntervalSince1970)
        let store = try makeFile(named: "SproutlyDB-backup-\(stamp).store")
        let shm = try makeFile(named: "SproutlyDB-backup-\(stamp).store-shm")
        let wal = try makeFile(named: "SproutlyDB-backup-\(stamp).store-wal")

        deleteStoreArchives()

        for url in [store, shm, wal] {
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: url.path),
                "\(url.lastPathComponent) survived Delete All Data, so the child records in it did too"
            )
        }
    }

    func testDeleteStoreArchivesRemovesArchivedPhotoFolderAndItsContents() throws {
        let stamp = Int(Date().timeIntervalSince1970)
        let folder = try makeDirectory(named: "MilestonePhotos-backup-\(stamp)", withFile: "a.jpg")

        deleteStoreArchives()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: folder.path),
            "the archived photo folder survived, so every photo of the child did too"
        )
    }

    /// Several archive generations can exist at once: `pruneOldArchives` keeps the
    /// two most recent, and only runs when the store fails to open again. A wipe has
    /// to take all of them, not the newest.
    func testDeleteStoreArchivesRemovesEveryGeneration() throws {
        let stamps = [1_700_000_000, 1_700_000_001, 1_700_000_002]
        var archives: [URL] = []
        for stamp in stamps {
            archives.append(try makeFile(named: "SproutlyDB-backup-\(stamp).store"))
            archives.append(try makeDirectory(named: "MilestonePhotos-backup-\(stamp)", withFile: "a.jpg"))
        }

        deleteStoreArchives()

        for url in archives {
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: url.path),
                "\(url.lastPathComponent) survived, so an older generation still holds the child's data"
            )
        }
    }

    /// The live store and photo folder must be untouched. They are deleted through
    /// SwiftData's cascade and `PhotoStore.delete`, and removing the files from under
    /// an open store would be a different and worse bug than the one being fixed.
    func testDeleteStoreArchivesLeavesTheLiveStoreAndPhotoFolderAlone() throws {
        let live = try makeFile(named: "SproutlyDB.store")
        let livePhotos = try makeDirectory(named: "MilestonePhotos", withFile: "a.jpg")

        deleteStoreArchives()

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: live.path),
            "the live store was deleted; the archive sweep must match only the -backup- prefixes"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: livePhotos.path),
            "the live photo folder was deleted; the archive sweep must match only the -backup- prefixes"
        )
    }

    /// The tests above prove the sweep works. They do not prove it is *called* —
    /// `deleteAllData` is private to `SettingsView`, so the wiring is only reachable
    /// by reading the source, the same way `UIRegressionTests` and `DisclaimerTests`
    /// guard their invariants. Without this, deleting the call reintroduces the bug
    /// with every test still green.
    func testDeleteAllDataCallsTheArchiveAndRenderSweeps() throws {
        let settings = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly/Views/SettingsView.swift")
        let source = try String(contentsOf: settings, encoding: .utf8)

        guard let body = source.range(of: "private func deleteAllData()") else {
            return XCTFail("deleteAllData() was renamed; update this guard to match")
        }
        let remainder = source[body.upperBound...]
        guard let end = remainder.range(of: "\n    }") else {
            return XCTFail("could not find the end of deleteAllData(); update this guard")
        }
        let function = String(remainder[..<end.lowerBound])

        XCTAssertTrue(
            function.contains("deleteStoreArchives()"),
            "deleteAllData() no longer sweeps store archives, so a wipe leaves a full copy of every child on disk"
        )
        XCTAssertTrue(
            function.contains("ShareRenderer.clearRenderedFiles()"),
            "deleteAllData() no longer sweeps rendered files, so a stranded report naming a child survives a wipe"
        )
    }

    /// Nothing else in Application Support belongs to the archive sweep.
    func testDeleteStoreArchivesLeavesUnrelatedFilesAlone() throws {
        let unrelated = try makeFile(named: "SomethingElse.plist")

        deleteStoreArchives()

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: unrelated.path),
            "an unrelated file was deleted; the sweep is prefix-matched for a reason"
        )
    }
}
