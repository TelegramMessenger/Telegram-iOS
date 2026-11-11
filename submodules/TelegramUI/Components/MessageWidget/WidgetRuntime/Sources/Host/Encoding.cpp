#include "Sources/Host/Encoding.h"

#include <string_view>

#include "Generated/Bindings.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

/// The Encoding Standard's labels of UTF-8.
constexpr std::string_view kUTF8Labels[] = {"unicode-1-1-utf-8", "unicode11utf8", "unicode20utf8",
                                            "utf-8",             "utf8",          "x-unicode20utf8"};

bool isASCIIWhitespace(char16_t c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r';
}

bool namesUTF8(const String& label) {
    uint32_t begin = 0;
    uint32_t end = label.length();
    while (begin < end && isASCIIWhitespace(label.at(begin))) {
        begin++;
    }
    while (end > begin && isASCIIWhitespace(label.at(end - 1))) {
        end--;
    }
    for (std::string_view name : kUTF8Labels) {
        if (end - begin != name.size()) {
            continue;
        }
        bool same = true;
        for (uint32_t i = 0; i < name.size() && same; i++) {
            char16_t c = label.at(begin + i);
            if (c >= 'A' && c <= 'Z') {
                c = char16_t(c + 32);
            }
            same = c == char16_t(name[i]);
        }
        if (same) {
            return true;
        }
    }
    return false;
}

/// ToBoolean(options[name]) for a dictionary member; an absent or undefined options object reads false.
bool optionFlag(JSContext* ctx, const std::optional<Value>& options, const char* name) {
    if (!options || JS_IsUndefined(options->get()) || JS_IsNull(options->get())) {
        return false;
    }
    if (!JS_IsObject(options->get())) {
        throw TypeError{"The options are not an object."};
    }
    Value value = Value::adopt(ctx, JS_GetPropertyStr(ctx, options->get(), name));
    if (JS_IsException(value.get())) {
        throw Thrown{};
    }
    const int truthy = JS_ToBool(ctx, value.get());
    if (truthy < 0) {
        throw Thrown{};
    }
    return truthy;
}

/// The UTF-8 bytes of a code point into `out` (room for four); how many.
size_t writeUTF8(uint8_t* out, uint32_t cp) {
    if (cp < 0x80) {
        out[0] = uint8_t(cp);
        return 1;
    }
    if (cp < 0x800) {
        out[0] = uint8_t(0xC0 | (cp >> 6));
        out[1] = uint8_t(0x80 | (cp & 0x3F));
        return 2;
    }
    if (cp < 0x10000) {
        out[0] = uint8_t(0xE0 | (cp >> 12));
        out[1] = uint8_t(0x80 | ((cp >> 6) & 0x3F));
        out[2] = uint8_t(0x80 | (cp & 0x3F));
        return 3;
    }
    out[0] = uint8_t(0xF0 | (cp >> 18));
    out[1] = uint8_t(0x80 | ((cp >> 12) & 0x3F));
    out[2] = uint8_t(0x80 | ((cp >> 6) & 0x3F));
    out[3] = uint8_t(0x80 | (cp & 0x3F));
    return 4;
}

void appendUTF8(Vector<uint8_t>& out, uint32_t cp) {
    uint8_t bytes[4];
    out.insert(out.end(), bytes, bytes + writeUTF8(bytes, cp));
}

/// The code point at `i` of a USVString (no lone surrogates), and how many code units it took.
uint32_t codePointAt(const String& s, uint32_t i, uint32_t& units) {
    const char16_t c = s.at(i);
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length()) {
        const char16_t d = s.at(i + 1);
        if (d >= 0xDC00 && d <= 0xDFFF) {
            units = 2;
            return 0x10000 + ((uint32_t(c) - 0xD800) << 10) + (uint32_t(d) - 0xDC00);
        }
    }
    units = 1;
    return c;
}

size_t utf8Length(uint32_t cp) {
    return cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4;
}

void defineData(JSContext* ctx, JSValueConst object, const char* name, JSValue value) {
    if (JS_DefinePropertyValueStr(ctx, object, name, value, JS_PROP_C_W_E) < 0) {
        throw Thrown{};
    }
}

} // namespace

