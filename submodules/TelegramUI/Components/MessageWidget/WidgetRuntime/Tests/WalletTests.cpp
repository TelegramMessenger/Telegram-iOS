// The wallet (widget-sandbox v0.5.0, docs/sdk-v1.md §2.18; v0.5.0 plan, Task 3), against upstream's tests
// (packages/core/tests/unit/sdk.test.ts "SDK v1: the wallet", packages/desktop/tests/test_main.cpp sdk_wallet_*, and the
// corpus's wallet-* attacks): `TelegramWidget.wallet` only with the wallet and canQuery, `request(data, { wallet: true })`
// on a tap only, the calls' arguments checked as the shim checks them, the gate's grant (the answer to a call made by a
// tap lets one wallet call follow within 10 s), and the wallet's own failure codes.
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "Sources/Events/Taps.h"
#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"
#include "twidget/sdk_policy.h"

using wr::PointerPhase;
using wr_test::HostEnv;
using wr_test::RenderEnv;

namespace {

using Calls = std::vector<std::pair<std::string, std::string>>;

/// A user-friendly destination (48 characters) and the transaction upstream's tests pay with.
const std::string kAddress = "EQ" + std::string(46, 'a');
const std::string kTx = "{\"valid_until\":1900000000,\"messages\":[{\"address\":\"" + kAddress + "\",\"amount\":\"1500000000\"}]}";

/// `#t` absolutely placed at (10, 10) 100 × 30, so a tap at (50, 25) hits it; `T` is TelegramWidget, `log` a list,
/// `TX` the transaction above.
std::string page(const std::string& script) {
    return "<!doctype html><html><head><style>body{margin:0;padding:0} #t{position:absolute;left:10px;top:10px;"
           "width:100px;height:30px;display:block}</style></head><body><div id=t>t</div>"
           "<script>window.log = []; const T = TelegramWidget; const t = document.getElementById('t'); const TX = " +
           kTx + ";" + script + "</script></body></html>";
}

twidget::WidgetContext context(bool canQuery, bool backgroundQuery, bool wallet, bool preview = false) {
    twidget::WidgetContext context;
    context.canQuery = canQuery;
    context.backgroundQuery = backgroundQuery;
    context.wallet = wallet;
    context.preview = preview;
    context.chatType = "private";
    return context;
}

void pass(RenderEnv& env, const twidget::WidgetContext& context) {
    wr::HostState::of(env.ctx()).setContext(env.ctx(), context);
}

void tap(RenderEnv& env) {
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 50, 25, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 50, 25, 1, true);
    env.env().drain();
}

twidget::WidgetRequestOutcome answer(std::optional<std::string> result) {
    twidget::WidgetRequestOutcome outcome;
    outcome.answer.result = std::move(result);
    return outcome;
}

twidget::WidgetRequestOutcome failure(twidget::WidgetRequestFailure failure) {
    twidget::WidgetRequestOutcome outcome;
    outcome.failure = failure;
    return outcome;
}

void complete(RenderEnv& env, int64_t id, const twidget::WidgetRequestOutcome& outcome) {
    wr::HostState::of(env.ctx()).completeRequest(env.ctx(), id, outcome);
    env.env().drain();
}

std::vector<std::string> diagnosticsOf(const wr_test::TestHost& host, const std::string& kind) {
    std::vector<std::string> out;
    for (const auto& [k, detail] : host.diagnostics) {
        if (k == kind) {
            out.push_back(detail);
        }
    }
    return out;
}

/// The bridge call a checked sendTransaction of TX posts, as request `id` with `data`.
std::pair<std::string, std::string> walletCall(int64_t id, const std::string& data) {
    return {"wallet", "[\"" + std::to_string(id) + "\",\"sendTransaction\"," + kTx + ",\"" + data + "\"]"};
}

