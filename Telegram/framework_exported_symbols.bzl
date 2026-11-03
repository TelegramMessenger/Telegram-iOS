"""The exported-symbols list of a framework: exactly the symbols its clients use.

A framework that exports everything keeps every public symbol in its export trie and keeps the
code behind it alive, since exported symbols are dead-strip roots. TelegramUIFramework exported
161,496 symbols of which its clients imported 194; linking it with this list cut it by 13.6 MB.

There is no build cycle although the clients link against the framework: this rule reads the
clients' compiled archives, which need only the framework's module interfaces, not its binary.
The order is: clients compile -> this list -> framework link -> clients link.

A symbol missing from the list is an undefined-symbol error when the client links, never a
runtime failure. Nothing in the app resolves its own symbols by name at runtime (`dlsym`);
NSClassFromString and Swift type/conformance lookup use runtime metadata, not exports.
"""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _static_archives(targets):
    archives = {}
    for target in targets:
        if CcInfo not in target:
            continue
        for linker_input in target[CcInfo].linking_context.linker_inputs.to_list():
            for library in linker_input.libraries:
                archive = library.static_library or library.pic_static_library
                if archive:
                    archives[archive.path] = archive
    return archives

def _scan(ctx, kind, archives):
    # One action per archive: an edit rescans only the archives it changed (the full scan of
    # TelegramUI's 1.8 GB of debug archives takes ~8.5 s); the merge below is cheap.
    outputs = []
    for archive in sorted(archives, key = lambda archive: archive.path):
        output = ctx.actions.declare_file("%s.%s/%s.txt" % (ctx.label.name, kind, archive.path.replace("/", "_")))
        ctx.actions.run(
            executable = "/bin/bash",
            arguments = [ctx.file._worker.path, "scan", kind, archive.path, output.path],
            inputs = [ctx.file._worker, archive],
            outputs = [output],
            mnemonic = "FrameworkSymbolScan",
            progress_message = "Scanning %s symbols of %s" % (kind, archive.short_path),
            execution_requirements = {"requires-darwin": "1"},
            use_default_shell_env = True,
        )
        outputs.append(output)
    return outputs

def _framework_exported_symbols_impl(ctx):
    # rules_apple leaves the libraries of the frameworks this one links against out of its
    # link (`frameworks` on ios_framework); mirror that for both sides.
    provided = _static_archives(ctx.attr.provided_by_frameworks)
    framework = {path: archive for path, archive in _static_archives(ctx.attr.framework_deps).items() if path not in provided}
    clients = {path: archive for path, archive in _static_archives(ctx.attr.clients).items() if path not in provided and path not in framework}

    defined = _scan(ctx, "defined", framework.values())
    undefined = _scan(ctx, "undefined", clients.values())
    defined_lists = ctx.actions.declare_file(ctx.label.name + ".defined_lists")
    undefined_lists = ctx.actions.declare_file(ctx.label.name + ".undefined_lists")
    ctx.actions.write(defined_lists, "".join([f.path + "\n" for f in defined]))
    ctx.actions.write(undefined_lists, "".join([f.path + "\n" for f in undefined]))

    output = ctx.actions.declare_file(ctx.label.name + ".exported_symbols")
    ctx.actions.run(
        executable = "/bin/bash",
        arguments = [ctx.file._worker.path, "merge", output.path, defined_lists.path, undefined_lists.path],
        inputs = [ctx.file._worker, defined_lists, undefined_lists] + defined + undefined,
        outputs = [output],
        mnemonic = "FrameworkExportedSymbols",
        progress_message = "Computing the symbols %{label} must export",
        execution_requirements = {"requires-darwin": "1"},
        use_default_shell_env = True,
    )
    return [DefaultInfo(files = depset([output]))]

framework_exported_symbols = rule(
    implementation = _framework_exported_symbols_impl,
    doc = "Writes the exported-symbols list for an ios_framework: the symbols defined in its " +
          "own archives that its clients' archives reference. Pass it to the framework as " +
          "`-exported_symbols_list $(location ...)`.",
    attrs = {
        "framework_deps": attr.label_list(
            doc = "The framework's `deps`.",
            mandatory = True,
        ),
        "provided_by_frameworks": attr.label_list(
            doc = "The `deps` of every framework in the framework's `frameworks`: their libraries are not linked into it.",
        ),
        "clients": attr.label_list(
            doc = "The `deps` of every binary that links the framework (app binary, extensions).",
            mandatory = True,
        ),
        "_worker": attr.label(
            default = "//Telegram:framework_exported_symbols.sh",
            allow_single_file = True,
        ),
    },
)
