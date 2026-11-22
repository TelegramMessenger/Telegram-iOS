// html5lib's tree-construction tests for a harness: the .dat reader, the expected-failures list, the skip rule, gumbo's
// own tree of a case, and the driver that runs the cases and counts them. GumboHtml5libTests (gumbo's tree) and
// WidgetRuntime's WidgetRuntimeBuilderHtml5libTests (the DOM its Builder makes from gumbo's tree) both run on it, so
// the two read, skip and count the same cases the same way.
#pragma once

#include <cstdio>
#include <fstream>
#include <functional>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include "gumbo.h"
#include "tree_dump.h"

namespace gumbo_test {

/// html5lib-tests 9329e64's tree-construction suite (tests/html5lib/tree-construction): every case the reader finds,
/// the skipped ones included. A run that reads another number fails, so a truncated, empty or unread .dat cannot pass.
/// The files are the BUILD's Html5libTreeConstruction glob, and the cases are their "#data" lines. `grep -c '^#data$'`
/// reports 1,709 in 54 files only because it takes the three *-unsafe.dat files, which hold NUL bytes, for binary and
/// counts nothing in them; `grep -a` counts 1,792 in 57.
inline constexpr int kExpectedCases = 1792;
inline constexpr int kExpectedFiles = 57;

struct Case {
    std::string data;
    std::string expected;
    std::string fragmentContext;
    bool scriptingOn = false;
};

/// A fragment case's context element: "td" is HTML's td, "svg path" SVG's path, "math mi" MathML's mi.
struct FragmentContext {
    GumboNamespaceEnum ns = GUMBO_NAMESPACE_HTML;
    std::string localName;
};

inline FragmentContext fragmentContextOf(const Case& c) {
    FragmentContext context;
    context.localName = c.fragmentContext;
    if (context.localName.rfind("svg ", 0) == 0) {
        context.ns = GUMBO_NAMESPACE_SVG;
        context.localName = context.localName.substr(4);
    } else if (context.localName.rfind("math ", 0) == 0) {
        context.ns = GUMBO_NAMESPACE_MATHML;
        context.localName = context.localName.substr(5);
    }
    return context;
}

/// gumbo has no scripting flag (it parses as with scripting off), and only knows the contexts it has tags for.
inline bool skips(const Case& c) {
    return c.scriptingOn || (!c.fragmentContext.empty() && gumbo_tag_enum(fragmentContextOf(c).localName.c_str()) == GUMBO_TAG_UNKNOWN);
}

inline bool readFile(const char* path, std::string* out) {
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        return false;
    }
    std::stringstream buffer;
    buffer << in.rdbuf();
    *out = buffer.str();
    return true;
}

inline std::vector<Case> readCases(const std::string& text) {
    std::vector<Case> cases;
    size_t pos = 0;
    while ((pos = text.find("#data\n", pos)) != std::string::npos) {
        size_t next = text.find("\n#data\n", pos + 6);
        size_t end = next == std::string::npos ? text.size() : next + 1;
        std::string block = text.substr(pos + 6, end - (pos + 6));
        pos = end;
        Case c;
        // An empty #data puts "#errors" at the block's start, with no newline before it (tests_innerHTML_1.dat:80, the
        // only one). M1a's reader looked only for "\n#errors\n" and read that whole block as the case's data.
        c.data = block.rfind("#errors\n", 0) == 0 ? std::string() : block.substr(0, block.find("\n#errors\n"));
        size_t fragment = block.find("\n#document-fragment\n");
        if (fragment != std::string::npos) {
            size_t start = fragment + 20;
            c.fragmentContext = block.substr(start, block.find('\n', start) - start);
        }
        c.scriptingOn = block.find("\n#script-on\n") != std::string::npos;
        std::string expected = block.substr(block.find("\n#document\n") + 11);
        while (!expected.empty() && expected.back() == '\n') {
            expected.pop_back();
        }
        c.expected = expected + "\n";
        cases.push_back(c);
    }
    return cases;
}

/// The expected-failures file: a "<file>.dat:<index>" per line, optionally followed by whitespace and a reason. A line
/// that starts with '#' is a comment.
inline bool readExpectedFailures(const char* path, std::set<std::string>* out) {
    std::string text;
    if (!readFile(path, &text)) {
        return false;
    }
    std::istringstream lines(text);
    std::string line;
    while (std::getline(lines, line)) {
        std::string id = line.substr(0, line.find_first_of(" \t"));
        if (!id.empty() && id[0] != '#') {
            out->insert(id);
        }
    }
    return true;
}

