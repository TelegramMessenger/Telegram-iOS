#include "Sources/Render/Bidi.h"

#include <algorithm>
#include <cstddef>
#include <utility>

#include "Sources/Host/ICU.h"

namespace wr::bidi {

namespace {

// UCharDirection's values, which are UAX #9's classes.
enum Type : uint8_t {
    L = U_LEFT_TO_RIGHT,
    R = U_RIGHT_TO_LEFT,
    EN = U_EUROPEAN_NUMBER,
    ES = U_EUROPEAN_NUMBER_SEPARATOR,
    ET = U_EUROPEAN_NUMBER_TERMINATOR,
    AN = U_ARABIC_NUMBER,
    CS = U_COMMON_NUMBER_SEPARATOR,
    B = U_BLOCK_SEPARATOR,
    S = U_SEGMENT_SEPARATOR,
    WS = U_WHITE_SPACE_NEUTRAL,
    ON = U_OTHER_NEUTRAL,
    LRE = U_LEFT_TO_RIGHT_EMBEDDING,
    LRO = U_LEFT_TO_RIGHT_OVERRIDE,
    AL = U_RIGHT_TO_LEFT_ARABIC,
    RLE = U_RIGHT_TO_LEFT_EMBEDDING,
    RLO = U_RIGHT_TO_LEFT_OVERRIDE,
    PDF = U_POP_DIRECTIONAL_FORMAT,
    NSM = U_DIR_NON_SPACING_MARK,
    BN = U_BOUNDARY_NEUTRAL,
    FSI = U_FIRST_STRONG_ISOLATE,
    LRI = U_LEFT_TO_RIGHT_ISOLATE,
    RLI = U_RIGHT_TO_LEFT_ISOLATE,
    PDI = U_POP_DIRECTIONAL_ISOLATE,
};

/// BD2's max_depth.
constexpr uint8_t kMaxDepth = 125;
/// BD16's stack of opening brackets.
constexpr size_t kMaxBracketDepth = 63;

bool isRemoved(Type t) {
    return t == LRE || t == RLE || t == LRO || t == RLO || t == PDF || t == BN;
}
bool isIsolateInitiator(Type t) {
    return t == LRI || t == RLI || t == FSI;
}
bool isNeutralOrIsolate(Type t) {
    return t == B || t == S || t == WS || t == ON || isIsolateInitiator(t) || t == PDI;
}
/// N0 and N1's strong direction of a resolved type: EN and AN count as R. ON for none.
Type strongDirection(Type t) {
    return t == L ? L : (t == R || t == EN || t == AN) ? R : ON;
}
Type directionOfLevel(uint8_t level) {
    return level % 2 ? R : L;
}
/// BD16 compares brackets under canonical equivalence: U+2329 and U+232A are U+3008 and U+3009.
UChar32 canonicalBracket(UChar32 c) {
    return c == 0x2329 ? 0x3008 : c == 0x232A ? 0x3009 : c;
}

class Paragraph {
public:
    Paragraph(const std::vector<UChar32>& chars, const std::vector<Type>& initial, size_t begin, size_t end, uint8_t level,
              std::vector<uint8_t>& levels)
        : m_chars(chars), m_initial(initial), m_begin(begin), m_end(end), m_level(level), m_levels(levels),
          m_types(initial.begin() + std::ptrdiff_t(begin), initial.begin() + std::ptrdiff_t(end)), m_matchingPDI(end - begin, -1),
          m_matchingInitiator(end - begin, -1) {}

    void resolve() {
        this->matchIsolates();
        this->explicitLevels();
        m_explicit.assign(m_levels.begin() + std::ptrdiff_t(m_begin), m_levels.begin() + std::ptrdiff_t(m_end));
        for (std::vector<size_t>& sequence : this->isolatingRunSequences()) {
            this->resolveSequence(sequence);
        }
        this->levelRemoved();
        this->resetWhitespace();
    }

private:
    Type initial(size_t i) const { return m_initial[m_begin + i]; }
    uint8_t& level(size_t i) { return m_levels[m_begin + i]; }
    size_t size() const { return m_end - m_begin; }

