// The headless corpus boot (M1b plan, Task 18; spec 6.2). Every corpus document but the attacks is booted with
// wr::boot on a virtual clock and run to idle at time 0 (parse, every script, DOMContentLoaded, load, pageshow, and
// timers due at once). Then one virtual second of timers and animation frames runs. It prints:
// - each document's CPU time and memory;
// - the failures bucketed by the global or member their message names;
// - the cost of the Window, HostState and loop on top of M1a's DOM context.
// Spec 6.2 records the numbers. Run it optimized and by hand:
//   ./build-input/bazel-9.2.0-darwin-arm64 test -c opt
//   //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeCorpusBootTests --test_output=all
// Each document boots with the render tree installed (width 360, M1c Task 11). Its first flush is the build after the
// parse, inside the boot; its CPU time is the boot's with the tree less the boot's of the same document with no tree
// (the parse alone), printed per document with the median, p90 and max.
// Each step runs in the harness's slice on its fake clock, which stops only a runaway. It fails on a stop other than
// Cpu, on a drive that runs out of steps (DriveEnd::StepLimit) and on a corpus of fewer than 200 documents; a crash
// fails it by itself. KB are deterministic and are the measurements of record; CPU times (the thread's CPU clock)
// depend on the machine, wall times on its load too.
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

