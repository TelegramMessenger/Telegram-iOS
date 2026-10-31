// Theme params per SDK v1 §2.3 (V2a plan, Task 4): TelegramWidget.themeParams carries every key as lowercase #rrggbb (the
// host's palette over the framework's DEFAULT_THEME_PARAMS for the scheme), a fresh frozen object per change; the same
// values are --tg-theme-* custom properties on the root, with --tg-color-scheme, which no widget rule replaces; a theme
// change updates all of it in the task before themeChanged and onTheme run.
#include <cmath>
#include <cstdio>
#include <optional>
#include <string>

#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

const char* const kPage =
    "<!doctype html><html><head><style>"
    ":root { --tg-theme-bg-color: #123456 !important }"
    "body { background: var(--tg-theme-bg-color); color: var(--tg-theme-text-color) }"
    "</style></head><body><p id=p>x</p>"
    "<script>window.css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();</script>"
    "</body></html>";

} // namespace

WR_TEST(testThemeParamsCarryEveryKeyAsHex) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("const k = ['bg_color', 'text_color', 'hint_color', 'link_color', 'button_color', 'button_text_color',"
                            " 'secondary_bg_color', 'accent_text_color', 'subtitle_text_color', 'destructive_text_color',"
                            " 'section_bg_color', 'section_header_text_color', 'section_separator_color', 'header_bg_color',"
                            " 'bottom_bar_bg_color']; const p = TelegramWidget.themeParams;"
                            "[k.every(x => /^#[0-9a-f]{6}$/.test(p[x])), Object.isFrozen(p), p === TelegramWidget.themeParams,"
                            " p.bg_color, p.text_color, p.link_color].join()"),
             std::string("true,true,true,#ffffff,#000000,#3390ec"));
}

WR_TEST(testTheRootCarriesTheVariablesNoWidgetRuleReplaces) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("[css('--tg-theme-bg-color'), css('--tg-theme-text-color'), css('--tg-color-scheme'),"
                            " getComputedStyle(document.body).backgroundColor].join()"),
             std::string("#ffffff,#000000,light,rgb(255, 255, 255)"));
    // Not even the widget's own style on the root.
    CHECK_EQ(env.env().eval("document.documentElement.style.setProperty('--tg-theme-bg-color', '#654321', 'important');"
                            " css('--tg-theme-bg-color')"),
             std::string("#ffffff"));
}

WR_TEST(testAThemeChangeUpdatesEverythingBeforeThemeChanged) {
    RenderEnv env(kPage);
    env.env().eval("window.before = TelegramWidget.themeParams; window.log = [];"
                   "TelegramWidget.onEvent('themeChanged', () => log.push([TelegramWidget.colorScheme, TelegramWidget.themeParams.bg_color,"
                   "  css('--tg-theme-bg-color'), css('--tg-color-scheme'), TelegramWidget.themeParams !== before,"
                   "  Object.isFrozen(TelegramWidget.themeParams)].join(':'))); 1");
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("dark:#212121:#212121:dark:true:true"));
}

WR_TEST(testTheHostsPaletteWins) {
    RenderEnv env(kPage);
    wr::HostState::of(env.ctx()).setThemeParams(env.ctx(), {{"bg_color", "#ABCDEF"}, {"text_color", "#010203"}, {"nonsense", "#000000"},
                                                             {"link_color", "red"}});
    env.env().drain();
    CHECK_EQ(env.env().eval("(p => [p.bg_color, p.text_color, p.link_color, 'nonsense' in p].join())(TelegramWidget.themeParams)"),
             std::string("#abcdef,#010203,#3390ec,false"));
    CHECK_EQ(env.env().eval("css('--tg-theme-bg-color')"), std::string("#abcdef"));
}

