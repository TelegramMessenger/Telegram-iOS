// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

func replaceSymbols() -> [String] {
    let symbols = [    "_celt_autocorr",
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
                       "remove_doubling"
    ]
    
    return symbols.map {
        return "-D\($0)=rnnoise_\($0)"
    }
}

let package = Package(
    name: "rnoise",
    platforms: [.macOS(.v10_11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "rnoise",
            targets: ["rnoise"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "rnoise",
            dependencies: [],
            path: ".",
            exclude: ["BUILD",
                     "Sources/compile.sh"],
            publicHeadersPath: "PublicHeaders",
            cSettings: [
                .headerSearchPath("PublicHeaders"),
                .unsafeFlags(replaceSymbols())
            ]),
    ]
)
