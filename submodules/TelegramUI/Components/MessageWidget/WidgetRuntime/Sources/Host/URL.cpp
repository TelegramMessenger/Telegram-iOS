#include "Sources/Host/URL.h"

#include <algorithm>

#include "Generated/Bindings.h"
#include "Sources/Host/Sequences.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

constexpr char kUpperHex[] = "0123456789ABCDEF";

int hexValue(uint8_t c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    }
    return -1;
}

/// The URL Standard's percent-decode, over bytes.
void percentDecode(const uint8_t* data, size_t size, Vector<uint8_t>& out) {
    for (size_t i = 0; i < size; i++) {
        if (data[i] == '%' && i + 2 < size && hexValue(data[i + 1]) >= 0 && hexValue(data[i + 2]) >= 0) {
            out.push_back(uint8_t(hexValue(data[i + 1]) * 16 + hexValue(data[i + 2])));
            i += 2;
        } else {
            out.push_back(data[i]);
        }
    }
}

/// application/x-www-form-urlencoded: only ASCII alphanumerics and *-._ stand as they are; space is "+".
void formEncode(const Vector<uint8_t>& bytes, std::string& out) {
    for (uint8_t b : bytes) {
        if ((b >= '0' && b <= '9') || (b >= 'A' && b <= 'Z') || (b >= 'a' && b <= 'z') || b == '*' || b == '-' || b == '.' || b == '_') {
            out += char(b);
        } else if (b == ' ') {
            out += '+';
        } else {
            out += '%';
            out += kUpperHex[b >> 4];
            out += kUpperHex[b & 15];
        }
    }
}

USVString toUSV(JSContext* ctx, const Text16& text) {
    return USVString(String::fromUTF16(ctx, text.data(), text.size()));
}

USVString usv(JSContext* ctx, JSValueConst value) {
    return convert<USVString>(ctx, value, ArgInfo{"URLSearchParams", "constructor", 0});
}

} // namespace

URLSearchParams::URLSearchParams(JSContext* ctx) : m_list(JSAllocator<Entry>(JS_GetRuntime(ctx))) {}

Text16 URLSearchParams::text(JSContext* ctx, const String& s) const {
    const uint32_t n = s.length();
    Text16 out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    out.reserve(n);
    for (uint32_t i = 0; i < n; i++) {
        out.push_back(s.at(i));
    }
    return out;
}

Ref<URLSearchParams> URLSearchParams::construct(JSContext* ctx, std::optional<Value> init) {
    Ref<URLSearchParams> params = create<URLSearchParams>(ctx, idl::kURLSearchParams, ctx);
    if (!init || JS_IsUndefined(init->get())) {
        return params;
    }
    JSValueConst value = init->get();
    if (JS_IsObject(value)) {
        if (std::optional<std::vector<Value>> items = sequenceValues(ctx, value, "URLSearchParams")) {
            // sequence<sequence<USVString>>: each item a pair.
            for (const Value& item : *items) {
                std::optional<std::vector<Value>> inner = JS_IsObject(item.get()) ? sequenceValues(ctx, item.get(), "URLSearchParams") : std::nullopt;
                if (!inner) {
                    throw TypeError{"URLSearchParams: each pair must be a sequence."};
                }
                std::vector<Value>& pair = *inner;
                if (pair.size() != 2) {
                    throw TypeError{"URLSearchParams: each pair must have exactly two items."};
                }
                params->m_list.emplace_back(params->text(ctx, usv(ctx, pair[0].get())), params->text(ctx, usv(ctx, pair[1].get())));
            }
            return params;
        }
        // record<USVString, USVString>: the own enumerable string-keyed properties, in order.
        JSPropertyEnum* names = nullptr;
        uint32_t count = 0;
        if (JS_GetOwnPropertyNames(ctx, &names, &count, value, JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY) < 0) {
            throw Thrown{};
        }
        struct Names {
            JSContext* ctx;
            JSPropertyEnum* names;
            uint32_t count;
            ~Names() { JS_FreePropertyEnum(ctx, names, count); }
        } owned{ctx, names, count};
        for (uint32_t i = 0; i < count; i++) {
            Value key = Value::adopt(ctx, JS_AtomToString(ctx, names[i].atom));
            Value item = Value::adopt(ctx, JS_GetProperty(ctx, value, names[i].atom));
            if (JS_IsException(key.get()) || JS_IsException(item.get())) {
                throw Thrown{};
            }
            params->m_list.emplace_back(params->text(ctx, usv(ctx, key.get())), params->text(ctx, usv(ctx, item.get())));
        }
        return params;
    }
    USVString query = usv(ctx, value);
    if (query.length() > 0 && query.at(0) == '?') {
        query = USVString(query.substring(ctx, 1, query.length()));
    }
    params->parse(ctx, query);
    return params;
}

