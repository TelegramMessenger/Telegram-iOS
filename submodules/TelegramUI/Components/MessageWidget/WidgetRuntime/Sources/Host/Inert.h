// SDK v1's removed and inert APIs (V2a plan, Task 1; docs/sdk-v1.md §2.10): the network interfaces, whose constructors
// throw NetworkDisabledError, and the helpers the inert members share (Sources/Host/Inert.cpp).
#pragma once

#include <vector>

#include "Generated/Bindings.h"
#include "Sources/Support/Values.h"

namespace wr {

/// A promise rejected with a DOMException named `name`.
Value rejectedWithDOMException(JSContext* ctx, const char* name, const char* message);
/// Throws NetworkDisabledError (a DOMError: the binding glue makes it a DOMException).
[[noreturn]] void throwNetworkDisabled();

#define WR_NETWORK_INTERFACE(Name)                                                                \
    class Name final : public PlatformObject {                                                    \
    public:                                                                                       \
        static Ref<Name> construct(JSContext*, std::vector<Value>) { throwNetworkDisabled(); }    \
    };
WR_NETWORK_INTERFACE(XMLHttpRequest)
WR_NETWORK_INTERFACE(WebSocket)
WR_NETWORK_INTERFACE(EventSource)
WR_NETWORK_INTERFACE(RTCPeerConnection)
WR_NETWORK_INTERFACE(Worker)
WR_NETWORK_INTERFACE(SharedWorker)
WR_NETWORK_INTERFACE(BroadcastChannel)
#undef WR_NETWORK_INTERFACE

} // namespace wr
