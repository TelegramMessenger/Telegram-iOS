// The test IDL's implementations (Tests/IDL/test.webidl).
#pragma once

#include <optional>
#include <string>
#include <variant>
#include <vector>

#include "Generated/TestBindings.h"

namespace wr::testidl {

class TestBase : public wr::PlatformObject {
public:
    wr::String baseName(JSContext* ctx) { return wr::String::fromUTF8(ctx, "base"); }
};

class TestSample : public TestBase {
public:
    static wr::Ref<TestSample> construct(JSContext* ctx, wr::String label);
    uint32_t count(JSContext*) { return m_count; }
    std::optional<wr::String> label(JSContext* ctx);
    void setLabel(JSContext* ctx, std::optional<wr::String> value);
    wr::String text(JSContext* ctx);
    void setText(JSContext* ctx, wr::LegacyNullToEmptyString value);
    TestBase* find(JSContext* ctx, wr::String name, bool deep);
    void add(JSContext* ctx, std::vector<std::variant<TestSample*, wr::String>> items);
    wr::String describe(JSContext* ctx, std::variant<wr::String, TestOptions> options);
    void fail(JSContext* ctx, wr::String name);
    /// Which alternative of (DOMString or unrestricted double or boolean) the value converted to, and its value.
    wr::String primitiveKind(JSContext* ctx, std::variant<wr::String, wr::Unrestricted, bool> value);
    static double half(JSContext* ctx, wr::Unrestricted x) { return x.value / 2.0; }
    void dispose(JSRuntime* rt) override;

private:
    uint32_t m_count = 0;
    wr::Held m_label{JS_NULL};
    wr::Held m_text;
};

class TestList : public wr::PlatformObject {
public:
    static wr::Ref<TestList> make(JSContext* ctx, uint32_t count);
    /// A list whose length stops the widget as a stop does: an uncatchable "interrupted" error.
    static wr::Ref<TestList> makeInterrupting(JSContext* ctx, uint32_t count);
    uint32_t length(JSContext* ctx);
    TestSample* item(JSContext* ctx, uint32_t index);
    JSValue indexedValue(JSContext* ctx, uint32_t index) { return JS_DupValue(ctx, m_items[index].value); }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    std::vector<wr::Held> m_items;
    bool m_interrupting = false;
};

class TestPairs : public wr::PlatformObject {
public:
    static wr::Ref<TestPairs> construct(JSContext* ctx);
    void append(JSContext* ctx, wr::String key, int32_t value);
    void removeFirst(JSContext*);
    uint32_t iterationLength(JSContext*) const { return uint32_t(m_pairs.size()); }
    std::pair<wr::String, int32_t> iterationPair(JSContext* ctx, uint32_t index);

private:
    std::vector<std::pair<std::string, int32_t>> m_pairs;
};

class TestCallbacks : public wr::PlatformObject {
public:
    static wr::Ref<TestCallbacks> construct(JSContext* ctx);
    std::optional<wr::Callback> stored(JSContext* ctx);
    void setStored(JSContext* ctx, std::optional<wr::Callback> value);
    std::optional<wr::LegacyCallback> legacy(JSContext* ctx);
    void setLegacy(JSContext* ctx, std::optional<wr::LegacyCallback> value);
    bool listenerIsFunction(JSContext* ctx);
    wr::String invoke(JSContext* ctx, wr::Callback callback, wr::String value);
    wr::String handlerKind(JSContext* ctx, std::variant<wr::String, wr::Callback> handler);
    void listen(JSContext* ctx, wr::CallbackInterface listener);
    wr::Value detailOf(JSContext* ctx, TestDetailInit init);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    wr::HeldCallback m_stored;
    wr::HeldCallback m_legacy;
    wr::HeldCallback m_listener;
};

class TestTarget : public wr::PlatformObject {
public:
    TestTarget();
    static wr::Ref<TestTarget> construct(JSContext* ctx);
    wr::String serial(JSContext* ctx);
    wr::String stamp(JSContext* ctx) { return wr::String::fromUTF8(ctx, "stamped"); }
    wr::String handlerTypes(JSContext* ctx);
    /// The fixture's event handler storage (Task 12 makes the real one): [LegacyTreatNonObjectAsNull], by type.
    JSValue handler(JSContext* ctx, JSAtom type);
    void setHandler(JSContext* ctx, JSAtom type, JSValueConst value);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    struct Handler {
        wr::HeldAtom type;
        wr::HeldCallback callback;
    };
    std::vector<Handler> m_handlers;
    uint32_t m_serial;
};

class TestGlobal : public TestTarget {
public:
    ~TestGlobal() override { s_destroyed++; }
    TestGlobal* window(JSContext*) { return this; }
    TestGlobal* self(JSContext*) { return this; }
    uint32_t ticks(JSContext*) { return m_ticks; }
    uint32_t tick(JSContext*) { return ++m_ticks; }
    static int destroyed() { return s_destroyed; }

private:
    uint32_t m_ticks = 0;
    static inline int s_destroyed = 0;
};

class TestHidden : public wr::PlatformObject {};

/// Defines `makeList(n)` and `makeInterruptingList(n)` on the global.
void installTestGlobals(JSContext* ctx);
/// Makes the global a TestGlobal (wr::createGlobal) and installs its members (Runtime::installGlobalMembers).
void installTestGlobal(JSContext* ctx);

} // namespace wr::testidl

// The event handler hooks generated glue calls for the fixture's TestTarget (Task 12 declares the EventTarget& ones).
namespace wr {
JSValue getEventHandler(JSContext* ctx, testidl::TestTarget& target, JSAtom type);
void setEventHandler(JSContext* ctx, testidl::TestTarget& target, JSAtom type, JSValueConst value);
} // namespace wr
