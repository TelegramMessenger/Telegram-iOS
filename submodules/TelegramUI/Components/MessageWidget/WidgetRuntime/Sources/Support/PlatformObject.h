// The payload behind every DOM object. The object owns its payload (allocated through QuickJS); a payload holds
// counted references to other objects (Held), reports them in trace() and releases them in dispose(). A finalizer only
// releases: in a garbage cycle the other payloads may already be gone.
#pragma once

#include <cstdint>
#include <new>
#include <utility>

#include "quickjs.h"
#include "Sources/Support/Errors.h"

namespace wr {

class PlatformObject {
public:
    virtual ~PlatformObject() = default;
    /// The object this payload belongs to. Not counted: the object owns the payload.
    JSValueConst object() const { return m_object; }
    JSValue newRef(JSContext* ctx) const { return JS_DupValue(ctx, m_object); }
    virtual void trace(JSRuntime* rt, JS_MarkFunc* mark) const {}
    virtual void dispose(JSRuntime* rt) {}

private:
    friend void attachPayload(JSValue object, PlatformObject* payload);
    JSValue m_object = JS_UNDEFINED;
};

/// One counted reference to a platform object.
template <class T>
class Ref {
public:
    Ref() = default;
    /// Takes over a reference the caller owns.
    static Ref adopt(JSContext* ctx, T* p) {
        Ref r;
        r.m_ctx = ctx;
        r.m_ptr = p;
        return r;
    }
    /// Adds a reference.
    static Ref retain(JSContext* ctx, T* p) {
        if (p) {
            JS_DupValue(ctx, p->object());
        }
        return adopt(ctx, p);
    }
    Ref(const Ref& other) : m_ctx(other.m_ctx), m_ptr(other.m_ptr) {
        if (m_ptr) {
            JS_DupValue(m_ctx, m_ptr->object());
        }
    }
    Ref(Ref&& other) noexcept : m_ctx(other.m_ctx), m_ptr(other.m_ptr) { other.m_ptr = nullptr; }
    template <class U>
    Ref(Ref<U>&& other) noexcept : m_ctx(other.context()), m_ptr(other.leak()) {}
    Ref& operator=(Ref other) noexcept {
        std::swap(m_ctx, other.m_ctx);
        std::swap(m_ptr, other.m_ptr);
        return *this;
    }
    ~Ref() {
        if (m_ptr) {
            JS_FreeValue(m_ctx, m_ptr->object());
        }
    }
    T* get() const { return m_ptr; }
    T* operator->() const { return m_ptr; }
    T& operator*() const { return *m_ptr; }
    explicit operator bool() const { return m_ptr != nullptr; }
    JSContext* context() const { return m_ctx; }
    /// Gives the reference up, as the object value (JS_NULL when empty).
    JSValue release() {
        JSValue v = m_ptr ? m_ptr->object() : JS_NULL;
        m_ptr = nullptr;
        return v;
    }
    /// Gives the reference up, as the payload.
    T* leak() {
        T* p = m_ptr;
        m_ptr = nullptr;
        return p;
    }

private:
    JSContext* m_ctx = nullptr;
    T* m_ptr = nullptr;
};

/// The class id of interface `iface` in the context's runtime (Runtime.cpp).
JSClassID classIdFor(JSContext* ctx, uint16_t iface);
/// Counts a new platform object in the context's runtime (Runtime.cpp; Runtime::liveObjects).
void noteCreated(JSContext* ctx);
/// Defines a new object's per-instance members: the [LegacyUnforgeable] members of `iface` and its ancestors
/// (Runtime.cpp). Nothing when the interface has none. Throws Thrown.
void defineInstanceMembers(JSContext* ctx, JSValueConst object, uint16_t iface);
/// Sets a new object's payload (PlatformObject.cpp).
void attachPayload(JSValue object, PlatformObject* payload);

/// Creates an object of interface `iface` with a new T payload. The caller owns the one reference.
template <class T, class... A>
Ref<T> create(JSContext* ctx, uint16_t iface, A&&... args) {
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
    JSValue object = JS_NewObjectClass(ctx, classIdFor(ctx, iface));
    if (JS_IsException(object)) {
        payload->dispose(JS_GetRuntime(ctx));
        payload->~T();
        js_free(ctx, memory);
        throw Thrown{};
    }
    attachPayload(object, payload);
    noteCreated(ctx);
    try {
        defineInstanceMembers(ctx, object, iface);
    } catch (...) {
        // The object owns its payload: freeing it runs the finalizer, which disposes the payload.
        JS_FreeValue(ctx, object);
        throw;
    }
    return Ref<T>::adopt(ctx, payload);
}

/// The payload of `v` if it is a platform object of this runtime (any interface).
PlatformObject* payloadOf(JSContext* ctx, JSValueConst v);
/// The payload of `v` if it is a platform object of this runtime implementing `iface` (its interface or an ancestor).
PlatformObject* payloadImplementing(JSContext* ctx, JSValueConst v, uint16_t iface);
bool isPlatformObject(JSContext* ctx, JSValueConst v);
/// The payload of an object known to be a live platform object of ours.
PlatformObject* payloadOfKnown(JSValueConst v);

/// The class hooks every interface's class shares.
void finalizePlatformObject(JSRuntime* rt, JSValueConst v);
void tracePlatformObject(JSRuntime* rt, JSValueConst v, JS_MarkFunc* mark);

} // namespace wr
