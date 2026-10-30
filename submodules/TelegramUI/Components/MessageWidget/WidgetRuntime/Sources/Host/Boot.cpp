#include "Sources/Host/Boot.h"

#include <optional>
#include <utility>

#include "Generated/Bindings.h"
#include "Sources/Canvas/ImageElement.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Events/Event.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Scripts.h"
#include "Sources/Host/Window.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

namespace {

using Scripts = Vector<Ref<HTMLScriptElement>>;

/// HTML's "update the current document readiness": sets it and fires readystatechange at the document. (Its first
/// step, returning when the readiness is unchanged, never applies: the boot sets each value once, in order.)
void updateReadiness(JSContext* ctx, Document& document, DocumentReadiness readiness) {
    document.setReadiness(readiness);
    fireEvent(ctx, document, Atom::fromUTF8(ctx, "readystatechange").get());
}

/// The boot's tasks (Ruling 9), one chain of them. The step numbers are those of HTML's "the end".
enum class Phase : uint8_t {
    /// The parse's scripts, one task each in tree order: HTML prepares a parsed script when the parser pops it.
    ParserScripts,
    /// Step 3: the readiness becomes "interactive".
    Interactive,
    /// Step 5: each script kept for after parsing, in order, a task each.
    ScriptsAfterParsing,
    /// Step 6: DOMContentLoaded at the document, bubbling (to the window).
    ContentLoaded,
    /// Step 9, after the async scripts (queued before it): "complete", load at the window with the legacy target
    /// override (event.target is the document), and the page showing steps' pageshow (9.11).
    Load,
};

/// A task of the chain: its phase and, in the two script phases, the list and the index of the script it is for.
struct Link {
    Phase phase;
    Scripts scripts;
    size_t index;
};

Link phaseLink(JSContext* ctx, Phase phase) {
    return Link{phase, Scripts{JSAllocator<Ref<HTMLScriptElement>>(JS_GetRuntime(ctx))}, 0};
}

/// Step 9's work after the readiness: load, then "fire a page transition event named pageshow at window with false",
/// a PageTransitionEvent, bubbling and cancelable, with the legacy target override.
void loadAndShow(JSContext* ctx) {
    Window& window = HostState::of(ctx).window();
    fireEvent(ctx, window, Atom::fromUTF8(ctx, "load").get(), false, false, true);
    idl::PageTransitionEventInit init;
    init.bubbles = true;
    init.cancelable = true;
    init.persisted = false;
    Ref<PageTransitionEvent> pageshow = PageTransitionEvent::construct(ctx, String::fromUTF8(ctx, "pageshow"), init);
    pageshow->setIsTrusted(true);
    dispatch(ctx, *pageshow, window, true);
}

/// What a link's task does.
void runLink(JSContext* ctx, Link& link) {
    switch (link.phase) {
    case Phase::ParserScripts:
        HostState::of(ctx).scripts().prepare(ctx, *link.scripts[link.index], ScriptElements::Caller::Parser);
        return;
    case Phase::Interactive:
        updateReadiness(ctx, DOMState::of(ctx).document(), DocumentReadiness::Interactive);
        return;
    case Phase::ScriptsAfterParsing:
        HostState::of(ctx).scripts().execute(ctx, *link.scripts[link.index]);
        return;
    case Phase::ContentLoaded:
        fireEvent(ctx, DOMState::of(ctx).document(), Atom::fromUTF8(ctx, "DOMContentLoaded").get(), true, false);
        return;
    case Phase::Load:
        // The host's inputs that waited for the load (state changes, the content safe area) run after it, in order
        // (their tasks queued first, so a catchable error below cannot keep them).
        HostState::of(ctx).releaseHeldInputs(ctx);
        // The parsed images' load and error first: the window's load waits for them (V5d plan, Task 5).
        fireParsedImageEvents(ctx);
        updateReadiness(ctx, DOMState::of(ctx).document(), DocumentReadiness::Complete);
        loadAndShow(ctx);
        return;
    }
}

/// The link after `link`: the next script of its list, else the next phase (a script phase with no script is passed
/// over). None after Load.
std::optional<Link> nextLink(JSContext* ctx, Link link) {
    switch (link.phase) {
    case Phase::ParserScripts:
        if (++link.index < link.scripts.size()) {
            return link;
        }
        return phaseLink(ctx, Phase::Interactive);
    case Phase::Interactive: {
        // Steps 3 to 5: once "interactive" is set, the list of scripts kept for after parsing, which the parse's
        // tasks filled as they prepared its deferred and module scripts.
        Link kept = phaseLink(ctx, Phase::ScriptsAfterParsing);
        std::swap(kept.scripts, HostState::of(ctx).scripts().scriptsAfterParsing());
        if (!kept.scripts.empty()) {
            return kept;
        }
        return phaseLink(ctx, Phase::ContentLoaded);
    }
    case Phase::ScriptsAfterParsing:
        if (++link.index < link.scripts.size()) {
            return link;
        }
        return phaseLink(ctx, Phase::ContentLoaded);
    case Phase::ContentLoaded:
        return phaseLink(ctx, Phase::Load);
    case Phase::Load:
        break;
    }
    return std::nullopt;
}

void queueLink(JSContext* ctx, Link link);

/// Queues the link after `link` while the widget runs. Never throws: its own failure (the memory limit) latches the
/// stop, as a step's would.
void queueNextLink(JSContext* ctx, Link& link) noexcept {
    if (Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    try {
        if (std::optional<Link> next = nextLink(ctx, std::move(link))) {
            queueLink(ctx, std::move(*next));
        }
    } catch (...) {
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

/// The one way a boot task is queued. The task runs the link's work and then, on any exit while the widget runs,
/// queues the next link (a scope guard): a catchable error the work throws, which the loop reports and the widget
/// survives, cannot end the chain. Never before the work: an async script's task, queued while a parse task prepares
/// it, must run right after that task, ahead of the next one. Throws as queueTask and makeTask do.
void queueLink(JSContext* ctx, Link link) {
    // A script's link runs it: a slice of its own, `script` in a CPU stop's message (upstream's pumpScripts).
    const TaskSource source =
        link.phase == Phase::ParserScripts || link.phase == Phase::ScriptsAfterParsing ? TaskSource::Script : TaskSource::DOMManipulation;
    EventLoop::of(ctx).queueTask(source, makeTask(ctx, [link = std::move(link)](JSContext* ctx) mutable {
        struct QueueNext {
            JSContext* ctx;
            Link& link;
            ~QueueNext() { queueNextLink(ctx, link); }
        } queueNext{ctx, link};
        EventLoop::of(ctx).markBootLinkStep();
        runLink(ctx, link);
    }));
}

} // namespace

Window* Document::defaultView(JSContext* ctx) {
    DOMState* dom = DOMState::find(ctx);
    HostState* host = HostState::find(ctx);
    if (!dom || !host || !dom->hasDocument() || this != &dom->document()) {
        return nullptr;
    }
    return &host->window();
}

ParseOutcome boot(JSContext* ctx, const BootOptions& options) {
    Runtime& runtime = Runtime::from(ctx);
    ParseOutcome outcome;
    // The host's entry, as a step is: a stopped widget boots nothing, and the boot may run on another thread than the
    // one that made the runtime.
    if (runtime.stopReason() != StopReason::None) {
        return outcome;
    }
    JS_UpdateStackTop(JS_GetRuntime(ctx));
    try {
        Document& document = DOMState::of(ctx).document();
        if (document.firstChildNode()) {
            // The parse needs an empty document: a host that hands boot one with children broke its contract.
            runtime.stop(StopReason::Internal);
            return outcome;
        }
        document.setURL(ctx, options.url);
        document.setReadiness(DocumentReadiness::Loading);
        {
            DOMState::DocumentParseScope parsing(DOMState::of(ctx));
            outcome = parseDocumentInto(ctx, document, options.html, options.limits);
        }
        // Ruling 13: the parsed markup is built, laid out and recorded before any script runs, so a first script that
        // never ends still leaves it (spec §5, step 3). The parse told the journal nothing: this flush is a full
        // build. A stop in it ends the boot below, as the parse's would.
        if (RenderTree* render = HostState::of(ctx).render()) {
            render->flush(ctx);
        }
        // The parse's scripts in tree order, held before any runs: scripts change the tree. Template contents live in
        // another document, so their scripts are not here.
        Scripts scripts{JSAllocator<Ref<HTMLScriptElement>>(JS_GetRuntime(ctx))};
        JSAtom script = DOMState::of(ctx).name(Name::script);
        for (Node* n = document.firstChildNode(); n; n = n->nextInTreeOrder(&document)) {
            if (n->isElement() && static_cast<Element*>(n)->hasHTMLName(script) && static_cast<HTMLScriptElement*>(n)->parserInserted()) {
                scripts.push_back(Ref<HTMLScriptElement>::retain(ctx, static_cast<HTMLScriptElement*>(n)));
            }
        }
        // Upstream's inputs wait for its boot: the host's state and content safe area changes wait for the load
        // (HostState::setData, setContentSafeArea).
        HostState::of(ctx).holdInputsUntilLoad();
        if (scripts.empty()) {
            queueLink(ctx, phaseLink(ctx, Phase::Interactive));
        } else {
            queueLink(ctx, Link{Phase::ParserScripts, std::move(scripts), 0});
        }
    } catch (...) {
        // Ruling C1: the boot is a step boundary. The parse runs attribute change steps outside any binding call, and
        // a stop inside them (Aborted), the memory limit (Thrown, std::bad_alloc) or any other failure latches what it
        // means here and ends the boot: nothing reaches the host, and the stopped widget runs nothing.
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
    return outcome;
}

} // namespace wr
