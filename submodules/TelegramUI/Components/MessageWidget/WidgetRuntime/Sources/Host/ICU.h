// The system ICU, libicucore: only what the SDK's own headers declare (utypes.h, uchar.h, ustring.h, uidna.h, …), which
// is all of it that is public API. Character properties, case mapping, UTF-16 and IDNA come from here; locale data never
// does (Intl asks the host, Sources/Host/Intl.h), and nothing may declare another ICU function by hand: App Store review
// rejects the app for any libicucore symbol the SDK's headers do not declare (build-system/Make/ICUImportCheck.py fails
// the build on one). Apple's library exports the names without ICU's version suffix, which is what U_DISABLE_RENAMING
// selects; it must come before any ICU header.
#pragma once

#ifndef U_DISABLE_RENAMING
#define U_DISABLE_RENAMING 1
#endif
static_assert(U_DISABLE_RENAMING == 1, "libicucore exports unsuffixed names");
// Apple's headers make UChar uint16_t; ICU's own default in C++ is char16_t, the same 16-bit unit, which the runtime's
// UTF-16 buffers (Text16) hold.
#ifndef UCHAR_TYPE
#define UCHAR_TYPE char16_t
#endif

#include <unicode/uchar.h>
#include <unicode/uidna.h>
#include <unicode/ustring.h>
#include <unicode/utf16.h>
#include <unicode/utf8.h>
#include <unicode/utypes.h>
