// Containers inside DOM payloads allocate through QuickJS, so they count toward the widget's memory limit.
#pragma once

#include <cstddef>
#include <memory>
#include <new>
#include <string>
#include <string_view>
#include <vector>

#include "quickjs.h"

namespace wr {

template <class T>
class JSAllocator {
public:
    using value_type = T;

    explicit JSAllocator(JSRuntime* rt) noexcept : m_rt(rt) {}
    template <class U>
    JSAllocator(const JSAllocator<U>& other) noexcept : m_rt(other.runtime()) {}

    T* allocate(size_t n) {
        void* p = js_malloc_rt(m_rt, n * sizeof(T));
        if (!p) {
            throw std::bad_alloc();
        }
        return static_cast<T*>(p);
    }

    void deallocate(T* p, size_t) noexcept { js_free_rt(m_rt, p); }

    JSRuntime* runtime() const noexcept { return m_rt; }

    template <class U>
    bool operator==(const JSAllocator<U>& other) const noexcept {
        return m_rt == other.runtime();
    }

private:
    JSRuntime* m_rt;
};

template <class T>
using Vector = std::vector<T, JSAllocator<T>>;

/// Text in the JS heap.
using JSText = std::basic_string<char, std::char_traits<char>, JSAllocator<char>>;
/// Immutable text in the JS heap that copies share: a saved canvas state copies the pointer, not the text.
using SharedText = std::shared_ptr<const JSText>;

inline SharedText makeSharedText(JSRuntime* rt, std::string_view text) {
    return std::allocate_shared<JSText>(JSAllocator<JSText>(rt), text, JSAllocator<char>(rt));
}

/// The text, or `fallback` where there is none.
inline std::string_view textOr(const SharedText& text, std::string_view fallback) {
    return text ? std::string_view(*text) : fallback;
}

} // namespace wr
