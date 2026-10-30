// The corpus goldens (spec §9 item 2): every non-attack corpus document's native results, recorded in deterministic
// mode, so that a change shows as a diff to fix or to accept. There is nothing to compare them with but themselves.
//
//   ./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeCorpusGoldenTests
//   WR_GOLDENS_UPDATE=1 ./build-input/bazel-9.2.0-darwin-arm64 run //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeCorpusGoldenTests
//
// The update writes every golden into Tests/CorpusGoldens/ under `bazel run` (the source tree), or into the test's
// undeclared outputs under `bazel test`, and removes the goldens of documents the corpus no longer has.
//
// A golden holds how the run ended (stop, drive), the render limits reached, what the host was told (diagnostics,
// console, bridge calls, storage commits, refused loads), the DOM without its scripts' and style sheets' text, the
// layout dump (RenderTree::layoutDump) and the paint (LayerTree::dump, each font description printed once).
//
// Deterministic mode: the host's virtual clock (its wall clock fixed at 2026-01-01T00:00:00Z), random seed 1, the fake
// render host's metrics, Intl answered by echoIntl (the request itself, never the system's locale data) and TZ pinned
// to Asia/Tokyo: an offset, so a local-time and UTC mix-up shows, and no daylight saving, so no transition is near.
// Each document boots at width 360 to idle, then runs one virtual second, then flushes, as the corpus gates do.
// Animations are kept: on the virtual clock their values at 1 s are results too.
// Each step runs in the harness's slice on its fake clock, which stops only a runaway. CPU times and memory are never
// recorded: they move with the machine and with the system allocator.
#include <pthread.h>
#include <time.h>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Errors.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"
#include "Tests/VirtualTime.h"

