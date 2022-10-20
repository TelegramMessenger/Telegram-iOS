# This file is part of PodSpecToBUILD
# Warning: this file is not accounted for as an explicit input into the build.
# Therefore, bin/RepoTools must be updated when this changes.

# Acknowledgements

AcknowledgementProvider = provider()

def _acknowledgement_merger_impl(ctx):
    concat = ctx.attr.value.files.to_list() if ctx.attr.value else []
    action = "--merge" if ctx.attr.value else "--finalize"
    args = [action, ctx.outputs.out.path]

    # Merge all of the dep licenses
    for dep in ctx.attr.deps:
        license = dep.files.to_list()
        concat.extend(license)

    for f in concat:
        args.append(f.path)

    # Write the final output. Bazel only writes the file when required
    ctx.actions.run(
        inputs=concat,
        arguments=args,
        executable=ctx.attr.merger.files.to_list()[0],
        outputs=[ctx.outputs.out]
    )

    return [AcknowledgementProvider(value=concat)]


acknowledgement_merger = rule(
    implementation=_acknowledgement_merger_impl,
    attrs={
        # We expect the deps to be AcknowledgementProviders
        # It isn't possible to enforce this across external package boundaries,
        "deps": attr.label_list(allow_files=True),
        "value": attr.label(),
        "output_name": attr.string(),
        "merger": attr.label(
            executable=True,
            cfg="host"
        )
    },
    outputs={"out": "%{output_name}.plist"}
)

# acknowledgments plist generates Acknowledgements.plist for use in a
# Settings.bundle


def acknowledgments_plist(name,
                          deps,
                          output_name="Acknowledgements",
                          merger="//Vendor/rules_pods/BazelExtensions:acknowledgement_merger",
                          ):
    acknowledgement_merger(
        name=name,
        deps=deps,
        value=None,
        output_name=output_name,
        merger=merger,
        visibility=["//visibility:public"]
    )

# acknowledged target takes a value in the form of a license file
#
# It may depend on other acknowledged targets


def acknowledged_target(name,
                        deps,
                        value,
                        merger="//Vendor/rules_pods/BazelExtensions:acknowledgement_merger",
                        ):
    acknowledgement_merger(
        name=name,
        deps=deps,
        output_name=name + "-acknowledgement",
        value=value,
        merger=merger,
        visibility=["//visibility:public"]
    )



def _umbrella_header_impl(ctx):
    headers_list = _get_module_map_headers(ctx.attr.hdrs)
    output = ctx.outputs.umbrella_header
    content = """
#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

{hdrs}

FOUNDATION_EXPORT double ParentVersionNumber;
FOUNDATION_EXPORT const unsigned char ParentVersionString[];
""".format(hdrs="\n".join(["#import \"" + h.path + "\"" for h in headers_list]))
    ctx.actions.write(
      content=content,
      output=output
    )
    objc_provider = apple_common.new_objc_provider(
        header=depset([output]),
    )

    return struct(
        files=depset([output]),
        providers=[objc_provider],
        objc=objc_provider,
        headers=depset([output]),
    )

umbrella_header = rule(
    implementation=_umbrella_header_impl,
    output_to_genfiles=True,
    attrs={
        "hdrs": attr.label_list(mandatory=True),
    },
    outputs={"umbrella_header": "%{name}.h"}
 )


def _get_module_map_headers(deps):
    headers_list = []
    for provider in deps:
        for input_file in provider.files.to_list():
            if input_file.path.endswith(".hmap"):
                continue
            if input_file.path.endswith(".hpp"):
                continue
            if input_file.path.endswith(".modulemap"):
                continue
            headers_list.append(input_file)
    return headers_list

