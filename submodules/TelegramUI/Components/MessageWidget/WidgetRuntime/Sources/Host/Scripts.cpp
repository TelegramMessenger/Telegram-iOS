#include "Sources/Host/Scripts.h"

#include <algorithm>
#include <iterator>
#include <optional>
#include <string>
#include <utility>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

namespace {

enum class ScriptType : uint8_t { Classic, Module, ImportMap, None };

bool isHTMLScript(JSContext* ctx, const Node& node) {
    return node.isElement() && static_cast<const Element&>(node).hasHTMLName(DOMState::of(ctx).name(Name::script));
}

/// What lowercased() gives for a value too long or not ASCII: equal to no name HTML knows, and never printed.
constexpr char kUnreadable = '\x01';

/// `value` with leading and trailing ASCII whitespace stripped when `strip`, ASCII lowercased. A value longer than
/// `maxLength` units, or with a non-ASCII character, is no name HTML knows: it comes back as kUnreadable without being
/// converted.
std::string lowercased(JSContext* ctx, const String& value, bool strip, uint32_t maxLength) {
    JSStringView v = value.view();
    auto unit = [&](uint32_t i) -> char16_t { return v.latin1 ? char16_t(v.latin1[i]) : v.utf16[i]; };
    uint32_t start = 0;
    uint32_t end = v.length;
    if (strip) {
        while (start < end && isASCIIWhitespace(unit(start))) {
            start++;
        }
        while (end > start && isASCIIWhitespace(unit(end - 1))) {
            end--;
        }
    }
    if (end - start > maxLength) {
        return std::string(1, kUnreadable);
    }
    std::string out;
    for (uint32_t i = start; i < end; i++) {
        char16_t c = unit(i);
        if (c >= 0x80) {
            return std::string(1, kUnreadable);
        }
        out += char(c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c);
    }
    return out;
}

/// MIME Sniffing's JavaScript MIME type essences.
bool isJavaScriptMIMETypeEssence(const std::string& type) {
    static const char* const kEssences[] = {
        "application/ecmascript", "application/javascript", "application/x-ecmascript", "application/x-javascript",
        "text/ecmascript",        "text/javascript",        "text/javascript1.0",       "text/javascript1.1",
        "text/javascript1.2",     "text/javascript1.3",     "text/javascript1.4",       "text/javascript1.5",
        "text/jscript",           "text/livescript",        "text/x-ecmascript",        "text/x-javascript",
    };
    return std::any_of(std::begin(kEssences), std::end(kEssences), [&](const char* e) { return type == e; });
}

/// HTML's step 8: the script block's type string, and what it is.
ScriptType scriptTypeOf(JSContext* ctx, HTMLScriptElement& el, DOMState& state, std::string* typeString) {
    std::optional<String> type = el.attributeValue(ctx, state.name(Name::type));
    std::optional<String> language = el.attributeValue(ctx, state.name(Name::language));
    if ((type && type->empty()) || (!type && language && language->empty()) || (!type && !language)) {
        *typeString = "text/javascript";
    } else if (type) {
        *typeString = lowercased(ctx, *type, true, 64);
    } else {
        *typeString = "text/" + lowercased(ctx, *language, false, 64);
    }
    if (isJavaScriptMIMETypeEssence(*typeString)) {
        return ScriptType::Classic;
    }
    if (*typeString == "module") {
        return ScriptType::Module;
    }
    if (*typeString == "importmap") {
        return ScriptType::ImportMap;
    }
    return ScriptType::None;
}

/// HTML's step 16: a classic script with both an event and a for attribute runs only for window's onload.
bool legacyEventForAllows(JSContext* ctx, HTMLScriptElement& el, DOMState& state) {
    std::optional<String> event = el.attributeValue(ctx, state.name(Name::event));
    std::optional<String> forValue = el.attributeValue(ctx, state.name(Name::for_));
    if (!event || !forValue) {
        return true;
    }
    if (lowercased(ctx, *forValue, true, 16) != "window") {
        return false;
    }
    std::string e = lowercased(ctx, *event, true, 16);
    return e == "onload" || e == "onload()";
}

/// The first 200 bytes of `s`, cut at a character boundary, for a diagnostic.
std::string clipped(const String& s) {
    bool cut = false;
    std::string out = s.utf8Prefix(200, &cut);
    return cut ? out + "…" : out;
}

/// HTML's "queue an element task on the DOM manipulation task source given el to fire an event named `type` at el".
/// `type` is a literal: the task keeps the pointer, nothing allocated outside the widget's memory.
void queueElementEvent(JSContext* ctx, HTMLScriptElement& el, const char* type) {
    EventLoop::of(ctx).queueTask(TaskSource::DOMManipulation,
                                 makeTask(ctx, [script = Ref<HTMLScriptElement>::retain(ctx, &el), type](JSContext* ctx) mutable {
                                     fireEvent(ctx, *script, Atom::fromUTF8(ctx, type).get());
                                 }));
}

/// The sets HTML executes "as soon as possible", in order or not: the source is always ready at once here, so each is
/// a task (HTML's networking task source; ours Script, which names a boot's in a CPU stop), and the queue's order is
/// the order. A parser-inserted one runs as the boot's, a link as the parse's other scripts are
/// (EventLoop::markBootLinkStep, which demotion exempts); one the widget inserted is its own.
void queueExecution(JSContext* ctx, HTMLScriptElement& el, bool parserInserted) {
    EventLoop::of(ctx).queueTask(TaskSource::Script, makeTask(ctx, [script = Ref<HTMLScriptElement>::retain(ctx, &el), parserInserted](JSContext* ctx) mutable {
        if (parserInserted) {
            EventLoop::of(ctx).markBootLinkStep();
        }
        HostState::of(ctx).scripts().execute(ctx, *script);
    }));
}

} // namespace

