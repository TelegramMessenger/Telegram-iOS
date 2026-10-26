// The headless corpus boot (M1b plan, Task 18; spec 6.2). Every corpus document but the attacks is booted with
// wr::boot on a virtual clock and run to idle at time 0 (parse, every script, DOMContentLoaded, load, pageshow, and
// timers due at once). Then one virtual second of timers and animation frames runs. It prints:
// - each document's units and memory;
// - the failures bucketed by the global or member their message names;
// - the cost of the Window, HostState and loop on top of M1a's DOM context.
// Spec 6.2 records the numbers. Run it optimized and by hand:
//   ./build-input/bazel-9.2.0-darwin-arm64 test -c opt
//   //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeCorpusBootTests --test_output=all
// Each document boots with the render tree installed (width 360, M1c Task 11). Its first flush is the build after the
// parse, inside the boot; its units are the boot's with the tree less the boot's of the same document with no tree
// (the parse alone), printed per document with the median, p90 and max.
// It fails on a stop other than Budget, on a drive that runs out of steps (DriveEnd::StepLimit) and on a corpus of
// fewer than 200 documents; a crash fails it by itself. Units and KB are deterministic and are the measurements of
// record. Wall times depend on the machine and its load.
#include <pthread.h>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <map>
#include <memory>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include "Sources/DOM/DOM.h"
#include "Tests/DOMHarness.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"
#include "Tests/VirtualTime.h"

namespace {

using Clock = std::chrono::steady_clock;

/// The boot's cap: today's parse ceiling plus its boot budget (400M + 48M), so that only a runaway stops.
constexpr uint64_t kBootCap = 448000000;
/// The virtual second's cap: today's task budget (28M) 60 times over, so that only a runaway stops. The second runs the
/// driver's frame ticks 1 to 59: tick 60 is 1000.0000000000001 ms, past it.
constexpr uint64_t kSecondCap = 28000000ull * 60;
constexpr uint64_t kAllowance = 1000000;   // the per-turn sync allowance (spec 3)
constexpr uint64_t kBootBudget = 48000000; // today's boot budget

std::vector<std::string> corpusFiles() {
    std::vector<std::string> files;
    const char* list = std::getenv("WR_CORPUS_FILES");
    std::istringstream paths(list ? list : "");
    std::string path;
    while (paths >> path) {
        if (path.find("/attacks/") == std::string::npos) {
            files.push_back(path);
        }
    }
    std::sort(files.begin(), files.end());
    return files;
}

std::string readFile(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    std::stringstream s;
    s << in.rdbuf();
    return s.str();
}

int64_t mallocSize(JSRuntime* rt) {
    JSMemoryUsage usage;
    JS_ComputeMemoryUsage(rt, &usage);
    return usage.malloc_size;
}

template <class T>
T percentile(std::vector<T> v, double p) {
    if (v.empty()) {
        return T();
    }
    std::sort(v.begin(), v.end());
    return v[std::min(v.size() - 1, size_t(p * double(v.size())))];
}

/// A failure's bucket: the global or member its message names, or its message with digits blanked.
std::string bucketOf(const std::string& text) {
    static const std::regex notDefined(R"(([A-Za-z_$][\w$]*) is not defined)");
    static const std::regex readOf(R"(cannot read property '([^']*)' of (undefined|null))");
    static const std::regex writeTo(R"(cannot set property '([^']*)' of (undefined|null))");
    static const std::regex notConstructor(R"(([A-Za-z_$][\w$.]*) is not a constructor)");
    std::smatch m;
    if (std::regex_search(text, m, notDefined)) {
        return "missing global: " + m[1].str();
    }
    if (std::regex_search(text, m, readOf)) {
        return "read of " + m[2].str() + ": ." + m[1].str();
    }
    if (std::regex_search(text, m, writeTo)) {
        return "write to " + m[2].str() + ": ." + m[1].str();
    }
    if (std::regex_search(text, m, notConstructor)) {
        return "not a constructor: " + m[1].str();
    }
    if (text.find("not a function") != std::string::npos) {
        return "not a function";
    }
    if (text.find("script-skipped") != std::string::npos) {
        return "script-skipped (no library loader in M1b)";
    }
    std::string first = text.substr(0, text.find('\n')).substr(0, 60);
    for (char& c : first) {
        if (c >= '0' && c <= '9') {
            c = '#';
        }
    }
    return first;
}

const char* stopName(wr::StopReason reason) {
    switch (reason) {
    case wr::StopReason::None: return "-";
    case wr::StopReason::Budget: return "budget";
    case wr::StopReason::Memory: return "memory";
    case wr::StopReason::Internal: return "internal";
    case wr::StopReason::LayoutQuery: return "layout-query";
    }
    return "?";
}

double median(std::vector<double> v) {
    std::sort(v.begin(), v.end());
    return v.empty() ? 0 : v[v.size() / 2];
}

} // namespace

