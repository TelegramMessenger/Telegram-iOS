// CSS.supports from profile 1's tables (V5c plan, Tasks 3 and 4; profile-v1.md, D23 and "Tables": true only when the
// validator keeps the declaration as written). The rows below are the profile's rules, one or more per rule; they are
// also the cases V4's validator must keep or change.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

/// Runs `rows` ("property", "value", expected) through CSS.supports(property, value); the mismatches, or "".
std::string mismatches(HostEnv& env, const char* rows) {
    return env.eval(std::string("const rows = ") + rows + ";"
                    "rows.map(([p, v, want]) => CSS.supports(p, v) === want ? '' : JSON.stringify([p, v])).filter(Boolean).join(' ')");
}

} // namespace

WR_TEST(testTheConformanceDeclarations) {
    HostEnv env;
    CHECK_EQ(env.eval("[CSS.supports('display', 'flex'), CSS.supports('display', 'no-such-value'), CSS.supports('transform', 'rotateY(10deg)')].join()"),
             std::string("true,false,false"));
}

WR_TEST(testTheDeclarationRules) {
    HostEnv env;
    CHECK_EQ(mismatches(env, R"JS([
        ['color', 'red', true], ['color', 'RED', true], [' DISPLAY ', ' FLEX ', true], ['display', 'grid', true],
        ['display', 'contents', false], ['position', 'sticky', false], ['position', '-webkit-sticky', false],
        ['position', 'absolute', true], ['overflow', 'auto', false], ['overflow-x', 'scroll', false],
        ['overflow', 'hidden', true], ['background-clip', 'text', false], ['background-clip', 'padding-box', true],
        ['transform', 'translate(1px, 2px)', true], ['transform', 'translateZ(1px)', false],
        ['transform', 'rotate(1deg) perspective(1px)', false], ['rotate', 'x 1deg', false], ['rotate', '45deg', true],
        ['translate', '1px 2px 3px', false], ['scale', '1 2', true], ['filter', 'blur(2px)', true],
        ['filter', 'sepia(1)', false], ['filter', 'url(#f)', false], ['font-family', 'Arial', false],
        ['font-family', 'sans-serif', true], ['font-family', 'system-ui, serif', true], ['font', '12px Arial', false],
        ['font', '12px/1.2 sans-serif', true], ['font', 'bold 12px sans-serif', true], ['width', '10px', true],
        ['width', '10furlongs', false], ['width', 'calc(1px + 2px)', true], ['width', 'foo(1px)', false],
        ['--x', 'anything at all', true], ['behavior', 'url(x)', false], ['color', 'inherit', true],
        ['display', 'revert-layer', true], ['color', 'red !important', false],
        ['background-image', 'url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==)', true], ['background-image', 'url(https://x/a.png)', false],
        ['background-image', 'url("x.svg")', false], ['background-image', 'url("data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==")', true], ['background-image', 'url("data:image/gif,AA")', false],
        ['display', 'var(--d)', true], ['transform', 'translate(var(--x))', true],
        ['transform', 'var(--a) rotateY(1deg)', false], ['color', '', false], ['', 'red', false],
        ['width', 'CALC(1PX + 2PX)', true], ['margin', '1px 2px', true]
    ])JS"),
             std::string(""));
}

/// widget-sandbox v0.1.1: user-select's value set (css.values) holds for CSS.supports as for the validator.
WR_TEST(testUserSelectValues) {
    HostEnv env;
    CHECK_EQ(env.eval("[CSS.supports('user-select', 'text'), CSS.supports('-webkit-user-select', 'none'),"
                      " CSS.supports('user-select', 'all'), CSS.supports('user-select', 'contain'),"
                      " CSS.supports('(user-select: auto)')].join()"),
             std::string("true,true,false,false,true"));
}

/// V5c final review, I1: var() (or attr()) skips only the display and position value tables, as the references gate
/// only the value-set check on it; every rule that rewrites or drops a declaration still applies.
WR_TEST(testVarSkipsOnlyTheValueTables) {
    HostEnv env;
    CHECK_EQ(mismatches(env, R"JS([
        ['overflow', 'auto var(--y)', false], ['position', 'sticky var(--y)', false],
        ['background-clip', 'text var(--c)', false], ['translate', 'var(--x) 1px 2px', false],
        ['rotate', 'x var(--a)', false], ['filter', 'var(--f) url(#a)', false],
        ['font-family', 'var(--f), -apple-system', false], ['display', 'var(--d)', true],
        ['position', 'var(--p)', true], ['overflow', 'var(--o)', true], ['font-family', 'var(--f), sans-serif', true]
    ])JS"),
             std::string(""));
    CHECK_EQ(env.eval("CSS.supports('(position: sticky var(--y))')"), std::string("false"));
}

