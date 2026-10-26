// widget-sandbox's SDK policy (its C++ copy, sdk_policy.cpp) against the fixture its four copies share
// (fixtures/sdk-policy.json): upstream's `sdk_policy_shared_fixture` (packages/desktop/tests/test_main.cpp at the
// vendored tag), with this file's own checks around it. WidgetRuntime's `setResizeAnchor` checks its edge with it.
#include "twidget/sdk_policy.h"
#include "twidget/json.h"

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <optional>
#include <sstream>
#include <string>

using namespace twidget;

namespace {

int g_failures = 0;

#define CHECK(cond) do { if (!(cond)) { g_failures++; std::fprintf(stderr, "  FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); } } while (0)
#define CHECK_MSG(cond, msg) do { if (!(cond)) { g_failures++; std::fprintf(stderr, "  FAIL %s:%d: %s — %s\n", __FILE__, __LINE__, #cond, std::string(msg).c_str()); } } while (0)

std::string readFile(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    std::ostringstream ss;
    ss << in.rdbuf();
    return ss.str();
}

/// Deep equality of JSON values, object members in any order (what node:assert's deepEqual compares).
bool jsonEqual(const Json& a, const Json& b) {
    if (a.type() != b.type()) return false;
    switch (a.type()) {
    case Json::Type::Null: return true;
    case Json::Type::Bool: return a.asBool() == b.asBool();
    case Json::Type::Number: return a.asNumber() == b.asNumber();
    case Json::Type::String: return a.asString() == b.asString();
    case Json::Type::Array:
        if (a.size() != b.size()) return false;
        for (size_t i = 0; i < a.size(); i++) if (!jsonEqual(a[i], b[i])) return false;
        return true;
    case Json::Type::Object:
        if (a.size() != b.size()) return false;
        for (const auto& [k, v] : a.obj()) { const Json* w = b.find(k); if (!w || !jsonEqual(v, *w)) return false; }
        return true;
    }
    return false;
}

/// `{ "repeat": [s, n] }` in the fixture stands for s repeated n times.
Json expandRepeat(const Json& v) {
    if (v.isArray()) {
        Json out = Json::array();
        for (const auto& x : v.arr()) out.push(expandRepeat(x));
        return out;
    }
    if (v.isObject()) {
        if (v.size() == 1 && v["repeat"].isArray()) {
            std::string s;
            for (int i = 0; i < v["repeat"][1].asInt(); i++) s += v["repeat"][0].asString();
            return Json(s);
        }
        Json out = Json::object();
        for (const auto& [k, x] : v.obj()) out.set(k, expandRepeat(x));
        return out;
    }
    return v;
}

Json orNull(const std::optional<std::string>& s) { return s ? Json(*s) : Json(); }

/// Upstream's test, unchanged but for the fixture's path.
void sdkPolicySharedFixture(const char* fixturePath) {
    auto root = Json::parse(readFile(fixturePath));
    CHECK_MSG(root.has_value(), std::string("fixture missing: ") + fixturePath);
    if (!root) return;
    int cases = 0;
    for (const auto& c : (*root)["links"].arr()) {
        cases++;
        Json got = orNull(sdk::checkLinkValue(c["method"].asString(), c["url"]));
        CHECK_MSG(jsonEqual(got, c["expect"]), c["method"].asString() + " " + c["url"].dump().substr(0, 100) + " → " + got.dump().substr(0, 100));
    }
    for (const auto& c : (*root)["haptics"].arr()) {
        cases++;
        auto h = sdk::checkHaptic(c["args"]);
        Json got;
        if (h) { got = Json::object(); got.set("haptic", h->haptic); if (h->value) got.set("value", *h->value); }
        CHECK_MSG(jsonEqual(got, c["expect"]), c["args"].dump() + " → " + got.dump());
    }
    int anchors = 0;
    for (const auto& c : (*root)["bridge"].arr()) {
        cases++;
        auto a = sdk::checkBridgeCall(c["method"], c["args"]);
        Json got = a ? a->toJson() : Json();
        CHECK_MSG(jsonEqual(got, c["expect"]), c["method"].dump() + " " + c["args"].dump() + " → " + got.dump());
        // setResizeAnchor carries the edge and no action; every other call an action and no edge.
        if (a) CHECK_MSG(a->action.has_value() != a->resizeAnchor.has_value(), c["method"].dump());
        if (c["method"].isString() && c["method"].asString() == "setResizeAnchor") anchors++;
    }
    // v0.1.3's fixture or later: a stale copy without the setResizeAnchor entries fails here.
    CHECK_MSG(anchors >= 15, std::to_string(anchors) + " setResizeAnchor entries");
    for (const auto& c : (*root)["hapticGate"].arr()) {
        cases++;
        sdk::HapticGate gate;
        int i = 0;
        for (const auto& s : c["steps"].arr()) {
            std::string got(sdk::HapticGate::name(gate.decide(s["at"].asNumber(), s["visible"].asBool())));
            CHECK_MSG(got == s["expect"].asString(), c["name"].asString() + ", step " + std::to_string(i) + ": " + got);
            i++;
        }
    }
    for (const auto& c : (*root)["themeParams"].arr()) {
        cases++;
        Json got = sdk::themeParamsJson(sdk::checkThemeParams(c["input"]));
        CHECK_MSG(jsonEqual(got, c["expect"]), c["input"].dump() + " → " + got.dump());
    }
    for (const auto& c : (*root)["locales"].arr()) {
        cases++;
        Json got = orNull(sdk::checkLocaleValue(c["input"]));
        CHECK_MSG(jsonEqual(got, c["expect"]), c["input"].dump() + " → " + got.dump());
    }
    for (const auto& c : (*root)["storage"].arr()) {
        cases++;
        auto commit = sdk::checkStorageCommit(expandRepeat(c["input"]));
        Json got = commit ? commit->toJson() : Json();
        CHECK_MSG(jsonEqual(got, expandRepeat(c["expect"])), c["note"].isString() ? c["note"].asString() : c["input"].dump());
    }
    for (const auto& c : (*root)["utf8"].arr()) {
        cases++;
        CHECK_MSG(sdk::utf8Length(c["s"].asString()) == size_t(c["bytes"].asInt()), c["s"].asString());
    }
    std::printf("    %d fixture cases\n", cases);
    CHECK(cases > 150);
    for (const char* section : {"links", "haptics", "bridge", "hapticGate", "themeParams", "locales", "storage", "utf8"})
        CHECK_MSG((*root)[section].size() > 0, section);
}

} // namespace

int main() {
    const char* fixture = std::getenv("WS_SDK_POLICY");
    CHECK_MSG(fixture != nullptr, "WS_SDK_POLICY is not set");
    if (fixture) {
        sdkPolicySharedFixture(fixture);
    }
    std::printf("%s (%d failed checks)\n", g_failures == 0 ? "PASS sdk_policy_shared_fixture" : "FAIL sdk_policy_shared_fixture", g_failures);
    return g_failures == 0 ? 0 : 1;
}
