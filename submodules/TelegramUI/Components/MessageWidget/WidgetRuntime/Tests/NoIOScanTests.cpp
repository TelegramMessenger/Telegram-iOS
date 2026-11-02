// No I/O in the runtime (M1c plan, Task 11; spec hard rule: nothing in WidgetRuntime may open a URL, a file or a socket,
// and a widget can never cause a network request from the device). Every source compiled into :WidgetRuntime (its own
// Sources/**, and the quickjs-ng, gumbo and litehtml fork sources it links) is read with its comments and string literals
// stripped, and fails on any call or type of the identifiers below. A hit fails unless the allowlist lists it, with the
// file, the line and the reason it is not reachable or not I/O. WR_SCAN_FILES lists the files (the Bazel target's data).
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include "Tests/SourceScan.h"
#include "Tests/wr_test.h"

namespace {

const char* const kForbidden[] = {
    "fopen",  "freopen",       "fdopen",   "open",     "openat",  "socket",  "connect",  "getaddrinfo", "gethostbyname",
    "dlopen", "popen",         "system",   "NSURL",    "CFURL",   "curl_easy_init", "ifstream", "ofstream", "fstream",
    "fread",  "fwrite",        "opendir",  "readdir",  "stat",    "lstat",   "unlink",   "remove",      "rename",
    "mmap",   "send",          "recv",     "sendto",   "recvfrom", "bind",   "listen",   "accept",      "syscall",
    "NSURLSession", "NSURLConnection", "CFReadStreamCreateForHTTPRequest", "CFStreamCreatePairWithSocketToHost",
    "filebuf",
};

/// Names that are types: a hit wherever they appear (outside a member access), call or not.
const char* const kTypes[] = {"ifstream", "ofstream", "fstream", "filebuf", "NSURL", "CFURL", "NSURLSession", "NSURLConnection"};

struct Allowed {
    const char* file;    // a suffix of the file's path
    const char* line;    // the hit's line, trimmed, as in the source (comments and all)
    const char* reason;
};

// Each entry is a hit that is not I/O the runtime performs. Start empty; add only with a reason that names the line.
const std::vector<Allowed> kAllowed = {
};

using wr_test::identChar;
using wr_test::stripped;

struct Hit {
    size_t line;
    std::string name;
};

/// The number of top-level arguments of the call whose `(` is at `open` (0 for `()`), to the matching `)`.
size_t argumentCount(const std::string& code, size_t open) {
    int depth = 0;
    size_t commas = 0;
    bool any = false;
    for (size_t k = open; k < code.size(); k++) {
        const char c = code[k];
        if (c == '(' || c == '[' || c == '{') {
            depth++;
        } else if (c == ')' || c == ']' || c == '}') {
            if (--depth == 0) {
                return any ? commas + 1 : 0;
            }
        } else if (c == ',' && depth == 1) {
            commas++;
        } else if (depth >= 1 && !(c == ' ' || c == '\n' || c == '\t' || c == '\r')) {
            any = any || depth >= 1;
        }
    }
    return commas + 1;
}

/// The forbidden identifiers in stripped source `code`: each when followed by `(` (any whitespace between, newlines
/// included), when it is a type, or when it is used as a value (`&open`, `(void)open`, `f(open, x)`, `f(x, open)`). Not a
/// member access (`x.open(`, `x->connect(`), a name qualified by a namespace other than std (`Foo::open`, `wr::send`), a part of
/// a longer identifier, or a declaration (`void open() {`: a non-keyword identifier directly before the name is a return
/// type). `std::filesystem` is a hit wherever it appears.
std::vector<Hit> hitsIn(const std::string& code) {
    std::vector<Hit> hits;
    size_t line = 1;
    const size_t n = code.size();
    auto space = [](char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; };
    static const char* const kStatementWords[] = {"return", "else", "do", "case", "throw", "co_return", "co_await",
                                                  "co_yield", "sizeof", "new", "delete", "and", "or", "not"};
    for (size_t i = 0; i < n;) {
        if (code[i] == '\n') {
            line++;
            i++;
            continue;
        }
        if (!(std::isalpha((unsigned char)code[i]) || code[i] == '_')) {
            i++;
            continue;
        }
        size_t end = i;
        while (end < n && identChar(code[end])) {
            end++;
        }
        const std::string word = code.substr(i, end - i);
        bool forbidden = false, isType = false;
        for (const char* name : kForbidden) {
            forbidden = forbidden || word == name;
        }
        for (const char* name : kTypes) {
            isType = isType || word == name;
        }
        // What comes before (past whitespace and newlines) and after.
        size_t before = i;
        while (before > 0 && space(code[before - 1])) {
            before--;
        }
        size_t after = end;
        while (after < n && space(code[after])) {
            after++;
        }
        if (word == "filesystem" && before >= 5 && code.compare(before - 5, 5, "std::") == 0) {
            hits.push_back({line, "std::filesystem"});
        }
        if (forbidden) {
            const bool member = (before >= 1 && code[before - 1] == '.') || (before >= 2 && code[before - 2] == '-' && code[before - 1] == '>');
            // `Foo::open`: a qualifier other than std (or the global `::open`, which is a hit) names another function.
            bool otherScope = false, otherScopeIsStd = false, continue_ = false;
            if (before >= 2 && code[before - 1] == ':' && code[before - 2] == ':') {
                size_t q = before - 2;
                while (q > 0 && space(code[q - 1])) {
                    q--;
                }
                size_t qs = q;
                while (qs > 0 && identChar(code[qs - 1])) {
                    qs--;
                }
                const std::string qualifier = code.substr(qs, q - qs);
                otherScope = !qualifier.empty() && qualifier != "std";
                otherScopeIsStd = qualifier == "std";
                before = qs;
                while (before > 0 && space(code[before - 1])) {
                    before--;
                }
            }
            const bool call = after < n && code[after] == '(';
            const char prev = before > 0 ? code[before - 1] : ' ';
            const char next = after < n ? code[after] : ' ';
            bool declaration = false, structStat = false;
            if (!isType && identChar(prev)) {
                size_t ws = before;
                while (ws > 0 && identChar(code[ws - 1])) {
                    ws--;
                }
                const std::string previous = code.substr(ws, before - ws);
                bool statement = false;
                for (const char* keyword : kStatementWords) {
                    statement = statement || previous == keyword;
                }
                // `struct stat st;` names the type: not a declaration of a function called stat.
                structStat = previous == "struct" && word == "stat";
                declaration = !statement && !structStat;
            }
            // A value: its address taken (not a reference declaration: `Type& open`), cast away (`(void)open`), or passed as
            // an argument (`use(open)`, `use(x, open)`; not the condition of an if/while/for/switch).
            bool value = false;
            if (prev == '&') {
                size_t b = before - 1;
                while (b > 0 && space(code[b - 1])) {
                    b--;
                }
                const char pp = b > 0 ? code[b - 1] : ' ';
                value = !(identChar(pp) || pp == '>' || pp == '*' || pp == '&' || pp == ')');
                value = value || pp == ')';
            } else if (prev == ')') {
                value = true;
            } else if ((prev == '(' || prev == ',') && (next == ',' || next == ')')) {
                value = true;
                if (prev == '(') {
                    size_t b = before - 1;
                    while (b > 0 && space(code[b - 1])) {
                        b--;
                    }
                    size_t ws = b;
                    while (ws > 0 && identChar(code[ws - 1])) {
                        ws--;
                    }
                    const std::string head = code.substr(ws, b - ws);
                    for (const char* keyword : {"if", "while", "for", "switch", "return", "sizeof", "catch", "decltype"}) {
                        value = value && head != keyword;
                    }
                }
            }
            // std::bind and the std::remove algorithm are not the socket call and the file removal; `remove` is the file
            // removal only with its one path argument (the algorithm takes a range and a value).
            if (word == "bind" && otherScopeIsStd) {
                continue_ = true;
            }
            if (word == "remove" && !(value || isType) && !(call && argumentCount(code, after) == 1)) {
                continue_ = true;
            }
            if (continue_) {
                i = end;
                continue;
            }
            if (!member && !otherScope && !declaration && (call || isType || structStat || value)) {
                hits.push_back({line, word});
            }
        }
        i = end;
    }
    return hits;
}

std::string lineOf(const std::string& text, size_t line) {
    size_t at = 0;
    for (size_t l = 1; l < line; l++) {
        at = text.find('\n', at);
        if (at == std::string::npos) {
            return "";
        }
        at++;
    }
    size_t end = text.find('\n', at);
    std::string s = text.substr(at, end == std::string::npos ? std::string::npos : end - at);
    const size_t b = s.find_first_not_of(" \t");
    const size_t e = s.find_last_not_of(" \t\r");
    return b == std::string::npos ? "" : s.substr(b, e - b + 1);
}

bool endsWith(const std::string& s, const std::string& suffix) {
    return s.size() >= suffix.size() && s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0;
}

bool sourceFile(const std::string& path) {
    for (const char* ext : {".c", ".cc", ".cpp", ".h", ".hpp", ".inc", ".m", ".mm"}) {
        if (endsWith(path, ext)) {
            return true;
        }
    }
    return false;
}

} // namespace

