// Every corpus document, the attacks included, and every client fixture run incrementally: built once, at the boot, and
// never stopped for an inconsistency (RenderTree::stopInternally), whatever the widget does after it.
//
//   ./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeCorpusIncrementalTests
//
// In the corpus goldens' deterministic mode (CorpusGoldenTests.cpp) at width 360: the boot, 3 s of virtual time, a 6 × 4
// grid of taps 300 ms apart, then 120 frames, each phase on the goldens' caps so that only a runaway stops. It prints the
// churn (Tests/LayerChurn.h): the layers the flushes re-created though their element did not change, the twenty
// documents with the most, and the sum by the fork's reason.
#include <pthread.h>
#include <time.h>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "Sources/Host/HostState.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Errors.h"
#include "Tests/HostHarness.h"
#include "Tests/LayerChurn.h"
#include "Tests/RenderHarness.h"
#include "Tests/VirtualTime.h"

namespace {

constexpr double kWidth = 360;

std::vector<std::string> files() {
    std::vector<std::string> out;
    for (const char* var : {"WR_CORPUS_FILES", "WR_FIXTURES"}) {
        std::istringstream paths(std::getenv(var) ? std::getenv(var) : "");
        for (std::string path; paths >> path;) {
            if (path.ends_with(".html")) {
                out.push_back(path);
            }
        }
    }
    std::sort(out.begin(), out.end());
    return out;
}

std::string readFile(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    std::stringstream s;
    s << in.rdbuf();
    return s.str();
}

// How the document ran.
struct Run {
    uint64_t builds = 0;
    wr::StopReason stop = wr::StopReason::None;
    size_t churned = 0;
};

// A path from the corpus's or the fixtures' root.
std::string shortPath(const std::string& path) {
    for (const char* root : {"corpus/", "Fixtures/"}) {
        if (const size_t at = path.rfind(root); at != std::string::npos) {
            return path.substr(at + std::string(root).size());
        }
    }
    return path;
}

Run runOf(const std::string& html, wr_test::ChurnTally& churn) {
    wr::RenderOptions options;
    options.width = kWidth;
    wr_test::RenderEnv env(html, options, false, [](wr_test::HostEnv& e) {
        e.host().intlAnswer = wr_test::echoIntl;
    });
    wr_test::ScopedChurnProbe churnProbe(env.render(), churn);
    wr::Runtime& runtime = env.env().runtime();
    const auto running = [&] { return runtime.stopReason() == wr::StopReason::None; };
    if (wr_test::driveVirtualTime(env.env(), 0, {}, 1000000) != wr_test::DriveEnd::StepLimit && running()) {
        wr_test::driveVirtualTime(env.env(), 3000, {}, 1000000);
    }
    const auto size = env.render().contentSize();
    const double height = size ? size->height : 300;
    wr::HostState& host = wr::HostState::of(env.ctx());
    for (int row = 0; row < 6 && running(); row++) {
        for (int column = 0; column < 4 && running(); column++) {
            const double x = 45 + 90 * column, y = (row + 0.5) * height / 6;
            try {
                host.pointer(env.ctx(), wr::PointerPhase::Down, x, y, 7, true);
                host.pointer(env.ctx(), wr::PointerPhase::Up, x, y, 7, true);
            } catch (const wr::Aborted&) {
            }
            wr_test::driveVirtualTime(env.env(), env.env().host().now + 300, {}, 1000000);
        }
    }
    for (int frame = 0; frame < 120 && running(); frame++) {
        try {
            env.env().frame(1000.0 / 60.0);
        } catch (const wr::Aborted&) {
        }
    }
    return Run{env.render().buildCount(), runtime.stopReason(), churnProbe.probe().total().churned};
}

void setUp() {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    setenv("TZ", "Asia/Tokyo", 1);
    tzset();
}

} // namespace

WR_TEST(testTheCorpusRunsIncrementally) {
    setUp();
    const std::vector<std::string> paths = files();
    CHECK(paths.size() >= 300);
    size_t stopped = 0;
    wr_test::ChurnTally churn;
    std::vector<std::pair<size_t, std::string>> churned;
    for (const std::string& path : paths) {
        const Run run = runOf(readFile(path), churn);
        churned.emplace_back(run.churned, shortPath(path));
        stopped += run.stop != wr::StopReason::None;
        // A strict cap (widget-sandbox v0.3.0) can stop a hostile document in its boot's build, which publishes nothing.
        const bool stoppedInItsBoot = run.builds == 0 && run.stop == wr::StopReason::Limit;
        if ((run.builds != 1 && !stoppedInItsBoot) || run.stop == wr::StopReason::Internal) {
            std::printf("  %s: %llu builds, stop %d\n", path.c_str(), (unsigned long long)run.builds, int(run.stop));
        }
        CHECK(run.builds == 1 || stoppedInItsBoot);
        CHECK(run.stop != wr::StopReason::Internal);
    }
    std::printf("%zu documents, each built once; %zu stopped (a limit, the CPU clock or the memory limit)\n", paths.size(), stopped);
    std::sort(churned.begin(), churned.end(), [](const auto& a, const auto& b) {
        return a.first != b.first ? a.first > b.first : a.second < b.second;
    });
    std::printf("churn, the most churned documents:\n");
    for (size_t i = 0; i < churned.size() && i < 20; i++) {
        std::printf("%8zu %s\n", churned[i].first, churned[i].second.c_str());
    }
    std::printf("churn (corpus): %s", churn.describe().c_str());
}
