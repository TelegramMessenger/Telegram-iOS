# build-system/Make — agent notes

## CI builds in tart VMs (and why every download needs a checksum)

GitLab CI (`.gitlab-ci.yml`) builds, uploads to TestFlight and verifies in tart VMs on the runner host:
`Make.py vm-build` / `vm-deploy-testflight` / `vm-ipa-diff` (`build-system/Make/TartBuild.py`), each in an ephemeral
clone of `macos-<macos>-xcode-<xcode>` from `versions.json` (uploads use `deploy_xcode`). One VM runs per host
(an flock at `~/.telegram-build/vm-build.lock`); CI passes `--waitForLock` so a second job queues instead of failing.
gitlab-runner runs as a launchd service whose PATH has no Homebrew, so `tart` is resolved via `TART_PATH`, PATH, then
the Homebrew locations. The bazel cache is bazel-remote on the runner host (`TELEGRAM_BAZEL_CACHE_HOST`); the guest
reaches it through tart's NAT at the host's LAN address or the gateway (`grpc://@auto:9092`).

**Every external download must carry a checksum.** Make.py points both `--remote_cache` and
`--experimental_remote_downloader` at bazel-remote, so bazel asks bazel-remote to fetch each archive and waits for the
whole download under the 60s `--remote_timeout`. bazel-remote serves an archive from its store only when the request
names its sha256; without one it re-downloads it from the internet on every build (the repository cache needs the
checksum too, and each ephemeral VM starts with an empty one). On the runner's slow link a large archive misses the
deadline: the build log fills with `Remote Cache: DEADLINE_EXCEEDED … remote_addr=…:9092`, the guest sits idle, and
after the retries `--experimental_remote_downloader_local_fallback` (`.bazelrc`) downloads it again inside the VM. That
reads like the VM cannot reach the cache; check with `curl http://<cache>:8080/status` from the guest (answers in
milliseconds if reachable). The tell is bazel-remote holding an outbound connection to the archive's host.

rules_rust 0.74.0 knows checksums only up to Rust 1.98.0, so `MODULE.bazel` supplies 1.98.1's in
`rust.toolchain(sha256s = …)`. **Bumping the Rust version means updating that dict** (each archive's checksum is at
`static.rust-lang.org/dist/<archive>.sha256`), or dropping it once rules_rust's `known_shas.bzl` covers the version.

## Replaying a release-only compiler crash from a CI log

For crashes like "Swift 6.4: SimplifyCFG crash in release builds only" in the root `CLAUDE.md`.

Replay the frontend command from the CI log in the bazel execroot. A single file only reproduces with a caller added,
because WMO deletes an internal function nothing calls before optimizing it. Give the replay its own
`-module-cache-path`: the default relative `bazel-out/…/_swift_module_cache`, run from the workspace instead of the
execroot, writes pcms into bazel's shared cache under a second path (the `bazel-out` symlink), and the next build fails
with "module '_DarwinFoundation1' is defined in both". Delete the hash directory it wrote to recover.

`Make.py build --target` on a bare `swift_library` builds it for the host (`no such module 'UIKit'`); a library gets its
iOS configuration only through the app's transition.
