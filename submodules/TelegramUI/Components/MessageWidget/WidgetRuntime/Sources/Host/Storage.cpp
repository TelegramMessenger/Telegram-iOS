#include "Sources/Host/Storage.h"

#include <algorithm>

#include "Sources/DOM/DOM.h"
#include "Sources/Host/Globals.h"
#include "Sources/Host/HostState.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

Storage::Storage(JSContext* ctx, std::string area)
    : m_area(std::move(area)), m_entries(JSAllocator<Entry>(JS_GetRuntime(ctx))) {}

void Storage::load(JSContext* ctx) {
    if (m_loaded) {
        return;
    }
    m_loaded = true;
    JSRuntime* rt = JS_GetRuntime(ctx);
    Host& host = Runtime::from(ctx).host();
    // SDK v1 §2.16: a preview's storage starts empty and is never kept.
    const HostState* state = HostState::find(ctx);
    const bool preview = state && state->isPreview();
    const std::vector<std::pair<std::string, std::string>> stored = preview ? std::vector<std::pair<std::string, std::string>>{} : host.storageArea(m_area);
    // The client stores what it got and the quota is the framework's (§5.4): a preload past it is dropped whole, with
    // storage-rejected, and the widget starts empty (§3.1).
    size_t bytes = 0;
    for (const auto& [key, value] : stored) {
        bytes += key.size() + value.size();
    }
    if (bytes > kStorageQuotaBytes) {
        host.diagnostic("storage-rejected", m_area + ": the stored area is over the quota");
        return;
    }
    for (const auto& [key, value] : stored) {
        m_entries.push_back(Entry{Text(key.begin(), key.end(), JSAllocator<char>(rt)), Text(value.begin(), value.end(), JSAllocator<char>(rt))});
    }
    m_bytes = bytes;
}

int Storage::find(JSContext* ctx, const std::string& key) {
    for (size_t i = 0; i < m_entries.size(); i++) {
        if (m_entries[i].key.size() == key.size() && std::equal(key.begin(), key.end(), m_entries[i].key.begin())) {
            return int(i);
        }
    }
    return -1;
}

uint32_t Storage::length(JSContext* ctx) {
    this->load(ctx);
    return uint32_t(m_entries.size());
}

std::optional<String> Storage::key(JSContext* ctx, uint32_t index) {
    this->load(ctx);
    if (index >= m_entries.size()) {
        return std::nullopt;
    }
    const Text& key = m_entries[index].key;
    return String::fromUTF8(ctx, std::string_view(key.data(), key.size()));
}

namespace {

/// A key converted only as far as an area could hold one (the final review's I3); nullopt for a longer key, which no
/// area holds.
std::optional<std::string> storableKey(JSContext* ctx, const String& key) {
    bool cut = false;
    std::string utf8 = key.utf8Prefix(kStorageQuotaBytes, &cut);
    if (cut) {
        return std::nullopt;
    }
    return utf8;
}

} // namespace

std::optional<String> Storage::getItem(JSContext* ctx, String key) {
    this->load(ctx);
    const std::optional<std::string> utf8 = storableKey(ctx, key);
    const int i = utf8 ? this->find(ctx, *utf8) : -1;
    if (i < 0) {
        return std::nullopt;
    }
    const Text& value = m_entries[size_t(i)].value;
    return String::fromUTF8(ctx, std::string_view(value.data(), value.size()));
}

void Storage::setItem(JSContext* ctx, String keyString, String valueString) {
    this->load(ctx);
    // Each converted only as far as the quota could hold it: a longer one cannot be stored.
    bool keyCut = false, valueCut = false;
    const std::string key = keyString.utf8Prefix(kStorageQuotaBytes, &keyCut);
    const std::string value = valueString.utf8Prefix(kStorageQuotaBytes, &valueCut);
    const int i = this->find(ctx, key);
    const size_t old = i < 0 ? 0 : m_entries[size_t(i)].key.size() + m_entries[size_t(i)].value.size();
    if (keyCut || valueCut || m_bytes - old + key.size() + value.size() > kStorageQuotaBytes) {
        throw DOMError{"QuotaExceededError", "The widget's storage is full (" + std::to_string(kStorageQuotaBytes / 1024) + " KB per area)."};
    }
    JSRuntime* rt = JS_GetRuntime(ctx);
    if (i < 0) {
        m_entries.push_back(Entry{Text(key.begin(), key.end(), JSAllocator<char>(rt)), Text(value.begin(), value.end(), JSAllocator<char>(rt))});
    } else {
        m_entries[size_t(i)].value.assign(value.begin(), value.end());
    }
    m_bytes = m_bytes - old + key.size() + value.size();
    m_changed = true;
}

