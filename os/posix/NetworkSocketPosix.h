//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_NETWORKSOCKETPOSIX_H
#define LIBTGVOIP_NETWORKSOCKETPOSIX_H

#include "../../NetworkSocket.h"
#include <vector>
#include <sys/select.h>
#include <pthread.h>

namespace tgvoip {

struct TCPSocket{
	int fd;
	IPv4Address address;
	uint16_t port;
	TCPO2State recvState;
	TCPO2State sendState;
};

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
	std::vector<TCPSocket> tcpSockets;
	bool needUpdateNat64Prefix;
	bool nat64Present;
	double switchToV6at;
	bool isV4Available;
	bool useTCP;
	bool closing;
	IPv4Address lastRecvdV4;
	IPv6Address lastRecvdV6;
	int pipeRead;
	int pipeWrite;
};

}

#endif //LIBTGVOIP_NETWORKSOCKETPOSIX_H
