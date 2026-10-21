// crypto (V5a plan, Task 1; Web Cryptography API §10.1): getRandomValues and randomUUID, the bytes from
// Host::randomBytes.
#pragma once

#include <cstddef>
#include <optional>

#include "Sources/Support/Bindings.h"

namespace wr {

/// Web Crypto: getRandomValues fills at most this many bytes; more is a QuotaExceededError.
inline constexpr size_t kMaxRandomBytes = 65536;

class Crypto : public PlatformObject {
public:
    Crypto() = default;
    /// An integer typed array (Int8 … BigUint64, Uint8Clamped) of at most kMaxRandomBytes, filled and returned; another
    /// view is a TypeMismatchError, anything else a TypeError.
    Value getRandomValues(JSContext* ctx, Value array);
    /// RFC 9562 §5.4: a version 4 UUID in lowercase hex.
    String randomUUID(JSContext* ctx);
};

} // namespace wr