/// Logs a settled wallet call: `ok:<result>:<frozen>` or `err:<code>`.
constexpr const char* kPay = "const pay = (tx, d) => T.wallet.sendTransaction(tx, d).then(a => log.push('ok:' + a.result + ':' + Object.isFrozen(a)), e => log.push(d + ':' + e.code));";

} // namespace

WR_TEST(testWalletIsThereOnlyWithTheWalletAndCanQueryAndNeverInAPreview) {
    const char* probe = "TelegramWidget.wallet === null ? 'null' : [typeof TelegramWidget.wallet.sendTransaction, typeof TelegramWidget.wallet.signData,"
                        " Object.isFrozen(TelegramWidget.wallet), TelegramWidget.wallet === TelegramWidget.wallet].join()";
    const std::pair<twidget::WidgetContext, std::string> cases[] = {
        {context(true, true, true), "function,function,true,true"},
        {context(true, false, true), "function,function,true,true"},
        {context(true, true, false), "null"},
        {context(false, false, true), "null"},
        {context(true, true, true, true), "null"},
    };
    for (const auto& [ctx, expected] : cases) {
        HostEnv env;
        wr::HostState::of(env.ctx()).setContext(env.ctx(), ctx);
        CHECK_EQ(env.eval(probe), expected);
    }
}

WR_TEST(testWalletRequestForTheWalletGoesOutOnATap) {
    RenderEnv env(page("t.onclick = () => T.request('pay:1', { wallet: true }).then(a => log.push(a.result));"));
    pass(env, context(true, false, true));
    tap(env);
    CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"1\",\"pay:1\",{\"wallet\":true}]"}}));
    complete(env, 1, answer("ok"));
    CHECK_EQ(env.env().eval("log.join()"), std::string("ok"));
}

WR_TEST(testWalletRequestForTheWalletWithoutItIsRefused) {
    RenderEnv env(page("t.onclick = () => T.request('pay:1', { wallet: true }).catch(e => log.push(e.code));"));
    pass(env, context(true, true, false));
    tap(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("NOT_ALLOWED"));
    CHECK(env.env().host().bridgeCalls.empty());
    CHECK(diagnosticsOf(env.env().host(), "request-blocked") ==
          (std::vector<std::string>{"request refused (no-wallet): the client has no wallet for this user (no WidgetContext.wallet)"}));
}

/// Never in the background, also in the private chat with the bot: a request for the wallet and a wallet call from a
/// timer are refused; a plain background request still goes out.
WR_TEST(testWalletNothingFromATimer) {
    RenderEnv env(page(kPay));
    pass(env, context(true, true, true));
    env.env().eval("setTimeout(() => { pay(TX, 'tx'); T.request('w', { wallet: true }).catch(e => log.push('rq:' + e.code)); }, 0); 1");
    env.env().advance(10);
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string("tx:NOT_ALLOWED rq:NOT_ALLOWED"));
    CHECK(env.env().host().bridgeCalls.empty());
    CHECK(diagnosticsOf(env.env().host(), "request-blocked") ==
          (std::vector<std::string>{
              "wallet.sendTransaction refused (no-activation): it needs a tap on the visible widget, or the answer to a call made by a tap within 10 s; one call each",
              "request refused (no-activation): a request for the wallet needs a tap on the visible widget, one request per tap"}));
    env.env().eval("T.request('plain'); 1");
    env.env().drain();
    CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"3\",\"plain\"]"}}));
}

WR_TEST(testWalletRequestOptionsAreChecked) {
    HostEnv env;
    wr::HostState::of(env.ctx()).setContext(env.ctx(), context(true, false, true));
    CHECK_EQ(env.eval("const r = []; for (const o of [{ wallet: 1 }, { x: true }, { wallet: true, x: undefined }, { x: undefined }, [], () => {}, null, 'w', 5]) {"
                      " try { TelegramWidget.request('x', o); r.push('no'); } catch (e) { r.push(e.constructor.name); } } r.join()"),
             std::string("TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError"));
    CHECK_EQ(env.eval("const s = []; for (const o of [undefined, {}, { wallet: null }, { wallet: undefined }, { wallet: false }, new Date(0)]) {"
                      " try { TelegramWidget.request('x', o).catch(() => {}); s.push('ok'); } catch (e) { s.push(e.constructor.name); } } s.join()"),
             std::string("ok,ok,ok,ok,ok,ok"));
    CHECK(env.host().bridgeCalls.empty());
}