ByteSpan bufferSourceBytes(JSContext* ctx, JSValueConst value, const char* what) {
    ByteSpan span;
    if (JS_IsArrayBuffer(value)) {
        span.data = JS_GetArrayBuffer(ctx, &span.size, value);
        if (!span.data) {
            // Detached: WebIDL's copy of its bytes is empty. The engine threw on the way, and a pending exception would
            // be read later as some other call's (fix-wave review, m1); a stop's is left to stop the widget.
            if (Runtime::from(ctx).stopReason() != StopReason::None) {
                throw Thrown{};
            }
            JS_FreeValue(ctx, JS_GetException(ctx));
            span.size = 0;
        }
        return span;
    }
    size_t offset = 0;
    size_t length = 0;
    Value buffer;
    if (JS_GetTypedArrayType(value) >= 0) {
        size_t elementSize = 0;
        buffer = Value::adopt(ctx, JS_GetTypedArrayBuffer(ctx, value, &offset, &length, &elementSize));
        if (JS_IsException(buffer.get())) {
            throw Thrown{};
        }
    } else if (JS_IsDataView(value)) {
        // The view's own slots, through the accessors the runtime took at startup: DataView.prototype's are redefinable,
        // and theirs once answered for the view (a negative offset wrapped the range check below and read the heap
        // before the buffer; a fresh ArrayBuffer from `buffer` was freed before its bytes were read).
        const Runtime& runtime = Runtime::from(ctx);
        auto slot = [&](Runtime::Intrinsic getter) {
            return Value::adopt(ctx, checked(ctx, JS_Call(ctx, runtime.intrinsic(getter), value, 0, nullptr)));
        };
        buffer = slot(Runtime::Intrinsic::DataViewBuffer);
        Value byteOffset = slot(Runtime::Intrinsic::DataViewByteOffset);
        Value byteLength = slot(Runtime::Intrinsic::DataViewByteLength);
        int64_t o = 0, l = 0;
        if (JS_ToInt64(ctx, &o, byteOffset.get()) < 0 || JS_ToInt64(ctx, &l, byteLength.get()) < 0) {
            throw Thrown{};
        }
        if (o < 0 || l < 0) {
            throw TypeError{std::string(what) + ": the view's range is invalid."};
        }
        offset = size_t(o);
        length = size_t(l);
    } else {
        throw TypeError{std::string(what) + ": expected an ArrayBuffer or an ArrayBuffer view."};
    }
    size_t size = 0;
    const uint8_t* bytes = JS_GetArrayBuffer(ctx, &size, buffer.get());
    if (!bytes) {
        throw Thrown{};
    }
    if (offset <= size && length <= size - offset) {
        span.data = bytes + offset;
        span.size = length;
    }
    return span;
}

Ref<TextEncoder> TextEncoder::construct(JSContext* ctx) {
    return create<TextEncoder>(ctx, idl::kTextEncoder);
}

Value TextEncoder::encode(JSContext* ctx, USVString input) {
    const uint32_t n = input.length();
    Vector<uint8_t> out{JSAllocator<uint8_t>(JS_GetRuntime(ctx))};
    out.reserve(n);
    for (uint32_t i = 0; i < n;) {
        uint32_t units = 1;
        appendUTF8(out, codePointAt(input, i, units));
        i += units;
    }
    Value array = Value::adopt(ctx, JS_NewUint8ArrayCopy(ctx, out.data(), out.size()));
    if (JS_IsException(array.get())) {
        throw Thrown{};
    }
    return array;
}

Value TextEncoder::encodeInto(JSContext* ctx, USVString source, Value destination) {
    if (JS_GetTypedArrayType(destination.get()) != JS_TYPED_ARRAY_UINT8) {
        throw TypeError{"encodeInto: the destination is not a Uint8Array."};
    }
    const ByteSpan span = bufferSourceBytes(ctx, destination.get(), "encodeInto");
    uint8_t* bytes = const_cast<uint8_t*>(span.data);
    const uint32_t n = source.length();
    uint32_t read = 0;
    size_t written = 0;
    while (read < n) {
        uint32_t units = 1;
        const uint32_t cp = codePointAt(source, read, units);
        const size_t need = utf8Length(cp);
        if (written + need > span.size) {
            break;
        }
        written += writeUTF8(bytes + written, cp);
        read += units;
    }
    Value result = Value::adopt(ctx, JS_NewObject(ctx));
    if (JS_IsException(result.get())) {
        throw Thrown{};
    }
    defineData(ctx, result.get(), "read", JS_NewUint32(ctx, read));
    defineData(ctx, result.get(), "written", JS_NewInt64(ctx, int64_t(written)));
    return result;
}

Ref<TextDecoder> TextDecoder::construct(JSContext* ctx, String label, std::optional<Value> options) {
    if (!namesUTF8(label)) {
        throw RangeError{"TextDecoder: only UTF-8 is supported."};
    }
    const bool fatal = optionFlag(ctx, options, "fatal");
    const bool ignoreBOM = optionFlag(ctx, options, "ignoreBOM");
    return create<TextDecoder>(ctx, idl::kTextDecoder, fatal, ignoreBOM);
}

