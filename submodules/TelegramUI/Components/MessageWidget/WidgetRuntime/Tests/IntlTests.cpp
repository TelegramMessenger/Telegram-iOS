// Intl's core (V5b plan, Task 1; ECMA-402 §9 and §8.3): the lazy global, getCanonicalLocales, the locale every request
// names, and the `intl` capability itself: requests written as widget-sandbox's shim writes them, untouched by a
// widget's toJSON, and answers taken as the host's text.
#include <string>

#include "Sources/Host/HostState.h"
#include "Sources/Host/Intl.h"
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

/// A request names the first requested locale, else the host's, with the unicode extension keywords its constructor
/// reads (ECMA-402 ResolveLocale; testOnlyARelevantSupportedKeywordReachesTheHost).
WR_TEST(testTheLocaleARequestNames) {
    HostEnv env;
    wr::HostState::of(env.ctx()).setLocale("ru-RU");
    CHECK_EQ(wr::intl::resolveLocale(env.ctx(), {}, wr::intl::RelevantKeys::NumberFormat), std::string("ru-RU"));
    CHECK_EQ(wr::intl::resolveLocale(env.ctx(), {"de-CH-1996", "fr"}, wr::intl::RelevantKeys::NumberFormat), std::string("de-CH-1996"));
    wr::HostState::of(env.ctx()).setLocale("not a tag");
    CHECK_EQ(wr::intl::resolveLocale(env.ctx(), {}, wr::intl::RelevantKeys::NumberFormat), std::string("en-US"));
    env.host().intlAnswer = wr_test::echoIntl;
    wr::HostState::of(env.ctx()).setLocale("ru-RU");
    env.eval("(1).toLocaleString(); new Intl.NumberFormat(['ar-EG-u-nu-latn', 'en']).format(1)");
    CHECK_EQ(env.host().intlRequests.size(), size_t(2));
    CHECK_EQ(env.host().intlRequests[0], std::string("{\"kind\":\"number\",\"locale\":\"ru-RU\",\"opts\":{},\"value\":1}"));
    // The tag as the widget wrote it, its unicode extension reduced to the keywords its constructor reads (here `nu`).
    CHECK_EQ(env.host().intlRequests[1], std::string("{\"kind\":\"number\",\"locale\":\"ar-EG-u-nu-latn\",\"opts\":{},\"value\":1}"));
    env.eval("new Date(0).toLocaleDateString('hi-IN-u-nu-deva-ca-indian-x-y', { dateStyle: 'full' }); new Intl.Collator('de-u-co-phonebk-kn').compare('a', 'b')");
    CHECK_EQ(env.host().intlRequests[2],
             std::string("{\"kind\":\"dateMethod\",\"method\":\"toLocaleDateString\",\"locale\":\"hi-IN-u-ca-indian-nu-deva\",\"opts\":{\"dateStyle\":\"full\"},\"value\":0}"));
    CHECK_EQ(env.host().intlRequests[3], std::string("{\"kind\":\"compare\",\"locale\":\"de-u-co-phonebk-kn\",\"opts\":{},\"a\":\"a\",\"b\":\"b\"}"));
}

