import Foundation
import SQLite3

actor ClipboardDatabase {
    static let shared = ClipboardDatabase()

    private var database: OpaquePointer?
    private let databaseURL: URL

    init(databaseURL: URL? = nil) {
        if let databaseURL {
            self.databaseURL = databaseURL
            return
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let directory = appSupport.appendingPathComponent("PasteX", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.databaseURL = directory.appendingPathComponent("PasteX.sqlite3")
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func fetchItems() throws -> [ClipboardItem] {
        try openIfNeeded()

        let sql = """
        SELECT id, type, title, subtitle, preview, content, NULL AS payload_blob, source_app, created_at,
               is_pinned
        FROM clipboard_items
        WHERE deleted_at IS NULL
        ORDER BY created_at DESC
        """

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var items: [ClipboardItem] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            items.append(try makeItem(from: statement))
        }

        return items
    }

    func fetchItem(id: UUID) throws -> ClipboardItem {
        try openIfNeeded()

        let sql = """
        SELECT id, type, title, subtitle, preview, content, payload_blob, source_app, created_at,
               is_pinned
        FROM clipboard_items
        WHERE id = ? AND deleted_at IS NULL
        LIMIT 1
        """

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        bind(id.uuidString, to: statement, at: 1)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.notFound
        }

        return try makeItem(from: statement)
    }

    func upsertCapture(_ capture: ClipboardCapture) throws -> ClipboardItem {
        try openIfNeeded()

        let id = UUID()
        let hash = capture.contentHash
        let sql = """
        INSERT INTO clipboard_items (
            id, type, title, subtitle, preview, content, payload_blob, source_app, created_at,
            updated_at, is_pinned, content_hash, content_hash_algorithm, deleted_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, NULL)
        ON CONFLICT(content_hash) DO UPDATE SET
            type = excluded.type,
            title = excluded.title,
            subtitle = excluded.subtitle,
            preview = excluded.preview,
            content = excluded.content,
            payload_blob = excluded.payload_blob,
            source_app = excluded.source_app,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at,
            deleted_at = NULL
        """

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        bind(id.uuidString, to: statement, at: 1)
        bind(capture.type.rawValue, to: statement, at: 2)
        bind(capture.title, to: statement, at: 3)
        bind(capture.subtitle, to: statement, at: 4)
        bind(capture.preview, to: statement, at: 5)
        bind(capture.content, to: statement, at: 6)
        bind(capture.payloadData, to: statement, at: 7)
        bind(capture.sourceApp, to: statement, at: 8)
        bind(capture.createdAt, to: statement, at: 9)
        bind(Date(), to: statement, at: 10)
        bind(hash, to: statement, at: 11)
        bind("local", to: statement, at: 12)

        try stepDone(statement)
        return try fetchItem(contentHash: hash)
    }

    func togglePin(id: UUID) throws {
        try openIfNeeded()

        let statement = try prepare(
            """
            UPDATE clipboard_items
            SET is_pinned = CASE is_pinned WHEN 0 THEN 1 ELSE 0 END,
                updated_at = ?
            WHERE id = ? AND deleted_at IS NULL
            """
        )
        defer { sqlite3_finalize(statement) }

        bind(Date(), to: statement, at: 1)
        bind(id.uuidString, to: statement, at: 2)
        try stepDone(statement)
    }

    func delete(id: UUID) throws {
        try openIfNeeded()

        let statement = try prepare(
            """
            UPDATE clipboard_items
            SET deleted_at = ?,
                updated_at = ?,
                payload_blob = NULL,
                content = preview
            WHERE id = ?
            """
        )
        defer { sqlite3_finalize(statement) }

        let now = Date()
        bind(now, to: statement, at: 1)
        bind(now, to: statement, at: 2)
        bind(id.uuidString, to: statement, at: 3)
        try stepDone(statement)
        releaseSQLiteMemory()
    }

    func clearHistory(keepingPinned: Bool = true) throws {
        try openIfNeeded()

        let sql = keepingPinned
            ? """
              UPDATE clipboard_items
              SET deleted_at = ?, updated_at = ?, payload_blob = NULL, content = preview
              WHERE is_pinned = 0 AND deleted_at IS NULL
              """
            : """
              UPDATE clipboard_items
              SET deleted_at = ?, updated_at = ?, payload_blob = NULL, content = preview
              WHERE deleted_at IS NULL
              """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        let now = Date()
        bind(now, to: statement, at: 1)
        bind(now, to: statement, at: 2)
        try stepDone(statement)
        releaseSQLiteMemory()
    }

    func prune(maxItems: Int, retentionCutoff: Date?, keepingPinned: Bool = true) throws {
        try openIfNeeded()

        if let retentionCutoff {
            let sql = keepingPinned
                ? "DELETE FROM clipboard_items WHERE is_pinned = 0 AND created_at < ?"
                : "DELETE FROM clipboard_items WHERE created_at < ?"
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }

            bind(retentionCutoff, to: statement, at: 1)
            try stepDone(statement)
            releaseSQLiteMemory()
        }

        let protectedPinnedClause = keepingPinned ? "AND is_pinned = 0" : ""
        let sql = """
        DELETE FROM clipboard_items
        WHERE id NOT IN (
            SELECT id
            FROM clipboard_items
            WHERE deleted_at IS NULL
            ORDER BY is_pinned DESC, created_at DESC
            LIMIT ?
        )
        \(protectedPinnedClause)
        """

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(maxItems))
        try stepDone(statement)
        releaseSQLiteMemory()
    }

    private func openIfNeeded() throws {
        guard database == nil else { return }

        var connection: OpaquePointer?
        if sqlite3_open(databaseURL.path, &connection) != SQLITE_OK {
            defer { sqlite3_close(connection) }
            throw DatabaseError.openFailed(message: String(cString: sqlite3_errmsg(connection)))
        }

        database = connection
        do {
            sqlite3_busy_timeout(connection, 5_000)
            try execute("PRAGMA journal_mode = WAL")
            try execute("PRAGMA foreign_keys = ON")
            try execute("PRAGMA cache_size = -8192")
            try execute("PRAGMA mmap_size = 0")
            try migrate()
        } catch {
            sqlite3_close(connection)
            database = nil
            throw error
        }
    }

    private func migrate() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id TEXT PRIMARY KEY NOT NULL,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                subtitle TEXT,
                preview TEXT NOT NULL,
                content TEXT NOT NULL,
                payload_blob BLOB,
                source_app TEXT NOT NULL,
                created_at REAL NOT NULL,
                is_pinned INTEGER NOT NULL DEFAULT 0,
                content_hash TEXT NOT NULL UNIQUE
            )
            """
        )

        try addColumnIfNeeded(table: "clipboard_items", column: "updated_at", definition: "REAL")
        try addColumnIfNeeded(table: "clipboard_items", column: "deleted_at", definition: "REAL")
        try addColumnIfNeeded(table: "clipboard_items", column: "content_hash_algorithm", definition: "TEXT")

        try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_items_created_at ON clipboard_items(created_at DESC)")
        try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_items_is_pinned ON clipboard_items(is_pinned)")
        try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_items_deleted_at ON clipboard_items(deleted_at)")

        try execute(
            """
            UPDATE clipboard_items
            SET payload_blob = NULL,
                content = preview
            WHERE deleted_at IS NOT NULL
              AND payload_blob IS NOT NULL
            """
        )
        releaseSQLiteMemory()
    }

    private func addColumnIfNeeded(table: String, column: String, definition: String) throws {
        guard try !columnExists(table: table, column: column) else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition)")
    }

    private func columnExists(table: String, column: String) throws -> Bool {
        let statement = try prepare("PRAGMA table_info(\(table))")
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if textColumn(statement, 1) == column {
                return true
            }
        }

        return false
    }

    private func fetchItem(contentHash: String) throws -> ClipboardItem {
        let sql = """
        SELECT id, type, title, subtitle, preview, content, payload_blob, source_app, created_at,
               is_pinned
        FROM clipboard_items
        WHERE content_hash = ?
        LIMIT 1
        """

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        bind(contentHash, to: statement, at: 1)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.notFound
        }

        return try makeItem(from: statement)
    }

    private func makeItem(from statement: OpaquePointer?) throws -> ClipboardItem {
        guard
            let id = UUID(uuidString: textColumn(statement, 0)),
            let type = ClipboardItemType(rawValue: textColumn(statement, 1))
        else {
            throw DatabaseError.invalidData
        }

        let subtitle = optionalTextColumn(statement, 3)
        let payloadData = dataColumn(statement, 6)
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
        let isPinned = sqlite3_column_int(statement, 9) != 0

        return ClipboardItem(
            id: id,
            type: type,
            title: textColumn(statement, 2),
            subtitle: subtitle,
            preview: textColumn(statement, 4),
            content: textColumn(statement, 5),
            payloadData: payloadData,
            sourceApp: textColumn(statement, 7),
            createdAt: createdAt,
            isPinned: isPinned
        )
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        defer { sqlite3_free(errorMessage) }

        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            throw DatabaseError.executeFailed(message: errorMessage.map { String(cString: $0) } ?? lastErrorMessage)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.executeFailed(message: lastErrorMessage)
        }

        return statement
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(message: lastErrorMessage)
        }
    }

    private func releaseSQLiteMemory() {
        guard let database else { return }
        sqlite3_db_release_memory(database)
        try? execute("PRAGMA shrink_memory")
    }

    private func bind(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        sqlite3_bind_text(statement, index, value, -1, SQLiteTransient)
    }

    private func bind(_ value: Date?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
    }

    private func bind(_ value: Data?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        _ = value.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(value.count), SQLiteTransient)
        }
    }

    private func textColumn(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    private func optionalTextColumn(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return textColumn(statement, index)
    }

    private func dataColumn(_ statement: OpaquePointer?, _ index: Int32) -> Data? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
        let count = Int(sqlite3_column_bytes(statement, index))
        return Data(bytes: bytes, count: count)
    }

    private var lastErrorMessage: String {
        guard let database else { return "Database is not open." }
        return String(cString: sqlite3_errmsg(database))
    }


}

private let SQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DatabaseError: LocalizedError {
    case openFailed(message: String)
    case executeFailed(message: String)
    case invalidData
    case notFound

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "Could not open PasteX database: \(message)"
        case .executeFailed(let message):
            return "SQLite operation failed: \(message)"
        case .invalidData:
            return "Clipboard database row contains invalid data."
        case .notFound:
            return "Clipboard item was not found."
        }
    }
}
