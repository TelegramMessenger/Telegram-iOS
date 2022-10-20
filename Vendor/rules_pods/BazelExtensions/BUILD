# Process bundles created by PodSpecToBUILD
# Move a bundle of the convention in Pods
# PackageName_Bundle_BundleName
# @see process_ipa.py
py_binary(
    name = "ipa_process",
    main = "process_ipa.py",
    srcs = ["process_ipa.py"],
    visibility = ["//visibility:public"]
)

py_binary(
    name = "acknowledgement_merger",
    srcs = ["acknowledgement_merger.py"],
    visibility = ["//visibility:public"]
)

sh_library(
    name = "vendored_srcs",
    srcs = glob(["**"]),
    visibility = ["//visibility:public"]
)

py_binary(
    name = "headermap_builder",
    srcs = ["headermap_builder.py", "headermap_tool.py"],
    visibility = ["//visibility:public"]
)

