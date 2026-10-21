// URLSearchParams (V5a plan, Task 6; the URL Standard §6.2 and application/x-www-form-urlencoded): parsing, the
// serializer, the list operations, the init forms, and the pair iterator.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

WR_TEST(testParse) {
    HostEnv env;
    CHECK_EQ(env.eval("const p = new URLSearchParams('?a=1&b=2&a=3'); [p.getAll('a').join('+'), p.get('c'), p.size, String(p)].join()"),
             std::string("1+3,,3,a=1&b=2&a=3"));
    CHECK_EQ(env.eval("new URLSearchParams('q=a+b%20c%zz&&=x&k').get('q') + '|' + new URLSearchParams('q=a+b%20c%zz&&=x&k').get('') + '|' +"
                      " new URLSearchParams('q=a+b%20c%zz&&=x&k').get('k')"),
             std::string("a b c%zz|x|"));
    CHECK_EQ(env.eval("[...new URLSearchParams('%ff=%C3%A9')].map(([k, v]) => k.codePointAt(0).toString(16) + ':' + v).join()"),
             std::string("fffd:é"));
}

WR_TEST(testSerialize) {
    HostEnv env;
    CHECK_EQ(env.eval("const p = new URLSearchParams(); p.append('q', 'a b&c=é'); p.append('*-._', '~!'); String(p)"),
             std::string("q=a+b%26c%3D%C3%A9&*-._=%7E%21"));
    // Review Focus 2: a lone surrogate is U+FFFD (USVString), three bytes.
    CHECK_EQ(env.eval("const s = new URLSearchParams(); s.append('k', '\\ud800'); s.toString()"), std::string("k=%EF%BF%BD"));
}

WR_TEST(testMutate) {
    HostEnv env;
    CHECK_EQ(env.eval("const p = new URLSearchParams('a=1&b=2&a=3'); const h = [p.has('a', '3'), p.has('a', '4'), p.has('z')];"
                      "p.delete('a', '1'); const d = String(p); p.set('a', 'x'); p.append('a', 'y'); p.set('a', 'z');"
                      "[h.join('+'), d, String(p)].join('|')"),
             std::string("true+false+false|b=2&a=3|b=2&a=z"));
    CHECK_EQ(env.eval("const s = new URLSearchParams('z=1&a=2&z=0&\\u00e9=1&e=2'); s.sort(); String(s)"),
             std::string("a=2&e=2&z=1&z=0&%C3%A9=1"));
    CHECK_EQ(env.eval("const p2 = new URLSearchParams('a=1&b=2'); p2.delete('a'); [p2.size, String(p2)].join()"), std::string("1,b=2"));
}

WR_TEST(testInit) {
    HostEnv env;
    CHECK_EQ(env.eval("[String(new URLSearchParams({ x: '1', y: 2 })), String(new URLSearchParams([['k', 'v'], ['k', 'w']])),"
                      " String(new URLSearchParams(new URLSearchParams('m=1'))), String(new URLSearchParams()), String(new URLSearchParams(5))].join('|')"),
             std::string("x=1&y=2|k=v&k=w|m=1||5="));
    CHECK_EQ(env.eval("(() => { try { new URLSearchParams([['k']]); return 'no' } catch (e) { return e.name } })()"), std::string("TypeError"));
}

WR_TEST(testIteration) {
    HostEnv env;
    CHECK_EQ(env.eval("JSON.stringify([...new URLSearchParams('a=1&b=2')])"), std::string("[[\"a\",\"1\"],[\"b\",\"2\"]]"));
    CHECK_EQ(env.eval("const p = new URLSearchParams('a=1&b=2'); const seen = []; p.forEach((v, k, o) => seen.push(k + v + (o === p)));"
                      "[[...p.keys()].join(), [...p.values()].join(), seen.join(), Object.prototype.toString.call(p.entries())].join('|')"),
             std::string("a,b|1,2|a1true,b2true|[object URLSearchParams Iterator]"));
    // Index-based: deleting the current entry moves the next one up, so it is skipped.
    CHECK_EQ(env.eval("const q = new URLSearchParams('a=1&b=2&c=3'); const ks = []; for (const [k] of q) { ks.push(k); if (k === 'a') q.delete('a'); } ks.join()"),
             std::string("a,c"));
}
