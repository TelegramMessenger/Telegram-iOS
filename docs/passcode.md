# Passcode credentials and wallet secret storage

This documents the current passcode security implementation: persistent storage,
cryptography, verification, authorization, migration, cleanup, and wallet secrets.
Screen layout, navigation, presentation, and other UI behavior are outside its
scope. It describes the implementation in this checkout, including the new
PasscodeCore and wallet security code, rather than identifying a released version.

## Ownership and dependencies

| Component | Responsibility |
| --- | --- |
| [PasscodeCore](../submodules/PasscodeCore/Sources/Passcode.swift) | Process configuration, shared credential storage, passcode verification, attempts, access-key wrapping, biometric Keychain access, and credential mutations. |
| [PasscodeSession / PasscodeCrypto](../submodules/PasscodeCore/Sources/PasscodeCrypto.swift) | Cryptographic primitives, scoped in-memory authorization, key derivation, availability, expiry, and revocation. |
| [AccountManagerIntegration](../submodules/PasscodeCore/Sources/AccountManagerIntegration.swift) | Factory and conversions connecting the credential store to AccountManager's access-challenge hooks. |
| [AccountManager](../submodules/TelegramCore/Sources/AccountManager/AccountManagerImpl.swift) | Nonsecret lock metadata, reconciliation with the credential store, and removal of legacy plaintext metadata. |
| [WalletProtection](../submodules/WalletContext/Sources/WalletSecurity.swift) | Wallet protection policy, biometric service name, and full local-secret reset coordination. |
| [WalletSecretEnvelope / WalletVault](../submodules/WalletContext/Sources/WalletSecurity.swift) | Encrypted secret format and private Keychain access. |
| [WalletAuthorization](../submodules/WalletContext/Sources/Security/WalletAuthorization.swift), [WalletStorage](../submodules/WalletContext/Sources/WalletStorage.swift), [WalletEngineRuntime](../submodules/WalletContext/Sources/WalletEngineRuntime.swift) | Operation authorization, persistent and temporary secret handling, and propagation into Rust host callbacks. |

PasscodeCore depends on TelegramCore to supply the AccountManager bridge.
TelegramCore receives closures and does not import PasscodeCore or WalletContext.
WalletContext consumes generic resource sessions; it never receives the root
access key. Wallet policy and envelope formats stay in WalletContext.

The wallet uses the existing Telegram passcode. Wallet protection is a separate
setting shared by local accounts, and wallet biometrics are independent of
Telegram's existing app-unlock biometric preference. Unlocking Telegram does not
grant wallet-key access.

## Persistent storage and process configuration

All new Keychain records are generic-password items with synchronization
explicitly disabled. Every query specifies an access group.

| Service / account | Contents | Access group and accessibility |
| --- | --- | --- |
| `org.telegram.passcode.v1` / `credential` | Versioned JSON credential, wrappers, protection settings, and biometric cleanup journal. | Shared `group.<baseAppBundleId>`; `WhenUnlockedThisDeviceOnly`. |
| `org.telegram.passcode.v1` / `device` | Random 32-byte device secret used in passcode derivation. | Same shared group and accessibility. |
| `org.telegram.passcode.v1` / `attempts` | JSON failure count, boot identity, and monotonic cooldown deadline. | Same shared group and accessibility. |
| `org.telegram.ton-wallet.vault.v1.biometric` / `biometric.<UUID>` | Copy of the stable 32-byte access key, protected by biometric access control. | Main app's private group; `WhenPasscodeSetThisDeviceOnly` plus `biometryCurrentSet`. |
| `org.telegram.ton-wallet.vault.v1.envelope.<namespace>` / secret reference | JSON encrypted wallet-secret envelope. | Main app's private group; `WhenUnlockedThisDeviceOnly`. |
| AccountManager `atomic-state` and SQLite access-challenge row | After migration, only `.secured(id:kind:)`, or `.none` when the passcode is disabled. | Existing shared AccountManager files; no passcode or wallet key in the new challenge representation. |

Wallet namespaces are
`telegram.<production|test>.<UInt64(bitPattern: account.peerId.toInt64())>`.
They isolate Telegram accounts and environments while allowing those accounts
to share one credential and protection policy.

