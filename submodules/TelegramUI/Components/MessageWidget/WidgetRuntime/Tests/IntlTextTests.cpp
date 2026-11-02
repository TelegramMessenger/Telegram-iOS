// Intl.PluralRules, RelativeTimeFormat, ListFormat and Collator, and String.prototype.localeCompare (V5b plan, Task 4;
// ECMA-402 §16, §17, §13, §10): the requests (`plural`, `relative`, `list`, `compare`), the plural categories found
// through the host, resolvedOptions, the refusals, huge inputs bounded and charged, and the locale case mapping that
// stays the system ICU's. The host is the echo glue (wr_test::echoIntl) unless a case says otherwise.
#include <string>

#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testTheRequests) {
    HostEnv env;
    env.host().intlAnswer = wr_test::echoIntl;
    CHECK_EQ(env.eval("new Intl.PluralRules('ru-RU', { type: 'ordinal', minimumFractionDigits: 1 }).select(3)"),
             std::string("{\"kind\":\"plural\",\"locale\":\"ru-RU\",\"opts\":{\"type\":\"ordinal\",\"minimumFractionDigits\":1},\"value\":3}"));
    CHECK_EQ(env.eval("new Intl.RelativeTimeFormat('en', { numeric: 'auto', style: 'short' }).format(-1.5, 'days')"),
             std::string("{\"kind\":\"relative\",\"locale\":\"en\",\"opts\":{\"style\":\"short\",\"numeric\":\"auto\"},\"value\":-1.5,\"unit\":\"days\"}"));
    CHECK_EQ(env.eval("new Intl.ListFormat('en', { type: 'unit' }).format(new Set(['a', 'b']))"),
             std::string("{\"kind\":\"list\",\"locale\":\"en\",\"opts\":{\"type\":\"unit\"},\"value\":[\"a\",\"b\"]}"));
    CHECK_EQ(env.eval("new Intl.ListFormat('en').format()"),
             std::string("{\"kind\":\"list\",\"locale\":\"en\",\"opts\":{},\"value\":[]}"));
    env.host().intlAnswer = [](std::string_view) { return std::string("-1"); };
    CHECK_EQ(env.eval("[new Intl.Collator('de', { sensitivity: 'base', numeric: true }).compare('a', 1), 'x'.localeCompare('y', 'sv')].join()"),
             std::string("-1,-1"));
    CHECK_EQ(env.host().intlRequests[env.host().intlRequests.size() - 2],
             std::string("{\"kind\":\"compare\",\"locale\":\"de\",\"opts\":{\"numeric\":true,\"sensitivity\":\"base\"},\"a\":\"a\",\"b\":\"1\"}"));
    CHECK_EQ(env.host().intlRequests.back(), std::string("{\"kind\":\"compare\",\"locale\":\"sv\",\"opts\":{},\"a\":\"x\",\"b\":\"y\"}"));
}

/// PluralRules' categories are the ones the host's rules give a set of samples, under the type alone; "other" always.
WR_TEST(testPluralCategoriesComeFromTheHost) {
    HostEnv env;
    env.host().intlAnswer = [](std::string_view request) {
        // ru's cardinal rules, for integers: one (1, 21, 101), few (2–4, 22–24), many (0, 5–20, 25–30, 100), other (fractions).
        const size_t at = request.find("\"value\":");
        const double n = std::stod(std::string(request.substr(at + 8)));
        const long i = long(n);
        if (n != double(i)) {
            return std::string("other");
        }
        return std::string(i % 10 == 1 && i % 100 != 11 ? "one" : (i % 10 >= 2 && i % 10 <= 4 && (i % 100 < 12 || i % 100 > 14)) ? "few" : "many");
    };
    CHECK_EQ(env.eval("JSON.stringify(new Intl.PluralRules('ru', { minimumFractionDigits: 2 }).resolvedOptions().pluralCategories)"),
             std::string("[\"one\",\"few\",\"many\",\"other\"]"));
    CHECK(env.host().intlRequests.back().find("\"opts\":{\"type\":\"cardinal\"}") != std::string::npos);
    CHECK_EQ(env.eval("const pr = new Intl.PluralRules('ru').resolvedOptions(); [pr.locale, pr.type, pr.minimumFractionDigits, pr.maximumFractionDigits].join()"),
             std::string("ru,cardinal,0,3"));
    CHECK_EQ(env.eval("[new Intl.PluralRules('ru').select(Infinity), new Intl.PluralRules('ru').select(NaN)].join()"), std::string("other,other"));
}

WR_TEST(testResolvedOptions) {
    HostEnv env;
    CHECK_EQ(env.eval("JSON.stringify(new Intl.RelativeTimeFormat('en-u-nu-arab', { numeric: 'auto', numberingSystem: 'thai' }).resolvedOptions())"),
             std::string("{\"locale\":\"en-u-nu-arab\",\"style\":\"long\",\"numeric\":\"auto\",\"numberingSystem\":\"latn\"}"));
    CHECK_EQ(env.eval("JSON.stringify(new Intl.ListFormat('en', { type: 'disjunction', style: 'narrow' }).resolvedOptions())"),
             std::string("{\"locale\":\"en\",\"type\":\"disjunction\",\"style\":\"narrow\"}"));
    CHECK_EQ(env.eval("JSON.stringify(new Intl.Collator('de', { numeric: true, collation: 'phonebk' }).resolvedOptions())"),
             std::string("{\"locale\":\"de\",\"usage\":\"sort\",\"sensitivity\":\"variant\",\"ignorePunctuation\":false,\"collation\":\"phonebk\","
                         "\"numeric\":true,\"caseFirst\":\"false\"}"));
    CHECK_EQ(env.eval("const co = new Intl.Collator('en', { usage: 'search', collation: 'phonebk', caseFirst: 'upper', ignorePunctuation: true }).resolvedOptions();"
                      " [co.usage, co.collation, co.caseFirst, co.ignorePunctuation].join()"),
             std::string("search,default,upper,true"));
}