ScriptElements::ScriptElements(JSContext* ctx, Document& document)
    : m_ctx(ctx), m_document(Ref<Document>::retain(ctx, &document)), m_pending(JSAllocator<Pending>(JS_GetRuntime(ctx))),
      m_afterParsing(JSAllocator<Ref<HTMLScriptElement>>(JS_GetRuntime(ctx))) {
    document.mutationListeners().push_back(this);
}

ScriptElements::~ScriptElements() {
    auto& listeners = m_document->mutationListeners();
    listeners.erase(std::remove(listeners.begin(), listeners.end(), static_cast<MutationListener*>(this)), listeners.end());
}

void ScriptElements::collect(Node& node, bool subtree) {
    try {
        m_pending.push_back(Pending{Ref<Node>::retain(m_ctx, &node), subtree});
    } catch (...) {
        // std::bad_alloc at the memory limit (latched Memory already): Aborted unwinds the mutation.
        abortForCaughtException(m_ctx);
    }
    Runtime::from(m_ctx).requestNativeExitWork();
}

// The post-connection steps, for every script in the inserted subtree (walked later, at depth 0). Only an element can
// be or contain a script.
void ScriptElements::nodeInserted(Node& node) {
    if (node.isElement()) {
        this->collect(node, true);
    }
}

// The script children changed steps: the post-connection steps for the script itself.
void ScriptElements::childrenChanged(Node& parent) {
    if (isHTMLScript(m_ctx, parent)) {
        this->collect(parent, false);
    }
}

// The script attribute change steps: setting or adding async clears force async; setting src (HTML: "value is not
// null", so not its removal) runs the post-connection steps. Only for the null namespace ("if namespace is not null,
// return"), and only for a connected script: the parser sets attributes on elements it has not attached yet (a parsed
// script must wait for the boot's task, not run as a script-inserted one), and those have no parent.
void ScriptElements::attributeChanged(Element& element, JSAtom localName, Namespace ns) {
    try {
        DOMState& state = DOMState::of(m_ctx);
        if (ns != Namespace::None || !element.hasHTMLName(state.name(Name::script))) {
            return;
        }
        auto& script = static_cast<HTMLScriptElement&>(element);
        if (localName == state.name(Name::async)) {
            script.setForceAsync(false);
        } else if (localName == state.name(Name::src) && !script.alreadyStarted() && element.parent() &&
                   element.hasAttributeAtom(m_ctx, localName) && element.connected(m_ctx)) {
            this->collect(element, false);
        }
    } catch (...) {
        // collect's Aborted (the memory limit, latched already) or any other failure: Aborted.
        abortForCaughtException(m_ctx);
    }
}

