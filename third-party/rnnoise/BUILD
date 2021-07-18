
replace_symbol_list = [
    "_celt_autocorr",
    "celt_fir",
    "celt_iir",
    "_celt_lpc",
    "celt_pitch_xcorr",
    "compute_band_corr",
    "compute_band_energy",
    "compute_dense",
    "compute_gru",
    "compute_rnn",
    "interp_band_gain",
    "opus_fft_alloc",
    "opus_fft_alloc_arch_c",
    "opus_fft_alloc_twiddles",
    "opus_fft_c",
    "opus_fft_free",
    "opus_fft_free_arch_c",
    "opus_fft_impl",
    "opus_ifft_c",
    "pitch_downsample",
    "pitch_filter",
    "pitch_search",
    "remove_doubling",
]
 
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
        "-D{name}=rnnoise_{name}".format(name = name) for name in replace_symbol_list
    ] + [
        "-Os",
    ],
    visibility = [
        "//visibility:public",
    ],
)
