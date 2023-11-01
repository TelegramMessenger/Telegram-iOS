#pragma once

#include <memory>
#include <string>

struct TokenListNode
{
    TokenListNode(TokenListNode* prev, TokenListNode* next)
        : prev(prev)
        , next(next)
    {
    }

    TokenListNode()
        : prev(nullptr)
        , next(nullptr)
    {
    }

    virtual ~TokenListNode() = default;

    TokenListNode(const TokenListNode&) = delete;
    TokenListNode& operator=(const TokenListNode&) = delete;

    virtual size_t length() const
    {
        return 0;
    }

    virtual bool isSyntax() const
    {
        return true;
    }

    TokenListNode* prev;
    TokenListNode* next;
};

typedef TokenListNode* TokenListPtr;

class TokenList
{
public:
    TokenList(std::string_view text);
    ~TokenList();

    TokenList(const TokenList&) = delete;
    TokenList& operator=(const TokenList&) = delete;
    TokenList(TokenList&& old) noexcept
    {
        head = old.head;
        length = old.length;

        old.head = new TokenListNode();
        old.head->next = old.head;
        old.length = 0;
    }

    struct ConstIterator
    {
        using iterator_category = std::forward_iterator_tag;
        using difference_type = std::ptrdiff_t;
        using value_type = const TokenListNode;
        using pointer = const TokenListNode*;
        using reference = const TokenListNode&;

        ConstIterator(pointer ptr) : m_ptr(ptr) {}

        reference operator*() const { return *m_ptr; }
        pointer operator->() { return m_ptr; }
        ConstIterator& operator++() { m_ptr = m_ptr->next; return *this; }
        friend bool operator== (const ConstIterator& a, const ConstIterator& b) { return a.m_ptr == b.m_ptr; };
        friend bool operator!= (const ConstIterator& a, const ConstIterator& b) { return a.m_ptr != b.m_ptr; };

    private:
        pointer m_ptr;
    };

    ConstIterator begin() const { return ConstIterator(head->next); }
    ConstIterator end() const { return ConstIterator(head); }

    TokenListPtr addAfter(TokenListPtr node, const std::string& type, TokenList&& children, const std::string& alias, size_t length);
    TokenListPtr addAfter(TokenListPtr node, std::string_view value);
    void removeRange(TokenListPtr node, size_t count);

    TokenListPtr head;
    size_t length;
};

class Text : public TokenListNode
{
public:
    Text(TokenListPtr prev, TokenListPtr next, std::string_view value)
        : TokenListNode(prev, next)
        , m_value(value)
    {

    }

    Text(const Text&) = delete;
    Text& operator=(const Text&) = delete;

    const std::string_view& value() const
    {
        return m_value;
    }

    size_t length() const
    {
        return m_value.size();
    }

    bool isSyntax() const
    {
        return false;
    }

private:
    const std::string_view m_value;
};

class Syntax : public TokenListNode
{
public:
    Syntax(TokenListPtr prev, TokenListPtr next, const std::string& type, TokenList&& children, const std::string& alias, size_t length);

    Syntax(const Syntax&) = delete;
    Syntax& operator=(const Syntax&) = delete;

    size_t length() const
    {
        return m_length;
    }

    bool isSyntax() const
    {
        return true;
    }

    const std::string &type() const
    {
        return m_type;
    }

    TokenList::ConstIterator begin() const
    {
        return m_children.begin();
    }

    TokenList::ConstIterator end() const
    {
        return m_children.end();
    }

    const std::string &alias() const
    {
        return m_alias;
    }

    const TokenList &children() const
	{
		return m_children;
	}

public:
    std::string m_type;
    TokenList m_children;
    std::string m_alias;
    size_t m_length;
};
