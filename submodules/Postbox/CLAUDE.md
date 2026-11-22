# Postbox — agent notes

Who may import Postbox (the Postbox → TelegramEngine refactor rules and its guard) is in the root `CLAUDE.md`. Upgrading the SQLCipher it runs on: `submodules/sqlcipher/CLAUDE.md`.

## `SqliteValueBox` self-heal policy

Tested in `Postbox/Tests/SqliteValueBoxRecoveryPolicyTests.swift`. The app and its extensions share one WAL database:

- **Only the owner deletes.** Deleting the database to recover is done only by the owning read-write connection
  (`removeDatabaseOnError` is folded with `!isReadOnly && !isTemporary` in `init`), always as the whole `db_sqlite` +
  `-wal` + `-shm` set (`removeDatabaseFiles`), and never on a transient result. Deleting `db_sqlite` alone makes the
  relaunched app share the extension's still-mapped `-shm` with a different WAL file (repeated "Corrupted DB at step,
  dropping").
- **The schema probe gives no verdict on transient errors.** `SQLITE_BUSY`/`LOCKED`/`IOERR`/`CANTOPEN`/… make it return
  `.unavailable`; lock contention (`BUSY`/`LOCKED`/`PROTOCOL`) is retried exactly once (each attempt already waits the
  5 s busy timeout), then the owner crashes without touching files while a non-owner reports no database. The crash is
  deliberate: `accountWithId` maps the owner's `.error` to a permanent `.upgrading(0.0)`, so returning nil would hang
  the launch screen.
- **Probe results (busy, disk full, I/O) never feed a deletion fallback**: they clear on relaunch or when space is
  freed, and deleting the account database is not a recovery.
- **The one valve is a failed `sqlite3_open_v2`** (`Database.open`): the owner records the failure in
  `db_sqlite-open-failures` and wipes on the third consecutive one, but only for errnos deleting could fix (EISDIR,
  EIO, unknown). EPERM and EACCES (data protection before first unlock), descriptor exhaustion, out of memory and disk
  full never advance it; a successful open resets it.
- The same owner fold gates in-place reencryption (`forceEncryptionIfNoSet`): a non-owner never rewrites the live file.
- `.tempkey` creation in `BuildConfig.m` is serialized across processes with `flock` on `.tempkey.lock`: two
  generators would each key a database with material only one of them persisted.

## Postbox shared-media removal (deferred design: tombstones)

`Transaction.updateMedia(id, update: nil)` is meant to remove a media from every message that carries it. Its one use:
the server answers a web-page update with `webPageEmpty` (no preview for that URL) and `UpdateInterpreter`
turns it into a nil media update (replayed through `updateMessageMedia(transaction:id:media:)`). The intended end state
matches a fresh store of such a message, which has no web-page media.

**Open defect:** it works only for media **embedded** in a single message (the message is rewritten and an
`.UpdateEmbeddedMedia` operation is emitted). For a **shared record** — two or more messages carry the same media id,
which pasting or forwarding the same link produces, since web-page ids are stable per URL —
`MessageHistoryTable.updateMedia` only decrements the record's reference count: the record stays, every message keeps
the preview, and views are not told, because `updatedMedia[id] = nil` on a `[MediaId: Media?]` **deletes the key**
instead of storing `.some(nil)`. Each further empty update decrements again, so the record is freed while messages
still reference it. The root cause: the media table knows only a *count* for a shared record, not which messages
reference it; the only reverse lookup is `enumerateMediaMessages`, a history scan.

**Decided design, not implemented yet: a tombstone.** Rewrite the `Direct` record into a flagged row whose `get`
returns no media, leave the reference count untouched, and record the removal with
`updatedMedia.updateValue(nil, forKey: id)` so live views drop it (the history view's `updateMedia` already handles
`.some(nil)`). Every render then omits the media, the count stays honest so the row is deleted on the final
dereference as today, and a later real update for the same id revives it for every referencing message at once.

- Do **not** delete the row immediately: the stale ids left in the messages' reference arrays would corrupt the count
  when the same id reappears (old messages would resolve a new message's embedded copy, and their later removal would
  decrement a count they never contributed to).
- The fully correct alternative is a reverse index (media id → message indices) beside the reference arrays, which
  also lets the per-message tag recomputation in `updateMessageMedia` run. It needs a version bump and a rebuild from
  the scan, so it replaces the tombstone only if a tag turns out to derive from the web-page media rather than the URL
  entity.
- Tests belong in `submodules/Postbox/Tests/` on `PostboxFixture` (two messages sharing one media, then an empty
  update).