Process entry points configure `PasscodeEnvironment` before opening AccountManager.
The main app supplies `.mainApp`, the App Group, `walletBiometricKeychainService`,
and a private-group resolver backed by
[BuildConfig.keychainAccessGroup](../submodules/BuildConfig/Sources/BuildConfig.m).
The resolver uses the existing Keychain-derived bundle seed prefix and base app
bundle ID. Extensions configure `.appExtension` and the same App Group.

Configuration is immutable: repeating the same configuration is allowed and
retains the first resolver; changing the group, process role, or biometric service
is rejected. Private-group resolution is lazy, caches only success, and can retry
after Keychain becomes available. An empty, shared, or mismatched private group
is rejected. Missing configuration, service, or group resolution never falls back
to an unscoped query. Extension-role processes cannot access the private wallet or
biometric storage through these APIs, even if supplied a biometric service name.

The shared credential, device secret, and attempts are intentionally accessible to
extensions in the App Group. Wallet ciphertext and biometric access-key copies
remain in the private group. These are distinct boundaries: sharing the credential
does not mean sharing the wallet's secret records.

## Credential format and key hierarchy

The credential JSON schema remains version **1**. Renaming the generic Swift
property to `protectionEnabled` preserves its encoded key **`walletProtection`**.
Existing service names, cryptographic labels, and envelope formats are retained.

| Field | Meaning |
| --- | --- |
| `version`, `id`, `revision` | Format version, stable credential UUID, and revision used to reject stale authorization. |
| `managedPasscode` | Whether this record is authoritative over legacy AccountManager metadata, including an intentional passcode removal. |
| `kind` | Optional `digits4`, `digits6`, or `alphanumeric`; absent when no passcode is set. |
| `salt`, `iterations`, `wrappedKey` | Passcode KDF parameters and AES-GCM-wrapped access key. |
| `unprotectedKey` | Access-key copy present while resource protection is disabled. “Unprotected” means no app-passcode wrapper; the containing Keychain item is still device-only and available only while unlocked. |
| `walletProtection` | Whether the access key requires passcode or wallet-biometric authorization. |
| `biometricAccount` | Committed biometric route, if any. |
| `pendingBiometricAccount`, `biometricCleanup` | Pending enrollment and obsolete accounts awaiting deletion. |

The access key is a random **256-bit** value that stays stable across passcode
changes and protection toggles. The passcode is neither stored nor compared to a
plaintext verifier. Successful authenticated decryption of its access-key wrapper
is the verification check.

The derivation and wrapping steps are:

```text
normalizedCode = normalize(code, kind)
password = HMAC-SHA256(
    key = deviceSecret,
    message = UTF8("telegram.passcode.v1\0" + normalizedCode)
)
KEK = PBKDF2-HMAC-SHA256(password, salt, iterations, output = 32 bytes)
wrappedKey = AES-256-GCM(
    key = KEK,
    plaintext = accessKey,
    AAD = UTF8("credential.v1:<credentialId>:<kind>")
)
```

`SecRandomCopyBytes` generates keys, salts, and nonces. Each wrap uses a fresh
**16-byte salt** and **12-byte nonce**. CommonCrypto calibrates PBKDF2 toward
**350 ms**, clamped to **600,000–3,000,000 iterations**, and the actual count is
stored with the wrapper. Derivation rejects parameters outside those bounds.
CryptoKit's combined AES-GCM representation is nonce, ciphertext, and 16-byte tag;
wrapping a 32-byte key therefore produces **60 bytes**. A newly created wrapper is
opened and compared with the original key before being committed.

Numeric normalization maps characters with a single-digit `wholeNumberValue`
below ten to ASCII digits. Setup then requires exactly four or six ASCII digits.
Alphanumeric codes use Unicode canonical precomposition and must be nonempty;
this preserves Swift's canonical-equivalence behavior for legacy strings. No
trimming, case folding, or new alphanumeric length rule is introduced by Core.

Loading a credential checks its version, nonempty ID, positive revision, wrapper
shape, and protection invariants. An enabled protection flag requires a passcode
and forbids an unprotected key; disabled protection requires a 32-byte unprotected
key. Once a `.secured` challenge has established that a credential must exist,
its absence is an error, never permission to generate a new unprotected root.
An existing credential's missing or malformed device secret is not regenerated.

