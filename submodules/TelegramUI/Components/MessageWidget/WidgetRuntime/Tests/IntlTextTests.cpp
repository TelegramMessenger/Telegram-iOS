// Intl.PluralRules, RelativeTimeFormat, ListFormat and Collator, and String.prototype.localeCompare (V5b plan, Task 4;
// ECMA-402 §16, §17, §13, §10): the conformance set's values, the other options, the refusals, and huge inputs bounded
// and charged. Expected strings are ICU's own output.
#include <string>

#include "Sources/Host/HostState.h"
#include "Sources/Support/Work.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testTheTextConformanceValues) {
    HostEnv env;
    CHECK_EQ(env.eval("new Intl.PluralRules('en-US').select(1) + ',' + new Intl.PluralRules('ru-RU').select(3)"), std::string("one,few"));
    CHECK_EQ(env.eval("new Intl.RelativeTimeFormat('en', { numeric: 'auto' }).format(-1, 'day')"), std::string("yesterday"));
    CHECK_EQ(env.eval("new Intl.ListFormat('en', { type: 'conjunction' }).format(['a', 'b', 'c'])"), std::string("a, b, and c"));
    CHECK_EQ(env.eval("new Intl.Collator('en').compare('a', 'B') < 0"), std::string("true"));
    CHECK_EQ(env.eval("['b', 'a', 'C'].sort((x, y) => x.localeCompare(y)).join()"), std::string("a,b,C"));
}

WR_TEST(testTheOtherTextOptions) {
    HostEnv env;
    CHECK_EQ(env.eval("const ord = new Intl.PluralRules('en', { type: 'ordinal' }); [ord.select(2), ord.select(3), ord.select(11),"
                      " new Intl.PluralRules('en', { minimumFractionDigits: 1 }).select(1)].join()"),
             std::string("two,few,other,other"));
    CHECK_EQ(env.eval("JSON.stringify(new Intl.PluralRules('ru').resolvedOptions().pluralCategories)"),
             std::string("[\"one\",\"few\",\"many\",\"other\"]"));
    CHECK_EQ(env.eval("const rtf = new Intl.RelativeTimeFormat('en'); [rtf.format(-1, 'days'), rtf.format(2, 'hour'),"
                      " new Intl.RelativeTimeFormat('en', { style: 'short' }).format(3, 'month')].join('|')"),
             std::string("1 day ago|in 2 hours|in 3 mo."));
    CHECK_EQ(env.eval("[new Intl.ListFormat('en', { type: 'disjunction' }).format(['a', 'b', 'c']),"
                      " new Intl.ListFormat('en', { type: 'unit', style: 'narrow' }).format(['a', 'b', 'c']),"
                      " new Intl.ListFormat('en').format('xy'), new Intl.ListFormat('en').format()].join('|')"),
             std::string("a, b, or c|a b c|x and y|"));
    CHECK_EQ(env.eval("[new Intl.Collator('en', { sensitivity: 'base' }).compare('a', 'A'),"
                      " new Intl.Collator('en', { numeric: true }).compare('2', '10'), new Intl.Collator('en').compare('2', '10'),"
                      " ['b', 'a'].sort(new Intl.Collator('en').compare).join(''), 'a'.localeCompare('A', 'en', { sensitivity: 'base' })].join()"),
             std::string("0,-1,1,ab,0"));
    CHECK_EQ(env.eval("const co = new Intl.Collator('de', { numeric: true }).resolvedOptions(); [co.locale, co.usage, co.sensitivity, co.numeric, co.caseFirst].join()"),
             std::string("de,sort,variant,true,false"));
}

WR_TEST(testWhatTheTextFormatsRefuse) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("const rtf = new Intl.RelativeTimeFormat('en'); [err(() => rtf.format(1, 'fortnight')), err(() => rtf.format(Infinity, 'day')),"
                      " err(() => new Intl.ListFormat('en').format(['a', 1])), err(() => new Intl.ListFormat('en', { type: 'bogus' })),"
                      " err(() => new Intl.ListFormat('en', 5)), err(() => Intl.PluralRules.prototype.select.call({}, 1)),"
                      " err(() => Object.getOwnPropertyDescriptor(Intl.Collator.prototype, 'compare').get.call({})),"
                      " err(() => String.prototype.localeCompare.call(null, 'a'))].join()"),
             std::string("RangeError,RangeError,TypeError,RangeError,TypeError,TypeError,TypeError,TypeError"));
    CHECK_EQ(env.eval("[Intl.PluralRules, Intl.RelativeTimeFormat, Intl.ListFormat, Intl.Collator].map(C => Object.prototype.toString.call(new C('en'))).join()"),
             std::string("[object Intl.PluralRules],[object Intl.RelativeTimeFormat],[object Intl.ListFormat],[object Intl.Collator]"));
    CHECK_EQ(env.eval("[err(() => Intl.Collator('en')), err(() => Intl.PluralRules('en')), err(() => Intl.ListFormat('en'))].join()"),
             std::string("ok,TypeError,TypeError"));
}

