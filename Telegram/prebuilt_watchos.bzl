"""Embeds the standalone, xcodebuild-built tgwatch watch app into the Bazel iOS build.

`apple_prebuilt_watchos_application` builds the watch app in two actions and exposes
it through the providers that `ios_application(watch_application = ...)` consumes:

  1. PrebuiltWatchosCompile (prebuilt_watchos_compile.sh) — runs `xcodebuild` against
     the exported tgwatch source tree, baking the api credentials and the bundle id but
     leaving PLACEHOLDER versions, and emits an unsigned .app archive.
  2. PrebuiltWatchosPatchSign (prebuilt_watchos_patch.sh) — rewrites the two per-build
     Info.plist version keys on the compiled app, then optionally codesigns it.

Splitting them lets Bazel cache the expensive (~4-min) compile across build numbers and
version bumps — which is every CI build, since `--define=buildNumber` changes each time.
Only the version is deferred to the patch step: the api id/hash and the bundle id are
stable for a given host configuration, so they stay baked by xcodebuild (the watch
Info.plist derives WKCompanionAppBundleIdentifier from PRODUCT_BUNDLE_IDENTIFIER via
$(...:base), so no bundle-id plist mutation is needed). Neither the version nor the api
values reach the compiled binary — they live only in Info.plist — so deferring them
cannot change the compiled output.

The providers exposed:

  * AppleBundleInfo      — bundle metadata (the host reads only `.product_type`).
  * AppleEmbeddableInfo  — `watch_bundles` (the zipped .app placed under Watch/).

The watch source tree is the committed in-repo snapshot at `Telegram/WatchApp/` (tracked
inputs). To update it, re-sync from the standalone tgwatch repo via
`tgwatch/tools/export-sources.sh`.

Notes on the rules_apple providers used here:
  * AppleBundleInfo's public init is banned; we build it with the internal raw
    initializer `new_applebundleinfo` (rules_apple is vendored + pinned in this repo,
    so depending on the internal label is safe).
"""

load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "new_applebundleinfo",
    "new_watchosapplicationbundleinfo",
)
load("@build_bazel_rules_apple//apple/internal/providers:embeddable_info.bzl", "AppleEmbeddableInfo")

