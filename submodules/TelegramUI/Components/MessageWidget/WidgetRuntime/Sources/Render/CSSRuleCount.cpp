#include "Sources/Render/CSSRuleCount.h"

#include <vector>

namespace wr {

namespace {

enum class Block : unsigned char { Rule, At, Keyframes, Frame };

bool isSpace(char c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
}

char lower(char c) {
    return c >= 'A' && c <= 'Z' ? char(c - 'A' + 'a') : c;
}

bool startsWithLowered(std::string_view text, std::string_view prefix) {
    if (text.size() < prefix.size()) {
        return false;
    }
    for (size_t i = 0; i < prefix.size(); i++) {
        if (lower(text[i]) != prefix[i]) {
            return false;
        }
    }
    return true;
}

bool isWordChar(char c) {
    const char l = lower(c);
    return (l >= 'a' && l <= 'z') || (c >= '0' && c <= '9') || c == '_';
}

/// `/^@(-webkit-)?keyframes\b/` over a prelude already trimmed.
bool isKeyframesPrelude(std::string_view head) {
    for (std::string_view name : {std::string_view("@keyframes"), std::string_view("@-webkit-keyframes")}) {
        if (startsWithLowered(head, name) && (head.size() == name.size() || !isWordChar(head[name.size()]))) {
            return true;
        }
    }
    return false;
}

std::string_view trimmed(std::string_view text) {
    while (!text.empty() && isSpace(text.front())) {
        text.remove_prefix(1);
    }
    while (!text.empty() && isSpace(text.back())) {
        text.remove_suffix(1);
    }
    return text;
}

} // namespace

// validator.ts countCssRules, character for character: a string runs to its closing quote (a backslash taking the
// next character), a comment to its `*/`, and each `{` opens a block whose kind its prelude decides.
CSSRuleCount countCssRules(std::string_view css) {
    CSSRuleCount count;
    std::vector<Block> stack;
    size_t prelude = 0;
    for (size_t i = 0; i < css.size(); i++) {
        const char c = css[i];
        if (c == '"' || c == '\'') {
            for (i++; i < css.size() && css[i] != c; i++) {
                if (css[i] == '\\') {
                    i++;
                }
            }
        } else if (c == '/' && i + 1 < css.size() && css[i + 1] == '*') {
            const size_t end = css.find("*/", i + 2);
            i = end == std::string_view::npos ? css.size() : end + 1;
        } else if (c == '{') {
            const std::string_view head = trimmed(css.substr(prelude, i - prelude));
            Block kind;
            if (!stack.empty() && stack.back() == Block::Keyframes) {
                kind = Block::Frame;
            } else if (isKeyframesPrelude(head)) {
                kind = Block::Keyframes;
            } else if (!head.empty() && head.front() == '@') {
                kind = Block::At;
            } else {
                kind = Block::Rule;
            }
            if (kind == Block::Keyframes) {
                count.keyframes++;
            } else if (kind == Block::Rule) {
                count.rules++;
            }
            stack.push_back(kind);
            prelude = i + 1;
        } else if (c == '}') {
            if (!stack.empty()) {
                stack.pop_back();
            }
            prelude = i + 1;
        } else if (c == ';') {
            prelude = i + 1;
        }
    }
    return count;
}

} // namespace wr
