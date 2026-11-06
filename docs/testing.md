# Verification

Run a Release build before publishing. Use a separate macOS account for UI tests that clear clipboard history.

- Launch the app and open history from the menu bar and global shortcut.
- Copy text, a URL, code, JSON, a color, and an image from another app.
- Search, change between list and board, and open both preview presentations.
- Copy through the row button and Command + 1 through Command + 9.
- Pin and unpin; restart and verify persisted state.
- Clear history from the main window and menu bar: test Cancel, Keep Pinned, and Delete All.
- Open preferences, change retention, and verify settings after restart.
- With a signed app installed in Applications, enable launch at login and verify after logging out and back in.
- Disconnect the network and verify all local workflows still function.

## Database Regression Check

Verify capture insertion, content deduplication, pinning, deletion, clearing with/without pinned items, and reopening the database against a temporary database. Never run destructive tests against the user's Application Support directory.

```sh
swiftc -parse-as-library \
  PasteX/Models/ClipboardItemType.swift PasteX/Models/ClipboardItem.swift \
  PasteX/Models/ClipboardCapture.swift PasteX/Services/ContentHasher.swift \
  PasteX/Persistence/ClipboardDatabase.swift Tests/DatabaseRegression.swift \
  -o /tmp/pastex-db-regression -lsqlite3
/tmp/pastex-db-regression
```
