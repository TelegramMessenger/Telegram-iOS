// WPT's URL data (V5b plan, Task 5; third-party/wpt/url/resources): every urltestdata.json case through new URL, every
// toascii.json case through new URL("https://" + input + "/x") and the host and hostname setters, compared with
// url-data-expected-failures.txt. A failure not in the list fails the test, and so does a listed case that passes: the
// list only shrinks, and what it holds is the parser's work list.
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <set>
#include <sstream>
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

std::string dataFile(const char* name) {
    const char* list = std::getenv("WR_URL_DATA");
    std::istringstream paths(list ? list : "");
    std::string path;
    while (paths >> path) {
        if (path.size() >= std::string(name).size() && path.compare(path.size() - std::string(name).size(), std::string::npos, name) == 0) {
            std::ifstream in(path, std::ios::binary);
            std::stringstream s;
            s << in.rdbuf();
            return s.str();
        }
    }
    return std::string();
}

/// The expected failures: one case id per line, its reason after " ## ", blank lines and "#" lines ignored.
std::set<std::string> expectedFailures() {
    std::set<std::string> out;
    std::istringstream lines(dataFile("url-data-expected-failures.txt"));
    std::string line;
    while (std::getline(lines, line)) {
        const size_t hash = line.find(" ## ");
        if (hash != std::string::npos) {
            line.resize(hash);
        }
        while (!line.empty() && line.back() == ' ') {
            line.pop_back();
        }
        if (!line.empty() && line[0] != '#') {
            out.insert(line);
        }
    }
    return out;
}

/// Runs `script` over the JSON text of `file` (as the global `wptData`): its completion is the failures, one per line.
std::set<std::string> failuresOf(const char* file, const char* script) {
    HostEnv env;
    const std::string text = dataFile(file);
    CHECK(!text.empty());
    JSContext* ctx = env.ctx();
    JSValue global = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global, "wptData", JS_NewStringLen(ctx, text.data(), text.size()));
    JS_FreeValue(ctx, global);
    const std::string result = env.eval(script);
    std::set<std::string> out;
    std::istringstream lines(result);
    std::string line;
    while (std::getline(lines, line)) {
        if (!line.empty()) {
            out.insert(line);
        }
    }
    return out;
}

void compareWithExpected(const std::set<std::string>& failures, const char* prefix) {
    const std::set<std::string> expected = expectedFailures();
    int unexpected = 0, stale = 0;
    for (const std::string& f : failures) {
        if (!expected.count(f)) {
            std::printf("  unexpected failure: %s\n", f.c_str());
            unexpected++;
        }
    }
    for (const std::string& e : expected) {
        if (e.rfind(prefix, 0) == 0 && !failures.count(e)) {
            std::printf("  passes now (remove it from the list): %s\n", e.c_str());
            stale++;
        }
    }
    std::printf("  %s: %zu failures, %d unexpected, %d stale\n", prefix, failures.size(), unexpected, stale);
    CHECK(unexpected == 0);
    CHECK(stale == 0);
}

} // namespace

WR_TEST(testURLTestData) {
    const std::set<std::string> failures = failuresOf("urltestdata.json", R"JS(
        const out = [];
        const id = c => 'urltestdata: ' + JSON.stringify(c.input) + (c.base == null ? '' : ' @ ' + JSON.stringify(c.base));
        for (const c of JSON.parse(wptData)) {
            if (typeof c === 'string') continue;
            let u;
            try { u = c.base == null ? new URL(c.input) : new URL(c.input, c.base) }
            catch (e) { if (!c.failure) out.push(id(c) + ' threw'); continue }
            if (c.failure) { out.push(id(c) + ' parsed'); continue }
            for (const k of ['href', 'protocol', 'username', 'password', 'host', 'hostname', 'port', 'pathname', 'search', 'hash'])
                if (u[k] !== c[k]) { out.push(id(c) + ' ' + k); break }
            if ('origin' in c && u.origin !== c.origin) out.push(id(c) + ' origin');
        }
        out.join('\n')
    )JS");
    compareWithExpected(failures, "urltestdata: ");
}

WR_TEST(testToASCII) {
    const std::set<std::string> failures = failuresOf("toascii.json", R"JS(
        const out = [];
        for (const c of JSON.parse(wptData)) {
            if (typeof c === 'string') continue;
            const id = 'toascii: ' + JSON.stringify(c.input);
            try {
                const u = new URL('https://' + c.input + '/x');
                if (c.output === null) out.push(id + ' parsed');
                else if (u.host !== c.output || u.hostname !== c.output || u.href !== 'https://' + c.output + '/x') out.push(id + ' host');
            } catch (e) { if (c.output !== null) out.push(id + ' threw') }
            const h = new URL('https://x/x'); h.host = c.input;
            if (h.host !== (c.output === null ? 'x' : c.output)) out.push(id + ' host setter');
            const n = new URL('https://x/x'); n.hostname = c.input;
            if (n.hostname !== (c.output === null ? 'x' : c.output)) out.push(id + ' hostname setter');
        }
        out.join('\n')
    )JS");
    compareWithExpected(failures, "toascii: ");
}
