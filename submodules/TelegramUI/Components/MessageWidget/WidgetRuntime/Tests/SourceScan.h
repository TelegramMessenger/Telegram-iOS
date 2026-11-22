// The source scans' reading of C, C++ and Objective-C (Tests/NoIOScanTests.cpp, Tests/NoWorkUnitsScanTests.cpp): the
// text with its comments and literals blanked, so a name in a comment or a string is never a hit.
#pragma once

#include <cctype>
#include <string>

namespace wr_test {

inline bool identChar(char c);

/// Whether the `R` at `i` starts a raw string literal: not the tail of an identifier, other than a u8, u, U or L prefix.
inline bool rawStringStart(const std::string& text, size_t i) {
    size_t before = i;
    if (before >= 2 && text[before - 2] == 'u' && text[before - 1] == '8') {
        before -= 2;
    } else if (before >= 1 && (text[before - 1] == 'u' || text[before - 1] == 'U' || text[before - 1] == 'L')) {
        before -= 1;
    }
    return before == 0 || !identChar(text[before - 1]);
}

/// Whether the `'` at `i` follows a number token (it starts with a digit), so it is a digit separator.
inline bool inNumberToken(const std::string& text, size_t i) {
    size_t start = i;
    while (start > 0 && identChar(text[start - 1])) {
        start--;
    }
    return start < i && std::isdigit((unsigned char)text[start]) && i + 1 < text.size() && std::isxdigit((unsigned char)text[i + 1]);
}

/// `text` with comments, string literals and character literals replaced by spaces (newlines kept, so line numbers hold).
inline std::string stripped(const std::string& text) {
    std::string out = text;
    const size_t n = text.size();
    size_t i = 0;
    auto blank = [&](size_t from, size_t to) {
        for (size_t k = from; k < to && k < n; k++) {
            if (out[k] != '\n') {
                out[k] = ' ';
            }
        }
    };
    while (i < n) {
        const char c = text[i];
        if (c == '/' && i + 1 < n && text[i + 1] == '/') {
            size_t end = i;
            while (end < n && text[end] != '\n') {
                // A backslash before the newline continues the comment.
                if (text[end] == '\\' && end + 1 < n && text[end + 1] == '\n') {
                    end++;
                }
                end++;
            }
            blank(i, end);
            i = end;
        } else if (c == '/' && i + 1 < n && text[i + 1] == '*') {
            size_t end = text.find("*/", i + 2);
            end = end == std::string::npos ? n : end + 2;
            blank(i, end);
            i = end;
        } else if (c == 'R' && i + 1 < n && text[i + 1] == '"' && rawStringStart(text, i)) {
            // A raw string: R"delim( ... )delim".
            size_t open = text.find('(', i + 2);
            if (open == std::string::npos) {
                break;
            }
            const std::string close = ")" + text.substr(i + 2, open - (i + 2)) + "\"";
            size_t end = text.find(close, open);
            end = end == std::string::npos ? n : end + close.size();
            blank(i, end);
            i = end;
        } else if (c == '"' || c == '\'') {
            // A digit separator (1'000, 0x1'F) is inside a number token: u8'a' and L'a' are character literals.
            if (c == '\'' && inNumberToken(text, i)) {
                i++;
                continue;
            }
            size_t end = i + 1;
            while (end < n && text[end] != c && text[end] != '\n') {
                end += text[end] == '\\' ? 2 : 1;
            }
            end = end < n && text[end] == c ? end + 1 : end;
            blank(i, end);
            i = end;
        } else {
            i++;
        }
    }
    return out;
}

inline bool identChar(char c) {
    return std::isalnum((unsigned char)c) || c == '_';
}

} // namespace wr_test
