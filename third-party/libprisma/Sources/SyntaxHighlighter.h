#pragma once
#include <sstream>

#include "TokenList.h"
#include <vector>
#include <map>
#include <optional>

class LanguageTree;
struct Grammar;

struct RematchOptions
{
    std::string token;
    size_t reach;
    int j;
};

class SyntaxHighlighter
{
public:
    SyntaxHighlighter(const std::string& languages);

    TokenList tokenize(const std::string& text, const std::string& language);

    std::map<std::string, std::string> languages() const;

private:
    // Upper bound on grammar recursion depth. tokenize() re-enters itself for
    // every matched token that has an `inside` grammar; some grammars generated
    // from Prism.js contain token cycles (e.g. brightscript's
    // directive-statement <-> expression), which without a bound recurse until
    // the thread stack is exhausted and the process is killed. At ~1.1 KiB of
    // stack per level this cap keeps the worst case well under a small
    // secondary-thread stack, while being far deeper than any legitimate
    // grammar's nesting, so real code is highlighted unchanged. Reaching the
    // cap degrades gracefully: the deepest match is kept as plain text instead
    // of being subdivided further.
    static constexpr size_t kMaxTokenizeDepth = 128;

    TokenList tokenize(std::string_view text, const Grammar* grammar, size_t depth);
    void matchGrammar(std::string_view text, TokenList& tokenList, const Grammar* grammar, TokenListPtr startNode, size_t startPos, RematchOptions* rematch, size_t depth);

    std::shared_ptr<LanguageTree> m_tree;
};