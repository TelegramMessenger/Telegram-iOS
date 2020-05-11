#include "LayerBase.h"

#include "Layer92.h"

bool LayerBase::ChangeProtocol(uint32_t protocol_version) {
    if (protocol && protocol->version == protocol_version)
        return true;
    auto new_protocol = ProtocolBase::CreateProtocol(protocol_version);
    if (!new_protocol)
        return false;
    protocol = std::move(new_protocol);
    return true;
}

LayerBase::LayerBase(uint32_t version)
: version(version)
, protocol(ProtocolBase::CreateProtocol(ProtocolBase::actual_version)) {}