WR_TEST(testWalletSendTransactionOnATapPostsTheCheckedCall) {
    RenderEnv env(page(std::string(kPay) + "t.onclick = () => pay({ messages: TX.messages, valid_until: 1900000000, network: null, from: undefined }, 'paid:1');"));
    pass(env, context(true, false, true));
    tap(env);
    // TON Connect's field order, the null and undefined fields left out.
    CHECK(env.env().host().bridgeCalls == (Calls{walletCall(1, "paid:1")}));
    complete(env, 1, answer("thanks"));
    CHECK_EQ(env.env().eval("log.join()"), std::string("ok:thanks:true"));
}

/// A tap pays: a request with the wallet, the bot answers with the transaction, the call on that answer goes out without
/// a new tap (the grant), the bot answers the payment.
WR_TEST(testWalletTheAnswerToATapsRequestGrantsTheCall) {
    RenderEnv env(page(std::string(kPay) + "t.onclick = () => T.request('pay:42', { wallet: true }).then(a => { log.push('tx'); pay(JSON.parse(a.result), 'paid:42'); });"));
    pass(env, context(true, false, true));
    tap(env);
    complete(env, 1, answer(kTx));
    CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"1\",\"pay:42\",{\"wallet\":true}]"}, walletCall(2, "paid:42")}));
    complete(env, 2, answer("thanks"));
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string("tx ok:thanks:true"));
}

/// The grant lasts 10 s from the answer, on the step's clock: at 9.999 s the call goes out, at 10.001 s it needs a tap.
WR_TEST(testWalletTheGrantLastsTenSeconds) {
    for (const auto& [delay, expected] : {std::pair<double, size_t>{9999, 2}, std::pair<double, size_t>{10001, 1}}) {
        RenderEnv env(page(std::string(kPay) + "t.onclick = () => T.request('order');"));
        pass(env, context(true, false, true));
        tap(env);
        complete(env, 1, answer("ok"));
        env.env().advance(delay);
        env.env().eval("pay(TX, 'late'); 1");
        env.env().drain();
        CHECK_EQ(env.env().host().bridgeCalls.size(), expected);
        CHECK_EQ(env.env().eval("log.join()"), std::string(expected == 2 ? "" : "late:NOT_ALLOWED"));
    }
}

/// A refusal in the window brings no grant: the next call needs a tap. One window per grant: a second call in the same
/// answer is BUSY, and a timer later gets nothing (the corpus's wallet-grant-reuse).
WR_TEST(testWalletOneCallPerGrant) {
    RenderEnv env(page(std::string(kPay) + "t.onclick = () => T.request('order').then(() => {"
                                           " T.wallet.sendTransaction(TX, 'first').then(() => log.push('first:sent'), e => { log.push('first:' + e.code);"
                                           "   pay(TX, 'after-refusal'); setTimeout(() => pay(TX, 'timer'), 1000); });"
                                           " pay(TX, 'second'); });"));
    pass(env, context(true, false, true));
    tap(env);
    complete(env, 1, answer("ok"));
    CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"1\",\"order\"]"}, walletCall(2, "first")}));
    complete(env, 2, failure(twidget::WidgetRequestFailure::Rejected));
    env.env().advance(1500);
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string("second:BUSY first:REJECTED after-refusal:NOT_ALLOWED timer:NOT_ALLOWED"));
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(2));
}