void URLSearchParams::parse(JSContext* ctx, const String& input) {
    m_list.clear();
    Vector<uint8_t> bytes{JSAllocator<uint8_t>(JS_GetRuntime(ctx))};
    encodeUTF8(input, bytes);
    size_t start = 0;
    while (start <= bytes.size()) {
        size_t end = start;
        while (end < bytes.size() && bytes[end] != '&') {
            end++;
        }
        if (end > start) {
            size_t equals = start;
            while (equals < end && bytes[equals] != '=') {
                equals++;
            }
            auto decode = [&](size_t from, size_t to) {
                Vector<uint8_t> plus{JSAllocator<uint8_t>(JS_GetRuntime(ctx))};
                for (size_t i = from; i < to; i++) {
                    plus.push_back(bytes[i] == '+' ? uint8_t(' ') : bytes[i]);
                }
                Vector<uint8_t> decoded{JSAllocator<uint8_t>(JS_GetRuntime(ctx))};
                percentDecode(plus.data(), plus.size(), decoded);
                Text16 out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
                decodeUTF8WithoutBOM(decoded.data(), decoded.size(), out);
                return out;
            };
            Text16 name = decode(start, equals);
            Text16 value = equals < end ? decode(equals + 1, end) : Text16{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
            m_list.emplace_back(std::move(name), std::move(value));
        }
        start = end + 1;
    }
}

std::string URLSearchParams::serialize(JSContext* ctx) const {
    std::string out;
    for (const Entry& entry : m_list) {
        if (!out.empty()) {
            out += '&';
        }
        Vector<uint8_t> bytes{JSAllocator<uint8_t>(JS_GetRuntime(ctx))};
        encodeUTF8(String::fromUTF16(ctx, entry.first.data(), entry.first.size()), bytes);
        formEncode(bytes, out);
        out += '=';
        bytes.clear();
        encodeUTF8(String::fromUTF16(ctx, entry.second.data(), entry.second.size()), bytes);
        formEncode(bytes, out);
    }
    return out;
}

void URLSearchParams::append(JSContext* ctx, USVString name, USVString value) {
    m_list.emplace_back(this->text(ctx, name), this->text(ctx, value));
    this->update(ctx);
}

void URLSearchParams::delete_(JSContext* ctx, USVString name, std::optional<USVString> value) {
    const Text16 n = this->text(ctx, name);
    const std::optional<Text16> v = value ? std::optional<Text16>(this->text(ctx, *value)) : std::nullopt;
    m_list.erase(std::remove_if(m_list.begin(), m_list.end(), [&](const Entry& e) { return e.first == n && (!v || e.second == *v); }),
                 m_list.end());
    this->update(ctx);
}

std::optional<USVString> URLSearchParams::get(JSContext* ctx, USVString name) {
    const Text16 n = this->text(ctx, name);
    for (const Entry& e : m_list) {
        if (e.first == n) {
            return toUSV(ctx, e.second);
        }
    }
    return std::nullopt;
}

std::vector<USVString> URLSearchParams::getAll(JSContext* ctx, USVString name) {
    const Text16 n = this->text(ctx, name);
    std::vector<USVString> out;
    for (const Entry& e : m_list) {
        if (e.first == n) {
            out.push_back(toUSV(ctx, e.second));
        }
    }
    return out;
}

bool URLSearchParams::has(JSContext* ctx, USVString name, std::optional<USVString> value) {
    const Text16 n = this->text(ctx, name);
    const std::optional<Text16> v = value ? std::optional<Text16>(this->text(ctx, *value)) : std::nullopt;
    return std::any_of(m_list.begin(), m_list.end(), [&](const Entry& e) { return e.first == n && (!v || e.second == *v); });
}

void URLSearchParams::set(JSContext* ctx, USVString name, USVString value) {
    const Text16 n = this->text(ctx, name);
    Text16 v = this->text(ctx, value);
    auto first = std::find_if(m_list.begin(), m_list.end(), [&](const Entry& e) { return e.first == n; });
    if (first == m_list.end()) {
        m_list.emplace_back(n, std::move(v));
    } else {
        first->second = std::move(v);
        m_list.erase(std::remove_if(first + 1, m_list.end(), [&](const Entry& e) { return e.first == n; }), m_list.end());
    }
    this->update(ctx);
}

void URLSearchParams::sort(JSContext* ctx) {
    std::stable_sort(m_list.begin(), m_list.end(), [](const Entry& a, const Entry& b) { return a.first < b.first; });
    this->update(ctx);
}

String URLSearchParams::toString(JSContext* ctx) {
    return String::fromUTF8(ctx, this->serialize(ctx));
}

std::pair<USVString, USVString> URLSearchParams::iterationPair(JSContext* ctx, uint32_t index) {
    return {toUSV(ctx, m_list[index].first), toUSV(ctx, m_list[index].second)};
}

namespace {

/// The code units of `s`; nullopt past url::kMaxURLLength, which no URL can have.
std::optional<std::u16string> urlUnits(JSContext* ctx, const String& s) {
    if (s.length() > url::kMaxURLLength) {
        return std::nullopt;
    }
    std::u16string out;
    out.reserve(s.length());
    for (uint32_t i = 0; i < s.length(); i++) {
        out += s.at(i);
    }
    return out;
}

std::optional<url::Record> parseWith(JSContext* ctx, const String& input, const std::optional<USVString>& base) {
    std::optional<url::Record> baseRecord;
    if (base) {
        std::optional<std::u16string> b = urlUnits(ctx, *base);
        baseRecord = b ? url::parse(*b, nullptr) : std::nullopt;
        if (!baseRecord) {
            return std::nullopt;
        }
    }
    std::optional<std::u16string> u = urlUnits(ctx, input);
    std::optional<url::Record> record = u ? url::parse(*u, baseRecord ? &*baseRecord : nullptr) : std::nullopt;
    if (record) {
        // A URL's href (ASCII) is at most kMaxURLLength, so it always parses back to its record (URL::record): an
        // input under the limit can serialize to nine times it.
        const std::string href = record->serialize();
        if (href.size() > url::kMaxURLLength) {
            return std::nullopt;
        }
    }
    return record;
}

USVString usvFromASCII(JSContext* ctx, const std::string& s) {
    return USVString(String::fromUTF8(ctx, s));
}

std::string encoded(JSContext* ctx, const String& value, url::EncodeSet set) {
    std::optional<std::u16string> u = urlUnits(ctx, value);
    std::string out;
    if (u) {
        for (char32_t c : url::codePoints(*u)) {
            url::percentEncode(c, set, out);
        }
    }
    return out;
}

} // namespace

void URLSearchParams::attachURL(JSContext* ctx, URL& url) {
    m_url.set(JS_GetRuntime(ctx), JS_DupValue(ctx, url.object()));
}

void URLSearchParams::update(JSContext* ctx) {
    if (m_url.isUndefined()) {
        return;
    }
    static_cast<URL*>(payloadOfKnown(m_url.value))->paramsChanged(ctx, this->serialize(ctx));
}

void URLSearchParams::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_url.mark(rt, mark);
}

