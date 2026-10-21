// One widget's QuickJS runtime and context, the classes of its interface table, and its interface objects, made on
// first use (quickjs-ng changes 3 and 4). It also owns the widget's work limit and its stop latch, and counts the
// calls into JS and the native frames on the stack (M1b plan, Global Constraints "Stops are final" and Ruling 6).
#pragma once

#include <array>
#include <cstdint>
#include <functional>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

#include "quickjs.h"
#include "Sources/Runtime/Host.h"
#include "Sources/Support/Bindings.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

/// Where a layer above the runtime keeps its per-runtime state: the DOM's (DOMState) and the host layer's (HostState:
/// the Window and the event loop). Both are destroyed before the context, the host slot first.
enum class ExtensionSlot : uint8_t { DOM = 0, Host = 1, Count = 2 };

/// Why a runtime stopped for good. The first reason latched wins. LayoutQuery: the layout queries of one task did more
/// than their own budget (sdk-v1 §2, "Layout query limit exceeded"; work::kLayoutQueryBudget).
enum class StopReason : uint8_t { None, Budget, Memory, Internal, LayoutQuery };

/// State a layer above the runtime keeps per runtime. Destroyed before the context.
class RuntimeExtension {
public:
    virtual ~RuntimeExtension() = default;
    /// HTML "clean up after running script": the outermost call into JS returned (Task 9 makes it the microtask
    /// checkpoint). Only the Host slot's extension is asked, never while it is already running, and never once the
    /// runtime stopped. Throws Aborted when the work it runs stops the widget.
    virtual void afterOutermostScript(JSContext* ctx) {}
    /// HTML "report the exception", taking over `exception` (Task 9: an ErrorEvent at the window). Only the Host slot's
    /// extension is asked; this default logs it to the host. Throws Aborted.
    virtual void reportException(JSContext* ctx, JSValue exception);
    /// Called on the Host extension when the outermost native frame is left normally after
    /// Runtime::requestNativeExitWork (Ruling 6): HostState prepares the scripts mutations collected.
    virtual void afterOutermostNative(JSContext*) {}
};

/// The tag of a host auto-init entry on the global that stands for a [Global] interface's operation
/// (installGlobalMembers), as opposed to an interface object's entry, whose opaque is the interface index + 1 (below
/// 2^15 + 1). The rest of the value is (iface << 16) | member.
inline constexpr uintptr_t kGlobalMemberTag = uintptr_t(1) << 31;
/// The tag of a host auto-init entry on the global that stands for a lazy global (Runtime::defineLazyGlobal); the rest
/// of the value is its index.
inline constexpr uintptr_t kLazyGlobalTag = uintptr_t(1) << 32;
static_assert(sizeof(uintptr_t) == 8, "kLazyGlobalTag needs a 64-bit opaque");

/// Registers the class of WebIDL pair iterator objects (Sources/Runtime/PairIterators.cpp) on `rt`, into `id`.
void registerPairIteratorClass(JSRuntime* rt, JSClassID& id);

class Runtime {
public:
    struct Options {
        const InterfaceTable* interfaces = nullptr;
        /// QuickJS's memory limit. An allocation it refuses stops the widget (StopReason::Memory, quickjs-ng change 9).
        size_t memoryLimitBytes = size_t(64) << 20;
        /// QuickJS's stack limit. The pool threads that run widgets have 2 MB stacks (MessageWidgetPool).
        size_t maxStackBytes = size_t(1) << 20;
        /// Math.random's seed (quickjs-ng change 7): the same seed gives the same sequence.
        uint64_t randomSeed = 1;
        /// The embedder's clocks, log and loader. Not owned; it outlives the runtime. nullptr gives a host whose clocks
        /// read zero, that logs nothing and refuses every script source.
        Host* host = nullptr;
    };

    static std::unique_ptr<Runtime> create(const Options& options);
    ~Runtime();
    Runtime(const Runtime&) = delete;
    Runtime& operator=(const Runtime&) = delete;

