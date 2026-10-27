// Intl.DateTimeFormat (V5b plan, Task 3; ECMA-402 §11): the options in their order and what ECMA-402 refuses, the
// requests (`date`, `dateMethod`, `dateParts`, `dateOptions`) with the options given and ToDateTimeOptions' defaults
// added as widget-sandbox's shim adds them, the time each one formats, and resolvedOptions. The host is the echo glue
// (wr_test::echoIntl) unless a case says otherwise.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testTheRequests) {
    HostEnv env;
    env.host().intlAnswer = wr_test::echoIntl;
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US', { timeZone: 'UTC' }).format(new Date(86400000))"),
             std::string("{\"kind\":\"date\",\"locale\":\"en-US\",\"opts\":{\"timeZone\":\"UTC\",\"year\":\"numeric\",\"month\":\"numeric\","
                         "\"day\":\"numeric\"},\"value\":86400000}"));
    CHECK_EQ(env.eval("new Date(0).toLocaleString('en-GB', { timeZone: 'Europe/Lisbon' })"),
             std::string("{\"kind\":\"dateMethod\",\"method\":\"toLocaleString\",\"locale\":\"en-GB\",\"opts\":{\"timeZone\":\"Europe/Lisbon\","
                         "\"year\":\"numeric\",\"month\":\"numeric\",\"day\":\"numeric\",\"hour\":\"numeric\",\"minute\":\"numeric\",\"second\":\"numeric\"},"
                         "\"value\":0}"));
    CHECK_EQ(env.eval("new Date(0).toLocaleTimeString('en', { hour12: false })"),
             std::string("{\"kind\":\"dateMethod\",\"method\":\"toLocaleTimeString\",\"locale\":\"en\",\"opts\":{\"hour12\":false,"
                         "\"hour\":\"numeric\",\"minute\":\"numeric\",\"second\":\"numeric\"},\"value\":0}"));
    CHECK_EQ(env.eval("new Date(0).toLocaleDateString('en', { weekday: 'long', hour: 'numeric' })"),
             std::string("{\"kind\":\"dateMethod\",\"method\":\"toLocaleDateString\",\"locale\":\"en\",\"opts\":{\"weekday\":\"long\","
                         "\"hour\":\"numeric\"},\"value\":0}"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en', { dateStyle: 'medium', timeStyle: 'short', fractionalSecondDigits: undefined }).formatToParts(1.9)[0].value"),
             std::string("{\"kind\":\"dateParts\",\"locale\":\"en\",\"opts\":{\"dateStyle\":\"medium\",\"timeStyle\":\"short\"},\"value\":1}"));
    env.eval("new Intl.DateTimeFormat('en', { hour: '2-digit' }).resolvedOptions()");
    CHECK_EQ(env.host().intlRequests.back(), std::string("{\"kind\":\"dateOptions\",\"locale\":\"en\",\"opts\":{\"hour\":\"2-digit\"}}"));
}

/// A format of nothing is now, the host's wall clock; a time ECMAScript cannot hold is a RangeError, and an invalid date
/// "Invalid Date" for the toLocale methods, with no request either way.
WR_TEST(testTheTimeFormatted) {
    HostEnv env;
    env.eval(kErr);
    env.host().intlAnswer = wr_test::echoIntl;
    env.host().now = 1500;
    CHECK_EQ(env.eval("JSON.parse(new Intl.DateTimeFormat('en').format()).value"), std::string("1767225601500"));
    const size_t before = env.host().intlRequests.size();
    CHECK_EQ(env.eval("[new Date(NaN).toLocaleString(), err(() => new Intl.DateTimeFormat('en').format(8.64e15 + 1)),"
                      " err(() => new Intl.DateTimeFormat('en').format(NaN))].join()"),
             std::string("Invalid Date,RangeError,RangeError"));
    CHECK_EQ(env.host().intlRequests.size(), before);
}

/// Review Focus 4 and 5: hostile zones and options. A zone's name is the host's to know (the glue formats an unknown one
/// in the device's zone); what cannot be one is refused here.
WR_TEST(testWhatECMA402Refuses) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("['Europe/../UTC', '+01:00', '', '/etc', 'a'.repeat(100000), 'Mars/Base'].map(z => err(() => new Intl.DateTimeFormat('en', { timeZone: z }))).join()"),
             std::string("RangeError,RangeError,RangeError,RangeError,RangeError,ok"));
    CHECK_EQ(env.eval("[err(() => new Intl.DateTimeFormat('en', { dateStyle: 'full', year: 'numeric' })),"
                      " err(() => new Intl.DateTimeFormat('en', { month: 'bogus' })),"
                      " err(() => new Intl.DateTimeFormat('en', { calendar: 'x' })),"
                      " err(() => new Date(0).toLocaleDateString('en', { timeStyle: 'short' })),"
                      " err(() => Intl.DateTimeFormat.prototype.formatToParts.call({}, 0)),"
                      " err(() => Date.prototype.toLocaleString.call({}))].join()"),
             std::string("TypeError,RangeError,RangeError,TypeError,TypeError,TypeError"));
}

/// resolvedOptions: ECMA-402's keys in its order from the host's answer (its locale, calendar, numbering system, time
/// zone and the fields it formats), ours where it has none.
WR_TEST(testResolvedOptions) {
    HostEnv env;
    CHECK_EQ(env.eval("JSON.stringify(new Intl.DateTimeFormat('en-US-u-ca-buddhist', { timeZone: 'UTC', hourCycle: 'h23', hour: 'numeric' }).resolvedOptions())"),
             std::string("{\"locale\":\"en-US-u-ca-buddhist\",\"calendar\":\"gregory\",\"numberingSystem\":\"latn\",\"timeZone\":\"UTC\",\"hourCycle\":\"h23\",\"hour\":\"numeric\"}"));
    env.host().intlAnswer = [](std::string_view) {
        return std::string("{\"calendar\":\"gregory\",\"day\":\"numeric\",\"locale\":\"en-US\",\"localeMatcher\":\"x\",\"month\":\"numeric\","
                           "\"numberingSystem\":\"latn\",\"timeZone\":\"Asia/Tokyo\",\"year\":\"numeric\"}");
    };
    CHECK_EQ(env.eval("Object.keys(new Intl.DateTimeFormat('en-US').resolvedOptions()).join()"),
             std::string("locale,calendar,numberingSystem,timeZone,year,month,day"));
    CHECK_EQ(env.eval("new Intl.DateTimeFormat('en-US').resolvedOptions().timeZone"), std::string("Asia/Tokyo"));
}

WR_TEST(testTheObjectShape) {
    HostEnv env;
    env.host().intlAnswer = [](std::string_view request) { return std::string(request.find("86400000") != std::string_view::npos ? "b" : "a"); };
    CHECK_EQ(env.eval("const dtf = Intl.DateTimeFormat('en-US', { timeZone: 'UTC' });"
                      "[dtf instanceof Intl.DateTimeFormat, dtf.format === dtf.format, [0, 86400000].map(dtf.format).join(' '),"
                      " Object.prototype.toString.call(dtf), Intl.DateTimeFormat.length].join()"),
             std::string("true,true,a b,[object Intl.DateTimeFormat],0"));
    CHECK_EQ(env.eval("const log = []; new Intl.DateTimeFormat('en', new Proxy({}, { get(t, k) { log.push(k) } })); log.join()"),
             std::string("localeMatcher,calendar,numberingSystem,hour12,hourCycle,timeZone,weekday,era,year,month,day,dayPeriod,"
                         "hour,minute,second,fractionalSecondDigits,timeZoneName,formatMatcher,dateStyle,timeStyle"));
}