def _module_map_impl(ctx):
    module_name = ctx.attr.module_name
    deps = ctx.attr.hdrs
    swift_hdr = ctx.attr.swift_hdr
    headers_list = _get_module_map_headers(deps)

    # relative from the module_map dir to the compilation root
    # e.g. bazel-out/ios_x86_64-fastbuild/genfiles/external/__Pod__
    module_map = ctx.outputs.module_map
    headers = depset(headers_list).to_list()
    relative_path = "".join(["../" for i in range(len(module_map.dirname.split("/")))])

    system_tag = " [system] "
    content = "module " + module_name + (system_tag if ctx.attr.is_system else "" ) + " {\n"
    umbrella_header_file = None
    if ctx.attr.umbrella_hdr:
        # Note: this umbrella header is created internally.
        umbrella_header_file = ctx.attr.umbrella_hdr[DefaultInfo].files.to_list()[0]
        content += "    umbrella header \"../%s\"\n" % (umbrella_header_file.basename)
        content += "    export * \n"
        content += "    module * { export * } \n"
    else:
        content += "    export * \n"
        for hdr in headers:
            content += "    header \"%s%s\"\n" % (relative_path, hdr.path)

    content += "}\n"

    if swift_hdr:
        content += """
module {module_name}.Swift {{
    header "{swift_umbrella_header}"
    requires objc
}}""".format(
            module_name = module_name,
            swift_umbrella_header = swift_hdr,
            )

    ctx.actions.write(
        content=content,
        output=module_map
    )

    # If the name is `module.modulemap` we propagate this as an include. If a
    # module map is added to `objc_library` as a dep, bazel will add these
    # automatically and add a _single_ include to this module map. Ideally there
    # would be an API to invoke clang with -fmodule-map=
    providers = []
    if ctx.attr.module_map_name == "module.modulemap":
        provider_hdr = [module_map] + ([umbrella_header_file] if umbrella_header_file else [])
        objc_provider = apple_common.new_objc_provider(
            module_map=depset([module_map]),
            header=depset(provider_hdr)
        )

        compilation_context = cc_common.create_compilation_context(
            headers=depset(provider_hdr),
            includes=depset([ctx.outputs.module_map.dirname]),
        )

        providers.append(CcInfo(compilation_context=compilation_context))
    else:
        # This is an explicit module map. Currently, we use these for swift only
        provider_hdr = [module_map] + ([umbrella_header_file] if umbrella_header_file else [])
        objc_provider = apple_common.new_objc_provider(
            header=depset(provider_hdr + [module_map])
        )

    providers.append(objc_provider)

    return struct(
        files=depset([module_map]),
        providers=providers,
        objc=objc_provider,
        headers=depset([module_map]),
    )


_gen_module_map = rule(
    implementation=_module_map_impl,
    output_to_genfiles=True,
    attrs = {
        "hdrs": attr.label_list(mandatory=True),
        "module_name": attr.string(mandatory=True),
        "module_map_name": attr.string(mandatory=True),
        "is_system": attr.bool(mandatory=True),
        "swift_hdr": attr.string(mandatory=False),
        "umbrella_hdr": attr.label(mandatory=False),
    },
    outputs = { "module_map": "%{name}/%{module_map_name}" }
)

def gen_module_map(name,
                   module_name,
                   hdrs=[],
                   module_map_name="module.modulemap",
                   tags=["xchammer"],
                   is_system=True,
                   swift_hdr=None,
                   umbrella_hdr=None,
                   visibility=["//visibility:public"]
                   ):
    """
    Generate a mnadule map based on a list of header file groups
    module_name: the name of the module
    is_system: if the module is system module or not. This is useful for
               PodToBUILD to ignore all pod warnings by default
    """
    _gen_module_map(name = name,
                    module_name=module_name,
                    hdrs=hdrs,
                    module_map_name=module_map_name,
                    is_system=is_system,
                    swift_hdr=swift_hdr,
                    umbrella_hdr=umbrella_hdr,
                    visibility=visibility,
                    tags=tags)