    /// BD9: each isolate initiator's matching PDI, and each PDI's initiator.
    void matchIsolates() {
        std::vector<size_t> open;
        for (size_t i = 0; i < this->size(); i++) {
            const Type t = this->initial(i);
            if (isIsolateInitiator(t)) {
                open.push_back(i);
            } else if (t == PDI && !open.empty()) {
                m_matchingPDI[open.back()] = int32_t(i);
                m_matchingInitiator[i] = int32_t(open.back());
                open.pop_back();
            }
        }
    }

    /// P2 and P3 over [from, to), skipping isolates: 1 when the first strong character is R or AL, else 0.
    uint8_t firstStrongLevel(size_t from, size_t to) const {
        for (size_t i = from; i < to; i++) {
            const Type t = this->initial(i);
            if (t == L) {
                return 0;
            }
            if (t == R || t == AL) {
                return 1;
            }
            if (isIsolateInitiator(t)) {
                if (m_matchingPDI[i] < 0) {
                    return 0;
                }
                i = size_t(m_matchingPDI[i]);
            }
        }
        return 0;
    }

    /// X1–X8.
    void explicitLevels() {
        struct Entry {
            uint8_t level;
            Type override;  // ON for neutral
            bool isolate;
        };
        std::vector<Entry> stack;
        stack.reserve(kMaxDepth + 2);
        stack.push_back({m_level, ON, false});
        size_t overflowIsolates = 0, overflowEmbeddings = 0, validIsolates = 0;
        auto applyOverride = [&](size_t i) {
            if (stack.back().override != ON) {
                m_types[i] = stack.back().override;
            }
        };
        for (size_t i = 0; i < this->size(); i++) {
            const Type t = this->initial(i);
            switch (t) {
            case RLE:
            case LRE:
            case RLO:
            case LRO: {
                const uint8_t current = stack.back().level;
                const uint8_t next = (t == RLE || t == RLO) ? uint8_t((current + 1) | 1) : uint8_t((current + 2) & ~1);
                if (next <= kMaxDepth && overflowIsolates == 0 && overflowEmbeddings == 0) {
                    stack.push_back({next, t == RLO ? R : t == LRO ? L : ON, false});
                } else if (overflowIsolates == 0) {
                    overflowEmbeddings++;
                }
                this->level(i) = stack.back().level;
                break;
            }
            case RLI:
            case LRI:
            case FSI: {
                this->level(i) = stack.back().level;
                applyOverride(i);
                const size_t close = m_matchingPDI[i] >= 0 ? size_t(m_matchingPDI[i]) : this->size();
                const bool rtl = t == RLI || (t == FSI && this->firstStrongLevel(i + 1, close) == 1);
                const uint8_t current = stack.back().level;
                const uint8_t next = rtl ? uint8_t((current + 1) | 1) : uint8_t((current + 2) & ~1);
                if (next <= kMaxDepth && overflowIsolates == 0 && overflowEmbeddings == 0) {
                    validIsolates++;
                    stack.push_back({next, ON, true});
                } else {
                    overflowIsolates++;
                }
                break;
            }
            case PDI:
                if (overflowIsolates > 0) {
                    overflowIsolates--;
                } else if (validIsolates > 0) {
                    overflowEmbeddings = 0;
                    while (!stack.back().isolate) {
                        stack.pop_back();
                    }
                    stack.pop_back();
                    validIsolates--;
                }
                this->level(i) = stack.back().level;
                applyOverride(i);
                break;
            case PDF:
                if (overflowIsolates > 0) {
                } else if (overflowEmbeddings > 0) {
                    overflowEmbeddings--;
                } else if (!stack.back().isolate && stack.size() >= 2) {
                    stack.pop_back();
                }
                this->level(i) = stack.back().level;
                break;
            case B:
                this->level(i) = m_level;
                break;
            case BN:
                this->level(i) = stack.back().level;
                break;
            default:
                this->level(i) = stack.back().level;
                applyOverride(i);
                break;
            }
        }
    }

