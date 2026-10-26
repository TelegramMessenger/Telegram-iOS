// Intl's core (V5b plan, Task 1; ECMA-402 §9 and §8.3): the lazy global, getCanonicalLocales, the locale every request
// names, and the `intl` capability itself: requests written as widget-sandbox's shim writes them, charged before the host
// is asked, untouched by a widget's toJSON, and answers taken as the host's text.
#include <string>

#include "Sources/Host/HostState.h"
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
    CHECK_EQ(env.eval("Intl.getCanonicalLocales(['DE-latn-ch-U-CA-GREGORY', 'sr-CYRL-419', 'en-X-PRIV-AB']).join()"),
             std::string("de-Latn-CH-u-ca-gregory,sr-Cyrl-419,en-x-priv-ab"));
    CHECK_EQ(env.eval("['x', 'en-US-u-ca-', '../../etc', 'x-private', 'a'.repeat(10000), 'en-a-b', 'de-1996-1996']"
                      ".map(t => err(() => Intl.getCanonicalLocales(t))).join()"),
             std::string("RangeError,RangeError,RangeError,RangeError,RangeError,RangeError,RangeError"));
    CHECK_EQ(env.eval("[[1], [null]].map(l => err(() => Intl.getCanonicalLocales(l))).join()"), std::string("TypeError,TypeError"));
    CHECK_EQ(env.eval("Intl.NumberFormat.supportedLocalesOf(['EN-us', 'xx']).join()"), std::string("en-US,xx"));
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

