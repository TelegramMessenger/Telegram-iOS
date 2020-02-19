load("//build-system:defines.bzl",
    "string_value",
)

def _telegram_info_plist(ctx):
    output = ctx.outputs.out

    plist_string = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleShortVersionString</key>
        <string>{app_version}</string>
        <key>CFBundleVersion</key>
        <string>{build_number}</string>
        <key>CFBundleURLTypes</key>
        <array>
            <dict>
                <key>CFBundleTypeRole</key>
                <string>Viewer</string>
                <key>CFBundleURLName</key>
                <string>{bundle_id}</string>
                <key>CFBundleURLSchemes</key>
                <array>
                    <string>telegram</string>
                </array>
            </dict>
            <dict>
                <key>CFBundleTypeRole</key>
                <string>Viewer</string>
                <key>CFBundleURLName</key>
                <string>{bundle_id}.ton</string>
                <key>CFBundleURLSchemes</key>
                <array>
                    <string>ton</string>
                </array>
            </dict>
            <dict>
                <key>CFBundleTypeRole</key>
                <string>Viewer</string>
                <key>CFBundleURLName</key>
                <string>{app_name}.compatibility</string>
                <key>CFBundleURLSchemes</key>
                <array>
                    <string>tg</string>
                    <string>{url_scheme}</string>
                </array>
            </dict>
        </array>
    </dict>
    </plist>
    """.format(
        app_version = string_value(ctx, ctx.attr.app_version_define),
        build_number = string_value(ctx, ctx.attr.build_number_define),
        bundle_id = string_value(ctx, ctx.attr.bundle_id_define),
        app_name = ctx.attr.app_name,
        url_scheme = ctx.attr.url_scheme,
    )

    ctx.actions.write(
        output = output,
        content = plist_string,
    )

telegram_info_plist = rule(
    implementation = _telegram_info_plist,
    attrs = {
        "app_name": attr.string(mandatory = True),
        "url_scheme": attr.string(mandatory = True),
        "bundle_id_define": attr.string(mandatory = True),
        "app_version_define": attr.string(mandatory = True),
        "build_number_define": attr.string(mandatory = True),
    },
    outputs = {
        "out": "%{name}.plist"
    },
)