    /// X9 and X10 (BD13): the level runs of what X9 keeps, chained through matching isolate initiators and PDIs.
    std::vector<std::vector<size_t>> isolatingRunSequences() {
        std::vector<std::pair<size_t, size_t>> runs;  // [first, last] indices into m_kept
        std::vector<size_t> runOf(this->size(), SIZE_MAX);
        for (size_t i = 0; i < this->size(); i++) {
            if (!isRemoved(this->initial(i))) {
                if (m_kept.empty() || this->level(m_kept.back()) != this->level(i)) {
                    runs.push_back({m_kept.size(), m_kept.size()});
                } else {
                    runs.back().second = m_kept.size();
                }
                runOf[i] = runs.size() - 1;
                m_kept.push_back(i);
            }
        }
        m_keptIndex.assign(this->size(), SIZE_MAX);
        for (size_t k = 0; k < m_kept.size(); k++) {
            m_keptIndex[m_kept[k]] = k;
        }
        std::vector<std::vector<size_t>> sequences;
        for (const auto& [first, last] : runs) {
            const size_t start = m_kept[first];
            if (this->initial(start) == PDI && m_matchingInitiator[start] >= 0) {
                continue;
            }
            std::vector<size_t> sequence;
            size_t run = runOf[start];
            for (;;) {
                for (size_t k = runs[run].first; k <= runs[run].second; k++) {
                    sequence.push_back(m_kept[k]);
                }
                const size_t end = sequence.back();
                if (!isIsolateInitiator(this->initial(end)) || m_matchingPDI[end] < 0) {
                    break;
                }
                run = runOf[size_t(m_matchingPDI[end])];
            }
            sequences.push_back(std::move(sequence));
        }
        return sequences;
    }

