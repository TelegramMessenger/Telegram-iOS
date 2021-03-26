 
objc_library(
    name = "rnnoise",
    enable_modules = True,
    module_name = "rnnoise",
    srcs = glob([
        "Sources/*.c",
        "Sources/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
      "PublicHeaders",
    ],
    copts = [
        "-Dcelt_iir=rnnoise_celt_iir",
        "-D_celt_autocorr=rnnoise__celt_autocorr",
        "-D_celt_lpc=rnnoise__celt_lpc",
    ],
    visibility = [
        "//visibility:public",
    ],
)
