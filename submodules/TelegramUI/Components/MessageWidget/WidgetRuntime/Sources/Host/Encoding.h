// TextEncoder and TextDecoder (V5a plan, Task 3; the Encoding Standard, UTF-8 only).
#pragma once

#include <optional>

#include "Sources/Support/Allocator.h"
#include "Sources/Support/Bindings.h"

namespace wr {

/// UTF-16 code units in the JS heap.
using Text16 = Vector<char16_t>;

/// The Encoding Standard's UTF-8 decoder, its state kept between feeds (TextDecoder's `stream`; V5a plan, Tasks 3
/// and 6). An error appends U+FFFD, one per maximal subpart, or with `fatal` stops the feed and answers false.
class UTF8Decoder {
public:
    bool feed(const uint8_t* data, size_t size, bool flush, bool fatal, Text16& out);
    void reset();

private:
    uint32_t m_codePoint = 0;
    int m_bytesNeeded = 0;
    int m_bytesSeen = 0;
    uint8_t m_lowerBoundary = 0x80;
    uint8_t m_upperBoundary = 0xBF;
};

/// The Encoding Standard's "UTF-8 decode without BOM": every byte sequence decodes, errors as U+FFFD.
void decodeUTF8WithoutBOM(const uint8_t* data, size_t size, Text16& out);
/// The UTF-8 bytes of a scalar value string's code units (a lone surrogate, which a USVString never has, as U+FFFD).
void encodeUTF8(const String& s, Vector<uint8_t>& out);

class TextEncoder : public PlatformObject {
public:
    TextEncoder() = default;
    static Ref<TextEncoder> construct(JSContext* ctx);
    String encoding(JSContext* ctx) { return String::fromUTF8(ctx, "utf-8"); }
    /// A Uint8Array of `input`'s UTF-8 (a USVString: lone surrogates arrive as U+FFFD).
    Value encode(JSContext* ctx, USVString input);
    /// { read, written }: as many whole code points of `source` as fit in `destination`, a Uint8Array.
    Value encodeInto(JSContext* ctx, USVString source, Value destination);
};

class TextDecoder : public PlatformObject {
public:
    TextDecoder(bool fatal, bool ignoreBOM) : m_fatal(fatal), m_ignoreBOM(ignoreBOM) {}
    /// `label` names UTF-8 (one of the standard's six labels, after trimming and ASCII lowercasing), else a RangeError;
    /// `options` reads `fatal` and `ignoreBOM`.
    static Ref<TextDecoder> construct(JSContext* ctx, String label, std::optional<Value> options);
    String encoding(JSContext* ctx) { return String::fromUTF8(ctx, "utf-8"); }
    bool fatal(JSContext*) const { return m_fatal; }
    bool ignoreBOM(JSContext*) const { return m_ignoreBOM; }
    /// `input` is an ArrayBuffer or a view (absent is empty); `options.stream` keeps an unfinished sequence for the next
    /// call.
    USVString decode(JSContext* ctx, std::optional<Value> input, std::optional<Value> options);

private:
    bool m_fatal;
    bool m_ignoreBOM;
    // The decoder, kept between calls while `stream` is set.
    bool m_doNotFlush = false;
    bool m_bomSeen = false;
    UTF8Decoder m_decoder;
};

/// The bytes of an ArrayBuffer or an ArrayBuffer view (a typed array or a DataView): a pointer into the buffer, valid
/// until script runs again. Anything else is a TypeError. Shared by Blob (Task 9).
struct ByteSpan {
    const uint8_t* data = nullptr;
    size_t size = 0;
};
ByteSpan bufferSourceBytes(JSContext* ctx, JSValueConst value, const char* what);

} // namespace wr
