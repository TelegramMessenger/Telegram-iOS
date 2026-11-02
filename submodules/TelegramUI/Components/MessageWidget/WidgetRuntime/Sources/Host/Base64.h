// atob and btoa (V5a plan, Task 2; HTML §8.3 "Base64 utility methods").
#pragma once

#include "Sources/Support/Values.h"

namespace wr {

/// btoa: the code units of `data` as bytes, base64-encoded with padding. A code unit above 0xFF is an
/// InvalidCharacterError. The output is built in the JS heap.
String base64Encode(JSContext* ctx, const String& data);
/// atob: Infra's forgiving-base64 decode (ASCII whitespace removed, one or two trailing "=" dropped when the length is a
/// multiple of four, no padding needed otherwise), each byte one code unit. Anything else is an InvalidCharacterError.
String forgivingBase64Decode(JSContext* ctx, const String& data);

} // namespace wr
