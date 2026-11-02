// A small test framework for WidgetRuntime's host tests: cases register themselves; `main` (TestMain.cpp) runs the
// ones whose names contain argv[1] (all when absent) and fails the process when any CHECK failed.
#pragma once

#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace wr_test {

struct Case {
    const char* name;
    void (*run)();
};

inline std::vector<Case>& cases() {
    static std::vector<Case> all;
    return all;
}

inline int& failures() {
    static int count = 0;
    return count;
}

struct Register {
    Register(const char* name, void (*run)()) { cases().push_back({name, run}); }
};

inline int runAll(int argc, char** argv) {
    const char* filter = argc > 1 ? argv[1] : nullptr;
    int ran = 0;
    for (const Case& c : cases()) {
        if (filter && !std::strstr(c.name, filter)) {
            continue;
        }
        int before = failures();
        // A test that lets an exception out (an Aborted from a stop it did not expect) fails, and the rest still run.
        try {
            c.run();
        } catch (...) {
            failures()++;
            std::printf("  an exception escaped the test\n");
        }
        ran++;
        std::printf("%s %s\n", failures() == before ? "PASS" : "FAIL", c.name);
        std::fflush(stdout);
    }
    std::printf("%d cases, %d failed checks\n", ran, failures());
    return failures() == 0 && ran > 0 ? 0 : 1;
}

} // namespace wr_test

#define WR_TEST(name) \
    static void name(); \
    static wr_test::Register name##_registration(#name, name); \
    static void name()

#define CHECK(cond) \
    do { \
        if (!(cond)) { \
            wr_test::failures()++; \
            std::printf("  %s:%d: CHECK(%s)\n", __FILE__, __LINE__, #cond); \
        } \
    } while (0)

#define CHECK_EQ(a, b) \
    do { \
        auto _a = (a); \
        auto _b = (b); \
        if (!(_a == _b)) { \
            wr_test::failures()++; \
            std::printf("  %s:%d: CHECK_EQ(%s, %s)\n", __FILE__, __LINE__, #a, #b); \
        } \
    } while (0)
