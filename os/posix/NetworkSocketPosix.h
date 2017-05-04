//
// Created by Grishka on 10.04.17.
//

#ifndef LIBTGVOIP_NETWORKSOCKETPOSIX_H
#define LIBTGVOIP_NETWORKSOCKETPOSIX_H

#include "../../NetworkSocket.h"

namespace tgvoip {

class NetworkSocketPosix : public NetworkSocket{
public:
	NetworkSocketPosix();
	virtual ~NetworkSocketPosix();
	virtual void Send(NetworkPacket* packet);
	virtual void Receive(NetworkPacket* packet);
	virtual void Open();
	virtual void Close();
	virtual std::string GetLocalInterfaceInfo(IPv4Address* v4addr, IPv6Address* v6addr);
	virtual void OnActiveInterfaceChanged();
	virtual uint16_t GetLocalPort();

	static std::string V4AddressToString(uint32_t address);
	static std::string V6AddressToString(unsigned char address[16]);
	static uint32_t StringToV4Address(std::string address);
	static void StringToV6Address(std::string address, unsigned char* out);

protected:
	virtual void SetMaxPriority();

private:
	int fd;
	bool needUpdateNat64Prefix;
	bool nat64Present;
	double switchToV6at;
	bool isV4Available;
	IPv4Address lastRecvdV4;
	IPv6Address lastRecvdV6;
};

}

#endif //LIBTGVOIP_NETWORKSOCKETPOSIX_H