    /// W1–W7, N0–N2, I1–I2 over one isolating run sequence (indices into the paragraph).
    void resolveSequence(const std::vector<size_t>& sequence) {
        // sos and eos from the explicit levels (X1–X8): the sequences before this one have already applied I1 and I2.
        const size_t n = sequence.size();
        const uint8_t level = m_explicit[sequence.front()];
        const size_t firstKept = m_keptIndex[sequence.front()];
        const uint8_t before = firstKept > 0 ? m_explicit[m_kept[firstKept - 1]] : m_level;
        const Type sos = directionOfLevel(std::max(level, before));
        const size_t lastKept = m_keptIndex[sequence.back()];
        const uint8_t after = isIsolateInitiator(this->initial(sequence.back())) || lastKept + 1 >= m_kept.size()
                                  ? m_level
                                  : m_explicit[m_kept[lastKept + 1]];
        const Type eos = directionOfLevel(std::max(level, after));
        std::vector<Type> t(n);
        for (size_t k = 0; k < n; k++) {
            t[k] = m_types[sequence[k]];
        }
        // W1
        for (size_t k = 0; k < n; k++) {
            if (t[k] == NSM) {
                t[k] = k == 0 ? sos : (isIsolateInitiator(t[k - 1]) || t[k - 1] == PDI) ? ON : t[k - 1];
            }
        }
        // W2, W3
        Type lastStrong = sos;
        for (size_t k = 0; k < n; k++) {
            if (t[k] == L || t[k] == R || t[k] == AL) {
                lastStrong = t[k];
            } else if (t[k] == EN && lastStrong == AL) {
                t[k] = AN;
            }
        }
        for (Type& type : t) {
            if (type == AL) {
                type = R;
            }
        }
        // W4
        for (size_t k = 1; k + 1 < n; k++) {
            if (t[k] == ES && t[k - 1] == EN && t[k + 1] == EN) {
                t[k] = EN;
            } else if (t[k] == CS && t[k - 1] == t[k + 1] && (t[k - 1] == EN || t[k - 1] == AN)) {
                t[k] = t[k - 1];
            }
        }
        // W5
        for (size_t k = 0; k < n;) {
            if (t[k] != ET) {
                k++;
                continue;
            }
            size_t end = k;
            while (end < n && t[end] == ET) {
                end++;
            }
            if ((k > 0 && t[k - 1] == EN) || (end < n && t[end] == EN)) {
                std::fill(t.begin() + std::ptrdiff_t(k), t.begin() + std::ptrdiff_t(end), EN);
            }
            k = end;
        }
        // W6
        for (Type& type : t) {
            if (type == ES || type == ET || type == CS) {
                type = ON;
            }
        }
        // W7
        lastStrong = sos;
        for (Type& type : t) {
            if (type == L || type == R) {
                lastStrong = type;
            } else if (type == EN && lastStrong == L) {
                type = L;
            }
        }
        this->resolveBrackets(sequence, t, sos, directionOfLevel(level));
        // N1, N2
        for (size_t k = 0; k < n;) {
            if (!isNeutralOrIsolate(t[k])) {
                k++;
                continue;
            }
            size_t end = k;
            while (end < n && isNeutralOrIsolate(t[end])) {
                end++;
            }
            const Type leading = k == 0 ? sos : strongDirection(t[k - 1]);
            const Type trailing = end == n ? eos : strongDirection(t[end]);
            std::fill(t.begin() + std::ptrdiff_t(k), t.begin() + std::ptrdiff_t(end),
                      leading == trailing ? leading : directionOfLevel(level));
            k = end;
        }
        // I1, I2
        for (size_t k = 0; k < n; k++) {
            uint8_t resolved = level;
            if (level % 2 == 0) {
                resolved += t[k] == R ? 1 : (t[k] == AN || t[k] == EN) ? 2 : 0;
            } else if (t[k] == L || t[k] == EN || t[k] == AN) {
                resolved += 1;
            }
            this->level(sequence[k]) = resolved;
        }
    }

    /// BD16 and N0.
    void resolveBrackets(const std::vector<size_t>& sequence, std::vector<Type>& t, Type sos, Type embedding) {
        struct Opener {
            UChar32 closing;
            size_t position;
        };
        std::vector<Opener> openers;
        std::vector<std::pair<size_t, size_t>> pairs;
        for (size_t k = 0; k < t.size(); k++) {
            if (t[k] != ON) {
                continue;
            }
            const UChar32 c = m_chars[m_begin + sequence[k]];
            const int32_t bracket = u_getIntPropertyValue(c, UCHAR_BIDI_PAIRED_BRACKET_TYPE);
            if (bracket == U_BPT_OPEN) {
                if (openers.size() == kMaxBracketDepth) {
                    break;
                }
                openers.push_back({canonicalBracket(u_getBidiPairedBracket(c)), k});
            } else if (bracket == U_BPT_CLOSE) {
                const UChar32 closing = canonicalBracket(c);
                for (size_t j = openers.size(); j-- > 0;) {
                    if (openers[j].closing == closing) {
                        pairs.push_back({openers[j].position, k});
                        openers.resize(j);
                        break;
                    }
                }
            }
        }
        std::sort(pairs.begin(), pairs.end());
        for (const auto& [open, close] : pairs) {
            bool embeddingInside = false, oppositeInside = false;
            for (size_t k = open + 1; k < close && !embeddingInside; k++) {
                const Type strong = strongDirection(t[k]);
                embeddingInside = strong == embedding;
                oppositeInside = oppositeInside || (strong != ON && strong != embedding);
            }
            Type resolved = ON;
            if (embeddingInside) {
                resolved = embedding;
            } else if (oppositeInside) {
                // The opposite direction when the context before the pair establishes it, else the embedding one: the
                // first strong type before the opening bracket either way.
                resolved = sos;
                for (size_t k = open; k-- > 0;) {
                    const Type strong = strongDirection(t[k]);
                    if (strong != ON) {
                        resolved = strong;
                        break;
                    }
                }
            }
            if (resolved == ON) {
                continue;
            }
            for (size_t bracket : {open, close}) {
                t[bracket] = resolved;
                // Characters originally NSM after a bracket N0 resolved take its direction.
                for (size_t k = bracket + 1; k < t.size() && this->initial(sequence[k]) == NSM; k++) {
                    t[k] = resolved;
                }
            }
        }
    }