/// gumbo's tree of the case, parsed with its default options, in html5lib's format.
inline std::string gumboTree(const Case& c) {
    GumboOptions options = kGumboDefaultOptions;
    if (!c.fragmentContext.empty()) {
        FragmentContext context = fragmentContextOf(c);
        options.fragment_namespace = context.ns;
        options.fragment_context = gumbo_tag_enum(context.localName.c_str());
    }
    GumboOutput* output = gumbo_parse_with_options(&options, c.data.data(), c.data.size());
    std::string tree = dumpTree(output, !c.fragmentContext.empty());
    gumbo_destroy_output(&options, output);
    return tree;
}

/// A harness's tree of a case, in html5lib's format: the case passes when it equals the case's #document.
using TreeOf = std::function<std::string(const Case&)>;
/// What else to print about a case that failed unexpectedly, after its input and the two trees.
using Explain = std::function<std::string(const Case&)>;

/// A harness's main. `argv` is <expected-failures.txt> <file.dat>...; every case `skips` keeps goes through `treeOf`.
/// A case in the expected failures must fail: one that passes fails the run until it is removed, and so does a listed
/// id that names no case run (a typo, or a case that is skipped). A file that cannot be read or gives no case fails
/// it too, and so does a total other than kExpectedCases cases in kExpectedFiles files. Prints a summary; returns the
/// exit status.
inline int runSuite(int argc, char** argv, const TreeOf& treeOf, const Explain& explain = nullptr) {
    if (argc < 3) {
        std::fprintf(stderr, "usage: %s <expected-failures.txt> <file.dat>...\n", argv[0]);
        return 2;
    }
    std::set<std::string> expectedFailures;
    if (!readExpectedFailures(argv[1], &expectedFailures)) {
        std::fprintf(stderr, "cannot read %s\n", argv[1]);
        return 2;
    }
    int passed = 0, failedAsExpected = 0, skipped = 0, failures = 0, total = 0, files = 0;
    for (int f = 2; f < argc; f++) {
        std::string path = argv[f];
        std::string name = path.substr(path.find_last_of('/') + 1);
        std::string text;
        if (!readFile(argv[f], &text)) {
            std::fprintf(stderr, "%s: cannot read\n", path.c_str());
            failures++;
            continue;
        }
        std::vector<Case> cases = readCases(text);
        files++;
        if (cases.empty()) {
            std::fprintf(stderr, "%s: no cases\n", name.c_str());
            failures++;
        }
        for (size_t i = 0; i < cases.size(); i++) {
            const Case& c = cases[i];
            total++;
            if (skips(c)) {
                skipped++;
                continue;
            }
            std::string id = name + ":" + std::to_string(i);
            std::string tree = treeOf(c);
            bool pass = tree == c.expected;
            // Taken out of the list as it runs: what is left at the end names no case that ran.
            bool expectedToFail = expectedFailures.erase(id) > 0;
            if (pass && !expectedToFail) {
                passed++;
            } else if (!pass && expectedToFail) {
                failedAsExpected++;
            } else {
                failures++;
                std::fprintf(stderr, "%s: %s\n", id.c_str(), pass ? "passes now; remove it from the expected failures" : "FAILED");
                if (!pass) {
                    std::fprintf(stderr, "  input:\n%s\n  expected:\n%s  actual:\n%s%s", c.data.c_str(), c.expected.c_str(), tree.c_str(),
                                 explain ? explain(c).c_str() : "");
                }
            }
        }
    }
    for (const std::string& id : expectedFailures) {
        std::fprintf(stderr, "%s: listed in the expected failures, but no such case ran\n", id.c_str());
        failures++;
    }
    if (total != kExpectedCases || files != kExpectedFiles) {
        std::fprintf(stderr, "%d cases in %d files; expected %d in %d (the vendored suite changed, or a file was not read)\n", total, files,
                     kExpectedCases, kExpectedFiles);
        failures++;
    }
    std::printf("%d cases in %d files: %d passed, %d failed as expected, %d skipped, %d unexpected\n", total, files, passed, failedAsExpected,
                skipped, failures);
    return failures == 0 ? 0 : 1;
}

} // namespace gumbo_test
