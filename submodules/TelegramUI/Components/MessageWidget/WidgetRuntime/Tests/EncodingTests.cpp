// TextEncoder and TextDecoder (V5a plan, Task 3; the Encoding Standard, UTF-8 only): encode and encodeInto, decode with
// the standard's error handling (one U+FFFD per maximal subpart, or a TypeError when fatal), the BOM, and streaming.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { return f() } catch (e) { return e.name } }; 1";

} // namespace

WR_TEST(testEncode) {
    HostEnv env;
    CHECK_EQ(env.eval("const e = new TextEncoder(); [e.encoding, [...e.encode('é')].join(' '), e.encode().length,"
                      " [...e.encode('\\ud800')].join(' '), e.encode('a') instanceof Uint8Array, [...e.encode('\\u{1F600}')].join(' ')].join()"),
             std::string("utf-8,195 169,0,239 191 189,true,240 159 152 128"));
}

WR_TEST(testEncodeInto) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("const d = new Uint8Array(3); const r = new TextEncoder().encodeInto('héllo', d); [r.read, r.written, [...d].join(' ')].join()"),
             std::string("2,3,104 195 169"));
    CHECK_EQ(env.eval("[err(() => new TextEncoder().encodeInto('a', new Uint16Array(2))), err(() => new TextEncoder().encodeInto('a', []))].join()"),
             std::string("TypeError,TypeError"));
}

WR_TEST(testDecode) {
    HostEnv env;
    CHECK_EQ(env.eval("const t = new TextDecoder(); [t.encoding, t.fatal, t.ignoreBOM, t.decode(new Uint8Array([0xd0, 0xaf])),"
                      " t.decode(new Uint8Array([0x61, 0x62]).buffer), t.decode(new DataView(new Uint8Array([0x7a, 0x63]).buffer, 1)),"
                      " t.decode(new Uint8Array([0x61, 0x62, 0x63]).subarray(1)), t.decode()].join('|')"),
             std::string("utf-8|false|false|Я|ab|c|bc|"));
    CHECK_EQ(env.eval("const u = new TextDecoder(); [u.decode(new Uint8Array([0xff])), u.decode(new Uint8Array([0xf0, 0x9f, 0x98])),"
                      " u.decode(new Uint8Array([0xe0, 0x80])), u.decode(new Uint8Array([0xef, 0xbb, 0xbf, 0x41])),"
                      " new TextDecoder('utf-8', { ignoreBOM: true }).decode(new Uint8Array([0xef, 0xbb, 0xbf, 0x41]))]"
                      ".map(s => [...s].map(c => c.codePointAt(0).toString(16)).join(' ')).join('|')"),
             std::string("fffd|fffd|fffd fffd|41|feff 41"));
}

WR_TEST(testFatalAndStream) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("[err(() => new TextDecoder('utf-8', { fatal: true }).decode(new Uint8Array([0xff]))), new TextDecoder('utf-8', { fatal: true }).fatal].join()"),
             std::string("TypeError,true"));
    CHECK_EQ(env.eval("const d = new TextDecoder(); d.decode(new Uint8Array([0xd0]), { stream: true }) + '|' + d.decode(new Uint8Array([0xaf]))"),
             std::string("|Я"));
    // A stream that ends inside a sequence ends with one U+FFFD.
    CHECK_EQ(env.eval("const s = new TextDecoder(); s.decode(new Uint8Array([0x61, 0xe2, 0x82]), { stream: true }) + '|' +"
                      " [...s.decode()].map(c => c.codePointAt(0).toString(16)).join()"),
             std::string("a|fffd"));
}

WR_TEST(testLabels) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("['utf8', ' UTF-8 ', 'unicode-1-1-utf-8', 'x-unicode20utf8'].map(l => new TextDecoder(l).encoding).join()"),
             std::string("utf-8,utf-8,utf-8,utf-8"));
    CHECK_EQ(env.eval("['latin1', 'utf-16le', 'nope'].map(l => err(() => new TextDecoder(l))).join()"),
             std::string("RangeError,RangeError,RangeError"));
}

/// The final review's C1: the options are read before the input's bytes are taken, so a `stream` getter that resizes
/// or transfers the buffer cannot leave the decoder reading freed or moved memory.
WR_TEST(testAnOptionsGetterCannotPullTheBufferAway) {
    HostEnv env;
    CHECK_EQ(env.eval("const ab = new ArrayBuffer(4, { maxByteLength: 8 }); new Uint8Array(ab).set([0x41, 0x42, 0x43, 0x44]);"
                      "JSON.stringify(new TextDecoder().decode(new Uint8Array(ab), { get stream() { ab.resize(0); return false } }))"),
             std::string("\"\""));
    CHECK_EQ(env.eval("const moved = new Uint8Array([0x41, 0x42]).buffer;"
                      "JSON.stringify(new TextDecoder().decode(moved, { get stream() { moved.transfer(); return false } }))"),
             std::string("\"\""));
}

/// The final review's C2 and the fix-wave's C-B: a DataView's buffer, offset and length are the view's own whatever
/// DataView.prototype's accessors were redefined to answer. A negative offset once wrapped the range check and read the
/// heap before the buffer; a `buffer` getter returning a fresh ArrayBuffer had its bytes read after it was freed.
WR_TEST(testARedefinedDataViewAccessorCannotChangeTheView) {
    HostEnv env;
    CHECK_EQ(env.eval("const dv = new DataView(new Uint8Array([65, 66, 67, 68, 69, 70, 71, 72]).buffer, 2, 3);"
                      "for (const [k, v] of [['byteOffset', () => -4096], ['byteLength', () => 4104], ['buffer', () => new ArrayBuffer(1 << 20)]])"
                      "  Object.defineProperty(DataView.prototype, k, { get: v, configurable: true });"
                      "JSON.stringify([new TextDecoder().decode(dv), new Blob([dv]).size])"),
             std::string("[\"CDE\",3]"));
}

/// The fix-wave's m1: taking the bytes of a detached buffer leaves no exception pending (a later, unrelated engine call
/// read it as its own).
WR_TEST(testADetachedBufferLeavesNoPendingException) {
    HostEnv env;
    CHECK_EQ(env.eval("const gone = new ArrayBuffer(4); gone.transfer(); JSON.stringify([new TextDecoder().decode(gone), new Blob([gone]).size])"),
             std::string("[\"\",0]"));
    CHECK(!JS_HasException(env.ctx()));
}
