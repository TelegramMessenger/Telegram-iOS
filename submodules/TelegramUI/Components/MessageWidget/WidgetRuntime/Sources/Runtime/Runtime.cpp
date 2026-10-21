#include "Sources/Runtime/Runtime.h"

#include <cstring>
#include <optional>
#include <stdexcept>

#include "Sources/Support/Callbacks.h"

namespace wr {

JSClassID classIdFor(JSContext* ctx, uint16_t iface) {
    return Runtime::from(ctx).classId(iface);
}

void noteCreated(JSContext* ctx) {
    Runtime::from(ctx).noteObjectCreated();
}

namespace {

/// The host of a runtime made without one: its clocks read zero, it logs nothing, and it refuses every script source.
class RefusingHost final : public Host {
public:
    std::string defaultTimeZone() override { return "UTC"; }
    double monotonicNow() override { return 0; }
    double wallClockNow() override { return 0; }
    void log(LogLevel, std::string_view) override {}
    void diagnostic(std::string_view, std::string_view) override {}
};

RefusingHost g_refusingHost;

} // namespace

void RuntimeExtension::reportException(JSContext* ctx, JSValue exception) {
    Runtime::from(ctx).logUncaughtException(ctx, exception);
}

NativeFrame::NativeFrame(JSContext* ctx) : m_ctx(ctx) {
    Runtime::from(ctx).m_nativeDepth++;
}

NativeFrame::~NativeFrame() {
    if (!m_left) {
        Runtime::from(m_ctx).m_nativeDepth--;
    }
}

void NativeFrame::leave() {
    Runtime& runtime = Runtime::from(m_ctx);
    m_left = true;
    if (--runtime.m_nativeDepth > 0 || !runtime.m_nativeExitWork) {
        return;
    }
    runtime.m_nativeExitWork = false;
    if (runtime.stopReason() != StopReason::None) {
        return;
    }
    if (RuntimeExtension* host = runtime.extension(ExtensionSlot::Host)) {
        host->afterOutermostNative(m_ctx);
    }
}

void defineInstanceMembers(JSContext* ctx, JSValueConst object, uint16_t iface) {
    Runtime& runtime = Runtime::from(ctx);
    if (runtime.hasUnforgeableMembers(iface)) {
        runtime.defineUnforgeableMembers(object, iface);
    }
}

Runtime::Runtime(const Options& options) : m_table(options.interfaces), m_host(options.host ? options.host : &g_refusingHost) {}

std::unique_ptr<Runtime> Runtime::create(const Options& options) {
    if (!options.interfaces) {
        throw std::invalid_argument("Runtime needs an interface table");
    }
    std::unique_ptr<Runtime> r(new Runtime(options));
    r->m_rt = JS_NewRuntime();
    if (!r->m_rt) {
        throw std::bad_alloc();
    }
    JS_SetRuntimeOpaque(r->m_rt, r.get());
    JS_SetMemoryLimit(r->m_rt, options.memoryLimitBytes);
    // An allocation refused at that limit latches the stop (quickjs-ng change 9).
    JS_SetMemoryLimitFunc(r->m_rt, &Runtime::memoryLimitRefused, r.get());
    JS_SetMaxStackSize(r->m_rt, options.maxStackBytes);
    JS_SetHostAutoInitFunc(r->m_rt, &Runtime::hostAutoInit);
    JS_SetClassProtoInitFunc(r->m_rt, &Runtime::classProtoInit);
    // The work limit and the latch: every interrupt poll and every native charge asks (quickjs-ng changes 1 and 2).
    JS_SetInterruptHandler(r->m_rt, &Runtime::interrupt, r.get());
    // Date.now() and new Date() read the host's wall clock (quickjs-ng change 7).
    JS_SetWallClockFunc(r->m_rt, &Runtime::wallClock, r.get());
    // No module loader: every import fails, before QuickJS's lookup among the loaded modules (refuseModule).
    JS_SetModuleLoaderFunc(r->m_rt, &Runtime::refuseModule, nullptr, r.get());

    const InterfaceTable& table = *r->m_table;
    for (uint16_t i = 0; i < table.count; i++) {
        JSClassID id = 0;
        JS_NewClassID(r->m_rt, &id);
        if (i == 0) {
            r->m_firstClassId = id;
        } else if (id != r->m_firstClassId + i) {
            throw std::logic_error("class ids are not contiguous");
        }
        JSClassDef def{};
        def.class_name = table.interfaces[i].name;
        def.finalizer = &finalizePlatformObject;
        def.gc_mark = &tracePlatformObject;
        def.exotic = const_cast<JSClassExoticMethods*>(table.interfaces[i].exotic);
        if (JS_NewClass(r->m_rt, id, &def) < 0) {
            throw std::bad_alloc();
        }
    }
    r->m_prototypes.assign(table.count, JS_UNDEFINED);
    r->m_interfaceObjects.assign(table.count, JS_UNDEFINED);
    r->m_pairIteratorPrototypes.assign(table.count, JS_UNDEFINED);
    registerPairIteratorClass(r->m_rt, r->m_pairIteratorClass);

    if (table.count >= 0x8000) {
        throw std::logic_error("too many interfaces");
    }
    // WebIDL [Global] (quickjs-ng change 6): the global object is an instance of that interface's class, so it can
    // carry the payload (createGlobal) and pass brand checks. It must be set before the context exists.
    uint32_t memberTotal = 0;
    r->m_hasUnforgeable.assign(table.count, false);
    for (uint16_t i = 0; i < table.count; i++) {
        const InterfaceInfo& info = table.interfaces[i];
        if (info.isGlobal) {
            if (r->m_globalInterface >= 0) {
                throw std::logic_error("the table has two [Global] interfaces");
            }
            r->m_globalInterface = i;
        }
        r->m_memberBase.push_back(memberTotal);
        memberTotal += info.memberCount;
        bool own = false;
        for (uint16_t m = 0; m < info.memberCount; m++) {
            own = own || info.members[m].unforgeable;
        }
        // Parents come first in the table (the generator orders them so), so a parent's answer is already known.
        if (info.parent >= int(i)) {
            throw std::logic_error("an interface comes before its parent in the table");
        }
        r->m_hasUnforgeable[i] = own || (info.parent >= 0 && r->m_hasUnforgeable[info.parent]);
    }
    r->m_memberFunctions.assign(size_t(memberTotal) * 2, JS_UNDEFINED);
    if (r->m_globalInterface >= 0) {
        JS_SetGlobalObjectClass(r->m_rt, r->classId(uint16_t(r->m_globalInterface)));
    }

    r->m_ctx = JS_NewContext(r->m_rt);
    if (!r->m_ctx) {
        throw std::bad_alloc();
    }
    JS_SetContextOpaque(r->m_ctx, r.get());
    JSContext* ctx = r->m_ctx;
    JS_SetRandomSeed(ctx, options.randomSeed);
    r->m_message = JS_NewAtom(ctx, "message");

    Value global = Value::adopt(ctx, JS_GetGlobalObject(ctx));
    {
        Value symbol = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, global.get(), "Symbol")));
        auto wellKnown = [&](const char* name) {
            Value s = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, symbol.get(), name)));
            return JS_ValueToAtom(ctx, s.get());
        };
        r->m_toStringTag = wellKnown("toStringTag");
        r->m_iterator = wellKnown("iterator");
        r->m_unscopables = wellKnown("unscopables");
        Value array = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, global.get(), "Array")));
        Value arrayProto = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, array.get(), "prototype")));
        r->m_arrayValues = checked(ctx, JS_GetPropertyStr(ctx, arrayProto.get(), "values"));
        r->m_arrayKeys = checked(ctx, JS_GetPropertyStr(ctx, arrayProto.get(), "keys"));
        r->m_arrayEntries = checked(ctx, JS_GetPropertyStr(ctx, arrayProto.get(), "entries"));
        r->m_arrayForEach = checked(ctx, JS_GetPropertyStr(ctx, arrayProto.get(), "forEach"));
        // %IteratorPrototype%: the prototype of %ArrayIteratorPrototype%.
        Value empty = Value::adopt(ctx, checked(ctx, JS_NewArray(ctx)));
        Value arrayIterator = Value::adopt(ctx, checked(ctx, JS_Call(ctx, r->m_arrayValues, empty.get(), 0, nullptr)));
        Value arrayIteratorProto = Value::adopt(ctx, checked(ctx, JS_GetPrototype(ctx, arrayIterator.get())));
        r->m_iteratorPrototype = checked(ctx, JS_GetPrototype(ctx, arrayIteratorProto.get()));

        using I = Intrinsic;
        r->m_intrinsics.fill(JS_UNDEFINED);
        auto prototypeOf = [&](const char* name, I constructor) {
            Value c = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, global.get(), name)));
            if (constructor != I::Count) {
                r->m_intrinsics[size_t(constructor)] = JS_DupValue(ctx, c.get());
            }
            return Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, c.get(), "prototype")));
        };
        auto take = [&](I which, JSValueConst object, const char* name) {
            r->m_intrinsics[size_t(which)] = checked(ctx, JS_GetPropertyStr(ctx, object, name));
        };
        auto takeGetter = [&](I which, JSValueConst proto, const char* name) {
            JSAtom atom = JS_NewAtom(ctx, name);
            JSPropertyDescriptor descriptor;
            const int own = JS_GetOwnProperty(ctx, &descriptor, proto, atom);
            JS_FreeAtom(ctx, atom);
            check(ctx, own);
            if (!own) {
                throw std::logic_error(std::string("the engine has no accessor DataView.prototype.") + name);
            }
            JS_FreeValue(ctx, descriptor.value);
            JS_FreeValue(ctx, descriptor.setter);
            r->m_intrinsics[size_t(which)] = descriptor.getter;
        };
        Value dataViewProto = prototypeOf("DataView", I::Count);
        takeGetter(I::DataViewBuffer, dataViewProto.get(), "buffer");
        takeGetter(I::DataViewByteOffset, dataViewProto.get(), "byteOffset");
        takeGetter(I::DataViewByteLength, dataViewProto.get(), "byteLength");
        // A collection's iterator `next`: the prototype of an iterator made from an empty one.
        auto takeIteratorNext = [&](I which, I constructor, I method) {
            JSValueConst undefined = JS_UNDEFINED;
            Value empty = Value::adopt(ctx, checked(ctx, JS_CallConstructor(ctx, r->m_intrinsics[size_t(constructor)], 1, &undefined)));
            Value iterator = Value::adopt(ctx, checked(ctx, JS_Call(ctx, r->m_intrinsics[size_t(method)], empty.get(), 0, nullptr)));
            Value iteratorProto = Value::adopt(ctx, checked(ctx, JS_GetPrototype(ctx, iterator.get())));
            take(which, iteratorProto.get(), "next");
        };
        Value mapProto = prototypeOf("Map", I::MapConstructor);
        take(I::MapEntries, mapProto.get(), "entries");
        take(I::MapSet, mapProto.get(), "set");
        takeIteratorNext(I::MapIteratorNext, I::MapConstructor, I::MapEntries);
        Value setProto = prototypeOf("Set", I::SetConstructor);
        take(I::SetValues, setProto.get(), "values");
        take(I::SetAdd, setProto.get(), "add");
        takeIteratorNext(I::SetIteratorNext, I::SetConstructor, I::SetValues);
        take(I::NumberValueOf, prototypeOf("Number", I::Count).get(), "valueOf");
        take(I::BigIntValueOf, prototypeOf("BigInt", I::Count).get(), "valueOf");
        take(I::DateGetTime, prototypeOf("Date", I::Count).get(), "getTime");
    }
    for (uint16_t i = 0; i < table.reflectedCount; i++) {
        r->m_reflectedAtoms.push_back(JS_NewAtom(ctx, table.reflectedNames[i]));
    }
    // One auto-init entry per exposed interface (quickjs-ng change 3): nothing is built until a script uses it.
    for (uint16_t i = 0; i < table.count; i++) {
        if (!table.interfaces[i].exposed) {
            continue;
        }
        JSAtom name = JS_NewAtom(ctx, table.interfaces[i].name);
        int status = JS_DefineHostAutoInitProperty(ctx, global.get(), name, reinterpret_cast<void*>(uintptr_t(i) + 1), JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE);
        JS_FreeAtom(ctx, name);
        check(ctx, status);
    }
    return r;
}