WR_TEST(testWhatTheTextFormatsRefuse) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("const rtf = new Intl.RelativeTimeFormat('en'); [err(() => rtf.format(1, 'fortnight')), err(() => rtf.format(Infinity, 'day')),"
                      " err(() => new Intl.ListFormat('en').format(['a', 1])), err(() => new Intl.ListFormat('en', { type: 'bogus' })),"
                      " err(() => new Intl.ListFormat('en', 5)), err(() => Intl.PluralRules.prototype.select.call({}, 1)),"
                      " err(() => Object.getOwnPropertyDescriptor(Intl.Collator.prototype, 'compare').get.call({})),"
                      " err(() => String.prototype.localeCompare.call(null, 'a')), err(() => new Intl.Collator('en', { collation: 'x' }))].join()"),
             std::string("RangeError,RangeError,TypeError,RangeError,TypeError,TypeError,TypeError,TypeError,RangeError"));
    CHECK_EQ(env.eval("[Intl.PluralRules, Intl.RelativeTimeFormat, Intl.ListFormat, Intl.Collator].map(C => Object.prototype.toString.call(new C('en'))).join()"),
             std::string("[object Intl.PluralRules],[object Intl.RelativeTimeFormat],[object Intl.ListFormat],[object Intl.Collator]"));
    CHECK_EQ(env.eval("[err(() => Intl.Collator('en')), err(() => Intl.PluralRules('en')), err(() => Intl.ListFormat('en'))].join()"),
             std::string("ok,TypeError,TypeError"));
}

/// Review Focus 2: huge inputs are charged before the work and capped.
WR_TEST(testHugeInputsAreBounded) {
    HostEnv env;
    env.eval(kErr);
    env.host().intlAnswer = [](std::string_view) { return std::string("0"); };
    CHECK_EQ(env.eval("const over = 'a'.repeat(1048577); err(() => over.localeCompare(over))"), std::string("RangeError"));
    CHECK_EQ(env.eval("const big = 'a'.repeat(1000000); big.localeCompare(big)"), std::string("0"));
    // A list of a million items is refused at the item cap (the final review's I1).
    env.eval("window.million = new Array(1000000).fill('a'); 1");
    CHECK_EQ(env.eval("(() => { try { new Intl.ListFormat('en', { type: 'unit', style: 'narrow' }).format(million) } catch (e) { return e.name + ': ' + e.message } })()"),
             std::string("RangeError: Intl.ListFormat.prototype.format: the list has more than 10000 items."));
}

/// The final review's I1 and M6: a list holds at most kMaxListItems items, empty strings included, read one at a time
/// from its iterator, which is closed when an item is refused (ECMA-402 StringListFromIterable).
WR_TEST(testAListIsBoundedByItsItemCount) {
    HostEnv env;
    env.eval(kErr);
    env.host().intlAnswer = wr_test::echoIntl;
    CHECK_EQ(env.eval("(() => { try { new Intl.ListFormat('en').format(new Array(1000000).fill('')) } catch (e) { return e.name + ': ' + e.message } })()"),
             std::string("RangeError: Intl.ListFormat.prototype.format: the list has more than 10000 items."));
    CHECK_EQ(env.eval("let closed = false, after = false; function* g() { try { yield 'a'; yield 1; after = true; yield 'b' } finally { closed = true } }"
                      "[err(() => new Intl.ListFormat('en').format(g())), closed, after].join()"),
             std::string("TypeError,true,false"));
    CHECK_EQ(env.eval("JSON.parse(new Intl.ListFormat('en', { type: 'unit', style: 'narrow' }).format(new Array(10000).fill('a'))).value.length"),
             std::string("10000"));
}

/// v0.1.1 plan, Task 10 (ECMA-402 TransformCase): toLocaleUpperCase and toLocaleLowerCase follow the language's own
/// case rules, the first requested locale's or else the host's; other languages keep the root's mapping, the engine's
/// own even when a widget replaces toUpperCase; a long string is mapped whole and charged for. The system ICU's public
/// case mapping, no request.
WR_TEST(testLocaleCaseMapping) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("['i'.toLocaleUpperCase('tr'), 'I'.toLocaleLowerCase('tr-TR'), 'i'.toLocaleUpperCase(['az', 'en']),"
                      " 'i'.toLocaleUpperCase('en'), 'straße'.toLocaleUpperCase('de'), 'i'.toLocaleUpperCase(),"
                      " 'Ά'.toLocaleUpperCase('el')].join()"),
             std::string("İ,ı,İ,I,STRASSE,I,Α"));
    CHECK_EQ(env.eval("[err(() => String.prototype.toLocaleUpperCase.call(null)), err(() => 'a'.toLocaleLowerCase('not a tag!'))].join()"),
             std::string("TypeError,RangeError"));
    // The root's mapping is the engine's own, kept at install.
    CHECK_EQ(env.eval("String.prototype.toUpperCase = () => 'replaced'; 'abc'.toLocaleUpperCase('en')"), std::string("ABC"));
    // The host's locale when none is requested.
    wr::HostState::of(env.ctx()).setLocale("tr-TR");
    CHECK_EQ(env.eval("'i'.toLocaleUpperCase()"), std::string("İ"));
    CHECK_EQ(env.eval("'i'.repeat(4000000).toLocaleUpperCase('tr').length"), std::string("4000000"));
    CHECK(env.host().intlRequests.empty());
}