/// The wait main allows a run-loop turn (MessageWidgetWaitPolicy.standard), in CPU ms.
constexpr double kWaitCapMs = 20;

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
    case wr::StopReason::Memory: return "memory";
    case wr::StopReason::Internal: return "internal";
    case wr::StopReason::LayoutQuery: return "layout-query";
    case wr::StopReason::Limit: return "limit";
    case wr::StopReason::Cpu: return "cpu";
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
        std::vector<double> domCpu, domBytes, hostCpu, hostBytes, hostMs;
        for (int run = 0; run < 300; run++) {
            double c0 = wr_test::threadCpuMs();
            wr_test::DOMEnv dom("");
            domCpu.push_back(wr_test::threadCpuMs() - c0);
            domBytes.push_back(double(mallocSize(dom.runtime().jsRuntime())));
            auto t0 = Clock::now();
            c0 = wr_test::threadCpuMs();
            wr_test::HostEnv host("");
            hostCpu.push_back(wr_test::threadCpuMs() - c0);
            hostMs.push_back(std::chrono::duration<double, std::milli>(Clock::now() - t0).count());
            hostBytes.push_back(double(mallocSize(host.runtime().jsRuntime())));
        }
        std::printf("DOM context: %.3f CPU ms, %.1f KB; with the Window, host state and loop: %.3f CPU ms, %.1f KB, %.3f ms; "
                    "the Window's share: %.3f CPU ms, %.1f KB\n",
                    median(domCpu), median(domBytes) / 1024, median(hostCpu), median(hostBytes) / 1024, median(hostMs),
                    median(hostCpu) - median(domCpu), (median(hostBytes) - median(domBytes)) / 1024);
    }

    // 2. Every non-attack corpus document.
    struct Row {
        std::string file;
        double bootCpuMs = 0, secondCpuMs = 0;
        double firstFlushCpuMs = 0;
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
        Row row;
        row.file = file.substr(file.find("corpus/") == std::string::npos ? 0 : file.find("corpus/") + 7);
        auto t0 = Clock::now();
        // The parse alone: the same boot with no render tree.
        double plainCpuMs = 0;
        {
            const double c0 = wr_test::threadCpuMs();
            std::unique_ptr<wr_test::HostEnv> plain = wr_test::HostEnv::booted(boot, 1);
            plainCpuMs = wr_test::threadCpuMs() - c0;
        }
        wr::RenderOptions renderOptions;
        renderOptions.width = 360;
        t0 = Clock::now();
        const double start = wr_test::threadCpuMs();
        wr_test::RenderEnv renderEnv(html, renderOptions, false);
        wr_test::HostEnv* env = &renderEnv.env();
        row.firstFlushCpuMs = std::max(0.0, wr_test::threadCpuMs() - start - plainCpuMs);
        JSRuntime* rt = env->runtime().jsRuntime();
        wr_test::DriveEnd bootEnd = wr_test::driveVirtualTime(*env, 0, {}, 1000000);
        row.bootMs = std::chrono::duration<double, std::milli>(Clock::now() - t0).count();
        if (bootEnd == wr_test::DriveEnd::StepLimit) {
            std::printf("  %s: the boot's drive ran out of steps\n", row.file.c_str());
        }
        CHECK(bootEnd != wr_test::DriveEnd::StepLimit);
        row.bootCpuMs = wr_test::threadCpuMs() - start;
        row.bootKB = double(mallocSize(rt)) / 1024;
        if (env->runtime().stopReason() == wr::StopReason::None) {
            const double before = wr_test::threadCpuMs();
            wr_test::DriveEnd secondEnd = wr_test::driveVirtualTime(*env, 1000, {}, 1000000);
            if (secondEnd == wr_test::DriveEnd::StepLimit) {
                std::printf("  %s: the virtual second's drive ran out of steps\n", row.file.c_str());
            }
            CHECK(secondEnd != wr_test::DriveEnd::StepLimit);
            row.secondCpuMs = wr_test::threadCpuMs() - before;
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
        CHECK(row.stop == wr::StopReason::None || row.stop == wr::StopReason::Cpu);
        rows.push_back(row);
    }

    std::printf("\n%12s %12s %10s %12s %9s %6s %8s  %s\n", "boot CPU ms", "1st flush", "boot KB", "second CPU", "boot ms", "fails", "stop", "file");
    for (const Row& row : rows) {
        std::printf("%12.3f %12.3f %10.1f %12.3f %9.3f %6d %8s  %s\n", row.bootCpuMs, row.firstFlushCpuMs, row.bootKB, row.secondCpuMs,
                    row.bootMs, row.failures, stopName(row.stop), row.file.c_str());
    }
    std::vector<double> boots, seconds, flushes;
    std::vector<double> memory;
    int withinWaitCap = 0, stopped = 0, failing = 0;
    std::string slowest, busiest, largest;
    double slowestCpuMs = 0, busiestCpuMs = 0;
    double largestKB = 0;
    for (const Row& row : rows) {
        boots.push_back(row.bootCpuMs);
        flushes.push_back(row.firstFlushCpuMs);
        seconds.push_back(row.secondCpuMs);
        memory.push_back(row.bootKB);
        withinWaitCap += row.bootCpuMs <= kWaitCapMs;
        stopped += row.stop != wr::StopReason::None;
        failing += row.failures > 0;
        if (row.bootKB > largestKB) {
            largestKB = row.bootKB;
            largest = row.file;
        }
        if (row.bootCpuMs > slowestCpuMs) {
            slowestCpuMs = row.bootCpuMs;
            slowest = row.file;
        }
        if (row.secondCpuMs > busiestCpuMs) {
            busiestCpuMs = row.secondCpuMs;
            busiest = row.file;
        }
    }
    std::printf("\n%zu documents. Boot: median %.3f CPU ms, p90 %.3f, max %.3f (%s); %d within main's 20 ms wait; %d stopped. "
                "Memory after the boot: median %.1f KB, max %.1f KB (%s). The virtual second: median %.3f CPU ms, max %.3f (%s). "
                "%d documents report failures.\n",
                rows.size(), percentile(boots, 0.5), percentile(boots, 0.9), slowestCpuMs, slowest.c_str(), withinWaitCap, stopped,
                percentile(memory, 0.5), largestKB, largest.c_str(), percentile(seconds, 0.5), busiestCpuMs, busiest.c_str(), failing);

    std::printf("First flush (the render build after the parse): median %.3f CPU ms, p90 %.3f, max %.3f.\n", percentile(flushes, 0.5),
                percentile(flushes, 0.9), percentile(flushes, 1.0));

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
