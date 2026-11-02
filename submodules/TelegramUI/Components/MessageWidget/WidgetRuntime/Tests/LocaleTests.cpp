// Locale (V2a plan, Task 7; widget-sandbox v0.1.0 docs/sdk-v1.md §2.9, packages/core/src/shared/sdk-policy.ts
// checkLocale): navigator.language is the client's UI language as the host passed it, navigator.languages a fresh
// frozen [language]; a missing or malformed locale (not a BCP 47-shaped tag of at most 35 characters) is en-US.
#include <string>

#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

WR_TEST(testTheDefaultIsEnUS) {
    HostEnv env;
    CHECK_EQ(env.eval("const l = navigator.languages; [navigator.language, l.length, l[0], Object.isFrozen(l),"
                      " Array.isArray(l), l !== navigator.languages].join()"),
             std::string("en-US,1,en-US,true,true,true"));
}

WR_TEST(testTheHostsLocale) {
    HostEnv env;
    wr::HostState::of(env.ctx()).setLocale("pt-BR");
    CHECK_EQ(env.eval("navigator.language + ':' + navigator.languages.join()"), std::string("pt-BR:pt-BR"));
    wr::HostState::of(env.ctx()).setLocale("zh-Hant-TW");
    CHECK_EQ(env.eval("navigator.language"), std::string("zh-Hant-TW"));
}

WR_TEST(testAMalformedLocaleIsEnUS) {
    HostEnv env;
    for (const char* locale : {"", "e", "en_US", "en--US", "123", "en-", "ru-123456789", "abcdefghi",
                               "en-aaaaaaaa-bbbbbbbb-cccccccc-dddddd"}) {
        wr::HostState::of(env.ctx()).setLocale("ru");
        wr::HostState::of(env.ctx()).setLocale(locale);
        CHECK_EQ(env.eval("navigator.language"), std::string("en-US"));
    }
    wr::HostState::of(env.ctx()).setLocale("en-aaaaaaaa-bbbbbbbb-cccccccc-ddddd");
    CHECK_EQ(env.eval("navigator.language.length"), std::string("35"));
}