    /// What X9 removed: the level of the character before, or the paragraph's.
    void levelRemoved() {
        for (size_t i = 0; i < this->size(); i++) {
            if (isRemoved(this->initial(i))) {
                this->level(i) = i > 0 ? this->level(i - 1) : m_level;
            }
        }
    }

    /// L1: segment and paragraph separators, and the whitespace and isolate controls (with what X9 removed among them)
    /// before one or at the end of the line, at the paragraph level.
    void resetWhitespace() {
        bool trailing = true;
        for (size_t i = this->size(); i-- > 0;) {
            const Type t = this->initial(i);
            if (t == S || t == B) {
                this->level(i) = m_level;
                trailing = true;
            } else if (t == WS || isIsolateInitiator(t) || t == PDI || isRemoved(t)) {
                if (trailing) {
                    this->level(i) = m_level;
                }
            } else {
                trailing = false;
            }
        }
    }

    const std::vector<UChar32>& m_chars;
    const std::vector<Type>& m_initial;
    const size_t m_begin;
    const size_t m_end;
    const uint8_t m_level;
    std::vector<uint8_t>& m_levels;
    /// Paragraph-relative from here on.
    std::vector<Type> m_types;
    std::vector<int32_t> m_matchingPDI;
    std::vector<int32_t> m_matchingInitiator;
    /// The levels X1–X8 gave.
    std::vector<uint8_t> m_explicit;
    /// The characters X9 keeps, in order, and each one's index among them.
    std::vector<size_t> m_kept;
    std::vector<size_t> m_keptIndex;
};

} // namespace

std::vector<uint8_t> levels(std::u16string_view text, uint8_t paragraphLevel) {
    std::vector<UChar32> chars;
    std::vector<size_t> unitOf;  // each character's first unit
    chars.reserve(text.size());
    unitOf.reserve(text.size());
    for (size_t i = 0; i < text.size();) {
        UChar32 c = text[i];
        unitOf.push_back(i);
        if (U16_IS_LEAD(c) && i + 1 < text.size() && U16_IS_TRAIL(text[i + 1])) {
            c = U16_GET_SUPPLEMENTARY(c, text[i + 1]);
            i += 2;
        } else {
            if (U16_IS_SURROGATE(c)) {
                c = 0xFFFD;
            }
            i++;
        }
        chars.push_back(c);
    }
    std::vector<Type> initial(chars.size());
    for (size_t i = 0; i < chars.size(); i++) {
        initial[i] = Type(u_charDirection(chars[i]));
    }
    std::vector<uint8_t> resolved(chars.size(), paragraphLevel);
    for (size_t begin = 0; begin < chars.size();) {
        size_t end = begin;
        while (end < chars.size() && initial[end] != B) {
            end++;
        }
        end = std::min(end + 1, chars.size());
        Paragraph(chars, initial, begin, end, paragraphLevel & 1, resolved).resolve();
        begin = end;
    }
    std::vector<uint8_t> out(text.size(), paragraphLevel);
    for (size_t i = 0; i < chars.size(); i++) {
        const size_t stop = i + 1 < chars.size() ? unitOf[i + 1] : text.size();
        std::fill(out.begin() + std::ptrdiff_t(unitOf[i]), out.begin() + std::ptrdiff_t(stop), resolved[i]);
    }
    return out;
}

bool isRemovedByX9(uint32_t c) {
    return isRemoved(Type(u_charDirection(UChar32(c))));
}

} // namespace wr::bidi