void URLSearchParams::dispose(JSRuntime* rt) {
    m_url.clear(rt);
}

Ref<URL> URL::make(JSContext* ctx, const url::Record& record) {
    Ref<URL> made = create<URL>(ctx, idl::kURL);
    made->store(ctx, record);
    Ref<URLSearchParams> params = create<URLSearchParams>(ctx, idl::kURLSearchParams, ctx);
    params->parse(ctx, String::fromUTF8(ctx, record.query.value_or("")));
    params->attachURL(ctx, *made);
    made->m_searchParams.set(JS_GetRuntime(ctx), params.release());
    return made;
}

Ref<URL> URL::construct(JSContext* ctx, USVString input, std::optional<USVString> base) {
    std::optional<url::Record> record = parseWith(ctx, input, base);
    if (!record) {
        throw TypeError{"URL: invalid URL."};
    }
    return make(ctx, *record);
}

std::optional<Ref<URL>> URL::parse(JSContext* ctx, USVString input, std::optional<USVString> base) {
    std::optional<url::Record> record = parseWith(ctx, input, base);
    if (!record) {
        return std::nullopt;
    }
    return make(ctx, *record);
}

bool URL::canParse(JSContext* ctx, USVString input, std::optional<USVString> base) {
    return parseWith(ctx, input, base).has_value();
}

