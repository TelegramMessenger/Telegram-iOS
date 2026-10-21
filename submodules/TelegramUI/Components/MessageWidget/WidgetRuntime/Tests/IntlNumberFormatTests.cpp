// Intl.NumberFormat (V5b plan, Task 2; ECMA-402 §15): the options in their order, the ICU skeleton they make, format and
// formatToParts, the object's shape, and Number/BigInt.prototype.toLocaleString. Expected strings are ICU's own output.
#include <string>

#include "Sources/Host/Intl.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testTheConformanceValues) {
    HostEnv env;
    CHECK_EQ(env.eval("new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(1234.5)"), std::string("$1,234.50"));
    CHECK_EQ(env.eval("new Intl.NumberFormat('ru-RU').format(1234.5) === '1\\u00A0234,5'"), std::string("true"));
    CHECK_EQ(env.eval("(1234.5).toLocaleString('en-US')"), std::string("1,234.5"));
    CHECK_EQ(env.eval("JSON.stringify(new Intl.NumberFormat('en-US').formatToParts(1234.5).map(p => [p.type, p.value]))"),
             std::string("[[\"integer\",\"1\"],[\"group\",\",\"],[\"integer\",\"234\"],[\"decimal\",\".\"],[\"fraction\",\"5\"]]"));
}

WR_TEST(testTheCorpusOptions) {
    HostEnv env;
    CHECK_EQ(env.eval("new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(1234.5)"),
             std::string("$1,235"));
    CHECK_EQ(env.eval("(3.14159).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })"), std::string("3.14"));
    CHECK_EQ(env.eval("new Intl.NumberFormat('en-US', { style: 'currency', currency: 'EUR' }).format(1234.5)"), std::string("€1,234.50"));
    CHECK_EQ(env.eval("new Intl.NumberFormat('en-US', { style: 'currency', currency: 'JPY' }).format(1234.5)"), std::string("¥1,235"));
}

WR_TEST(testStylesNotationsAndSigns) {
    HostEnv env;
    CHECK_EQ(env.eval("[new Intl.NumberFormat('en-US', { style: 'percent' }).format(0.256),"
                      " new Intl.NumberFormat('en-US', { notation: 'compact' }).format(1234567),"
                      " new Intl.NumberFormat('en-US', { notation: 'scientific' }).format(1234),"
                      " new Intl.NumberFormat('en-US', { signDisplay: 'always' }).format(5),"
                      " new Intl.NumberFormat('en-US', { style: 'unit', unit: 'kilometer-per-hour' }).format(50),"
                      " new Intl.NumberFormat('en-US', { useGrouping: false }).format(1234)].join('|')"),
             std::string("26%|1.2M|1.234E3|+5|50 km/h|1234"));
}

/// Review Focus 5: the values at the edges.
WR_TEST(testTheEdges) {
    HostEnv env;
    CHECK_EQ(env.eval("const en = new Intl.NumberFormat('en-US'); [en.format(NaN), en.format(Infinity), en.format(-0), en.format(1e21)].join('|')"),
             std::string("NaN|∞|-0|1,000,000,000,000,000,000,000"));
    CHECK_EQ(env.eval("const big = 2n ** 200n; en.format(big) === big.toString().replace(/\\B(?=(\\d{3})+(?!\\d))/g, ',')"), std::string("true"));
    CHECK_EQ(env.eval("JSON.stringify(en.formatToParts(NaN))"), std::string("[{\"type\":\"nan\",\"value\":\"NaN\"}]"));
    CHECK_EQ(env.eval("JSON.stringify(en.formatToParts(-Infinity).map(p => p.type))"), std::string("[\"minusSign\",\"infinity\"]"));
}

WR_TEST(testWhatECMA402Refuses) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("[{ style: 'currency' }, { currency: 'US' }, { maximumFractionDigits: 101 }, { style: 'bogus' },"
                      " { style: 'unit', unit: 'parsec' }, { style: 'unit' }, { minimumFractionDigits: 3, maximumFractionDigits: 1 },"
                      " { roundingIncrement: 3 }, { roundingIncrement: 5, maximumSignificantDigits: 2 }]"
                      ".map(o => err(() => new Intl.NumberFormat('en', o))).join()"),
             std::string("TypeError,RangeError,RangeError,RangeError,RangeError,TypeError,RangeError,RangeError,TypeError"));
    CHECK_EQ(env.eval("[() => Object.getOwnPropertyDescriptor(Intl.NumberFormat.prototype, 'format').get.call({}),"
                      " () => Intl.NumberFormat.prototype.formatToParts.call({}, 1), () => Intl.NumberFormat.prototype.resolvedOptions.call(1)]"
                      ".map(err).join()"),
             std::string("TypeError,TypeError,TypeError"));
    CHECK_EQ(env.eval("[err(() => Number.prototype.toLocaleString.call('1')), err(() => BigInt.prototype.toLocaleString.call(1))].join()"),
             std::string("TypeError,TypeError"));
}