/// The answer to a background request brings no grant.
WR_TEST(testWalletABackgroundAnswerBringsNoGrant) {
    RenderEnv env(page(kPay));
    pass(env, context(true, true, true));
    env.env().eval("T.request('bg').then(() => pay(TX, 'after')); 1");
    env.env().drain();
    CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"1\",\"bg\"]"}}));
    complete(env, 1, answer("ok"));
    CHECK_EQ(env.env().eval("log.join()"), std::string("after:NOT_ALLOWED"));
}

/// A wallet call keeps the wallet's codes; a request's Rejected or BadRequest is FAILED; INVALID_ANSWER brings no grant.
WR_TEST(testWalletFailureCodes) {
    {
        RenderEnv env(page(std::string(kPay) + "t.onclick = () => pay(TX, 'w');"));
        pass(env, context(true, false, true));
        tap(env);
        complete(env, 1, failure(twidget::WidgetRequestFailure::BadRequest));
        tap(env);
        complete(env, 2, failure(twidget::WidgetRequestFailure::Timeout));
        CHECK_EQ(env.env().eval("log.join(' ')"), std::string("w:BAD_REQUEST w:TIMEOUT"));
    }
    {
        RenderEnv env(page("t.onclick = () => T.request('r').catch(e => log.push(e.code));"));
        pass(env, context(true, false, true));
        tap(env);
        complete(env, 1, failure(twidget::WidgetRequestFailure::Rejected));
        tap(env);
        complete(env, 2, failure(twidget::WidgetRequestFailure::BadRequest));
        CHECK_EQ(env.env().eval("log.join(' ')"), std::string("FAILED FAILED"));
    }
    {
        RenderEnv env(page(std::string(kPay) + "t.onclick = () => T.request('r').catch(e => { log.push(e.code); pay(TX, 'next'); });"));
        pass(env, context(true, false, true));
        tap(env);
        complete(env, 1, answer(std::string("a\0b", 3)));
        CHECK_EQ(env.env().eval("log.join(' ')"), std::string("INVALID_ANSWER next:NOT_ALLOWED"));
    }
}

/// A wallet call's rejection is worded as upstream's shim words it: `wallet.<method>: `, the wallet's words where they
/// differ (WALLET_MESSAGES), a request's otherwise (upstream's sdk.test.ts: "wallet.sendTransaction: the user declined in
/// the wallet window").
WR_TEST(testWalletErrorsCarryTheShimsWords) {
    constexpr const char* kLogMessage = "const say = p => p.then(a => log.push('ok'), e => log.push(e.message));";
    {
        RenderEnv env(page(std::string(kLogMessage) + "t.onclick = () => say(T.wallet.sendTransaction(TX, 'w'));"));
        pass(env, context(true, false, true));
        tap(env);
        complete(env, 1, failure(twidget::WidgetRequestFailure::Rejected));
        tap(env);
        complete(env, 2, failure(twidget::WidgetRequestFailure::BadRequest));
        tap(env);
        complete(env, 3, failure(twidget::WidgetRequestFailure::Failed));
        tap(env);
        complete(env, 4, failure(twidget::WidgetRequestFailure::Timeout));
        CHECK_EQ(env.env().eval("log.join('|')"),
                 std::string("wallet.sendTransaction: the user declined in the wallet window|"
                             "wallet.sendTransaction: the wallet refused it (the network, the sender, the expiry or the cells)|"
                             "wallet.sendTransaction: the client could not complete the call|"
                             "wallet.sendTransaction: the bot did not answer in time"));
    }
    {
        RenderEnv env(page(std::string(kLogMessage) + "t.onclick = () => { say(T.wallet.signData({ type: 'text', text: 'x' }, 'a'));"
                                                      " say(T.wallet.sendTransaction(TX, 'b')); };"));
        pass(env, context(true, false, true));
        env.env().eval("say(T.wallet.sendTransaction(TX, 'c')); 1");
        env.env().drain();
        tap(env);
        CHECK_EQ(env.env().eval("log.join('|')"),
                 std::string("wallet.sendTransaction: it needs a tap on the widget and runs in that tap's handler (one call per tap), or follows within "
                             "10 s the answer to a call made by a tap|"
                             "wallet.sendTransaction: a request is already in flight; wait for its answer"));
        // A reference kept past a context without the wallet.
        env.env().eval("window.W = T.wallet; 1");
        complete(env, 2, answer("ok"));
        pass(env, context(true, false, false));
        env.env().eval("log.length = 0; say(W.signData({ type: 'text', text: 'x' }, 'd')); 1");
        env.env().drain();
        CHECK_EQ(env.env().eval("log.join('|')"), std::string("wallet.signData: the client has no wallet for this user (TelegramWidget.wallet is null)"));
    }
}

