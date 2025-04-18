#include "Highlight.h"

#include "LanguageTree.h"

GrammarPtr::GrammarPtr(std::shared_ptr<LanguageTree> tree, size_t path)
    : m_tree(tree)
    , m_path(path)
{

}

const Grammar* GrammarPtr::operator->() const
{
    return get();
}

const Grammar* GrammarPtr::get() const
{
    return m_tree->resolveGrammar(m_path);
}

PatternPtr::PatternPtr(std::shared_ptr<LanguageTree> tree, size_t path)
    : m_tree(tree)
    , m_path(path)
{

}

const Pattern* PatternPtr::get() const
{
    return m_tree->resolvePattern(m_path);
}

const Grammar* Pattern::inside() const
{
    if (m_inside)
    {
        return m_inside->get();
    }

    return nullptr;
}