WR_TEST(testCorpusBoot) {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    double load[3] = {0, 0, 0};
    getloadavg(load, 3);
    std::printf("load averages before: %.2f %.2f %.2f\n", load[0], load[1], load[2]);

    // 1. The Window, HostState and loop on top of the DOM context: HostEnv("") against DOMEnv("") (medians of 300).
    {
        std::vector<double> domUnits, domBytes, hostUnits, hostBytes, hostMs;
        for (int run = 0; run < 300; run++) {
            wr_test::DOMEnv dom("");
            domUnits.push_back(double(JS_GetWorkUnits(dom.runtime().jsRuntime())));
            domBytes.push_back(double(mallocSize(dom.runtime().jsRuntime())));
            auto t0 = Clock::now();
            wr_test::HostEnv host("");
            hostMs.push_back(std::chrono::duration<double, std::milli>(Clock::now() - t0).count());
            hostUnits.push_back(double(JS_GetWorkUnits(host.runtime().jsRuntime())));
            hostBytes.push_back(double(mallocSize(host.runtime().jsRuntime())));
        }
        std::printf("DOM context: %.0f units, %.1f KB; with the Window, host state and loop: %.0f units, %.1f KB, %.3f ms; "
                    "the Window's share: %.0f units, %.1f KB\n",
                    median(domUnits), median(domBytes) / 1024, median(hostUnits), median(hostBytes) / 1024, median(hostMs),
                    median(hostUnits) - median(domUnits), (median(hostBytes) - median(domBytes)) / 1024);
    }

    // 2. Every non-attack corpus document.
    struct Row {
        std::string file;
        uint64_t bootUnits = 0, secondUnits = 0;
        uint64_t firstFlushUnits = 0;
        double bootKB = 0, bootMs = 0;
        int failures = 0;
        wr::StopReason stop = wr::StopReason::None;
    };
    std::vector<Row> rows;
    std::map<std::string, std::set<std::string>> buckets;  // bucket -> files
    std::vector<std::string> files = corpusFiles();
    CHECK(files.size() >= 200);
    for (const std::string& file : files) {
        std::string html = readFile(file);
        wr::BootOptions boot;
        boot.html = html;
        uint64_t start = 0;
        Row row;
        row.file = file.substr(file.find("corpus/") == std::string::npos ? 0 : file.find("corpus/") + 7);
        auto t0 = Clock::now();
        // The parse alone: the same boot with no render tree.
        uint64_t plainStart = 0, plainUnits = 0;
        {
            std::unique_ptr<wr_test::HostEnv> plain = wr_test::HostEnv::booted(boot, 1, [&](wr_test::HostEnv& e) {
                plainStart = JS_GetWorkUnits(e.runtime().jsRuntime());
                e.runtime().setWorkLimit(plainStart + kBootCap);
            });
            plainUnits = JS_GetWorkUnits(plain->runtime().jsRuntime()) - plainStart;
        }
        wr::RenderOptions renderOptions;
        renderOptions.width = 360;
        t0 = Clock::now();
        wr_test::RenderEnv renderEnv(html, renderOptions, false, [&](wr_test::HostEnv& e) {
            start = JS_GetWorkUnits(e.runtime().jsRuntime());
            e.runtime().setWorkLimit(start + kBootCap);
        });
        wr_test::HostEnv* env = &renderEnv.env();
        row.firstFlushUnits = JS_GetWorkUnits(env->runtime().jsRuntime()) - start;
        row.firstFlushUnits = row.firstFlushUnits > plainUnits ? row.firstFlushUnits - plainUnits : 0;
        JSRuntime* rt = env->runtime().jsRuntime();
        wr_test::DriveEnd bootEnd = wr_test::driveVirtualTime(*env, 0, {}, 1000000);
        row.bootMs = std::chrono::duration<double, std::milli>(Clock::now() - t0).count();
        if (bootEnd == wr_test::DriveEnd::StepLimit) {
            std::printf("  %s: the boot's drive ran out of steps\n", row.file.c_str());
        }
        CHECK(bootEnd != wr_test::DriveEnd::StepLimit);
        row.bootUnits = JS_GetWorkUnits(rt) - start;
        row.bootKB = double(mallocSize(rt)) / 1024;
        if (env->runtime().stopReason() == wr::StopReason::None) {
            uint64_t before = JS_GetWorkUnits(rt);
            env->runtime().setWorkLimit(before + kSecondCap);
            wr_test::DriveEnd secondEnd = wr_test::driveVirtualTime(*env, 1000, {}, 1000000);
            if (secondEnd == wr_test::DriveEnd::StepLimit) {
                std::printf("  %s: the virtual second's drive ran out of steps\n", row.file.c_str());
            }
            CHECK(secondEnd != wr_test::DriveEnd::StepLimit);
            row.secondUnits = JS_GetWorkUnits(rt) - before;
        }
        row.stop = env->runtime().stopReason();
        for (const auto& [kind, detail] : env->host().diagnostics) {
            row.failures++;
            buckets[bucketOf(kind + ": " + detail)].insert(row.file);
        }
        for (const auto& [level, text] : env->host().logs) {
            if (level == wr::LogLevel::Error) {
                row.failures++;
                buckets[bucketOf(text)].insert(row.file);
            }
        }
        CHECK(row.stop == wr::StopReason::None || row.stop == wr::StopReason::Budget);
        rows.push_back(row);
    }

    std::printf("\n%12s %12s %10s %12s %9s %6s %8s  %s\n", "boot units", "1st flush", "boot KB", "second units", "boot ms", "fails", "stop", "file");
    for (const Row& row : rows) {
        std::printf("%12llu %12llu %10.1f %12llu %9.3f %6d %8s  %s\n", (unsigned long long)row.bootUnits,
                    (unsigned long long)row.firstFlushUnits, row.bootKB,
                    (unsigned long long)row.secondUnits, row.bootMs, row.failures, stopName(row.stop), row.file.c_str());
    }
    std::vector<uint64_t> boots, seconds, flushes;
    std::vector<double> memory;
    int withinAllowance = 0, withinBootBudget = 0, stopped = 0, failing = 0, busy = 0;
    std::string slowest, busiest, largest;
    uint64_t slowestUnits = 0, busiestUnits = 0;
    double largestKB = 0;
    for (const Row& row : rows) {
        boots.push_back(row.bootUnits);
        flushes.push_back(row.firstFlushUnits);
        seconds.push_back(row.secondUnits);
        memory.push_back(row.bootKB);
        withinAllowance += row.bootUnits <= kAllowance;
        withinBootBudget += row.bootUnits <= kBootBudget;
        stopped += row.stop != wr::StopReason::None;
        failing += row.failures > 0;
        busy += row.secondUnits > 0;
        if (row.bootKB > largestKB) {
            largestKB = row.bootKB;
            largest = row.file;
        }
        if (row.bootUnits > slowestUnits) {
            slowestUnits = row.bootUnits;
            slowest = row.file;
        }
        if (row.secondUnits > busiestUnits) {
            busiestUnits = row.secondUnits;
            busiest = row.file;
        }
    }
    std::printf("\n%zu documents. Boot: median %llu units, p90 %llu, max %llu (%s); %d within the 1,000,000-unit allowance, "
                "%d within today's 48,000,000-unit boot budget; %d stopped. Memory after the boot: median %.1f KB, max %.1f KB (%s). "
                "The virtual second: median %llu units, max %llu (%s); %d documents spend units in it. "
                "%d documents report failures.\n",
                rows.size(), (unsigned long long)percentile(boots, 0.5), (unsigned long long)percentile(boots, 0.9),
                (unsigned long long)slowestUnits, slowest.c_str(), withinAllowance, withinBootBudget, stopped,
                percentile(memory, 0.5), largestKB, largest.c_str(),
                (unsigned long long)percentile(seconds, 0.5), (unsigned long long)busiestUnits, busiest.c_str(), busy, failing);

    std::printf("First flush (the render build after the parse): median %llu units, p90 %llu, max %llu.\n",
                (unsigned long long)percentile(flushes, 0.5), (unsigned long long)percentile(flushes, 0.9),
                (unsigned long long)percentile(flushes, 1.0));

    std::vector<std::pair<std::string, std::set<std::string>>> sorted(buckets.begin(), buckets.end());
    std::sort(sorted.begin(), sorted.end(), [](const auto& a, const auto& b) {
        return a.second.size() != b.second.size() ? a.second.size() > b.second.size() : a.first < b.first;
    });
    std::printf("\nfailures by bucket (files):\n");
    for (const auto& [bucket, inFiles] : sorted) {
        std::string examples;
        int n = 0;
        for (const std::string& f : inFiles) {
            if (n++ == 3) {
                break;
            }
            examples += (examples.empty() ? "" : ", ") + f;
        }
        std::printf("%5zu  %s  (%s)\n", inFiles.size(), bucket.c_str(), examples.c_str());
    }
    getloadavg(load, 3);
    std::printf("load averages after: %.2f %.2f %.2f\n", load[0], load[1], load[2]);
}
