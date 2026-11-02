// atob and btoa (V5a plan, Task 2; HTML §8.3 "Base64 utility methods", Infra's forgiving-base64): btoa over code
// units of at most 0xFF, atob decoding forgivingly into such code units; anything else is an InvalidCharacterError.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { return f() } catch (e) { return (e instanceof DOMException ? 'DOMException:' : '') + e.name } }; 1";

} // namespace

WR_TEST(testBtoa) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("[btoa('hi'), btoa(''), btoa('\\xff\\x00'), btoa('\\u00e9'), btoa('abc'), btoa('ab')].join(' ')"),
             std::string("aGk=  /wA= 6Q== YWJj YWI="));
    CHECK_EQ(env.eval("[err(() => btoa('\\u0100')), err(() => btoa('\\ud800'))].join()"),
             std::string("DOMException:InvalidCharacterError,DOMException:InvalidCharacterError"));
}

WR_TEST(testAtobIsForgiving) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("[atob('aGk='), atob('aGk'), atob(' aG\\nk= \\t'), atob(''), atob('YWJj')].join('|')"),
             std::string("hi|hi|hi||abc"));
    CHECK_EQ(env.eval("[...atob('/wA=')].map(c => c.charCodeAt(0)).join()"), std::string("255,0"));
    CHECK_EQ(env.eval("['a', 'aGk==', 'aG=k', 'a*b=', 'aGk=a'].map(s => err(() => atob(s))).join()"),
             std::string("DOMException:InvalidCharacterError,DOMException:InvalidCharacterError,DOMException:InvalidCharacterError,"
                         "DOMException:InvalidCharacterError,DOMException:InvalidCharacterError"));
}