void Storage::removeItem(JSContext* ctx, String key) {
    this->load(ctx);
    const std::optional<std::string> utf8 = storableKey(ctx, key);
    const int i = utf8 ? this->find(ctx, *utf8) : -1;
    if (i < 0) {
        return;
    }
    m_bytes -= m_entries[size_t(i)].key.size() + m_entries[size_t(i)].value.size();
    m_entries.erase(m_entries.begin() + i);
    m_changed = true;
}

void Storage::clear(JSContext* ctx) {
    this->load(ctx);
    if (m_entries.empty()) {
        return;
    }
    m_entries.clear();
    m_bytes = 0;
    m_changed = true;
}

std::vector<String> Storage::supportedNames(JSContext* ctx) {
    this->load(ctx);
    std::vector<String> names;
    for (const Entry& entry : m_entries) {
        names.push_back(String::fromUTF8(ctx, std::string_view(entry.key.data(), entry.key.size())));
    }
    return names;
}

std::optional<String> Storage::namedValue(JSContext* ctx, const String& name) {
    // Named property visibility: nothing on the prototype chain may have the name.
    Value proto = Value::adopt(ctx, checked(ctx, JS_GetPrototype(ctx, this->object())));
    Atom atom = Atom::fromString(ctx, name);
    const int found = JS_HasProperty(ctx, proto.get(), atom.get());
    if (found < 0) {
        throw Thrown{};
    }
    if (found) {
        return std::nullopt;
    }
    return this->getItem(ctx, name);
}

bool Storage::deleteNamed(JSContext* ctx, const String& name) {
    this->load(ctx);
    const std::optional<std::string> utf8 = storableKey(ctx, name);
    if (!utf8 || this->find(ctx, *utf8) < 0) {
        return false;
    }
    this->removeItem(ctx, name);
    return true;
}

void Storage::commitIfChanged(JSContext* ctx) {
    // Nothing is committed once the widget has stopped: the task that stopped it was cut short, so its writes are not a
    // state the widget reached (V2b plan, Task 1).
    if (!m_changed || Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    m_changed = false;
    // SDK v1 §2.16: a preview's storage lives only for its run.
    if (const HostState* state = HostState::find(ctx); state && state->isPreview()) {
        return;
    }
    std::vector<std::pair<std::string, std::string>> entries;
    entries.reserve(m_entries.size());
    for (const Entry& entry : m_entries) {
        entries.emplace_back(std::string(entry.key.data(), entry.key.size()), std::string(entry.value.data(), entry.value.size()));
    }
    Runtime::from(ctx).host().storageCommit(m_area, entries);
}

// MARK: Window

Storage* Window::localStorage(JSContext* ctx) {
    if (m_localStorage.isUndefined()) {
        m_localStorage.set(JS_GetRuntime(ctx), create<Storage>(ctx, idl::kStorage, ctx, std::string("local")).release());
    }
    return static_cast<Storage*>(payloadOfKnown(m_localStorage.value));
}

Storage* Window::sessionStorage(JSContext* ctx) {
    if (m_sessionStorage.isUndefined()) {
        m_sessionStorage.set(JS_GetRuntime(ctx), create<Storage>(ctx, idl::kStorage, ctx, std::string("session")).release());
    }
    return static_cast<Storage*>(payloadOfKnown(m_sessionStorage.value));
}

void Window::commitStorage(JSContext* ctx) {
    for (Held* held : {&m_localStorage, &m_sessionStorage}) {
        if (!held->isUndefined()) {
            static_cast<Storage*>(payloadOfKnown(held->value))->commitIfChanged(ctx);
        }
    }
}

} // namespace wr
