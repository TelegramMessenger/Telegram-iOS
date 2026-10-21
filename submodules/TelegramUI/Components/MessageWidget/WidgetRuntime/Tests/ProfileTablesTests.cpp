// Profile 1's tables (V5c plan, Task 1): the generated Sources/Host/ProfileTables.inc against the vendored
// third-party/widget-sandbox/profile/profile.json it was made from, and the lookups CSS.supports and V4's validator use.
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>

#include "Sources/Host/Profile.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;
using wr::profile::CSSTable;

namespace {

std::string profileJSON() {
    const char* path = std::getenv("WR_PROFILE_JSON");
    std::ifstream in(path ? path : "", std::ios::binary);
    std::stringstream s;
    s << in.rdbuf();
    return s.str();
}

std::string joined(CSSTable table) {
    std::string out;
    for (std::string_view entry : wr::profile::table(table)) {
        out += out.empty() ? "" : "\n";
        out += entry;
    }
    return out;
}

} // namespace

WR_TEST(testTheTablesAreTheProfiles) {
    HostEnv env;
    const std::string text = profileJSON();
    CHECK(!text.empty());
    JSContext* ctx = env.ctx();
    JSValue global = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global, "profileText", JS_NewStringLen(ctx, text.data(), text.size()));
    JS_FreeValue(ctx, global);
    env.eval("window.p = JSON.parse(profileText); window.c = p.tables.css;"
             "window.j = a => [...a].sort().join('\\n'); 1");
    const struct {
        CSSTable table;
        const char* source;
    } rows[] = {
        {CSSTable::Properties, "j(c.properties)"},
        {CSSTable::Functions, "j(c.functions)"},
        {CSSTable::Units, "j(c.units)"},
        {CSSTable::DisplayValues, "j(c.values.display)"},
        {CSSTable::PositionValues, "j(c.values.position)"},
        {CSSTable::PositionRewrites, "j(Object.keys(c.rewrite.position))"},
        {CSSTable::OverflowRewrites, "j(Object.keys(c.rewrite.overflow))"},
        {CSSTable::FilterFunctions, "j(c.filterFunctions)"},
        {CSSTable::Transform3D, "j(c.transform3d)"},
        {CSSTable::GenericFonts, "j(c.fonts.generic)"},
        {CSSTable::PseudoClasses, "j([...c.pseudoClasses, ...Object.keys(c.pseudoRewrite)])"},
        {CSSTable::PseudoElements, "j(c.pseudoElements)"},
        {CSSTable::ImageTypes, "j(p.tables.images)"},
    };
    for (const auto& row : rows) {
        CHECK_EQ(joined(row.table), env.eval(row.source));
    }
    CHECK_EQ(std::to_string(wr::profile::kVersion), env.eval("String(p.profile)"));
}

WR_TEST(testTheLookups) {
    using wr::profile::contains;
    CHECK(contains(CSSTable::Properties, "display"));
    CHECK(!contains(CSSTable::Properties, "behavior"));
    CHECK(contains(CSSTable::Functions, "calc"));
    CHECK(!contains(CSSTable::Functions, "expression"));
    CHECK(contains(CSSTable::Units, "px"));
    CHECK(contains(CSSTable::Transform3D, "rotatey"));
    CHECK(contains(CSSTable::PseudoClasses, "disabled"));
    CHECK(contains(CSSTable::ImageTypes, "image/png"));
    CHECK(wr::profile::kVersion == 1);
}