    static Runtime& from(JSContext* ctx) { return *static_cast<Runtime*>(JS_GetContextOpaque(ctx)); }

    JSContext* context() const { return m_ctx; }
    JSRuntime* jsRuntime() const { return m_rt; }
    const InterfaceTable& interfaces() const { return *m_table; }
    Host& host() const { return *m_host; }

    JSClassID classId(uint16_t iface) const { return m_firstClassId + iface; }
    /// The interface index of a platform object of this runtime, or -1.
    int interfaceOf(JSValueConst v) const;
    /// Whether interface `index` is `iface` or derives from it.
    bool implementsInterface(int index, uint16_t iface) const;

    /// Made on first use; borrowed. Throws Thrown.
    JSValueConst interfaceObject(uint16_t iface);
    JSValueConst prototype(uint16_t iface);
    size_t materializedCount() const { return m_materialized; }

    /// The table index of the [Global] interface, or -1. When there is one, the context's global object is an
    /// instance of its class (quickjs-ng change 6), with no payload until createGlobal<T>.
    int globalInterface() const { return m_globalInterface; }
    /// WebIDL [Global]. Makes the global object's [[Prototype]] iface's prototype and defines iface's regular members
    /// on it:
    /// - operations as lazy data properties: an auto-init entry (quickjs-ng change 3) can only become a data property;
    /// - attributes as accessors, made now;
    /// - [LegacyUnforgeable] members non-configurable;
    /// - then the ancestors' [LegacyUnforgeable] members.
    /// An own property of the same name that the engine made (QuickJS's queueMicrotask, performance) gives way to the
    /// IDL member. Call once, after createGlobal<T>. Throws Thrown, and std::logic_error when iface is not the
    /// table's [Global] interface.
    void installGlobalMembers(uint16_t iface);
    /// Makes a global's value: a new reference, or the exception marker.
    using LazyGlobal = JSValue (*)(JSContext* ctx);
    /// Defines `name` on the global object as a writable, configurable, non-enumerable data property whose value
    /// `make` makes the first time the property is read or described (V5b plan, Task 1: `Intl`). Throws Thrown.
    void defineLazyGlobal(const char* name, LazyGlobal make);
    /// Whether iface or an ancestor has [LegacyUnforgeable] members.
    bool hasUnforgeableMembers(uint16_t iface) const { return m_hasUnforgeable[iface]; }
    /// Defines the [LegacyUnforgeable] members of iface and its ancestors as own properties of `object`. One function
    /// per member serves every instance (WebIDL: the same getter for every object). Runs for every new instance, so
    /// it charges its work. Throws Thrown.
    void defineUnforgeableMembers(JSValueConst object, uint16_t iface);

    JSAtom reflectedAtom(uint16_t id) const { return m_reflectedAtoms[id]; }

    /// Defines a global data property (writable, configurable), taking over `value`.
    void setGlobal(const char* name, JSValue value);
    /// Defines a non-writable, non-configurable global data property, taking over `value`.
    void setFixedGlobal(const char* name, JSValue value);

    /// Evaluates a global script for a test: its completion value as a string, or "Name: message" with *threw set. It
    /// counts as a call into JS: the cleanup hook runs after it, and an Aborted the hook throws (a checkpoint whose work
    /// stopped the widget) propagates. When the call latched the runtime (the budget, out of memory, a native's
    /// failure), it throws Aborted, as every call into JS does; it latches nothing of its own, so an uncatchable error
    /// that latched nothing reads back as its message ("InternalError: interrupted"). On a runtime already stopped it
    /// evaluates nothing and answers that same text with *threw set.
    std::string evaluateToString(std::string_view code, const char* filename, bool* threw);

    void setExtension(ExtensionSlot slot, std::unique_ptr<RuntimeExtension> extension) { m_extensions[size_t(slot)] = std::move(extension); }
    RuntimeExtension* extension(ExtensionSlot slot) const { return m_extensions[size_t(slot)].get(); }

