// Telegram (VENDOR.md edit 12): twidget's user-agent sheet, moved here from LHDocument.mm's MasterCSS().
#include "telegram_master_css.h"
#include "master_css.h"

namespace litehtml
{
    const std::string& telegram_master_css()
    {
        static const std::string& css = *new std::string([] {
            std::string s     = litehtml::master_css;
            size_t      start = s.find("a:link");
            size_t      end   = start == std::string::npos ? start : s.find('}', start);
            if(end != std::string::npos)
                s.replace(start, end - start + 1, "a:link { cursor: pointer; }");
        s += R"CSS(
[hidden], template, datalist { display: none; }
details, summary { display: block; }
summary::before { content: "▶︎"; display: inline-block; width: 1.25em; font-size: 0.9em; }
details[open] > summary::before { content: "▼︎"; }
details:not([open]) > :not(summary) { display: none; }
input, select, textarea, button { appearance: auto; font-family: system-ui; font-size: 11px; font-weight: 400; font-style: normal; color: rgba(2, 3, 1, 0.004); letter-spacing: normal; word-spacing: normal; line-height: normal; text-transform: none; text-indent: 0; text-shadow: none; text-align: left; }
input { box-sizing: content-box; padding: 1.01px 2.01px; border: 2px inset rgba(1, 2, 3, 0.004); background-color: rgba(3, 2, 1, 0.004); vertical-align: baseline; }
input[type="number"] { padding: 1.01px 2.02px 1.01px 2.01px; }
input[type="checkbox"], input[type="radio"] { box-sizing: border-box; width: 12px; height: 12px; margin: 3px 2px; padding: 0; border: 0; }
input[type="range"] { width: 129px; height: 16px; margin: 2px; padding: 0; border: 0; }
input[type="color"] { box-sizing: border-box; width: 44px; height: 23px; padding: 1px; border-width: 2px; }
input[type="button"], input[type="submit"], input[type="reset"], button { box-sizing: border-box; padding: 0.01px 6.01px 1.01px; border: 2px outset rgba(1, 2, 3, 0.004); background-color: rgba(3, 2, 1, 0.004); text-align: center; }
select { box-sizing: border-box; padding: 0; border: 1px solid rgba(1, 2, 3, 0.004); border-radius: 5px; background-color: rgba(3, 2, 1, 0.004); vertical-align: baseline; }
textarea { display: inline-block; box-sizing: content-box; width: 12.73em; height: auto; padding: 2px 5px; border: 1px solid rgba(1, 2, 3, 0.004); background-color: rgba(3, 2, 1, 0.004); white-space: pre-wrap; overflow-wrap: break-word; overflow: hidden; }
fieldset { display: block; margin: 0 2px; padding: 0.35em 0.75em 0.625em; border: 2px groove rgb(192, 192, 192); }
legend { display: table; padding: 0 2px; }
progress, meter { appearance: auto; display: inline-block; box-sizing: border-box; width: 140px; height: 14px; vertical-align: -0.2em; overflow: hidden; color: transparent; font-size: 0; }
meter { width: 70px; }
)CSS";
            return s;
        }());
        return css;
    }
} // namespace litehtml