/// ECMA-402 ResolveLocale (follow-ups review, C1 and I1): a request keeps only the unicode extension keywords its
/// constructor reads (NumberFormat and RelativeTimeFormat nu; DateTimeFormat ca, hc, nu; Collator co, kf, kn; PluralRules
/// and ListFormat none), each with a value this client supports, sorted by key. Other keywords, attributes and unknown
/// values never reach the glue: an unknown numbering system makes Foundation's relative formatter trap (the app's
/// crash), and the glue reads plural rules from a language key an extension breaks. Other extensions and private use
/// are dropped too, as a resolved locale has none of them (they reached the glue's plural key as `@…=` keywords).
WR_TEST(testOnlyARelevantSupportedKeywordReachesTheHost) {
    HostEnv env;
    env.host().intlAnswer = wr_test::echoIntl;
    auto localeOf = [&](const char* script) {
        env.host().intlRequests.clear();
        env.eval(script);
        if (env.host().intlRequests.empty()) {
            return std::string("no request");
        }
        const std::string& request = env.host().intlRequests.back();
        const size_t at = request.find("\"locale\":\"");
        if (at == std::string::npos) {
            return std::string("no locale");
        }
        return request.substr(at + 10, request.find('"', at + 10) - at - 10);
    };
    CHECK_EQ(localeOf("new Intl.NumberFormat('en-u-nu-bogus').format(1)"), std::string("en"));
    CHECK_EQ(localeOf("new Intl.NumberFormat('en-u-nu').format(1)"), std::string("en"));
    CHECK_EQ(localeOf("new Intl.NumberFormat('en-u-ca-japanese-nu-thai').format(1)"), std::string("en-u-nu-thai"));
    CHECK_EQ(localeOf("new Intl.NumberFormat('en-u-attr-nu-thai').format(1)"), std::string("en-u-nu-thai"));
    CHECK_EQ(localeOf("new Intl.DateTimeFormat('en-u-nu-japanfin-hc-h23-ca-japanese').format(0)"), std::string("en-u-ca-japanese-hc-h23"));
    CHECK_EQ(localeOf("new Intl.DateTimeFormat('en-u-ca-bogus-hc-h99').format(0)"), std::string("en"));
    CHECK_EQ(localeOf("new Intl.DateTimeFormat('ar-u-ca-islamic-civil').format(0)"), std::string("ar-u-ca-islamic-civil"));
    CHECK_EQ(localeOf("new Intl.RelativeTimeFormat('en-u-nu-yes').format(1, 'day')"), std::string("en"));
    CHECK_EQ(localeOf("new Intl.RelativeTimeFormat('fa-u-nu-arabext').format(1, 'day')"), std::string("fa-u-nu-arabext"));
    CHECK_EQ(localeOf("new Intl.PluralRules('ar-u-nu-arab').select(2)"), std::string("ar"));
    CHECK_EQ(localeOf("new Intl.ListFormat('en-u-nu-thai').format(['a'])"), std::string("en"));
    CHECK_EQ(localeOf("new Intl.Collator('de-u-co-bogus-kn-false').compare('a', 'b')"), std::string("de-u-kn-false"));
    CHECK_EQ(localeOf("new Intl.Collator('de-u-kn-true-co-phonebk').compare('a', 'b')"), std::string("de-u-co-phonebk-kn"));
    // ECMA-402: a `co` keyword may not name `standard` or `search`.
    CHECK_EQ(localeOf("new Intl.Collator('de-u-co-standard').compare('a', 'b')"), std::string("de"));
    CHECK_EQ(localeOf("new Intl.Collator('de-u-co-search').compare('a', 'b')"), std::string("de"));
    CHECK_EQ(localeOf("new Intl.NumberFormat('de-t-en-u-nu-thai-x-a').format(1)"), std::string("de-u-nu-thai"));
    CHECK_EQ(localeOf("new Intl.PluralRules('ar-t-en').select(2)"), std::string("ar"));
    CHECK_EQ(localeOf("new Intl.DateTimeFormat('ja-JP-a-bc-u-ca-japanese-x-y').format(0)"), std::string("ja-JP-u-ca-japanese"));
    CHECK_EQ(localeOf("(1).toLocaleString('en-u-nu-bogus')"), std::string("en"));
    CHECK_EQ(localeOf("new Date(0).toLocaleDateString('en-u-nu-bogus-ca-roc')"), std::string("en-u-ca-roc"));
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

/// An answer past kMaxIntlAnswer is refused.
WR_TEST(testARequestsAnswerIsBounded) {
    HostEnv env;
    env.eval(kErr);
    env.host().intlAnswer = wr_test::echoIntl;
    CHECK_EQ(env.eval("new Intl.ListFormat('en').format(['" + std::string(100000, 'a') + "']).length > 100000"), std::string("true"));
    env.host().intlAnswer = [](std::string_view) { return std::string(wr::intl::kMaxIntlAnswer + 1, 'x'); };
    CHECK_EQ(env.eval("err(() => (1).toLocaleString())"), std::string("RangeError"));
    env.host().intlAnswer = [](std::string_view) { return std::string(wr::intl::kMaxIntlAnswer, 'x'); };
    CHECK_EQ(env.eval("(1).toLocaleString().length"), std::string("4194304"));
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