    // The work limit and the stop latch (Global Constraints, "Stops are final").
    /// The work counter (JS_GetWorkUnits) value at which the widget stops. UINT64_MAX: none.
    /// A new limit starts a new step (the host sets one before each), so it starts the layout-query count again too.
    void setWorkLimit(uint64_t absoluteUnits) {
        m_workLimit = absoluteUnits;
        m_layoutQueryUnits = 0;
    }
    uint64_t workLimit() const { return m_workLimit; }
    /// The work this step's layout queries did (Sources/DOM/Geometry.cpp counts it against work::kLayoutQueryBudget).
    uint64_t layoutQueryUnits() const { return m_layoutQueryUnits; }
    void addLayoutQueryUnits(uint64_t units) { m_layoutQueryUnits += units; }
    /// Calls `observer` with the work counter (JS_GetWorkUnits) from the interrupt poll, whenever at least `everyUnits`
    /// have passed since its last call (M1d plan, Task 1): the host feeds main's wait meter from it while a step runs.
    /// It never throws: an exception from `observer` is dropped. An empty function removes it.
    void setWorkObserver(std::function<void(uint64_t total)> observer, uint64_t everyUnits);
    /// Latches `reason` unless a stop is latched already, and with the first one stops QuickJS's runtime (quickjs-ng
    /// change 10): from then on no exception can be caught, whatever was thrown (bare null included). Allocates
    /// nothing: the memory-limit hook calls it inside QuickJS's allocator, and the interrupt handler inside a poll.
    void stop(StopReason reason) noexcept {
        if (m_stopReason == StopReason::None) {
            m_stopReason = reason;
            JS_SetStopped(m_rt);
        }
    }
    StopReason stopReason() const { return m_stopReason; }
    /// The one public fatal-error check, for an exception that reached C++ other than through callFunction (a job's
    /// failure, a failed JS_Eval or JS_ToCString). When the runtime has stopped, or `exception` is QuickJS's out-of-memory
    /// error, or it is uncatchable, latches the runtime (Memory for out of memory; for an uncatchable error Budget when
    /// the work limit is spent, else Internal) and throws Aborted. Otherwise returns: the exception is catchable and the
    /// caller reports it. Borrows `exception`.
    void throwIfFatal(JSContext* ctx, JSValueConst exception);
    /// Throws Aborted when the runtime stopped. (Task 5 internal, like abortWithPendingException, enterScript and
    /// leaveScript: later tasks use throwIfFatal.)
    void throwIfStopped() const;
    /// Takes the pending exception, latches the runtime as throwIfFatal classifies it (unless already stopped) and
    /// throws Aborted. For a pending exception that must stop the widget (a failed charge): one that could be caught
    /// latches Internal.
    [[noreturn]] void abortWithPendingException(JSContext* ctx);
    /// Inside a catch block, at a script boundary or on a path whose contract is "throws only Aborted" (Task 9's report
    /// and microtask checkpoint, through wr::abortForCaughtException): latches what the C++ exception being handled
    /// means and throws Aborted. Aborted passes on as it is (latched where it started), Thrown by its pending exception
    /// (classifyFatal, a catchable one Internal), std::bad_alloc latches Memory, anything else Internal.
    [[noreturn]] void abortForCaughtException(JSContext* ctx);

    // Native frames (Ruling 6, mutation depth).
    /// Ruling 6, mutation depth: binding calls and MutationScopes nested since the last call into JS.
    int nativeDepth() const { return m_nativeDepth; }
    /// Asks for the Host extension's afterOutermostNative when the outermost native frame is next left normally.
    void requestNativeExitWork() { m_nativeExitWork = true; }
    /// For the JS a caller is about to run (callFunction, callInterface, runScript, an event handler's compilation):
    /// saves the native depth and starts it at 0, so a binding call that JS makes is outermost again; restores it when
    /// the JS returns.
    class ScriptBoundary {
    public:
        explicit ScriptBoundary(Runtime& runtime) : m_runtime(runtime), m_saved(runtime.m_nativeDepth) { runtime.m_nativeDepth = 0; }
        ~ScriptBoundary() { m_runtime.m_nativeDepth = m_saved; }
        ScriptBoundary(const ScriptBoundary&) = delete;
        ScriptBoundary& operator=(const ScriptBoundary&) = delete;