/// TON Connect's transaction as the shim checks it: anything else throws a TypeError and posts nothing.
WR_TEST(testWalletMalformedTransactionsThrow) {
    HostEnv env;
    wr::HostState::of(env.ctx()).setContext(env.ctx(), context(true, true, true));
    env.eval("var A = '" + kAddress + "', M = { address: A, amount: '1' }; 1");
    CHECK_EQ(env.eval("const r = []; for (const tx of ["
                      " { messages: [] }, { messages: Array(256).fill(M) }, { messages: [{ address: '0:' + 'a'.repeat(64), amount: '1' }] },"
                      " { messages: [{ address: A, amount: 1 }] }, { messages: [{ address: A, amount: '01' }] }, { validUntil: 1, messages: [M] },"
                      " { messages: [{ address: A, amount: '1', extra_currency: {} }] }, { valid_until: NaN, messages: [M] }, { valid_until: 1.5, messages: [M] },"
                      " { messages: [{ address: A, amount: '1', payload: () => 'te6' }] }, { messages: [new Date(0)] }, { messages: [M], x: undefined },"
                      " { network: '-1', messages: [M] }, { from: 'me', messages: [M] }, { messages: [{ address: A, amount: '1', payload: 'a'.repeat(8193) }] },"
                      " { messages: M }, () => {}, null, 'tx', [M]]) {"
                      " try { TelegramWidget.wallet.sendTransaction(tx, 'd'); r.push('no'); } catch (e) { r.push(e.constructor.name); } } r.join()"),
             std::string("TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,"
                         "TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError"));
    CHECK_EQ(env.eval("const d = []; for (const data of [undefined, '', 'x'.repeat(65), 5, '\\uD800']) {"
                      " try { TelegramWidget.wallet.sendTransaction({ messages: [M] }, data); d.push('no'); } catch (e) { d.push(e.constructor.name); } } d.join()"),
             std::string("TypeError,TypeError,TypeError,TypeError,TypeError"));
    CHECK(env.host().bridgeCalls.empty());
    // A getter is read as the shim reads it; 255 messages, the network and sender in both forms, and a proxied array
    // (Array.isArray looks through it) pass.
    CHECK_EQ(env.eval("const g = []; for (const tx of [{ get messages() { g.push('get'); return [M]; } }, { messages: Array(255).fill(M) },"
                      " { network: '-239', from: '0:' + 'b'.repeat(64), messages: [M] }, { network: '-3', from: 'UQ' + 'c'.repeat(46), messages: [M] },"
                      " { messages: new Proxy([M], {}) }]) {"
                      " try { TelegramWidget.wallet.sendTransaction(tx, 'd').catch(() => {}); g.push('ok'); } catch (e) { g.push(e.constructor.name); } } g.join()"),
             std::string("get,ok,ok,ok,ok,ok"));
}

