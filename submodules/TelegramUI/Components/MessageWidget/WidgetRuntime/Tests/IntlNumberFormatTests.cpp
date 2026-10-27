// Intl.NumberFormat (V5b plan, Task 2; ECMA-402 §15): the options in their order and what ECMA-402 refuses, the
// requests (`number`, `numberParts`, `numberOptions`) with the options the widget gave, what is formatted without one
// (NaN and the infinities), resolvedOptions merged from the host's answer and ours, and Number/BigInt.prototype
// .toLocaleString. The host is the echo glue (wr_test::echoIntl) unless a case says otherwise.
#include <string>

#include "Sources/Host/Intl.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testTheRequests) {
    HostEnv env;
    env.host().intlAnswer = wr_test::echoIntl;
    CHECK_EQ(env.eval("new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(1234.5)"),
             std::string("{\"kind\":\"number\",\"locale\":\"de-DE\",\"opts\":{\"style\":\"currency\",\"currency\":\"EUR\"},\"value\":1234.5}"));
    CHECK_EQ(env.eval("new Intl.NumberFormat('en-US').formatToParts(-0.5)[0].value"),
             std::string("{\"kind\":\"numberParts\",\"locale\":\"en-US\",\"opts\":{},\"value\":-0.5}"));
    env.eval("new Intl.NumberFormat('en-US', { style: 'percent' }).resolvedOptions()");
    CHECK_EQ(env.host().intlRequests.back(), std::string("{\"kind\":\"numberOptions\",\"locale\":\"en-US\",\"opts\":{\"style\":\"percent\"}}"));
    CHECK_EQ(env.eval("(5).toLocaleString('en', { maximumFractionDigits: 1 })"),
             std::string("{\"kind\":\"number\",\"locale\":\"en\",\"opts\":{\"maximumFractionDigits\":1},\"value\":5}"));
    // A BigInt is its digits, a JSON number the glue reads as the shim's Number(value).
    CHECK_EQ(env.eval("(2n ** 70n).toLocaleString('en')"),
             std::string("{\"kind\":\"number\",\"locale\":\"en\",\"opts\":{},\"value\":1180591620717411303424}"));
    CHECK_EQ(env.eval("new Intl.NumberFormat('en').format(1e21) + new Intl.NumberFormat('en').format(-0)"),
             std::string("{\"kind\":\"number\",\"locale\":\"en\",\"opts\":{},\"value\":1e+21}{\"kind\":\"number\",\"locale\":\"en\",\"opts\":{},\"value\":0}"));
}

/// The options a request carries are the ones the widget gave, as ECMA-402 read them: a number option as its number,
/// useGrouping as given, the digit options ECMA-402 ignores left out, and nothing the glue does not format with.
WR_TEST(testTheGivenOptions) {
    HostEnv env;
    env.host().intlAnswer = wr_test::echoIntl;
    CHECK_EQ(env.eval("JSON.stringify(JSON.parse(new Intl.NumberFormat('en', { localeMatcher: 'lookup', minimumFractionDigits: '2', useGrouping: false,"
                      " signDisplay: 'exceptZero', minimumIntegerDigits: 3.7 }).format(1)).opts)"),
             std::string("{\"minimumIntegerDigits\":3,\"minimumFractionDigits\":2,\"useGrouping\":false,\"signDisplay\":\"exceptZero\"}"));
    CHECK_EQ(env.eval("JSON.stringify(JSON.parse(new Intl.NumberFormat('en', { useGrouping: 'min2', maximumSignificantDigits: 3,"
                      " minimumFractionDigits: 1 }).format(1)).opts)"),
             std::string("{\"maximumSignificantDigits\":3,\"useGrouping\":\"min2\"}"));
}

/// JSON has no NaN or infinity (the shim's request would format null as 0): those are formatted here, with no request.
WR_TEST(testNaNAndTheInfinities) {
    HostEnv env;
    env.host().intlAnswer = wr_test::echoIntl;
    CHECK_EQ(env.eval("const en = new Intl.NumberFormat('en-US'); [en.format(NaN), en.format(Infinity), en.format(-Infinity),"
                      " new Intl.NumberFormat('en', { signDisplay: 'always' }).format(Infinity), new Intl.NumberFormat('en', { signDisplay: 'never' }).format(-Infinity),"
                      " (NaN).toLocaleString()].join('|')"),
             std::string("NaN|∞|-∞|+∞|∞|NaN"));
    CHECK_EQ(env.eval("JSON.stringify(en.formatToParts(NaN))"), std::string("[{\"type\":\"nan\",\"value\":\"NaN\"}]"));
    CHECK_EQ(env.eval("JSON.stringify(en.formatToParts(-Infinity).map(p => p.type))"), std::string("[\"minusSign\",\"infinity\"]"));
    CHECK(env.host().intlRequests.empty());
}

