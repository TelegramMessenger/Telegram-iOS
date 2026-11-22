// URL (V5a plan, Task 7; the URL Standard's basic URL parser and serializer, without IDNA): parsing, relative
// resolution, the percent-encode sets, hosts (IPv4, IPv6, opaque), failures, the setters and searchParams, and the
// object URL stubs.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { return f() } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testParse) {
    HostEnv env;
    CHECK_EQ(env.eval("const u = new URL('https://t.me/path?a=1&b=two#h');"
                      "[u.href, u.protocol, u.hostname, u.host, u.port, u.pathname, u.search, u.hash, u.origin, u.searchParams.get('b')].join('|')"),
             std::string("https://t.me/path?a=1&b=two#h|https:|t.me|t.me||/path|?a=1&b=two|#h|https://t.me|two"));
    CHECK_EQ(env.eval("[new URL('HTTPS://EXAMPLE.org:443/a/./b/../c').href, new URL('https://h.example').href, new URL('  https://h.example/x  ').href,"
                      " new URL('ht\\ttps://h.ex\\nample/').href].join('|')"),
             std::string("https://example.org/a/c|https://h.example/|https://h.example/x|https://h.example/"));
    CHECK_EQ(env.eval("const c = new URL('https://user:pw@h.example:8080/'); [c.username, c.password, c.host, c.port, c.origin, c.href].join('|')"),
             std::string("user|pw|h.example:8080|8080|https://h.example:8080|https://user:pw@h.example:8080/"));
}

WR_TEST(testRelative) {
    HostEnv env;
    CHECK_EQ(env.eval("[new URL('../x?y#z', 'https://a.b/c/d/e'), new URL('//h.example/p', 'https://a.b/'), new URL('?x', 'https://a.b/c?y#z'),"
                      " new URL('#f', 'https://a.b/c?y'), new URL('/r', 'https://a.b/c/d'), new URL('', 'https://a.b/c?q#f')].map(String).join('|')"),
             std::string("https://a.b/c/x?y#z|https://h.example/p|https://a.b/c?x|https://a.b/c?y#f|https://a.b/r|https://a.b/c?q"));
}

WR_TEST(testPercentEncoding) {
    HostEnv env;
    CHECK_EQ(env.eval("[new URL('https://h.example/ a b').pathname, new URL('https://h.example/?q=a b').search, new URL('https://h.example/#a b').hash,"
                      " new URL('HTTP://H.EXAMPLE/%7e?%7e#%7e').href, new URL('https://h.example/a/%2e%2E/b').pathname,"
                      " new URL('https://h.example/\\ud800').pathname, new URL('https://h.example/é?é#é').href,"
                      " new URL(\"https://h.example/?'\").search, new URL(\"x:/?'\").search].join('|')"),
             std::string("/%20a%20b|?q=a%20b|#a%20b|http://h.example/%7e?%7e#%7e|/b|/%EF%BF%BD|https://h.example/%C3%A9?%C3%A9#%C3%A9|?%27|?'"));
}

WR_TEST(testHosts) {
    HostEnv env;
    CHECK_EQ(env.eval("[new URL('http://h.example\\\\a\\\\b').href, new URL('https://[::1]:8443/').hostname, new URL('https://[::1]:8443/').host,"
                      " new URL('http://[0:0:0:0:0:ffff:7f00:1]/').hostname, new URL('http://[1:0:0:2:0:0:0:3]/').hostname,"
                      " new URL('http://0x7f.1/').href, new URL('http://010.0.0.1/').hostname].join('|')"),
             std::string("http://h.example/a/b|[::1]|[::1]:8443|[::ffff:7f00:1]|[1:0:0:2::3]|http://127.0.0.1/|8.0.0.1"));
    CHECK_EQ(env.eval("const m = new URL('mailto:x@y.z'); [m.protocol, m.pathname, m.origin, m.host, new URL('foo://Host.Ex/p').host].join('|')"),
             std::string("mailto:|x@y.z|null||Host.Ex"));
}

