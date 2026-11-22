// UAX #9 (Sources/Render/Bidi.cpp) against Unicode's conformance data: each case's levels through rule L1 for its
// resolved paragraph level, an 'x' for a character X9 removes. The sample (Tests/bidi-character-test-sample.txt) runs by
// default; the whole BidiCharacterTest.txt (91,670 cases) with --test_env=WR_BIDI_CHARACTER_TEST=<path>, as it did
// with the implementation's first commit.
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "Sources/Host/ICU.h"
#include "Sources/Render/Bidi.h"
#include "Tests/wr_test.h"

namespace {

std::vector<std::string> fields(const std::string& line, char separator) {
    std::vector<std::string> out;
    std::stringstream s(line);
    std::string field;
    while (std::getline(s, field, separator)) {
        out.push_back(field);
    }
    return out;
}

/// The failures of the case `line` ("code points;direction;paragraph level;levels;order"), as one line, or "".
std::string check(const std::string& line) {
    const std::vector<std::string> f = fields(line, ';');
    if (f.size() < 4) {
        return "malformed: " + line;
    }
    std::u16string text;
    std::vector<uint32_t> chars;
    std::stringstream codes(f[0]);
    std::string hex;
    while (codes >> hex) {
        const uint32_t c = uint32_t(std::stoul(hex, nullptr, 16));
        chars.push_back(c);
        if (c > 0xFFFF) {
            text.push_back(char16_t(U16_LEAD(c)));
            text.push_back(char16_t(U16_TRAIL(c)));
        } else {
            text.push_back(char16_t(c));
        }
    }
    const std::vector<uint8_t> levels = wr::bidi::levels(text, uint8_t(std::stoi(f[2])));
    std::stringstream expected(f[3]);
    std::string want, got;
    size_t unit = 0;
    bool same = true;
    for (uint32_t c : chars) {
        std::string token;
        expected >> token;
        const std::string answer = wr::bidi::isRemovedByX9(c) ? std::string("x") : std::to_string(levels[unit]);
        same = same && (token == "x" ? answer == "x" : answer == token);
        got += answer + " ";
        unit += c > 0xFFFF ? 2 : 1;
    }
    return same ? std::string() : line + "\n    got " + got;
}

} // namespace

WR_TEST(testBidiCharacterTestCases) {
    const char* path = std::getenv("WR_BIDI_CHARACTER_TEST");
    std::ifstream in(path ? path : "");
    CHECK(in.good());
    size_t cases = 0, failed = 0;
    for (std::string line; std::getline(in, line);) {
        if (line.empty() || line[0] == '#') {
            continue;
        }
        cases++;
        const std::string failure = check(line);
        if (!failure.empty()) {
            if (failed++ < 20) {
                std::printf("  %s\n", failure.c_str());
            }
        }
    }
    std::printf("  %zu bidi cases, %zu failed\n", cases, failed);
    CHECK(cases >= 2000);
    CHECK_EQ(failed, size_t(0));
}

/// Units the algorithm cannot see as characters: a surrogate pair shares its character's level; an unpaired surrogate
/// is U+FFFD, a neutral.
WR_TEST(testSurrogatesShareTheirCharactersLevel) {
    // U+10800 CYPRIOT SYLLABLE A is R.
    const std::vector<uint8_t> pair = wr::bidi::levels(u"a\U00010800b", 0);
    CHECK_EQ(pair, (std::vector<uint8_t>{0, 1, 1, 0}));
    const std::u16string lone = {u'\x5D0', char16_t(0xD800), u'\x5D1'};
    CHECK_EQ(wr::bidi::levels(lone, 0), (std::vector<uint8_t>{1, 1, 1}));
}

/// A paragraph separator ends a paragraph: embeddings do not cross it, and the next paragraph starts at the same level.
WR_TEST(testAParagraphSeparatorEndsTheEmbeddings) {
    // RLE a PS b: the RLE ends at the separator, so b is at the paragraph's level.
    const std::vector<uint8_t> levels = wr::bidi::levels(u"‫a b", 0);
    CHECK_EQ(levels, (std::vector<uint8_t>{0, 2, 0, 0}));
}

/// Bracket pairs nest at most 63 deep (BD16) and each pair scans only what it encloses, so deep nesting over a long line
/// stays linear: a million units resolve, every one of them.
WR_TEST(testDeeplyNestedBracketsOverALongLine) {
    std::u16string text;
    while (text.size() < 1000000) {
        text += std::u16string(63, u'(') + u"אa1" + std::u16string(63, u')');
    }
    const std::vector<uint8_t> levels = wr::bidi::levels(text, 1);
    CHECK_EQ(levels.size(), text.size());
    CHECK_EQ(levels[63], uint8_t(1));
    CHECK_EQ(levels[64], uint8_t(2));
}