/// V5c fix-wave review, I1 and Minors 1-2: a substituted item is kept in a filter list and a font shorthand may end at
/// its size, as the validator keeps both; and the rules var() now reaches answer true where the validator keeps it.
WR_TEST(testVarIsKeptWhereTheValidatorKeepsIt) {
    HostEnv env;
    CHECK_EQ(mismatches(env, R"JS([
        ['filter', 'var(--f)', true], ['backdrop-filter', 'blur(2px) var(--f)', true],
        ['-webkit-backdrop-filter', 'var(--glass)', true], ['filter', 'attr(data-f)', true],
        ['filter', 'linear-gradient(red, blue) var(--f)', false], ['filter', 'var(--f) url(#a)', false],
        ['font', 'var(--s) 12px', true], ['font', '12px / var(--lh)', true], ['font', '12px', false],
        ['transform', 'var(--t)', true], ['rotate', 'var(--r)', true], ['translate', 'var(--x) 1px', true],
        ['translate', 'var(--a) var(--b) var(--c)', false], ['scale', 'var(--s)', true],
        ['font', '12px var(--f)', true], ['font', '12px var(--f), Arial', false], ['display', 'flex var(--x)', true],
        ['position', 'absolute var(--x)', true], ['position', 'inherit var(--p)', true],
        ['font-family', 'var(--f), Arial', false], ['font-family', 'var(--f)', true]
    ])JS"),
             std::string(""));
    CHECK_EQ(env.eval("CSS.supports('(filter: var(--f))')"), std::string("true"));
}

/// Review Focus 1: hostile values answer false, refused on their length or depth.
WR_TEST(testHostileValues) {
    HostEnv env;
    CHECK_EQ(env.eval("[CSS.supports('width', '('.repeat(1000000)), CSS.supports('width', 'a'.repeat(10000000)),"
                      " CSS.supports('width', 'calc('.repeat(100) + '1px'), CSS.supports('width', '1px)')].join()"),
             std::string("false,false,false,false"));
    env.eval("window.v = '1px '.repeat(2500); 1");
    CHECK_EQ(env.eval("CSS.supports('margin', v)"), std::string("true"));
}

/// Task 4: CSS.supports(conditionText), CSS Conditional 4's <supports-condition> over the profile's declarations, or
/// the text in parentheses (CSSOM), which is what makes a bare declaration true.
WR_TEST(testTheConditions) {
    HostEnv env;
    const std::string rows = R"JS([
        ['(display: flex) and (gap: 1px)', true], ['(display: flex)', true], ['display: flex', true],
        ['Display: Flex', true], ['not (display: contents)', true], ['NOT (display: flex)', false],
        ['(display: flex) or (display: contents)', true], ['(display: flex) and (display: contents)', false],
        ['(display: flex) and (gap: 1px) or (color: red)', false], ['((display: flex))', true],
        ['(not (display: contents)) and (color: red)', true], ['selector(:hover)', true],
        ['selector(:focus-visible)', false], ['selector(a::before)', true], ['selector(& a)', false],
        ['selector(li:not(:first-child))', true], ['selector(:not(:focus-within))', false],
        ['font-tech(color-COLRv1)', false], ['(foo)', false], ['', false], ['not(display: flex)', false],
        ['(display: flex) and', false], ['and (display: flex)', false], ['(--x: 1)', true],
        ['(transform: rotateY(1deg))', false], ['(display: flex)(color: red)', false]
    ])JS";
    CHECK_EQ(env.eval("const conditions = " + rows + ";"
                      "conditions.map(([c, want]) => CSS.supports(c) === want ? '' : JSON.stringify(c)).filter(Boolean).join(' ')"),
             std::string(""));
    // Review Focus 1: too deep or too long is false, never a native stack overflow.
    CHECK_EQ(env.eval("[CSS.supports('('.repeat(100000)), CSS.supports('not '.repeat(100000) + '(a:b)'), CSS.supports('('.repeat(70) + 'color: red' + ')'.repeat(70)),"
                      " CSS.supports('('.repeat(30) + 'color: red' + ')'.repeat(30))].join()"),
             std::string("false,false,false,true"));
}

/// V4 plan, Task 2: CSS.supports is the policy's verdict, true exactly for Keep and Augment (a family the validator
/// completes, a light-dark() it resolves, a :disabled it rewrites) and false for a rewrite or a drop (plan OP4:
/// strict attr()).
WR_TEST(testSupportsIsTheVerdict) {
    HostEnv env;
    CHECK_EQ(mismatches(env, R"JS([
        ['font-family', 'ui-monospace', true], ['color', 'light-dark(#fff,#000)', true], ['position', 'sticky', false],
        ['content', 'attr(class)', false], ['content', 'attr(data-x)', true]
    ])JS"),
             std::string(""));
    CHECK_EQ(env.eval("CSS.supports('selector(button:disabled)')"), std::string("true"));
}
