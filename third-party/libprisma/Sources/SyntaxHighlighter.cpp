#include "SyntaxHighlighter.h"
#include "LanguageTree.h"
#include "TokenList.h"

SyntaxHighlighter::SyntaxHighlighter(const std::string& path)
{
    m_tree = std::make_shared<LanguageTree>();
    m_tree->load(path);
}

TokenList SyntaxHighlighter::tokenize(const std::string& text, const std::string& language)
{
    const Grammar* grammar = m_tree->find(language);
    if (grammar)
    {
        return tokenize(text, grammar);
    }

    return TokenList(text);
}

std::map<std::string, std::string> SyntaxHighlighter::languages() const
{
    return m_tree->keys();
}

TokenList SyntaxHighlighter::tokenize(std::string_view text, const Grammar* grammar)
{
    TokenList tokenList(text);
    matchGrammar(text, tokenList, grammar, tokenList.head, 0, nullptr);

    return tokenList;
}

void SyntaxHighlighter::matchGrammar(std::string_view text, TokenList& tokenList, const Grammar* grammar, TokenListPtr startNode, size_t startPos, RematchOptions* rematch)
{
    for (const auto& token : grammar->tokens)
    {
        int x = 0;
        for (auto j = token.cbegin(); j != token.cend(); ++j)
        {
            if (rematch && rematch->j == x && rematch->token == token.name())
            {
                return;
            }

            const auto& pattern = *j;
            const auto& inside = pattern->inside();
            const bool greedy = pattern->greedy();

            size_t pos = startPos;

            // iterate the token list and keep track of the current token/string position
            for (TokenListPtr currentNode = startNode->next;
                currentNode != tokenList.head;
                pos += currentNode->length(), currentNode = currentNode->next)
            {
                if (rematch && pos >= rematch->reach)
                {
                    break;
                }

                if (tokenList.length > text.length())
                {
                    // Something went terribly wrong, ABORT, ABORT!
                    return;
                }

                if (currentNode->isSyntax())
                {
                    continue;
                }

                const auto& currentText = dynamic_cast<Text&>(*currentNode);
                std::string_view str = currentText.value();

                auto removeCount = 1; // this is the to parameter of removeBetween
                std::string_view match;
                bool matchSuccess = false;
                size_t matchIndex = pos;

                if (greedy)
                {
                    match = pattern->match(matchSuccess, matchIndex, text);
                    if (!matchSuccess || matchIndex >= text.length())
                    {
                        break;
                    }

                    auto from = matchIndex;
                    auto to = matchIndex + match.length();
                    auto p = pos;

                    // find the node that contains the match
                    p += currentNode->length();
                    while (from >= p)
                    {
                        currentNode = currentNode->next;
                        p += currentNode->length();
                    }
                    // adjust pos (and p)
                    p -= currentNode->length();
                    pos = p;

                    // the current node is a Token, then the match starts inside another Token, which is invalid
                    if (currentNode->isSyntax())
                    {
                        continue;
                    }

                    // find the last node which is affected by this match
                    for (TokenListPtr k = currentNode;
                        k != tokenList.head && (p < to || !k->isSyntax());
                        k = k->next)
                    {
                        removeCount++;
                        p += k->length();
                    }
                    removeCount--;

                    // replace with the new match
                    str = text.substr(pos, p - pos);
                    matchIndex -= pos;
                }
                else
                {
                    matchIndex = 0;
                    match = pattern->match(matchSuccess, matchIndex, str);
                    if (!matchSuccess)
                    {
                        continue;
                    }
                }

                auto from = matchIndex;
                auto before = str.substr(0, from);
                auto after = str.substr(from + match.length());

                auto reach = pos + str.length();
                if (rematch && reach > rematch->reach)
                {
                    rematch->reach = reach;
                }

                TokenListPtr removeFrom = currentNode->prev;

                if (before.size())
                {
                    removeFrom = tokenList.addAfter(removeFrom, before);
                    pos += before.length();
                }

                tokenList.removeRange(removeFrom, removeCount);

                TokenList tokenEntries = [&]() {
                    if (inside)
                    {
                        return tokenize(match, inside);
                    }
                    else
                    {
                        return TokenList(match);
                    }
                }();

                currentNode = tokenList.addAfter(removeFrom, token.name(),
                    std::move(tokenEntries),
                    pattern->alias(),
                    match.size());

                if (after.size())
                {
                    tokenList.addAfter(currentNode, after);
                }

                if (removeCount > 1)
                {
                    // at least one Token object was removed, so we have to do some rematching
                    // this can only happen if the current pattern is greedy
                    RematchOptions nestedRematch = {
                        .token = token.name(),
                        .reach = reach,
                        .j = x
                    };

                    matchGrammar(text, tokenList, grammar, currentNode->prev, pos, &nestedRematch);

                    // the reach might have been extended because of the rematching
                    if (rematch && nestedRematch.reach > rematch->reach)
                    {
                        rematch->reach = nestedRematch.reach;
                    }
                }
            }

            ++x;
        }
    }
}