WR_TEST(testWhatECMA402Refuses) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("[{ style: 'currency' }, { currency: 'US' }, { maximumFractionDigits: 101 }, { style: 'bogus' },"
                      " { style: 'unit', unit: 'parsec' }, { style: 'unit' }, { minimumFractionDigits: 3, maximumFractionDigits: 1 },"
                      " { roundingIncrement: 3 }, { roundingIncrement: 5, maximumSignificantDigits: 2 }, { numberingSystem: 'a' },"
                      " { useGrouping: 'sometimes' }]"
                      ".map(o => err(() => new Intl.NumberFormat('en', o))).join()"),
             std::string("TypeError,RangeError,RangeError,RangeError,RangeError,TypeError,RangeError,RangeError,TypeError,RangeError,RangeError"));
    CHECK_EQ(env.eval("[() => Object.getOwnPropertyDescriptor(Intl.NumberFormat.prototype, 'format').get.call({}),"
                      " () => Intl.NumberFormat.prototype.formatToParts.call({}, 1), () => Intl.NumberFormat.prototype.resolvedOptions.call(1)]"
                      ".map(err).join()"),
             std::string("TypeError,TypeError,TypeError"));
    CHECK_EQ(env.eval("[err(() => Number.prototype.toLocaleString.call('1')), err(() => BigInt.prototype.toLocaleString.call(1))].join()"),
             std::string("TypeError,TypeError"));
}

/// resolvedOptions: ECMA-402's keys in its order, each the host's value where its answer has one (the locale it
/// formats in, a currency's own digits), else ours.
WR_TEST(testResolvedOptions) {
    HostEnv env;
    CHECK_EQ(env.eval("Object.keys(new Intl.NumberFormat('en-US').resolvedOptions()).join()"),
             std::string("locale,numberingSystem,style,minimumIntegerDigits,minimumFractionDigits,maximumFractionDigits,useGrouping,"
                         "notation,signDisplay,roundingIncrement,roundingMode,roundingPriority,trailingZeroDisplay"));
    CHECK_EQ(env.eval("const ro = new Intl.NumberFormat('en-US-u-nu-thai', { style: 'currency', currency: 'eur' }).resolvedOptions();"
                      "[ro.locale, ro.currency, ro.currencyDisplay, ro.minimumFractionDigits, ro.maximumFractionDigits, ro.useGrouping].join()"),
             std::string("en-US-u-nu-thai,EUR,symbol,2,2,auto"));
    env.host().intlAnswer = [](std::string_view) {
        return std::string("{\"currency\":\"JPY\",\"locale\":\"ja-JP\",\"maximumFractionDigits\":0,\"minimumFractionDigits\":0,\"other\":1}");
    };
    CHECK_EQ(env.eval("JSON.stringify(new Intl.NumberFormat('ja', { style: 'currency', currency: 'jpy' }).resolvedOptions())"),
             std::string("{\"locale\":\"ja-JP\",\"numberingSystem\":\"latn\",\"style\":\"currency\",\"currency\":\"JPY\",\"currencyDisplay\":\"symbol\","
                         "\"currencySign\":\"standard\",\"minimumIntegerDigits\":1,\"minimumFractionDigits\":0,\"maximumFractionDigits\":0,"
                         "\"useGrouping\":\"auto\",\"notation\":\"standard\",\"signDisplay\":\"auto\",\"roundingIncrement\":1,"
                         "\"roundingMode\":\"halfExpand\",\"roundingPriority\":\"auto\",\"trailingZeroDisplay\":\"auto\"}"));
}

WR_TEST(testTheObjectShape) {
    HostEnv env;
    env.host().intlAnswer = [](std::string_view) { return std::string("formatted"); };
    CHECK_EQ(env.eval("const nf = Intl.NumberFormat('en'); const f = nf.format;"
                      "[nf instanceof Intl.NumberFormat, nf.format === nf.format, f(1), Object.prototype.toString.call(nf),"
                      " Intl.NumberFormat.length, Intl.NumberFormat.name, typeof Intl.NumberFormat.supportedLocalesOf].join()"),
             std::string("true,true,formatted,[object Intl.NumberFormat],0,NumberFormat,function"));
}

/// Review Focus 1: the getters run in ECMA-402's order, and one that re-enters Intl or throws leaves nothing broken.
WR_TEST(testOptionGettersRunInSpecOrderAndMayReenter) {
    HostEnv env;
    env.host().intlAnswer = wr_test::echoIntl;
    CHECK_EQ(env.eval("const log = []; new Intl.NumberFormat('en', new Proxy({}, { get(t, k) { log.push(k) } })); log.join()"),
             std::string("localeMatcher,numberingSystem,style,currency,currencyDisplay,currencySign,unit,unitDisplay,notation,"
                         "minimumIntegerDigits,minimumFractionDigits,maximumFractionDigits,minimumSignificantDigits,"
                         "maximumSignificantDigits,roundingIncrement,roundingMode,roundingPriority,trailingZeroDisplay,"
                         "compactDisplay,useGrouping,signDisplay"));
    CHECK_EQ(env.eval("new Intl.NumberFormat('en', { style: 'currency', get currency() { new Intl.NumberFormat('en').format(1); return 'USD' } }).format(1)"),
             std::string("{\"kind\":\"number\",\"locale\":\"en\",\"opts\":{\"style\":\"currency\",\"currency\":\"USD\"},\"value\":1}"));
    CHECK_EQ(env.eval("(() => { try { new Intl.NumberFormat('en', { get style() { throw new RangeError('g') } }) } catch (e) { return e.message } })()"),
             std::string("g"));
    // The options are read once, at construction: changing the object later changes nothing.
    CHECK_EQ(env.eval("const o = { style: 'percent' }; const p = new Intl.NumberFormat('en', o); o.style = 'decimal'; JSON.parse(p.format(1)).opts.style"),
             std::string("percent"));
}
