#include "Tests/TestImpl.h"

#include <cctype>
#include <cstdio>

#include "Sources/Runtime/Runtime.h"

namespace wr::testidl {

wr::Ref<TestSample> TestSample::construct(JSContext* ctx, wr::String label) {
    wr::Ref<TestSample> made = wr::create<TestSample>(ctx, kTestSample);
    made->setLabel(ctx, std::move(label));
    return made;
}

std::optional<wr::String> TestSample::label(JSContext* ctx) {
    if (JS_IsNull(m_label.value)) {
        return std::nullopt;
    }
    return wr::String::adopt(ctx, JS_DupValue(ctx, m_label.value));
}

void TestSample::setLabel(JSContext* ctx, std::optional<wr::String> value) {
    m_label.set(JS_GetRuntime(ctx), value ? value->toJS(ctx) : JS_NULL);
}

wr::String TestSample::text(JSContext* ctx) {
    return m_text.isUndefined() ? wr::String::fromUTF8(ctx, "") : wr::String::adopt(ctx, JS_DupValue(ctx, m_text.value));
}

void TestSample::setText(JSContext* ctx, wr::LegacyNullToEmptyString value) {
    m_text.set(JS_GetRuntime(ctx), value.toJS(ctx));
}

TestBase* TestSample::find(JSContext* ctx, wr::String name, bool deep) {
    std::optional<wr::String> own = this->label(ctx);
    return (own && own->equals(ctx, name)) || deep ? this : nullptr;
}

void TestSample::add(JSContext* ctx, std::vector<std::variant<TestSample*, wr::String>> items) {
    m_count += uint32_t(items.size());
}

wr::String TestSample::primitiveKind(JSContext* ctx, std::variant<wr::String, wr::Unrestricted, bool> value) {
    if (const wr::String* s = std::get_if<wr::String>(&value)) {
        return wr::String::fromUTF8(ctx, "string:" + s->utf8());
    }
    if (const wr::Unrestricted* n = std::get_if<wr::Unrestricted>(&value)) {
        char buffer[32];
        std::snprintf(buffer, sizeof buffer, "number:%g", n->value);
        return wr::String::fromUTF8(ctx, buffer);
    }
    return wr::String::fromUTF8(ctx, std::get<bool>(value) ? "boolean:true" : "boolean:false");
}

wr::String TestSample::describe(JSContext* ctx, std::variant<wr::String, TestOptions> options) {
    std::string label = this->label(ctx).value_or(wr::String()).utf8();
    if (const wr::String* plain = std::get_if<wr::String>(&options)) {
        return wr::String::fromUTF8(ctx, plain->utf8() + ":" + label);
    }
    const TestOptions& o = std::get<TestOptions>(options);
    std::string out = o.prefix.utf8() + label;
    if (o.loud) {
        for (char& c : out) {
            c = char(std::toupper(static_cast<unsigned char>(c)));
        }
    }
    return wr::String::fromUTF8(ctx, out);
}

void TestSample::fail(JSContext* ctx, wr::String name) {
    throw wr::DOMError{"NotFoundError", "no " + name.utf8()};
}

void TestSample::dispose(JSRuntime* rt) {
    m_label.clear(rt);
    m_text.clear(rt);
}

wr::Ref<TestPairs> TestPairs::construct(JSContext* ctx) {
    return wr::create<TestPairs>(ctx, kTestPairs);
}

void TestPairs::append(JSContext*, wr::String key, int32_t value) {
    m_pairs.emplace_back(key.utf8(), value);
}

void TestPairs::removeFirst(JSContext*) {
    if (!m_pairs.empty()) {
        m_pairs.erase(m_pairs.begin());
    }
}

std::pair<wr::String, int32_t> TestPairs::iterationPair(JSContext* ctx, uint32_t index) {
    return {wr::String::fromUTF8(ctx, m_pairs[index].first), m_pairs[index].second};
}

wr::Ref<TestList> TestList::make(JSContext* ctx, uint32_t count) {
    wr::Ref<TestList> list = wr::create<TestList>(ctx, kTestList);
    for (uint32_t i = 0; i < count; i++) {
        wr::Ref<TestSample> sample = TestSample::construct(ctx, wr::String::fromUTF8(ctx, "item" + std::to_string(i)));
        list->m_items.push_back(wr::Held{sample.release()});
    }
    return list;
}

wr::Ref<TestList> TestList::makeInterrupting(JSContext* ctx, uint32_t count) {
    wr::Ref<TestList> list = make(ctx, count);
    list->m_interrupting = true;
    return list;
}

uint32_t TestList::length(JSContext* ctx) {
    if (m_interrupting) {
        // What JS_ThrowInterrupted (quickjs.c) leaves pending when the runtime stops the widget.
        JS_ThrowInternalError(ctx, "interrupted");
        JSValue error = JS_GetException(ctx);
        JS_SetUncatchableError(ctx, error);
        JS_Throw(ctx, error);
        throw wr::Thrown{};
    }
    return uint32_t(m_items.size());
}

TestSample* TestList::item(JSContext* ctx, uint32_t index) {
    return index < m_items.size() ? static_cast<TestSample*>(wr::payloadOfKnown(m_items[index].value)) : nullptr;
}

void TestList::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    for (const wr::Held& item : m_items) {
        item.mark(rt, mark);
    }
}

