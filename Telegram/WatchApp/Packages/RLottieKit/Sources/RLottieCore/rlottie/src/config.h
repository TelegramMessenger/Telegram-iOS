// Manually authored config.h for vendored rlottie build via Swift Package Manager.
// Replaces the cmake-generated config.h (from cmake/config.h.in).
// We disable all optional features that would require extra dependencies or
// platform-specific setup:
//   - LOTTIE_THREAD_SUPPORT: requires std::thread / TaskQueue wiring; disabled
//     to keep the rendering synchronous (caller drives frame requests).
//   - LOTTIE_CACHE_SUPPORT: model cache; disabled for simplicity.
//   - LOTTIE_IMAGE_MODULE_SUPPORT: dynamic-library plugin for image decoding;
//     disabled (stb_image is vendored and used unconditionally instead).
//   - LOTTIE_LOGGING_SUPPORT: debug logging to stderr; disabled.

// #define LOTTIE_THREAD_SUPPORT
// #define LOTTIE_CACHE_SUPPORT
// #define LOTTIE_IMAGE_MODULE_SUPPORT
// #define LOTTIE_LOGGING_SUPPORT
