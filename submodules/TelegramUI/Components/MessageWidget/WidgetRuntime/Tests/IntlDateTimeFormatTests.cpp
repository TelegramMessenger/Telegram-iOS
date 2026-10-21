// Intl.DateTimeFormat (V5b plan, Task 3; ECMA-402 §11): the options in their order, a skeleton turned into a pattern by
// ICU's pattern generator (or a date and time style), the host's time zone as the default, format and formatToParts,
// and Date.prototype.toLocale{String,DateString,TimeString}. Expected strings are ICU's own output (U+202F before AM).
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testTheConformanceValues) {
    HostEnv env;
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US', { timeZone: 'UTC' }).format(new Date(0))"), std::string("1/1/1970"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US', { timeZone: 'UTC' }).formatToParts(new Date(0)).some(p => p.type === 'year' && p.value === '1970')"),
             std::string("true"));
    CHECK_EQ(env.eval("JSON.stringify(new Intl.DateTimeFormat('en-US', { timeZone: 'UTC' }).formatToParts(new Date(0)).map(p => p.type))"),
             std::string("[\"month\",\"literal\",\"day\",\"literal\",\"year\"]"));
}

WR_TEST(testTheCorpusOptions) {
    HostEnv env;
    CHECK_EQ(env.eval("new Date(0).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', timeZone: 'UTC' })"),
             std::string("Thursday, January 1"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Lisbon', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' }).format(new Date(0))"),
             std::string("01:00:00"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-GB', { timeZone: 'UTC', weekday: 'long', day: 'numeric', month: 'short' }).format(new Date(0))"),
             std::string("Thursday 1 Jan"));
    CHECK_EQ(env.eval("new Date(0).toLocaleTimeString('en-US', { timeZone: 'UTC' }) === '12:00:00\\u202FAM'"), std::string("true"));
}

WR_TEST(testStylesAndHourCycles) {
    HostEnv env;
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US', { dateStyle: 'full', timeZone: 'UTC' }).format(0)"), std::string("Thursday, January 1, 1970"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US', { timeStyle: 'short', timeZone: 'UTC' }).format(0) === '12:00\\u202FAM'"), std::string("true"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US', { timeStyle: 'short', hourCycle: 'h23', timeZone: 'UTC' }).format(0)"), std::string("00:00"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US', { hour: 'numeric', hour12: false, timeZone: 'UTC' }).format(0)"), std::string("00"));
    CHECK_EQ(env.eval("[{ hour: 'numeric' }, { hour: 'numeric', hour12: false }, { hour: 'numeric', hourCycle: 'h11' }, { timeStyle: 'short', hourCycle: 'h23' }]"
                      ".map(o => new Intl.DateTimeFormat('en-US', o).resolvedOptions().hourCycle).join()"),
             std::string("h12,h23,h11,h23"));
}

WR_TEST(testTheHostDefaults) {
    HostEnv env;
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US').resolvedOptions().timeZone"), std::string("UTC"));
    CHECK_EQ(env.eval("new Date(0).toLocaleString('en-US') === '1/1/1970, 12:00:00\\u202FAM'"), std::string("true"));
    CHECK_EQ(env.eval("new Date(NaN).toLocaleString()"), std::string("Invalid Date"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US', { timeZone: 'etc/gmt' }).resolvedOptions().timeZone"), std::string("UTC"));
}

/// Review Focus 4 and 5: hostile zones and out-of-range times.
WR_TEST(testWhatECMA402Refuses) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("['Mars/Base', 'Europe/../UTC', 'a'.repeat(100000)].map(z => err(() => new Intl.DateTimeFormat('en', { timeZone: z }))).join()"),
             std::string("RangeError,RangeError,RangeError"));
    CHECK_EQ(env.eval("[err(() => new Intl.DateTimeFormat('en', { dateStyle: 'full', year: 'numeric' })),"
                      " err(() => new Intl.DateTimeFormat('en', { month: 'bogus' })),"
                      " err(() => new Intl.DateTimeFormat('en').format(8.64e15 + 1)),"
                      " err(() => Intl.DateTimeFormat.prototype.formatToParts.call({}, 0)),"
                      " err(() => Date.prototype.toLocaleString.call({}))].join()"),
             std::string("TypeError,RangeError,RangeError,TypeError,TypeError"));
}

WR_TEST(testTheObjectShape) {
    HostEnv env;
    CHECK_EQ(env.eval("const dtf = Intl.DateTimeFormat('en-US', { timeZone: 'UTC' });"
                      "[dtf instanceof Intl.DateTimeFormat, dtf.format === dtf.format, [0, 86400000].map(dtf.format).join(' '),"
                      " Object.prototype.toString.call(dtf), Intl.DateTimeFormat.length].join()"),
             std::string("true,true,1/1/1970 1/2/1970,[object Intl.DateTimeFormat],0"));
    CHECK_EQ(env.eval("Object.keys(new Intl.DateTimeFormat('en-US', { timeZone: 'UTC' }).resolvedOptions()).join()"),
             std::string("locale,calendar,numberingSystem,timeZone,year,month,day"));
    CHECK_EQ(env.eval("Object.keys(new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', timeZone: 'UTC' }).resolvedOptions()).join()"),
             std::string("locale,calendar,numberingSystem,timeZone,hourCycle,hour12,hour,minute"));
    CHECK_EQ(env.eval("[new Intl.DateTimeFormat('th-TH').resolvedOptions().calendar, new Intl.DateTimeFormat('en-US').resolvedOptions().calendar].join()"),
             std::string("buddhist,gregory"));
    CHECK_EQ(env.eval("const log = []; new Intl.DateTimeFormat('en', new Proxy({}, { get(t, k) { log.push(k) } })); log.join()"),
             std::string("localeMatcher,calendar,numberingSystem,hour12,hourCycle,timeZone,weekday,era,year,month,day,dayPeriod,"
                         "hour,minute,second,fractionalSecondDigits,timeZoneName,formatMatcher,dateStyle,timeStyle"));
}