void TestList::dispose(JSRuntime* rt) {
    for (wr::Held& item : m_items) {
        item.clear(rt);
    }
}

wr::Ref<TestCallbacks> TestCallbacks::construct(JSContext* ctx) {
    return wr::create<TestCallbacks>(ctx, kTestCallbacks);
}

std::optional<wr::Callback> TestCallbacks::stored(JSContext* ctx) {
    if (m_stored.empty()) {
        return std::nullopt;
    }
    return wr::Callback(wr::Value::dup(ctx, m_stored.get()));
}

void TestCallbacks::setStored(JSContext* ctx, std::optional<wr::Callback> value) {
    m_stored.set(JS_GetRuntime(ctx), value ? value->newRef() : JS_UNDEFINED);
}

std::optional<wr::LegacyCallback> TestCallbacks::legacy(JSContext* ctx) {
    if (m_legacy.empty()) {
        return std::nullopt;
    }
    return wr::LegacyCallback(wr::Value::dup(ctx, m_legacy.get()));
}

void TestCallbacks::setLegacy(JSContext* ctx, std::optional<wr::LegacyCallback> value) {
    m_legacy.set(JS_GetRuntime(ctx), value ? value->newRef() : JS_UNDEFINED);
}

bool TestCallbacks::listenerIsFunction(JSContext* ctx) {
    return !m_listener.empty() && JS_IsFunction(ctx, m_listener.get());
}

wr::String TestCallbacks::invoke(JSContext* ctx, wr::Callback callback, wr::String value) {
    // A direct call: the runtime's call helper (charging, the microtask checkpoint) is Task 5's. The fixture only
    // needs to show that the converted value is the function that was passed.
    JSValue arg = value.toJS(ctx);
    JSValue result = JS_Call(ctx, callback.get(), JS_UNDEFINED, 1, &arg);
    JS_FreeValue(ctx, arg);
    wr::Value owned = wr::Value::adopt(ctx, wr::checked(ctx, result));
    return wr::String::fromJS(ctx, owned.get());
}

wr::String TestCallbacks::handlerKind(JSContext* ctx, std::variant<wr::String, wr::Callback> handler) {
    if (std::holds_alternative<wr::Callback>(handler)) {
        return wr::String::fromUTF8(ctx, "function");
    }
    return wr::String::fromUTF8(ctx, "string:" + std::get<wr::String>(handler).utf8());
}

void TestCallbacks::listen(JSContext* ctx, wr::CallbackInterface listener) {
    m_listener.set(JS_GetRuntime(ctx), listener.newRef());
}

wr::Value TestCallbacks::detailOf(JSContext* ctx, TestDetailInit init) {
    return init.detail;
}

