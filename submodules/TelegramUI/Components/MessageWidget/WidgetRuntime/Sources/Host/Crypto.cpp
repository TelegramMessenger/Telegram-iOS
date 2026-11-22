#include "Sources/Host/Crypto.h"

#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

Value Crypto::getRandomValues(JSContext* ctx, Value array) {
    const int type = JS_GetTypedArrayType(array.get());
    if (type < 0) {
        if (JS_IsDataView(array.get())) {
            throw DOMError{"TypeMismatchError", "getRandomValues takes an integer typed array."};
        }
        throw TypeError{"getRandomValues: the argument is not a typed array."};
    }
    if (type == JS_TYPED_ARRAY_FLOAT16 || type == JS_TYPED_ARRAY_FLOAT32 || type == JS_TYPED_ARRAY_FLOAT64) {
        throw DOMError{"TypeMismatchError", "getRandomValues takes an integer typed array."};
    }
    size_t offset = 0, length = 0, elementSize = 0;
    Value buffer = Value::adopt(ctx, JS_GetTypedArrayBuffer(ctx, array.get(), &offset, &length, &elementSize));
    if (JS_IsException(buffer.get())) {
        throw Thrown{};
    }
    if (length > kMaxRandomBytes) {
        throw DOMError{"QuotaExceededError", "getRandomValues fills at most 65536 bytes."};
    }
    size_t size = 0;
    uint8_t* bytes = JS_GetArrayBuffer(ctx, &size, buffer.get());
    if (bytes && offset + length <= size) {
        Runtime::from(ctx).host().randomBytes(bytes + offset, length);
    }
    return array;
}

String Crypto::randomUUID(JSContext* ctx) {
    uint8_t bytes[16];
    Runtime::from(ctx).host().randomBytes(bytes, sizeof(bytes));
    bytes[6] = uint8_t((bytes[6] & 0x0f) | 0x40);
    bytes[8] = uint8_t((bytes[8] & 0x3f) | 0x80);
    static constexpr char kHex[] = "0123456789abcdef";
    char text[37];
    size_t at = 0;
    for (size_t i = 0; i < sizeof(bytes); i++) {
        if (i == 4 || i == 6 || i == 8 || i == 10) {
            text[at++] = '-';
        }
        text[at++] = kHex[bytes[i] >> 4];
        text[at++] = kHex[bytes[i] & 15];
    }
    return String::fromUTF8(ctx, std::string_view(text, at));
}

} // namespace wr
