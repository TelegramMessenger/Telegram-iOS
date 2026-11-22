// Measurements for spec section 6.2 (M1a plan, Task 18). Prints tables; fails only on a context that grew past
// 256 KB or a corpus document that hit gumbo's node limit. The context grows with the interface table (136 KB after
// M1a, 186 after M1b, 225 after V5e, 229 after V5f); the gate is there for eager materialization (all 80 interfaces
// installed eagerly measured 555 KB), not for an interface more. The corpus' paths come in WR_CORPUS_FILES (BUILD). Run
// optimized:
//   ./build-input/bazel-9.2.0-darwin-arm64 test -c opt
//   //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeMeasurementTests --test_output=all
// KB are deterministic and are the measurements of record; times depend on the machine, and wall times on its load too
// (the thread asks for user-interactive QoS, so it is not left on an efficiency core).
#include <pthread.h>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "Sources/DOM/DOM.h"
#include "Tests/DOMHarness.h"

namespace {

using Clock = std::chrono::steady_clock;

std::vector<std::string> corpusFiles() {
    std::vector<std::string> files;
    const char* list = std::getenv("WR_CORPUS_FILES");
    std::istringstream paths(list ? list : "");
    std::string path;
    while (paths >> path) {
        files.push_back(path);
    }
    return files;
}

double median(std::vector<double> v) {
    std::sort(v.begin(), v.end());
    return v[v.size() / 2];
}

int64_t mallocSize(JSRuntime* rt) {
    JSMemoryUsage usage;
    JS_ComputeMemoryUsage(rt, &usage);
    return usage.malloc_size;
}

std::string readFile(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    std::stringstream s;
    s << in.rdbuf();
    return s.str();
}

} // namespace

