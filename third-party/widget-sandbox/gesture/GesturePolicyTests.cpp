// widget-sandbox's gesture policy (its C++ copy, gesture_policy.cpp) against the fixture the four copies share
// (fixtures/gesture-policy.json): upstream's `gesture_policy_shared_fixture` (packages/desktop/tests/test_main.cpp at the
// vendored tag), with this file's own checks around it.
#include "twidget/gesture_policy.h"
#include "twidget/json.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

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

Json claimJson(const WidgetGestureClaim& c) {
    Json o = Json::object();
    o.set("x", c.x).set("y", c.y).set("hold", c.hold);
    return o;
}

/// The TS `GestureVerdict` shape (owner, gesture, cancel always; action, event, edge only when set), or null.
Json verdictJson(const std::optional<GestureVerdict>& v) {
    if (!v) return Json();
    Json o = Json::object();
    o.set("owner", gesture::name(v->owner)).set("gesture", gesture::name(v->gesture)).set("cancel", v->cancel);
    if (v->action) o.set("action", gesture::name(*v->action));
    if (v->event) o.set("event", gesture::name(*v->event));
    if (v->edge) o.set("edge", true);
    return o;
}

/// Upstream's test, unchanged but for the fixture's path.
void gesturePolicySharedFixture(const char* fixturePath) {
    auto root = Json::parse(readFile(fixturePath));
    CHECK_MSG(root.has_value(), std::string("fixture missing: ") + fixturePath);
    if (!root) return;
    const std::pair<std::string_view, double> constants[] = {
        {"TOUCH_SLOP_PX", gesture::TOUCH_SLOP_PX}, {"HOLD_MS", gesture::HOLD_MS}, {"DOUBLE_TAP_MS", gesture::DOUBLE_TAP_MS},
        {"DOUBLE_TAP_SLOP_PX", gesture::DOUBLE_TAP_SLOP_PX}, {"EDGE_STRIP_PX", gesture::EDGE_STRIP_PX}};
    CHECK((*root)["constants"].size() == std::size(constants));
    for (const auto& [name, value] : (*root)["constants"].obj()) {
        auto it = std::find_if(std::begin(constants), std::end(constants), [&](const auto& c) { return c.first == name; });
        CHECK_MSG(it != std::end(constants) && it->second == value.asNumber(), name);
    }
    int claims = 0;
    for (const auto& c : (*root)["claims"].arr()) {
        claims++;
        std::vector<std::string> touchActions;
        for (const auto& ta : c["touchActions"].arr()) touchActions.push_back(ta.asString());
        Json got = claimJson(gesture::claimOf(touchActions, c["prevented"].asBool()));
        CHECK_MSG(jsonEqual(got, c["expect"]), c["touchActions"].dump() + " prevented " + c["prevented"].dump() + " → " + got.dump());
    }
    int cases = 0, steps = 0, claimed = 0;
    for (const auto& c : (*root)["cases"].arr()) {
        cases++;
        GestureArbiter a;
        int i = 0;
        for (const auto& s : c["steps"].arr()) {
            steps++;
            std::string where = c["name"].asString() + ": step " + std::to_string(i++) + " " + s.dump().substr(0, 80);
            std::optional<GestureVerdict> got;
            if (const Json* p = s.find("down")) {
                std::string pointer = s["pointer"].isString() ? s["pointer"].asString() : "touch";
                std::optional<PointerKind> kind;
                for (PointerKind k : {PointerKind::Touch, PointerKind::Pen, PointerKind::Mouse}) if (gesture::name(k) == pointer) kind = k;
                CHECK_MSG(kind.has_value(), where + ": unknown pointer");
                WidgetGestureClaim claim;
                if (const Json* given = s.find("claimed")) {
                    claimed++;
                    CHECK_MSG(given->isObject() && (*given)["x"].isBool() && (*given)["y"].isBool() && (*given)["hold"].isBool(), where + ": claimed is not {x, y, hold}");
                    claim = {(*given)["x"].asBool(), (*given)["y"].asBool(), (*given)["hold"].asBool()};
                } else {
                    claim = gesture::claimOf({s["claim"].isString() ? s["claim"].asString() : "auto"});
                }
                got = a.down((*p)[0].asNumber(), (*p)[1].asNumber(), (*p)[2].asNumber(), claim, kind.value_or(PointerKind::Touch), s["button"].asInt(0));
            } else if (const Json* p = s.find("move")) {
                got = a.move((*p)[0].asNumber(), (*p)[1].asNumber(), (*p)[2].asNumber());
            } else if (const Json* p = s.find("up")) {
                got = a.up((*p)[0].asNumber(), (*p)[1].asNumber(), (*p)[2].asNumber());
            } else if (const Json* t = s.find("tick")) {
                got = a.tick(t->asNumber());
            } else if (s["cancel"].asBool()) {
                a.cancel();
                continue;
            } else if (const Json* deadline = s.find("holdDeadline")) {
                std::optional<double> d = a.holdDeadline();
                Json dj = d ? Json(*d) : Json();
                CHECK_MSG(jsonEqual(dj, *deadline), where + " → " + dj.dump());
                continue;
            } else {
                CHECK_MSG(false, where + ": unknown step");
                continue;
            }
            Json gj = verdictJson(got);
            CHECK_MSG(s.find("expect") && jsonEqual(gj, s["expect"]), where + " → " + gj.dump());
        }
    }
    std::printf("    %d claims, %d cases, %d steps (%d with a claim given as is)\n", claims, cases, steps, claimed);
    // v0.1.3's fixture (vertical drags are the chat's) or later: a stale copy fails here.
    CHECK(claims >= 21 && cases >= 28 && steps >= 174 && claimed >= 3);
    // A verdict and NO_CLAIM are values: a caller may keep one, and nothing changes the other.
    GestureArbiter a;
    GestureVerdict v = a.down(0, 100, 50, gesture::claimOf({"auto"}));
    a.tick(500);
    CHECK(verdictJson(v).dump() == "{\"owner\":\"pending\",\"gesture\":\"press\",\"cancel\":false}");
    static_assert(gesture::NO_CLAIM == WidgetGestureClaim{false, false, false});
}

} // namespace

int main() {
    const char* fixture = std::getenv("WS_GESTURE_POLICY");
    CHECK_MSG(fixture != nullptr, "WS_GESTURE_POLICY is not set");
    if (fixture) {
        gesturePolicySharedFixture(fixture);
    }
    std::printf("%s (%d failed checks)\n", g_failures == 0 ? "PASS gesture_policy_shared_fixture" : "FAIL gesture_policy_shared_fixture", g_failures);
    return g_failures == 0 ? 0 : 1;
}