## Verification, attempts, and locking

`verify` loads the current credential and checks a supplied credential reference's
ID before trying the code. It checks the shared cooldown, derives the KEK, and
authenticates the wrapper. Success removes `attempts` and issues a session bound
to the credential ID, revision, requested scope, and lifetime.

A wrapper-authentication failure records an incorrect attempt and returns
`invalidCode`. This also means damage that passes the wrapper's structural checks
can surface as an incorrect code. Missing storage, invalid KDF parameters, or a
missing device secret fail before this attempt-increment path. Biometric failures
and cancellations do not run the incorrect-PIN path. A synchronous PIN check
already in progress can finish after its caller cancels; consumers must reject
and invalidate a late successful session.

The first five incorrect attempts have no cooldown. The sixth sets a **60-second**
deadline; each later wrong attempt after a cooldown expires starts another
60 seconds. Expiry alone does not clear the accumulated count. There is no
increasing delay or destructive wipe in this counter. Successful verification,
passcode change/removal, and full credential reset clear it.

The stored boot identity comes from `kern.boottime`, and deadlines use system
uptime, not wall-clock time. Reopening the store preserves the deadline. After a
boot change, a count of at least six starts a fresh 60-second cooldown; rebooting
does not clear it. Decoding rejects invalid counts, nonfinite/negative deadlines,
and same-boot deadlines more than 60 seconds in the future. Counts saturate at
1,000,000, preventing overflow.

The old AppLock attempt fields/API remain for compatibility, but current PIN
submission uses the credential store's verification and cooldown. Legacy
app-lock JSON counters are no longer the enforcement authority. Existing app-lock
and Share PIN entry points migrate a legacy challenge before verifying through
Core, rather than comparing input with metadata strings.

Production AccountManagers configure
`<accounts-metadata>/passcode-v1.lock`. Credential and attempt read/modify/write
operations hold an `NSRecursiveLock` and an exclusive `flock` on that file. The
main app and extensions, including temporary AccountManagers, use the same path.
Failure to open or acquire the configured file lock returns `unavailable` rather
than proceeding without serialization. Standalone injected stores can omit the
file lock; the production factory is responsible for installing it.

## Sessions and authorization checks

`PasscodeSession` is the single in-memory authorization object. Its identity,
scope, authentication origin, key, revision, deadline, and revocation state are
shared across every reference; there is no independent wallet grant containing a
copy of the root key.

| Scope | Capability |
| --- | --- |
| `.appUnlock` | Verify the app's lock challenge; cannot derive wallet/resource keys or mutate credentials. |
| `.managePasscode` | Change or disable the passcode, with passcode-origin authentication. |
| `.settings` | Change protection/biometric settings and change or disable the passcode, with passcode-origin authentication. Cannot derive resource keys. |
| `.resource(namespace:)` | Derive keys only for that exact nonempty namespace. Cannot authorize passcode/settings mutations. |

`withDerivedKey(namespace:domain:)` requires an exact resource scope and nonempty
namespace/domain. It derives 32 bytes using HKDF-SHA256, with the access key as
input key material, UTF-8 namespace as salt, and UTF-8 consumer domain as info.
Only the derived key reaches the consumer closure. Registration, validity checks,
key use, availability, and revocation use the same recursive session-registry
lock, so revocation cannot miss a session registered during key use.

Standard sessions expire after **five minutes**, measured using uptime, and are
revoked on backgrounding or an actual app lock. `.ownerManaged` is permitted only
for resource scopes: it has no deadline, suspends key use while unavailable, and
must be finished by its operation owner. Its availability wait supports cancellation
and fails on revocation. These sessions are used for explicitly owned creation,
import/restoration, and backup operations; ordinary sensitive actions use standard
sessions. Sessions are not persisted across process termination.

AppLock owns the foreground-and-unlocked key-access gate. The actual passcode-lock
signal is distinct from temporary app inactivity: an inactive/active transition
around a biometric prompt is not itself a credential revocation. Opening the
availability gate resumes permitted work but never revives a revoked session.
Credential changes, account changes, and unrelated wallet replacement revoke
authorization even for owner-managed work.

