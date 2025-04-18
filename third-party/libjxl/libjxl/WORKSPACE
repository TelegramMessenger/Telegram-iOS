load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")

http_archive(
    name = "bazel_skylib",
    sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
    ],
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

local_repository(
    name = "highway",
    path = "third_party/highway",
)

local_repository(
    name = "brotli",
    path = "third_party/brotli",
)

new_local_repository(
    name = "googletest",
    build_file = "third_party/googletest/BUILD.bazel",
    path = "third_party/googletest",
)

new_local_repository(
    name = "skcms",
    build_file_content = """
cc_library(
    name = "skcms",
    srcs = [
        "skcms.cc",
        "skcms_internal.h",
        "src/Transform_inl.h",
    ],
    hdrs = ["skcms.h"],
    visibility = ["//visibility:public"],
)
    """,
    path = "third_party/skcms",
)

new_git_repository(
    name = "zlib",
    build_file_content = """
cc_library(
    name = "zlib",
    defines = ["HAVE_UNISTD_H"],
    srcs = [
        "adler32.c",
        "compress.c",
        "crc32.c",
        "crc32.h",
        "deflate.c",
        "deflate.h",
        "gzclose.c",
        "gzguts.h",
        "gzlib.c",
        "gzread.c",
        "gzwrite.c",
        "infback.c",
        "inffast.c",
        "inffast.h",
        "inffixed.h",
        "inflate.c",
        "inflate.h",
        "inftrees.c",
        "inftrees.h",
        "trees.c",
        "trees.h",
        "uncompr.c",
        "zconf.h",
        "zutil.c",
        "zutil.h",
    ],
    hdrs = ["zlib.h"],
    includes = ["."],
    visibility = ["//visibility:public"],
)
    """,
    remote = "https://github.com/madler/zlib",
    tag = "v1.2.13",
)

new_local_repository(
    name = "png",
    build_file_content = """
genrule(
    name = "pnglibconf",
    srcs = ["scripts/pnglibconf.h.prebuilt"],
    outs = ["pnglibconf.h"],
    cmd = "cp -f $< $@",
)
cc_library(
    name = "png",
    srcs = [
        "png.c",
        "pngconf.h",
        "pngdebug.h",
        "pngerror.c",
        "pngget.c",
        "pnginfo.h",
        ":pnglibconf",
        "pngmem.c",
        "pngpread.c",
        "pngpriv.h",
        "pngread.c",
        "pngrio.c",
        "pngrtran.c",
        "pngrutil.c",
        "pngset.c",
        "pngstruct.h",
        "pngtrans.c",
        "pngwio.c",
        "pngwrite.c",
        "pngwtran.c",
        "pngwutil.c",
    ],
    hdrs = ["png.h"],
    includes = ["."],
    linkopts = ["-lm"],
    visibility = ["//visibility:public"],
    deps = ["@zlib//:zlib"],
)
    """,
    path = "third_party/libpng",
)