Runtime::~Runtime() {
    if (m_ctx) {
        // The host layer's state may refer to the DOM's, never the other way round.
        m_extensions[size_t(ExtensionSlot::Host)].reset();
        m_extensions[size_t(ExtensionSlot::DOM)].reset();
        for (JSValue& v : m_prototypes) {
            JS_FreeValue(m_ctx, v);
        }
        for (JSValue& v : m_interfaceObjects) {
            JS_FreeValue(m_ctx, v);
        }
        for (JSValue& v : m_pairIteratorPrototypes) {
            JS_FreeValue(m_ctx, v);
        }
        JS_FreeValue(m_ctx, m_iteratorPrototype);
        for (JSValue& v : m_memberFunctions) {
            JS_FreeValue(m_ctx, v);
        }
        for (JSAtom a : m_reflectedAtoms) {
            JS_FreeAtom(m_ctx, a);
        }
        JS_FreeAtom(m_ctx, m_toStringTag);
        JS_FreeAtom(m_ctx, m_iterator);
        JS_FreeAtom(m_ctx, m_unscopables);
        JS_FreeAtom(m_ctx, m_message);
        JS_FreeValue(m_ctx, m_arrayValues);
        JS_FreeValue(m_ctx, m_arrayKeys);
        JS_FreeValue(m_ctx, m_arrayEntries);
        JS_FreeValue(m_ctx, m_arrayForEach);
        for (JSValue& v : m_intrinsics) {
            JS_FreeValue(m_ctx, v);
        }
        JS_FreeContext(m_ctx);
    }
    if (m_rt) {
        JS_RunGC(m_rt);
        JS_FreeRuntime(m_rt);
    }
}

