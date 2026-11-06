import Foundation
import SQLite3

@main
struct DatabaseRegression {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.sqlite3")
        let database = ClipboardDatabase(databaseURL: url)
        let capture = ClipboardCapture(
            type: .text, title: "Test", subtitle: nil, preview: "Test",
            content: "Test", payloadData: nil, sourceApp: "Tests", createdAt: Date()
        )
        let first = try await database.upsertCapture(capture)
        let duplicate = try await database.upsertCapture(capture)
        precondition(first.id == duplicate.id, "Repeated captures must reuse their row")
        try await database.togglePin(id: first.id)
        try await database.clearHistory(keepingPinned: true)
        let pinned = try await database.fetchItems()
        precondition(pinned.count == 1 && pinned[0].isPinned)
        let reopened = ClipboardDatabase(databaseURL: url)
        let restored = try await reopened.fetchItems()
        precondition(restored.count == 1 && restored[0].id == first.id)
        try await database.clearHistory(keepingPinned: false)
        let cleared = try await database.fetchItems()
        precondition(cleared.isEmpty)
        let fresh = try await database.upsertCapture(capture)
        try await database.delete(id: fresh.id)
        let deleted = try await database.fetchItems()
        precondition(deleted.isEmpty)
        do {
            _ = try await database.fetchItem(id: fresh.id)
            preconditionFailure("Deleted items must not be available to pending previews")
        } catch DatabaseError.notFound {}

        let brokenURL = directory.appendingPathComponent("migration.sqlite3")
        var connection: OpaquePointer?
        precondition(sqlite3_open(brokenURL.path, &connection) == SQLITE_OK)
        precondition(sqlite3_exec(connection, "CREATE TABLE clipboard_items (id TEXT)", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(connection)
        let recovering = ClipboardDatabase(databaseURL: brokenURL)
        do {
            _ = try await recovering.fetchItems()
            preconditionFailure("Invalid schema should fail migration")
        } catch DatabaseError.executeFailed {}
        precondition(sqlite3_open(brokenURL.path, &connection) == SQLITE_OK)
        precondition(sqlite3_exec(connection, "DROP TABLE clipboard_items", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(connection)
        let recovered = try await recovering.fetchItems()
        precondition(recovered.isEmpty, "Failed initialization must allow a fresh migration")
        print("PASS: insert, deduplication, pin, clear, reopen, delete, hidden deleted payloads, migration recovery")
    }
}