    private:
        Runtime& m_runtime;
        int m_saved;
    };

    // Calls into JS (Ruling 6, callback depth).
    int scriptDepth() const { return m_scriptDepth; }
    /// Around a JS-visible read a report makes of a value (ToString of the exception, its `stack`, a rejection's reason
    /// described for the host; final review I3): the author code that read runs counts as a call into JS, so a
    /// callback it makes is not the outermost call and the cleanup hook (the microtask checkpoint) never runs inside
    /// the conversion. Leaving runs no cleanup: the task, callback or script the report belongs to runs its own
    /// afterwards, which drains what the read queued. The depth is given back on every exit, Aborted and Thrown
    /// included. Only the reads: the ErrorEvent's dispatch is not one, and each of its listeners stays outermost.
    class ConversionScope {
    public:
        explicit ConversionScope(Runtime& runtime) : m_runtime(runtime) { runtime.m_scriptDepth++; }
        ~ConversionScope() { m_runtime.m_scriptDepth--; }
        ConversionScope(const ConversionScope&) = delete;
        ConversionScope& operator=(const ConversionScope&) = delete;

    private:
        Runtime& m_runtime;
    };
    /// Before a call into JS (wr::callFunction, wr::callInterface).
    void enterScript() { m_scriptDepth++; }
    /// After it, with the call's result (taken over): an uncatchable error or out of memory aborts, and so does a call
    /// that returned on a runtime it stopped (QuickJS turns some exceptions, a stop's included, into a promise
    /// rejection); otherwise the value or the exception, after the cleanup hook ran if this was the outermost call.
    CallResult leaveScript(JSContext* ctx, JSValue result);
    /// HTML "run a classic script" (or "run a module script" when `isModule`, with no module loader: an `import` fails
    /// to link and throws): evaluates `source` at native depth 0 (ScriptBoundary), reports an exception it throws, or
    /// the reason a module's evaluation promise was rejected with by the time it returns (before the cleanup, as HTML
    /// orders it), and returns false then. A module's promise still pending (top-level await) is not reported if it
    /// rejects later: that is an unhandledrejection. Throws Aborted on a stop: one inside the script (also when a
    /// promise turned it into a rejection), and a C++ failure in the report or the cleanup, which latches Memory for
    /// bad_alloc and Internal otherwise.
    bool runScript(std::string_view source, const char* filename, bool isModule);
    /// HTML "report the exception", taking over `exception`: to the Host slot's extension, or the default log.
    void reportException(JSContext* ctx, JSValue exception);
    /// The default report: "Uncaught <the exception as a string>" to the host's log, the string cut at 4,000 UTF-8
    /// bytes (Ruling 14; only that much of it is converted). Takes over `exception`. Throws Aborted.
    void logUncaughtException(JSContext* ctx, JSValue exception);