url::Record URL::record(JSContext* ctx) const {
    const String href = String::adopt(ctx, JS_DupValue(ctx, m_href.value));
    std::optional<std::u16string> u = urlUnits(ctx, href);
    std::optional<url::Record> record = u ? url::parse(*u, nullptr) : std::nullopt;
    // A serialization parses back to its record (the URL Standard's idempotence).
    return record ? *record : url::Record{};
}

void URL::store(JSContext* ctx, const url::Record& record) {
    const std::string href = record.serialize();
    // A setter whose result would be longer than the limit leaves the URL as it was, as a setter's failure does
    // (parseWith refuses such a URL to the constructor, parse, canParse and the href setter).
    if (href.size() > url::kMaxURLLength) {
        return;
    }
    m_href.set(JS_GetRuntime(ctx), String::fromUTF8(ctx, href).toJS(ctx));
}

void URL::syncParams(JSContext* ctx, const url::Record& record) {
    static_cast<URLSearchParams*>(payloadOfKnown(m_searchParams.value))->parse(ctx, String::fromUTF8(ctx, record.query.value_or("")));
}

void URL::paramsChanged(JSContext* ctx, const std::string& serialization) {
    url::Record r = this->record(ctx);
    r.query = serialization.empty() ? std::nullopt : std::optional<std::string>(serialization);
    this->store(ctx, r);
}

USVString URL::href(JSContext* ctx) {
    return USVString(String::adopt(ctx, JS_DupValue(ctx, m_href.value)));
}

void URL::setHref(JSContext* ctx, USVString value) {
    std::optional<url::Record> record = parseWith(ctx, value, std::nullopt);
    if (!record) {
        throw TypeError{"URL: invalid URL."};
    }
    this->store(ctx, *record);
    this->syncParams(ctx, *record);
}

USVString URL::origin(JSContext* ctx) {
    return usvFromASCII(ctx, this->record(ctx).origin());
}

USVString URL::protocol(JSContext* ctx) {
    return usvFromASCII(ctx, this->record(ctx).scheme + ":");
}

