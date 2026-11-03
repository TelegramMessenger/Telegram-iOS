/* Stub config.h for SPM build — disables all SIMD dispatch paths.
   WEBP_HAVE_NEON is intentionally NOT defined here: combined with
   HAVE_CONFIG_H being set, cpu.h's auto-detection of __aarch64__ is
   suppressed and no NEON function pointers are registered.
   Similarly we do not define WEBP_HAVE_SSE2 / WEBP_HAVE_SSE41.        */
