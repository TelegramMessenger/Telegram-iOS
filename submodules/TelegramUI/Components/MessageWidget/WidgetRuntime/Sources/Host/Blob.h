// Blob (V5a plan, Task 9; File API §3).
#pragma once

#include <optional>

#include "Sources/Support/Allocator.h"
#include "Sources/Support/Bindings.h"

namespace wr {

class Blob final : public PlatformObject {
public:
    /// `type` is a string value, taken over (the File API's checked, lowercased type).
    Blob(JSContext* ctx, JSValue type);
    /// `blobParts` a sequence of strings (UTF-8, a lone surrogate as U+FFFD), buffer sources (copied) and blobs;
    /// `options.type` kept lowercased when it is all U+0020–U+007E, else "".
    static Ref<Blob> construct(JSContext* ctx, std::optional<Value> blobParts, std::optional<Value> options);
    uint64_t size(JSContext*) const { return m_bytes.size(); }
    String type(JSContext* ctx) const { return String::adopt(ctx, JS_DupValue(ctx, m_type.value)); }
    Ref<Blob> slice(JSContext* ctx, std::optional<int64_t> start, std::optional<int64_t> end, std::optional<String> contentType);
    /// Promises resolved at once: the bytes decoded as UTF-8, and a new ArrayBuffer of them.
    Value text(JSContext* ctx);
    Value arrayBuffer(JSContext* ctx);
    void dispose(JSRuntime* rt) override { m_type.clear(rt); }

private:
    Vector<uint8_t> m_bytes;
    /// A JS string, in the JS heap under its limit (V5a final review, I1: a C++-heap copy per Blob escaped it).
    Held m_type;
};

} // namespace wr