    /// The well-known @@iterator, taken when the runtime was made (a script cannot replace it). Borrowed.
    JSAtom iteratorSymbol() const { return m_iterator; }
    /// Built-in functions taken when the runtime was made, before any script ran: the host reads a DataView and walks a
    /// Map or a Set through these, so a script that redefines DataView.prototype's accessors or replaces Map.prototype's
    /// methods cannot change what it reads (V5a final review, C2 and C3). Number.prototype.valueOf, BigInt.prototype.valueOf
    /// and Date.prototype.getTime are ECMA-402's thisNumberValue, thisBigIntValue and thisTimeValue (V5b).
    enum class Intrinsic : uint8_t {
        DataViewBuffer,
        DataViewByteOffset,
        DataViewByteLength,
        MapConstructor,
        MapEntries,
        MapSet,
        MapIteratorNext,
        SetConstructor,
        SetValues,
        SetAdd,
        SetIteratorNext,
        NumberValueOf,
        BigIntValueOf,
        DateGetTime,
        Count
    };
    /// Borrowed.
    JSValueConst intrinsic(Intrinsic which) const { return m_intrinsics[size_t(which)]; }
    /// Platform objects created and not yet finalized (tests).
    size_t liveObjects() const { return m_liveObjects; }
    /// Imports the module normalize hook refused (refuseModule): every static import and import() (tests).
    uint64_t refusedImports() const { return m_refusedImports; }
    void noteObjectCreated() { m_liveObjects++; }
    void noteObjectFinalized() { m_liveObjects--; }

private:
    explicit Runtime(const Options& options);
    void materialize(uint16_t iface);
    /// The function of member `member` of `iface`, made once and kept: the method, the getter, or (`setter`) the
    /// setter, JS_UNDEFINED when the attribute has none. Borrowed. Throws Thrown.
    JSValueConst memberFunction(uint16_t iface, uint16_t member, bool setter);
    /// Defines member `member` of `iface` on `object` with `flags`: a method as a data property of its function, an
    /// attribute as an accessor of its getter and setter. Throws Thrown.
    void defineMember(JSValueConst object, uint16_t iface, uint16_t member, int flags);
    /// WebIDL "define the iteration methods" for a pair iterator (Sources/Runtime/PairIterators.cpp): entries, keys, values
    /// and forEach on `proto`, @@iterator the same function as entries, and the interface's iterator prototype
    /// ("<name> Iterator", inheriting %IteratorPrototype%, with next). Throws Thrown.
    void definePairIteration(uint16_t iface, JSValueConst proto);
    static JSValue pairIteratorMethod(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv, int magic);
    static JSValue pairForEach(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv, int magic);
    static JSValue pairIteratorNext(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv, int magic);
    static JSValue hostAutoInit(JSContext* ctx, JSValueConst obj, JSAtom prop, void* opaque);
    static JSValue classProtoInit(JSContext* ctx, JSClassID classId);
    static int interrupt(JSRuntime* rt, void* opaque);
    /// QuickJS's hook for an allocation refused at the memory limit (quickjs-ng change 9): latches Memory, unless a stop
    /// is latched already. Whatever the refusal throws (an out-of-memory error, or bare null when QuickJS could not even
    /// build that error) cannot be caught, and a promise propagates it rather than rejecting with it (change 10); the
    /// next interrupt poll, which the refusal makes the very next one, stops the widget. It runs inside the allocator:
    /// no allocation, no script.
    static void memoryLimitRefused(JSRuntime* rt, void* opaque) noexcept;
    /// QuickJS's module normalize hook, with no loader: there is no module loader (M1b), so every specifier of every
    /// import (static, or import()) is refused here, and counted. QuickJS calls it first
    /// (js_host_resolve_imported_module), before it looks the name up among the modules it keeps loaded. That lookup
    /// would find an earlier module script by its URL (fork change 11 charges its walk). Throws QuickJS's own message,
    /// reading at most 200 bytes of the name; allocates only that error, runs no script and opens nothing.
    static char* refuseModule(JSContext* ctx, const char* baseName, const char* name, void* opaque) noexcept;
    /// QuickJS's wall clock (Date). noexcept: an embedder's throw from Host::wallClockNow terminates instead of
    /// crossing into QuickJS.
    static double wallClock(void* opaque) noexcept;
    /// Whether `exception` is QuickJS's out-of-memory error. Reads its own `message` without running script or
    /// allocating. An allocation refused at the limit has latched Memory already (memoryLimitRefused); this is for the
    /// error QuickJS throws without a refusal (the backing allocator's own failure, a native's JS_ThrowOutOfMemory).
    bool isOutOfMemory(JSContext* ctx, JSValueConst exception) const;
    /// The one classification of an exception that reached C++ (every path that latches on one asks it): None when it
    /// can be caught and the runtime runs; otherwise the reason the runtime stops: the one already latched (an
    /// allocation refused at the memory limit latched Memory, whatever it threw), Memory for QuickJS's out of memory,
    /// and for an uncatchable error Budget when the work limit is spent, else Internal. Bare null is never Memory by
    /// itself: a script can throw it. Borrows `exception`.
    StopReason classifyFatal(JSContext* ctx, JSValueConst exception) const;
    /// The cleanup hook, when no call into JS is on the stack, none is running and the runtime has not stopped. A C++
    /// failure inside it latches and becomes Aborted (abortForCaughtException).
    void runCleanupIfOutermost(JSContext* ctx);

