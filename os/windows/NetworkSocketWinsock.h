//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_NETWORKSOCKETWINSOCK_H
#define LIBTGVOIP_NETWORKSOCKETWINSOCK_H

#include "../../NetworkSocket.h"
#include <stdint.h>
#include <vector>

namespace tgvoip {

struct TCPSocket{
	uintptr_t fd;
	IPv4Address address;
	uint16_t port;
	TCPO2State recvState;
	TCPO2State sendState;
};

class NetworkSocketWinsock : public NetworkSocket{
public:
	NetworkSocketWinsock();
	virtual ~NetworkSocketWinsock();
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
	uintptr_t fd;
	bool needUpdateNat64Prefix;
	bool nat64Present;
	double switchToV6at;
	bool isV4Available;
	IPv4Address lastRecvdV4;
	IPv6Address lastRecvdV6;
	bool isAtLeastVista;
	std::vector<TCPSocket> tcpSockets;
	bool closing;

};

}

#endif //LIBTGVOIP_NETWORKSOCKETWINSOCK_H