def _gen_includes_impl(ctx):
    includes = []
    includes.extend(ctx.attr.include)

    for target in ctx.attr.include_files:
        for f in target.files.to_list():
            includes.append(f.path)

    compilation_context = cc_common.create_compilation_context(
            includes=depset(includes))

    return [
        CcInfo(compilation_context=compilation_context),
        # objc_library deps requires an ObjcProvider
        apple_common.new_objc_provider()
    ]

_gen_includes = rule(
    implementation=_gen_includes_impl,
    attrs = {
        "include": attr.string_list(mandatory=True),
        "include_files": attr.label_list(mandatory=True),
    }
)

def gen_includes(name,
                 include=[],
                 include_files=[],
                 tags=["xchammer"],
                 visibility=["//visibility:public"]):
    _gen_includes(name=name,
                  include=include,
                  include_files=include_files,
                  tags=tags,
                  visibility=visibility)


def _make_headermap_json(namespace, hdrs):
    mappings = {}
    for provider in hdrs:
        for input_file in provider.files.to_list():
            hdr = input_file
            namespaced_key = namespace + "/" + hdr.basename
            mappings[namespaced_key] = hdr.path
            mappings[hdr.basename] = hdr.path
    return struct(mappings=mappings).to_json()


def _make_headermap_impl(ctx):
    # Write a JSON file for *this* headermap
    json_f = ctx.actions.declare_file(ctx.label.name + "_internal.json")
    out = _make_headermap_json(ctx.attr.namespace, ctx.attr.hdrs)
    ctx.actions.write(
        content=out,
        output=json_f
    )

    # Add a list of headermaps in JSON or hmap format
    args = [ctx.outputs.headermap.path, json_f.path]
    inputs = [json_f]

    # Extract propagated headermaps
    for hdr_provider in ctx.attr.deps:
        hdrs = []

        if CcInfo in hdr_provider:
            compilation_context = hdr_provider[CcInfo].compilation_context
            hdrs.extend(compilation_context.headers.to_list())

        if hasattr(hdr_provider, "objc"):
            hdrs.extend(hdr_provider.objc.direct_headers)

        for hdr in hdrs:
            if hdr.path.endswith(".hmap"):
                # Add headermaps
                inputs.append(hdr)
                args.append(hdr.path)

    ctx.actions.run(
        inputs=inputs,
        arguments=args,
        executable=ctx.attr.headermap_builder.files.to_list()[0],
        outputs=[ctx.outputs.headermap]
    )

    compilation_context = cc_common.create_compilation_context(
        headers=depset([ctx.outputs.headermap]))
    objc_provider = apple_common.new_objc_provider(
        header=depset([ctx.outputs.headermap]),
    )

    return struct(
        files=depset([ctx.outputs.headermap]),
        providers=[
            CcInfo(compilation_context=compilation_context),
            objc_provider,
        ],
        objc=objc_provider,
        headers=depset([ctx.outputs.headermap]),
    )

def headermap(
    tags=["xchammer"],**kwargs):
    _headermap(tags=tags, **kwargs)

# Derive a headermap from transitive headermaps
# hdrs: a file group containing headers for this rule
# namespace: the Apple style namespace these header should be under
# deps: rules providing headers. i.e. an `objc_library`
# Note: this intententionally does not propgate the include. We don't want to
# end up with O(N) includes.
# The pattern in PodToBUILD is:
# - Add all deps to a headermap
# - Include the headermap
# TODO(Add the ability to disallow propagation of "internal" includes )
# e.g. "MyLib.h" instead of <MyLib/MyLib.h>
_headermap = rule(
    implementation=_make_headermap_impl,
    output_to_genfiles=True,
    attrs={
        "namespace": attr.string(mandatory=True),
        "hdrs": attr.label_list(mandatory=True),
        "deps": attr.label_list(mandatory=False),
        "headermap_builder": attr.label(
            executable=True,
            cfg="host",
            default=Label(
                "//Vendor/rules_pods/BazelExtensions:headermap_builder"),
        )
    },
    outputs={"headermap": "%{name}.hmap"}
)

