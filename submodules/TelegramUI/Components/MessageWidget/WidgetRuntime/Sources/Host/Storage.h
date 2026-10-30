// Web Storage per SDK v1 §2.8 (V2a plan, Task 2): one area, "local" or "session", held in counted memory, with the
// framework's quota (16384 bytes of keys and values in UTF-8). The host gives the stored area at the first read
// (Host::storageArea) and gets it back at the end of a task that changed it (Host::storageCommit; Window::commitStorage).
#pragma once

#include <optional>
#include <string>
#include <vector>

#include "Generated/Bindings.h"
#include "Sources/Support/Allocator.h"
#include "twidget/sdk_policy.h"

namespace wr {

/// SDK v1 §2.8: the vendored policy's STORAGE_QUOTA_BYTES (4 KB since widget-sandbox v0.3.0, 16 KB before).
inline constexpr size_t kStorageQuotaBytes = size_t(twidget::sdk::STORAGE_QUOTA_BYTES);

class Storage final : public PlatformObject {
public:
    Storage(JSContext* ctx, std::string area);

    // Storage
    uint32_t length(JSContext* ctx);
    std::optional<String> key(JSContext* ctx, uint32_t index);
    std::optional<String> getItem(JSContext* ctx, String key);
    /// Throws QuotaExceededError, storing nothing, when the area would pass kStorageQuotaBytes.
    void setItem(JSContext* ctx, String key, String value);
    void removeItem(JSContext* ctx, String key);
    void clear(JSContext* ctx);

    // The NamedExotic contract. A key is visible as a property only where nothing on the prototype chain has that name
    // (WebIDL's named property visibility: Storage is not [LegacyOverrideBuiltIns]).
    std::vector<String> supportedNames(JSContext* ctx);
    std::optional<String> namedValue(JSContext* ctx, const String& name);
    void setNamed(JSContext* ctx, const String& name, const String& value) { this->setItem(ctx, name, value); }
    bool deleteNamed(JSContext* ctx, const String& name);

    /// Hands the area to the host when it changed since the last commit.
    void commitIfChanged(JSContext* ctx);

private:
    using Text = std::basic_string<char, std::char_traits<char>, JSAllocator<char>>;
    struct Entry {
        Text key;
        Text value;
    };
    void load(JSContext* ctx);
    /// The index of `key`, or -1.
    int find(JSContext* ctx, const std::string& key);

    std::string m_area;
    Vector<Entry> m_entries;
    size_t m_bytes = 0;
    bool m_loaded = false;
    bool m_changed = false;
};

} // namespace wr
