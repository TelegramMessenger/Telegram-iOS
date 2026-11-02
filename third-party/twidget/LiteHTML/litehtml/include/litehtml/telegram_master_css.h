#ifndef LH_TELEGRAM_MASTER_CSS_H
#define LH_TELEGRAM_MASTER_CSS_H

#include <string>

namespace litehtml
{
    // Telegram (VENDOR.md edit 12): litehtml's master_css with `a:link` replaced by `a:link { cursor: pointer; }`,
    // plus twidget's additions (hidden elements, details/summary, form controls, fieldset, progress/meter). The
    // iOS renderer (LHDocument.mm) and host tests lay out against this one sheet.
    const std::string& telegram_master_css();
} // namespace litehtml

#endif // LH_TELEGRAM_MASTER_CSS_H