new_git_repository(
    name = "libjpeg_turbo",
    build_file_content = """
load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
SUBSTITUTIONS = {
    "@BUILD@" : "20230208",
    "@CMAKE_PROJECT_NAME@" : "libjpeg-turbo",
    "@COPYRIGHT_YEAR@" : "2023",
    "@INLINE@" : "__inline__",
    "@JPEG_LIB_VERSION@" : "62",
    "@LIBJPEG_TURBO_VERSION_NUMBER@" : "2001091",
    "@SIZE_T@" : "8",
    "@THREAD_LOCAL@" : "__thread",
    "@VERSION@" : "2.1.91",
}
YES_DEFINES = [
    "C_ARITH_CODING_SUPPORTED", "D_ARITH_CODING_SUPPORTED",
    "HAVE_BUILTIN_CTZL", "MEM_SRCDST_SUPPORTED"
]
NO_DEFINES = [
    "WITH_SIMD", "RIGHT_SHIFT_IS_UNSIGNED", "HAVE_INTRIN_H"
]
SUBSTITUTIONS.update({
    "#cmakedefine " + key : "#define " + key for key in YES_DEFINES
})
SUBSTITUTIONS.update({
    "#cmakedefine " + key : "// #define " + key for key in NO_DEFINES
})
[
    expand_template(
        name = "expand_" + src,
        template = src + ".in",
        out = src,
        substitutions = SUBSTITUTIONS,
        visibility = ["//visibility:public"],
    ) for src in ["jconfig.h", "jconfigint.h", "jversion.h"]
]
JPEG16_SOURCES = [
    "jccolor.c",
    "jcdiffct.c",
    "jclossls.c",
    "jcmainct.c",
    "jcprepct.c",
    "jcsample.c",
    "jdcolor.c",
    "jddiffct.c",
    "jdlossls.c",
    "jdmainct.c",
    "jdmerge.c",
    "jdpostct.c",
    "jdsample.c",
    "jquant1.c",
    "jquant2.c",
    "jutils.c",
]
JPEG12_SOURCES = JPEG16_SOURCES + [
    "jccoefct.c",
    "jcdctmgr.c",
    "jdcoefct.c",
    "jddctmgr.c",
    "jfdctfst.c",
    "jfdctint.c",
    "jidctflt.c",
    "jidctfst.c",
    "jidctint.c",
    "jidctred.c",
]
JPEG_SOURCES = JPEG12_SOURCES + [
    "jaricom.c",
    "jcapimin.c",
    "jcapistd.c",
    "jcarith.c",
    "jchuff.c",
    "jcicc.c",
    "jcinit.c",
    "jclhuff.c",
    "jcmarker.c",
    "jcmaster.c",
    "jcomapi.c",
    "jcparam.c",
    "jcphuff.c",
    "jdapimin.c",
    "jdapistd.c",
    "jdarith.c",
    "jdatadst.c",
    "jdatasrc.c",
    "jdhuff.c",
    "jdicc.c",
    "jdinput.c",
    "jdlhuff.c",
    "jdmarker.c",
    "jdmaster.c",
    "jdphuff.c",
    "jdtrans.c",
    "jerror.c",
    "jfdctflt.c",
    "jmemmgr.c",
    "jmemnobs.c",
]
JPEG_HEADERS = [
    "jccolext.c",
    "jchuff.h",
    "jcmaster.h",
    "jconfig.h",
    "jconfigint.h",
    "jdcoefct.h",
    "jdcol565.c",
    "jdcolext.c",
    "jdct.h",
    "jdhuff.h",
    "jdmainct.h",
    "jdmaster.h",
    "jdmerge.h",
    "jdmrg565.c",
    "jdmrgext.c",
    "jdsample.h",
    "jerror.h",
    "jinclude.h",
    "jlossls.h",
    "jmemsys.h",
    "jmorecfg.h",
    "jpeg_nbits_table.h",
    "jpegapicomp.h",
    "jpegint.h",
    "jpeglib.h",
    "jsamplecomp.h",
    "jsimd.h",
    "jsimddct.h",
    "jstdhuff.c",
    "jversion.h",
]
cc_library(
    name = "jpeg16",
    srcs = JPEG16_SOURCES,
    hdrs = JPEG_HEADERS,
    local_defines = ["BITS_IN_JSAMPLE=16"],
    visibility = ["//visibility:public"],
)
cc_library(
    name = "jpeg12",
    srcs = JPEG12_SOURCES,
    hdrs = JPEG_HEADERS,
    local_defines = ["BITS_IN_JSAMPLE=12"],
    visibility = ["//visibility:public"],
)
cc_library(
    name = "jpeg",
    srcs = JPEG_SOURCES,
    hdrs = JPEG_HEADERS,
    deps = [":jpeg16", ":jpeg12"],
    includes = ["."],
    visibility = ["//visibility:public"],
)
exports_files([
    "jmorecfg.h",
    "jpeglib.h",
])
    """,
    remote = "https://github.com/libjpeg-turbo/libjpeg-turbo.git",
    tag = "2.1.91",
)

http_archive(
    name = "gif",
    build_file_content = """
cc_library(
    name = "gif",
    srcs = [
        "dgif_lib.c", "egif_lib.c", "gifalloc.c", "gif_err.c", "gif_font.c",
        "gif_hash.c", "openbsd-reallocarray.c", "gif_hash.h",
        "gif_lib_private.h"
    ],
    hdrs = ["gif_lib.h"],
    includes = ["."],
    visibility = ["//visibility:public"],
)
    """,
    sha256 = "31da5562f44c5f15d63340a09a4fd62b48c45620cd302f77a6d9acf0077879bd",
    strip_prefix = "giflib-5.2.1",
    url = "https://netcologne.dl.sourceforge.net/project/giflib/giflib-5.2.1.tar.gz",
)

