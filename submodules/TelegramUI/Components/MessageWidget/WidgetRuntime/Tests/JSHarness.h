// A runtime per test, and checks written in JavaScript.
#pragma once

#include <memory>
#include <string>
#include <string_view>

#include "Sources/Runtime/Runtime.h"
#include "Tests/wr_test.h"

namespace wr_test {

class JSEnv {
public:
    /// A runtime over `table`, with `host` (not owned: it outlives the environment) or none.
    explicit JSEnv(const wr::InterfaceTable& table, wr::Host* host = nullptr);
    ~JSEnv();
    wr::Runtime& runtime() { return *m_runtime; }
    JSContext* ctx() { return m_runtime->context(); }
    /// The completion value as a string, or "THROW <Name>: <message>".
    std::string eval(std::string_view code);

private:
    std::unique_ptr<wr::Runtime> m_runtime;
};

} // namespace wr_test

#define CHECK_JS(env, expr) \
    do { \
        std::string _r = (env).eval(std::string("String(!!(") + (expr) + "))"); \
        if (_r != "true") { \
            wr_test::failures()++; \
            std::printf("  %s:%d: CHECK_JS(%s) -> %s\n", __FILE__, __LINE__, (expr), _r.c_str()); \
        } \
    } while (0)

#define CHECK_JS_EQ(env, expr, expected) \
    do { \
        std::string _r = (env).eval(std::string("String(") + (expr) + ")"); \
        if (_r != std::string(expected)) { \
            wr_test::failures()++; \
            std::printf("  %s:%d: CHECK_JS_EQ(%s) -> %s, expected %s\n", __FILE__, __LINE__, (expr), _r.c_str(), std::string(expected).c_str()); \
        } \
    } while (0)

/// `code` throws an exception whose `name` is `name`.
#define CHECK_THROWS(env, code, name) \
    do { \
        std::string _r = (env).eval(std::string("(() => { try { ") + (code) + "; return 'no exception'; } catch (e) { return String(e.name); } })()"); \
        if (_r != std::string(name)) { \
            wr_test::failures()++; \
            std::printf("  %s:%d: CHECK_THROWS(%s) -> %s, expected %s\n", __FILE__, __LINE__, (code), _r.c_str(), name); \
        } \
    } while (0)
