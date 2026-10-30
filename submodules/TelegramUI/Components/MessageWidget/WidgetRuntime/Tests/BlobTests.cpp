// Blob (V5a plan, Task 9; File API §3): parts (strings as UTF-8, buffer sources copied, blobs appended), the type,
// slice, text and arrayBuffer; URL.createObjectURL makes nothing.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

WR_TEST(testParts) {
    HostEnv env;
    CHECK_EQ(env.eval("const b = new Blob(['ab', new Uint8Array([99]), new Blob(['d'])], { type: 'Text/Plain' });"
                      "[b.size, b.type, new Blob().size, new Blob([], { type: 'a\\u00e9' }).type, new Blob([], { type: 'x\\ny' }).type,"
                      " new Blob(['\\ud800']).size, new Blob([new Uint8Array([1, 2, 3]).buffer, new DataView(new ArrayBuffer(2))]).size].join()"),
             std::string("4,text/plain,0,,,3,5"));
    CHECK_EQ(env.eval("(() => { try { new Blob(5); return 'no' } catch (e) { return e.name } })()"), std::string("TypeError"));
}

WR_TEST(testReads) {
    HostEnv env;
    env.eval("window.out = []; const b = new Blob(['ab', new Uint8Array([99, 100])]);"
             "b.text().then(t => out.push('text:' + t));"
             "b.arrayBuffer().then(a => out.push('bytes:' + [...new Uint8Array(a)].join(' ')));"
             "b.slice(1, 3).text().then(t => out.push('slice:' + t + ':' + b.slice(1, 3).size));"
             "b.slice(-1).text().then(t => out.push('tail:' + t));"
             "out.push('type:' + b.slice(0, 1, 'X/Y').type); 1");
    env.drain();
    CHECK_EQ(env.eval("out.join('|')"), std::string("type:x/y|text:abcd|bytes:97 98 99 100|slice:bc:2|tail:d"));
}

WR_TEST(testCreateObjectURL) {
    HostEnv env;
    CHECK_EQ(env.eval("URL.createObjectURL(new Blob(['x'])) === ''"), std::string("true"));
}

/// The final review's I1: a Blob's type is kept in the JS heap, under the memory limit (it was a C++-heap copy per Blob,
/// which the limit never saw).
WR_TEST(testABlobTypeIsInTheJSHeap) {
    HostEnv env;
    env.eval("window.t = 'A'.repeat(1 << 20); window.keep = []; 1");
    JSRuntime* rt = env.runtime().jsRuntime();
    JSMemoryUsage before, after;
    JS_ComputeMemoryUsage(rt, &before);
    CHECK_EQ(env.eval("for (let i = 0; i < 16; i++) keep.push(new Blob([], { type: t })); [keep[15].type.length, keep[15].type[0]].join()"),
             std::string("1048576,a"));
    JS_ComputeMemoryUsage(rt, &after);
    CHECK(after.malloc_size - before.malloc_size >= 16 * (1 << 20));
}