/// The host's declarations are parsed on their own: a root style the widget leaves unclosed cannot swallow them.
WR_TEST(testAnUnclosedRootStyleCannotSwallowTheVariables) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("document.documentElement.setAttribute('style', '--tg-theme-bg-color: #654321 !important; --y: (');"
                            " css('--tg-theme-bg-color') + ',' + css('--tg-color-scheme')"),
             std::string("#ffffff,light"));
}

/// A change is the scheme or any completed colour: the same palette again, or one that completes to the same values,
/// changes nothing and fires nothing; a new colour in the same scheme fires once.
WR_TEST(testOnlyAChangeFiresThemeChanged) {
    RenderEnv env(kPage);
    env.env().eval("window.n = 0; TelegramWidget.onEvent('themeChanged', () => n++); window.first = TelegramWidget.themeParams; 1");
    wr::HostState::of(env.ctx()).setThemeParams(env.ctx(), {{"bg_color", "#FFFFFF"}});
    env.env().drain();
    CHECK_EQ(env.env().eval("n + ':' + (TelegramWidget.themeParams === first)"), std::string("0:true"));
    wr::HostState::of(env.ctx()).setThemeParams(env.ctx(), {{"hint_color", "#000001"}});
    env.env().drain();
    wr::HostState::of(env.ctx()).setThemeParams(env.ctx(), {{"hint_color", "#000001"}});
    env.env().drain();
    CHECK_EQ(env.env().eval("n + ':' + TelegramWidget.colorScheme + ':' + TelegramWidget.themeParams.hint_color + ':' +"
                            " Object.keys(TelegramWidget.themeParams).length"),
             std::string("1:light:#000001:15"));
    // A scheme change keeps the host's palette and completes the rest from the dark defaults.
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.env().drain();
    CHECK_EQ(env.env().eval("(p => [n, p.hint_color, p.bg_color].join())(TelegramWidget.themeParams)"), std::string("2,#000001,#212121"));
}

/// SDK v1 §2.4 (V2b plan, Task 2): each button token is checked against its grammar — colours #rrggbb, lengths in
/// px/em/rem, a font shorthand naming generic families only, opacities 0–1 — and a token that fails is dropped.
WR_TEST(testButtonTokensAreChecked) {
    wr::ThemeButtonTokens bad;
    bad.bg = "red";
    bad.text = "#12345";
    bad.radius = "8";
    bad.font = "500 14px Helvetica";
    bad.padding = "8px; color: red";
    bad.height = "10vh";
    bad.pressedOpacity = 1.5;
    bad.disabledOpacity = -0.1;
    CHECK(wr::checkButtonTokens(bad) == wr::ThemeButtonTokens{});
    wr::ThemeButtonTokens good;
    good.bg = "#3390EC";
    good.text = "#ffffff";
    good.radius = "8px";
    good.font = "500 14px/1.2 system-ui,sans-serif";
    good.padding = "8px 14px";
    good.height = "2.5em";
    good.pressedOpacity = 0.7;
    good.disabledOpacity = 0.5;
    const wr::ThemeButtonTokens checked = wr::checkButtonTokens(good);
    CHECK(checked.bg == std::optional<std::string>("#3390ec"));
    CHECK(checked.text == good.text && checked.radius == good.radius && checked.font == good.font && checked.padding == good.padding &&
          checked.height == good.height && checked.pressedOpacity == good.pressedOpacity && checked.disabledOpacity == good.disabledOpacity);
    const std::string declarations = wr::themeRootDeclarations(wr::completeThemeParams({}, wr::Theme::Light), wr::Theme::Light, checked);
    CHECK(declarations.find("--tg-button-bg:#3390ec !important") != std::string::npos);
    CHECK(declarations.find("--tg-button-font:500 14px/1.2 system-ui,sans-serif !important") != std::string::npos);
    CHECK(declarations.find("--tg-button-pressed-opacity:0.7 !important") != std::string::npos);
    // Lengths are the reference's LENGTH, shared with the text tokens: a bare 0, at most four digits and three decimals.
    wr::ThemeButtonTokens lengths;
    lengths.radius = "0";
    lengths.padding = "0 14px";
    lengths.height = "12345px";
    const wr::ThemeButtonTokens checkedLengths = wr::checkButtonTokens(lengths);
    CHECK(checkedLengths.radius == lengths.radius && checkedLengths.padding == lengths.padding && !checkedLengths.height);
}