Credential mutations invalidate local sessions. Store validation also compares
the session's ID/revision with the persisted credential, catching changes observed
from another process. `isValid` alone checks local lifetime/revocation, not current
persistent credential state; storage consumers must perform store validation too.

## Credential changes and commit behavior

Initial setup may create a credential without prior authorization when no passcode
exists. Changing or disabling an existing passcode requires a live, matching,
passcode-origin management or settings session. Unprotected and biometric resource
sessions cannot be promoted into that authority.

Setting a passcode when none exists, including after passcode removal, automatically
enables wallet protection (Confirm with Passcode). The new passcode wrapper,
`protectionEnabled = true`, and removal of `unprotectedKey` are committed in the
same credential-item update, preserving the existing access key. Changing an
existing passcode preserves the user's protection setting. Setup does not enable
wallet biometrics, and legacy passcode migration retains its existing behavior.

A passcode change rewraps the **same access key** with new salt/KDF parameters and
nonce, increments the revision, and marks the record managed. Wallet envelopes
and their DEKs do not change. Authorization is rechecked after derivation and
before the write. `setPasscodeWithSettingsSession` can return a fresh settings
session for the updated credential; a failed precommit operation invalidates its
candidate session. A successful passcode change revokes the old sessions.

Enabling protection removes `unprotectedKey` in the same credential-item update
that sets the flag. Disabling protection restores the access-key copy and removes
the committed biometric route in that same update. Disabling the passcode also
clears its kind/KDF/wrapper fields and disables both protection and wallet
biometrics, while preserving the access key and marking the removal authoritative.

Settings mutations retain the authenticated settings session and advance its
revision after commit, while revoking other sessions. They preserve its original
deadline. A credential commit or subsequent cleanup never makes an externally
revoked session valid again. Wallet setters validate first and treat an unchanged
setting as a no-op.

“Atomic” refers to replacing the credential Keychain item. Attempts removal,
AccountManager writes, and obsolete biometric deletion are separate operations.
Once the credential write begins and succeeds, cancellation cannot pretend that
the old credential is still authoritative: callers reconcile the committed result
and invalidate any session that must no longer be delivered. Cleanup failure after
commit may return an error while the new setting is already in force.

## Wallet biometric key access

Wallet biometrics release the access key through an actual protected Keychain
read using an `LAContext`. A Boolean LocalAuthentication result is not a substitute
for this read. The ACL is `biometryCurrentSet` with
`WhenPasscodeSetThisDeviceOnly`; it does not include a system-device-passcode
fallback. Telegram's separate app-unlock biometric path does not release this key.

Enrollment requires a passcode-authenticated settings session and enabled wallet
protection. It uses a new `biometric.<UUID>` account rather than updating an
existing item's ACL:

1. Retry old cleanup, then persist `pendingBiometricAccount` before creating the item.
2. Write the access key under the biometric ACL.
3. Read it through the supplied `LAContext` and compare it with the session's key.
4. Revalidate the session and pending account under the credential lock.
5. Commit the new account/revision, moving any previous account into the cleanup journal.
6. Revoke other sessions, advance the retained settings session, and delete obsolete entries.

A failure during the protected read or finalization before commit attempts to
delete its candidate. A failure in the initial enrollment-write phase leaves any
saved pending journal for later cleanup. Both preserve the previous committed
route. After commit, cleanup failure retains the new route and
journal; it must not delete the newly committed key. Disabling biometrics likewise
commits removal of the route before deleting its old item. `resumeCleanup()` turns
any pending enrollment into cleanup work and retries deletions. Journal-only writes
do not publish credential-change notifications.

Biometric authentication can issue only resource sessions. After the protected
read, the store validates the credential revision before returning the session,
rejecting a result made stale while the OS prompt was outstanding. Losing the
biometric item or changing enrollment does not remove the passcode wrapper; the
passcode remains the route for recovery and reenrollment.

## AccountManager migration and metadata cleanup

Legacy `.numericalPassword(String)` and `.plaintextPassword(String)` challenges
remain readable for migration. New challenges use `.secured(id:kind:)` and contain
no code. A malformed existing challenge is represented as a secured invalid
challenge rather than silently becoming `.none`.

The production `passcodeAccountManager` factory provides three synchronous hooks:
`prepare`, `resolve`, and `finishInitialization`. Preparation configures the shared
file lock and handles fresh-install cleanup before the initial atomic state is
written. Resolution consults the credential store; finishing initialization retries
biometric cleanup in the main process.

