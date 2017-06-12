//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "NetworkSocketPosix.h"
#include <sys/socket.h>
#include <errno.h>
#include <assert.h>
#include <netdb.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <netinet/tcp.h>
#include "../../logging.h"
#include "../../VoIPController.h"
#include "../../BufferInputStream.h"
#include "../../BufferOutputStream.h"

using namespace tgvoip;


NetworkSocketPosix::NetworkSocketPosix() : lastRecvdV4(0), lastRecvdV6("::0"){
	needUpdateNat64Prefix=true;
	nat64Present=false;
	switchToV6at=0;
	isV4Available=false;
	useTCP=false;
	closing=false;

	int p[2];
	int pipeRes=pipe(p);
	assert(pipeRes==0);
	pipeRead=p[0];
	pipeWrite=p[1];
}

NetworkSocketPosix::~NetworkSocketPosix(){
	close(pipeRead);
	close(pipeWrite);
}

void NetworkSocketPosix::SetMaxPriority(){
#ifdef __APPLE__
	int prio=NET_SERVICE_TYPE_VO;
	int res=setsockopt(fd, SOL_SOCKET, SO_NET_SERVICE_TYPE, &prio, sizeof(prio));
	if(res<0){
		LOGE("error setting darwin-specific net priority: %d / %s", errno, strerror(errno));
	}
#else
	int prio=5;
	int res=setsockopt(fd, SOL_SOCKET, SO_PRIORITY, &prio, sizeof(prio));
	if(res<0){
		LOGE("error setting priority: %d / %s", errno, strerror(errno));
	}
	prio=6 << 5;
	res=setsockopt(fd, SOL_IP, IP_TOS, &prio, sizeof(prio));
	if(res<0){
		LOGE("error setting ip tos: %d / %s", errno, strerror(errno));
	}
#endif
}

