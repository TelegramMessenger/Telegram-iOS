// HTML's script processing model (https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model):
// "prepare the script element", "execute the script element", the triggers for scripts that script inserts, fills or
// gives a src (the post-connection, children changed and attribute change steps), and the list of scripts "the end"
// executes. One per runtime, owned by HostState; it listens to the main document's mutations.
#pragma once

#include <cstdint>

#include "Sources/DOM/Document.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/PlatformObject.h"

namespace wr {

class HTMLScriptElement;

class ScriptElements : public MutationListener {
public:
    /// Registers with `document`'s mutation listeners; the destructor unregisters.
    ScriptElements(JSContext* ctx, Document& document);
    ~ScriptElements() override;
    ScriptElements(const ScriptElements&) = delete;
    ScriptElements& operator=(const ScriptElements&) = delete;

    /// Who prepares: the boot's task for one of the parse's scripts (Parser), or a trigger (Dynamic).
    enum class Caller : uint8_t { Parser, Dynamic };
    /// "prepare the script element". Runs the script now where HTML says "immediately execute"; queues its execution
    /// as a task, or appends it to scriptsAfterParsing, otherwise. Throws Aborted.
    void prepare(JSContext* ctx, HTMLScriptElement& script, Caller caller);
    /// "execute the script element". Throws Aborted.
    void execute(JSContext* ctx, HTMLScriptElement& script);
    /// HTML's "list of scripts that will execute when the document has finished parsing", in order.
    Vector<Ref<HTMLScriptElement>>& scriptsAfterParsing() { return m_afterParsing; }
    /// Prepares what the mutation triggers collected, in order. Called at mutation depth 0: by HostState's native-exit
    /// hook and after every task. Re-entrant: a script it runs that inserts another prepares that one at once.
    void preparePending(JSContext* ctx);
    bool hasPending() const { return !m_pending.empty(); }

    // MutationListener: collect only, and run no script. The pending list's growth and the attribute steps' connected
    // check are the only work; a failure in it (the memory limit) latches the stop and throws Aborted, so a
    // half-notified mutation is never observed (as EventHandlerAttributes does).
    void nodeInserted(Node& node) override;
    void childrenChanged(Node& parent) override;
    void attributeChanged(Element& element, JSAtom localName, Namespace ns) override;

private:
    struct Pending {
        Ref<Node> node;
        /// An inserted root, whose script descendants are prepared in tree order; otherwise a script itself.
        bool subtree;
    };
    void collect(Node& node, bool subtree);

    JSContext* m_ctx;
    Ref<Document> m_document;
    Vector<Pending> m_pending;
    Vector<Ref<HTMLScriptElement>> m_afterParsing;
};

} // namespace wr