void ScriptElements::preparePending(JSContext* ctx) {
    while (!m_pending.empty()) {
        // Take this round's entries: a script run below that inserts another prepares that one in a nested call, at
        // once, before the rest of this round (HTML runs an inserted inline script during the script inserting it).
        Vector<Pending> round{JSAllocator<Pending>(JS_GetRuntime(ctx))};
        std::swap(round, m_pending);
        for (Pending& p : round) {
            if (!p.subtree) {
                // HTML's post-connection steps prepare only a connected script. prepare's own step 7 returns for a
                // disconnected one only after steps 2 to 4 have cleared a parser-inserted script's parser document
                // and set its force async, which would make its boot turn run it as a script-inserted one.
                if (p.node->connected(ctx)) {
                    this->prepare(ctx, static_cast<HTMLScriptElement&>(*p.node), Caller::Dynamic);
                }
                continue;
            }
            Node& root = *p.node;
            if (!root.connected(ctx)) {
                continue;
            }
            // HTML's static node list: the scripts in the subtree as inserted, before any of them runs.
            Vector<Ref<HTMLScriptElement>> scripts{JSAllocator<Ref<HTMLScriptElement>>(JS_GetRuntime(ctx))};
            for (Node* n = &root; n; n = n->nextInTreeOrder(&root)) {
                if (isHTMLScript(ctx, *n)) {
                    scripts.push_back(Ref<HTMLScriptElement>::retain(ctx, static_cast<HTMLScriptElement*>(n)));
                }
            }
            for (Ref<HTMLScriptElement>& script : scripts) {
                this->prepare(ctx, *script, Caller::Dynamic);
            }
        }
    }
}

void ScriptElements::prepare(JSContext* ctx, HTMLScriptElement& el, Caller caller) {
    Ref<HTMLScriptElement> keep = Ref<HTMLScriptElement>::retain(ctx, &el);
    DOMState& state = DOMState::of(ctx);
    Host& host = Runtime::from(ctx).host();
    // 1.
    if (el.alreadyStarted()) {
        return;
    }
    // 2, 3.
    Ref<Document> parserDocument = Ref<Document>::retain(ctx, el.parserDocument());
    el.setParserDocument(ctx, nullptr);
    // 4.
    if (parserDocument && !el.hasAttributeAtom(ctx, state.name(Name::async))) {
        el.setForceAsync(true);
    }
    // 5, 6.
    String sourceText = childTextContent(ctx, el);
    bool hasSrc = el.hasAttributeAtom(ctx, state.name(Name::src));
    if (!hasSrc && sourceText.empty()) {
        return;
    }
    // 7. A script the boot hands over runs even if an earlier script removed it: the parser would have handed it
    // over before any later script could (the parse-before-scripts divergence, spec section 10.2).
    if (caller == Caller::Dynamic && !el.connected(ctx)) {
        return;
    }
    // 8.
    std::string typeString;
    ScriptType type = scriptTypeOf(ctx, el, state, &typeString);
    if (type == ScriptType::None) {
        // Data blocks (JSON, templates, x- types) are inert by design; anything else is worth telling the author.
        bool dataBlock = typeString.find("json") != std::string::npos || typeString.find("template") != std::string::npos ||
                         typeString.find("x-") != std::string::npos;
        if (typeString.find(kUnreadable) != std::string::npos) {
            host.diagnostic("script-skipped", "unsupported script type (too long or non-ASCII)");
        } else if (!dataBlock) {
            host.diagnostic("script-skipped", "unsupported script type \"" + typeString + "\"");
        }
        return;
    }
    // 9.
    if (parserDocument) {
        el.setParserDocument(ctx, parserDocument.get());
        el.setForceAsync(false);
    }
    // 10, 11.
    el.setAlreadyStarted(true);
    el.setPreparationTimeDocument(ctx, el.nodeDocument());
    // 12.
    if (parserDocument && parserDocument.get() != &el.nodeDocument()) {
        return;
    }
    // 13. Scripting is disabled outside the window's document (no other has a browsing context). The listener hears
    // only that document, but a script collected there can be moved into another (connected in `new Document()`)
    // before its turn.
    if (&el.nodeDocument() != m_document.get()) {
        return;
    }
    // 14.
    if (type == ScriptType::Classic && el.hasAttributeAtom(ctx, state.name(Name::nomodule))) {
        return;
    }
    // 16.
    if (type == ScriptType::Classic && !legacyEventForAllows(ctx, el, state)) {
        return;
    }
    // Import maps are not supported: without a module loader there is nothing to map.
    if (type == ScriptType::ImportMap) {
        host.diagnostic("script-skipped", "import maps are not supported");
        if (hasSrc) {
            queueElementEvent(ctx, el, "error");
        }
        return;
    }
    el.setScriptKind(type == ScriptType::Module ? HTMLScriptElement::Kind::Module : HTMLScriptElement::Kind::Classic);
    bool parserInserted = bool(parserDocument);
    if (hasSrc) {
        String src = *el.attributeValue(ctx, state.name(Name::src));
        if (src.empty()) {
            queueElementEvent(ctx, el, "error");
            return;
        }
        el.setFromExternalFile(true);
        // No URL parser until M2: the loader gets the attribute as written. The host's loader answers at once; the
        // runtime itself never fetches anything.
        std::string url = src.utf8();
        ScriptLoader* loader = host.scriptLoader();
        std::optional<ScriptSource> source = loader ? loader->load(url) : std::nullopt;
        if (source) {
            el.setResult(ctx, String::fromUTF8(ctx, source->text), String::fromUTF8(ctx, source->url));
        } else {
            host.diagnostic("script-skipped", "external script not available: " + clipped(src));
            el.setNullResult(JS_GetRuntime(ctx));
        }
        if (parserInserted) {
            el.setReadyToBeParserExecuted(true);
        }
    } else {
        el.setResult(ctx, sourceText, el.nodeDocument().URL(ctx));
    }
    // HTML's step 32, the cases in its order.
    bool async = el.hasAttributeAtom(ctx, state.name(Name::async));
    bool defer = el.hasAttributeAtom(ctx, state.name(Name::defer));
    if ((type == ScriptType::Classic && hasSrc && parserInserted && defer && !async) ||
        (type == ScriptType::Module && parserInserted && !async)) {
        m_afterParsing.push_back(Ref<HTMLScriptElement>::retain(ctx, &el));
        return;
    }
    if (type == ScriptType::Classic && hasSrc && parserInserted && !async) {
        // A parsing-blocking script, ready at once.
        this->execute(ctx, el);
        return;
    }
    if ((type == ScriptType::Classic && hasSrc) || type == ScriptType::Module) {
        // "In order as soon as possible" (no async, not force async) or "as soon as possible": a task either way.
        queueExecution(ctx, el, parserInserted);
        return;
    }
    // An inline classic script, parser-inserted or not: "immediately execute the script element".
    this->execute(ctx, el);
}