WR_TEST(testMeasurements) {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    double load[3] = {0, 0, 0};
    getloadavg(load, 3);
    std::printf("load averages before: %.2f %.2f %.2f\n", load[0], load[1], load[2]);

    // 1. A context with the DOM installed and an empty document parsed, nothing materialized but what the document's
    // wrappers need; and, for comparison, a bare runtime: the interface table's classes and global entries, no DOM.
    {
        std::vector<double> ms, bytes, cpu;
        for (int run = 0; run < 300; run++) {
            auto t0 = Clock::now();
            const double c0 = wr_test::threadCpuMs();
            wr_test::DOMEnv env("");
            cpu.push_back(wr_test::threadCpuMs() - c0);
            ms.push_back(std::chrono::duration<double, std::milli>(Clock::now() - t0).count());
            bytes.push_back(double(mallocSize(env.runtime().jsRuntime())));
        }
        std::printf("context + DOM: %.3f ms, %.3f CPU ms, %.0f KB (median of 300)\n", median(ms), median(cpu), median(bytes) / 1024);
        CHECK(median(bytes) <= 256 * 1024);
        ms.clear();
        bytes.clear();
        cpu.clear();
        for (int run = 0; run < 300; run++) {
            auto t0 = Clock::now();
            const double c0 = wr_test::threadCpuMs();
            wr_test::JSEnv env(wr::idl::kTable);
            cpu.push_back(wr_test::threadCpuMs() - c0);
            ms.push_back(std::chrono::duration<double, std::milli>(Clock::now() - t0).count());
            bytes.push_back(double(mallocSize(env.runtime().jsRuntime())));
        }
        std::printf("bare runtime (interface entries, no DOM): %.3f ms, %.3f CPU ms, %.0f KB (median of 300)\n", median(ms), median(cpu),
                    median(bytes) / 1024);
    }

    // 2. Each exposed interface materialized alone (its object and prototype, and so its parents'), and 3. all of them.
    // In the DOM context the document and its html, head and body are wrappers already, so their interfaces (and
    // their parents) are materialized before the touch and their rows measure the touch alone; the bare runtime has
    // nothing materialized, so its column is each interface's whole cost.
    {
        const wr::InterfaceTable& table = wr::idl::kTable;
        struct Cost {
            double ms, kb, cpu;
        };
        auto measureTouch = [](bool withDOM, const std::string& touch) {
            std::vector<double> ms, bytes, cpu;
            auto once = [&](wr_test::JSEnv& env) {
                JSRuntime* rt = env.runtime().jsRuntime();
                int64_t b0 = mallocSize(rt);
                auto t0 = Clock::now();
                const double c0 = wr_test::threadCpuMs();
                env.eval(touch);
                cpu.push_back(wr_test::threadCpuMs() - c0);
                ms.push_back(std::chrono::duration<double, std::milli>(Clock::now() - t0).count());
                bytes.push_back(double(mallocSize(rt) - b0));
            };
            for (int run = 0; run < 50; run++) {
                if (withDOM) {
                    wr_test::DOMEnv env("");
                    once(env);
                } else {
                    wr_test::JSEnv env(wr::idl::kTable);
                    once(env);
                }
            }
            return Cost{median(ms), median(bytes) / 1024, median(cpu)};
        };
        std::printf("\n%-32s %30s   %30s\n", "", "in the DOM context", "in a bare runtime");
        std::printf("%-32s %10s %10s %10s   %10s %10s %10s\n", "interface", "ms", "KB", "CPU ms", "ms", "KB", "CPU ms");
        std::string all;
        int exposed = 0;
        for (uint16_t i = 0; i < table.count; i++) {
            const wr::InterfaceInfo& info = table.interfaces[i];
            if (!info.exposed) {
                continue;
            }
            exposed++;
            std::string touch = std::string("void ") + info.name + ".prototype;";
            all += touch;
            Cost dom = measureTouch(true, touch), bare = measureTouch(false, touch);
            std::printf("%-32s %10.4f %10.1f %10.4f   %10.4f %10.1f %10.4f\n", info.name, dom.ms, dom.kb, dom.cpu, bare.ms, bare.kb, bare.cpu);
        }
        Cost dom = measureTouch(true, all), bare = measureTouch(false, all);
        std::printf("%-32s %10.4f %10.1f %10.4f   %10.4f %10.1f %10.4f\n", "(all exposed interfaces)", dom.ms, dom.kb, dom.cpu, bare.ms, bare.kb,
                    bare.cpu);
        // The touch script's own cost, against which the rows above read: an interface already made.
        Cost script = measureTouch(true, "void Node.prototype;");
        std::printf("exposed interfaces: %d; the touch alone (Node in the DOM context): %.4f ms, %.1f KB, %.4f CPU ms\n", exposed, script.ms,
                    script.kb, script.cpu);
    }

    // 4. Every corpus document parsed natively into a fresh document (gumbo and the DOM build together).
    {
        double totalMs = 0, maxMs = 0;
        size_t totalBytes = 0, documents = 0;
        std::string slowest;
        std::vector<std::string> files = corpusFiles();
        CHECK(files.size() > 300);
        for (const std::string& file : files) {
            std::string html = readFile(file);
            wr_test::DOMEnv env;
            JSContext* ctx = env.ctx();
            std::vector<double> ms;
            wr::ParseOutcome outcome;
            for (int run = 0; run < 5; run++) {
                wr::Ref<wr::Document> document = wr::Document::createHTML(ctx);
                auto t0 = Clock::now();
                outcome = wr::parseDocumentInto(ctx, *document, html);
                ms.push_back(std::chrono::duration<double, std::milli>(Clock::now() - t0).count());
            }
            double m = median(ms);
            totalMs += m;
            totalBytes += html.size();
            documents++;
            if (m > maxMs) {
                maxMs = m;
                slowest = file;
            }
            // No corpus document should reach either parse limit (nodes or total attributes).
            if (outcome.stoppedAtNodeLimit) {
                std::printf("  %s stopped at the node limit\n", file.c_str());
            }
            if (outcome.stoppedAtAttributeLimit) {
                std::printf("  %s stopped at the attribute limit\n", file.c_str());
            }
            CHECK(!outcome.stoppedAtNodeLimit && !outcome.stoppedAtAttributeLimit);
        }
        std::printf("\ncorpus: %zu documents, %zu KB, parse %.3f ms total, %.3f ms mean, %.3f ms max (%s)\n", documents,
                    totalBytes / 1024, totalMs, documents ? totalMs / double(documents) : 0.0, maxMs, slowest.c_str());
    }

    getloadavg(load, 3);
    std::printf("load averages after: %.2f %.2f %.2f\n", load[0], load[1], load[2]);
}
