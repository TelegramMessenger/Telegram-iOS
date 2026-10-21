// Theme params per SDK v1 §2.3 (V2a plan, Task 4): TelegramWidget.themeParams carries every key as lowercase #rrggbb (the
// host's palette over the framework's DEFAULT_THEME_PARAMS for the scheme), a fresh frozen object per change; the same
// values are --tg-theme-* custom properties on the root, with --tg-color-scheme, which no widget rule replaces; a theme
// change updates all of it in the task before themeChanged and onTheme run.
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
}