    const InterfaceTable* m_table;
    Host* m_host;
    JSRuntime* m_rt = nullptr;
    JSContext* m_ctx = nullptr;
    JSClassID m_firstClassId = 0;
    std::vector<JSValue> m_prototypes;
    std::vector<JSValue> m_interfaceObjects;
    std::vector<JSAtom> m_reflectedAtoms;
    size_t m_materialized = 0;
    JSAtom m_toStringTag = JS_ATOM_NULL;
    JSAtom m_iterator = JS_ATOM_NULL;
    JSAtom m_unscopables = JS_ATOM_NULL;
    JSAtom m_message = JS_ATOM_NULL;
    JSValue m_arrayValues = JS_UNDEFINED;
    JSValue m_arrayKeys = JS_UNDEFINED;
    JSValue m_arrayEntries = JS_UNDEFINED;
    JSValue m_arrayForEach = JS_UNDEFINED;
    std::array<JSValue, size_t(Intrinsic::Count)> m_intrinsics{};
    /// %IteratorPrototype%, taken when the runtime was made; the class of pair iterator objects, and each pair-iterable
    /// interface's iterator prototype (JS_UNDEFINED until materialized).
    JSValue m_iteratorPrototype = JS_UNDEFINED;
    JSClassID m_pairIteratorClass = 0;
    std::vector<JSValue> m_pairIteratorPrototypes;
    std::array<std::unique_ptr<RuntimeExtension>, size_t(ExtensionSlot::Count)> m_extensions;
    size_t m_liveObjects = 0;
    uint64_t m_refusedImports = 0;
    int m_globalInterface = -1;
    std::vector<bool> m_hasUnforgeable;
    /// The index of each interface's first member in m_memberFunctions / 2.
    std::vector<uint32_t> m_memberBase;
    /// Two slots per member (method or getter; setter), JS_UNDEFINED until made.
    std::vector<JSValue> m_memberFunctions;
    std::vector<LazyGlobal> m_lazyGlobals;
    uint64_t m_workLimit = UINT64_MAX;
    uint64_t m_layoutQueryUnits = 0;
    std::function<void(uint64_t)> m_workObserver;
    uint64_t m_workObserverEvery = 0;
    uint64_t m_workObserverLast = 0;
    StopReason m_stopReason = StopReason::None;
    int m_scriptDepth = 0;
    bool m_inCleanup = false;
    friend class NativeFrame;
    int m_nativeDepth = 0;
    bool m_nativeExitWork = false;
};

/// Gives the context's global object a new T payload, which the global then owns: it is finalized with the context.
/// The global is an instance of the table's [Global] interface's class (quickjs-ng change 6). Once per context.
/// Throws Thrown, and std::logic_error when the table has no [Global] interface or the global already has a payload.
template <class T, class... A>
T& createGlobal(JSContext* ctx, A&&... args) {
    Runtime& runtime = Runtime::from(ctx);
    Value global = Value::adopt(ctx, JS_GetGlobalObject(ctx));
    if (runtime.globalInterface() < 0 || runtime.interfaceOf(global.get()) != runtime.globalInterface()) {
        throw std::logic_error("createGlobal: the table has no [Global] interface");
    }
    if (payloadOfKnown(global.get())) {
        throw std::logic_error("createGlobal: the global object already has a payload");
    }
    void* memory = js_malloc(ctx, sizeof(T));
    if (!memory) {
        throw Thrown{};
    }
    T* payload;
    try {
        payload = new (memory) T(std::forward<A>(args)...);
    } catch (...) {
        js_free(ctx, memory);
        throw;
    }
    attachPayload(global.get(), payload);
    runtime.noteObjectCreated();
    return *payload;
}

} // namespace wr