WR_TEST(testScannerSeesWhatItShould) {
    // The scanner's own canary: calls, types and values are hits; comments, strings, member calls, other scopes, longer
    // names and declarations are not.
    struct Case {
        const char* code;
        std::vector<std::string> hits;   // "line:name"
    };
    const Case cases[] = {
        {"int f() { FILE* a = fopen(\"fopen(\", \"r\"); // fopen(x)\n"
         "  /* socket(1,2,3) */ std::ifstream in; x.open(1); y->connect(2); reopen(3); int fd = open (p, 0);\n"
         "  const char* s = R\"x(system(\"ls\"))x\"; return system(s) + 1'000; }\n"
         "struct W { void open() {} int socket(int); };\n",
         {"1:fopen", "2:ifstream", "2:open", "3:system"}},
        {"void f() { open\n(p, 0); }\n", {"1:open"}},
        {"const char* a = u8R\"(/*)\"; fopen(p, m); /* c */\n", {"1:fopen"}},
        {"char a = u8'a'; fopen(p, m); char b = L'x'; auto c = 0x1'F; open(p, 0);\n", {"1:fopen", "1:open"}},
        {"auto p = &open; auto q = &fopen;\n", {"1:open", "1:fopen"}},
        {"void g() { (void)open; use(fopen); use(x, open); }\n", {"1:open", "1:fopen", "1:open"}},
        {"int fd = ::open(p, 0); Foo::open(1); std::remove(p);\n", {"1:open", "1:remove"}},
        {"int open(int);\nvoid h() {\n  open(p, 0);\n}\n", {"3:open"}},
        {"namespace fs = std::filesystem; struct stat st; int stat(const char*, struct stat*);\n", {"1:std::filesystem", "1:stat", "1:stat"}},
        {"void r() { std::remove(p); std::remove(a.begin(), a.end(), x); remove(tokens, 0); auto f = std::bind(g, 1); bind(s, a, n); }\n",
         {"1:remove", "1:bind"}},
        {"void k(int open, bool send) {}\n", {}},
    };
    for (const Case& c : cases) {
        std::vector<std::string> names;
        for (const Hit& hit : hitsIn(stripped(c.code))) {
            names.push_back(std::to_string(hit.line) + ":" + hit.name);
        }
        if (names != c.hits) {
            std::printf("  case %s\n", c.code);
            for (const std::string& n : names) {
                std::printf("    hit %s\n", n.c_str());
            }
        }
        CHECK(names == c.hits);
    }
}