bool UTF8Decoder::feed(const uint8_t* data, size_t size, bool flush, bool fatal, Text16& out) {
    auto emit = [&](uint32_t cp) {
        if (cp >= 0x10000) {
            out.push_back(char16_t(0xD800 + ((cp - 0x10000) >> 10)));
            out.push_back(char16_t(0xDC00 + ((cp - 0x10000) & 0x3FF)));
        } else {
            out.push_back(char16_t(cp));
        }
    };
    for (size_t i = 0; i < size;) {
        const uint8_t byte = data[i];
        if (m_bytesNeeded == 0) {
            i++;
            if (byte < 0x80) {
                emit(byte);
            } else if (byte >= 0xC2 && byte <= 0xDF) {
                m_bytesNeeded = 1;
                m_codePoint = byte & 0x1F;
            } else if (byte >= 0xE0 && byte <= 0xEF) {
                if (byte == 0xE0) {
                    m_lowerBoundary = 0xA0;
                }
                if (byte == 0xED) {
                    m_upperBoundary = 0x9F;
                }
                m_bytesNeeded = 2;
                m_codePoint = byte & 0xF;
            } else if (byte >= 0xF0 && byte <= 0xF4) {
                if (byte == 0xF0) {
                    m_lowerBoundary = 0x90;
                }
                if (byte == 0xF4) {
                    m_upperBoundary = 0x8F;
                }
                m_bytesNeeded = 3;
                m_codePoint = byte & 0x7;
            } else {
                if (fatal) {
                    this->reset();
                    return false;
                }
                emit(0xFFFD);
            }
            continue;
        }
        if (byte < m_lowerBoundary || byte > m_upperBoundary) {
            // The sequence ends here; the byte is processed again as a fresh one.
            this->reset();
            if (fatal) {
                return false;
            }
            emit(0xFFFD);
            continue;
        }
        i++;
        m_lowerBoundary = 0x80;
        m_upperBoundary = 0xBF;
        m_codePoint = (m_codePoint << 6) | (byte & 0x3F);
        if (++m_bytesSeen == m_bytesNeeded) {
            const uint32_t cp = m_codePoint;
            this->reset();
            emit(cp);
        }
    }
    if (flush && m_bytesNeeded != 0) {
        this->reset();
        if (fatal) {
            return false;
        }
        emit(0xFFFD);
    }
    return true;
}

void UTF8Decoder::reset() {
    m_codePoint = 0;
    m_bytesNeeded = 0;
    m_bytesSeen = 0;
    m_lowerBoundary = 0x80;
    m_upperBoundary = 0xBF;
}

void decodeUTF8WithoutBOM(const uint8_t* data, size_t size, Text16& out) {
    UTF8Decoder decoder;
    decoder.feed(data, size, true, false, out);
}

void encodeUTF8(const String& s, Vector<uint8_t>& out) {
    const uint32_t n = s.length();
    for (uint32_t i = 0; i < n;) {
        uint32_t units = 1;
        uint32_t cp = codePointAt(s, i, units);
        if (cp >= 0xD800 && cp <= 0xDFFF) {
            cp = 0xFFFD;
        }
        appendUTF8(out, cp);
        i += units;
    }
}

USVString TextDecoder::decode(JSContext* ctx, std::optional<Value> input, std::optional<Value> options) {
    // A call that is not a continuation starts a new decoder.
    if (!m_doNotFlush) {
        m_bomSeen = false;
        m_decoder.reset();
    }
    // The options first (WebIDL converts the dictionary before the method runs): a `stream` getter is script, which can
    // resize, transfer or detach the input's buffer, so its bytes are taken only after it has run (the final review's
    // C1), and nothing runs script between taking them and decoding them.
    const bool stream = optionFlag(ctx, options, "stream");
    ByteSpan bytes;
    if (input && !JS_IsUndefined(input->get())) {
        bytes = bufferSourceBytes(ctx, input->get(), "decode");
    }
    m_doNotFlush = stream;
    Text16 out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    out.reserve(bytes.size);
    if (!m_decoder.feed(bytes.data, bytes.size, !m_doNotFlush, m_fatal, out)) {
        m_doNotFlush = false;
        throw TypeError{"decode: the data is not valid UTF-8."};
    }
    // The first code point of a stream is dropped when it is a BOM, unless ignoreBOM.
    if (!m_ignoreBOM && !m_bomSeen && !out.empty()) {
        m_bomSeen = true;
        if (out.front() == 0xFEFF) {
            out.erase(out.begin());
        }
    }
    return USVString(String::fromUTF16(ctx, out.data(), out.size()));
}

} // namespace wr