Migration proceeds in this order:

1. Reconcile the existing atomic-state and SQLite challenge representations.
2. Resolve an already managed Keychain credential first. Otherwise, when migration
   is allowed, wrap the legacy code and commit `managedPasscode = true` in Keychain.
   Six-character numerical codes retain `digits6`; other numerical legacy codes
   use `digits4`; plaintext codes use `alphanumeric`.
3. Securely remove the old SQLite challenge row, then write and commit its
   replacement with the nonsecret reference, or remove it for a committed `.none`.
4. Atomically rewrite `atomic-state` with the same authoritative challenge.
5. Outside the metadata transaction, invoke `VACUUM` and a truncating WAL checkpoint,
   then attempt to write `passcode-v1-metadata-clean` to record completed cleanup.

The Keychain commit is authoritative before either metadata copy is updated.
`managedReference()` distinguishes an unmanaged/missing record from a managed
record with no passcode. This prevents stale plaintext metadata from restoring an
old passcode or undoing a disable operation. Once a `.secured` reference has been
observed, the store requires an existing credential and cannot silently replace it.

Initialization permits migration for writable, nontemporary AccountManagers;
temporary/read-only initialization does not persist the migration. Transactional
challenge reads also resolve through the credential service. Direct metadata
setters accept a proposed value only if it equals the service's authoritative
result, so metadata callers cannot independently create, change, or remove a code.
Migration errors preserve the existing lock metadata and defer work.

If cleanup is interrupted before its marker is recorded, a later writable
initialization or transaction retries it. This removes current plaintext metadata
and asks SQLite to reclaim its remnants; it cannot guarantee physical erasure of
historical filesystem snapshots or flash cells. The underlying `vacuum()` requires
both SQLite commands to succeed using preconditions; it does not expose a
recoverable cleanup error to AccountManager.

Sources: [challenge encoding and secure row replacement](../submodules/TelegramCore/Sources/AccountManager/AccountManagerMetadataTable.swift),
[atomic-state decoding](../submodules/TelegramCore/Sources/AccountManager/AccountManagerAtomicState.swift),
[reconciliation and cleanup](../submodules/TelegramCore/Sources/AccountManager/AccountManagerImpl.swift),
[SQLite cleanup](../submodules/Postbox/Sources/SqliteValueBox.swift).

## Wallet envelope encryption and integrity checks

Each secret has an independent random **32-byte data-encryption key (DEK)** and
immutable UUID `secretId`. The version-1 JSON envelope contains `version`, `vaultId`,
`secretId`, `wrappedDek`, and `ciphertext`.

```text
wrappingKey = HKDF-SHA256(
    input = accessKey,
    salt = UTF8(namespace),
    info = UTF8("telegram.wallet.dek.v1"),
    output = 32 bytes
)
wrappedDek = AES-256-GCM(
    key = wrappingKey, plaintext = DEK,
    AAD = UTF8("dek.v1:<namespace>:<secretId>")
)
ciphertext = AES-256-GCM(
    key = DEK, plaintext = secret,
    AAD = UTF8("secret.v1:<namespace>:<secretId>")
)
```

The two seals use independently generated 12-byte nonces. Empty secrets and vault
IDs are rejected during encryption. Decryption requires version 1, the expected
vault ID, a nonempty secret ID, and a live session for exactly that namespace. Both
the wrapped DEK and payload must authenticate. Namespace/domain separation and
the two AAD labels prevent cross-account use and substitution of mismatched
envelope parts.

The authenticated identity is the immutable `secretId`, not the Keychain account
name or active/candidate/rollback slot. This intentionally permits copying an
envelope during wallet replacement and rotation. The serialized version is checked
explicitly; the AAD labels select the version-1 cryptographic construction. Do not
add slot binding without redesigning those transitions. The wallet recovery path
also validates that a recovered phrase matches the wallet's public identity before
local installation, as described below.

## Wallet secret storage lifecycle

Before **enabling wallet protection**, `setWalletProtectionEnabled` validates the
settings session and checks the current protection state, then resumes biometric
cleanup before removing the unprotected root key copy in the protection commit.