new_git_repository(
    name = "imath",
    build_file_content = """
load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
SUBSTITUTIONS = {
    "@IMATH_INTERNAL_NAMESPACE@": "Imath_3_1",
    "@IMATH_LIB_VERSION@": "3.1.4",
    "@IMATH_NAMESPACE_CUSTOM@": "0",
    "@IMATH_NAMESPACE@": "Imath",
    "@IMATH_PACKAGE_NAME@": "Imath 3.1.4",
    "@IMATH_VERSION_MAJOR@": "3",
    "@IMATH_VERSION_MINOR@": "1",
    "@IMATH_VERSION_PATCH@": "4",
    "@IMATH_VERSION@": "3.1.4",
}
YES_DEFINES = [
    "IMATH_HALF_USE_LOOKUP_TABLE", "IMATH_ENABLE_API_VISIBILITY",
]
NO_DEFINES = [
    "IMATH_HAVE_LARGE_STACK",
]
ONE_DEFINES = [
    "IMATH_USE_NOEXCEPT",
]
SUBSTITUTIONS.update({
    "#cmakedefine " + key : "#define " + key for key in YES_DEFINES
})
SUBSTITUTIONS.update({
    "#cmakedefine " + key : "// #define " + key for key in NO_DEFINES
})
SUBSTITUTIONS.update({
    "#cmakedefine01 " + key : "#define " + key + " 1" for key in ONE_DEFINES
})
expand_template(
    name = "expand_ImathConfig",
    template = "config/ImathConfig.h.in",
    out = "src/Imath/ImathConfig.h",
    substitutions = SUBSTITUTIONS,
)
cc_library(
    name = "Imath",
    srcs = [
        "src/Imath/ImathColorAlgo.cpp",
        ":src/Imath/ImathConfig.h",
        "src/Imath/ImathFun.cpp",
        "src/Imath/ImathMatrixAlgo.cpp",
        "src/Imath/ImathRandom.cpp",
        "src/Imath/half.cpp",
        "src/Imath/toFloat.h",
    ],
    hdrs = [
        "src/Imath/ImathBox.h",
        "src/Imath/ImathBoxAlgo.h",
        "src/Imath/ImathColor.h",
        "src/Imath/ImathColorAlgo.h",
        "src/Imath/ImathEuler.h",
        "src/Imath/ImathExport.h",
        "src/Imath/ImathForward.h",
        "src/Imath/ImathFrame.h",
        "src/Imath/ImathFrustum.h",
        "src/Imath/ImathFrustumTest.h",
        "src/Imath/ImathFun.h",
        "src/Imath/ImathGL.h",
        "src/Imath/ImathGLU.h",
        "src/Imath/ImathInt64.h",
        "src/Imath/ImathInterval.h",
        "src/Imath/ImathLine.h",
        "src/Imath/ImathLineAlgo.h",
        "src/Imath/ImathMath.h",
        "src/Imath/ImathMatrix.h",
        "src/Imath/ImathMatrixAlgo.h",
        "src/Imath/ImathNamespace.h",
        "src/Imath/ImathPlane.h",
        "src/Imath/ImathPlatform.h",
        "src/Imath/ImathQuat.h",
        "src/Imath/ImathRandom.h",
        "src/Imath/ImathRoots.h",
        "src/Imath/ImathShear.h",
        "src/Imath/ImathSphere.h",
        "src/Imath/ImathTypeTraits.h",
        "src/Imath/ImathVec.h",
        "src/Imath/ImathVecAlgo.h",
        "src/Imath/half.h",
        "src/Imath/halfFunction.h",
        "src/Imath/halfLimits.h",
    ],
    includes = ["src/Imath"],
    visibility = ["//visibility:public"],
)
""",
    remote = "https://github.com/AcademySoftwareFoundation/imath",
    tag = "v3.1.5",
)

