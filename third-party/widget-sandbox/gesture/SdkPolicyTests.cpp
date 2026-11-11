// widget-sandbox's SDK policy (its C++ copy, sdk_policy.cpp) against the fixture its four copies share
// (fixtures/sdk-policy.json): upstream's `sdk_policy_shared_fixture` and `sdk_request_strings_refuse_surrogates_and_invalid_utf8`
// (packages/desktop/tests/test_main.cpp at the vendored tag, v0.5.0), with this file's own checks around them.
// WidgetRuntime's `setResizeAnchor` checks its edge with it, and its HostState runs the request and haptic gates and the
// state, viewer, chat type and answer checks.
#include "twidget/sdk_policy.h"
#include "twidget/json.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
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

/// A fixture's data input as a native host passes it: each field a string, or none for null / absent.
WidgetData widgetDataOf(const Json& input) {
    WidgetData d;
    if (input["chatData"].isString()) d.chatData = input["chatData"].asString();
    if (input["publicData"].isString()) d.publicData = input["publicData"].asString();
    return d;
}

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
    int anchors = 0, requests = 0, copies = 0, watches = 0, wallets = 0;
    for (const auto& c : (*root)["bridge"].arr()) {
        cases++;
        auto a = sdk::checkBridgeCall(c["method"], c["args"]);
        Json got = a ? a->toJson() : Json();
        CHECK_MSG(jsonEqual(got, c["expect"]), c["method"].dump() + " " + c["args"].dump() + " → " + got.dump());
        // Exactly one of the six: the action, setResizeAnchor's edge, the request, the text to copy, the watch flag, the wallet call.
        if (a) CHECK_MSG(int(a->action.has_value()) + int(a->resizeAnchor.has_value()) + int(a->request.has_value()) + int(a->copyText.has_value()) +
                                 int(a->watchPublicData.has_value()) + int(a->wallet.has_value()) == 1,
                         c["method"].dump());
        wallets += a && a->wallet;
        const std::string method = c["method"].isString() ? c["method"].asString() : "";
        anchors += method == "setResizeAnchor";
        requests += method == "request";
        copies += method == "copyText";
        watches += method == "watchPublicData";
    }
    // v0.1.3's fixture or later: a stale copy without the setResizeAnchor entries fails here; the bot's requests: request and copyText.
    CHECK_MSG(anchors >= 15, std::to_string(anchors) + " setResizeAnchor entries");
    CHECK_MSG(requests >= 19 && copies >= 12, std::to_string(requests) + " request, " + std::to_string(copies) + " copyText entries");
    CHECK_MSG(watches >= 6, std::to_string(watches) + " watchPublicData entries"); // round 7 or later
    int touchSteps = 0;
    for (const auto& c : (*root)["hapticGate"].arr()) {
        cases++;
        sdk::HapticGate gate;
        int i = 0;
        for (const auto& s : c["steps"].arr()) {
            // v0.2.2: {at, touch: "down" | "up"} is the host's press / release; else {at, visible, expect} is a decision.
            if (s["touch"].isString()) {
                touchSteps++;
                if (s["touch"].asString() == "down") gate.press(s["at"].asNumber());
                else gate.release(s["at"].asNumber());
            } else {
                std::string got(sdk::HapticGate::name(gate.decide(s["at"].asNumber(), s["visible"].asBool())));
                CHECK_MSG(got == s["expect"].asString(), c["name"].asString() + ", step " + std::to_string(i) + ": " + got);
            }
            i++;
        }
    }
    CHECK_MSG(touchSteps >= 6, std::to_string(touchSteps) + " touch steps"); // v0.2.2's fixture or later
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
    // Bot data and requests.
    for (const auto& c : (*root)["widgetData"].arr()) {
        cases++;
        Json got = sdk::checkWidgetData(widgetDataOf(expandRepeat(c["input"])), c["copy"].asBool()).toJson();
        CHECK_MSG(jsonEqual(got, expandRepeat(c["expect"])), (c["note"].isString() ? c["note"].asString() : c["input"].dump().substr(0, 80)) + " → " + got.dump().substr(0, 120));
    }
    int viewerShapes = 0;
    for (const auto& c : (*root)["viewer"].arr()) {
        cases++;
        // The input in the widget's field names, mapped onto the typed struct (round 6: Mini Apps' WebAppUser).
        const Json in = expandRepeat(c["input"]);
        std::optional<WidgetViewer> input;
        if (in["id"].isNumber()) {
            WidgetViewer v;
            v.id = int64_t(in["id"].asNumber());
            if (in["first_name"].isString()) v.firstName = in["first_name"].asString();
            if (in["last_name"].isString()) v.lastName = in["last_name"].asString();
            if (in["username"].isString()) v.username = in["username"].asString();
            v.isPremium = in["is_premium"].asBool();
            input = v;
        }
        Json got = sdk::checkViewer(input).toJson();
        CHECK_MSG(jsonEqual(got, expandRepeat(c["expect"])), (c["note"].isString() ? c["note"].asString() : in.dump().substr(0, 80)) + " → " + got.dump().substr(0, 160));
        viewerShapes += c["expect"].find("rejected") != nullptr;
    }
    // Round 6 or later: {viewer, rejected}; a stale copy fails here.
    CHECK_MSG(viewerShapes >= 20, std::to_string(viewerShapes) + " viewer cases with a rejected list");
    for (const auto& c : (*root)["chatType"].arr()) {
        cases++;
        Json got = orNull(sdk::checkChatType(c["input"].asString())); // null is "" (none) for a native host
        CHECK_MSG(jsonEqual(got, c["expect"]), c["input"].dump() + " → " + got.dump());
    }
    for (const auto& c : (*root)["answers"].arr()) {
        cases++;
        const Json input = expandRepeat(c["input"]);
        // The server's answer is only the result.
        WidgetRequestAnswer answer;
        if (input["result"].isString()) answer.result = input["result"].asString();
        std::optional<sdk::CheckedAnswer> checked = sdk::checkRequestAnswer(answer);
        Json got = checked ? checked->toJson() : Json();
        CHECK_MSG(jsonEqual(got, expandRepeat(c["expect"])), (c["note"].isString() ? c["note"].asString() : input.dump().substr(0, 80)) + " → " + got.dump().substr(0, 120));
    }
    for (const auto& c : (*root)["requestGate"].arr()) {
        cases++;
        sdk::RequestGate gate;
        int i = 0;
        for (const auto& s : c["steps"].arr()) {
            if (s["op"].asString() == "finish") gate.finish(s["answeredAt"].isNumber() ? std::optional<double>(s["answeredAt"].asNumber()) : std::nullopt);
            else if (s["op"].asString() == "decideWallet") {
                sdk::RequestGate::WalletConditions at{s["gesture"].asBool(), s["visible"].asBool(), s["canQuery"].asBool(), s["wallet"].asBool()};
                std::string got(sdk::requestVerdictName(gate.decideWallet(s["at"].asNumber(), at)));
                CHECK_MSG(got == s["expect"].asString(), c["name"].asString() + ", step " + std::to_string(i) + ": " + got);
            }
            else if (s["op"].asString() == "show") {
                bool busy = gate.busy();
                CHECK_MSG(gate.show(s["at"].asNumber()) == s["expect"].asBool(), c["name"].asString() + ", step " + std::to_string(i));
                CHECK_MSG(gate.busy() == busy, c["name"].asString() + ", step " + std::to_string(i) + ": show changes nothing in flight");
            } else {
                sdk::RequestGate::Conditions at{s["gesture"].asBool(), s["visible"].asBool(), s["canQuery"].asBool(), s["backgroundQuery"].asBool(), s["withWallet"].asBool(), s["wallet"].asBool()};
                std::string got(sdk::requestVerdictName(gate.decide(s["at"].asNumber(), at)));
                CHECK_MSG(got == s["expect"].asString(), c["name"].asString() + ", step " + std::to_string(i) + ": " + got);
            }
            i++;
        }
        CHECK_MSG(!c["steps"].arr().empty(), c["name"].asString());
    }
    std::vector<std::string> verdicts;
    for (const auto& c : (*root)["requestRefusals"].arr()) {
        cases++;
        sdk::RequestVerdict all[] = {sdk::RequestVerdict::Foreground, sdk::RequestVerdict::Background, sdk::RequestVerdict::Held, sdk::RequestVerdict::Granted,
                                     sdk::RequestVerdict::Disabled, sdk::RequestVerdict::NoWallet, sdk::RequestVerdict::Busy, sdk::RequestVerdict::NoActivation,
                                     sdk::RequestVerdict::RateLimited};
        const sdk::RequestVerdict* v = std::find_if(std::begin(all), std::end(all), [&](sdk::RequestVerdict x) { return sdk::requestVerdictName(x) == c["verdict"].asString(); });
        CHECK_MSG(v != std::end(all), c["verdict"].asString());
        if (v == std::end(all)) continue;
        verdicts.push_back(c["verdict"].asString());
        std::optional<std::string_view> refusal = sdk::requestRefusal(*v);
        Json got = refusal ? Json(*refusal) : Json();
        CHECK_MSG(jsonEqual(got, c["expect"]), c["verdict"].asString() + " → " + got.dump());
    }
    CHECK_MSG(verdicts.size() == 9, std::to_string(verdicts.size()) + " verdicts"); // every verdict once
    CHECK_MSG(wallets == 3, std::to_string(wallets) + " valid wallet calls");
    // The wallet (docs/sdk-v1.md §2.18): TON Connect's transaction and signData payload, checked.
    for (const auto& c : (*root)["walletTransactions"].arr()) {
        cases++;
        std::optional<WalletTransaction> tx = sdk::checkWalletTransaction(expandRepeat(c["input"]));
        Json got = tx ? tx->toJson() : Json();
        CHECK_MSG(jsonEqual(got, expandRepeat(c["expect"])), (c["note"].isString() ? c["note"].asString() : c["input"].dump().substr(0, 100)) + " → " + got.dump().substr(0, 120));
    }
    for (const auto& c : (*root)["signDataPayloads"].arr()) {
        cases++;
        std::optional<SignDataPayload> p = sdk::checkSignDataPayload(expandRepeat(c["input"]));
        Json got = p ? p->toJson() : Json();
        CHECK_MSG(jsonEqual(got, expandRepeat(c["expect"])), (c["note"].isString() ? c["note"].asString() : c["input"].dump().substr(0, 100)) + " → " + got.dump().substr(0, 120));
    }
    // The server's spec or later (the server's flags, answers of a result only, no NUL in data); a stale copy fails here.
    int flagged = 0, shows = 0, nulData = 0, edits = 0;
    for (const auto& c : (*root)["requestGate"].arr())
        for (const auto& st : c["steps"].arr()) { flagged += st.find("canQuery") != nullptr; shows += st["op"].asString() == "show"; }
    for (const auto& c : (*root)["widgetData"].arr()) nulData += c.find("copy") != nullptr && c["input"].dump().find("\\u0000") != std::string::npos;
    for (const auto& c : (*root)["answers"].arr()) edits += c["expect"].find("edit") != nullptr;
    CHECK_MSG(flagged >= 10 && shows >= 2 && nulData >= 1 && edits == 0,
              std::to_string(flagged) + " gate steps with canQuery, " + std::to_string(shows) + " show steps, " + std::to_string(nulData) + " NUL data cases, " + std::to_string(edits) + " answers with an edit");
    // Round 4 (previews): the methods a preview may call.
    for (const auto& c : (*root)["previewMethods"].arr()) {
        cases++;
        CHECK_MSG(sdk::allowedInPreview(c["method"].asString()) == c["allowed"].asBool(), c["method"].dump());
    }
    std::printf("    %d fixture cases\n", cases);
    CHECK(cases > 150);
    for (const char* section : {"links", "haptics", "bridge", "hapticGate", "themeParams", "locales", "storage", "utf8",
                                "widgetData", "viewer", "chatType", "answers", "requestGate", "requestRefusals", "previewMethods", "walletTransactions", "signDataPayloads"})
        CHECK_MSG((*root)[section].size() > 0, section);
}

