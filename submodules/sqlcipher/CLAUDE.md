# Upgrading the vendored SQLCipher

`submodules/sqlcipher` is the SQLCipher **amalgamation** (one `Sources/sqlite3.c` plus the three public headers), not
the source tree; currently SQLCipher 4.19.0 / SQLite 3.53.4. Keep SQLite at 3.51.3 or later: it carries the WAL-reset
corruption fix, which matters because the app and the notification extension write and checkpoint the same WAL
database.

A SQLCipher release archive does not ship the amalgamation; generate it from the tree:

```sh
./configure --with-tempstore=yes --enable-fts5 \
  CFLAGS="-DSQLITE_HAS_CODEC -DSQLITE_EXTRA_INIT=sqlcipher_extra_init -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown -DSQLCIPHER_CRYPTO_CC" \
  LDFLAGS="-framework Security -framework Foundation"
make sqlite3.c sqlite3.h     # also copies sqlite3ext.h and ext/session/sqlite3session.h to the root
```

(needs `/usr/bin/tclsh`; the configure flags do not bake into the amalgamation, every feature is selected by the `-D`s
in `BUILD`). Copy `sqlite3.c` to `Sources/` and the three headers to `PublicHeaders/sqlcipher/`. Then check
`sqlite3.c` for `#define SQLITE_VERSION` and `CIPHER_VERSION_NUMBER` rather than trusting the archive name.

Non-obvious points:

- **`sqlcipher.c` `#error`s** unless `SQLITE_EXTRA_INIT=sqlcipher_extra_init`,
  `SQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown`, `SQLITE_THREADSAFE` in {1,2} and `SQLITE_TEMP_STORE` in {2,3} are
  all defined. `BUILD` and `Package.swift` carry them; keep the two in sync.
- **Keep the amalgamation pristine.** Don't hand-edit SQLite's `MIN`/`MAX` macros to quiet clang's
  `-Wambiguous-macro` under `enable_modules`; `BUILD` passes `-Wno-ambiguous-macro` instead.
- **Behaviour that touches `SqliteValueBox`:** `PRAGMA cipher_memory_security = OFF` is a no-op (memory security can
  only be turned on); `PRAGMA key` on a connection that has already decrypted a page is ignored with a log line, so
  re-keying means opening a new connection (which the value box already does); a keyless
  `PRAGMA cipher_plaintext_header_size` is a silent no-op and only `cipher_default_plaintext_header_size` applies
  before `PRAGMA key`.
- The `-W#warnings` suppression is for `"gethostuuid() is disabled."`, which the amalgamation emits on iOS. A
  `clang -fsyntax-only` pass with the `BUILD` defines is a 1-second smoke check.

The recovery policy of the database it opens (`SqliteValueBox`'s self-heal) is in `submodules/Postbox/CLAUDE.md`.
