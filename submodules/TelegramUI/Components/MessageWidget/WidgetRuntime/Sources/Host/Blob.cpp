#include "Sources/Host/Blob.h"

#include <algorithm>

#include "Generated/Bindings.h"
#include "Sources/Host/Encoding.h"
#include "Sources/Host/Sequences.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

/// File API: a type of code units U+0020–U+007E only, ASCII-lowercased; anything else is "". A new string value, in the
/// JS heap: the input itself when it is lowercase already.
JSValue checkedType(JSContext* ctx, const String& type) {
    const uint32_t n = type.length();
    bool lowercase = true;
    for (uint32_t i = 0; i < n; i++) {
        const char16_t c = type.at(i);
        if (c < 0x20 || c > 0x7E) {
            return JS_NewString(ctx, "");
        }
        lowercase = lowercase && !(c >= 'A' && c <= 'Z');
    }
    if (lowercase) {
        return type.toJS(ctx);
    }
    Text16 out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    out.reserve(n);
    for (uint32_t i = 0; i < n; i++) {
        const char16_t c = type.at(i);
        out.push_back(c >= 'A' && c <= 'Z' ? char16_t(c + 32) : c);
    }
    return String::fromUTF16(ctx, out.data(), out.size()).toJS(ctx);
}

Value resolvedWith(JSContext* ctx, Value value) {
    JSValue resolving[2];
    Value promise = Value::adopt(ctx, JS_NewPromiseCapability(ctx, resolving));
    if (JS_IsException(promise.get())) {
        throw Thrown{};
    }
    Value resolve = Value::adopt(ctx, resolving[0]);
    Value reject = Value::adopt(ctx, resolving[1]);
    JSValueConst argv[1] = {value.get()};
    Value result = Value::adopt(ctx, JS_Call(ctx, resolve.get(), JS_UNDEFINED, 1, argv));
    if (JS_IsException(result.get())) {
        throw Thrown{};
    }
    return promise;
}

/// A relative slice index (File API's slice steps).
uint64_t relative(std::optional<int64_t> index, uint64_t size, uint64_t fallback) {
    if (!index) {
        return fallback;
    }
    if (*index < 0) {
        return uint64_t(std::max<int64_t>(int64_t(size) + *index, 0));
    }
    return std::min<uint64_t>(uint64_t(*index), size);
}

} // namespace

Blob::Blob(JSContext* ctx, JSValue type) : m_bytes(JSAllocator<uint8_t>(JS_GetRuntime(ctx))) {
    m_type.set(JS_GetRuntime(ctx), type);
}

Ref<Blob> Blob::construct(JSContext* ctx, std::optional<Value> blobParts, std::optional<Value> options) {
    Value type = Value::adopt(ctx, JS_NewString(ctx, ""));
    if (options && JS_IsObject(options->get())) {
        Value value = Value::adopt(ctx, JS_GetPropertyStr(ctx, options->get(), "type"));
        if (JS_IsException(value.get())) {
            throw Thrown{};
        }
        if (!JS_IsUndefined(value.get())) {
            type = Value::adopt(ctx, checkedType(ctx, convert<String>(ctx, value.get(), ArgInfo{"Blob", "constructor", 1})));
        }
    }
    if (JS_IsException(type.get())) {
        throw Thrown{};
    }
    Ref<Blob> blob = create<Blob>(ctx, idl::kBlob, ctx, JS_DupValue(ctx, type.get()));
    if (!blobParts || JS_IsUndefined(blobParts->get())) {
        return blob;
    }
    std::optional<std::vector<Value>> parts =
        JS_IsObject(blobParts->get()) ? sequenceValues(ctx, blobParts->get(), "Blob") : std::nullopt;
    if (!parts) {
        throw TypeError{"Blob: the parts are not a sequence."};
    }
    for (const Value& part : *parts) {
        if (Blob* other = unwrap<Blob>(ctx, part.get(), idl::kBlob)) {
            blob->m_bytes.insert(blob->m_bytes.end(), other->m_bytes.begin(), other->m_bytes.end());
        } else if (JS_IsArrayBuffer(part.get()) || JS_GetTypedArrayType(part.get()) >= 0 || JS_IsDataView(part.get())) {
            const ByteSpan span = bufferSourceBytes(ctx, part.get(), "Blob");
            if (span.data) {
                blob->m_bytes.insert(blob->m_bytes.end(), span.data, span.data + span.size);
            }
        } else {
            const USVString text = convert<USVString>(ctx, part.get(), ArgInfo{"Blob", "constructor", 0});
            encodeUTF8(text, blob->m_bytes);
        }
    }
    return blob;
}

Ref<Blob> Blob::slice(JSContext* ctx, std::optional<int64_t> start, std::optional<int64_t> end, std::optional<String> contentType) {
    const uint64_t size = m_bytes.size();
    const uint64_t from = relative(start, size, 0);
    const uint64_t to = relative(end, size, size);
    Value type = Value::adopt(ctx, contentType ? checkedType(ctx, *contentType) : JS_NewString(ctx, ""));
    if (JS_IsException(type.get())) {
        throw Thrown{};
    }
    Ref<Blob> sliced = create<Blob>(ctx, idl::kBlob, ctx, JS_DupValue(ctx, type.get()));
    if (to > from) {
        sliced->m_bytes.assign(m_bytes.begin() + ptrdiff_t(from), m_bytes.begin() + ptrdiff_t(to));
    }
    return sliced;
}

Value Blob::text(JSContext* ctx) {
    Text16 out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    decodeUTF8WithoutBOM(m_bytes.data(), m_bytes.size(), out);
    // File API reads with "UTF-8 decode", which drops a leading BOM.
    if (!out.empty() && out.front() == 0xFEFF) {
        out.erase(out.begin());
    }
    return resolvedWith(ctx, Value::adopt(ctx, String::fromUTF16(ctx, out.data(), out.size()).toJS(ctx)));
}

Value Blob::arrayBuffer(JSContext* ctx) {
    Value buffer = Value::adopt(ctx, JS_NewArrayBufferCopy(ctx, m_bytes.data(), m_bytes.size()));
    if (JS_IsException(buffer.get())) {
        throw Thrown{};
    }
    return resolvedWith(ctx, std::move(buffer));
}

} // namespace wr
