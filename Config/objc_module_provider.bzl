
def _impl(ctx):
    output_dir = ctx.attr.name + "_ModuleHeaders"
    dir = ctx.actions.declare_directory(output_dir)
    files = []
    files_command = ""
    for file in ctx.files.headers:
        outFile = ctx.actions.declare_file(output_dir + "/" + ctx.attr.module_name + "/" + file.basename)
        files.append(outFile)
        files_command = files_command + " && cp " + file.path + " " + outFile.path
    ctx.actions.run_shell(
        outputs = [dir] + files,
        inputs = ctx.files.headers,
        command = "mkdir -p " + dir.path + " " + files_command
    )
    return [
        apple_common.new_objc_provider(
            include_system = depset([dir.path]),
            header = depset(files),
        ),
    ]

objc_module = rule(
    implementation = _impl,
    attrs = {
        "module_name": attr.string(mandatory = True),
        "headers": attr.label_list(
            allow_files = [".h"],
        ),
    },
)