/// SDK v1 §2.4, the text tokens (v0.1.1): a font size of 8–64 px kept to two decimals, a line height of 1–3 kept to
/// three, a padding of one to four lengths (`0`, or up to four digits and three decimals in px, em or rem); a token that
/// fails is dropped.
WR_TEST(testTextTokensAreChecked) {
    for (const double fontSize : {7.99, 64.01, std::nan(""), HUGE_VAL}) {
        wr::ThemeTextTokens bad;
        bad.fontSize = fontSize;
        CHECK(wr::checkTextTokens(bad) == wr::ThemeTextTokens{});
    }
    for (const double lineHeight : {0.99, 3.01, -1.0}) {
        wr::ThemeTextTokens bad;
        bad.lineHeight = lineHeight;
        CHECK(wr::checkTextTokens(bad) == wr::ThemeTextTokens{});
    }
    for (const char* padding : {"", "8px; color: red", "1px 2px 3px 4px 5px", "10vh", "8px  12px", "12345px", "1.2345px", "8"}) {
        wr::ThemeTextTokens bad;
        bad.padding = padding;
        CHECK(wr::checkTextTokens(bad) == wr::ThemeTextTokens{});
    }
    wr::ThemeTextTokens good;
    good.fontSize = 17.3333;
    good.lineHeight = 1.23456;
    good.padding = "0 1.5em 6px 11rem";
    const wr::ThemeTextTokens checked = wr::checkTextTokens(good);
    CHECK(checked.fontSize == std::optional<double>(17.33));
    CHECK(checked.lineHeight == std::optional<double>(1.235));
    CHECK(checked.padding == good.padding);
}

/// The root always carries the three text variables, with the reference set for a token not passed or refused.
WR_TEST(testTheRootAlwaysCarriesTheTextTokens) {
    const wr::ThemeParams params = wr::completeThemeParams({}, wr::Theme::Light);
    const std::string defaults = wr::themeRootDeclarations(params, wr::Theme::Light);
    CHECK(defaults.find(";--tg-text-font-size:15px !important;--tg-text-line-height:1.35 !important;--tg-text-padding:8px 12px !important") !=
          std::string::npos);
    wr::ThemeTextTokens text;
    text.fontSize = 17;
    text.lineHeight = 1.3;
    text.padding = "6px 11px";
    const std::string passed = wr::themeRootDeclarations(params, wr::Theme::Light, {}, wr::checkTextTokens(text));
    CHECK(passed.find(";--tg-text-font-size:17px !important;--tg-text-line-height:1.3 !important;--tg-text-padding:6px 11px !important") !=
          std::string::npos);
    text.fontSize = 100;
    const std::string refused = wr::themeRootDeclarations(params, wr::Theme::Light, {}, wr::checkTextTokens(text));
    CHECK(refused.find("--tg-text-font-size:15px !important;--tg-text-line-height:1.3 !important") != std::string::npos);
}

