// Web Storage per SDK v1 §2.8 (V2a plan, Task 2): localStorage and sessionStorage, 4 KB of keys and values in UTF-8
// per area (QuotaExceededError past it, nothing stored), named properties, the stored area there at the first read, and
// a changed area committed to the host at the end of the task that changed it.
#include <string>

#include "Sources/Host/HostState.h"
#include "Sources/Host/Storage.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::HostEnv;

WR_TEST(testStorageReadsAndWrites) {
    HostEnv env;
    CHECK_EQ(env.eval("localStorage.setItem('k', 'v'); localStorage.setItem('n', 1);"
                      "[localStorage.getItem('k'), localStorage.getItem('n'), typeof localStorage.getItem('n'), localStorage.k,"
                      " localStorage.length, [localStorage.key(0), localStorage.key(1)].sort().join('+'), localStorage.key(2),"
                      " localStorage.getItem('missing'), localStorage.missing, 'k' in localStorage,"
                      " localStorage instanceof Storage].join()"),
             std::string("v,1,string,v,2,k+n,,,,true,true"));
    CHECK_EQ(env.eval("localStorage.removeItem('k'); localStorage.x = 7; delete localStorage.n;"
                      "[localStorage.getItem('k'), localStorage.getItem('x'), localStorage.getItem('n'), localStorage.length].join()"),
             std::string(",7,,1"));
    CHECK_EQ(env.eval("localStorage.clear(); localStorage.length"), std::string("0"));
    // A named property never shadows Storage's own members.
    CHECK_EQ(env.eval("localStorage.setItem('getItem', 'x'); typeof localStorage.getItem"), std::string("function"));
}

// widget-sandbox v0.3.0: 4 KB (16 KB before).
WR_TEST(testTheQuotaIsFourKilobytesOfUtf8) {
    HostEnv env;
    // Exactly 4096 bytes: key 'a' and 4095 bytes of value.
    CHECK_EQ(env.eval("localStorage.setItem('a', 'x'.repeat(4095)); localStorage.getItem('a').length"), std::string("4095"));
    CHECK_EQ(env.eval("try { localStorage.setItem('b', ''); 'stored' } catch (e) { e.name + ':' + (e instanceof DOMException) }"),
             std::string("QuotaExceededError:true"));
    CHECK_EQ(env.eval("localStorage.getItem('b')"), std::string("null"));
    // Replacing a value counts its new bytes only.
    CHECK_EQ(env.eval("localStorage.setItem('a', 'y'.repeat(4095)); localStorage.getItem('a')[0]"), std::string("y"));
    // UTF-8: 'é' is two bytes, so 2047 of them and a key of two bytes fill the area.
    CHECK_EQ(env.eval("localStorage.clear(); localStorage.setItem('ab', 'é'.repeat(2047)); "
                      "try { localStorage.setItem('c', 'x'); 'stored' } catch (e) { e.name }"),
             std::string("QuotaExceededError"));
    // The named setter goes through the same quota.
    CHECK_EQ(env.eval("try { localStorage.big = 'x'.repeat(20000); 'stored' } catch (e) { e.name }"), std::string("QuotaExceededError"));
}

WR_TEST(testSessionStorageIsSeparate) {
    HostEnv env;
    CHECK_EQ(env.eval("sessionStorage.setItem('s', '1'); [sessionStorage.getItem('s'), localStorage.getItem('s'),"
                      " sessionStorage === sessionStorage, localStorage !== sessionStorage].join()"),
             std::string("1,,true,true"));
    CHECK_EQ(env.eval("try { sessionStorage.setItem('s', 'x'.repeat(4096)); 'stored' } catch (e) { e.name }"),
             std::string("QuotaExceededError"));
}

WR_TEST(testAChangedAreaIsCommittedAtTheEndOfItsTask) {
    HostEnv env;
    env.eval("setTimeout(() => { localStorage.setItem('k', 'v'); localStorage.setItem('k', 'w'); localStorage.setItem('j', '1'); }, 0); 1");
    env.advance(1);
    CHECK_EQ(env.host().storageCommits.size(), size_t(1));
    if (!env.host().storageCommits.empty()) {
        CHECK_EQ(env.host().storageCommits[0].first, std::string("local"));
        const std::vector<std::pair<std::string, std::string>> expected = {{"k", "w"}, {"j", "1"}};
        CHECK(env.host().storageCommits[0].second == expected);
    }
    // A task that changes nothing commits nothing.
    env.eval("setTimeout(() => localStorage.getItem('k'), 0); 1");
    env.advance(1);
    CHECK_EQ(env.host().storageCommits.size(), size_t(1));
}

