// URLSearchParams and URL (V5a plan, Tasks 6 and 7; the URL Standard).
#pragma once

#include <optional>
#include <utility>
#include <vector>

#include "Sources/Host/Encoding.h"
#include "Sources/Host/URLParser.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Bindings.h"

namespace wr {

class URL;

class URLSearchParams : public PlatformObject {
public:
    explicit URLSearchParams(JSContext* ctx);
    static Ref<URLSearchParams> construct(JSContext* ctx, std::optional<Value> init);
    uint32_t size(JSContext*) const { return uint32_t(m_list.size()); }
    void append(JSContext* ctx, USVString name, USVString value);
    void delete_(JSContext* ctx, USVString name, std::optional<USVString> value);
    std::optional<USVString> get(JSContext* ctx, USVString name);
    std::vector<USVString> getAll(JSContext* ctx, USVString name);
    bool has(JSContext* ctx, USVString name, std::optional<USVString> value);
    void set(JSContext* ctx, USVString name, USVString value);
    void sort(JSContext* ctx);
    String toString(JSContext* ctx);
    uint32_t iterationLength(JSContext*) const { return uint32_t(m_list.size()); }
    std::pair<USVString, USVString> iterationPair(JSContext* ctx, uint32_t index);

    /// The application/x-www-form-urlencoded parser over `input` (a query without its "?"), replacing the list.
    void parse(JSContext* ctx, const String& input);
    /// The application/x-www-form-urlencoded serializer: ASCII, "" for an empty list.
    std::string serialize(JSContext* ctx) const;
    /// The URL object these params belong to (url.searchParams): its query follows every change of the list.
    void attachURL(JSContext* ctx, URL& url);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    using Entry = std::pair<Text16, Text16>;
    Text16 text(JSContext* ctx, const String& s) const;
    /// The URL Standard's "update steps": the URL's query becomes the serialization (null when empty).
    void update(JSContext* ctx);

    Vector<Entry> m_list;
    Held m_url;
};

/// The URL Standard's URL (V5a plan, Task 7). The record lives as its serialization, a JS string in the JS heap, and is
/// parsed again for every read; the setters splice their component into the record and re-parse where the standard's
/// state override would (Ruling).
class URL : public PlatformObject {
public:
    URL() = default;
    static Ref<URL> construct(JSContext* ctx, USVString url, std::optional<USVString> base);
    static std::optional<Ref<URL>> parse(JSContext* ctx, USVString url, std::optional<USVString> base);
    static bool canParse(JSContext* ctx, USVString url, std::optional<USVString> base);
    USVString href(JSContext* ctx);
    void setHref(JSContext* ctx, USVString value);
    USVString origin(JSContext* ctx);
    USVString protocol(JSContext* ctx);
    void setProtocol(JSContext* ctx, USVString value);
    USVString username(JSContext* ctx);
    void setUsername(JSContext* ctx, USVString value);
    USVString password(JSContext* ctx);
    void setPassword(JSContext* ctx, USVString value);
    USVString host(JSContext* ctx);
    void setHost(JSContext* ctx, USVString value);
    USVString hostname(JSContext* ctx);
    void setHostname(JSContext* ctx, USVString value);
    USVString port(JSContext* ctx);
    void setPort(JSContext* ctx, USVString value);
    USVString pathname(JSContext* ctx);
    void setPathname(JSContext* ctx, USVString value);
    USVString search(JSContext* ctx);
    void setSearch(JSContext* ctx, USVString value);
    URLSearchParams* searchParams(JSContext* ctx);
    USVString hash(JSContext* ctx);
    void setHash(JSContext* ctx, USVString value);
    USVString toJSON(JSContext* ctx) { return this->href(ctx); }
    static String createObjectURL(JSContext* ctx, Value) { return String::fromUTF8(ctx, ""); }
    static void revokeObjectURL(JSContext*, String) {}

    /// The params' update steps: the query becomes `serialization`, or null when it is empty.
    void paramsChanged(JSContext* ctx, const std::string& serialization);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    static Ref<URL> make(JSContext* ctx, const url::Record& record);
    url::Record record(JSContext* ctx) const;
    void store(JSContext* ctx, const url::Record& record);
    /// The search params' list from the record's query.
    void syncParams(JSContext* ctx, const url::Record& record);

    Held m_href;
    Held m_searchParams;
};

} // namespace wr