void NetworkSocketPosix::Send(NetworkPacket *packet){
	if(!packet || !packet->address){
		LOGW("tried to send null packet");
		return;
	}
	if(packet->protocol==PROTO_TCP){
		//LOGV("Sending TCP packet to %s:%u", packet->address->ToString().c_str(), packet->port);
		IPv4Address* v4addr=dynamic_cast<IPv4Address*>(packet->address);
		if(v4addr){
			TCPSocket* _socket=NULL;
			for(std::vector<TCPSocket>::iterator itr=tcpSockets.begin();itr!=tcpSockets.end();++itr){
				if(itr->address==*v4addr && itr->port==packet->port){
					_socket=&*itr;
					break;
				}
			}
			if(!_socket){
				TCPSocket s;
				s.fd=socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
				s.port=packet->port;
				s.address=IPv4Address(*v4addr);
				int opt=1;
				setsockopt(s.fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));
				timeval timeout;
				timeout.tv_sec=1;
				timeout.tv_usec=0;
				setsockopt(s.fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
				timeout.tv_sec=60;
				setsockopt(s.fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
				sockaddr_in addr;
				addr.sin_family=AF_INET;
				addr.sin_addr.s_addr=s.address.GetAddress();
				addr.sin_port=htons(s.port);
				int res=connect(s.fd, (const sockaddr*) &addr, sizeof(addr));
				if(res!=0){
					LOGW("error connecting TCP socket to %s:%u: %d / %s; %d / %s", s.address.ToString().c_str(), s.port, res, strerror(res), errno, strerror(errno));
					close(s.fd);
					return;
				}else{
					//LOGI("connected successfully, fd=%d", s.fd);
					char c=1;
					write(pipeWrite, &c, 1);
				}
				unsigned char buf[64];
				GenerateTCPO2States(buf, &s.recvState, &s.sendState);
				send(s.fd, buf, sizeof(buf), 0);
				tcpSockets.push_back(s);
				_socket=&tcpSockets[tcpSockets.size()-1];
			}
			if(_socket){
				//LOGV("sending to %s:%u, fd=%d, size=%d (%d)", _socket->address.ToString().c_str(), _socket->port, _socket->fd, packet->length, packet->length%4);
				BufferOutputStream os(packet->length+4);
				size_t len=packet->length/4;
				if(len<0x7F){
					os.WriteByte((unsigned char)len);
				}else{
					os.WriteByte(0x7F);
					os.WriteByte((unsigned char)(len & 0xFF));
					os.WriteByte((unsigned char)((len >> 8) & 0xFF));
					os.WriteByte((unsigned char)((len >> 16) & 0xFF));
				}
				os.WriteBytes(packet->data, packet->length);
				EncryptForTCPO2(os.GetBuffer(), os.GetLength(), &_socket->sendState);
				int res=send(_socket->fd, os.GetBuffer(), os.GetLength(), 0);
				if(res<0){
					LOGW("error sending to TCP: %d / %s; %d / %s", res, strerror(res), errno, strerror(errno));
				}
			}
		}else{
			LOGW("TCP over IPv6 isn't supported yet");
		}
		return;
	}
	sockaddr_in6 addr;
	IPv4Address* v4addr=dynamic_cast<IPv4Address*>(packet->address);
	if(v4addr){
		if(needUpdateNat64Prefix && !isV4Available && VoIPController::GetCurrentTime()>switchToV6at && switchToV6at!=0){
			LOGV("Updating NAT64 prefix");
			nat64Present=false;
			addrinfo* addr0;
			int res=getaddrinfo("ipv4only.arpa", NULL, NULL, &addr0);
			if(res!=0){
				LOGW("Error updating NAT64 prefix: %d / %s", res, gai_strerror(res));
			}else{
				addrinfo* addrPtr;
				unsigned char* addr170=NULL;
				unsigned char* addr171=NULL;
				for(addrPtr=addr0;addrPtr;addrPtr=addrPtr->ai_next){
					if(addrPtr->ai_family==AF_INET6){
						sockaddr_in6* translatedAddr=(sockaddr_in6*)addrPtr->ai_addr;
						uint32_t v4part=*((uint32_t*)&translatedAddr->sin6_addr.s6_addr[12]);
						if(v4part==0xAA0000C0 && !addr170){
							addr170=translatedAddr->sin6_addr.s6_addr;
						}
						if(v4part==0xAB0000C0 && !addr171){
							addr171=translatedAddr->sin6_addr.s6_addr;
						}
						char buf[INET6_ADDRSTRLEN];
						LOGV("Got translated address: %s", inet_ntop(AF_INET6, &translatedAddr->sin6_addr, buf, sizeof(buf)));
					}
				}
				if(addr170 && addr171 && memcmp(addr170, addr171, 12)==0){
					nat64Present=true;
					memcpy(nat64Prefix, addr170, 12);
					char buf[INET6_ADDRSTRLEN];
					LOGV("Found nat64 prefix from %s", inet_ntop(AF_INET6, addr170, buf, sizeof(buf)));
				}else{
					LOGV("Didn't find nat64");
				}
				freeaddrinfo(addr0);
			}
			needUpdateNat64Prefix=false;
		}
		memset(&addr, 0, sizeof(sockaddr_in6));
		addr.sin6_family=AF_INET6;
		*((uint32_t*)&addr.sin6_addr.s6_addr[12])=v4addr->GetAddress();
		if(nat64Present)
			memcpy(addr.sin6_addr.s6_addr, nat64Prefix, 12);
		else
			addr.sin6_addr.s6_addr[11]=addr.sin6_addr.s6_addr[10]=0xFF;

	}else{
		IPv6Address* v6addr=dynamic_cast<IPv6Address*>(packet->address);
		assert(v6addr!=NULL);
		memcpy(addr.sin6_addr.s6_addr, v6addr->GetAddress(), 16);
	}
	addr.sin6_port=htons(packet->port);
	char buf[INET6_ADDRSTRLEN];
	inet_ntop(AF_INET6, &addr.sin6_addr, buf, sizeof(buf));
	int res=sendto(fd, packet->data, packet->length, 0, (const sockaddr *) &addr, sizeof(addr));
	if(res<0){
		LOGE("error sending: %d / %s", errno, strerror(errno));
		if(errno==ENETUNREACH && !isV4Available && VoIPController::GetCurrentTime()<switchToV6at){
			switchToV6at=VoIPController::GetCurrentTime();
			LOGI("Network unreachable, trying NAT64");
		}
	}
}

void NetworkSocketPosix::Receive(NetworkPacket *packet){
	while(true){
		fd_set readSet, errSet;
		FD_ZERO(&readSet);
		FD_ZERO(&errSet);

		FD_SET(pipeRead, &readSet);
		FD_SET(fd, &readSet);
		FD_SET(fd, &errSet);
		int maxfd=pipeRead>fd ? pipeRead : fd;

		for(std::vector<TCPSocket>::iterator itr=tcpSockets.begin(); itr!=tcpSockets.end(); ++itr){
			FD_SET(itr->fd, &readSet);
			FD_SET(itr->fd, &errSet);
			if(itr->fd>maxfd)
				maxfd=itr->fd;
		}

		int res=select(maxfd+1, &readSet, NULL, &errSet, NULL);

		if(FD_ISSET(pipeRead, &readSet)){
			char d;
			read(pipeRead, &d, 1);
			if(closing){
				packet->length=0;
				return;
			}
			continue;
		}

		if(FD_ISSET(fd, &readSet) || FD_ISSET(fd, &errSet)){
			int addrLen=sizeof(sockaddr_in6);
			sockaddr_in6 srcAddr;
			ssize_t len=recvfrom(fd, packet->data, packet->length, 0, (sockaddr *) &srcAddr, (socklen_t *) &addrLen);
			if(len>0)
				packet->length=(size_t) len;
			else{
				LOGE("error receiving %d / %s", errno, strerror(errno));
				packet->length=0;
				return;
			}
			//LOGV("Received %d bytes from %s:%d at %.5lf", len, inet_ntoa(srcAddr.sin_addr), ntohs(srcAddr.sin_port), GetCurrentTime());
			if(!isV4Available && IN6_IS_ADDR_V4MAPPED(&srcAddr.sin6_addr)){
				isV4Available=true;
				LOGI("Detected IPv4 connectivity, will not try IPv6");
			}
			if(IN6_IS_ADDR_V4MAPPED(&srcAddr.sin6_addr) || (nat64Present && memcmp(nat64Prefix, srcAddr.sin6_addr.s6_addr, 12)==0)){
				in_addr v4addr=*((in_addr *) &srcAddr.sin6_addr.s6_addr[12]);
				lastRecvdV4=IPv4Address(v4addr.s_addr);
				packet->address=&lastRecvdV4;
			}else{
				lastRecvdV6=IPv6Address(srcAddr.sin6_addr.s6_addr);
				packet->address=&lastRecvdV6;
			}
			packet->protocol=PROTO_UDP;
			packet->port=ntohs(srcAddr.sin6_port);
			return;
		}

		for(std::vector<TCPSocket>::iterator itr=tcpSockets.begin(); itr!=tcpSockets.end();){
			if(FD_ISSET(itr->fd, &readSet)){
				unsigned char len1;
				size_t packetLen=0;
				size_t offset=0;
				ssize_t len=recv(itr->fd, &len1, 1, 0);
				if(len<=0)
					goto failed;
				EncryptForTCPO2(&len1, 1, &itr->recvState);

				if(len1<0x7F){
					packetLen=(size_t)len1*4;
				}else{
					unsigned char len2[3];
					len=recv(itr->fd, len2, 3, 0);
					if(len<=0)
						goto failed;
					EncryptForTCPO2(len2, 3, &itr->recvState);
					packetLen=((size_t)len2[0] | ((size_t)len2[1] << 8) | ((size_t)len2[2] << 16))*4;
				}

				if(packetLen>packet->length){
					LOGW("packet too big to fit into buffer");
					packet->length=0;
					return;
				}

				while(offset<packetLen){
					len=recv(itr->fd, packet->data+offset, packetLen-offset, 0);
					if(len<=0)
						goto failed;
					offset+=len;
				}
				EncryptForTCPO2(packet->data, packetLen, &itr->recvState);
				packet->address=&itr->address;
				packet->length=packetLen;
				packet->port=itr->port;
				packet->protocol=PROTO_TCP;

				return;

				failed:
				packet->length=0;
				close(itr->fd);
				itr=tcpSockets.erase(itr);
				continue;
			}
			if(FD_ISSET(itr->fd, &errSet)){
				close(itr->fd);
				itr=tcpSockets.erase(itr);
				continue;
			}
			++itr;
		}
	}
}

void NetworkSocketPosix::Open(){
	fd=socket(PF_INET6, SOCK_DGRAM, IPPROTO_UDP);
	if(fd<0){
		LOGE("error creating socket: %d / %s", errno, strerror(errno));
	}
	int flag=0;
	int res=setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &flag, sizeof(flag));
	if(res<0){
		LOGE("error enabling dual stack socket: %d / %s", errno, strerror(errno));
	}

	SetMaxPriority();

	int tries=0;
	sockaddr_in6 addr;
	//addr.sin6_addr.s_addr=0;
	memset(&addr, 0, sizeof(sockaddr_in6));
	//addr.sin6_len=sizeof(sa_family_t);
	addr.sin6_family=AF_INET6;
	for(tries=0;tries<10;tries++){
		addr.sin6_port=htons(GenerateLocalPort());
		res=::bind(fd, (sockaddr *) &addr, sizeof(sockaddr_in6));
		LOGV("trying bind to port %u", ntohs(addr.sin6_port));
		if(res<0){
			LOGE("error binding to port %u: %d / %s", ntohs(addr.sin6_port), errno, strerror(errno));
		}else{
			break;
		}
	}
	if(tries==10){
		addr.sin6_port=0;
		res=::bind(fd, (sockaddr *) &addr, sizeof(sockaddr_in6));
		if(res<0){
			LOGE("error binding to port %u: %d / %s", ntohs(addr.sin6_port), errno, strerror(errno));
			//SetState(STATE_FAILED);
			return;
		}
	}
	size_t addrLen=sizeof(sockaddr_in6);
	getsockname(fd, (sockaddr*)&addr, (socklen_t*) &addrLen);
	uint16_t localUdpPort=ntohs(addr.sin6_port);
	LOGD("Bound to local UDP port %u", ntohs(addr.sin6_port));

	needUpdateNat64Prefix=true;
	isV4Available=false;
	switchToV6at=VoIPController::GetCurrentTime()+ipv6Timeout;
}

