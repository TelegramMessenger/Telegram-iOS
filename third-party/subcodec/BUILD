cc_library(
    name = "h264bitstream",
    srcs = [
        "third_party/h264bitstream/h264_stream.c",
        "third_party/h264bitstream/h264_nal.c",
        "third_party/h264bitstream/h264_sei.c",
    ],
    hdrs = glob(["third_party/h264bitstream/*.h"]),
    includes = ["third_party/h264bitstream"],
    copts = ["-Wno-all"],
)

cc_library(
    name = "subcodec",
    srcs = [
        "src/frame_writer.cpp",
        "src/cavlc.cpp",
        "src/h264_parser.cpp",
        "src/sprite_data.cpp",
        "src/mbs_encode.cpp",
        "src/mbs_mux_common.cpp",
        "src/mux_surface.cpp",
    ],
    hdrs = glob(["src/*.h"]),
    includes = ["src"],
    copts = [
        "-std=c++2b",
        "-Wno-all",
    ],
    deps = [":h264bitstream"],
)

cc_library(
    name = "sprite_encode",
    srcs = [
        "src/sprite_encode.cpp",
        "src/sprite_extractor.cpp",
    ],
    hdrs = glob(["src/*.h"]),
    includes = ["src"],
    copts = [
        "-std=c++2b",
        "-Wno-all",
        "-Ithird-party/openh264/third_party/openh264/src/codec/api/wels",
    ],
    deps = [
        ":subcodec",
        "//third-party/openh264:openh264",
    ],
)

objc_library(
    name = "SubcodecObjC",
    module_name = "SubcodecObjC",
    enable_modules = True,
    srcs = [
        "Sources/SubcodecObjC/SCSprite.mm",
        "Sources/SubcodecObjC/SCMuxSurface.mm",
        "Sources/SubcodecObjC/SCSpriteRegion.mm",
        "Sources/SubcodecObjC/SCDecodedFrame.mm",
        "Sources/SubcodecObjC/SCOpenH264Decoder.mm",
        "Sources/SubcodecObjC/SCVideoToolboxDecoder.mm",
        "Sources/SubcodecObjC/AnnexBSplitter.h",
    ],
    hdrs = glob(["Sources/SubcodecObjC/include/*.h"]),
    includes = ["Sources/SubcodecObjC/include"],
    copts = [
        "-std=c++2b",
        "-Wno-all",
        "-Ithird-party/openh264/third_party/openh264/src/codec/api/wels",
    ],
    deps = [
        ":subcodec",
        ":sprite_encode",
        "//third-party/openh264:openh264",
        "//third-party/openh264:openh264_decoder",
    ],
    sdk_frameworks = [
        "VideoToolbox",
        "CoreMedia",
        "CoreVideo",
    ],
    visibility = ["//visibility:public"],
)
