#pragma once

#include <string>

#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

// Stops for the counted caps of the strict policy (Limits, widget-sandbox v0.3.0), with the reasons upstream's validator
// stops a widget with (validator.ts): the conformance set's stop tests are judged by their start. Each latches
// StopReason::Limit and throws Aborted; only call one where Limits::stops holds.

[[noreturn]] inline void stopForLimit(JSContext* ctx, std::string reason) {
    Runtime::from(ctx).stopForLimit(std::move(reason));
    throw Aborted{};
}

/// One text value past Limits::textValueUnits: a Text's data, a text attribute, a sheet's text, a canvas string, Path2D
/// data.
[[noreturn]] inline void stopForTextValue(JSContext* ctx, size_t units) {
    stopForLimit(ctx, "Text limit exceeded: a text value of " + std::to_string(units) + " characters (max " +
                          std::to_string(Runtime::from(ctx).limits().textValueUnits) + ")");
}

/// The document's text past Limits::textBudgetUnits.
[[noreturn]] inline void stopForTextBudget(JSContext* ctx) {
    stopForLimit(ctx, "Text limit exceeded: the document's text is over " +
                          std::to_string(Runtime::from(ctx).limits().textBudgetUnits) + " characters");
}

/// One attribute value past Limits::attributeUnits.
[[noreturn]] inline void stopForAttribute(JSContext* ctx, size_t units) {
    stopForLimit(ctx, "Attribute limit exceeded: a value of " + std::to_string(units) + " characters (max " +
                          std::to_string(Runtime::from(ctx).limits().attributeUnits) + ")");
}

} // namespace wr