def _apple_prebuilt_watchos_application_impl(ctx):
    # The watch app is built from the committed in-repo snapshot at Telegram/WatchApp,
    # tracked as inputs (incremental + cacheable).
    source_path = ctx.attr.in_repo_source_dir
    api_id = ctx.var.get("watchApiId", "0")
    api_hash = ctx.var.get("watchApiHash", "placeholder")
    identity = ctx.var.get("watchSigningIdentity", "")

    # The provisioning profile is an external, machine-specific absolute path passed via
    # --define rather than a Bazel label, so the gitignored profile need not be exposed as
    # a target. The local action reads it directly. Empty => unsigned build; when set but
    # the identity is empty, the worker derives the signing identity from the profile.
    profile = ctx.var.get("watchProvisioningProfile", "")

    # The embedded watch app's CFBundleShortVersionString / CFBundleVersion must match
    # the host app, or rules_apple's child-version verification fails. Source the
    # marketing version from versions.json (same as the host's VersionInfoPlist) and the
    # build version from buildNumber (Make.py always emits --define=buildNumber). Both
    # reach the patch action only, never the compile action.
    build_number = ctx.var.get("buildNumber", "1")
    archive = ctx.actions.declare_file(ctx.label.name + ".zip")

    # Intermediate output of the compile action: the unsigned, placeholder-version .app.
    compiled_archive = ctx.actions.declare_file(ctx.label.name + "_compiled.zip")

    # The host ios_application reads the watch app's Info.plist (via AppleBundleInfo.infoplist)
    # to verify WKCompanionAppBundleIdentifier against the host bundle id, so expose it as a
    # separate output (resources.bzl bundle_verification crashes on a None infoplist).
    infoplist = ctx.actions.declare_file(ctx.label.name + "_Info.plist")

    # The compile action runs xcodebuild locally (it needs the host's Xcode + SwiftPM
    # network access), but its output — an unsigned, placeholder-version .app — is
    # portable across machines that share the same Xcode SDK, so it IS shared via the
    # cache: `no-remote-exec` pins execution local while still allowing Bazel to
    # read/write the `--remote_cache` / `--disk_cache`.
    #
    # Note the deliberate absence of `"local": "1"`. Verified against the vendored
    # bazel 8.4.2 via --execution_log_json_file: `local` alone sets cacheable=false and
    # remoteCacheable=false, so it silently defeats every cache — including the disk
    # cache — no matter what the other tags say. `no-remote-exec` + `no-sandbox` already
    # give us local, unsandboxed execution (the log reports remotable=false,
    # runner=local), so `local` would buy nothing and cost all caching. This is the bug
    # that made the original "Enable watch app cache" change inert.
    #
    # Caveat: if the build fleet runs different Xcode major versions, mismatched
    # artifacts could be served (the action key does not include the Xcode version);
    # align Xcode across builders, or add `no-remote-cache` to be safe.
    compile_exec_requirements = {
        "no-sandbox": "1",
        "no-remote-exec": "1",
        "requires-network": "1",
    }

    # The patch+sign action cannot share results across machines: its inputs include
    # the absolute `--watchProvisioningProfile` path (whose *contents* are not an action
    # input) and the codesigning identity is resolved from the local keychain, both
    # machine-specific. Sharing signed output would be wrong rather than merely useless,
    # so keep the umbrella `no-remote` plus `local` here.
    patch_exec_requirements = {
        "no-sandbox": "1",
        "no-remote": "1",
        "local": "1",
        "requires-network": "1",
    }

    # Action 1 — compile. Inputs are ONLY the in-repo snapshot (+ the worker); the
    # arguments carry just the api credentials and the bundle id. So this (expensive)
    # xcodebuild re-runs when the watch sources, api credentials or host bundle id
    # change — but not when the version, build number or signing identity change.
    ctx.actions.run(
        executable = "/bin/bash",
        arguments = [
            ctx.file._compile_worker.path,
            source_path,
            compiled_archive.path,
            api_id,
            api_hash,
            # Watch app bundle id ("<host>.watchkitapp"). xcodebuild bakes it as
            # PRODUCT_BUNDLE_IDENTIFIER so the signed CFBundleIdentifier matches the host
            # config; the Info.plist derives WKCompanionAppBundleIdentifier from it via
            # $(PRODUCT_BUNDLE_IDENTIFIER:base). Keeps the build dynamic across hosts with
            # no post-build bundle-id mutation (xcodebuild bakes, the patch worker signs).
            ctx.attr.bundle_id,
        ],
        inputs = [ctx.file._compile_worker] + ctx.files.srcs,
        outputs = [compiled_archive],
        mnemonic = "PrebuiltWatchosCompile",
        progress_message = "Compiling watch app via xcodebuild",
        execution_requirements = compile_exec_requirements,
        use_default_shell_env = True,
    )

    # Action 2 — patch the Info.plist version + optionally sign. Cheap; re-runs on a
    # version/build-number/identity change without re-running the compile above.
    # versions.json is an input here only, so a version bump skips the compile.
    ctx.actions.run(
        executable = "/bin/bash",
        arguments = [
            ctx.file._patch_worker.path,
            compiled_archive.path,
            archive.path,
            identity,
            profile,
            infoplist.path,
            ctx.file.versions_json.path,
            build_number,
        ],
        inputs = [ctx.file._patch_worker, compiled_archive, ctx.file.versions_json],
        outputs = [archive, infoplist],
        mnemonic = "PrebuiltWatchosPatchSign",
        progress_message = "Patching%s watch app Info.plist" % (" + signing" if profile else ""),
        execution_requirements = patch_exec_requirements,
        use_default_shell_env = True,
    )

    return [
        DefaultInfo(files = depset([archive])),
        new_applebundleinfo(
            archive = archive,
            bundle_id = ctx.attr.bundle_id,
            bundle_name = ctx.attr.bundle_name,
            bundle_extension = ".app",
            platform_type = "watchos",
            # Must be a single-target watchOS app (NOT watch2_application) so the host
            # skips the watchos_stub partial (see ios_rules.bzl product_type check).
            product_type = "com.apple.product-type.application",
            minimum_os_version = ctx.attr.minimum_os_version,
            minimum_deployment_os_version = ctx.attr.minimum_os_version,
            infoplist = infoplist,
            binary = None,
            entitlements = None,
            # Best-effort constant; the host ios_application reads only product_type.
            uses_swift = True,
            extension_safe = False,
        ),
        # Marker provider required by ios_application's watch_application attr
        # (providers = [[AppleBundleInfo, WatchosApplicationBundleInfo]]).
        new_watchosapplicationbundleinfo(),
        AppleEmbeddableInfo(
            # The signed (or unsigned) .app archive, expanded into the host's Watch/ section.
            watch_bundles = depset([archive]),
            # Empty: the worker signs everything inside the watch app itself.
            signed_frameworks = depset(),
        ),
    ]

apple_prebuilt_watchos_application = rule(
    implementation = _apple_prebuilt_watchos_application_impl,
    attrs = {
        "bundle_id": attr.string(default = "ph.telegra.Telegraph.watchkitapp"),
        "bundle_name": attr.string(default = "tgwatch Watch App"),
        "minimum_os_version": attr.string(default = "26.0"),
        "srcs": attr.label(
            default = "//Telegram/WatchApp:sources",
            allow_files = True,
            doc = "Committed in-repo watch source snapshot (tracked inputs).",
        ),
        "in_repo_source_dir": attr.string(
            default = "Telegram/WatchApp",
            doc = "Execroot-relative path to the committed snapshot (must match the package of 'srcs').",
        ),
        "versions_json": attr.label(
            allow_single_file = True,
            default = "//:versions.json",
            doc = "Source of the marketing version (key 'app'), kept in sync with the host app.",
        ),
        "_compile_worker": attr.label(
            default = "//Telegram:prebuilt_watchos_compile.sh",
            allow_single_file = True,
        ),
        "_patch_worker": attr.label(
            default = "//Telegram:prebuilt_watchos_patch.sh",
            allow_single_file = True,
        ),
    },
)
