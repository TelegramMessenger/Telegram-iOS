#ifndef OPUS_CONFIG_H
#define OPUS_CONFIG_H

#define OPUS_BUILD 1
#define USE_ALLOCA 1
#define HAVE_LRINTF 1
#define HAVE_LRINT 1
#define VAR_ARRAYS 1

/* Disable SIMD intrinsic dispatch. We exclude the corresponding .c files in
 * Package.swift and -U the architecture macros in cSettings, so any NEON/SSE
 * dispatch stubs left compiled in fall through to scalar paths. */

/* Float build — FIXED_POINT not defined → float build, which matches the
 * decoder API (opus_decode_float) the Swift facade exposes. */

#endif