/// A request names the first requested locale, else the host's, never with a unicode extension (Foundation's Locale,
/// the glue's, misreads one into a locale it cannot format with, and the glue traps on that).
WR_TEST(testTheLocaleARequestNames) {
    HostEnv env;
    wr::HostState::of(env.ctx()).setLocale("ru-RU");
    CHECK_EQ(wr::intl::resolveLocale(env.ctx(), {}), std::string("ru-RU"));
    CHECK_EQ(wr::intl::resolveLocale(env.ctx(), {"de-CH-1996", "fr"}), std::string("de-CH-1996"));
    wr::HostState::of(env.ctx()).setLocale("not a tag");
    CHECK_EQ(wr::intl::resolveLocale(env.ctx(), {}), std::string("en-US"));
    CHECK_EQ(wr::intl::withoutUnicodeExtensions("th-TH-u-nu-thai-ca-buddhist-x-y"), std::string("th-TH-x-y"));
    env.host().intlAnswer = wr_test::echoIntl;
    wr::HostState::of(env.ctx()).setLocale("ru-RU");
    env.eval("(1).toLocaleString(); new Intl.NumberFormat(['ar-EG-u-nu-latn', 'en']).format(1)");
    CHECK_EQ(env.host().intlRequests.size(), size_t(2));
    CHECK_EQ(env.host().intlRequests[0], std::string("{\"kind\":\"number\",\"locale\":\"ru-RU\",\"opts\":{},\"value\":1}"));
    CHECK_EQ(env.host().intlRequests[1], std::string("{\"kind\":\"number\",\"locale\":\"ar-EG\",\"opts\":{},\"value\":1}"));
    env.eval("new Date(0).toLocaleDateString('hi-IN-u-nu-deva-ca-indian-x-y', { dateStyle: 'full' }); new Intl.Collator('de-u-co-phonebk-kn').compare('a', 'b')");
    CHECK_EQ(env.host().intlRequests[2],
             std::string("{\"kind\":\"dateMethod\",\"method\":\"toLocaleDateString\",\"locale\":\"hi-IN-x-y\",\"opts\":{\"dateStyle\":\"full\"},\"value\":0}"));
    CHECK_EQ(env.host().intlRequests[3], std::string("{\"kind\":\"compare\",\"locale\":\"de\",\"opts\":{},\"a\":\"a\",\"b\":\"b\"}"));
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

/// A request is charged before the host is asked (work::kIntlRequest, a date's kinds more, and its bytes), its answer's
/// bytes after; an answer past kMaxIntlAnswer is refused.
WR_TEST(testARequestIsChargedAndItsAnswerBounded) {
    HostEnv env;
    env.eval(kErr);
    env.host().intlAnswer = wr_test::echoIntl;
    JSRuntime* rt = env.runtime().jsRuntime();
    uint64_t before = JS_GetWorkUnits(rt);
    CHECK_EQ(env.eval("new Intl.ListFormat('en').format(['" + std::string(100000, 'a') + "']).length > 100000"), std::string("true"));
    const std::string& request = env.host().intlRequests.back();
    CHECK(JS_GetWorkUnits(rt) - before >= wr::work::kIntlRequest + 2 * request.size() * wr::work::kIntlByte);
    // A date's kinds at their own rates: the host may make a formatter for each, and one per field for parts.
    env.eval("window.dtf = new Intl.DateTimeFormat('en'); 1");
    before = JS_GetWorkUnits(rt);
    env.eval("dtf.format(0); 1");
    const uint64_t format = JS_GetWorkUnits(rt) - before;
    CHECK(format >= wr::work::kIntlDateRequest);
    before = JS_GetWorkUnits(rt);
    env.eval("dtf.formatToParts(0); 1");
    CHECK(JS_GetWorkUnits(rt) - before >= wr::work::kIntlDateRequest + wr::work::kIntlDateParts);
    env.host().intlAnswer = [](std::string_view) { return std::string(wr::intl::kMaxIntlAnswer + 1, 'x'); };
    CHECK_EQ(env.eval("err(() => (1).toLocaleString())"), std::string("RangeError"));
    before = JS_GetWorkUnits(rt);
    env.host().intlAnswer = [](std::string_view) { return std::string(wr::intl::kMaxIntlAnswer, 'x'); };
    CHECK_EQ(env.eval("(1).toLocaleString().length"), std::string("4194304"));
    CHECK(JS_GetWorkUnits(rt) - before >= wr::intl::kMaxIntlAnswer * wr::work::kIntlByte);
}

/// A request is written in native code, never through JSON.stringify: a widget's toJSON reaches none of it.
WR_TEST(testAWidgetsToJSONCannotReachARequest) {
    HostEnv env;
    env.host().intlAnswer = wr_test::echoIntl;
    env.eval("Object.prototype.toJSON = () => 'hijacked'; Array.prototype.toJSON = () => 'hijacked'; String.prototype.toJSON = () => 'hijacked';"
             "new Intl.ListFormat('en', { type: 'disjunction' }).format(['a\"b', '\\u0000']); 1");
    CHECK_EQ(env.host().intlRequests.back(),
             std::string("{\"kind\":\"list\",\"locale\":\"en\",\"opts\":{\"type\":\"disjunction\"},\"value\":[\"a\\\"b\",\"\\u0000\"]}"));
}

/// The answer is the host's text as it is: a U+0000 or any character survives, parts and options are its JSON, and an
/// answer that is not the JSON a kind needs is the shim's fallback (an empty list or object).
WR_TEST(testAnAnswerIsTheHostsText) {
    HostEnv env;
    env.host().intlAnswer = [](std::string_view) { return std::string("a\0b\xE2\x82\xAC", 6); };
    CHECK_EQ(env.eval("const s = (1).toLocaleString(); [s.length, s.charCodeAt(1), s.charCodeAt(3)].join()"), std::string("4,0,8364"));
    env.host().intlAnswer = [](std::string_view) { return std::string("not json"); };
    CHECK_EQ(env.eval("JSON.stringify(new Intl.NumberFormat('en').formatToParts(1))"), std::string("[]"));
    CHECK_EQ(env.eval("new Intl.NumberFormat('en').resolvedOptions().locale"), std::string("en"));
    env.host().intlAnswer = [](std::string_view) { return std::string("[1]"); };
    CHECK_EQ(env.eval("JSON.stringify(new Intl.DateTimeFormat('en').resolvedOptions())"),
             std::string("{\"locale\":\"en\",\"calendar\":\"gregory\",\"numberingSystem\":\"latn\",\"year\":\"numeric\",\"month\":\"numeric\",\"day\":\"numeric\"}"));
}

/// A host without locale data (the default) answers "": formats are empty, parts empty, plural "other", resolvedOptions
/// ours alone, and comparisons in code-unit order.
WR_TEST(testWithoutLocaleData) {
    HostEnv env;
    CHECK_EQ(env.eval("[(1).toLocaleString(), new Date(0).toLocaleString(), new Intl.PluralRules('en').select(1), new Intl.ListFormat('en').format(['a']),"
                      " new Intl.RelativeTimeFormat('en').format(1, 'day'), new Intl.NumberFormat('en').formatToParts(1).length].join('|')"),
             std::string("||other|||0"));
    CHECK_EQ(env.eval("[['b', 'a', 'B'].sort((x, y) => x.localeCompare(y)).join(''), new Intl.Collator('en').compare('a', 'a')].join()"),
             std::string("Bab,0"));
}