void URL::setProtocol(JSContext* ctx, USVString value) {
    std::optional<std::u16string> u = urlUnits(ctx, value);
    if (!u) {
        return;
    }
    std::string scheme;
    for (char16_t c : *u) {
        if (c == ':') {
            break;
        }
        const bool alpha = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
        const bool rest = alpha || (c >= '0' && c <= '9') || c == '+' || c == '-' || c == '.';
        if (scheme.empty() ? !alpha : !rest) {
            return;
        }
        scheme += char(c >= 'A' && c <= 'Z' ? c + 32 : c);
    }
    url::Record r = this->record(ctx);
    if (scheme.empty() || url::isSpecialScheme(scheme) != r.special()) {
        return;
    }
    if (scheme == "file" && (!r.username.empty() || !r.password.empty() || r.port)) {
        return;
    }
    if (r.scheme == "file" && r.host && r.host->empty()) {
        return;
    }
    r.scheme = scheme;
    if (r.port && r.port == url::defaultPort(scheme)) {
        r.port.reset();
    }
    this->store(ctx, r);
}

USVString URL::username(JSContext* ctx) {
    return usvFromASCII(ctx, this->record(ctx).username);
}

void URL::setUsername(JSContext* ctx, USVString value) {
    url::Record r = this->record(ctx);
    if (!r.host || r.host->empty() || r.scheme == "file") {
        return;
    }
    r.username = encoded(ctx, value, url::EncodeSet::Userinfo);
    this->store(ctx, r);
}

USVString URL::password(JSContext* ctx) {
    return usvFromASCII(ctx, this->record(ctx).password);
}

void URL::setPassword(JSContext* ctx, USVString value) {
    url::Record r = this->record(ctx);
    if (!r.host || r.host->empty() || r.scheme == "file") {
        return;
    }
    r.password = encoded(ctx, value, url::EncodeSet::Userinfo);
    this->store(ctx, r);
}

USVString URL::host(JSContext* ctx) {
    const url::Record r = this->record(ctx);
    if (!r.host) {
        return usvFromASCII(ctx, "");
    }
    return usvFromASCII(ctx, r.port ? *r.host + ":" + std::to_string(*r.port) : *r.host);
}

void URL::setHost(JSContext* ctx, USVString value) {
    url::Record r = this->record(ctx);
    std::optional<std::u16string> u = urlUnits(ctx, value);
    if (r.opaquePath || !u) {
        return;
    }
    // The host and an optional port, up to the first delimiter the host state stops at.
    std::u16string part;
    bool brackets = false, hasPort = false;
    for (char16_t c : *u) {
        if (c == '/' || c == '?' || c == '#' || (r.special() && c == '\\')) {
            break;
        }
        brackets = c == '[' ? true : c == ']' ? false : brackets;
        hasPort = hasPort || (c == ':' && !brackets);
        part += c;
    }
    if (part.empty() && r.special()) {
        return;
    }
    std::u16string candidate(r.scheme.begin(), r.scheme.end());
    candidate += u"://" + part + u"/";
    std::optional<url::Record> c = url::parse(candidate, nullptr);
    if (!c) {
        return;
    }
    r.host = c->host;
    if (hasPort) {
        r.port = c->port;
    }
    this->store(ctx, r);
}

USVString URL::hostname(JSContext* ctx) {
    return usvFromASCII(ctx, this->record(ctx).host.value_or(""));
}

void URL::setHostname(JSContext* ctx, USVString value) {
    url::Record r = this->record(ctx);
    std::optional<std::u16string> u = urlUnits(ctx, value);
    if (r.opaquePath || !u) {
        return;
    }
    std::u16string part;
    bool brackets = false;
    for (char16_t c : *u) {
        if (c == '/' || c == '?' || c == '#' || (r.special() && c == '\\') || (c == ':' && !brackets)) {
            break;
        }
        brackets = c == '[' ? true : c == ']' ? false : brackets;
        part += c;
    }
    if (part.empty() && r.special()) {
        return;
    }
    std::u16string candidate(r.scheme.begin(), r.scheme.end());
    candidate += u"://" + part + u"/";
    std::optional<url::Record> c = url::parse(candidate, nullptr);
    if (!c) {
        return;
    }
    r.host = c->host;
    this->store(ctx, r);
}

