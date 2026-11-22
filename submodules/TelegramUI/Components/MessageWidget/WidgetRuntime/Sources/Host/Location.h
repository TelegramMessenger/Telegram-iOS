// A minimal, read-only Location over the document's URL. The parts are split without a URL parser (M2 brings the
// WHATWG one): enough for about:srcdoc and the WPT runner's http: URLs.
#pragma once

#include <string>
#include <string_view>

#include "Generated/Bindings.h"
#include "Sources/Support/Bindings.h"

namespace wr {

/// An absolute URL's parts as Location reports them: the scheme, an authority after "//" (host, hostname, port, with a
/// special scheme's default port dropped), the path, the query and the fragment ("" when empty), and the origin
/// ("null" for a scheme without one).
struct URLParts {
    std::string protocol;
    std::string host;
    std::string hostname;
    std::string port;
    std::string pathname;
    std::string search;
    std::string hash;
    std::string origin;
};

URLParts splitURL(std::string_view url);

class Location : public PlatformObject {
public:
    Location() = default;
    String href(JSContext* ctx);
    String origin(JSContext* ctx);
    String protocol(JSContext* ctx);
    String host(JSContext* ctx);
    String hostname(JSContext* ctx);
    String port(JSContext* ctx);
    String pathname(JSContext* ctx);
    String search(JSContext* ctx);
    String hash(JSContext* ctx);

private:
    /// The document's URL, split.
    URLParts parts(JSContext* ctx);
};

} // namespace wr
