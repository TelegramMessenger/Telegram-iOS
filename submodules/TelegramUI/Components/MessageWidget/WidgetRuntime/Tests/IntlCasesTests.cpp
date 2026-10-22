// widget-sandbox v0.1.1's Intl parity fixture (v0.1.1 plan, Task 10): every request run as a widget would make it
// (Tests/IntlCases.js) over the host's system ICU, compared with V8's answers. A case that answers differently and is
// not in intl-cases-expected-failures.txt fails the test, and so does a listed case that answers as V8 now: the list
// holds each drift with its reason, never a tolerance. The iOS ICU runs the same cases in WidgetRuntimeIOS's
// WRIntlCasesTests, against the list's `ios` lines.
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
    const char* list = std::getenv("WR_INTL_CASES");
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

/// The line's id: what precedes " ## ", trailing spaces dropped.
std::string idOf(std::string line) {
    const size_t hash = line.find(" ## ");
    if (hash != std::string::npos) {
        line.resize(hash);
    }
    while (!line.empty() && line.back() == ' ') {
        line.pop_back();
    }
    return line;
}

/// The list's `<platform> <id>` lines for `platform`, as ids.
std::set<std::string> expectedFailures(const std::string& platform) {
    std::set<std::string> out;
    std::istringstream lines(dataFile("intl-cases-expected-failures.txt"));
    std::string line;
    while (std::getline(lines, line)) {
        if (line.empty() || line[0] == '#' || line.rfind(platform + " ", 0) != 0) {
            continue;
        }
        out.insert(idOf(line.substr(platform.size() + 1)));
    }
    return out;
}

} // namespace

WR_TEST(testTheIntlCasesAnswerAsV8) {
    HostEnv env;
    const std::string fixture = dataFile("intl-cases.json");
    const std::string script = dataFile("IntlCases.js");
    CHECK(!fixture.empty() && !script.empty());
    JSContext* ctx = env.ctx();
    JSValue global = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global, "intlCasesText", JS_NewStringLen(ctx, fixture.data(), fixture.size()));
    JS_FreeValue(ctx, global);
    const std::string result = env.eval(script);
    std::set<std::string> failures;
    std::istringstream lines(result);
    std::string line;
    int unexpected = 0;
    const std::set<std::string> expected = expectedFailures("host");
    while (std::getline(lines, line)) {
        if (line.empty()) {
            continue;
        }
        const std::string id = idOf(line);
        failures.insert(id);
        if (!expected.count(id)) {
            std::printf("  unexpected: %s\n", line.c_str());
            unexpected++;
        }
    }
    int stale = 0;
    for (const std::string& id : expected) {
        if (!failures.count(id)) {
            std::printf("  answers as V8 now (remove it from the list): %s\n", id.c_str());
            stale++;
        }
    }
    std::printf("  %zu cases differ, %d unexpected, %d stale\n", failures.size(), unexpected, stale);
    CHECK(unexpected == 0);
    CHECK(stale == 0);
}
