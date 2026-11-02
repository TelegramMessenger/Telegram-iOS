// Selectors Level 4, the profile's subset (M1a plan, Task 17): parsed with litehtml's CSS Syntax tokenizer (the policy
// layer's), matched right to left with WebKit's match results.
//
// A parsed list lives only inside one native call (querySelector*, matches, closest), on the C++ allocator: its size
// is a constant multiple of the selector string, which is already in JS memory (M1a plan, ruling 5). The parser keeps
// ruling 6's caps: 16,384 UTF-16 units of source, 32 nested functional pseudo-classes, 1,024 compound selectors in all
// and brackets 64 deep, past which a selector is a SyntaxError that no forgiving list drops. The length bounds that
// transient heap (Selectors.cpp, at the cap); the others bound the matcher's recursion (a frame per compound) and
// litehtml's componentizer (a frame per bracket).
#pragma once

#include <cstdint>
#include <vector>

#include "Sources/DOM/Element.h"

namespace wr {

struct ComplexSelector;
using SelectorList = std::vector<ComplexSelector>;

enum class PseudoClass : uint8_t {
    Root, Empty, FirstChild, LastChild, OnlyChild, FirstOfType, LastOfType, OnlyOfType,
    NthChild, NthLastChild, NthOfType, NthLastOfType, Not, Is, Where, Scope,
    AnyLink, Visited, Target, Defined, Checked, Indeterminate, Default, Disabled, Enabled, Required, Optional,
    ReadOnly, ReadWrite, PlaceholderShown, Focus, FocusWithin, FocusVisible, Hover, Active,
};

struct SimpleSelector {
    enum class Kind : uint8_t { Type, Universal, Id, Class, Attribute, Pseudo, PseudoElement };
    /// `*|` (any) or `|` (none). A type or universal selector without a prefix means any (there is no default
    /// namespace); an attribute selector without one means none.
    enum class Namespaces : uint8_t { Any, None };
    enum class Op : uint8_t { Exists, Equals, Includes, DashMatch, Prefix, Suffix, Substring };
    enum class Case : uint8_t { Default, Insensitive, Sensitive };

    Kind kind = Kind::Universal;
    Namespaces ns = Namespaces::Any;
    /// Type: the local name as written; Attribute: the attribute's name as written.
    Atom name;
    /// The same, ASCII-lowercased: what an HTML element in an HTML document is matched against.
    Atom lowerName;
    /// Id and Attribute: the value.
    String value;
    /// Class: the one class, as elementHasClasses takes it (made once here, not per element tested).
    std::vector<String> classes;
    Op op = Op::Exists;
    Case caseSensitivity = Case::Default;
    /// The attribute is in HTML's list of attributes whose values match case-insensitively.
    bool htmlCaseInsensitive = false;
    PseudoClass pseudo = PseudoClass::Root;
    /// An+B, saturated to 32 bits.
    int32_t a = 0;
    int32_t b = 0;
    /// :not/:is/:where, and nth-child's "of S".
    std::vector<ComplexSelector> list;
    /// Substring (`*=`): Knuth-Morris-Pratt failure tables for the value, as written and ASCII-lowercased.
    std::vector<uint32_t> failure;
    std::vector<uint32_t> failureFolded;
};

enum class Combinator : uint8_t { None, Descendant, Child, NextSibling, SubsequentSibling };

struct CompoundSelector {
    std::vector<SimpleSelector> simples;
    /// The combinator between this compound and the next one to its right.
    Combinator combinator = Combinator::None;
};

struct ComplexSelector {
    /// Left to right.
    std::vector<CompoundSelector> compounds;
};

/// Throws DOMError SyntaxError (and Thrown when the memory limit refuses a name's or a value's string).
SelectorList parseSelectors(JSContext* ctx, const String& text);
/// `scope` is :scope's node: querySelector's receiver, or the element matches() or closest() was called on. Matching
/// reads the tree through views and runs no script, so the tree cannot change while it runs.
bool matchesSelectors(JSContext* ctx, const SelectorList& list, Element& element, Node* scope);

} // namespace wr