WR_TEST(testFailures) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("['foo', 'https://exa mple.org', 'https://h.example:65536/', 'https://\\uFFFD.example/', 'http://[::1/', 'https://',"
                      " 'http://1.2.3.4.5/', 'http://192.168.0.257/'].map(u => err(() => new URL(u))).join()"),
             std::string("TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError"));
    CHECK_EQ(env.eval("[URL.canParse('x'), URL.canParse('x', 'https://a.b/'), URL.parse('x'), URL.parse('https://a.b') instanceof URL].join()"),
             std::string("false,true,,true"));
}

/// Review Focus 4: searchParams and search stay in sync both ways.
WR_TEST(testSettersAndSearchParams) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("const u = new URL('https://a.b/p?x=1#f'); const p = u.searchParams; u.search = 'k=v';"
                      "const a = [p.get('k'), p.get('x'), u.href].join(); p.append('n', '1');"
                      "const b = [u.search, u.href].join(); u.search = ''; [a, b, u.search, p.size, u.href, u.searchParams === p].join('|')"),
             std::string("v,,https://a.b/p?k=v#f|?k=v&n=1,https://a.b/p?k=v&n=1#f||0|https://a.b/p#f|true"));
    CHECK_EQ(env.eval("const v = new URL('https://a.b/'); v.hash = 'top'; v.pathname = '/a b'; v.port = '99999'; const before = v.href; v.port = '81';"
                      "v.hostname = 'c.d'; v.search = '?q=#'; [before, v.href].join('|')"),
             std::string("https://a.b/a%20b#top|https://c.d:81/a%20b?q=%23#top"));
    CHECK_EQ(env.eval("const w = new URL('https://a.b/'); [err(() => { w.href = 'x' }), w.href, String(w) === w.href, JSON.stringify(new URL('https://a.b'))].join('|')"),
             std::string("TypeError|https://a.b/|true|\"https://a.b/\""));
    CHECK_EQ(env.eval("const s = new URL('https://a.b/'); s.searchParams.set('q', 'a b'); s.href"), std::string("https://a.b/?q=a+b"));
}

WR_TEST(testObjectURLs) {
    HostEnv env;
    CHECK_EQ(env.eval("[URL.createObjectURL({}) === '', URL.revokeObjectURL('x') === undefined].join()"), std::string("true,true"));
}

/// The final review: a URL whose serialization would be longer than the input limit is refused, by the constructor,
/// parse and canParse alike (one constructed and then read as an empty record: protocol ":" while href was right), and a
/// setter that would make one leaves the URL as it was.
WR_TEST(testAURLLongerThanTheLimitIsRefused) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("const big = 'data:,' + '\\u00e9'.repeat(400000); [err(() => new URL(big).protocol), URL.parse(big), URL.canParse(big)].join()"),
             std::string("TypeError,,false"));
    CHECK_EQ(env.eval("const u = new URL('https://a.example/'); u.pathname = '\\u00e9'.repeat(200000); [u.href, u.protocol, u.pathname].join()"),
             std::string("https://a.example/,https:,/"));
}

/// V5b: the URL Standard's "domain to ASCII" through UTS 46 (non-transitional, CheckBidi and CheckJoiners, no
/// CheckHyphens), from the system ICU.
WR_TEST(testInternationalDomains) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("[new URL('https://\\u00fc.example/').host, new URL('https://XN--TDA.example/').host, new URL('https://fa\\u00df.de/').host,"
                      " new URL('https://-x.example/').host].join()"),
             std::string("xn--tda.example,xn--tda.example,xn--fa-hia.de,-x.example"));
    // An ASCII domain is only lowercased, invalid Punycode included (WPT's toascii.json); a non-ASCII one is checked.
    CHECK_EQ(env.eval("[new URL('https://XN--A.example/').host, err(() => new URL('https://a\\u200Db/')), err(() => new URL('https://\\u05D0a/'))].join()"),
             std::string("xn--a.example,TypeError,TypeError"));
}
