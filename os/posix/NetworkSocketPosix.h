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

class SocketSelectCancellerPosix : public SocketSelectCanceller{
friend class NetworkSocketPosix;
public:
	SocketSelectCancellerPosix();
	virtual ~SocketSelectCancellerPosix();
	virtual void CancelSelect();
private:
	int pipeRead;
	int pipeWrite;
};

class NetworkSocketPosix : public NetworkSocket{
public:
	NetworkSocketPosix(NetworkProtocol protocol);
	virtual ~NetworkSocketPosix();
	virtual void Send(NetworkPacket* packet);
	virtual void Receive(NetworkPacket* packet);
	virtual void Open();
	virtual void Close();
	virtual void Connect(NetworkAddress* address, uint16_t port);
	virtual std::string GetLocalInterfaceInfo(IPv4Address* v4addr, IPv6Address* v6addr);
	virtual void OnActiveInterfaceChanged();
	virtual uint16_t GetLocalPort();

	static std::string V4AddressToString(uint32_t address);
	static std::string V6AddressToString(unsigned char address[16]);
	static uint32_t StringToV4Address(std::string address);
	static void StringToV6Address(std::string address, unsigned char* out);
	static IPv4Address* ResolveDomainName(std::string name);
	static bool Select(std::vector<NetworkSocket*>& readFds, std::vector<NetworkSocket*>& errorFds, SocketSelectCanceller* canceller);

	virtual NetworkAddress *GetConnectedAddress();

	virtual uint16_t GetConnectedPort();

	virtual void SetTimeouts(int sendTimeout, int recvTimeout);

protected:
	virtual void SetMaxPriority();

private:
	static int GetDescriptorFromSocket(NetworkSocket* socket);
	int fd;
	bool needUpdateNat64Prefix;
	bool nat64Present;
	double switchToV6at;
	bool isV4Available;
	bool useTCP;
	bool closing;
	IPv4Address lastRecvdV4;
	IPv6Address lastRecvdV6;
	NetworkAddress* tcpConnectedAddress;
	uint16_t tcpConnectedPort;
};

}

#endif //LIBTGVOIP_NETWORKSOCKETPOSIX_H