void NetworkSocketPosix::Close(){
	closing=true;
	char c=1;
	write(pipeWrite, &c, 1);
	shutdown(fd, SHUT_RDWR);
	close(fd);
	for(std::vector<TCPSocket>::iterator itr=tcpSockets.begin(); itr!=tcpSockets.end();++itr){
		shutdown(itr->fd, SHUT_RDWR);
		close(itr->fd);
	}
}

void NetworkSocketPosix::OnActiveInterfaceChanged(){
	needUpdateNat64Prefix=true;
	isV4Available=false;
	switchToV6at=VoIPController::GetCurrentTime()+ipv6Timeout;
}

std::string NetworkSocketPosix::GetLocalInterfaceInfo(IPv4Address *v4addr, IPv6Address *v6addr){
	struct ifconf ifc;
	struct ifreq* ifr;
	char buf[16384];
	int sd;
	std::string name="";
	sd=socket(PF_INET, SOCK_DGRAM, 0);
	if(sd>0){
		ifc.ifc_len=sizeof(buf);
		ifc.ifc_ifcu.ifcu_buf=buf;
		if(ioctl(sd, SIOCGIFCONF, &ifc)==0){
			ifr=ifc.ifc_req;
			int len;
			int i;
			for(i=0;i<ifc.ifc_len;){
#ifndef __linux__
				len=IFNAMSIZ + ifr->ifr_addr.sa_len;
#else
				len=sizeof(*ifr);
#endif
				if(ifr->ifr_addr.sa_family==AF_INET){
					if(ioctl(sd, SIOCGIFADDR, ifr)==0){
						struct sockaddr_in* addr=(struct sockaddr_in *)(&ifr->ifr_addr);
						LOGI("Interface %s, address %s\n", ifr->ifr_name, inet_ntoa(addr->sin_addr));
						if(ioctl(sd, SIOCGIFFLAGS, ifr)==0){
							if(!(ifr->ifr_flags & IFF_LOOPBACK) && (ifr->ifr_flags & IFF_UP) && (ifr->ifr_flags & IFF_RUNNING)){
								//LOGV("flags = %08X", ifr->ifr_flags);
								if((ntohl(addr->sin_addr.s_addr) & 0xFFFF0000)==0xA9FE0000){
									LOGV("skipping link-local");
									continue;
								}
								if(v4addr){
									*v4addr=IPv4Address(addr->sin_addr.s_addr);
								}
								name=ifr->ifr_name;
							}
						}
					}else{
						LOGE("Error getting address for %s: %d\n", ifr->ifr_name, errno);
					}
				}
				ifr=(struct ifreq*)((char*)ifr+len);
				i+=len;
			}
		}else{
			LOGE("Error getting LAN address: %d", errno);
		}
	}
	close(sd);
	return name;
}

