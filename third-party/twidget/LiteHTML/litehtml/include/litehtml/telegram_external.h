#ifndef LH_TELEGRAM_EXTERNAL_H
#define LH_TELEGRAM_EXTERNAL_H

// Telegram (VENDOR.md edit 12): building a document from an external DOM. The entry points are public members of
// litehtml::document (insert_child, remove_child, append_text, external_element_allowed), implemented in
// telegram_external.cpp; this header holds what the implementation shares.

namespace litehtml
{
    class element;

    // True for the parents whose text create_node keeps as one piece: the raw-text elements <style> and <script>.
    bool is_raw_text_parent(const element& parent);
} // namespace litehtml

#endif // LH_TELEGRAM_EXTERNAL_H