WalletStorage reads, writes, checks for, and deletes secrets only in the encrypted
envelope service. Presence checking does not itself prove that an existing
envelope decrypts. Old plaintext wallet records are not read or migrated.

Active signing secrets, replacement candidates, and rotation candidates are
encrypted envelopes. Rollback storage, candidate promotion, and restoration copy
the existing envelope bytes where the same secret is being moved. Temporary
import/capture secrets are also stored as encrypted envelopes in memory and opened
only under scoped authorization. A passcode change leaves all of these ciphertexts
usable because the access key is stable.

Wallet descriptors, rotation/replacement journals, and TON Connect session records
remain separate device-only private Keychain records; they are not mnemonic
envelopes. Descriptors and journals retain secret references and public metadata,
while mnemonic payloads belong in the secret store. Plaintext still exists
transiently when displaying/exporting a phrase or supplying it to the engine.

[WalletLogger](../submodules/WalletContext/Sources/WalletLogger.swift) records error
type, domain, code, and classified kind instead of interpolating the error payload
in its structured error path. Generic fallback diagnostics still format arbitrary
error text and strip controls/truncate it; that is not comprehensive secret
redaction. Keep passcodes, phrases, and keys out of errors and log contexts.

## Wallet operations, Rust callbacks, and backup recovery

`WalletAuthorizationContext` registers sessions by identity for its namespace and
validates the credential revision, availability, and optional prepared-operation
session ID. Operation/result generations reject stale completion after account,
credential, or wallet changes. Independent actions do not inherit authorization
merely because an earlier action succeeded. Explicit owners finish their sessions
on completion or abandonment.

Swift `TaskLocal` carries the session during wallet work. UniFFI launches separate
tasks, so the serialized runtime explicitly installs the current session on the
platform host for an FFI call and clears it afterward. Host callbacks restore that
scope and check authorization before reading or writing persistent or temporary
secrets. An upstream request for user presence is satisfied by the app's
foreground/unlocked availability and configured wallet protection policy, including
a scoped unprotected session when protection is off.

Public balances and history do not require secret access. Sensitive operations
such as signing, phrase access, and encrypted-comment work use the authorization
path. Prepared operations bind to their session identity; retaining a session does
not extend its deadline. Owner-managed authorization also does not extend an
engine-generated transaction's expiry or bypass sequence-number checks.

The existing Telegram server backup is a separate recovery mechanism. Local
passcode changes rewrap local access; they do not rewrite the server backup or
turn the passcode into a server-recovery password. Automatic server phrase export
is disabled while wallet protection is enabled, preventing a missing local secret
from silently bypassing protection through backup. Explicit restoration retains
the existing Telegram account/2FA requirements and installs the recovered phrase
through the protected local storage path.

For context, the [backup codec](../submodules/WalletContext/Sources/WalletPhraseCodec.swift)
normalizes mnemonic words to lowercase, joins them with spaces, and pads the UTF-8
text with spaces to **215 bytes**. [WalletBackupCrypto](../submodules/WalletBackupCrypto/Sources/WalletBackupCrypto.mm)
splits that text into three 215-byte XOR shares, all required for recovery:
two random shares and a third equal to the text XOR both. It prepends
`08 dd 90 8b d7` to **each share after splitting**, then encrypts the resulting
220-byte payload for its 32-byte holder public key using the tde2e ECDH/message
APIs and a distinct ephemeral key. Export uses a fresh client key pair, decrypts
and XORs the three complete payloads, validates and removes the reconstructed
prefix, and verifies canonical phrase encoding of the remaining 215 bytes.
The derived 32-byte public key must match the expected wallet identity before
local installation. XOR of three identical prefixes restores that prefix, so
this reader also supports interim backups that split an already-prefixed
220-byte mnemonic block; no migration or separate fallback is needed.
The local passcode is not an input to this backup encryption.

## Destructive reset and fresh installations

`resetWalletLocalSecrets(environment:credentials:)` coordinates removal of local
wallet records and credential replacement. It requires the main-app environment.
Its production startup use is a confirmed fresh installation, where all three are
true: no AccountManager `atomic-state` file, no legacy account records, and no
legacy access challenge. This handles Keychain records surviving an uninstall.
Temporary/read-only managers and extensions do not perform the startup reset.