namespace {

constexpr const char* kGoldensInSource = "submodules/TelegramUI/Components/MessageWidget/WidgetRuntime/Tests/CorpusGoldens";
constexpr double kWidth = 360;

std::vector<std::string> corpusFiles() {
    std::vector<std::string> files;
    const char* list = std::getenv("WR_CORPUS_FILES");
    std::istringstream paths(list ? list : "");
    std::string path;
    while (paths >> path) {
        if (path.find("/attacks/") == std::string::npos && path.ends_with(".html")) {
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

bool writeFile(const std::filesystem::path& path, const std::string& text) {
    std::error_code error;
    std::filesystem::create_directories(path.parent_path(), error);
    std::ofstream out(path, std::ios::binary | std::ios::trunc);
    out << text;
    return bool(out);
}

/// The path under corpus/, which the golden's path repeats (generated/with-profile and without-profile share names).
std::string shortName(const std::string& file) {
    const size_t at = file.find("corpus/");
    return at == std::string::npos ? file : file.substr(at + 7);
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

const char* levelName(wr::LogLevel level) {
    switch (level) {
    case wr::LogLevel::Debug: return "debug";
    case wr::LogLevel::Log: return "log";
    case wr::LogLevel::Info: return "info";
    case wr::LogLevel::Warn: return "warn";
    case wr::LogLevel::Error: return "error";
    }
    return "?";
}

/// One line however many the text has: newlines as \n, backslashes doubled.
std::string oneLine(const std::string& text) {
    std::string out;
    for (char c : text) {
        out += c == '\n' ? std::string("\\n") : c == '\\' ? std::string("\\\\") : std::string(1, c);
    }
    return out;
}

/// The paint dump with each font description printed once: a text item's `font=(…)` becomes `font=f<n>`, numbered in
/// the order of first use, and the descriptions follow under `== fonts`. Quoted strings (a text item's text) are copied
/// as they are.
std::string internFonts(const std::string& dump) {
    static const std::string kKey = "font=(";
    std::string out, fonts;
    std::map<std::string, size_t> numbers;
    bool quoted = false;
    for (size_t at = 0; at < dump.size(); at++) {
        const char c = dump[at];
        if (quoted) {
            out += c;
            if (c == '\\' && at + 1 < dump.size()) {
                out += dump[++at];
            } else if (c == '"') {
                quoted = false;
            }
            continue;
        }
        if (c == '"') {
            quoted = true;
        } else if (dump.compare(at, kKey.size(), kKey) == 0) {
            const size_t open = at + kKey.size() - 1;
            size_t end = open;
            int depth = 0;
            bool inString = false;
            for (; end < dump.size(); end++) {
                const char d = dump[end];
                if (inString) {
                    end += d == '\\' ? 1 : 0;
                    inString = d != '"';
                } else if (d == '"') {
                    inString = true;
                } else if (d == '(') {
                    depth++;
                } else if (d == ')' && --depth == 0) {
                    break;
                }
            }
            const std::string description = dump.substr(open, end + 1 - open);
            const auto [it, added] = numbers.emplace(description, numbers.size() + 1);
            if (added) {
                fonts += "f" + std::to_string(it->second) + " " + description + "\n";
            }
            out += "font=f" + std::to_string(it->second);
            at = end;
            continue;
        }
        out += c;
    }
    return fonts.empty() ? out : out + "\n== fonts\n" + fonts;
}

/// The document's golden: what the run ended with, what the host was told, the DOM, the layout and the paint.
std::string golden(const std::string& html) {
    wr::RenderOptions options;
    options.width = kWidth;
    wr_test::RenderEnv env(html, options, false, [](wr_test::HostEnv& e) {
        e.host().intlAnswer = wr_test::echoIntl;
    });
    wr_test::DriveEnd end = wr_test::driveVirtualTime(env.env(), 0, {}, 1000000);
    if (end != wr_test::DriveEnd::StepLimit && env.env().runtime().stopReason() == wr::StopReason::None) {
        end = wr_test::driveVirtualTime(env.env(), 1000, {}, 1000000);
    }
    try {
        env.render().flushForQuery(env.ctx());
    } catch (const wr::Aborted&) {
    }

    std::string out;
    out += "stop " + std::string(stopName(env.env().runtime().stopReason())) + "\n";
    out += "drive " + std::string(wr_test::driveEndName(end)) + "\n";
    for (const std::string& limit : env.render().renderLimits()) {
        out += "limit " + limit + "\n";
    }
    for (const auto& [kind, detail] : env.env().host().diagnostics) {
        out += "diagnostic " + kind + " " + oneLine(detail) + "\n";
    }
    for (const auto& [level, text] : env.env().host().logs) {
        out += "console " + std::string(levelName(level)) + " " + oneLine(text) + "\n";
    }
    for (const auto& [method, args] : env.env().host().bridgeCalls) {
        out += "bridge " + method + " " + oneLine(args) + "\n";
    }
    for (const auto& [area, entries] : env.env().host().storageCommits) {
        out += "storage " + area;
        for (const auto& [key, value] : entries) {
            out += " " + oneLine(key) + "=" + oneLine(value);
        }
        out += "\n";
    }
    out += "refused-loads " + std::to_string(env.render().refusedLoads()) + "\n";
    // The DOM without its scripts' and style sheets' text, which is the source's. A stopped runtime evaluates nothing
    // ("STOPPED"): the DOM it ended with is in the layout and paint below.
    out += "\n== dom\n" +
           env.env().eval("(() => { const root = document.documentElement.cloneNode(true);"
                          " for (const e of root.querySelectorAll('script, style')) e.textContent = '';"
                          " return root.outerHTML; })()") +
           "\n";
    out += "\n== layout\n" + env.render().layoutDump();
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    out += "\n== paint\n" + (tree ? internFonts(tree->dump()) : std::string("none\n"));
    return out;
}

/// The first differing line of two goldens, with 2 lines before it and 3 after, each cut to 200 columns.
std::string lineDifference(const std::string& expected, const std::string& actual) {
    auto split = [](const std::string& text) {
        std::vector<std::string> lines;
        std::istringstream in(text);
        for (std::string line; std::getline(in, line);) {
            lines.push_back(line.substr(0, 200));
        }
        return lines;
    };
    const std::vector<std::string> x = split(expected), y = split(actual);
    size_t at = 0;
    while (at < x.size() && at < y.size() && x[at] == y[at]) {
        at++;
    }
    std::string out = "    first differing line " + std::to_string(at + 1) + "\n";
    for (size_t i = at > 2 ? at - 2 : 0; i < at + 4 && (i < x.size() || i < y.size()); i++) {
        out += "    golden| " + (i < x.size() ? x[i] : std::string("<end>")) + "\n    actual| " +
               (i < y.size() ? y[i] : std::string("<end>")) + "\n";
    }
    return out;
}

} // namespace

WR_TEST(testTheCorpusMatchesItsGoldens) {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    setenv("TZ", "Asia/Tokyo", 1);
    tzset();
    const std::vector<std::string> files = corpusFiles();
    CHECK(files.size() >= 200);

    const char* update = std::getenv("WR_GOLDENS_UPDATE");
    const bool updating = update && std::string(update) == "1";
    std::filesystem::path writeRoot;
    if (updating) {
        if (const char* workspace = std::getenv("BUILD_WORKSPACE_DIRECTORY")) {
            writeRoot = std::filesystem::path(workspace) / kGoldensInSource;
        } else if (const char* outputs = std::getenv("TEST_UNDECLARED_OUTPUTS_DIR")) {
            writeRoot = std::filesystem::path(outputs) / "CorpusGoldens";
        }
        CHECK(!writeRoot.empty());
    }

    std::vector<std::string> missing, changed;
    std::set<std::string> written;
    for (const std::string& file : files) {
        const std::string name = shortName(file);
        const std::string actual = golden(readFile(file));
        const std::string relative = name + ".txt";
        if (updating) {
            const bool ok = writeFile(writeRoot / relative, actual);
            CHECK(ok);
            written.insert(relative);
            continue;
        }
        const std::filesystem::path stored = std::filesystem::path(kGoldensInSource) / relative;
        if (!std::filesystem::exists(stored)) {
            missing.push_back(name);
            continue;
        }
        const std::string expected = readFile(stored.string());
        if (expected != actual) {
            std::printf("  %s: differs from its golden\n%s", name.c_str(), lineDifference(expected, actual).c_str());
            changed.push_back(name);
        }
    }

    if (updating) {
        // A golden whose document the corpus no longer has goes.
        std::error_code error;
        for (auto it = std::filesystem::recursive_directory_iterator(writeRoot, error);
             it != std::filesystem::recursive_directory_iterator(); ++it) {
            if (it->is_regular_file()) {
                const std::string relative = std::filesystem::relative(it->path(), writeRoot).string();
                if (!written.contains(relative)) {
                    std::filesystem::remove(it->path());
                    std::printf("  removed %s\n", relative.c_str());
                }
            }
        }
        std::printf("\nwrote %zu goldens to %s\n", written.size(), writeRoot.c_str());
        return;
    }
    std::printf("\n%zu documents, %zu without a golden, %zu changed\n", files.size(), missing.size(), changed.size());
    for (const std::string& name : missing) {
        std::printf("  no golden: %s\n", name.c_str());
    }
    if (!missing.empty() || !changed.empty()) {
        std::printf("a change to accept: WR_GOLDENS_UPDATE=1 bazel run this target (see the header of this file)\n");
    }
    CHECK(missing.empty());
    CHECK(changed.empty());
}
