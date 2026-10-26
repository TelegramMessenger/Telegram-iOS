// crypto (V5a plan, Task 1; Web Cryptography API §10.1: getRandomValues and randomUUID only, no subtle): random bytes
// from the host (Host::randomBytes) into an integer typed array of at most 65,536 bytes.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

WR_TEST(testGetRandomValuesFillsAndReturnsItsArgument) {
    HostEnv env;
    CHECK_EQ(env.eval("const a = new Uint8Array(32); [crypto.getRandomValues(a) === a, a.some(b => b !== 0)].join()"),
             std::string("true,true"));
    CHECK_EQ(env.eval("[new Int16Array(8), new Uint32Array(4), new BigUint64Array(2), new Uint8ClampedArray(4)]"
                      ".every(x => crypto.getRandomValues(x) === x && Array.prototype.some.call(x, v => v != 0))"),
             std::string("true"));
}

WR_TEST(testGetRandomValuesRefusesWhatWebCryptoRefuses) {
    HostEnv env;
    env.eval("window.err = f => { try { f(); return 'ok' } catch (e) { return (e instanceof DOMException ? 'DOMException:' : '') + e.name } }; 1");
    CHECK_EQ(env.eval("[new Float32Array(4), new Float64Array(1), new DataView(new ArrayBuffer(4))]"
                      ".map(x => err(() => crypto.getRandomValues(x))).join()"),
             std::string("DOMException:TypeMismatchError,DOMException:TypeMismatchError,DOMException:TypeMismatchError"));
    CHECK_EQ(env.eval("[[], {}, undefined].map(x => err(() => crypto.getRandomValues(x))).join()"),
             std::string("TypeError,TypeError,TypeError"));
    CHECK_EQ(env.eval("[err(() => crypto.getRandomValues(new Uint8Array(65537))), err(() => crypto.getRandomValues(new Uint8Array(65536)))].join()"),
             std::string("DOMException:QuotaExceededError,ok"));
    CHECK_EQ(env.eval("const b = new Uint8Array(8); crypto.getRandomValues(b.subarray(2, 4)); [b[0], b[1], b[4], b[7]].join()"),
             std::string("0,0,0,0"));
}

WR_TEST(testRandomUUIDIsVersion4) {
    HostEnv env;
    CHECK_EQ(env.eval("const ids = Array.from({ length: 50 }, () => crypto.randomUUID());"
                      "[ids.every(u => /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(u)),"
                      " new Set(ids).size].join()"),
             std::string("true,50"));
    CHECK_EQ(env.eval("[crypto === crypto, typeof crypto.subtle, typeof Crypto, (() => { try { new Crypto(); return 'made' } catch (e) { return e.name } })()].join()"),
             std::string("true,undefined,function,TypeError"));
}