new_git_repository(
    name = "openexr",
    build_file_content = """
load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
SUBSTITUTIONS = {
    "@IEX_INTERNAL_NAMESPACE@": "Iex_3_0",
    "@IEX_NAMESPACE_CUSTOM@": "0",
    "@IEX_NAMESPACE@": "Iex",
    "@ILMTHREAD_INTERNAL_NAMESPACE@": "IlmThread_3_0",
    "@ILMTHREAD_NAMESPACE_CUSTOM@": "0",
    "@ILMTHREAD_NAMESPACE@": "IlmThread",
    "@OPENEXR_IMF_NAMESPACE@": "Imf",
    "@OPENEXR_INTERNAL_IMF_NAMESPACE@": "Imf_3_0",
    "@OPENEXR_LIB_VERSION@": "3.0.4",
    "@OPENEXR_NAMESPACE_CUSTOM@": "0",
    "@OPENEXR_PACKAGE_NAME@": "OpenEXR 3.0.4",
    "@OPENEXR_VERSION_EXTRA@": "",
    "@OPENEXR_VERSION_MAJOR@": "3",
    "@OPENEXR_VERSION_MINOR@": "0",
    "@OPENEXR_VERSION_PATCH@": "4",
    "@OPENEXR_VERSION@": "3.0.4",
}
YES_DEFINES = [
    "OPENEXR_ENABLE_API_VISIBILITY", "OPENEXR_IMF_HAVE_COMPLETE_IOMANIP",
    "OPENEXR_HAVE_LARGE_STACK",
]
NO_DEFINES = [
    "HAVE_UCONTEXT_H", "IEX_HAVE_CONTROL_REGISTER_SUPPORT",
    "IEX_HAVE_SIGCONTEXT_CONTROL_REGISTER_SUPPORT", "OPENEXR_IMF_HAVE_DARWIN",
    "OPENEXR_IMF_HAVE_GCC_INLINE_ASM_AVX", "OPENEXR_IMF_HAVE_LINUX_PROCFS",
    "OPENEXR_IMF_HAVE_SYSCONF_NPROCESSORS_ONLN",
]
ONE_DEFINES = [
    "ILMTHREAD_THREADING_ENABLED",
]
ZERO_DEFINES = [
    "ILMTHREAD_HAVE_POSIX_SEMAPHORES",
]
SUBSTITUTIONS.update({
    "#cmakedefine " + key : "#define " + key for key in YES_DEFINES
})
SUBSTITUTIONS.update({
    "#cmakedefine " + key : "// #define " + key for key in NO_DEFINES
})
SUBSTITUTIONS.update({
    "#cmakedefine01 " + key : "#define " + key + " 1" for key in ONE_DEFINES
})
SUBSTITUTIONS.update({
    "#cmakedefine01 " + key : "#define " + key + " 0" for key in ZERO_DEFINES
})
[
    expand_template(
        name = "expand_" + item,
        template = "cmake/" + item + ".h.in",
        out = "src/lib/Iex/" + item + ".h",
        substitutions = SUBSTITUTIONS,
    ) for item in ["IexConfig", "IexConfigInternal"]
]
[
expand_template(
        name = "expand_" + item,
        template = "cmake/" + item + ".h.in",
        out = "src/lib/IlmThread/" + item + ".h",
        substitutions = SUBSTITUTIONS,
    ) for item in ["IlmThreadConfig"]
]
[
expand_template(
        name = "expand_" + item,
        template = "cmake/" + item + ".h.in",
        out = "src/lib/OpenEXR/" + item + ".h",
        substitutions = SUBSTITUTIONS,
    ) for item in ["OpenEXRConfig", "OpenEXRConfigInternal"]
]
cc_library(
    name = "Iex",
    srcs = [
        "src/lib/Iex/IexBaseExc.cpp",
        "src/lib/Iex/IexMathFloatExc.cpp",
        "src/lib/Iex/IexMathFpu.cpp",
        "src/lib/Iex/IexThrowErrnoExc.cpp",
    ],
    hdrs = [
        "src/lib/Iex/Iex.h",
        "src/lib/Iex/IexBaseExc.h",
        ":src/lib/Iex/IexConfig.h",
        ":src/lib/Iex/IexConfigInternal.h",
        "src/lib/Iex/IexErrnoExc.h",
        "src/lib/Iex/IexExport.h",
        "src/lib/Iex/IexForward.h",
        "src/lib/Iex/IexMacros.h",
        "src/lib/Iex/IexMathExc.h",
        "src/lib/Iex/IexMathFloatExc.h",
        "src/lib/Iex/IexMathFpu.h",
        "src/lib/Iex/IexMathIeeeExc.h",
        "src/lib/Iex/IexNamespace.h",
        "src/lib/Iex/IexThrowErrnoExc.h",
        ":src/lib/OpenEXR/OpenEXRConfig.h",
    ],
    includes = [
        "src/lib/Iex",
        "src/lib/OpenEXR",
    ],
)

cc_library(
    name = "IlmThread",
    srcs = [
        "src/lib/IlmThread/IlmThread.cpp",
        "src/lib/IlmThread/IlmThreadPool.cpp",
        "src/lib/IlmThread/IlmThreadSemaphore.cpp",
        "src/lib/IlmThread/IlmThreadSemaphoreOSX.cpp",
        "src/lib/IlmThread/IlmThreadSemaphorePosix.cpp",
        "src/lib/IlmThread/IlmThreadSemaphorePosixCompat.cpp",
        "src/lib/IlmThread/IlmThreadSemaphoreWin32.cpp",
    ],
    hdrs = [
        "src/lib/IlmThread/IlmThread.h",
        ":src/lib/IlmThread/IlmThreadConfig.h",
        "src/lib/IlmThread/IlmThreadExport.h",
        "src/lib/IlmThread/IlmThreadForward.h",
        "src/lib/IlmThread/IlmThreadMutex.h",
        "src/lib/IlmThread/IlmThreadNamespace.h",
        "src/lib/IlmThread/IlmThreadPool.h",
        "src/lib/IlmThread/IlmThreadSemaphore.h",
    ],
    includes = ["src/lib/IlmThread"],
    deps = [":Iex"],
)
cc_library(
    name = "OpenEXR",
    srcs = [
        "src/lib/OpenEXR/ImfAcesFile.cpp",
        "src/lib/OpenEXR/ImfAttribute.cpp",
        "src/lib/OpenEXR/ImfB44Compressor.cpp",
        "src/lib/OpenEXR/ImfBoxAttribute.cpp",
        "src/lib/OpenEXR/ImfCRgbaFile.cpp",
        "src/lib/OpenEXR/ImfChannelList.cpp",
        "src/lib/OpenEXR/ImfChannelListAttribute.cpp",
        "src/lib/OpenEXR/ImfChromaticities.cpp",
        "src/lib/OpenEXR/ImfChromaticitiesAttribute.cpp",
        "src/lib/OpenEXR/ImfCompositeDeepScanLine.cpp",
        "src/lib/OpenEXR/ImfCompressionAttribute.cpp",
        "src/lib/OpenEXR/ImfCompressor.cpp",
        "src/lib/OpenEXR/ImfConvert.cpp",
        "src/lib/OpenEXR/ImfDeepCompositing.cpp",
        "src/lib/OpenEXR/ImfDeepFrameBuffer.cpp",
        "src/lib/OpenEXR/ImfDeepImageStateAttribute.cpp",
        "src/lib/OpenEXR/ImfDeepScanLineInputFile.cpp",
        "src/lib/OpenEXR/ImfDeepScanLineInputPart.cpp",
        "src/lib/OpenEXR/ImfDeepScanLineOutputFile.cpp",
        "src/lib/OpenEXR/ImfDeepScanLineOutputPart.cpp",
        "src/lib/OpenEXR/ImfDeepTiledInputFile.cpp",
        "src/lib/OpenEXR/ImfDeepTiledInputPart.cpp",
        "src/lib/OpenEXR/ImfDeepTiledOutputFile.cpp",
        "src/lib/OpenEXR/ImfDeepTiledOutputPart.cpp",
        "src/lib/OpenEXR/ImfDoubleAttribute.cpp",
        "src/lib/OpenEXR/ImfDwaCompressor.cpp",
        "src/lib/OpenEXR/ImfEnvmap.cpp",
        "src/lib/OpenEXR/ImfEnvmapAttribute.cpp",
        "src/lib/OpenEXR/ImfFastHuf.cpp",
        "src/lib/OpenEXR/ImfFloatAttribute.cpp",
        "src/lib/OpenEXR/ImfFloatVectorAttribute.cpp",
        "src/lib/OpenEXR/ImfFrameBuffer.cpp",
        "src/lib/OpenEXR/ImfFramesPerSecond.cpp",
        "src/lib/OpenEXR/ImfGenericInputFile.cpp",
        "src/lib/OpenEXR/ImfGenericOutputFile.cpp",
        "src/lib/OpenEXR/ImfHeader.cpp",
        "src/lib/OpenEXR/ImfHuf.cpp",
        "src/lib/OpenEXR/ImfIDManifest.cpp",
        "src/lib/OpenEXR/ImfIDManifestAttribute.cpp",
        "src/lib/OpenEXR/ImfIO.cpp",
        "src/lib/OpenEXR/ImfInputFile.cpp",
        "src/lib/OpenEXR/ImfInputPart.cpp",
        "src/lib/OpenEXR/ImfInputPartData.cpp",
        "src/lib/OpenEXR/ImfIntAttribute.cpp",
        "src/lib/OpenEXR/ImfKeyCode.cpp",
        "src/lib/OpenEXR/ImfKeyCodeAttribute.cpp",
        "src/lib/OpenEXR/ImfLineOrderAttribute.cpp",
        "src/lib/OpenEXR/ImfLut.cpp",
        "src/lib/OpenEXR/ImfMatrixAttribute.cpp",
        "src/lib/OpenEXR/ImfMisc.cpp",
        "src/lib/OpenEXR/ImfMultiPartInputFile.cpp",
        "src/lib/OpenEXR/ImfMultiPartOutputFile.cpp",
        "src/lib/OpenEXR/ImfMultiView.cpp",
        "src/lib/OpenEXR/ImfOpaqueAttribute.cpp",
        "src/lib/OpenEXR/ImfOutputFile.cpp",
        "src/lib/OpenEXR/ImfOutputPart.cpp",
        "src/lib/OpenEXR/ImfOutputPartData.cpp",
        "src/lib/OpenEXR/ImfPartType.cpp",
        "src/lib/OpenEXR/ImfPizCompressor.cpp",
        "src/lib/OpenEXR/ImfPreviewImage.cpp",
        "src/lib/OpenEXR/ImfPreviewImageAttribute.cpp",
        "src/lib/OpenEXR/ImfPxr24Compressor.cpp",
        "src/lib/OpenEXR/ImfRational.cpp",
        "src/lib/OpenEXR/ImfRationalAttribute.cpp",
        "src/lib/OpenEXR/ImfRgbaFile.cpp",
        "src/lib/OpenEXR/ImfRgbaYca.cpp",
        "src/lib/OpenEXR/ImfRle.cpp",
        "src/lib/OpenEXR/ImfRleCompressor.cpp",
        "src/lib/OpenEXR/ImfScanLineInputFile.cpp",
        "src/lib/OpenEXR/ImfStandardAttributes.cpp",
        "src/lib/OpenEXR/ImfStdIO.cpp",
        "src/lib/OpenEXR/ImfStringAttribute.cpp",
        "src/lib/OpenEXR/ImfStringVectorAttribute.cpp",
        "src/lib/OpenEXR/ImfSystemSpecific.cpp",
        "src/lib/OpenEXR/ImfTestFile.cpp",
        "src/lib/OpenEXR/ImfThreading.cpp",
        "src/lib/OpenEXR/ImfTileDescriptionAttribute.cpp",
        "src/lib/OpenEXR/ImfTileOffsets.cpp",
        "src/lib/OpenEXR/ImfTiledInputFile.cpp",
        "src/lib/OpenEXR/ImfTiledInputPart.cpp",
        "src/lib/OpenEXR/ImfTiledMisc.cpp",
        "src/lib/OpenEXR/ImfTiledOutputFile.cpp",
        "src/lib/OpenEXR/ImfTiledOutputPart.cpp",
        "src/lib/OpenEXR/ImfTiledRgbaFile.cpp",
        "src/lib/OpenEXR/ImfTimeCode.cpp",
        "src/lib/OpenEXR/ImfTimeCodeAttribute.cpp",
        "src/lib/OpenEXR/ImfVecAttribute.cpp",
        "src/lib/OpenEXR/ImfVersion.cpp",
        "src/lib/OpenEXR/ImfWav.cpp",
        "src/lib/OpenEXR/ImfZip.cpp",
        "src/lib/OpenEXR/ImfZipCompressor.cpp",
        "src/lib/OpenEXR/b44ExpLogTable.h",
        "src/lib/OpenEXR/dwaLookups.h",
    ],
    hdrs = [
        ":src/lib/Iex/IexConfig.h",
        ":src/lib/Iex/IexConfigInternal.h",
        ":src/lib/IlmThread/IlmThreadConfig.h",
        "src/lib/OpenEXR/ImfAcesFile.h",
        "src/lib/OpenEXR/ImfArray.h",
        "src/lib/OpenEXR/ImfAttribute.h",
        "src/lib/OpenEXR/ImfAutoArray.h",
        "src/lib/OpenEXR/ImfB44Compressor.h",
        "src/lib/OpenEXR/ImfBoxAttribute.h",
        "src/lib/OpenEXR/ImfCRgbaFile.h",
        "src/lib/OpenEXR/ImfChannelList.h",
        "src/lib/OpenEXR/ImfChannelListAttribute.h",
        "src/lib/OpenEXR/ImfCheckedArithmetic.h",
        "src/lib/OpenEXR/ImfChromaticities.h",
        "src/lib/OpenEXR/ImfChromaticitiesAttribute.h",
        "src/lib/OpenEXR/ImfCompositeDeepScanLine.h",
        "src/lib/OpenEXR/ImfCompression.h",
        "src/lib/OpenEXR/ImfCompressionAttribute.h",
        "src/lib/OpenEXR/ImfCompressor.h",
        "src/lib/OpenEXR/ImfConvert.h",
        "src/lib/OpenEXR/ImfDeepCompositing.h",
        "src/lib/OpenEXR/ImfDeepFrameBuffer.h",
        "src/lib/OpenEXR/ImfDeepImageState.h",
        "src/lib/OpenEXR/ImfDeepImageStateAttribute.h",
        "src/lib/OpenEXR/ImfDeepScanLineInputFile.h",
        "src/lib/OpenEXR/ImfDeepScanLineInputPart.h",
        "src/lib/OpenEXR/ImfDeepScanLineOutputFile.h",
        "src/lib/OpenEXR/ImfDeepScanLineOutputPart.h",
        "src/lib/OpenEXR/ImfDeepTiledInputFile.h",
        "src/lib/OpenEXR/ImfDeepTiledInputPart.h",
        "src/lib/OpenEXR/ImfDeepTiledOutputFile.h",
        "src/lib/OpenEXR/ImfDeepTiledOutputPart.h",
        "src/lib/OpenEXR/ImfDoubleAttribute.h",
        "src/lib/OpenEXR/ImfDwaCompressor.h",
        "src/lib/OpenEXR/ImfDwaCompressorSimd.h",
        "src/lib/OpenEXR/ImfEnvmap.h",
        "src/lib/OpenEXR/ImfEnvmapAttribute.h",
        "src/lib/OpenEXR/ImfExport.h",
        "src/lib/OpenEXR/ImfFastHuf.h",
        "src/lib/OpenEXR/ImfFloatAttribute.h",
        "src/lib/OpenEXR/ImfFloatVectorAttribute.h",
        "src/lib/OpenEXR/ImfForward.h",
        "src/lib/OpenEXR/ImfFrameBuffer.h",
        "src/lib/OpenEXR/ImfFramesPerSecond.h",
        "src/lib/OpenEXR/ImfGenericInputFile.h",
        "src/lib/OpenEXR/ImfGenericOutputFile.h",
        "src/lib/OpenEXR/ImfHeader.h",
        "src/lib/OpenEXR/ImfHuf.h",
        "src/lib/OpenEXR/ImfIDManifest.h",
        "src/lib/OpenEXR/ImfIDManifestAttribute.h",
        "src/lib/OpenEXR/ImfIO.h",
        "src/lib/OpenEXR/ImfInputFile.h",
        "src/lib/OpenEXR/ImfInputPart.h",
        "src/lib/OpenEXR/ImfInputPartData.h",
        "src/lib/OpenEXR/ImfInputStreamMutex.h",
        "src/lib/OpenEXR/ImfInt64.h",
        "src/lib/OpenEXR/ImfIntAttribute.h",
        "src/lib/OpenEXR/ImfKeyCode.h",
        "src/lib/OpenEXR/ImfKeyCodeAttribute.h",
        "src/lib/OpenEXR/ImfLineOrder.h",
        "src/lib/OpenEXR/ImfLineOrderAttribute.h",
        "src/lib/OpenEXR/ImfLut.h",
        "src/lib/OpenEXR/ImfMatrixAttribute.h",
        "src/lib/OpenEXR/ImfMisc.h",
        "src/lib/OpenEXR/ImfMultiPartInputFile.h",
        "src/lib/OpenEXR/ImfMultiPartOutputFile.h",
        "src/lib/OpenEXR/ImfMultiView.h",
        "src/lib/OpenEXR/ImfName.h",
        "src/lib/OpenEXR/ImfNamespace.h",
        "src/lib/OpenEXR/ImfOpaqueAttribute.h",
        "src/lib/OpenEXR/ImfOptimizedPixelReading.h",
        "src/lib/OpenEXR/ImfOutputFile.h",
        "src/lib/OpenEXR/ImfOutputPart.h",
        "src/lib/OpenEXR/ImfOutputPartData.h",
        "src/lib/OpenEXR/ImfOutputStreamMutex.h",
        "src/lib/OpenEXR/ImfPartHelper.h",
        "src/lib/OpenEXR/ImfPartType.h",
        "src/lib/OpenEXR/ImfPixelType.h",
        "src/lib/OpenEXR/ImfPizCompressor.h",
        "src/lib/OpenEXR/ImfPreviewImage.h",
        "src/lib/OpenEXR/ImfPreviewImageAttribute.h",
        "src/lib/OpenEXR/ImfPxr24Compressor.h",
        "src/lib/OpenEXR/ImfRational.h",
        "src/lib/OpenEXR/ImfRationalAttribute.h",
        "src/lib/OpenEXR/ImfRgba.h",
        "src/lib/OpenEXR/ImfRgbaFile.h",
        "src/lib/OpenEXR/ImfRgbaYca.h",
        "src/lib/OpenEXR/ImfRle.h",
        "src/lib/OpenEXR/ImfRleCompressor.h",
        "src/lib/OpenEXR/ImfScanLineInputFile.h",
        "src/lib/OpenEXR/ImfSimd.h",
        "src/lib/OpenEXR/ImfStandardAttributes.h",
        "src/lib/OpenEXR/ImfStdIO.h",
        "src/lib/OpenEXR/ImfStringAttribute.h",
        "src/lib/OpenEXR/ImfStringVectorAttribute.h",
        "src/lib/OpenEXR/ImfSystemSpecific.h",
        "src/lib/OpenEXR/ImfTestFile.h",
        "src/lib/OpenEXR/ImfThreading.h",
        "src/lib/OpenEXR/ImfTileDescription.h",
        "src/lib/OpenEXR/ImfTileDescriptionAttribute.h",
        "src/lib/OpenEXR/ImfTileOffsets.h",
        "src/lib/OpenEXR/ImfTiledInputFile.h",
        "src/lib/OpenEXR/ImfTiledInputPart.h",
        "src/lib/OpenEXR/ImfTiledMisc.h",
        "src/lib/OpenEXR/ImfTiledOutputFile.h",
        "src/lib/OpenEXR/ImfTiledOutputPart.h",
        "src/lib/OpenEXR/ImfTiledRgbaFile.h",
        "src/lib/OpenEXR/ImfTimeCode.h",
        "src/lib/OpenEXR/ImfTimeCodeAttribute.h",
        "src/lib/OpenEXR/ImfVecAttribute.h",
        "src/lib/OpenEXR/ImfVersion.h",
        "src/lib/OpenEXR/ImfWav.h",
        "src/lib/OpenEXR/ImfXdr.h",
        "src/lib/OpenEXR/ImfZip.h",
        "src/lib/OpenEXR/ImfZipCompressor.h",
        ":src/lib/OpenEXR/OpenEXRConfig.h",
        ":src/lib/OpenEXR/OpenEXRConfigInternal.h",
    ],
    includes = ["src/lib/OpenEXR"],
    deps = [
        ":IlmThread",
        "@imath//:Imath",
        "@zlib//:zlib",
    ],
    visibility = ["//visibility:public"],
)
""",
    remote = "https://github.com/AcademySoftwareFoundation/openexr",
    tag = "v3.1.5",
)