void TestCallbacks::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_stored.mark(rt, mark);
    m_legacy.mark(rt, mark);
    m_listener.mark(rt, mark);
}

void TestCallbacks::dispose(JSRuntime* rt) {
    m_stored.clear(rt);
    m_legacy.clear(rt);
    m_listener.clear(rt);
}

static uint32_t s_nextSerial = 1;

TestTarget::TestTarget() : m_serial(s_nextSerial++) {}

wr::Ref<TestTarget> TestTarget::construct(JSContext* ctx) {
    return wr::create<TestTarget>(ctx, kTestTarget);
}

wr::String TestTarget::serial(JSContext* ctx) {
    return wr::String::fromUTF8(ctx, "s" + std::to_string(m_serial));
}

wr::String TestTarget::handlerTypes(JSContext* ctx) {
    std::string out;
    for (const Handler& h : m_handlers) {
        if (h.callback.empty()) {
            continue;
        }
        if (!out.empty()) {
            out += ",";
        }
        out += wr::String::fromAtom(ctx, h.type.atom).utf8();
    }
    return wr::String::fromUTF8(ctx, out);
}

JSValue TestTarget::handler(JSContext* ctx, JSAtom type) {
    for (const Handler& h : m_handlers) {
        if (h.type.atom == type && !h.callback.empty()) {
            return JS_DupValue(ctx, h.callback.get());
        }
    }
    return JS_NULL;
}

void TestTarget::setHandler(JSContext* ctx, JSAtom type, JSValueConst value) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    // [LegacyTreatNonObjectAsNull]: a non-object is null.
    JSValue stored = JS_IsObject(value) ? JS_DupValue(ctx, value) : JS_UNDEFINED;
    for (Handler& h : m_handlers) {
        if (h.type.atom == type) {
            h.callback.set(rt, stored);
            return;
        }
    }
    Handler h;
    h.type.set(rt, JS_DupAtom(ctx, type));
    h.callback.set(rt, stored);
    m_handlers.push_back(std::move(h));
}

void TestTarget::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    for (const Handler& h : m_handlers) {
        h.callback.mark(rt, mark);
    }
}

void TestTarget::dispose(JSRuntime* rt) {
    for (Handler& h : m_handlers) {
        h.callback.clear(rt);
        h.type.clear(rt);
    }
}

static JSValue makeList(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    return wr::glue(ctx, [&]() -> JSValue {
        uint32_t n = argc > 0 ? wr::convert<uint32_t>(ctx, argv[0], wr::ArgInfo{"globalThis", "makeList", 0}) : 0;
        return wr::toJS(ctx, TestList::make(ctx, n));
    });
}

static JSValue makeInterruptingList(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    return wr::glue(ctx, [&]() -> JSValue {
        uint32_t n = argc > 0 ? wr::convert<uint32_t>(ctx, argv[0], wr::ArgInfo{"globalThis", "makeInterruptingList", 0}) : 0;
        return wr::toJS(ctx, TestList::makeInterrupting(ctx, n));
    });
}

void installTestGlobals(JSContext* ctx) {
    wr::Runtime::from(ctx).setGlobal("makeList", JS_NewCFunction(ctx, makeList, "makeList", 1));
    wr::Runtime::from(ctx).setGlobal("makeInterruptingList", JS_NewCFunction(ctx, makeInterruptingList, "makeInterruptingList", 1));
}

void installTestGlobal(JSContext* ctx) {
    wr::createGlobal<TestGlobal>(ctx);
    wr::Runtime::from(ctx).installGlobalMembers(kTestGlobal);
}

} // namespace wr::testidl

namespace wr {

JSValue getEventHandler(JSContext* ctx, testidl::TestTarget& target, JSAtom type) {
    return target.handler(ctx, type);
}

void setEventHandler(JSContext* ctx, testidl::TestTarget& target, JSAtom type, JSValueConst value) {
    target.setHandler(ctx, type, value);
}

} // namespace wr
