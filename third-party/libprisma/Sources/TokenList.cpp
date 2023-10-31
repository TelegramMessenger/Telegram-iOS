#include "TokenList.h"

TokenList::TokenList(std::string_view value)
    : head(new TokenListNode())
    , length(1)
{
    const TokenListPtr newNode = new Text(head, head, value);
    head->next = newNode;
}

TokenList::~TokenList()
{
    TokenListPtr next = head->next;
    while (head != next)
    {
        TokenListPtr current = next;
        next = next->next;
        delete current;
    }

    delete head;
}

TokenListPtr TokenList::addAfter(TokenListPtr node, const std::string& type, TokenList&& children, const std::string& alias, size_t textLength)
{
    const TokenListPtr next = node->next;
    const TokenListPtr newNode = new Syntax(node, next, type, std::move(children), alias, textLength);

    node->next = newNode;
    next->prev = newNode;
    length++;

    return newNode;
}

TokenListPtr TokenList::addAfter(TokenListPtr node, std::string_view value)
{
    const TokenListPtr next = node->next;
    const TokenListPtr newNode = new Text(node, next, value);

    node->next = newNode;
    next->prev = newNode;
    length++;

    return newNode;
}

void TokenList::removeRange(TokenListPtr node, size_t count)
{
    TokenListPtr item = node->next;

    for (size_t i = 0; i < count && item != nullptr; i++)
    {
        node->next = item->next;
        node->next->prev = node;
        delete item;

        item = node->next;
        length--;
    }
}

Syntax::Syntax(TokenListPtr prev, TokenListPtr next, const std::string& type, TokenList&& children, const std::string& alias, size_t length)
    : TokenListNode(prev, next)
    , m_type(type)
    , m_children(std::move(children))
    , m_alias(alias)
    , m_length(length)
{

}