/// The shim reads the messages with `for…of` once their `length` is from 1 to 255: what goes out is what the array's
/// iterator gives, whatever its indices hold, and the global Symbol replaced changes nothing.
WR_TEST(testWalletTheMessagesAreTheIteratorsValues) {
    RenderEnv env(page(std::string(kPay) + "const A = TX.messages[0].address;"
                                           "const ms = [{ address: A, amount: '7' }];"
                                           "ms[Symbol.iterator] = function* () { yield TX.messages[0]; };"
                                           "window.Symbol = { iterator: 'nope' };"
                                           "t.onclick = () => pay({ valid_until: 1900000000, messages: ms }, 'paid:1');"));
    pass(env, context(true, false, true));
    tap(env);
    CHECK(env.env().host().bridgeCalls == (Calls{walletCall(1, "paid:1")}));

    HostEnv host;
    wr::HostState::of(host.ctx()).setContext(host.ctx(), context(true, true, true));
    host.eval("var M = { address: '" + kAddress + "', amount: '1' }, closed = 0;"
              "var withValues = (length, values) => { const a = Array(length).fill(M); a[Symbol.iterator] = values; return a; };"
              "var endless = () => ({ next: () => ({ done: false, value: M }), return() { closed++; return {}; } }); 1");
    // The length bounds first, then the iterator: none, nothing, 256 values (the rest unread, the iterator closed), a
    // non-object result; 255 values pass whatever the length says.
    CHECK_EQ(host.eval("const r = []; for (const ms of [withValues(0, function* () { yield M; }), withValues(256, function* () { yield M; }),"
                       " withValues(1, undefined), withValues(1, function* () {}), withValues(1, endless), withValues(1, () => ({ next: () => 5 })),"
                       " withValues(1, function* () { for (let i = 0; i < 255; i++) yield M; })]) {"
                       " try { TelegramWidget.wallet.sendTransaction({ messages: ms }, 'd').catch(() => {}); r.push('ok'); } catch (e) { r.push(e.constructor.name); } }"
                       " r.join() + ':' + closed"),
             std::string("TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,ok:1"));
}

/// TON Connect's signData payload: text, bytes or a cell with its schema; no domain (the client signs for the bot).
WR_TEST(testWalletSignDataPayloads) {
    HostEnv env;
    wr::HostState::of(env.ctx()).setContext(env.ctx(), context(true, true, true));
    CHECK_EQ(env.eval("const r = []; for (const p of [{ type: 'text', text: 'x', domain: 'example.com' }, { type: 'text', text: 'é'.repeat(2049) },"
                      " { type: 'text', text: '' }, { type: 'cell', cell: 'te6' }, { type: 'binary', bytes: '***' }, { type: 'x' }, { text: 'x' },"
                      " { type: 'binary', bytes: 'AAAA' }, { type: 'cell', schema: 'x#_ = X;', cell: 'te6', network: '-239' }, { type: 'text', text: 'é'.repeat(2048) }]) {"
                      " try { TelegramWidget.wallet.signData(p, 's').catch(() => {}); r.push('no'); } catch (e) { r.push(e.constructor.name); } } r.join()"),
             std::string("TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,no,no,no"));
    CHECK(env.host().bridgeCalls.empty());
}

WR_TEST(testWalletSignDataOnATapPostsThePayload) {
    RenderEnv env(page("t.onclick = () => T.wallet.signData({ type: 'text', text: 'I agree', network: undefined }, 'sign:1').then(a => log.push('ok:' + a.result));"));
    pass(env, context(true, false, true));
    tap(env);
    CHECK(env.env().host().bridgeCalls == (Calls{{"wallet", "[\"1\",\"signData\",{\"type\":\"text\",\"text\":\"I agree\"},\"sign:1\"]"}}));
    complete(env, 1, answer("signed"));
    CHECK_EQ(env.env().eval("log.join()"), std::string("ok:signed"));
}

/// A preview has no wallet, and its request for the wallet is NOT_ALLOWED with nothing posted.
WR_TEST(testWalletAPreviewAsksNothing) {
    RenderEnv env(page(""));
    pass(env, context(true, true, true, true));
    env.env().eval("T.request('x', { wallet: true }).catch(e => log.push(e.code)); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join() + ':' + (T.wallet === null)"), std::string("NOT_ALLOWED:true"));
    CHECK(env.env().host().bridgeCalls.empty());
}