uint16_t NetworkSocketPosix::GetLocalPort(){
	sockaddr_in6 addr;
	size_t addrLen=sizeof(sockaddr_in6);
	getsockname(fd, (sockaddr*)&addr, (socklen_t*) &addrLen);
	return ntohs(addr.sin6_port);
}

std::string NetworkSocketPosix::V4AddressToString(uint32_t address){
	char buf[INET_ADDRSTRLEN];
	in_addr addr;
	addr.s_addr=address;
	inet_ntop(AF_INET, &addr, buf, sizeof(buf));
	return std::string(buf);
}

std::string NetworkSocketPosix::V6AddressToString(unsigned char *address){
	char buf[INET6_ADDRSTRLEN];
	in6_addr addr;
	memcpy(addr.s6_addr, address, 16);
	inet_ntop(AF_INET6, &addr, buf, sizeof(buf));
	return std::string(buf);
}

uint32_t NetworkSocketPosix::StringToV4Address(std::string address){
	in_addr addr;
	inet_pton(AF_INET, address.c_str(), &addr);
	return addr.s_addr;
}

void NetworkSocketPosix::StringToV6Address(std::string address, unsigned char *out){
	in6_addr addr;
	inet_pton(AF_INET6, address.c_str(), &addr);
	memcpy(out, addr.s6_addr, 16);
}