USVString URL::port(JSContext* ctx) {
    const url::Record r = this->record(ctx);
    return usvFromASCII(ctx, r.port ? std::to_string(*r.port) : std::string());
}

void URL::setPort(JSContext* ctx, USVString value) {
    url::Record r = this->record(ctx);
    std::optional<std::u16string> u = urlUnits(ctx, value);
    if (!r.host || r.host->empty() || r.scheme == "file" || !u) {
        return;
    }
    if (u->empty()) {
        r.port.reset();
        this->store(ctx, r);
        return;
    }
    uint32_t port = 0;
    size_t digits = 0;
    for (char16_t c : *u) {
        if (c < '0' || c > '9') {
            break;
        }
        port = port * 10 + uint32_t(c - '0');
        digits++;
        if (port > 65535) {
            return;
        }
    }
    if (digits == 0) {
        return;
    }
    r.port = url::defaultPort(r.scheme) == uint16_t(port) ? std::nullopt : std::optional<uint16_t>(uint16_t(port));
    this->store(ctx, r);
}

USVString URL::pathname(JSContext* ctx) {
    return usvFromASCII(ctx, this->record(ctx).pathname());
}

void URL::setPathname(JSContext* ctx, USVString value) {
    url::Record r = this->record(ctx);
    std::optional<std::u16string> u = urlUnits(ctx, value);
    if (r.opaquePath || !u) {
        return;
    }
    // The path state with an override takes "?" and "#" as path code points: encoded before the re-parse.
    std::u16string body;
    for (char16_t c : *u) {
        body += c == '?' ? u"%3F" : c == '#' ? u"%23" : std::u16string(1, c);
    }
    if (body.empty() || (body[0] != '/' && !(r.special() && body[0] == '\\'))) {
        body.insert(0, u"/");
    }
    std::u16string candidate(r.scheme.begin(), r.scheme.end());
    candidate += u":";
    if (r.host) {
        candidate += u"//" + std::u16string(r.host->begin(), r.host->end());
    }
    candidate += body;
    std::optional<url::Record> c = url::parse(candidate, nullptr);
    if (!c || c->opaquePath) {
        return;
    }
    r.path = c->path;
    this->store(ctx, r);
}

USVString URL::search(JSContext* ctx) {
    const url::Record r = this->record(ctx);
    return usvFromASCII(ctx, r.query && !r.query->empty() ? "?" + *r.query : std::string());
}

void URL::setSearch(JSContext* ctx, USVString value) {
    url::Record r = this->record(ctx);
    if (value.length() == 0) {
        r.query.reset();
    } else {
        const String input = value.at(0) == '?' ? value.substring(ctx, 1, value.length()) : String(value);
        r.query = encoded(ctx, input, r.special() ? url::EncodeSet::SpecialQuery : url::EncodeSet::Query);
    }
    this->store(ctx, r);
    this->syncParams(ctx, r);
}

URLSearchParams* URL::searchParams(JSContext*) {
    return static_cast<URLSearchParams*>(payloadOfKnown(m_searchParams.value));
}

USVString URL::hash(JSContext* ctx) {
    const url::Record r = this->record(ctx);
    return usvFromASCII(ctx, r.fragment && !r.fragment->empty() ? "#" + *r.fragment : std::string());
}

void URL::setHash(JSContext* ctx, USVString value) {
    url::Record r = this->record(ctx);
    if (value.length() == 0) {
        r.fragment.reset();
    } else {
        const String input = value.at(0) == '#' ? value.substring(ctx, 1, value.length()) : String(value);
        r.fragment = encoded(ctx, input, url::EncodeSet::Fragment);
    }
    this->store(ctx, r);
}

void URL::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_href.mark(rt, mark);
    m_searchParams.mark(rt, mark);
}

void URL::dispose(JSRuntime* rt) {
    m_href.clear(rt);
    m_searchParams.clear(rt);
}

} // namespace wr
