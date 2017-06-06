//
// Created by Grishka on 29.03.17.
//

#ifndef LIBTGVOIP_NETWORKSOCKET_H
#define LIBTGVOIP_NETWORKSOCKET_H

#include <stdint.h>
#include <string>

namespace tgvoip {

	enum NetworkProtocol{
		PROTO_UDP=0,
		PROTO_TCP
	};

	struct TCPO2State{
		unsigned char key[32];
		unsigned char iv[16];
		unsigned char ecount[16];
		uint32_t num;
	};

	class NetworkAddress{
	public:
		virtual std::string ToString()=0;
		//virtual sockaddr& ToSockAddr(uint16_t port)=0;
		bool operator==(const NetworkAddress& other);
		bool operator!=(const NetworkAddress& other);
	};

	class IPv4Address : public NetworkAddress{
	public:
		IPv4Address(std::string addr);
		IPv4Address(uint32_t addr);
		IPv4Address();
		virtual std::string ToString();
		//virtual sockaddr& ToSockAddr(uint16_t port);
		uint32_t GetAddress();

	private:
		uint32_t address;
	};

	class IPv6Address : public NetworkAddress{
	public:
		IPv6Address(std::string addr);
		IPv6Address(uint8_t addr[16]);
		IPv6Address();
		virtual std::string ToString();
		//virtual sockaddr& ToSockAddr(uint16_t port);
		const uint8_t* GetAddress();
	private:
		uint8_t address[16];
	};

	struct NetworkPacket{
		unsigned char* data;
		size_t length;
		NetworkAddress* address;
		uint16_t port;
		NetworkProtocol protocol;
	};
	typedef struct NetworkPacket NetworkPacket;

	class NetworkSocket{
	public:
		NetworkSocket();
		virtual ~NetworkSocket();
		virtual void Send(NetworkPacket* packet)=0;
		virtual void Receive(NetworkPacket* packet)=0;
		virtual void Open()=0;
		virtual void Close()=0;
		virtual uint16_t GetLocalPort()=0;
		virtual std::string GetLocalInterfaceInfo(IPv4Address* inet4addr, IPv6Address* inet6addr);
		virtual void OnActiveInterfaceChanged()=0;
		bool IsFailed();

		static NetworkSocket* Create();

	protected:
		virtual uint16_t GenerateLocalPort();
		virtual void SetMaxPriority();
		static void GenerateTCPO2States(unsigned char* buffer, TCPO2State* recvState, TCPO2State* sendState);
		static void EncryptForTCPO2(unsigned char* buffer, size_t len, TCPO2State* state);
		double ipv6Timeout;
		unsigned char nat64Prefix[12];
		bool failed;
	};

}

#endif //LIBTGVOIP_NETWORKSOCKET_H