void ScriptElements::execute(JSContext* ctx, HTMLScriptElement& el) {
    Ref<HTMLScriptElement> keep = Ref<HTMLScriptElement>::retain(ctx, &el);
    // Held across the script: it can adopt el into another document, releasing el's reference to this one.
    Ref<Document> document = Ref<Document>::retain(ctx, &el.nodeDocument());
    // 2.
    if (el.preparationTimeDocument() != document.get()) {
        return;
    }
    // 4.
    if (el.result() == HTMLScriptElement::Result::Null) {
        fireEvent(ctx, el, Atom::fromUTF8(ctx, "error").get());
        return;
    }
    String source = el.resultSource(ctx);
    std::string url = el.resultURL(ctx);
    std::string text = source.utf8();
    Runtime& runtime = Runtime::from(ctx);
    // 6. currentScript is the classic script while it runs, the microtask checkpoint of "clean up after running
    // script" included; a module script runs with it null.
    if (el.scriptKind() == HTMLScriptElement::Kind::Classic) {
        Ref<HTMLScriptElement> old = Ref<HTMLScriptElement>::retain(ctx, document->currentScriptElement());
        document->setCurrentScript(ctx, &el);
        try {
            runtime.runScript(text, url.c_str(), false);
        } catch (...) {
            document->setCurrentScript(ctx, old.get());
            throw;
        }
        document->setCurrentScript(ctx, old.get());
    } else {
        runtime.runScript(text, url.c_str(), true);
    }
    // 8.
    if (el.fromExternalFile()) {
        fireEvent(ctx, el, Atom::fromUTF8(ctx, "load").get());
    }
}

} // namespace wr
