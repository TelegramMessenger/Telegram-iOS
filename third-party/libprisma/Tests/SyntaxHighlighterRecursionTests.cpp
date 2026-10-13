// Regression test for the unbounded-recursion DoS in the code-block syntax
// highlighter (see the "brightscript" report). A short message whose language
// is a Prism grammar with a token cycle (directive-statement -> expression ->
// directive-statement) drove SyntaxHighlighter::tokenize()/matchGrammar() into
// unbounded mutual recursion and exhausted the thread stack (SIGSEGV into the
// guard page) as soon as the block was highlighted.
//
// The fix bounds the grammar recursion with a depth counter. This test loads
// the real shipped grammars.dat (passed as argv[1] via the BUILD `args`) and
// highlights the report's payload; before the fix it crashes, after the fix it
// returns and highlighting stays lossless (the concatenated text is unchanged).
//
// Pure C++ host test, following the CHECK_TRUE + main() pattern of the tgcalls
// cc_tests. No gtest dependency.

#include "SyntaxHighlighter.h"
#include "TokenList.h"

#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>

static int g_failures = 0;

#define CHECK_TRUE(cond, msg)                                              \
    do {                                                                   \
        if (!(cond)) {                                                     \
            std::fprintf(stderr, "FAIL: %s (%s:%d)\n", (msg), __FILE__,    \
                         __LINE__);                                        \
            ++g_failures;                                                  \
        } else {                                                          \
            std::fprintf(stderr, "ok: %s\n", (msg));                       \
        }                                                                  \
    } while (0)

// Flatten a highlighted TokenList back to its plain text, mirroring the paint
// walk in Syntaxer.mm: Text nodes contribute their value, Syntax nodes recurse
// into their children. Highlighting must be lossless.
static void appendNode(const TokenListNode& node, std::string& out) {
    if (node.isSyntax()) {
        const auto& syntax = dynamic_cast<const Syntax&>(node);
        for (auto it = syntax.begin(); it != syntax.end(); ++it) {
            appendNode(*it, out);
        }
    } else {
        const auto& text = dynamic_cast<const Text&>(node);
        out.append(text.value());
    }
}

static std::string flatten(const TokenList& tokens) {
    std::string out;
    for (auto it = tokens.begin(); it != tokens.end(); ++it) {
        appendNode(*it, out);
    }
    return out;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::fprintf(stderr, "usage: %s <path-to-grammars.dat>\n", argv[0]);
        return 2;
    }

    std::ifstream f(argv[1], std::ios::binary);
    if (!f) {
        std::fprintf(stderr, "cannot open grammars.dat at %s\n", argv[1]);
        return 2;
    }
    std::stringstream ss;
    ss << f.rdbuf();
    std::string grammars = ss.str();
    CHECK_TRUE(grammars.size() > 100000, "grammars.dat loaded");

    SyntaxHighlighter highlighter(grammars);

    // The DoS payload: a "brightscript" code block. Before the depth bound this
    // recurses without limit and the process dies with a stack overflow, so
    // simply reaching the assertions below is the core of the regression.
    {
        const std::string code = "#iFclude <a>";
        TokenList tokens = highlighter.tokenize(code, "brightscript");
        CHECK_TRUE(flatten(tokens) == code,
                   "brightscript DoS payload highlights losslessly without overflow");
    }

    // Longer minimised variants from the report, all previously crashing.
    for (const std::string& code : {std::string("#iFclude <a>2}"),
                                    std::string("#iFclude <a>2}ss"),
                                    std::string("#iFncLude x <a>\fracde <a>\frac{{1}{2}")}) {
        TokenList tokens = highlighter.tokenize(code, "brightscript");
        CHECK_TRUE(flatten(tokens) == code,
                   "brightscript variant highlights losslessly without overflow");
    }

    // Controls: benign inputs must still be highlighted and stay lossless.
    {
        const std::string code = "print 1";
        TokenList tokens = highlighter.tokenize(code, "brightscript");
        CHECK_TRUE(flatten(tokens) == code, "benign brightscript stays lossless");
    }
    {
        const std::string code = "var x = 1; function f() { return x; }";
        TokenList tokens = highlighter.tokenize(code, "javascript");
        CHECK_TRUE(flatten(tokens) == code, "javascript stays lossless");
    }

    if (g_failures == 0) {
        std::fprintf(stderr, "ALL PASS\n");
        return 0;
    }
    std::fprintf(stderr, "%d FAILURE(S)\n", g_failures);
    return 1;
}
