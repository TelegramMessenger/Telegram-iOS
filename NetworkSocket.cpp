//
// Created by Grishka on 29.03.17.
//

#include "NetworkSocket.h"
#include <stdexcept>
#include <algorithm>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#include "os/windows/NetworkSocketWinsock.h"
#else
#include "os/posix/NetworkSocketPosix.h"
#endif
#include "logging.h"
#include "VoIPServerConfig.h"
#include "VoIPController.h"

#define MIN_UDP_PORT 16384
#define MAX_UDP_PORT 32768

using namespace tgvoip;

NetworkSocket::NetworkSocket(){
	ipv6Timeout=ServerConfig::GetSharedInstance()->GetDouble("nat64_fallback_timeout", 3);
	failed=false;
}

NetworkSocket::~NetworkSocket(){

}

std::string NetworkSocket::GetLocalInterfaceInfo(IPv4Address *inet4addr, IPv6Address *inet6addr){
	std::string r="not implemented";
	return r;
}

uint16_t NetworkSocket::GenerateLocalPort(){
	return (uint16_t) ((rand()%(MAX_UDP_PORT-MIN_UDP_PORT))+MIN_UDP_PORT);
}

void NetworkSocket::SetMaxPriority(){
}

bool NetworkSocket::IsFailed(){
	return failed;
}

NetworkSocket *NetworkSocket::Create(){
#ifndef _WIN32
	return new NetworkSocketPosix();
#else
	return new NetworkSocketWinsock();
#endif
}

void NetworkSocket::GenerateTCPO2States(unsigned char* buffer, TCPO2State* recvState, TCPO2State* sendState){
	memset(recvState, 0, sizeof(TCPO2State));
	memset(sendState, 0, sizeof(TCPO2State));
	unsigned char nonce[64];
	uint32_t *first = reinterpret_cast<uint32_t*>(nonce), *second = first + 1;
	uint32_t first1 = 0x44414548U, first2 = 0x54534f50U, first3 = 0x20544547U, first4 = 0x20544547U, first5 = 0xeeeeeeeeU;
	uint32_t second1 = 0;
	do {
		VoIPController::crypto.rand_bytes(nonce, sizeof(nonce));
	} while (*first == first1 || *first == first2 || *first == first3 || *first == first4 || *first == first5 || *second == second1 || *reinterpret_cast<unsigned char*>(nonce) == 0xef);

	// prepare encryption key/iv
	memcpy(sendState->key, nonce + 8, 32);
	memcpy(sendState->iv, nonce + 8 + 32, 16);

	// prepare decryption key/iv
	char reversed[48];
	memcpy(reversed, nonce + 8, sizeof(reversed));
	std::reverse(reversed, reversed + sizeof(reversed));
	memcpy(recvState->key, reversed, 32);
	memcpy(recvState->iv, reversed + 32, 16);

	// write protocol identifier
	*reinterpret_cast<uint32_t*>(nonce + 56) = 0xefefefefU;
	memcpy(buffer, nonce, 56);
	EncryptForTCPO2(nonce, sizeof(nonce), sendState);
	memcpy(buffer+56, nonce+56, 8);
}

void NetworkSocket::EncryptForTCPO2(unsigned char *buffer, size_t len, TCPO2State *state){
	VoIPController::crypto.aes_ctr_encrypt(buffer, len, state->key, state->iv, state->ecount, &state->num);
}

bool NetworkAddress::operator==(const NetworkAddress &other){
	IPv4Address* self4=dynamic_cast<IPv4Address*>(this);
	IPv4Address* other4=dynamic_cast<IPv4Address*>((NetworkAddress*)&other);
	if(self4 && other4){
		return self4->GetAddress()==other4->GetAddress();
	}
	IPv6Address* self6=dynamic_cast<IPv6Address*>(this);
	IPv6Address* other6=dynamic_cast<IPv6Address*>((NetworkAddress*)&other);
	if(self6 && other6){
		return memcmp(self6->GetAddress(), other6->GetAddress(), 16)==0;
	}
	return false;
}

bool NetworkAddress::operator!=(const NetworkAddress &other){
	return !(*this == other);
}

IPv4Address::IPv4Address(std::string addr){
#ifndef _WIN32
	this->address=NetworkSocketPosix::StringToV4Address(addr);
#else
	this->address=NetworkSocketWinsock::StringToV4Address(addr);
#endif
}

IPv4Address::IPv4Address(uint32_t addr){
	this->address=addr;
}

IPv4Address::IPv4Address(){
	this->address=0;
}


std::string IPv4Address::ToString(){
#ifndef _WIN32
	return NetworkSocketPosix::V4AddressToString(address);
#else
	return NetworkSocketWinsock::V4AddressToString(address);
#endif
}

/*sockaddr &IPv4Address::ToSockAddr(uint16_t port){
	sockaddr_in sa;
	sa.sin_family=AF_INET;
	sa.sin_addr=addr;
	sa.sin_port=port;
	return *((sockaddr *) &sa);
}*/

uint32_t IPv4Address::GetAddress(){
	return address;
}

IPv6Address::IPv6Address(std::string addr){
#ifndef _WIN32
	NetworkSocketPosix::StringToV6Address(addr, this->address);
#else
	NetworkSocketWinsock::StringToV6Address(addr, this->address);
#endif
}

IPv6Address::IPv6Address(uint8_t addr[16]){
	memcpy(address, addr, 16);
}

IPv6Address::IPv6Address(){
	memset(address, 0, 16);
}

std::string IPv6Address::ToString(){
	return "";
}

/*sockaddr &IPv6Address::ToSockAddr(uint16_t port){
	sockaddr_in6 sa;
	sa.sin6_family=AF_INET6;
	sa.sin6_addr=addr;
	sa.sin6_port=port;
	return *((sockaddr *) &sa);
}*/

const uint8_t *IPv6Address::GetAddress(){
	return address;
}