/// Review Focus 2: huge inputs are charged before the work and capped.
WR_TEST(testHugeInputsAreBoundedAndCharged) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("const over = 'a'.repeat(1048577); err(() => over.localeCompare(over))"), std::string("RangeError"));
    JSRuntime* rt = env.runtime().jsRuntime();
    uint64_t before = JS_GetWorkUnits(rt);
    CHECK_EQ(env.eval("const big = 'a'.repeat(1000000); big.localeCompare(big)"), std::string("0"));
    CHECK(JS_GetWorkUnits(rt) - before >= 2 * 1000000 / 8);
    // A list of a million items is refused at the item cap (the final review's I1), each item charged as it is read.
    // The array is made before the count starts: filling it is charged too (the fix-wave review's m4).
    env.eval("window.million = new Array(1000000).fill('a'); 1");
    before = JS_GetWorkUnits(rt);
    CHECK_EQ(env.eval("(() => { try { new Intl.ListFormat('en', { type: 'unit', style: 'narrow' }).format(million) } catch (e) { return e.name + ': ' + e.message } })()"),
             std::string("RangeError: Intl.ListFormat.prototype.format: the list has more than 10000 items."));
    const uint64_t listWork = JS_GetWorkUnits(rt) - before;
    CHECK(listWork >= 10000 * wr::work::kNodeVisit);
    // It stopped at the cap: reading all million items would charge at least 1,000,000 * kNodeVisit by itself.
    CHECK(listWork < 1000000 * wr::work::kNodeVisit);
}

/// The final review's I1 and M6: a list holds at most kMaxListItems items, empty strings included, read one at a time
/// from its iterator, which is closed when an item is refused (ECMA-402 StringListFromIterable).
WR_TEST(testAListIsBoundedByItsItemCount) {
    HostEnv env;
    env.eval(kErr);
    // Refused at the item cap, before ICU sees a list (an output past the length cap was refused only after formatting).
    CHECK_EQ(env.eval("(() => { try { new Intl.ListFormat('en').format(new Array(1000000).fill('')) } catch (e) { return e.name + ': ' + e.message } })()"),
             std::string("RangeError: Intl.ListFormat.prototype.format: the list has more than 10000 items."));
    CHECK_EQ(env.eval("let closed = false, after = false; function* g() { try { yield 'a'; yield 1; after = true; yield 'b' } finally { closed = true } }"
                      "[err(() => new Intl.ListFormat('en').format(g())), closed, after].join()"),
             std::string("TypeError,true,false"));
    CHECK_EQ(env.eval("new Intl.ListFormat('en', { type: 'unit', style: 'narrow' }).format(new Array(10000).fill('a')).length"), std::string("19999"));
}

/// The final review's M3 (re-graded): a numberingSystem ICU does not know falls back to the locale's own, as ECMA-402
/// says, rather than making ICU refuse the locale.
WR_TEST(testAnUnknownNumberingSystemFallsBack) {
    HostEnv env;
    CHECK_EQ(env.eval("const d = new Intl.DateTimeFormat('en-US', { numberingSystem: 'abcd', timeZone: 'UTC' }); [d.format(0), d.resolvedOptions().numberingSystem].join()"),
             std::string("1/1/1970,latn"));
    CHECK_EQ(env.eval("const r = new Intl.RelativeTimeFormat('en', { numberingSystem: 'abcd' }); [r.format(1, 'day'), r.resolvedOptions().numberingSystem].join()"),
             std::string("in 1 day,latn"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US', { numberingSystem: 'arab', timeZone: 'UTC', year: 'numeric' }).format(0) === '\u0661\u0669\u0667\u0660'"),
             std::string("true"));
}

/// The final review's M4 (re-graded): a Collator sets only the attributes its options give and reports the rest from
/// ICU, so a locale's own tailoring stands (Danish sorts upper case first, Thai ignores punctuation).
WR_TEST(testACollatorKeepsTheLocalesOwnDefaults) {
    HostEnv env;
    CHECK_EQ(env.eval("const da = new Intl.Collator('da'); [da.compare('a', 'A'), da.resolvedOptions().caseFirst].join()"), std::string("1,upper"));
    CHECK_EQ(env.eval("new Intl.Collator('th').resolvedOptions().ignorePunctuation"), std::string("true"));
    CHECK_EQ(env.eval("[new Intl.Collator('da', { caseFirst: 'lower' }).compare('a', 'A'), new Intl.Collator('en').resolvedOptions().caseFirst,"
                      " new Intl.Collator('en').resolvedOptions().ignorePunctuation].join()"),
             std::string("-1,false,false"));
}

/// v0.1.1 plan, Task 10 (ECMA-402 TransformCase): toLocaleUpperCase and toLocaleLowerCase follow the language's own
/// case rules, the first requested locale's or else the host's; other languages keep the root's mapping, the engine's
/// own even when a widget replaces toUpperCase; a long string is mapped whole and charged for.
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
    JSRuntime* rt = env.runtime().jsRuntime();
    const uint64_t before = JS_GetWorkUnits(rt);
    CHECK_EQ(env.eval("'i'.repeat(4000000).toLocaleUpperCase('tr').length"), std::string("4000000"));
    CHECK(JS_GetWorkUnits(rt) - before >= 4000000 / 8 * (1 + wr::work::kCaseMapEightUnits));
}