WR_TEST(testNoIOInTheRuntime) {
    std::vector<std::string> files;
    const char* list = std::getenv("WR_SCAN_FILES");
    std::istringstream paths(list ? list : "");
    std::string path;
    while (paths >> path) {
        if (sourceFile(path)) {
            files.push_back(path);
        }
    }
    size_t own = 0, quickjs = 0, gumbo = 0, litehtml = 0;
    for (const std::string& file : files) {
        own += file.find("WidgetRuntime/Sources/") != std::string::npos;
        quickjs += file.find("quickjs-ng/") != std::string::npos;
        gumbo += file.find("gumbo/") != std::string::npos;
        litehtml += file.find("litehtml/") != std::string::npos;
    }
    std::printf("scanning %zu files: %zu of WidgetRuntime, %zu quickjs-ng, %zu gumbo, %zu litehtml\n", files.size(), own, quickjs,
                gumbo, litehtml);
    // The scan must have reached all four trees: an empty or partial list would pass for nothing.
    CHECK(own >= 108);
    CHECK(quickjs >= 16);
    CHECK(gumbo >= 26);
    CHECK(litehtml >= 128);

    std::set<size_t> used;
    size_t allowedHits = 0;
    for (const std::string& file : files) {
        std::ifstream in(file, std::ios::binary);
        std::stringstream buffer;
        buffer << in.rdbuf();
        const std::string text = buffer.str();
        CHECK(!text.empty());
        for (const Hit& hit : hitsIn(stripped(text))) {
            const std::string line = lineOf(text, hit.line);
            bool allowed = false;
            for (size_t k = 0; k < kAllowed.size(); k++) {
                if (endsWith(file, kAllowed[k].file) && line == kAllowed[k].line) {
                    allowed = true;
                    used.insert(k);
                }
            }
            if (allowed) {
                allowedHits++;
                continue;
            }
            std::printf("  I/O: %s:%zu: %s: %s\n", file.c_str(), hit.line, hit.name.c_str(), line.c_str());
            CHECK(false);
        }
    }
    for (size_t k = 0; k < kAllowed.size(); k++) {
        if (!used.count(k)) {
            std::printf("  the allowlist entry for %s (%s) matched nothing\n", kAllowed[k].file, kAllowed[k].line);
            CHECK(false);
        }
    }
    std::printf("%zu allowlisted hits\n", allowedHits);
}
