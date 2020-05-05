#include "ProtocolBase.h"

#include "Protocol10.h"

const std::map<uint8_t, ProtocolBase::Constructor> ProtocolBase::constructors = {
        {10, std::make_unique<Protocol10>},
};

const uint32_t ProtocolBase::actual_version = 10;
const uint32_t ProtocolBase::minimal_version = 10;

std::unique_ptr<ProtocolBase> ProtocolBase::CreateProtocol(uint32_t version) {
    auto protocol = constructors.find(version);
    if (protocol == constructors.end())
        return nullptr;
    return protocol->second();
}

bool ProtocolBase::IsSupported(uint32_t version) {
    return constructors.find(version) != constructors.end();
}

ProtocolBase::ProtocolBase(uint32_t version) : version(version) {}