/// The tokens reach the layout: the root's font, the body's margin; no widget rule replaces them; a token change alone
/// is a theme change (one themeChanged), and the same tokens again change nothing.
WR_TEST(testTextTokensDriveTheRootAndTheBody) {
    RenderEnv env("<!doctype html><html><head><style>:root { --tg-text-font-size: 30px !important }</style></head><body><p id=p>x</p>"
                  "<script>window.css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();"
                  "window.cs = (e, p) => getComputedStyle(e).getPropertyValue(p);"
                  "window.n = 0; TelegramWidget.onEvent('themeChanged', () => n++);</script></body></html>");
    const std::string read = "[css('--tg-text-font-size'), css('--tg-text-line-height'), css('--tg-text-padding'),"
                             " cs(document.documentElement, 'font-size'), cs(document.documentElement, 'line-height'),"
                             " cs(document.body, 'margin-top'), cs(document.body, 'margin-left'), n].join()";
    CHECK_EQ(env.env().eval(read), std::string("15px,1.35,8px 12px,15px,20.25px,8px,12px,0"));
    wr::ThemeTextTokens text;
    text.fontSize = 17;
    text.lineHeight = 1.3;
    text.padding = "6px 11px";
    wr::HostState& state = wr::HostState::of(env.ctx());
    state.setTheme(env.ctx(), wr::Theme::Light, {}, {}, text);
    env.env().drain();
    CHECK_EQ(env.env().eval(read), std::string("17px,1.3,6px 11px,17px,22.1px,6px,11px,1"));
    state.setTheme(env.ctx(), wr::Theme::Light, {}, {}, text);
    env.env().drain();
    CHECK_EQ(env.env().eval("n"), std::string("1"));
    // A scheme change keeps them.
    state.themeChanged(env.ctx(), wr::Theme::Dark);
    env.env().drain();
    CHECK_EQ(env.env().eval(read), std::string("17px,1.3,6px 11px,17px,22.1px,6px,11px,2"));
}

/// Twidget edit 80: a theme switch whose colours reach the page through var(--tg-theme-*), light-dark() in a sheet and an
/// inline light-dark() patches, equal to a fresh build each way, and keeps litehtml's render tree (only paint changed).
WR_TEST(testAThemeSwitchKeepsTheTree) {
    RenderEnv env("<!doctype html><html><head><style>p{color:var(--tg-theme-text-color)} .s{color:light-dark(#000001,#000002)}"
                  "</style></head><body><p>themed</p><div class=s>sheet</div>"
                  "<div style=\"color:light-dark(#000003,#000004)\">inline</div></body></html>");
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    wr::HostState& state = wr::HostState::of(env.ctx());
    uint64_t switches = 0;
    for (const wr::Theme theme : {wr::Theme::Dark, wr::Theme::Light}) {
        state.themeChanged(env.ctx(), theme);
        env.env().drain();
        env.flush();
        switches++;
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().patchCount(), patches + switches);
        CHECK(env.render().document() && env.render().document()->rebuild_reason().empty());
        auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
        CHECK_EQ(env.render().layoutDump(), layout);
        CHECK(env.render().layerTree() && env.render().layerTree()->dump() == rebuilt);
    }
}

/// Twidget edit 80 (final review I2): light-dark() in what is kept as tokens and resolved later (a box-shadow at
/// compute, an SVG paint at draw, from a rule or a presentation attribute) follows a theme switch, as a fresh build.
WR_TEST(testAThemeSwitchRepaintsTokenColours) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0} .s{width:20px;height:20px;"
                  "box-shadow:0 2px 3px light-dark(#000001,#000002)} rect{fill:light-dark(#000003,#000004)}</style></head>"
                  "<body><div class=s></div><svg width=40 height=20><circle cx=10 cy=10 r=5"
                  " fill='light-dark(#000005,#000006)'></circle><rect x=20 y=5 width=10 height=10></rect></svg></body></html>");
    const uint64_t builds = env.render().buildCount();
    wr::HostState& state = wr::HostState::of(env.ctx());
    for (const wr::Theme theme : {wr::Theme::Dark, wr::Theme::Light}) {
        state.themeChanged(env.ctx(), theme);
        env.env().drain();
        env.flush();
        CHECK_EQ(env.render().buildCount(), builds);
        auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
        if (!env.render().layerTree() || env.render().layerTree()->dump() != rebuilt) {
            std::printf("  patched:\n%s---\n  rebuilt:\n%s", env.render().layerTree() ? env.render().layerTree()->dump().c_str() : "",
                        rebuilt.c_str());
        }
        CHECK(env.render().layerTree() && env.render().layerTree()->dump() == rebuilt);
    }
}