int Runtime::interfaceOf(JSValueConst v) const {
    JSClassID id = JS_GetClassID(v);
    if (id == JS_INVALID_CLASS_ID || id < m_firstClassId || id >= m_firstClassId + m_table->count) {
        return -1;
    }
    return int(id - m_firstClassId);
}

bool Runtime::implementsInterface(int index, uint16_t iface) const {
    for (int i = index; i >= 0; i = m_table->interfaces[i].parent) {
        if (i == iface) {
            return true;
        }
    }
    return false;
}

JSValueConst Runtime::interfaceObject(uint16_t iface) {
    this->materialize(iface);
    return m_interfaceObjects[iface];
}

JSValueConst Runtime::prototype(uint16_t iface) {
    this->materialize(iface);
    return m_prototypes[iface];
}

void Runtime::setGlobal(const char* name, JSValue value) {
    Value global = Value::adopt(m_ctx, JS_GetGlobalObject(m_ctx));
    check(m_ctx, JS_DefinePropertyValueStr(m_ctx, global.get(), name, value, JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
}

void Runtime::setFixedGlobal(const char* name, JSValue value) {
    Value global = Value::adopt(m_ctx, JS_GetGlobalObject(m_ctx));
    check(m_ctx, JS_DefinePropertyValueStr(m_ctx, global.get(), name, value, 0));
}

std::string Runtime::evaluateToString(std::string_view code, const char* filename, bool* threw) {
    // A call into JS like the others (Ruling 6): the test's script starts at native depth 0.
    ScriptBoundary boundary(*this);
    if (m_stopReason != StopReason::None) {
        // A latched runtime evaluates nothing. It answers the text an uncatchable error that latched nothing converts
        // to below; a stop inside the script throws Aborted instead.
        *threw = true;
        return "InternalError: interrupted";
    }
    std::string source(code);
    m_scriptDepth++;
    JSValue result = JS_Eval(m_ctx, source.c_str(), source.size(), filename, JS_EVAL_TYPE_GLOBAL);
    m_scriptDepth--;
    *threw = JS_IsException(result);
    if (*threw) {
        result = JS_GetException(m_ctx);
    }
    if (m_stopReason != StopReason::None) {
        // The call latched the runtime: Aborted, as from every call into JS. Checked before converting, which would
        // run script on a stopped runtime.
        JS_FreeValue(m_ctx, result);
        throw Aborted{};
    }
    const char* text = JS_ToCString(m_ctx, result);
    std::string out = text ? text : "<unprintable>";
    if (!text) {
        JS_FreeValue(m_ctx, JS_GetException(m_ctx));
    }
    JS_FreeCString(m_ctx, text);
    JS_FreeValue(m_ctx, result);
    // The conversion runs a toString, which the budget can stop too.
    this->throwIfStopped();
    // An Aborted from the cleanup hook (the checkpoint stopped the widget) propagates: HostEnv::eval reads it.
    this->runCleanupIfOutermost(m_ctx);
    return out;
}

void Runtime::defineLazyGlobal(const char* name, LazyGlobal make) {
    m_lazyGlobals.push_back(make);
    Value global = Value::adopt(m_ctx, JS_GetGlobalObject(m_ctx));
    JSAtom atom = JS_NewAtom(m_ctx, name);
    const int status = JS_DefineHostAutoInitProperty(m_ctx, global.get(), atom,
                                                     reinterpret_cast<void*>(kLazyGlobalTag | (m_lazyGlobals.size() - 1)),
                                                     JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE);
    JS_FreeAtom(m_ctx, atom);
    check(m_ctx, status);
}

JSValue Runtime::hostAutoInit(JSContext* ctx, JSValueConst obj, JSAtom prop, void* opaque) {
    Runtime& runtime = from(ctx);
    uintptr_t code = reinterpret_cast<uintptr_t>(opaque);
    try {
        if (code & kLazyGlobalTag) {
            return runtime.m_lazyGlobals.at(size_t(code & ~kLazyGlobalTag))(ctx);
        }
        if (code & kGlobalMemberTag) {
            // A [Global] interface's operation (installGlobalMembers): its shared function.
            uint16_t iface = uint16_t((code >> 16) & 0x7FFF);
            uint16_t member = uint16_t(code & 0xFFFF);
            return JS_DupValue(ctx, runtime.memberFunction(iface, member, false));
        }
        uint16_t iface = uint16_t(code - 1);
        runtime.materialize(iface);
        return JS_DupValue(ctx, runtime.m_interfaceObjects[iface]);
    } catch (...) {
        return rethrowAsJS(ctx);
    }
}

JSValue Runtime::classProtoInit(JSContext* ctx, JSClassID classId) {
    Runtime& runtime = from(ctx);
    if (classId < runtime.m_firstClassId || classId >= runtime.m_firstClassId + runtime.m_table->count) {
        return JS_NULL;
    }
    uint16_t iface = uint16_t(classId - runtime.m_firstClassId);
    try {
        runtime.materialize(iface);
    } catch (...) {
        return rethrowAsJS(ctx);
    }
    return JS_DupValue(ctx, runtime.m_prototypes[iface]);
}

void Runtime::setWorkObserver(std::function<void(uint64_t total)> observer, uint64_t everyUnits) {
    m_workObserver = std::move(observer);
    m_workObserverEvery = everyUnits;
    m_workObserverLast = JS_GetWorkUnits(m_rt);
}

int Runtime::interrupt(JSRuntime* rt, void* opaque) {
    auto* runtime = static_cast<Runtime*>(opaque);
    if (runtime->m_stopReason != StopReason::None) {
        return 1;
    }
    if (runtime->m_workObserver) {
        const uint64_t units = JS_GetWorkUnits(rt);
        if (units - runtime->m_workObserverLast >= runtime->m_workObserverEvery) {
            runtime->m_workObserverLast = units;
            try {
                runtime->m_workObserver(units);
            } catch (...) {
            }
        }
    }
    if (JS_GetWorkUnits(rt) >= runtime->m_workLimit) {
        runtime->stop(StopReason::Budget);
        return 1;
    }
    return 0;
}

char* Runtime::refuseModule(JSContext* ctx, const char* baseName, const char* name, void* opaque) noexcept {
    static_cast<Runtime*>(opaque)->m_refusedImports++;
    JS_ThrowReferenceError(ctx, "could not load module '%.200s'", name);
    return nullptr;
}

void Runtime::memoryLimitRefused(JSRuntime* rt, void* opaque) noexcept {
    static_cast<Runtime*>(opaque)->stop(StopReason::Memory);
}

double Runtime::wallClock(void* opaque) noexcept {
    return static_cast<Runtime*>(opaque)->host().wallClockNow();
}

void Runtime::throwIfStopped() const {
    if (m_stopReason != StopReason::None) {
        throw Aborted{};
    }
}

bool Runtime::isOutOfMemory(JSContext* ctx, JSValueConst exception) const {
    if (!JS_IsError(exception)) {
        return false;
    }
    JSPropertyDescriptor desc;
    int has = JS_GetOwnProperty(ctx, &desc, exception, m_message);
    if (has < 0) {
        // Even reading its own property failed: memory is gone.
        JS_FreeValue(ctx, JS_GetException(ctx));
        return true;
    }
    if (has == 0) {
        return false;
    }
    bool outOfMemory = false;
    JSStringView view{nullptr, nullptr, 0};
    static const char kText[] = "out of memory";
    if (!(desc.flags & JS_PROP_GETSET) && JS_IsString(desc.value) && JS_GetStringView(desc.value, &view) && view.latin1 &&
        view.length == sizeof(kText) - 1) {
        outOfMemory = std::memcmp(view.latin1, kText, sizeof(kText) - 1) == 0;
    }
    JS_FreeValue(ctx, desc.value);
    JS_FreeValue(ctx, desc.getter);
    JS_FreeValue(ctx, desc.setter);
    return outOfMemory;
}

StopReason Runtime::classifyFatal(JSContext* ctx, JSValueConst exception) const {
    if (m_stopReason != StopReason::None) {
        return m_stopReason;
    }
    if (this->isOutOfMemory(ctx, exception)) {
        return StopReason::Memory;
    }
    if (!JS_IsUncatchableError(exception)) {
        return StopReason::None;
    }
    // The budget's interrupt has normally latched Budget already; an uncatchable error with work left is ours.
    return JS_GetWorkUnits(m_rt) >= m_workLimit ? StopReason::Budget : StopReason::Internal;
}

void Runtime::throwIfFatal(JSContext* ctx, JSValueConst exception) {
    StopReason reason = this->classifyFatal(ctx, exception);
    if (reason != StopReason::None) {
        this->stop(reason);
        throw Aborted{};
    }
}

void Runtime::abortWithPendingException(JSContext* ctx) {
    Value exception = Value::adopt(ctx, JS_GetException(ctx));
    StopReason reason = this->classifyFatal(ctx, exception.get());
    // A stop comes here (a failed charge: the interrupt latched Budget), and so does a Thrown that
    // abortForCaughtException caught on a path that may only abort. A catchable exception there is a failure of our
    // own: Internal.
    this->stop(reason == StopReason::None ? StopReason::Internal : reason);
    throw Aborted{};
}

void Runtime::abortForCaughtException(JSContext* ctx) {
    try {
        throw;
    } catch (const Aborted&) {
        throw;
    } catch (const Thrown&) {
        this->abortWithPendingException(ctx);
    } catch (const std::bad_alloc&) {
        this->stop(StopReason::Memory);
    } catch (...) {
        this->stop(StopReason::Internal);
    }
    throw Aborted{};
}

void Runtime::runCleanupIfOutermost(JSContext* ctx) {
    if (m_scriptDepth != 0 || m_inCleanup || m_stopReason != StopReason::None) {
        return;
    }
    RuntimeExtension* host = this->extension(ExtensionSlot::Host);
    if (!host) {
        return;
    }
    m_inCleanup = true;
    struct Reset {
        bool& flag;
        ~Reset() { flag = false; }
    } reset{m_inCleanup};
    try {
        host->afterOutermostScript(ctx);
    } catch (...) {
        this->abortForCaughtException(ctx);
    }
}

CallResult Runtime::leaveScript(JSContext* ctx, JSValue result) {
    m_scriptDepth--;
    if (JS_IsException(result)) {
        // Owned from here: an Aborted from the fatal check or the cleanup releases it on the way out.
        Value thrown = Value::adopt(ctx, JS_GetException(ctx));
        this->throwIfFatal(ctx, thrown.get());
        this->runCleanupIfOutermost(ctx);
        return CallResult{CallStatus::Threw, std::move(thrown)};
    }
    Value value = Value::adopt(ctx, result);
    // A call can return normally on a runtime it stopped: QuickJS turns some exceptions, the stop's included, into a
    // promise rejection (Promise.try; quickjs-ng change 8 fixed only the executor, VENDOR.md).
    this->throwIfStopped();
    this->runCleanupIfOutermost(ctx);
    return CallResult{CallStatus::Returned, std::move(value)};
}

bool Runtime::runScript(std::string_view source, const char* filename, bool isModule) {
    JSContext* ctx = m_ctx;
    // Ruling 6: the script starts at native depth 0, so its binding calls are outermost again.
    ScriptBoundary boundary(*this);
    this->throwIfStopped();
    try {
        charge(ctx, work::kBindingCall);
        chargeScan(ctx, source.size());
    } catch (const Thrown&) {
        this->abortWithPendingException(ctx);
    }
    std::string text;
    try {
        text.assign(source);
    } catch (...) {
        this->abortForCaughtException(ctx);
    }
    m_scriptDepth++;
    JSValue result = JS_Eval(ctx, text.c_str(), text.size(), filename, isModule ? JS_EVAL_TYPE_MODULE : JS_EVAL_TYPE_GLOBAL);
    bool completed = true;
    if (JS_IsException(result)) {
        // HTML "run a classic script": the exception is reported while the script is still on the stack (listeners the
        // report runs are nested), and only then cleaned up. A fatal one aborts instead, and so does a C++ failure in
        // the report.
        try {
            Value exception = Value::adopt(ctx, JS_GetException(ctx));
            this->throwIfFatal(ctx, exception.get());
            this->reportException(ctx, exception.release());
        } catch (...) {
            m_scriptDepth--;
            this->abortForCaughtException(ctx);
        }
        completed = false;
    } else if (isModule && JS_IsPromise(result) && JS_PromiseState(ctx, result) == JS_PROMISE_REJECTED) {
        // HTML "run a module script": a throw in the module's body rejected its evaluation promise. The promise is
        // handled first (the rejection tracker drops it from its about-to-be-notified list: no allocation, no script),
        // then its reason goes the exception's way: the fatal check, then the report.
        try {
            Value promise = Value::adopt(ctx, result);
            JS_PromiseMarkAsHandled(ctx, promise.get());
            Value reason = Value::adopt(ctx, JS_PromiseResult(ctx, promise.get()));
            this->throwIfFatal(ctx, reason.get());
            this->reportException(ctx, reason.release());
        } catch (...) {
            m_scriptDepth--;
            this->abortForCaughtException(ctx);
        }
        completed = false;
    } else {
        // A classic script's completion value, or a module's fulfilled (or still pending) evaluation promise: a
        // pending one that rejects later is an ordinary promise rejection, which Task 9 tracks (unhandledrejection, not
        // HTML's report).
        JS_FreeValue(ctx, result);
    }
    m_scriptDepth--;
    // A script can complete on a runtime it stopped: QuickJS turns some exceptions, the stop's included, into a
    // promise rejection (Promise.try, VENDOR.md entry 8; a module's evaluation, in entry 10's list of what it leaves
    // alone).
    this->throwIfStopped();
    this->runCleanupIfOutermost(ctx);
    return completed;
}

void Runtime::reportException(JSContext* ctx, JSValue exception) {
    if (RuntimeExtension* host = this->extension(ExtensionSlot::Host)) {
        host->reportException(ctx, exception);
    } else {
        this->logUncaughtException(ctx, exception);
    }
}

void Runtime::logUncaughtException(JSContext* ctx, JSValue exception) {
    Value owned = Value::adopt(ctx, exception);
    // ToString can run a script's own toString: at a safe point, counted as script (ConversionScope: no cleanup runs
    // inside it), and a stop it hits still stops the widget. Only the diagnostic's 4,000 bytes are converted to UTF-8.
    std::optional<String> text;
    try {
        JSStringView view{nullptr, nullptr, 0};
        if (JS_IsString(owned.get()) && !JS_GetStringView(owned.get(), &view)) {
            // A thrown rope: JS_ToString flattens it, a copy of all of it that QuickJS would notice only at its next
            // poll, so it is charged first. (A rope an object's toString returns is flattened inside JS_ToString, as in
            // every conversion: QuickJS counts that allocation itself.)
            chargeScan(ctx, JS_GetStringLength(owned.get()));
        }
        ConversionScope conversion(*this);
        text = String::adopt(ctx, checked(ctx, JS_ToString(ctx, owned.get())));
    } catch (const Thrown&) {
        Value failure = Value::adopt(ctx, JS_GetException(ctx));
        this->throwIfFatal(ctx, failure.get());
    }
    if (!text) {
        m_host->log(LogLevel::Error, "Uncaught exception");
        return;
    }
    m_host->log(LogLevel::Error, "Uncaught " + text->utf8Prefix(kMaxDiagnosticBytes, nullptr));
}

} // namespace wr
