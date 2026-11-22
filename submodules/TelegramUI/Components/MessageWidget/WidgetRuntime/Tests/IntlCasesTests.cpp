// widget-sandbox v0.1.1's Intl fixture as a protocol check: every case run as a widget would make it (Tests/IntlCases.js)
// over a host that knows only the fixture, answering a request with V8's answer to the fixture's request equal to it
// (compared as parsed JSON). A case passes only when the runtime sent exactly the request widget-sandbox's shim sends
// for that call and turned the answer into what a widget sees: what the glue answers is checked on its own, by
// //third-party/widget-sandbox:WidgetSandboxIntlTests, and end to end on iOS by WidgetRuntimeIOS's WRIntlCasesTests
// (the drift list's `ios` lines). Case mapping makes no request: it is the host's system ICU here.
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <map>
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

/// JSON with its object keys sorted, in a QuickJS context of its own (never the widget's, which is mid-call when a
/// request arrives).
class Normalizer {
public:
    Normalizer() : m_rt(JS_NewRuntime()), m_ctx(JS_NewContext(m_rt)) {
        const char* code = "(s => { const sort = v => Array.isArray(v) ? v.map(sort) : (v !== null && typeof v === 'object')"
                           " ? Object.keys(v).sort().reduce((o, k) => (o[k] = sort(v[k]), o), {}) : v;"
                           " return JSON.stringify(sort(JSON.parse(s))) })";
        m_function = JS_Eval(m_ctx, code, std::strlen(code), "<normalize>", JS_EVAL_TYPE_GLOBAL);
    }
    ~Normalizer() {
        JS_FreeValue(m_ctx, m_function);
        JS_FreeContext(m_ctx);
        JS_FreeRuntime(m_rt);
    }
    std::string operator()(std::string_view json) {
        JSValue argument = JS_NewStringLen(m_ctx, json.data(), json.size());
        JSValue result = JS_Call(m_ctx, m_function, JS_UNDEFINED, 1, &argument);
        JS_FreeValue(m_ctx, argument);
        std::string out;
        if (const char* text = JS_IsException(result) ? nullptr : JS_ToCString(m_ctx, result)) {
            out = text;
            JS_FreeCString(m_ctx, text);
        } else {
            JS_FreeValue(m_ctx, JS_GetException(m_ctx));
        }
        JS_FreeValue(m_ctx, result);
        return out;
    }
    /// Each case's request, normalized, and V8's answer as the glue's text: a string as it is, parts and options as JSON.
    std::map<std::string, std::string> answers(const std::string& fixture) {
        const char* code = "(f => JSON.stringify(JSON.parse(f).cases.map(c => [JSON.stringify(c.request),"
                           " typeof c.expected === 'string' ? c.expected : JSON.stringify(c.expected)])))";
        JSValue function = JS_Eval(m_ctx, code, std::strlen(code), "<answers>", JS_EVAL_TYPE_GLOBAL);
        JSValue argument = JS_NewStringLen(m_ctx, fixture.data(), fixture.size());
        JSValue list = JS_Call(m_ctx, function, JS_UNDEFINED, 1, &argument);
        JS_FreeValue(m_ctx, argument);
        JS_FreeValue(m_ctx, function);
        std::map<std::string, std::string> out;
        const char* text = JS_IsException(list) ? nullptr : JS_ToCString(m_ctx, list);
        JS_FreeValue(m_ctx, list);
        if (!text) {
            return out;
        }
        // Back through the same context: [[request, answer], …].
        JSValue pairs = JS_ParseJSON(m_ctx, text, std::strlen(text), "<pairs>");
        JS_FreeCString(m_ctx, text);
        int64_t length = 0;
        JS_GetLength(m_ctx, pairs, &length);
        for (int64_t i = 0; i < length; i++) {
            JSValue pair = JS_GetPropertyUint32(m_ctx, pairs, uint32_t(i));
            JSValue request = JS_GetPropertyUint32(m_ctx, pair, 0);
            JSValue answer = JS_GetPropertyUint32(m_ctx, pair, 1);
            const char* r = JS_ToCString(m_ctx, request);
            const char* a = JS_ToCString(m_ctx, answer);
            out[(*this)(r)] = a;
            JS_FreeCString(m_ctx, r);
            JS_FreeCString(m_ctx, a);
            JS_FreeValue(m_ctx, answer);
            JS_FreeValue(m_ctx, request);
            JS_FreeValue(m_ctx, pair);
        }
        JS_FreeValue(m_ctx, pairs);
        return out;
    }

private:
    JSRuntime* m_rt;
    JSContext* m_ctx;
    JSValue m_function;
};

} // namespace

WR_TEST(testTheRuntimeSpeaksTheShimsProtocol) {
    HostEnv env;
    const std::string fixture = dataFile("intl-cases.json");
    const std::string script = dataFile("IntlCases.js");
    CHECK(!fixture.empty() && !script.empty());
    Normalizer normalize;
    const std::map<std::string, std::string> answers = normalize.answers(fixture);
    CHECK(answers.size() > 100);
    std::set<std::string> unknown;
    env.host().intlAnswer = [&](std::string_view request) {
        auto found = answers.find(normalize(request));
        if (found == answers.end()) {
            unknown.insert(std::string(request));
            return std::string();
        }
        return found->second;
    };
    JSContext* ctx = env.ctx();
    JSValue global = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global, "intlCasesText", JS_NewStringLen(ctx, fixture.data(), fixture.size()));
    JS_FreeValue(ctx, global);
    const std::string result = env.eval(script);
    std::istringstream lines(result);
    std::string line;
    int differ = 0;
    while (std::getline(lines, line)) {
        if (!line.empty()) {
            std::printf("  differs: %s\n", line.c_str());
            differ++;
        }
    }
    for (const std::string& request : unknown) {
        std::printf("  a request the shim does not send: %s\n", request.c_str());
    }
    std::printf("  %zu requests, %d cases differ, %zu unknown requests\n", env.host().intlRequests.size(), differ, unknown.size());
    CHECK(differ == 0);
    CHECK(unknown.empty());
}
