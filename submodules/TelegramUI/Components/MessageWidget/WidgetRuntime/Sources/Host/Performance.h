// HR-Time's Performance: now() and timeOrigin from the host's clocks, relative to the window's time origin.
#pragma once

#include "Generated/Bindings.h"
#include "Sources/Events/EventTarget.h"

namespace wr {

class Performance : public EventTarget {
public:
    Performance() = default;
    double now(JSContext* ctx);
    double timeOrigin(JSContext* ctx);
    Object toJSON(JSContext* ctx);
};

} // namespace wr