WR_TEST(testTheObjectShape) {
    HostEnv env;
    CHECK_EQ(env.eval("const nf = Intl.NumberFormat('en'); const f = nf.format;"
                      "[nf instanceof Intl.NumberFormat, nf.format === nf.format, f(1), Object.prototype.toString.call(nf),"
                      " Intl.NumberFormat.length, Intl.NumberFormat.name, typeof Intl.NumberFormat.supportedLocalesOf].join()"),
             std::string("true,true,1,[object Intl.NumberFormat],0,NumberFormat,function"));
    CHECK_EQ(env.eval("Object.keys(new Intl.NumberFormat('en-US').resolvedOptions()).join()"),
             std::string("locale,numberingSystem,style,minimumIntegerDigits,minimumFractionDigits,maximumFractionDigits,useGrouping,"
                         "notation,signDisplay,roundingIncrement,roundingMode,roundingPriority,trailingZeroDisplay"));
    CHECK_EQ(env.eval("const ro = new Intl.NumberFormat('en-US-u-nu-thai', { style: 'currency', currency: 'eur' }).resolvedOptions();"
                      "[ro.locale, ro.currency, ro.currencyDisplay, ro.minimumFractionDigits, ro.maximumFractionDigits, ro.useGrouping].join()"),
             std::string("en-US,EUR,symbol,2,2,auto"));
    CHECK_EQ(env.eval("Intl.NumberFormat.supportedLocalesOf(['en-US', 'xx']).join()"), std::string("en-US"));
    CHECK_EQ(env.eval("(12345n).toLocaleString('de-DE')"), std::string("12.345"));
}

/// Review Focus 1: the getters run in ECMA-402's order, and one that re-enters Intl or throws leaves nothing broken.
WR_TEST(testOptionGettersRunInSpecOrderAndMayReenter) {
    HostEnv env;
    CHECK_EQ(env.eval("const log = []; new Intl.NumberFormat('en', new Proxy({}, { get(t, k) { log.push(k) } })); log.join()"),
             std::string("localeMatcher,numberingSystem,style,currency,currencyDisplay,currencySign,unit,unitDisplay,notation,"
                         "minimumIntegerDigits,minimumFractionDigits,maximumFractionDigits,minimumSignificantDigits,"
                         "maximumSignificantDigits,roundingIncrement,roundingMode,roundingPriority,trailingZeroDisplay,"
                         "compactDisplay,useGrouping,signDisplay"));
    CHECK_EQ(env.eval("new Intl.NumberFormat('en', { style: 'currency', get currency() { new Intl.NumberFormat('en').format(1); return 'USD' } }).format(1)"),
             std::string("$1.00"));
    CHECK_EQ(env.eval("new Intl.NumberFormat('en', { get style() {"
                      " Object.defineProperty(Intl.NumberFormat.prototype, 'format', { get() { return () => 'x' }, configurable: true });"
                      " return 'percent' } }).resolvedOptions().style"),
             std::string("percent"));
    CHECK_EQ(env.eval("(() => { try { new Intl.NumberFormat('en', { get style() { throw new RangeError('g') } }) } catch (e) { return e.message } })()"),
             std::string("g"));
    CHECK_EQ(env.eval("Intl.NumberFormat.prototype.formatToParts.call(new Intl.NumberFormat('en'), 7)[0].value"), std::string("7"));
}

/// Review Focus 3: many distinct formatters keep the ICU cache at its cap, and results stay right across evictions.
WR_TEST(testTheICUCacheStaysBounded) {
    HostEnv env;
    CHECK_EQ(env.eval("const out = []; for (let i = 0; i < 10000; i++) {"
                      " const s = new Intl.NumberFormat('en-US', { minimumIntegerDigits: 1 + i % 21, maximumFractionDigits: Math.floor(i / 21) % 21 }).format(1.5);"
                      " if (i === 0 || i === 22) out.push(s) }"
                      " out.push(new Intl.NumberFormat('en-US', { minimumIntegerDigits: 1, maximumFractionDigits: 0 }).format(1.5)); out.join()"),
             std::string("2,01.5,2"));
    CHECK(wr::intl::intlState(env.ctx()).cache.size() <= wr::intl::kIntlCacheSize);
}
