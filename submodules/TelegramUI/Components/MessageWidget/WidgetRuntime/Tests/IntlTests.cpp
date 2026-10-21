// Intl's core (V5b plan, Task 1; ECMA-402 §9 and §8.3): the lazy global, getCanonicalLocales over ICU's tag
// canonicalization, the locale resolution every constructor uses, and the host's defaults.
#include <string>

#include "Sources/Host/HostState.h"
#include "Sources/Host/ICU.h"
#include "Sources/Host/Intl.h"
#include "Sources/Support/Work.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testIntlIsALazyGlobal) {
    HostEnv env;
    CHECK_EQ(env.eval("const d = Object.getOwnPropertyDescriptor(globalThis, 'Intl');"
                      "[typeof Intl, d.writable, d.configurable, d.enumerable, Object.prototype.toString.call(Intl)].join()"),
             std::string("object,true,true,false,[object Intl]"));
    HostEnv fresh;
    CHECK_EQ(fresh.eval("delete globalThis.Intl; typeof Intl"), std::string("undefined"));
}

WR_TEST(testGetCanonicalLocales) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("Intl.getCanonicalLocales(['EN-us', 'zh-hant-tw', 'en-US']).join()"), std::string("en-US,zh-Hant-TW"));
    CHECK_EQ(env.eval("JSON.stringify([Intl.getCanonicalLocales('DE'), Intl.getCanonicalLocales()])"), std::string("[[\"de\"],[]]"));
    CHECK_EQ(env.eval("['x', 'en-US-u-ca-', '../../etc', 'x-private', 'a'.repeat(10000)].map(t => err(() => Intl.getCanonicalLocales(t))).join()"),
             std::string("RangeError,RangeError,RangeError,RangeError,RangeError"));
    CHECK_EQ(env.eval("[[1], [null]].map(l => err(() => Intl.getCanonicalLocales(l))).join()"), std::string("TypeError,TypeError"));
}

/// Review Focus 2: a long locale list is charged per entry before it is read.
WR_TEST(testALongLocaleListIsCharged) {
    HostEnv env;
    env.eval("window.many = new Array(100000).fill('en'); 1");
    JSRuntime* rt = env.runtime().jsRuntime();
    const uint64_t before = JS_GetWorkUnits(rt);
    CHECK_EQ(env.eval("Intl.getCanonicalLocales(many).join()"), std::string("en"));
    CHECK(JS_GetWorkUnits(rt) - before >= 100000 * wr::work::kNodeVisit);
}

WR_TEST(testTheHostGivesTheDefaults) {
    HostEnv env;
    CHECK_EQ(env.host().defaultTimeZone(), std::string("UTC"));
    wr::HostState::of(env.ctx()).setLocale("ru-RU");
    CHECK_EQ(wr::intl::resolveLocale(env.ctx(), {}), std::string("ru-RU"));
    wr::HostState::of(env.ctx()).setLocale("xx-unknown");
    CHECK_EQ(wr::intl::resolveLocale(env.ctx(), {}), std::string("en-US"));
    CHECK_EQ(wr::intl::resolveLocale(env.ctx(), {"de-CH-1996", "fr"}), std::string("de-CH"));
}

WR_TEST(testICUIsTheSystemsAndRecentEnough) {
    static_assert(U_ICU_VERSION_MAJOR_NUM >= 69, "the floor is ICU 69 (iOS 15.0)");
    CHECK_EQ(std::string(u_errorName(U_ZERO_ERROR)), std::string("U_ZERO_ERROR"));
    // Every weak import resolved, so Intl installed itself.
    CHECK(wr::intl::icuAvailable());
}

/// The final review's C1: the locale list is deduplicated through a hash set and holds at most kMaxLocaleList distinct
/// tags (a RangeError beyond), so many distinct tags cost linear work, not the quadratic compares of a list search.
WR_TEST(testManyDistinctLocalesAreRefused) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("err(() => Intl.getCanonicalLocales(Array.from({ length: 20000 }, (_, i) => 'en-x-' + i.toString(36))))"),
             std::string("RangeError"));
    CHECK_EQ(env.eval("Intl.getCanonicalLocales(Array.from({ length: 128 }, (_, i) => 'en-x-' + i.toString(36))).length"), std::string("128"));
}

/// The final review's I2: ICU's legacy aliases (zh_TW, zh_HK) are available locales, so they resolve to themselves and
/// format in Traditional Chinese rather than as zh.
WR_TEST(testLegacyAliasLocalesResolveToThemselves) {
    HostEnv env;
    CHECK_EQ(env.eval("[new Intl.NumberFormat('zh-TW').resolvedOptions().locale, new Intl.DateTimeFormat('zh-HK').resolvedOptions().locale].join()"),
             std::string("zh-TW,zh-HK"));
    CHECK_EQ(env.eval("new Intl.RelativeTimeFormat('zh-TW').format(1, 'day').includes('\\u5F8C')"), std::string("true"));
}
