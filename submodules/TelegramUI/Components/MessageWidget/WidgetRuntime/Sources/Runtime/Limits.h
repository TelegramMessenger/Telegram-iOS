#pragma once

#include <cstddef>
#include <cstdint>

namespace wr {

/// The counted caps of widget-sandbox v0.3.0's policies (docs/decisions.md, "Strict limits from the start"): each about
/// twice what real widgets use. Under strict (every widget the app shows) a cap passed stops the widget with upstream's
/// reason (Runtime::stopForLimit); compat keeps the caps from before v0.3.0 and never stops on one, what was past it
/// being dropped as before: the stress kit's measuring runs and tests only. Counts, never time (the user's rule).
struct Limits {
    /// A counted cap passed stops the widget (strict) or drops what passed it (compat).
    bool stops = true;
    /// One text value: a Text's data, a text attribute, a canvas string, Path2D data. UTF-16 units.
    size_t textValueUnits = 32768;
    /// The document's text: Texts, text attributes, a sheet's text and its strings. UTF-16 units.
    size_t textBudgetUnits = 49152;
    /// One attribute value, an inline `style` included. UTF-16 units. 0: none (compat: the render's byte budget).
    size_t attributeUnits = 8192;
    /// Operations in one batch (a flush): nodes made, inserted or removed, attributes set or removed, text changed, one
    /// per canvas drawn on. 0: none.
    size_t opsPerBatch = 10000;
    /// Style rules and `@keyframes` in the document's stylesheets. 0: none.
    size_t cssRules = 400;
    size_t cssKeyframes = 32;
    /// Commands to one canvas in one task: past it the command throws RangeError (strict) or is dropped (compat).
    size_t canvasCommands = 10000;
    /// The canvases a build sees, width × height together. 0: none (compat: the bitmap allocator's own cap).
    uint64_t canvasPixels = uint64_t(2048) * 2048;
    /// Live timers (`setTimeout`, `setInterval`): past it `RangeError("too many timers")`.
    size_t timers = 64;
    /// Script animations rendered; the rest are not (`animation-limit`).
    size_t renderedAnimations = 64;
    /// The QuickJS heap (the runtime's Options::memoryLimitBytes, which the embedder sets from this): an allocation past
    /// it stops the widget (StopReason::Memory).
    size_t memoryBytes = size_t(8) << 20;

    static Limits strict() { return Limits{}; }
    static Limits compat() {
        Limits limits;
        limits.stops = false;
        limits.textValueUnits = 65536;
        limits.textBudgetUnits = 262144;
        limits.attributeUnits = 0;
        limits.opsPerBatch = 0;
        limits.cssRules = 0;
        limits.cssKeyframes = 0;
        limits.canvasCommands = 400000;
        limits.canvasPixels = 0;
        limits.timers = 256;
        limits.renderedAnimations = 1024;
        limits.memoryBytes = size_t(64) << 20;
        return limits;
    }
};

} // namespace wr
