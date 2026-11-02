#include "Tests/WPT/WPTSupport.h"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <map>
#include <set>
#include <sstream>
#include <tuple>

namespace wr_wpt {

namespace fs = std::filesystem;

namespace {

constexpr size_t npos = std::string_view::npos;

bool startsWith(std::string_view s, std::string_view prefix) {
    return s.size() >= prefix.size() && s.compare(0, prefix.size(), prefix) == 0;
}

bool endsWith(std::string_view s, std::string_view suffix) {
    return s.size() >= suffix.size() && s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0;
}

std::string_view trim(std::string_view s) {
    constexpr std::string_view kSpace = " \t\n\r\f";
    size_t b = s.find_first_not_of(kSpace);
    if (b == npos) {
        return {};
    }
    return s.substr(b, s.find_last_not_of(kSpace) - b + 1);
}

std::string lower(std::string_view s) {
    std::string out(s);
    for (char& c : out) {
        c = char(std::tolower(static_cast<unsigned char>(c)));
    }
    return out;
}

bool hasScheme(std::string_view ref) {
    if (ref.empty() || !std::isalpha(static_cast<unsigned char>(ref[0]))) {
        return false;
    }
    for (size_t i = 1; i < ref.size(); i++) {
        unsigned char c = static_cast<unsigned char>(ref[i]);
        if (c == ':') {
            return true;
        }
        if (!std::isalnum(c) && c != '+' && c != '-' && c != '.') {
            return false;
        }
    }
    return false;
}

/// `path` (starting with '/') with "." and ".." segments removed, as the URL parser removes them; nullopt when ".."
/// would climb above the root.
std::optional<std::string> normalizePath(std::string_view path) {
    std::vector<std::string_view> segments;
    std::string_view rest = path.substr(1);
    bool endsWithDirectory = false;
    while (true) {
        size_t slash = rest.find('/');
        std::string_view segment = rest.substr(0, slash);
        bool last = slash == npos;
        if (segment == "..") {
            if (segments.empty()) {
                return std::nullopt;
            }
            segments.pop_back();
            endsWithDirectory = last;
        } else if (segment == ".") {
            endsWithDirectory = last;
        } else {
            segments.push_back(segment);
            endsWithDirectory = false;
        }
        if (last) {
            break;
        }
        rest = rest.substr(slash + 1);
    }
    std::string out;
    for (std::string_view segment : segments) {
        out += '/';
        out += segment;
    }
    if (out.empty() || endsWithDirectory) {
        out += '/';
    }
    return out;
}

int hexValue(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    c = char(std::tolower(static_cast<unsigned char>(c)));
    return c >= 'a' && c <= 'f' ? c - 'a' + 10 : -1;
}

std::string percentDecode(std::string_view s) {
    std::string out;
    for (size_t i = 0; i < s.size(); i++) {
        if (s[i] == '%' && i + 2 < s.size() && hexValue(s[i + 1]) >= 0 && hexValue(s[i + 2]) >= 0) {
            out += char(hexValue(s[i + 1]) * 16 + hexValue(s[i + 2]));
            i += 2;
        } else {
            out += s[i];
        }
    }
    return out;
}

std::string escapeHTMLText(std::string_view s) {
    std::string out;
    for (char c : s) {
        out += c == '&' ? "&amp;" : c == '<' ? "&lt;" : c == '>' ? "&gt;" : std::string(1, c);
    }
    return out;
}

std::string escapeHTMLAttribute(std::string_view s) {
    std::string out;
    for (char c : s) {
        out += c == '&' ? "&amp;" : c == '"' ? "&quot;" : std::string(1, c);
    }
    return out;
}

/// The value of attribute `name` (ASCII case-insensitive) in a tag's attribute text, or "".
std::string attributeValue(std::string_view tag, std::string_view name) {
    size_t i = 0;
    while (i < tag.size()) {
        while (i < tag.size() && (std::isspace(static_cast<unsigned char>(tag[i])) || tag[i] == '/')) {
            i++;
        }
        size_t nameStart = i;
        while (i < tag.size() && !std::isspace(static_cast<unsigned char>(tag[i])) && tag[i] != '=' && tag[i] != '/') {
            i++;
        }
        std::string attribute = lower(tag.substr(nameStart, i - nameStart));
        while (i < tag.size() && std::isspace(static_cast<unsigned char>(tag[i]))) {
            i++;
        }
        std::string value;
        if (i < tag.size() && tag[i] == '=') {
            i++;
            while (i < tag.size() && std::isspace(static_cast<unsigned char>(tag[i]))) {
                i++;
            }
            if (i < tag.size() && (tag[i] == '"' || tag[i] == '\'')) {
                char quote = tag[i++];
                size_t end = tag.find(quote, i);
                value = std::string(tag.substr(i, end == npos ? npos : end - i));
                i = end == npos ? tag.size() : end + 1;
            } else {
                size_t start = i;
                while (i < tag.size() && !std::isspace(static_cast<unsigned char>(tag[i]))) {
                    i++;
                }
                value = std::string(tag.substr(start, i - start));
            }
        }
        if (!attribute.empty() && attribute == name) {
            return value;
        }
        if (attribute.empty() && i == nameStart) {
            i++;
        }
    }
    return {};
}

/// (name, content) of every <meta> tag, in order.
std::vector<std::pair<std::string, std::string>> metaTags(std::string_view html) {
    std::vector<std::pair<std::string, std::string>> out;
    std::string lowered = lower(html);
    size_t pos = 0;
    while ((pos = lowered.find("<meta", pos)) != std::string::npos) {
        size_t end = lowered.find('>', pos);
        if (end == std::string::npos) {
            break;
        }
        std::string_view tag = html.substr(pos + 5, end - pos - 5);
        out.emplace_back(lower(trim(attributeValue(tag, "name"))), std::string(trim(attributeValue(tag, "content"))));
        pos = end;
    }
    return out;
}

const std::set<std::string>& subtestStatuses() {
    static const std::set<std::string> all = {"PASS", "FAIL", "TIMEOUT", "NOTRUN", "PRECONDITION_FAILED"};
    return all;
}

const std::set<std::string>& harnessStatuses() {
    static const std::set<std::string> all = {"OK", "ERROR", "TIMEOUT", "PRECONDITION_FAILED", "STOPPED", "NOCOMPLETE"};
    return all;
}

const std::set<std::string>& skipReasons() {
    static const std::set<std::string> all = {"iframe", "second-document", "testdriver", "server", "out-of-IDL", "bug", "virtual-clock"};
    return all;
}

std::vector<std::string_view> splitTabs(std::string_view line) {
    std::vector<std::string_view> fields;
    size_t start = 0;
    while (true) {
        size_t tab = line.find('\t', start);
        fields.push_back(line.substr(start, tab == npos ? npos : tab - start));
        if (tab == npos) {
            return fields;
        }
        start = tab + 1;
    }
}

template <class F>
void forEachLine(std::string_view text, F&& f) {
    size_t pos = 0;
    int number = 0;
    while (pos < text.size()) {
        size_t end = text.find('\n', pos);
        std::string_view line = text.substr(pos, end == npos ? npos : end - pos);
        if (!line.empty() && line.back() == '\r') {
            line.remove_suffix(1);
        }
        pos = end == npos ? text.size() : end + 1;
        if (!f(++number, line)) {
            return;
        }
    }
}

std::tuple<std::string, int, std::string> sortKey(const Record& r) {
    return {r.test, r.harness ? 0 : 1, r.subtest};
}

/// Whether `path` (pathOf's) is in what //third-party/wpt:TestFiles declares, so the loader reads exactly the
/// test's declared inputs although its root is the real vendored directory (WPTRunner.cpp's findRoot).
bool isDeclaredPath(std::string_view path) {
    for (std::string_view dir : {"/resources/", "/common/", "/dom/", "/html/", "/css/", "/web-animations/"}) {
        if (startsWith(path, dir)) {
            return true;
        }
    }
    return path == "/LICENSE.md";
}

} // namespace

std::optional<std::string> pathOf(std::string_view url) {
    if (!startsWith(url, kOrigin)) {
        return std::nullopt;
    }
    std::string_view rest = url.substr(kOrigin.size());
    if (!rest.empty() && rest[0] != '/' && rest[0] != '?' && rest[0] != '#') {
        return std::nullopt;
    }
    std::string_view path = rest.substr(0, rest.find_first_of("?#"));
    std::string decoded = path.empty() ? std::string("/") : percentDecode(path);
    if (decoded.find('\0') != std::string::npos) {
        return std::nullopt;
    }
    std::string_view segments = std::string_view(decoded).substr(1);
    while (true) {
        size_t slash = segments.find('/');
        std::string_view segment = segments.substr(0, slash);
        if (segment == "." || segment == "..") {
            return std::nullopt;
        }
        if (slash == npos) {
            break;
        }
        segments = segments.substr(slash + 1);
    }
    return decoded;
}

std::optional<std::string> resolveURL(std::string_view base, std::string_view ref) {
    std::optional<std::string> basePath = pathOf(base);
    if (!basePath) {
        return std::nullopt;
    }
    std::string r(trim(ref));
    std::replace(r.begin(), r.end(), '\\', '/');
    std::string_view baseWithoutFragment = base.substr(0, base.find('#'));
    if (r.empty()) {
        return std::string(baseWithoutFragment);
    }
    if (r[0] == '#') {
        return std::string(baseWithoutFragment) + r;
    }
    if (r[0] == '?') {
        return std::string(kOrigin) + *basePath + r;
    }
    std::string path;
    if (hasScheme(r) || startsWith(r, "//")) {
        std::string_view authority = startsWith(r, "//") ? std::string_view("//web-platform.test:8000") : kOrigin;
        if (!startsWith(r, authority)) {
            return std::nullopt;
        }
        std::string_view after = std::string_view(r).substr(authority.size());
        if (!after.empty() && after[0] != '/' && after[0] != '?' && after[0] != '#') {
            return std::nullopt;
        }
        path = !after.empty() && after[0] == '/' ? std::string(after) : "/" + std::string(after);
    } else if (r[0] == '/') {
        path = r;
    } else {
        path = basePath->substr(0, basePath->rfind('/') + 1) + r;
    }
    size_t cut = path.find_first_of("?#");
    std::string suffix = cut == std::string::npos ? std::string() : path.substr(cut);
    std::optional<std::string> normalized = normalizePath(std::string_view(path).substr(0, cut));
    if (!normalized) {
        return std::nullopt;
    }
    return std::string(kOrigin) + *normalized + suffix;
}

ScriptMeta parseScriptMeta(std::string_view source) {
    ScriptMeta meta;
    forEachLine(source, [&](int, std::string_view line) {
        line = trim(line);
        if (!startsWith(line, "//")) {
            return false;
        }
        std::string_view body = trim(line.substr(2));
        if (!startsWith(body, "META:")) {
            return true;
        }
        body = trim(body.substr(5));
        size_t eq = body.find('=');
        if (eq == npos) {
            return true;
        }
        std::string key(trim(body.substr(0, eq)));
        std::string value(trim(body.substr(eq + 1)));
        if (key == "script") {
            meta.scripts.push_back(value);
        } else if (key == "variant") {
            meta.variants.push_back(value);
        } else if (key == "title") {
            meta.title = value;
        } else if (key == "timeout") {
            meta.longTimeout = value == "long";
        } else if (key == "global") {
            meta.window = false;
            std::string_view tokens = value;
            while (!tokens.empty()) {
                size_t comma = tokens.find(',');
                std::string_view token = trim(tokens.substr(0, comma));
                if (token == "window" || token == "default") {
                    meta.window = true;
                }
                tokens = comma == npos ? std::string_view() : tokens.substr(comma + 1);
            }
        }
        return true;
    });
    return meta;
}

bool isTestharnessPage(std::string_view html) {
    return html.find("/resources/testharness.js") != npos;
}

bool htmlHasLongTimeout(std::string_view html) {
    for (const auto& [name, content] : metaTags(html)) {
        if (name == "timeout" && lower(content) == "long") {
            return true;
        }
    }
    return false;
}

std::vector<std::string> htmlVariants(std::string_view html) {
    std::vector<std::string> variants;
    for (const auto& [name, content] : metaTags(html)) {
        if (name == "variant") {
            variants.push_back(content);
        }
    }
    return variants;
}

std::string synthesizePage(std::string_view scriptPath, const ScriptMeta& meta, bool any) {
    std::string page = "<!doctype html>\n<meta charset=utf-8>\n";
    if (meta.longTimeout) {
        page += "<meta name=\"timeout\" content=\"long\">\n";
    }
    if (!meta.title.empty()) {
        page += "<title>" + escapeHTMLText(meta.title) + "</title>\n";
    }
    if (any) {
        page += "<script>\nself.GLOBAL = {\n  isWindow: function() { return true; },\n  isWorker: function() { return false; },\n"
                "  isShadowRealm: function() { return false; },\n};\n</script>\n";
    }
    page += "<script src=\"/resources/testharness.js\"></script>\n<script src=\"/resources/testharnessreport.js\"></script>\n";
    for (const std::string& script : meta.scripts) {
        page += "<script src=\"" + escapeHTMLAttribute(script) + "\"></script>\n";
    }
    page += "<div id=log></div>\n<script src=\"" + escapeHTMLAttribute(scriptPath) + "\"></script>\n";
    return page;
}

bool parseSkipList(std::string_view text, std::vector<SkipEntry>* out, std::string* error) {
    out->clear();
    bool ok = true;
    forEachLine(text, [&](int number, std::string_view line) {
        if (line.empty() || line[0] == '#') {
            return true;
        }
        std::vector<std::string_view> fields = splitTabs(line);
        if (fields.size() != 3) {
            *error = "wpt-skip.txt:" + std::to_string(number) + ": expected three tab-separated fields";
            ok = false;
            return false;
        }
        if (!skipReasons().count(std::string(fields[1]))) {
            *error = "wpt-skip.txt:" + std::to_string(number) + ": unknown reason '" + std::string(fields[1]) + "'";
            ok = false;
            return false;
        }
        out->push_back({std::string(fields[0]), std::string(fields[1]), std::string(fields[2])});
        return true;
    });
    return ok;
}

bool isSkipped(const std::vector<SkipEntry>& skips, std::string_view test) {
    for (const SkipEntry& skip : skips) {
        if (skip.test == test) {
            return true;
        }
        bool covered = startsWith(test, skip.test) && test.size() > skip.test.size() && (test[skip.test.size()] == '?' || test[skip.test.size()] == '#');
        if (covered && skip.test.find_first_of("?#") == std::string::npos) {
            return true;
        }
    }
    return false;
}

std::vector<Page> discoverPages(const std::string& root, const std::vector<std::string>& dirs, const std::vector<SkipEntry>& skips) {
    static const std::set<std::string> kNotTests = {"resources", "support", "crashtests", "tools"};
    std::vector<Page> pages;
    auto add = [&](std::string test, std::string url, std::string html, bool longTimeout) {
        if (!isSkipped(skips, test)) {
            pages.push_back({std::move(test), std::move(url), std::move(html), longTimeout});
        }
    };
    for (const std::string& dir : dirs) {
        std::error_code ec;
        fs::recursive_directory_iterator it(root + "/" + dir, ec), end;
        for (; !ec && it != end; it.increment(ec)) {
            const fs::directory_entry& entry = *it;
            std::string name = entry.path().filename().string();
            if (entry.is_symlink()) {
                continue;
            }
            if (entry.is_directory()) {
                if (kNotTests.count(name)) {
                    it.disable_recursion_pending();
                }
                continue;
            }
            if (!entry.is_regular_file() || name.find("-manual.") != std::string::npos) {
                continue;
            }
            std::string rel = fs::relative(entry.path(), root).generic_string();
            bool any = endsWith(name, ".any.js");
            bool window = endsWith(name, ".window.js");
            if (any || window) {
                std::optional<std::string> source = readFile(entry.path().string());
                if (!source) {
                    continue;
                }
                ScriptMeta meta = parseScriptMeta(*source);
                if (!meta.window) {
                    continue;
                }
                std::string html = synthesizePage("/" + rel, meta, any);
                std::string pagePath = rel.substr(0, rel.size() - 3) + ".html";
                std::vector<std::string> variants = meta.variants.empty() ? std::vector<std::string>{""} : meta.variants;
                for (const std::string& variant : variants) {
                    add(rel + variant, std::string(kOrigin) + "/" + pagePath + variant, html, meta.longTimeout);
                }
            } else if (endsWith(name, ".html") || endsWith(name, ".htm") || endsWith(name, ".xhtml") || endsWith(name, ".xht")) {
                std::optional<std::string> html = readFile(entry.path().string());
                if (!html || !isTestharnessPage(*html)) {
                    continue;
                }
                std::vector<std::string> variants = htmlVariants(*html);
                if (variants.empty()) {
                    variants.push_back("");
                }
                bool longTimeout = htmlHasLongTimeout(*html);
                for (const std::string& variant : variants) {
                    add(rel + variant, std::string(kOrigin) + "/" + rel + variant, *html, longTimeout);
                }
            }
        }
    }
    std::sort(pages.begin(), pages.end(), [](const Page& a, const Page& b) { return a.test < b.test; });
    return pages;
}

std::string subtestStatusName(int status) {
    static const char* const kNames[] = {"PASS", "FAIL", "TIMEOUT", "NOTRUN", "PRECONDITION_FAILED"};
    return status >= 0 && status < 5 ? kNames[status] : "FAIL";
}

std::string harnessStatusName(int status) {
    static const char* const kNames[] = {"OK", "ERROR", "TIMEOUT", "PRECONDITION_FAILED"};
    return status >= 0 && status < 4 ? kNames[status] : "ERROR";
}

std::string escapeField(std::string_view s) {
    std::string out;
    if (!s.empty() && s[0] == '#') {
        out += '\\';  // a field starting "#" would read as the harness token
    }
    for (char c : s) {
        switch (c) {
        case '\\': out += "\\\\"; break;
        case '\t': out += "\\t"; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        default: out += c;
        }
    }
    return out;
}

std::string unescapeField(std::string_view s) {
    std::string out;
    for (size_t i = 0; i < s.size(); i++) {
        if (s[i] != '\\' || i + 1 == s.size()) {
            out += s[i];
            continue;
        }
        char next = s[++i];
        out += next == 't' ? '\t' : next == 'n' ? '\n' : next == 'r' ? '\r' : next;
    }
    return out;
}

std::string formatExpectations(std::vector<Record> records) {
    std::sort(records.begin(), records.end(), [](const Record& a, const Record& b) { return sortKey(a) < sortKey(b); });
    std::string text =
        "# WidgetRuntime's WPT expectations (M1b plan, Task 17). Written by `WidgetRuntimeWPTTests --update`; edit by\n"
        "# hand only to lower a result on purpose, then update with --allow-regressions. One record per line, three\n"
        "# tab-separated fields: <test> <subtest> <status>.\n"
        "# <test>     the page's source path under third-party/wpt, plus its variant (\"dom/nodes/Node-cloneNode.html\",\n"
        "#            \"dom/events/Event-constructors.any.js\", \"dom/x.window.js?1-10\").\n"
        "# <subtest>  the subtest's name, with \\ tab newline and carriage return written \\\\ \\t \\n \\r and a leading # as\n"
        "#            \\#; a repeated name gets \" (2)\", \" (3)\", ...; or #harness for the file's harness status.\n"
        "# <status>   subtests: PASS FAIL TIMEOUT NOTRUN PRECONDITION_FAILED. #harness: OK ERROR TIMEOUT\n"
        "#            PRECONDITION_FAILED, or the runner's STOPPED (the runtime latched a stop) and NOCOMPLETE (no\n"
        "#            completion before the runner's virtual-time limit).\n"
        "# Records sort by <test>, then #harness first, then <subtest>, in byte order.\n";
    for (const Record& r : records) {
        text += escapeField(r.test) + "\t" + (r.harness ? std::string(kHarness) : escapeField(r.subtest)) + "\t" + r.status + "\n";
    }
    return text;
}

bool parseExpectations(std::string_view text, std::vector<Record>* out, std::string* error) {
    out->clear();
    std::set<std::tuple<std::string, int, std::string>> seen;
    bool ok = true;
    forEachLine(text, [&](int number, std::string_view line) {
        if (line.empty() || line[0] == '#') {
            return true;
        }
        auto fail = [&](const std::string& why) {
            *error = "wpt-expectations.txt:" + std::to_string(number) + ": " + why;
            ok = false;
            return false;
        };
        std::vector<std::string_view> fields = splitTabs(line);
        if (fields.size() != 3) {
            return fail("expected three tab-separated fields");
        }
        Record r;
        r.test = unescapeField(fields[0]);
        r.harness = fields[1] == kHarness;
        r.subtest = r.harness ? std::string() : unescapeField(fields[1]);
        r.status = std::string(fields[2]);
        if (!(r.harness ? harnessStatuses() : subtestStatuses()).count(r.status)) {
            return fail("unknown status '" + r.status + "'");
        }
        if (!seen.insert(sortKey(r)).second) {
            return fail("a repeated record");
        }
        out->push_back(std::move(r));
        return true;
    });
    return ok;
}

int rank(const Record& r) {
    if (r.status == "PASS" || r.status == "OK") {
        return 2;
    }
    if (r.status == "FAIL" || r.status == "PRECONDITION_FAILED" || r.status == "ERROR") {
        return 1;
    }
    return 0;
}

Comparison compare(const std::vector<Record>& expected, const std::vector<Record>& actual,
                   const std::function<bool(std::string_view test)>& inScope) {
    std::map<std::tuple<std::string, int, std::string>, const Record*> want, got;
    for (const Record& r : expected) {
        if (inScope(r.test)) {
            want[sortKey(r)] = &r;
        }
    }
    for (const Record& r : actual) {
        got[sortKey(r)] = &r;
    }
    auto label = [](const Record& r) { return r.test + " | " + (r.harness ? std::string(kHarness) : r.subtest); };
    Comparison c;
    for (const auto& [key, w] : want) {
        auto it = got.find(key);
        if (it == got.end()) {
            c.regressions.push_back(label(*w) + ": expected " + w->status + ", not reported");
            continue;
        }
        const Record* g = it->second;
        if (g->status == w->status) {
            continue;
        }
        std::string line = label(*w) + ": expected " + w->status + ", got " + g->status;
        int a = rank(*g), b = rank(*w);
        (a < b ? c.regressions : a > b ? c.improvements : c.changes).push_back(line);
    }
    for (const auto& [key, g] : got) {
        if (!want.count(key)) {
            (rank(*g) == 2 ? c.improvements : c.changes).push_back(label(*g) + ": new, " + g->status);
        }
    }
    return c;
}

std::optional<std::string> readFile(const std::string& path) {
    std::error_code ec;
    fs::file_status status = fs::symlink_status(path, ec);
    if (ec || status.type() != fs::file_type::regular) {
        return std::nullopt;
    }
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        return std::nullopt;
    }
    std::ostringstream s;
    s << in.rdbuf();
    return s.str();
}

WPTLoader::WPTLoader(std::string root, std::string reportShim) : m_root(std::move(root)), m_reportShim(std::move(reportShim)) {
    std::error_code ec;
    m_canonicalRoot = fs::weakly_canonical(m_root, ec).string();
}

std::optional<wr::ScriptSource> WPTLoader::load(std::string_view url) {
    std::optional<std::string> absolute = resolveURL(m_pageURL, url);
    std::optional<std::string> path = absolute ? pathOf(*absolute) : std::nullopt;
    if (!path || !isDeclaredPath(*path)) {
        m_refused.emplace_back(url);
        return std::nullopt;
    }
    if (*path == "/resources/testharnessreport.js") {
        return wr::ScriptSource{m_reportShim, *absolute};
    }
    std::string file = m_root + *path;
    std::error_code ec;
    std::string canonical = fs::weakly_canonical(file, ec).string();
    std::optional<std::string> text;
    if (!ec && startsWith(canonical, m_canonicalRoot + "/")) {
        text = readFile(file);
    }
    if (!text) {
        m_refused.emplace_back(url);
        return std::nullopt;
    }
    return wr::ScriptSource{std::move(*text), *absolute};
}

} // namespace wr_wpt
