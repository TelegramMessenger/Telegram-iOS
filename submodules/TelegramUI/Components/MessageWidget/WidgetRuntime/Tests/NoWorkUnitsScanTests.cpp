// No work units anywhere (the CPU-clock limits plan, Task 7): a widget's execution is judged by the widget thread's CPU
// clock alone, so the runtime, its iOS glue and the quickjs-ng fork carry no work counter, charge or work limit. Every
// source of WidgetRuntime/Sources, WidgetRuntimeIOS/Sources and quickjs-ng's QuickJS is read with its comments and
// literals blanked (Tests/SourceScan.h), and any of the names below as a whole identifier fails, as does an include of
// the rates' header. WR_SCAN_FILES lists the files (the Bazel target's data).
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "Tests/SourceScan.h"
#include "Tests/wr_test.h"

namespace {

const char* const kNames[] = {
    "charge",         "chargeScan",      "chargeOrStop",     "chargeQueryRead",  "JS_ChargeWork",   "JS_GetWorkUnits",
    "setWorkLimit",   "setWorkLimitAfter", "setWorkObserver", "workUnits",        "work_units",      "lre_charge_steps",
    "lre_charge_work", "js_charge_hop",   "kLayoutQueryBudget",
};
/// The rate macros.
const char* const kPrefixes[] = {"JS_WORK_"};

struct Hit {
    size_t line;
    std::string name;
};

std::vector<Hit> hitsIn(const std::string& code) {
    std::vector<Hit> hits;
    size_t line = 1;
    for (size_t i = 0; i < code.size();) {
        if (code[i] == '\n') {
            line++;
            i++;
            continue;
        }
        if (!(std::isalpha((unsigned char)code[i]) || code[i] == '_') || (i > 0 && wr_test::identChar(code[i - 1]))) {
            i++;
            continue;
        }
        size_t end = i;
        while (end < code.size() && wr_test::identChar(code[end])) {
            end++;
        }
        const std::string word = code.substr(i, end - i);
        bool hit = false;
        for (const char* name : kNames) {
            hit = hit || word == name;
        }
        for (const char* prefix : kPrefixes) {
            hit = hit || word.rfind(prefix, 0) == 0;
        }
        if (hit) {
            hits.push_back({line, word});
        }
        i = end;
    }
    return hits;
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

WR_TEST(testTheWorkScanSeesWhatItShould) {
    const std::string code = wr_test::stripped("void f() { charge(ctx, 1); /* chargeScan(ctx, 2) */ x.recharge = \"JS_ChargeWork\";\n"
                                               "  uint64_t u = JS_GetWorkUnits(rt) + JS_WORK_CHECK_PERIOD; discharge(1); }\n");
    std::vector<std::string> names;
    for (const Hit& hit : hitsIn(code)) {
        names.push_back(std::to_string(hit.line) + ":" + hit.name);
    }
    CHECK(names == (std::vector<std::string>{"1:charge", "2:JS_GetWorkUnits", "2:JS_WORK_CHECK_PERIOD"}));
}

WR_TEST(testNoWorkUnits) {
    std::vector<std::string> files;
    const char* list = std::getenv("WR_SCAN_FILES");
    std::istringstream paths(list ? list : "");
    std::string path;
    while (paths >> path) {
        if (sourceFile(path)) {
            files.push_back(path);
        }
    }
    size_t own = 0, ios = 0, quickjs = 0;
    for (const std::string& file : files) {
        own += file.find("WidgetRuntime/Sources/") != std::string::npos;
        ios += file.find("WidgetRuntimeIOS/Sources/") != std::string::npos;
        quickjs += file.find("quickjs-ng/") != std::string::npos;
    }
    std::printf("scanning %zu files: %zu of WidgetRuntime, %zu of WidgetRuntimeIOS, %zu quickjs-ng\n", files.size(), own, ios, quickjs);
    // The scan must have reached all three trees: an empty or partial list would pass for nothing.
    CHECK(own >= 108);
    CHECK(ios >= 5);
    CHECK(quickjs >= 16);
    size_t hits = 0;
    for (const std::string& file : files) {
        std::ifstream in(file, std::ios::binary);
        std::stringstream buffer;
        buffer << in.rdbuf();
        const std::string text = buffer.str();
        CHECK(!text.empty());
        if (text.find("Support/Work.h") != std::string::npos) {
            std::printf("  units: %s: includes Support/Work.h\n", file.c_str());
            hits++;
        }
        for (const Hit& hit : hitsIn(wr_test::stripped(text))) {
            if (hits++ < 200) {
                std::printf("  units: %s:%zu: %s\n", file.c_str(), hit.line, hit.name.c_str());
            }
        }
    }
    std::printf("%zu hits\n", hits);
    CHECK_EQ(hits, size_t(0));
}