/// Upstream's test, unchanged: what the fixture cannot carry. The strings of the bot's data and requests refuse a lone
/// surrogate (its WTF-8 form, as QuickJS and the engine's `Surrogates::Keep` parse give it) and invalid UTF-8 everywhere a
/// string leaves the widget or enters it; lengths are UTF-8 bytes for the data and UTF-16 code units for copyText;
/// out-of-range ids and viewers are none.
void sdkRequestStringsRefuseSurrogatesAndInvalidUtf8() {
    const std::string lone = "\xED\xA0\x80", loneLow = "\xED\xB0\x80", emoji = "\xF0\x9F\x98\x80";
    for (const std::string& bad : {"a" + lone, loneLow + "b", lone + loneLow /* CESU-8, not a pair in UTF-8 */, std::string("\xFF"), std::string("x\xC3"), std::string("\xC0\xAF")}) {
        CHECK_MSG(!sdk::checkRequestData(bad), bad);
        CHECK_MSG(!sdk::checkCopyText(bad), bad);
        CHECK_MSG(!sdk::checkWidgetDataValue(bad), bad);
        CHECK(!sdk::checkRequestAnswer(WidgetRequestAnswer{bad}));
        sdk::CheckedWidgetData d = sdk::checkWidgetData(WidgetData{bad, std::string("ok")}, false);
        CHECK(!d.chatData && d.publicData == std::string("ok") && d.rejected == std::vector<std::string>{"chatData"});
    }
    CHECK(sdk::checkRequestData(emoji) == emoji);
    CHECK(sdk::checkRequestData(std::string("a\0b", 3)).has_value()); // a NUL is a character like any other
    auto call = Json::parse("[\"request\",[1,\"a\\ud800\"]]", Json::Surrogates::Keep);
    CHECK(call && !sdk::checkBridgeCall((*call)[0], (*call)[1]));
    call = Json::parse("[\"copyText\",[\"\\udc00\"]]", Json::Surrogates::Keep);
    CHECK(call && !sdk::checkBridgeCall((*call)[0], (*call)[1]));
    // UTF-16 code units: an emoji is 2, so 128 fit and 129 do not; 256 Cyrillic letters (512 bytes) fit.
    CHECK(sdk::utf16Length(emoji) == 2 && sdk::utf16Length("\xD0\xB6") == 1 && sdk::utf16Length("a" + emoji + "\xE2\x82\xAC") == 4);
    std::string emojis, cyrillic;
    for (int i = 0; i < 128; i++) emojis += emoji;
    for (int i = 0; i < 256; i++) cyrillic += "\xD0\xB6";
    CHECK(sdk::checkCopyText(emojis).has_value() && !sdk::checkCopyText(emojis + "a"));
    CHECK(sdk::checkCopyText(cyrillic).has_value() && !sdk::checkCopyText(cyrillic + "a"));
    // Ids: integers 1 … 2^31 − 1, as numbers only.
    for (const char* args : {"[1e0,\"x\"]", "[2147483647.0,\"x\"]"}) CHECK_MSG(sdk::checkBridgeCall(Json("request"), *Json::parse(args)).has_value(), args);
    for (const char* args : {"[0.5,\"x\"]", "[1e10,\"x\"]", "[true,\"x\"]", "[null,\"x\"]", "[[1],\"x\"]", "[-0,\"x\"]"})
        CHECK_MSG(!sdk::checkBridgeCall(Json("request"), *Json::parse(args)), args);
    // Viewers outside 1 … 2^53 − 1.
    CHECK(!sdk::checkViewer(WidgetViewer{INT64_MIN}).viewer && !sdk::checkViewer(WidgetViewer{INT64_MAX}).viewer && !sdk::checkViewer(std::nullopt).viewer);
    CHECK(sdk::checkViewer(WidgetViewer{sdk::MAX_VIEWER_ID}).viewer->id == sdk::MAX_VIEWER_ID);
    // The viewer's names refuse WTF-8 surrogates and invalid UTF-8; the username is ASCII only (a Cyrillic letter is 2
    // bytes, so a byte count would not catch "аннаx" either way).
    for (const std::string& bad : {"A" + lone, std::string("\xFF"), std::string("x\xC3")}) {
        WidgetViewer v{7};
        v.firstName = bad;
        v.lastName = "Lee";
        sdk::CheckedViewer c = sdk::checkViewer(v);
        CHECK_MSG(c.viewer && !c.viewer->firstName && c.viewer->lastName == std::string("Lee") && c.rejected == std::vector<std::string>{"first_name"}, bad);
    }
    {
        WidgetViewer v{7};
        v.username = "\xD0\xB0nnax";
        v.isPremium = false;
        sdk::CheckedViewer c = sdk::checkViewer(v);
        CHECK(c.viewer && !c.viewer->username && c.rejected == std::vector<std::string>{"username"});
        CHECK(sdk::viewerJson(*c.viewer).dump() == "{\"id\":7}");
        std::string names;
        for (int i = 0; i < 64; i++) names += "\xD0\xB6"; // 64 Cyrillic letters: 128 bytes, 64 UTF-16 code units
        v = WidgetViewer{7};
        v.firstName = names;
        CHECK(sdk::checkViewer(v).viewer->firstName == names);
        v.firstName = names + "a";
        CHECK(sdk::checkViewer(v).rejected == std::vector<std::string>{"first_name"});
    }
    CHECK(sdk::viewerFieldRule("first_name") == "not text of 1–64 UTF-16 code units" && sdk::viewerFieldRule("username") == "not 5–32 characters of A–Z, a–z, 0–9 and _" &&
          sdk::viewerFieldRule("is_premium") == "not a boolean");
    // A client failure outside the three is FAILED; the privileged methods now include copyText, not request.
    CHECK(sdk::requestFailureCode(WidgetRequestFailure::Timeout) == "TIMEOUT" && sdk::requestFailureCode(WidgetRequestFailure::RateLimited) == "RATE_LIMITED");
    CHECK(sdk::requestFailureCode(WidgetRequestFailure::Failed) == "FAILED" && sdk::requestFailureCode(WidgetRequestFailure(42)) == "FAILED");
    CHECK(sdk::isPrivilegedMethod("copyText") && !sdk::isPrivilegedMethod("request"));
}

} // namespace

int main() {
    const char* fixture = std::getenv("WS_SDK_POLICY");
    CHECK_MSG(fixture != nullptr, "WS_SDK_POLICY is not set");
    if (fixture) {
        sdkPolicySharedFixture(fixture);
    }
    const int fixtureFailures = g_failures;
    std::printf("%s (%d failed checks)\n", fixtureFailures == 0 ? "PASS sdk_policy_shared_fixture" : "FAIL sdk_policy_shared_fixture", fixtureFailures);
    sdkRequestStringsRefuseSurrogatesAndInvalidUtf8();
    const int stringFailures = g_failures - fixtureFailures;
    std::printf("%s (%d failed checks)\n", stringFailures == 0 ? "PASS sdk_request_strings_refuse_surrogates_and_invalid_utf8" : "FAIL sdk_request_strings_refuse_surrogates_and_invalid_utf8", stringFailures);
    return g_failures == 0 ? 0 : 1;
}