/// The final review's I2: a write in the rendering update (a MediaQueryList change listener, a ResizeObserver callback)
/// is committed at the end of its own step, not at some later task's.
WR_TEST(testAWriteInTheRenderingUpdateIsCommittedInItsStep) {
    wr_test::RenderEnv env("<!doctype html><html><head></head><body><div id=d style=\"height:10px\"></div><script>"
                           "matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => localStorage.setItem('dark', String(e.matches)));"
                           "</script></body></html>");
    const size_t before = env.env().host().storageCommits.size();
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.env().drain();
    CHECK_EQ(env.env().host().storageCommits.size(), before + 1);
    env.env().eval("new ResizeObserver(() => sessionStorage.setItem('ro', '1')).observe(document.getElementById('d'));"
                   "setTimeout(() => {}, 0); 1");
    env.env().advance(1);
    CHECK_EQ(env.env().host().storageCommits.size(), before + 2);
    CHECK(!env.env().host().storageCommits.empty() && env.env().host().storageCommits.back().first == "session");
}

/// The final review's I3: a key is converted only as far as the quota could hold one (a longer key cannot be stored,
/// so it is absent).
WR_TEST(testAHugeKeyIsAbsent) {
    HostEnv env;
    env.eval("window.huge = 'a'.repeat(3000000); localStorage.setItem('k', 'v'); 1");
    CHECK_EQ(env.eval("String(localStorage.getItem(huge))"), std::string("null"));
    CHECK_EQ(env.eval("localStorage.removeItem(huge); localStorage.length"), std::string("1"));
}

WR_TEST(testTheStoredAreaIsThereAtTheFirstRead) {
    HostEnv env;
    env.host().storedAreas["local"] = {{"k", "v"}, {"n", "2"}};
    CHECK_EQ(env.eval("[localStorage.getItem('k'), localStorage.n, localStorage.length, sessionStorage.length].join()"),
             std::string("v,2,2,0"));
}

namespace {

size_t diagnosticsOfKind(HostEnv& env, const std::string& kind) {
    size_t count = 0;
    for (const auto& [k, detail] : env.host().diagnostics) {
        count += k == kind ? 1 : 0;
    }
    return count;
}

} // namespace

/// SDK v1 §3.1 (V2b plan, Task 1): a preload past the quota is dropped whole, with `storage-rejected`, and the widget
/// starts empty; one exactly at the quota loads.
WR_TEST(testAPreloadOverTheQuotaIsDroppedWhole) {
    {
        HostEnv env;
        env.host().storedAreas["local"] = {{"a", std::string(2047, 'x')}, {"b", std::string(2047, 'y')}};
        CHECK_EQ(env.eval("localStorage.length"), std::string("2"));
        CHECK_EQ(diagnosticsOfKind(env, "storage-rejected"), size_t(0));
    }
    {
        HostEnv env;
        env.host().storedAreas["local"] = {{"a", std::string(2047, 'x')}, {"b", std::string(2048, 'y')}};
        CHECK_EQ(env.eval("[localStorage.length, localStorage.getItem('a')].join()"), std::string("0,"));
        CHECK_EQ(diagnosticsOfKind(env, "storage-rejected"), size_t(1));
    }
}

/// V2b plan, Task 1: once the runtime has stopped nothing more is committed, so the writes of the task that stopped
/// never reach the host.
WR_TEST(testNothingIsCommittedAfterAStop) {
    wr_test::ScopedProductSlices slices;
    HostEnv env;
    env.eval("setTimeout(() => { localStorage.setItem('k', 'v'); for (;;) {} }, 0); 1");
    wr_test::stopAfter(env.runtime());
    env.advance(1);
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(env.host().storageCommits.size(), size_t(0));
}
