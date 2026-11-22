// The CSS namespace (V5c plan, Task 2; CSSOM §6.6 and §2.1): a lazy global holding escape and supports, and
// CSS.escape's "serialize an identifier", including what the reference's shim gets wrong.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testTheCSSNamespace) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("[typeof CSS, Object.prototype.toString.call(CSS), CSS.escape.length, CSS.supports.length,"
                      " Object.getOwnPropertyDescriptor(globalThis, 'CSS').enumerable, typeof new Function('return CSS')().escape].join()"),
             std::string("object,[object CSS],1,1,false,function"));
    CHECK_EQ(env.eval("[err(() => CSS.supports()), err(() => CSS.escape())].join()"), std::string("TypeError,TypeError"));
}

/// Review Focus 5: CSSOM's serialize an identifier, where the reference's one-line shim differs.
WR_TEST(testEscape) {
    HostEnv env;
    // Each case: the input, then CSSOM's serialization of it; a mismatch is reported by its index.
    CHECK_EQ(env.eval("const cases = [['a b', 'a\\\\ b'], ['\\0', '\\uFFFD'], ['0a', '\\\\30 a'], ['-0', '-\\\\30 '], ['-', '\\\\-'],"
                      " ['--', '--'], ['\\x01\\x1f\\x7f', '\\\\1 \\\\1f \\\\7f '], ['\\u00a9', '\\u00a9'], ['a.b#c', 'a\\\\.b\\\\#c'],"
                      " ['_x-1', '_x-1'], ['', '']];"
                      "cases.map(([input, want], i) => CSS.escape(input) === want ? '' : i + ':' + JSON.stringify(CSS.escape(input))).filter(Boolean).join()"),
             std::string(""));
    CHECK_EQ(env.eval("CSS.escape('\\uD800x') === '\\uD800x'"), std::string("true"));
    CHECK_EQ(env.eval("CSS.escape(12)"), std::string("\\31 2"));
}

WR_TEST(testEscapeTakesALongString) {
    HostEnv env;
    env.eval("window.long = 'a'.repeat(1000000); 1");
    CHECK_EQ(env.eval("CSS.escape(long).length"), std::string("1000000"));
}