Reset runs before the initial atomic state is written, legacy PIN migration, and
wallet runtime creation. Under the credential lock it:

1. Revokes all local sessions.
2. Enumerates private-group Keychain attributes and deletes records whose service
   starts with `org.telegram.ton-wallet.`: descriptors, legacy/encrypted secrets,
   candidates, rollback records, journals, TON Connect sessions, and biometric keys.
3. Removes the shared attempt counter.
4. Writes a new random device secret and a new credential with a fresh ID/access
   key, no passcode, protection disabled, and `managedPasscode = true`.

Cleanup does not read old wallet secrets or require a decodable old credential,
so missing/corrupt credential data can be removed. Its closure must not reenter
the credential store. If wallet deletion fails, persisted credential keys remain
unchanged, but sessions are already revoked and some wallet items may already
have been deleted. Device-key and credential writes are separate too: this is a
destructive sequence with retry handling, not a transaction across Keychain items.

Preparation failure prevents writing initial AccountManager state, allowing a
later startup to retry the fresh-install cleanup. This path is not triggered by
incorrect codes or ordinary startup. It requires access to the configured groups
and cannot erase records in an old group the app can no longer access. It removes
local wallet data; it does not delete a server backup.

## Verification coverage and limits

The standalone suites exercise production cryptography and injectable security
logic without building the full application:

```sh
rtk proxy swift test --package-path submodules/PasscodeCore
rtk proxy swift test --package-path submodules/WalletContext
```

| Suite | Relevant coverage |
| --- | --- |
| [PasscodeCoreTests](../submodules/PasscodeCore/Tests/PasscodeCoreTests.swift) | Verification, Unicode compatibility, stable derived keys across PIN changes, fresh salts/nonces, cooldown/reboot behavior, corrupt/missing records, scope and authentication-origin checks, expiry/revocation races, cancellation around commit, settings-session retention, biometric journaling/cleanup failures, and reset ordering. |
| [PasscodeEnvironmentTests](../submodules/PasscodeCore/Tests/PasscodeEnvironmentTests.swift) | Explicit query groups, immutable configuration, deferred private-group resolution, missing service/configuration, and extension restrictions. |
| [PasscodeInterprocessTests](../submodules/PasscodeCore/Tests/PasscodeInterprocessTests.swift) | Separate processes using production `flock` against injected atomic file storage, preservation of six concurrent wrong attempts and cooldown, reset cleanup holding the lock, and lock-open failures. |
| [WalletSecurityTests](../submodules/WalletContext/TestsSecurity/WalletSecurityTests.swift), [WalletProtectionTests](../submodules/WalletContext/TestsSecurity/WalletProtectionTests.swift) | Envelope/namespace tampering, session isolation/lifetimes, private cleanup/reset, and fixed pre-refactor credential/envelope compatibility fixtures. |

PasscodeCore's SwiftPM target excludes `AccountManagerIntegration.swift`.
WalletContext's standalone package compiles `Sources/Security`, without the full
WalletStorage, Telegram networking, UI, or Rust integration. Those bridges require
the production Bazel build and integration/device validation. Injected biometric
tests do not exercise a real sensor or signed Keychain entitlement enforcement.
These commands describe the available checks; they are not a claim that a build
or device validation was performed when this document was written.

Integration checks should cover upgrades with each legacy code kind and multiple
wallet namespaces; interrupted metadata/envelope/biometric commits; shared main-app
and Share Extension attempts; unavailable Keychain after lock/restore; biometric
enrollment changes and PIN recovery; reboot during cooldown; fresh-install cleanup;
and key access during background, lock, account change, and FFI callbacks. KDF
calibration and private/shared Keychain boundaries require signed-device checks.

The protection model relies on Keychain access controls and trusted application
code. Extracting both the credential and device secret still permits offline
guesses at the configured KDF cost; the software attempt counter is not an offline
rate limiter. When protection is disabled, the unprotected access-key copy is an
intentional bypass of PIN derivation for wallet access. This does not defend
against arbitrary execution in the main app, a compromised OS, or possession of
the recovery phrase. Swift `String`/`Data` and cryptographic libraries may retain
copies, so explicit buffer clearing is best effort rather than guaranteed physical
RAM erasure.
