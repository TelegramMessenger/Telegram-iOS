#include <sys/socket.h>
#include <errno.h>
#include <string.h>
#include <wchar.h>
#include "VoIPController.h"
#include "logging.h"
#include "threading.h"
#include "BufferOutputStream.h"
#include "BufferInputStream.h"
#include "OpusEncoder.h"
#include "OpusDecoder.h"
#include "VoIPServerConfig.h"
#include <assert.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <math.h>
#include <net/if.h>
#include <arpa/inet.h>
#include <sys/ioctl.h>
#include <exception>
#include <stdexcept>
#include <netdb.h>

#ifdef __APPLE__
#include "os/darwin/AudioUnitIO.h"
#include <mach/mach_time.h>
double CVoIPController::machTimebase=0;
uint64_t CVoIPController::machTimestart=0;
#import <Foundation/Foundation.h>
#endif

#define SHA1_LENGTH 20
#define SHA256_LENGTH 32

#ifndef TGVOIP_USE_CUSTOM_CRYPTO
#include <openssl/sha.h>
#include <openssl/aes.h>
#include <openssl/rand.h>

void tgvoip_openssl_aes_ige_encrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
	AES_KEY akey;
	AES_set_encrypt_key(key, 32*8, &akey);
	AES_ige_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

void tgvoip_openssl_aes_ige_decrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
	AES_KEY akey;
	AES_set_decrypt_key(key, 32*8, &akey);
	AES_ige_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

void tgvoip_openssl_rand_bytes(uint8_t* buffer, size_t len){
	RAND_bytes(buffer, len);
}

void tgvoip_openssl_sha1(uint8_t* msg, size_t len, uint8_t* output){
	SHA1(msg, len, output);
}

void tgvoip_openssl_sha256(uint8_t* msg, size_t len, uint8_t* output){
	SHA256(msg, len, output);
}

voip_crypto_functions_t CVoIPController::crypto={
		tgvoip_openssl_rand_bytes,
		tgvoip_openssl_sha1,
		tgvoip_openssl_sha256,
		tgvoip_openssl_aes_ige_encrypt,
		tgvoip_openssl_aes_ige_decrypt

};
#else
voip_crypto_functions_t CVoIPController::crypto; // set it yourself upon initialization
#endif

extern FILE* tgvoipLogFile;

CVoIPController::CVoIPController(){
	seq=1;
	lastRemoteSeq=0;
	state=STATE_WAIT_INIT;
	audioInput=NULL;
	audioOutput=NULL;
	decoder=NULL;
	encoder=NULL;
	jitterBuffer=NULL;
	audioOutStarted=false;
	audioTimestampIn=0;
	audioTimestampOut=0;
	stopping=false;
	int i;
	for(i=0;i<20;i++){
		emptySendBuffers.push_back(new CBufferOutputStream(1024));
	}
	sendQueue=new CBlockingQueue(21);
	init_mutex(sendBufferMutex);
	memset(remoteAcks, 0, sizeof(double)*32);
	memset(sentPacketTimes, 0, sizeof(double)*32);
	memset(recvPacketTimes, 0, sizeof(double)*32);
	memset(rttHistory, 0, sizeof(double)*32);
	memset(sendLossCountHistory, 0, sizeof(uint32_t)*32);
	memset(&stats, 0, sizeof(voip_stats_t));
	lastRemoteAckSeq=0;
	lastSentSeq=0;
	recvLossCount=0;
	packetsRecieved=0;
	waitingForAcks=false;
	networkType=NET_TYPE_UNKNOWN;
	audioPacketGrouping=3;
	audioPacketsWritten=0;
	currentAudioPacket=NULL;
	stateCallback=NULL;
	echoCanceller=NULL;
	dontSendPackets=0;
	micMuted=false;
	currentEndpoint=NULL;
	needSendP2pPing=false;
	waitingForRelayPeerInfo=false;
	lastP2pPingTime=0;
	p2pPingCount=0;
	allowP2p=true;
	dataSavingMode=false;
	memset(activeNetItfName, 0, 32);
	publicEndpointsReqTime=0;
	init_mutex(queuedPacketsMutex);
	connectionInitTime=0;
	lastRecvPacketTime=0;
	dataSavingRequestedByPeer=false;
	peerVersion=0;
	conctl=new CCongestionControl();
	prevSendLossCount=0;
	receivedInit=false;
	receivedInitAck=false;
	
	needUpdateNat64Prefix=true;
	nat64Present=false;

	maxAudioBitrate=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_max_bitrate", 20000);
	maxAudioBitrateGPRS=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_max_bitrate_gprs", 8000);
	maxAudioBitrateEDGE=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_max_bitrate_edge", 16000);
	maxAudioBitrateSaving=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_max_bitrate_saving", 8000);
	initAudioBitrate=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_init_bitrate", 16000);
	initAudioBitrateGPRS=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_init_bitrate_gprs", 8000);
	initAudioBitrateEDGE=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_init_bitrate_edge", 8000);
	initAudioBitrateSaving=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_init_bitrate_saving", 8000);
	audioBitrateStepIncr=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_bitrate_step_incr", 1000);
	audioBitrateStepDecr=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_bitrate_step_decr", 1000);
	minAudioBitrate=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("audio_min_bitrate", 8000);
	relaySwitchThreshold=CVoIPServerConfig::GetSharedInstance()->GetDouble("relay_switch_threshold", 0.8);
	p2pToRelaySwitchThreshold=CVoIPServerConfig::GetSharedInstance()->GetDouble("p2p_to_relay_switch_threshold", 0.6);
	relayToP2pSwitchThreshold=CVoIPServerConfig::GetSharedInstance()->GetDouble("relay_to_p2p_switch_threshold", 0.8);

#ifdef __APPLE__
    machTimestart=0;
#ifdef TGVOIP_USE_AUDIO_SESSION
	needNotifyAcquiredAudioSession=false;
#endif
#endif
    
	voip_stream_t* stm=(voip_stream_t *) malloc(sizeof(voip_stream_t));
	stm->id=1;
	stm->type=STREAM_TYPE_AUDIO;
	stm->codec=CODEC_OPUS;
	stm->enabled=1;
	stm->frameDuration=60;
	outgoingStreams.push_back(stm);
}

CVoIPController::~CVoIPController(){
	LOGD("Entered CVoIPController::~CVoIPController");
	if(audioInput)
		audioInput->Stop();
	if(audioOutput)
		audioOutput->Stop();
	stopping=true;
	runReceiver=false;
	LOGD("before shutdown socket");
	shutdown(udpSocket, SHUT_RDWR);
	sendQueue->Put(NULL);
    close(udpSocket);
	LOGD("before join sendThread");
	join_thread(sendThread);
	LOGD("before join recvThread");
	join_thread(recvThread);
	LOGD("before join tickThread");
	join_thread(tickThread);
	free_mutex(sendBufferMutex);
	LOGD("before close socket");
	LOGD("before free send buffers");
	while(emptySendBuffers.size()>0){
		delete emptySendBuffers[emptySendBuffers.size()-1];
		emptySendBuffers.pop_back();
	}
	while(sendQueue->Size()>0){
		void* p=sendQueue->Get();
		if(p)
			delete (CBufferOutputStream*)p;
	}
	LOGD("before delete jitter buffer");
	if(jitterBuffer){
		delete jitterBuffer;
	}
	LOGD("before stop decoder");
	if(decoder){
		decoder->Stop();
	}
	LOGD("before delete audio input");
	if(audioInput){
		delete audioInput;
	}
	LOGD("before delete encoder");
	if(encoder){
		encoder->Stop();
		delete encoder;
	}
	LOGD("before delete audio output");
	if(audioOutput){
		delete audioOutput;
	}
	LOGD("before delete decoder");
	if(decoder){
		delete decoder;
	}
	LOGD("before delete echo canceller");
	if(echoCanceller){
		echoCanceller->Stop();
		delete echoCanceller;
	}
	delete sendQueue;
	unsigned int i;
	for(i=0;i<incomingStreams.size();i++){
		free(incomingStreams[i]);
	}
	incomingStreams.clear();
	for(i=0;i<outgoingStreams.size();i++){
		free(outgoingStreams[i]);
	}
	outgoingStreams.clear();
	for(i=0;i<endpoints.size();i++){
		free(endpoints[i]);
	}
	free_mutex(queuedPacketsMutex);
	for(i=0;i<queuedPackets.size();i++){
		if(queuedPackets[i]->data)
			free(queuedPackets[i]->data);
		free(queuedPackets[i]);
	}
	delete conctl;
	LOGD("Left CVoIPController::~CVoIPController");
	if(tgvoipLogFile){
		FILE* log=tgvoipLogFile;
		tgvoipLogFile=NULL;
		fclose(log);
	}
}

void CVoIPController::SetRemoteEndpoints(voip_endpoint_t* endpoints, size_t count, bool allowP2p){
	LOGW("Set remote endpoints");
	assert(count>0);
	preferredRelay=NULL;
	size_t i;
	for(i=0;i<count;i++){
		voip_endpoint_t* ep=(voip_endpoint_t *) malloc(sizeof(voip_endpoint_t));
		memcpy(ep, &endpoints[i], sizeof(voip_endpoint_t));
		ep->_averageRtt=0;
		ep->_lastPingTime=0;
		memset(ep->_rtts, 0, sizeof(double)*6);
		this->endpoints.push_back(ep);
		if(ep->type==EP_TYPE_UDP_RELAY && !preferredRelay)
			preferredRelay=ep;
	}
	currentEndpoint=this->endpoints[0];
	this->allowP2p=allowP2p;
}

void* CVoIPController::StartRecvThread(void* controller){
	((CVoIPController*)controller)->RunRecvThread();
	return NULL;
}

void* CVoIPController::StartSendThread(void* controller){
	((CVoIPController*)controller)->RunSendThread();
	return NULL;
}


void* CVoIPController::StartTickThread(void* controller){
	((CVoIPController*) controller)->RunTickThread();
	return NULL;
}


void CVoIPController::Start(){
	int res;
	LOGW("Starting voip controller");
	int32_t cfgFrameSize=CVoIPServerConfig::GetSharedInstance()->GetInt("audio_frame_size", 60);
	if(cfgFrameSize==20 || cfgFrameSize==40 || cfgFrameSize==60)
		outgoingStreams[0]->frameDuration=(uint16_t) cfgFrameSize;
	udpSocket=socket(PF_INET6, SOCK_DGRAM, IPPROTO_UDP);
	if(udpSocket<0){
		LOGE("error creating socket: %d / %s", errno, strerror(errno));
	}
	int flag=0;
	res=setsockopt(udpSocket, IPPROTO_IPV6, IPV6_V6ONLY, &flag, sizeof(flag));
	if(res<0){
		LOGE("error enabling dual stack socket: %d / %s", errno, strerror(errno));
	}
#ifdef __APPLE__
	int prio=NET_SERVICE_TYPE_VO;
	res=setsockopt(udpSocket, SOL_SOCKET, SO_NET_SERVICE_TYPE, &prio, sizeof(prio));
	if(res<0){
		LOGE("error setting darwin-specific net priority: %d / %s", errno, strerror(errno));
	}
#else
	int prio=5;
	res=setsockopt(udpSocket, SOL_SOCKET, SO_PRIORITY, &prio, sizeof(prio));
	if(res<0){
		LOGE("error setting priority: %d / %s", errno, strerror(errno));
	}
	prio=6 << 5;
	res=setsockopt(udpSocket, SOL_IP, IP_TOS, &prio, sizeof(prio));
	if(res<0){
		LOGE("error setting ip tos: %d / %s", errno, strerror(errno));
	}
#endif
	int tries=0;
	sockaddr_in6 addr;
	//addr.sin6_addr.s_addr=0;
	memset(&addr, 0, sizeof(sockaddr_in6));
	//addr.sin6_len=sizeof(sa_family_t);
	addr.sin6_family=AF_INET6;
	for(tries=0;tries<10;tries++){
		addr.sin6_port=htons(GenerateLocalUDPPort());
		res=::bind(udpSocket, (sockaddr *) &addr, sizeof(sockaddr_in6));
		LOGV("trying bind to port %u", ntohs(addr.sin6_port));
		if(res<0){
			LOGE("error binding to port %u: %d / %s", ntohs(addr.sin6_port), errno, strerror(errno));
		}else{
			break;
		}
	}
	if(tries==10){
		addr.sin6_port=0;
		res=::bind(udpSocket, (sockaddr *) &addr, sizeof(sockaddr_in6));
		if(res<0){
			LOGE("error binding to port %u: %d / %s", ntohs(addr.sin6_port), errno, strerror(errno));
			SetState(STATE_FAILED);
			return;
		}
	}
	size_t addrLen=sizeof(sockaddr_in6);
	getsockname(udpSocket, (sockaddr*)&addr, (socklen_t*) &addrLen);
	localUdpPort=ntohs(addr.sin6_port);
	LOGD("Bound to local UDP port %u", ntohs(addr.sin6_port));
	
    SendPacket(NULL, 0, currentEndpoint);

	runReceiver=true;
	start_thread(recvThread, StartRecvThread, this);
	set_thread_priority(recvThread, get_thread_max_priority());
	set_thread_name(recvThread, "voip-recv");
	start_thread(sendThread, StartSendThread, this);
	set_thread_priority(sendThread, get_thread_max_priority());
	set_thread_name(sendThread, "voip-send");
	start_thread(tickThread, StartTickThread, this);
	set_thread_priority(tickThread, get_thread_max_priority());
	set_thread_name(tickThread, "voip-tick");
}

size_t CVoIPController::AudioInputCallback(unsigned char* data, size_t length, void* param){
	((CVoIPController*)param)->HandleAudioInput(data, length);
	return 0;
}

void CVoIPController::HandleAudioInput(unsigned char *data, size_t len){
	if(stopping)
		return;
	if(waitingForAcks || dontSendPackets>0){
		LOGV("waiting for RLC, dropping outgoing audio packet");
		return;
	}
	int audioPacketGrouping=1;
	CBufferOutputStream* pkt=NULL;
	if(audioPacketsWritten==0){
		pkt=GetOutgoingPacketBuffer();
		if(!pkt){
			LOGW("Dropping data packet, queue overflow");
			return;
		}
		currentAudioPacket=pkt;
	}else{
		pkt=currentAudioPacket;
	}
	unsigned char flags=(unsigned char) (len>255 ? STREAM_DATA_FLAG_LEN16 : 0);
	pkt->WriteByte((unsigned char) (1 | flags)); // streamID + flags
	if(len>255)
		pkt->WriteInt16((int16_t)len);
	else
		pkt->WriteByte((unsigned char)len);
	pkt->WriteInt32(audioTimestampOut);
	pkt->WriteBytes(data, len);
	audioPacketsWritten++;
	if(audioPacketsWritten>=audioPacketGrouping){
		uint32_t pl=pkt->GetLength();
		unsigned char tmp[pl];
		memcpy(tmp, pkt->GetBuffer(), pl);
		pkt->Reset();
		unsigned char type;
		switch(audioPacketGrouping){
			case 2:
				type=PKT_STREAM_DATA_X2;
				break;
			case 3:
				type=PKT_STREAM_DATA_X3;
				break;
			default:
				type=PKT_STREAM_DATA;
				break;
		}
		WritePacketHeader(pkt, type, pl);
		pkt->WriteBytes(tmp, pl);
		//LOGI("payload size %u", pl);
		if(pl<253)
			pl+=1;
		for(;pl%4>0;pl++)
			pkt->WriteByte(0);
		sendQueue->Put(pkt);
		audioPacketsWritten=0;
	}
	audioTimestampOut+=outgoingStreams[0]->frameDuration;
}

void CVoIPController::Connect(){
	assert(state!=STATE_WAIT_INIT_ACK);
	connectionInitTime=GetCurrentTime();
	SendInit();
}


void CVoIPController::SetEncryptionKey(char *key, bool isOutgoing){
	memcpy(encryptionKey, key, 256);
	uint8_t sha1[SHA1_LENGTH];
	crypto.sha1((uint8_t*) encryptionKey, 256, sha1);
	memcpy(keyFingerprint, sha1+(SHA1_LENGTH-8), 8);
	uint8_t sha256[SHA256_LENGTH];
	crypto.sha256((uint8_t*) encryptionKey, 256, sha256);
	memcpy(callID, sha256+(SHA256_LENGTH-16), 16);
	this->isOutgoing=isOutgoing;
}

uint32_t CVoIPController::WritePacketHeader(CBufferOutputStream *s, unsigned char type, uint32_t length){
	uint32_t acks=0;
	int i;
	for(i=0;i<32;i++){
		if(recvPacketTimes[i]>0)
			acks|=1;
		if(i<31)
			acks<<=1;
	}

	uint32_t pseq=seq++;

	if(state==STATE_WAIT_INIT || state==STATE_WAIT_INIT_ACK){
		s->WriteInt32(TLID_DECRYPTED_AUDIO_BLOCK);
		int64_t randomID;
		crypto.rand_bytes((uint8_t *) &randomID, 8);
		s->WriteInt64(randomID);
		unsigned char randBytes[7];
		crypto.rand_bytes(randBytes, 7);
		s->WriteByte(7);
		s->WriteBytes(randBytes, 7);
		uint32_t pflags=PFLAG_HAS_RECENT_RECV | PFLAG_HAS_SEQ;
		if(length>0)
			pflags|=PFLAG_HAS_DATA;
		if(state==STATE_WAIT_INIT || state==STATE_WAIT_INIT_ACK){
			pflags|=PFLAG_HAS_CALL_ID | PFLAG_HAS_PROTO;
		}
		pflags|=((uint32_t) type) << 24;
		s->WriteInt32(pflags);

		if(pflags & PFLAG_HAS_CALL_ID){
			s->WriteBytes(callID, 16);
		}
		s->WriteInt32(lastRemoteSeq);
		s->WriteInt32(pseq);
		s->WriteInt32(acks);
		if(pflags & PFLAG_HAS_PROTO){
			s->WriteInt32(PROTOCOL_NAME);
		}
		if(length>0){
			if(length<=253){
				s->WriteByte((unsigned char) length);
			}else{
				s->WriteByte(254);
				s->WriteByte((unsigned char) (length & 0xFF));
				s->WriteByte((unsigned char) ((length >> 8) & 0xFF));
				s->WriteByte((unsigned char) ((length >> 16) & 0xFF));
			}
		}
	}else{
		s->WriteInt32(TLID_SIMPLE_AUDIO_BLOCK);
		int64_t randomID;
		crypto.rand_bytes((uint8_t *) &randomID, 8);
		s->WriteInt64(randomID);
		unsigned char randBytes[7];
		crypto.rand_bytes(randBytes, 7);
		s->WriteByte(7);
		s->WriteBytes(randBytes, 7);
		uint32_t lenWithHeader=length+13;
		if(lenWithHeader>0){
			if(lenWithHeader<=253){
				s->WriteByte((unsigned char) lenWithHeader);
			}else{
				s->WriteByte(254);
				s->WriteByte((unsigned char) (lenWithHeader & 0xFF));
				s->WriteByte((unsigned char) ((lenWithHeader >> 8) & 0xFF));
				s->WriteByte((unsigned char) ((lenWithHeader >> 16) & 0xFF));
			}
		}
		s->WriteByte(type);
		s->WriteInt32(lastRemoteSeq);
		s->WriteInt32(pseq);
		s->WriteInt32(acks);
	}

	if(type==PKT_STREAM_DATA || type==PKT_STREAM_DATA_X2 || type==PKT_STREAM_DATA_X3)
		conctl->PacketSent(pseq, length);

	memmove(&sentPacketTimes[1], sentPacketTimes, 31*sizeof(double));
	sentPacketTimes[0]=GetCurrentTime();
	lastSentSeq=pseq;
	//LOGI("packet header size %d", s->GetLength());

	return pseq;
}


void CVoIPController::UpdateAudioBitrate(){
	if(encoder){
		if(dataSavingMode || dataSavingRequestedByPeer){
			maxBitrate=maxAudioBitrateSaving;
			encoder->SetBitrate(initAudioBitrateSaving);
		}else if(networkType==NET_TYPE_GPRS){
			maxBitrate=maxAudioBitrateGPRS;
			encoder->SetBitrate(initAudioBitrateGPRS);
		}else if(networkType==NET_TYPE_EDGE){
			maxBitrate=maxAudioBitrateEDGE;
			encoder->SetBitrate(initAudioBitrateEDGE);
		}else{
			maxBitrate=maxAudioBitrate;
			encoder->SetBitrate(initAudioBitrate);
		}
	}
}


void CVoIPController::SendInit(){
	CBufferOutputStream* out=new CBufferOutputStream(1024);
	WritePacketHeader(out, PKT_INIT, 15);
	out->WriteInt32(PROTOCOL_VERSION);
	out->WriteInt32(MIN_PROTOCOL_VERSION);
	uint32_t flags=0;
	if(dataSavingMode)
		flags|=INIT_FLAG_DATA_SAVING_ENABLED;
	out->WriteInt32(flags);
	out->WriteByte(1); // audio codecs count
	out->WriteByte(CODEC_OPUS);
	out->WriteByte(0); // video codecs count
	for(std::vector<voip_endpoint_t*>::const_iterator itr=endpoints.begin();itr!=endpoints.end();++itr){
		SendPacket(out->GetBuffer(), out->GetLength(), *itr);
	}
	SetState(STATE_WAIT_INIT_ACK);
	delete out;
}

void CVoIPController::SendInitAck(){

}

void CVoIPController::RunRecvThread(){
	LOGI("Receive thread starting");
	unsigned char buffer[1024];
	sockaddr_in6 srcAddr;
	int addrLen;
	while(runReceiver){
		//LOGI("Before recv");
		addrLen=sizeof(sockaddr_in6);
		ssize_t len=recvfrom(udpSocket, buffer, 1024, 0, (sockaddr *) &srcAddr, (socklen_t *) &addrLen);
		//LOGV("Received %d bytes from %s:%d at %.5lf", len, inet_ntoa(srcAddr.sin_addr), ntohs(srcAddr.sin_port), GetCurrentTime());
		voip_endpoint_t* srcEndpoint=NULL;
		if(IN6_IS_ADDR_V4MAPPED(&srcAddr.sin6_addr) || (nat64Present && memcmp(nat64Prefix, srcAddr.sin6_addr.s6_addr, 12)==0)){
			in_addr v4addr=*((in_addr*)&srcAddr.sin6_addr.s6_addr[12]);
			int _i;
			for(_i=0;_i<endpoints.size();_i++){
				if(endpoints[_i]->address.s_addr==v4addr.s_addr && endpoints[_i]->port==ntohs(srcAddr.sin6_port)){
					srcEndpoint=endpoints[_i];
					break;
				}
			}
		}
		if(!srcEndpoint){
			char abuf[INET6_ADDRSTRLEN];
			LOGW("Received a packet from unknown source %s:%u", inet_ntop(AF_INET6, &srcAddr.sin6_addr, abuf, INET6_ADDRSTRLEN), ntohs(srcAddr.sin6_port));
			continue;
		}
		if(len<=0){
			LOGW("error receiving: %d / %s", errno, strerror(errno));
			continue;
		}
		if(IS_MOBILE_NETWORK(networkType))
			stats.bytesRecvdMobile+=(uint64_t)len;
		else
			stats.bytesRecvdWifi+=(uint64_t)len;
		CBufferInputStream* in=new CBufferInputStream(buffer, (size_t)len);
		try{
		if(memcmp(buffer, srcEndpoint->type==EP_TYPE_UDP_RELAY ? srcEndpoint->peerTag : callID, 16)!=0){
			LOGW("Received packet has wrong peerTag");
			delete in;
			continue;
		}
		in->Seek(16);
		if(waitingForRelayPeerInfo && in->Remaining()>=32){
			bool isPublicIpResponse=true;
			int i;
			for(i=0;i<12;i++){
				if((unsigned char)buffer[in->GetOffset()+i]!=0xFF){
					isPublicIpResponse=false;
					break;
				}
			}
            
			if(isPublicIpResponse){
				waitingForRelayPeerInfo=false;
				in->Seek(in->GetOffset()+12);
				uint32_t tlid=(uint32_t) in->ReadInt32();
				if(tlid==TLID_UDP_REFLECTOR_PEER_INFO){
					uint32_t myAddr=(uint32_t) in->ReadInt32();
					uint32_t myPort=(uint32_t) in->ReadInt32();
					uint32_t peerAddr=(uint32_t) in->ReadInt32();
					uint32_t peerPort=(uint32_t) in->ReadInt32();
					voip_endpoint_t* p2pEndpoint=NULL;
					for(i=0;i<endpoints.size();i++){
						if(endpoints[i]->type==EP_TYPE_UDP_P2P_INET){
							p2pEndpoint=endpoints[i];
							break;
						}
					}
					if(!p2pEndpoint){
						p2pEndpoint=(voip_endpoint_t *) malloc(sizeof(voip_endpoint_t));
						endpoints.push_back(p2pEndpoint);
					}
					memset(p2pEndpoint, 0, sizeof(voip_endpoint_t));
					p2pEndpoint->type=EP_TYPE_UDP_P2P_INET;
					p2pEndpoint->port=peerPort;
					p2pEndpoint->address.s_addr=peerAddr;//ntohl(peerAddr);
					LOGW("Received reflector peer info, my=%08X:%u, peer=%08X:%u", myAddr, myPort, peerAddr, peerPort);
					if(myAddr==peerAddr){
						LOGW("Detected LAN");
						in_addr lanAddr;
						GetLocalNetworkItfInfo(&lanAddr, NULL);
						CBufferOutputStream* pkt=GetOutgoingPacketBuffer();
						if(pkt){
							WritePacketHeader(pkt, PKT_LAN_ENDPOINT, 8);
							pkt->WriteInt32(lanAddr.s_addr);
							pkt->WriteInt32(localUdpPort);
							sendQueue->Put(pkt);
						}
					}else{
						for(i=0;i<endpoints.size();i++){
							if(endpoints[i]->type==EP_TYPE_UDP_P2P_LAN){
								free(endpoints[i]);
								endpoints.erase(endpoints.begin()+i);
								break;
							}
						}
					}
					p2pPingCount=0;
					lastP2pPingTime=0;
					needSendP2pPing=true;
				}else{
					LOGE("It looks like a reflector response but tlid is %08X, expected %08X", tlid, TLID_UDP_REFLECTOR_PEER_INFO);
				}
				delete in;
				continue;
			}
		}
		if(in->Remaining()<40){
			delete in;
			continue;
		}

		unsigned char fingerprint[8], msgHash[16];
		in->ReadBytes(fingerprint, 8);
		in->ReadBytes(msgHash, 16);
		if(memcmp(fingerprint, keyFingerprint, 8)!=0){
			LOGW("Received packet has wrong key fingerprint");
			delete in;
			continue;
		}
		unsigned char key[32], iv[32];
		KDF(msgHash, isOutgoing ? 8 : 0, key, iv);
        unsigned char aesOut[in->Remaining()];
		crypto.aes_ige_decrypt((unsigned char *) buffer+in->GetOffset(), aesOut, in->Remaining(), key, iv);
        memcpy(buffer+in->GetOffset(), aesOut, in->Remaining());
		unsigned char sha[SHA1_LENGTH];
		uint32_t _len=(uint32_t) in->ReadInt32();
		if(_len>in->Remaining())
			_len=in->Remaining();
		crypto.sha1((uint8_t *) (buffer+in->GetOffset()-4), (size_t) (_len+4), sha);
		if(memcmp(msgHash, sha+(SHA1_LENGTH-16), 16)!=0){
			LOGW("Received packet has wrong hash after decryption");
			delete in;
			continue;
		}

		lastRecvPacketTime=GetCurrentTime();


		/*decryptedAudioBlock random_id:long random_bytes:string flags:# voice_call_id:flags.2?int128 in_seq_no:flags.4?int out_seq_no:flags.4?int
	 * recent_received_mask:flags.5?int proto:flags.3?int extra:flags.1?string raw_data:flags.0?string = DecryptedAudioBlock
simpleAudioBlock random_id:long random_bytes:string raw_data:string = DecryptedAudioBlock;
*/
		uint32_t ackId, pseq, acks;
		unsigned char type;
		uint32_t tlid=(uint32_t) in->ReadInt32();
		uint32_t packetInnerLen;
		if(tlid==TLID_DECRYPTED_AUDIO_BLOCK){
			in->ReadInt64(); // random id
			uint32_t randLen=(uint32_t) in->ReadTlLength();
			in->Seek(in->GetOffset()+randLen+pad4(randLen));
			uint32_t flags=(uint32_t) in->ReadInt32();
			type=(unsigned char) ((flags >> 24) & 0xFF);
			if(!(flags & PFLAG_HAS_SEQ && flags & PFLAG_HAS_RECENT_RECV)){
				LOGW("Received packet doesn't have PFLAG_HAS_SEQ, PFLAG_HAS_RECENT_RECV, or both");
				delete in;
				continue;
			}
			if(flags & PFLAG_HAS_CALL_ID){
				unsigned char pktCallID[16];
				in->ReadBytes(pktCallID, 16);
				if(memcmp(pktCallID, callID, 16)!=0){
					LOGW("Received packet has wrong call id");
					delete in;
					lastError=ERROR_UNKNOWN;
					SetState(STATE_FAILED);
					return;
				}
			}
			ackId=(uint32_t) in->ReadInt32();
			pseq=(uint32_t) in->ReadInt32();
			acks=(uint32_t) in->ReadInt32();
			if(flags & PFLAG_HAS_PROTO){
				uint32_t proto=(uint32_t) in->ReadInt32();
				if(proto!=PROTOCOL_NAME){
					LOGW("Received packet uses wrong protocol");
					delete in;
					lastError=ERROR_INCOMPATIBLE;
					SetState(STATE_FAILED);
					return;
				}
			}
			if(flags & PFLAG_HAS_EXTRA){
				uint32_t extraLen=(uint32_t) in->ReadTlLength();
				in->Seek(in->GetOffset()+extraLen+pad4(extraLen));
			}
			if(flags & PFLAG_HAS_DATA){
				packetInnerLen=in->ReadTlLength();
			}
		}else if(tlid==TLID_SIMPLE_AUDIO_BLOCK){
			in->ReadInt64(); // random id
			uint32_t randLen=(uint32_t) in->ReadTlLength();
			in->Seek(in->GetOffset()+randLen+pad4(randLen));
			packetInnerLen=in->ReadTlLength();
			type=in->ReadByte();
			ackId=(uint32_t) in->ReadInt32();
			pseq=(uint32_t) in->ReadInt32();
			acks=(uint32_t) in->ReadInt32();
		}else{
			LOGW("Received a packet of unknown type %08X", tlid);
			delete in;
			continue;
		}
		packetsRecieved++;
		if(seqgt(pseq, lastRemoteSeq)){
			uint32_t diff=pseq-lastRemoteSeq;
			if(diff>31){
				memset(recvPacketTimes, 0, 32*sizeof(double));
			}else{
				memmove(&recvPacketTimes[diff], recvPacketTimes, (32-diff)*sizeof(double));
				if(diff>1){
					memset(recvPacketTimes, 0, diff*sizeof(double));
				}
				recvPacketTimes[0]=GetCurrentTime();
			}
			lastRemoteSeq=pseq;
		}else if(!seqgt(pseq, lastRemoteSeq) && lastRemoteSeq-pseq<32){
			if(recvPacketTimes[lastRemoteSeq-pseq]!=0){
				LOGW("Received duplicated packet for seq %u", pseq);
				delete in;
				continue;
			}
			recvPacketTimes[lastRemoteSeq-pseq]=GetCurrentTime();
		}else if(lastRemoteSeq-pseq>=32){
			LOGW("Packet %u is out of order and too late", pseq);
			delete in;
			continue;
		}
		if(seqgt(ackId, lastRemoteAckSeq)){
			uint32_t diff=ackId-lastRemoteAckSeq;
			if(diff>31){
				memset(remoteAcks, 0, 32*sizeof(double));
			}else{
				memmove(&remoteAcks[diff], remoteAcks, (32-diff)*sizeof(double));
				if(diff>1){
					memset(remoteAcks, 0, diff*sizeof(double));
				}
				remoteAcks[0]=GetCurrentTime();
			}
			if(waitingForAcks && lastRemoteAckSeq>=firstSentPing){
				memset(rttHistory, 0, 32*sizeof(double));
				waitingForAcks=false;
				dontSendPackets=10;
				LOGI("resuming sending");
			}
			lastRemoteAckSeq=ackId;
			conctl->PacketAcknowledged(ackId);
			int i;
			for(i=0;i<31;i++){
				if(remoteAcks[i+1]==0){
					if((acks >> (31-i)) & 1){
						remoteAcks[i+1]=GetCurrentTime();
						conctl->PacketAcknowledged(ackId-(i+1));
					}
				}
			}
			lock_mutex(queuedPacketsMutex);
			for(i=0;i<queuedPackets.size();i++){
				voip_queued_packet_t* qp=queuedPackets[i];
				int j;
				bool didAck=false;
				for(j=0;j<16;j++){
					LOGD("queued packet %u, seq %u=%u", i, j, qp->seqs[j]);
					if(qp->seqs[j]==0)
						break;
                    int remoteAcksIndex=lastRemoteAckSeq-qp->seqs[j];
					LOGV("remote acks index %u, value %f", remoteAcksIndex, remoteAcksIndex>=0 && remoteAcksIndex<32 ? remoteAcks[remoteAcksIndex] : -1);
					if(seqgt(lastRemoteAckSeq, qp->seqs[j]) && remoteAcksIndex>=0 && remoteAcksIndex<32 && remoteAcks[remoteAcksIndex]>0){
						LOGD("did ack seq %u, removing", qp->seqs[j]);
						didAck=true;
						break;
					}
				}
				if(didAck){
					if(qp->data)
						free(qp->data);
					free(qp);
					queuedPackets.erase(queuedPackets.begin()+i);
					i--;
					continue;
				}
			}
			unlock_mutex(queuedPacketsMutex);
		}

		if(srcEndpoint!=currentEndpoint && srcEndpoint->type==EP_TYPE_UDP_RELAY && currentEndpoint->type!=EP_TYPE_UDP_RELAY){
			if(seqgt(lastSentSeq-32, lastRemoteAckSeq)){
				currentEndpoint=srcEndpoint;
				LOGI("Peer network address probably changed, switching to relay");
				if(allowP2p)
					SendPublicEndpointsRequest();
			}
		}
		//LOGV("acks: %u -> %.2lf, %.2lf, %.2lf, %.2lf, %.2lf, %.2lf, %.2lf, %.2lf", lastRemoteAckSeq, remoteAcks[0], remoteAcks[1], remoteAcks[2], remoteAcks[3], remoteAcks[4], remoteAcks[5], remoteAcks[6], remoteAcks[7]);
		//LOGD("recv: %u -> %.2lf, %.2lf, %.2lf, %.2lf, %.2lf, %.2lf, %.2lf, %.2lf", lastRemoteSeq, recvPacketTimes[0], recvPacketTimes[1], recvPacketTimes[2], recvPacketTimes[3], recvPacketTimes[4], recvPacketTimes[5], recvPacketTimes[6], recvPacketTimes[7]);
		//LOGI("RTT = %.3lf", GetAverageRTT());
		//LOGV("Packet %u type is %d", pseq, type);
		if(type==PKT_INIT){
			LOGD("Received init");
			if(!receivedInit){
				receivedInit=true;
				currentEndpoint=srcEndpoint;
				if(srcEndpoint->type==EP_TYPE_UDP_RELAY)
					preferredRelay=srcEndpoint;
				LogDebugInfo();
			}
			peerVersion=(uint32_t) in->ReadInt32();
			LOGI("Peer version is %d", peerVersion);
			uint32_t minVer=(uint32_t) in->ReadInt32();
			if(minVer>PROTOCOL_VERSION || peerVersion<MIN_PROTOCOL_VERSION){
				lastError=ERROR_INCOMPATIBLE;
				delete in;
				SetState(STATE_FAILED);
				return;
			}
			uint32_t flags=(uint32_t) in->ReadInt32();
			if(flags & INIT_FLAG_DATA_SAVING_ENABLED){
				dataSavingRequestedByPeer=true;
				UpdateDataSavingState();
				UpdateAudioBitrate();
			}
			
			int i;
			int numSupportedAudioCodecs=in->ReadByte();
			for(i=0; i<numSupportedAudioCodecs; i++){
				in->ReadByte(); // ignore for now
			}
			int numSupportedVideoCodecs=in->ReadByte();
			for(i=0; i<numSupportedVideoCodecs; i++){
				in->ReadByte(); // ignore for now
			}

			CBufferOutputStream *out=new CBufferOutputStream(1024);
			WritePacketHeader(out, PKT_INIT_ACK, (peerVersion>=2 ? 10 : 2)+(peerVersion>=2 ? 6 : 4)*outgoingStreams.size());
			if(peerVersion>=2){
				out->WriteInt32(PROTOCOL_VERSION);
				out->WriteInt32(MIN_PROTOCOL_VERSION);
			}
			
			out->WriteByte((unsigned char) outgoingStreams.size());
			for(i=0; i<outgoingStreams.size(); i++){
				out->WriteByte(outgoingStreams[i]->id);
				out->WriteByte(outgoingStreams[i]->type);
				out->WriteByte(outgoingStreams[i]->codec);
				if(peerVersion>=2)
					out->WriteInt16(outgoingStreams[i]->frameDuration);
				else
					outgoingStreams[i]->frameDuration=20;
				out->WriteByte((unsigned char) (outgoingStreams[i]->enabled ? 1 : 0));
			}
			SendPacket(out->GetBuffer(), out->GetLength(), currentEndpoint);
			delete out;
		}
		if(type==PKT_INIT_ACK){
			LOGD("Received init ack");

			if(!receivedInitAck){
				receivedInitAck=true;
				if(packetInnerLen>10){
					peerVersion=in->ReadInt32();
					uint32_t minVer=(uint32_t) in->ReadInt32();
					if(minVer>PROTOCOL_VERSION || peerVersion<MIN_PROTOCOL_VERSION){
						lastError=ERROR_INCOMPATIBLE;
						delete in;
						SetState(STATE_FAILED);
						return;
					}
				}else{
					peerVersion=1;
				}

				LOGI("peer version from init ack %d", peerVersion);

				unsigned char streamCount=in->ReadByte();
				if(streamCount==0)
					goto malformed_packet;

				int i;
				voip_stream_t *incomingAudioStream=NULL;
				for(i=0; i<streamCount; i++){
					voip_stream_t *stm=(voip_stream_t *) malloc(sizeof(voip_stream_t));
					stm->id=in->ReadByte();
					stm->type=in->ReadByte();
					stm->codec=in->ReadByte();
					if(peerVersion>=2)
						stm->frameDuration=(uint16_t) in->ReadInt16();
					else
						stm->frameDuration=20;
					stm->enabled=in->ReadByte()==1;
					incomingStreams.push_back(stm);
					if(stm->type==STREAM_TYPE_AUDIO && !incomingAudioStream)
						incomingAudioStream=stm;
				}
				if(!incomingAudioStream)
					goto malformed_packet;

				voip_stream_t *outgoingAudioStream=outgoingStreams[0];

				if(!audioInput){
					LOGI("before create audio io");
					audioInput=CAudioInput::Create();
					audioInput->Configure(48000, 16, 1);
					audioOutput=CAudioOutput::Create();
					audioOutput->Configure(48000, 16, 1);
					echoCanceller=new CEchoCanceller(config.enableAEC, config.enableNS, config.enableAGC);
					encoder=new COpusEncoder(audioInput);
					encoder->SetCallback(AudioInputCallback, this);
					encoder->SetOutputFrameDuration(outgoingAudioStream->frameDuration);
					encoder->SetEchoCanceller(echoCanceller);
					encoder->Start();
					if(!micMuted){
						audioInput->Start();
						if(!audioInput->IsInitialized()){
							lastError=ERROR_AUDIO_IO;
							delete in;
							SetState(STATE_FAILED);
							return;
						}
					}
					UpdateAudioBitrate();

					jitterBuffer=new CJitterBuffer(NULL, incomingAudioStream->frameDuration);
					decoder=new COpusDecoder(audioOutput);
					decoder->SetEchoCanceller(echoCanceller);
					decoder->SetJitterBuffer(jitterBuffer);
					decoder->SetFrameDuration(incomingAudioStream->frameDuration);
					decoder->Start();
					if(incomingAudioStream->frameDuration>50)
						jitterBuffer->SetMinPacketCount(CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_initial_delay_60", 3));
					else if(incomingAudioStream->frameDuration>30)
						jitterBuffer->SetMinPacketCount(CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_initial_delay_40", 4));
					else
						jitterBuffer->SetMinPacketCount(CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_initial_delay_20", 6));
					//audioOutput->Start();
#ifdef TGVOIP_USE_AUDIO_SESSION
#ifdef __APPLE__
					if(acquireAudioSession){
						acquireAudioSession(^(){
							LOGD("Audio session acquired");
							needNotifyAcquiredAudioSession=true;
						});
					}else{
						CAudioUnitIO::AudioSessionAcquired();
					}
#endif
#endif
				}
				SetState(STATE_ESTABLISHED);
				if(allowP2p)
					SendPublicEndpointsRequest();
			}
		}
		if(type==PKT_STREAM_DATA || type==PKT_STREAM_DATA_X2 || type==PKT_STREAM_DATA_X3){
			int count;
			switch(type){
				case PKT_STREAM_DATA_X2:
					count=2;
					break;
				case PKT_STREAM_DATA_X3:
					count=3;
					break;
				case PKT_STREAM_DATA:
				default:
					count=1;
					break;
			}
			int i;
			for(i=0;i<count;i++){
				unsigned char streamID=in->ReadByte();
				unsigned char flags=(unsigned char) (streamID & 0xC0);
				uint16_t sdlen=(uint16_t) (flags & STREAM_DATA_FLAG_LEN16 ? in->ReadInt16() : in->ReadByte());
				uint32_t pts=(uint32_t) in->ReadInt32();
				//LOGD("stream data, pts=%d, len=%d, rem=%d", pts, sdlen, in->Remaining());
				audioTimestampIn=pts;
				if(!audioOutStarted && audioOutput){
					audioOutput->Start();
					audioOutStarted=true;
				}
				if(jitterBuffer)
					jitterBuffer->HandleInput((unsigned char*) (buffer+in->GetOffset()), sdlen, pts);
				if(i<count-1)
					in->Seek(in->GetOffset()+sdlen);
			}
		}
		if(type==PKT_PING){
			LOGD("Received ping from %s:%d", inet_ntoa(srcEndpoint->address), srcEndpoint->port);
			if(srcEndpoint->type!=EP_TYPE_UDP_RELAY && !allowP2p){
				LOGW("Received p2p ping but p2p is disabled by manual override");
				delete in;
				continue;
			}
			if(srcEndpoint==currentEndpoint){
				CBufferOutputStream *pkt=GetOutgoingPacketBuffer();
				if(!pkt){
					LOGW("Dropping pong packet, queue overflow");
					delete in;
					continue;
				}
				WritePacketHeader(pkt, PKT_PONG, 4);
				pkt->WriteInt32(pseq);
				sendQueue->Put(pkt);
			}else{
				CBufferOutputStream pkt(32);
				WritePacketHeader(&pkt, PKT_PONG, 4);
				pkt.WriteInt32(pseq);
				SendPacket(pkt.GetBuffer(), pkt.GetLength(), srcEndpoint);
			}
		}
		if(type==PKT_PONG){
			if(packetInnerLen>=4){
				uint32_t pingSeq=(uint32_t) in->ReadInt32();
				if(pingSeq==srcEndpoint->_lastPingSeq){
					memmove(&srcEndpoint->_rtts[1], srcEndpoint->_rtts, sizeof(double)*5);
					srcEndpoint->_rtts[0]=GetCurrentTime()-srcEndpoint->_lastPingTime;
					int i;
					srcEndpoint->_averageRtt=0;
					for(i=0;i<6;i++){
						if(srcEndpoint->_rtts[i]==0)
							break;
						srcEndpoint->_averageRtt+=srcEndpoint->_rtts[i];
					}
					srcEndpoint->_averageRtt/=i;
					LOGD("Current RTT via %s: %.3llf, average: %.3llf", inet_ntoa(srcEndpoint->address), srcEndpoint->_rtts[0], srcEndpoint->_averageRtt);
				}
			}
			/*if(currentEndpoint!=srcEndpoint && (srcEndpoint->type==EP_TYPE_UDP_P2P_INET || srcEndpoint->type==EP_TYPE_UDP_P2P_LAN)){
				LOGI("Switching to P2P now!");
				currentEndpoint=srcEndpoint;
				needSendP2pPing=false;
			}*/
		}
		if(type==PKT_STREAM_STATE){
			unsigned char id=in->ReadByte();
			unsigned char enabled=in->ReadByte();
			int i;
			for(i=0;i<incomingStreams.size();i++){
				if(incomingStreams[i]->id==id){
					incomingStreams[i]->enabled=enabled==1;
					UpdateAudioOutputState();
					break;
				}
			}
		}
		if(type==PKT_LAN_ENDPOINT){
			uint32_t peerAddr=(uint32_t) in->ReadInt32();
			uint16_t peerPort=(uint16_t) in->ReadInt32();
			voip_endpoint_t* p2pEndpoint=GetEndpointByType(EP_TYPE_UDP_P2P_LAN);
			if(!p2pEndpoint){
				p2pEndpoint=(voip_endpoint_t *) malloc(sizeof(voip_endpoint_t));
				endpoints.push_back(p2pEndpoint);
			}
			memset(p2pEndpoint, 0, sizeof(voip_endpoint_t));
			p2pEndpoint->type=EP_TYPE_UDP_P2P_LAN;
			p2pEndpoint->port=peerPort;
			p2pEndpoint->address.s_addr=peerAddr;//ntohl(peerAddr);
		}
		if(type==PKT_NETWORK_CHANGED){
			currentEndpoint=preferredRelay;
			if(allowP2p)
				SendPublicEndpointsRequest();
			if(peerVersion>=2){
				uint32_t flags=(uint32_t) in->ReadInt32();
				dataSavingRequestedByPeer=(flags & INIT_FLAG_DATA_SAVING_ENABLED)==INIT_FLAG_DATA_SAVING_ENABLED;
				UpdateDataSavingState();
				UpdateAudioBitrate();
			}
		}
			if(type==PKT_SWITCH_PREF_RELAY){
				uint64_t relayId=(uint64_t) in->ReadInt64();
				int i;
				for(i=0;i<endpoints.size();i++){
					if(endpoints[i]->type==EP_TYPE_UDP_RELAY && endpoints[i]->id==relayId){
						preferredRelay=endpoints[i];
						LOGD("Switching preferred relay to %s:%d", inet_ntoa(preferredRelay->address), preferredRelay->port);
						break;
					}
				}
				if(currentEndpoint->type==EP_TYPE_UDP_RELAY)
					currentEndpoint=preferredRelay;
			}
			/*if(type==PKT_SWITCH_TO_P2P && allowP2p){
				voip_endpoint_t* p2p=GetEndpointByType(EP_TYPE_UDP_P2P_INET);
				if(p2p){
					voip_endpoint_t* lan=GetEndpointByType(EP_TYPE_UDP_P2P_LAN);
					if(lan && lan->_averageRtt>0){
						LOGI("Switching to p2p (LAN)");
						currentEndpoint=lan;
					}else{
						if(lan)
							lan->_lastPingTime=0;
						if(p2p->_averageRtt>0){
							LOGI("Switching to p2p (Inet)");
							currentEndpoint=p2p;
						}else{
							p2p->_lastPingTime=0;
						}
					}
				}
			}*/
		}catch(std::out_of_range x){
			LOGW("Error parsing packet: %s", x.what());
		}
		malformed_packet:
		delete in;
	}
	LOGI("=== recv thread exiting ===");
}

void CVoIPController::RunSendThread(){
	while(runReceiver){
		CBufferOutputStream* pkt=(CBufferOutputStream *) sendQueue->GetBlocking();
		if(pkt){
			SendPacket(pkt->GetBuffer(), pkt->GetLength(), currentEndpoint);
			pkt->Reset();
			lock_mutex(sendBufferMutex);
			emptySendBuffers.push_back(pkt);
			unlock_mutex(sendBufferMutex);
		}
	}
	LOGI("=== send thread exiting ===");
}


void CVoIPController::RunTickThread(){
	uint32_t tickCount=0;
	bool wasWaitingForAcks=false;
	while(runReceiver){
		usleep(100000);
		tickCount++;
		if(tickCount%5==0 && state==STATE_ESTABLISHED){
			memmove(&rttHistory[1], rttHistory, 31*sizeof(double));
			rttHistory[0]=GetAverageRTT();
			/*if(rttHistory[16]>0){
				LOGI("rtt diff: %.3lf", rttHistory[0]-rttHistory[16]);
			}*/
			int i;
			double v=0;
			for(i=1;i<32;i++){
				v+=rttHistory[i-1]-rttHistory[i];
			}
			v=v/32;
			if(rttHistory[0]>10.0 && rttHistory[8]>10.0 && (networkType==NET_TYPE_EDGE || networkType==NET_TYPE_GPRS)){
				waitingForAcks=true;
			}else{
				waitingForAcks=false;
			}
			if(waitingForAcks)
				wasWaitingForAcks=false;
			//LOGI("%.3lf/%.3lf, rtt diff %.3lf, waiting=%d, queue=%d", rttHistory[0], rttHistory[8], v, waitingForAcks, sendQueue->Size());
			if(jitterBuffer){
				int lostCount=jitterBuffer->GetAndResetLostPacketCount();
				if(lostCount>0 || (lostCount<0 && recvLossCount>((uint32_t)-lostCount)))
					recvLossCount+=lostCount;
			}
		}
		if(dontSendPackets>0)
			dontSendPackets--;

		int i;

		conctl->Tick();

		if(state==STATE_ESTABLISHED){
			int act=conctl->GetBandwidthControlAction();
			if(act==TGVOIP_CONCTL_ACT_DECREASE){
				uint32_t bitrate=encoder->GetBitrate();
				if(bitrate>8000)
					encoder->SetBitrate(bitrate<(minAudioBitrate+audioBitrateStepDecr) ? minAudioBitrate : (bitrate-audioBitrateStepDecr));
			}else if(act==TGVOIP_CONCTL_ACT_INCREASE){
				uint32_t bitrate=encoder->GetBitrate();
				if(bitrate<maxBitrate)
					encoder->SetBitrate(bitrate+audioBitrateStepIncr);
			}

			if(tickCount%10==0 && encoder){
				uint32_t sendLossCount=conctl->GetSendLossCount();
				memmove(sendLossCountHistory+1, sendLossCountHistory, 31*sizeof(uint32_t));
				sendLossCountHistory[0]=sendLossCount-prevSendLossCount;
				prevSendLossCount=sendLossCount;
				double avgSendLossCount=0;
				for(i=0;i<10;i++){
					avgSendLossCount+=sendLossCountHistory[i];
				}
				double packetsPerSec=1000/(double)outgoingStreams[0]->frameDuration;
				avgSendLossCount=avgSendLossCount/10/packetsPerSec;
				//LOGV("avg send loss: %.1f%%", avgSendLossCount*100);

				if(avgSendLossCount>0.1){
					encoder->SetPacketLoss(40);
				}else if(avgSendLossCount>0.075){
					encoder->SetPacketLoss(35);
				}else if(avgSendLossCount>0.0625){
					encoder->SetPacketLoss(30);
				}else if(avgSendLossCount>0.05){
					encoder->SetPacketLoss(25);
				}else if(avgSendLossCount>0.025){
					encoder->SetPacketLoss(20);
				}else if(avgSendLossCount>0.01){
					encoder->SetPacketLoss(17);
				}else{
					encoder->SetPacketLoss(15);
				}
			}
		}

		bool areThereAnyEnabledStreams=false;

		for(i=0;i<outgoingStreams.size();i++){
			if(outgoingStreams[i]->enabled)
				areThereAnyEnabledStreams=true;
		}

		if((waitingForAcks && tickCount%10==0) || (!areThereAnyEnabledStreams && tickCount%2==0)){
			CBufferOutputStream* pkt=GetOutgoingPacketBuffer();
			if(!pkt){
				LOGW("Dropping ping packet, queue overflow");
				return;
			}
			uint32_t seq=WritePacketHeader(pkt, PKT_NOP, 0);
			firstSentPing=seq;
			sendQueue->Put(pkt);
			LOGV("sent ping");
		}

		if(state==STATE_WAIT_INIT_ACK && GetCurrentTime()-stateChangeTime>.5){
			SendInit();
		}

		/*if(needSendP2pPing){
			if(GetCurrentTime()-lastP2pPingTime>2){
				if(p2pPingCount<10){ // try hairpin routing first, even if we have a LAN address
					SendP2pPing(EP_TYPE_UDP_P2P_INET);
				}
				if(p2pPingCount>=5 && p2pPingCount<15){ // last resort to get p2p
					SendP2pPing(EP_TYPE_UDP_P2P_LAN);
				}
				p2pPingCount++;
			}
		}*/

		if(waitingForRelayPeerInfo && GetCurrentTime()-publicEndpointsReqTime>5){
			LOGD("Resending peer relay info request");
			SendPublicEndpointsRequest();
		}

		lock_mutex(queuedPacketsMutex);
		for(i=0;i<queuedPackets.size();i++){
			voip_queued_packet_t* qp=queuedPackets[i];
			if(qp->timeout>0 && qp->firstSentTime>0 && GetCurrentTime()-qp->firstSentTime>=qp->timeout){
				LOGD("Removing queued packet because of timeout");
				if(qp->data)
					free(qp->data);
				free(qp);
				queuedPackets.erase(queuedPackets.begin()+i);
				i--;
				continue;
			}
			if(GetCurrentTime()-qp->lastSentTime>=qp->retryInterval){
				CBufferOutputStream* pkt=GetOutgoingPacketBuffer();
				if(pkt){
					uint32_t seq=WritePacketHeader(pkt, qp->type, qp->length);
					memmove(&qp->seqs[1], qp->seqs, 4*9);
					qp->seqs[0]=seq;
					qp->lastSentTime=GetCurrentTime();
					LOGD("Sending queued packet, seq=%u, type=%u, len=%u", seq, qp->type, qp->length);
					if(qp->firstSentTime==0)
						qp->firstSentTime=qp->lastSentTime;
					if(qp->length)
						pkt->WriteBytes(qp->data, qp->length);
					sendQueue->Put(pkt);
				}
			}
		}
		unlock_mutex(queuedPacketsMutex);

		if(jitterBuffer)
			jitterBuffer->Tick();

		if(state==STATE_ESTABLISHED){
			voip_endpoint_t* minPingRelay=preferredRelay;
			double minPing=preferredRelay->_averageRtt;
			for(i=0;i<endpoints.size();i++){
				voip_endpoint_t* e=endpoints[i];
				if(GetCurrentTime()-e->_lastPingTime>=10){
					LOGV("Sending ping to %s", inet_ntoa(e->address));
					CBufferOutputStream pkt(32);
					uint32_t seq=WritePacketHeader(&pkt, PKT_PING, 0);
					e->_lastPingTime=GetCurrentTime();
					e->_lastPingSeq=seq;
					SendPacket(pkt.GetBuffer(), pkt.GetLength(), e);
				}
				if(e->type==EP_TYPE_UDP_RELAY){
					if(e->_averageRtt>0 && e->_averageRtt<minPing*relaySwitchThreshold){
						minPing=e->_averageRtt;
						minPingRelay=e;
					}
				}
			}
			if(minPingRelay!=preferredRelay){
				preferredRelay=minPingRelay;
				if(currentEndpoint->type==EP_TYPE_UDP_RELAY)
					currentEndpoint=preferredRelay;
				LogDebugInfo();
				/*CBufferOutputStream pkt(32);
				pkt.WriteInt64(preferredRelay->id);
				SendPacketReliably(PKT_SWITCH_PREF_RELAY, pkt.GetBuffer(), pkt.GetLength(), 1, 9);*/
			}
			if(currentEndpoint->type==EP_TYPE_UDP_RELAY){
				voip_endpoint_t *p2p=GetEndpointByType(EP_TYPE_UDP_P2P_INET);
				if(p2p){
					voip_endpoint_t *lan=GetEndpointByType(EP_TYPE_UDP_P2P_LAN);
					if(lan && lan->_averageRtt>0 && lan->_averageRtt<minPing*relayToP2pSwitchThreshold){
						//SendPacketReliably(PKT_SWITCH_TO_P2P, NULL, 0, 1, 5);
						currentEndpoint=lan;
						LOGI("Switching to p2p (LAN)");
						LogDebugInfo();
					}else{
						if(p2p->_averageRtt>0 && p2p->_averageRtt<minPing*relayToP2pSwitchThreshold){
							//SendPacketReliably(PKT_SWITCH_TO_P2P, NULL, 0, 1, 5);
							currentEndpoint=p2p;
							LOGI("Switching to p2p (Inet)");
							LogDebugInfo();
						}
					}
				}
			}else{
				if(minPing>0 && minPing<currentEndpoint->_averageRtt*p2pToRelaySwitchThreshold){
					LOGI("Switching to relay");
					currentEndpoint=preferredRelay;
					LogDebugInfo();
				}
			}
		}

		if(state==STATE_ESTABLISHED){
			if(GetCurrentTime()-lastRecvPacketTime>=config.recv_timeout){
				if(currentEndpoint && currentEndpoint->type!=EP_TYPE_UDP_RELAY){
					LOGW("Packet receive timeout, switching to relay");
					currentEndpoint=preferredRelay;
					for(i=0;i<endpoints.size();i++){
						if(endpoints[i]->type==EP_TYPE_UDP_P2P_INET || endpoints[i]->type==EP_TYPE_UDP_P2P_LAN){
							endpoints[i]->_averageRtt=0;
							memset(endpoints[i]->_rtts, 0, sizeof(voip_endpoint_t::_rtts));
						}
					}
					if(allowP2p){
						SendPublicEndpointsRequest();
					}
					UpdateDataSavingState();
					UpdateAudioBitrate();
					CBufferOutputStream s(4);
					s.WriteInt32(dataSavingMode ? INIT_FLAG_DATA_SAVING_ENABLED : 0);
					SendPacketReliably(PKT_NETWORK_CHANGED, s.GetBuffer(), s.GetLength(), 1, 20);
					lastRecvPacketTime=GetCurrentTime();
				}else{
					LOGW("Packet receive timeout, disconnecting");
					lastError=ERROR_TIMEOUT;
					SetState(STATE_FAILED);
				}
			}
		}else if(state==STATE_WAIT_INIT){
			if(GetCurrentTime()-connectionInitTime>=config.init_timeout){
				LOGW("Init timeout, disconnecting");
				lastError=ERROR_TIMEOUT;
				SetState(STATE_FAILED);
			}
		}
		
#if defined(__APPLE__) && defined(TGVOIP_USE_AUDIO_SESSION)
		if(needNotifyAcquiredAudioSession){
			needNotifyAcquiredAudioSession=false;
			CAudioUnitIO::AudioSessionAcquired();
		}
#endif
	}
	LOGI("=== tick thread exiting ===");
}


voip_endpoint_t *CVoIPController::GetRemoteEndpoint(){
	//return useLan ? &remoteLanEp : &remotePublicEp;
	return currentEndpoint;
}


void CVoIPController::SendPacket(unsigned char *data, size_t len, voip_endpoint_t* ep){
	if(stopping)
		return;
	sockaddr_in6 dst(MakeInetAddress(ep->address, ep->port));
	//dst.sin_addr=ep->address;
	//dst.sin_port=htons(ep->port);
	//dst.sin_family=AF_INET;
	CBufferOutputStream out(len+128);
	if(ep->type==EP_TYPE_UDP_RELAY)
		out.WriteBytes(ep->peerTag, 16);
	else
		out.WriteBytes(callID, 16);
	if(len>0){
		CBufferOutputStream inner(len+128);
		inner.WriteInt32(len);
		inner.WriteBytes(data, len);
		if(inner.GetLength()%16!=0){
			size_t padLen=16-inner.GetLength()%16;
			unsigned char padding[padLen];
			crypto.rand_bytes((uint8_t *) padding, padLen);
			inner.WriteBytes(padding, padLen);
		}
		assert(inner.GetLength()%16==0);
		unsigned char key[32], iv[32], msgHash[SHA1_LENGTH];
		crypto.sha1((uint8_t *) inner.GetBuffer(), len+4, msgHash);
		out.WriteBytes(keyFingerprint, 8);
		out.WriteBytes((msgHash+(SHA1_LENGTH-16)), 16);
		KDF(msgHash+(SHA1_LENGTH-16), isOutgoing ? 0 : 8, key, iv);
        unsigned char aesOut[inner.GetLength()];
		crypto.aes_ige_encrypt(inner.GetBuffer(), aesOut, inner.GetLength(), key, iv);
		out.WriteBytes(aesOut, inner.GetLength());
	}
	//LOGV("Sending %d bytes to %s:%d", out.GetLength(), inet_ntoa(ep->address), ep->port);
	if(IS_MOBILE_NETWORK(networkType))
		stats.bytesSentMobile+=(uint64_t)out.GetLength();
	else
		stats.bytesSentWifi+=(uint64_t)out.GetLength();
	int res=sendto(udpSocket, out.GetBuffer(), out.GetLength(), 0, (const sockaddr *) &dst, sizeof(dst));
	if(res<0){
		LOGE("error sending: %d / %s", errno, strerror(errno));
	}
}


void CVoIPController::SetNetworkType(int type){
	networkType=type;
	UpdateDataSavingState();
	UpdateAudioBitrate();
	char itfName[32];
	GetLocalNetworkItfInfo(NULL, itfName);
	if(strcmp(itfName, activeNetItfName)!=0){
		needUpdateNat64Prefix=true;
		LOGI("Active network interface changed: %s -> %s", activeNetItfName, itfName);
		bool isFirstChange=strlen(activeNetItfName)==0;
		strcpy(activeNetItfName, itfName);
		if(isFirstChange)
			return;
		if(currentEndpoint && currentEndpoint->type!=EP_TYPE_UDP_RELAY){
			currentEndpoint=preferredRelay;
			for(std::vector<voip_endpoint_t*>::iterator itr=endpoints.begin();itr!=endpoints.end();){
				if((*itr)->type==EP_TYPE_UDP_P2P_INET){
					(*itr)->_averageRtt=0;
					memset((*itr)->_rtts, 0, sizeof((*itr)->_rtts));
				}
				if((*itr)->type==EP_TYPE_UDP_P2P_LAN){
					free((*itr));
					itr=endpoints.erase(itr);
				}else{
					++itr;
				}
			}
		}
		if(allowP2p && currentEndpoint){
			SendPublicEndpointsRequest();
		}
		CBufferOutputStream s(4);
		s.WriteInt32(dataSavingMode ? INIT_FLAG_DATA_SAVING_ENABLED : 0);
		SendPacketReliably(PKT_NETWORK_CHANGED, s.GetBuffer(), s.GetLength(), 1, 20);
	}
	LOGI("set network type: %d, active interface %s", type, activeNetItfName);
	/*if(type==NET_TYPE_GPRS || type==NET_TYPE_EDGE)
		audioPacketGrouping=2;
	else
		audioPacketGrouping=1;*/
}


double CVoIPController::GetAverageRTT(){
	if(lastSentSeq>=lastRemoteAckSeq){
		uint32_t diff=lastSentSeq-lastRemoteAckSeq;
		//LOGV("rtt diff=%u", diff);
		if(diff<32){
			int i;
			double res=0;
			int count=0;
			for(i=diff;i<32;i++){
				if(remoteAcks[i-diff]>0){
					res+=(remoteAcks[i-diff]-sentPacketTimes[i]);
					count++;
				}
			}
			if(count>0)
				res/=count;
			return res;
		}
	}
	return 999;
}

#if defined(__APPLE__)
static void initMachTimestart() {
    mach_timebase_info_data_t tb = { 0, 0 };
    mach_timebase_info(&tb);
    CVoIPController::machTimebase = tb.numer;
    CVoIPController::machTimebase /= tb.denom;
    CVoIPController::machTimestart = mach_absolute_time();
}
#endif

double CVoIPController::GetCurrentTime(){
#if defined(__linux__)
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec+(double)ts.tv_nsec/1000000000.0;
#elif defined(__APPLE__)
    static pthread_once_t token = PTHREAD_ONCE_INIT;
    pthread_once(&token, &initMachTimestart);
	return (mach_absolute_time() - machTimestart) * machTimebase / 1000000000.0f;
#endif
}

void CVoIPController::SetStateCallback(void (* f)(CVoIPController*, int)){
	stateCallback=f;
	if(stateCallback){
		stateCallback(this, state);
	}
}


void CVoIPController::SetState(int state){
	this->state=state;
	stateChangeTime=GetCurrentTime();
	if(stateCallback){
		stateCallback(this, state);
	}
}


void CVoIPController::SetMicMute(bool mute){
	micMuted=mute;
	if(audioInput){
		if(mute)
			audioInput->Stop();
		else
			audioInput->Start();
		if(!audioInput->IsInitialized()){
			lastError=ERROR_AUDIO_IO;
			SetState(STATE_FAILED);
			return;
		}
	}
	if(echoCanceller)
		echoCanceller->Enable(!mute);
	int i;
	for(i=0;i<outgoingStreams.size();i++){
		if(outgoingStreams[i]->type==STREAM_TYPE_AUDIO){
			unsigned char buf[2];
			buf[0]=outgoingStreams[i]->id;
			buf[1]=(char) (mute ? 0 : 1);
			SendPacketReliably(PKT_STREAM_STATE, buf, 2, .5f, 20);
			outgoingStreams[i]->enabled=!mute;
		}
	}
}


void CVoIPController::UpdateAudioOutputState(){
	bool areAnyAudioStreamsEnabled=false;
	int i;
	for(i=0;i<incomingStreams.size();i++){
		if(incomingStreams[i]->type==STREAM_TYPE_AUDIO && incomingStreams[i]->enabled)
			areAnyAudioStreamsEnabled=true;
	}
	if(jitterBuffer){
		jitterBuffer->Reset();
	}
	if(decoder){
		decoder->ResetQueue();
	}
	if(audioOutput){
		if(audioOutput->IsPlaying()!=areAnyAudioStreamsEnabled){
			if(areAnyAudioStreamsEnabled)
				audioOutput->Start();
			else
				audioOutput->Stop();
		}
	}
}


CBufferOutputStream *CVoIPController::GetOutgoingPacketBuffer(){
	CBufferOutputStream* pkt=NULL;
	lock_mutex(sendBufferMutex);
	if(emptySendBuffers.size()>0){
		pkt=emptySendBuffers[emptySendBuffers.size()-1];
		emptySendBuffers.pop_back();
	}
	unlock_mutex(sendBufferMutex);
	return pkt;
}


void CVoIPController::KDF(unsigned char* msgKey, size_t x, unsigned char* aesKey, unsigned char* aesIv){
	uint8_t sA[SHA1_LENGTH], sB[SHA1_LENGTH], sC[SHA1_LENGTH], sD[SHA1_LENGTH];
	CBufferOutputStream buf(128);
	buf.WriteBytes(msgKey, 16);
	buf.WriteBytes(encryptionKey+x, 32);
	crypto.sha1(buf.GetBuffer(), buf.GetLength(), sA);
	buf.Reset();
	buf.WriteBytes(encryptionKey+32+x, 16);
	buf.WriteBytes(msgKey, 16);
	buf.WriteBytes(encryptionKey+48+x, 16);
	crypto.sha1(buf.GetBuffer(), buf.GetLength(), sB);
	buf.Reset();
	buf.WriteBytes(encryptionKey+64+x, 32);
	buf.WriteBytes(msgKey, 16);
	crypto.sha1(buf.GetBuffer(), buf.GetLength(), sC);
	buf.Reset();
	buf.WriteBytes(msgKey, 16);
	buf.WriteBytes(encryptionKey+96+x, 32);
	crypto.sha1(buf.GetBuffer(), buf.GetLength(), sD);
	buf.Reset();
	buf.WriteBytes(sA, 8);
	buf.WriteBytes(sB+8, 12);
	buf.WriteBytes(sC+4, 12);
	assert(buf.GetLength()==32);
	memcpy(aesKey, buf.GetBuffer(), 32);
	buf.Reset();
	buf.WriteBytes(sA+8, 12);
	buf.WriteBytes(sB, 8);
	buf.WriteBytes(sC+16, 4);
	buf.WriteBytes(sD, 8);
	assert(buf.GetLength()==32);
	memcpy(aesIv, buf.GetBuffer(), 32);
}

void CVoIPController::GetDebugString(char *buffer, size_t len){
	char endpointsBuf[10240];
	memset(endpointsBuf, 0, 10240);
	int i;
	for(i=0;i<endpoints.size();i++){
		const char* type;
		switch(endpoints[i]->type){
			case EP_TYPE_UDP_P2P_INET:
				type="UDP_P2P_INET";
				break;
			case EP_TYPE_UDP_P2P_LAN:
				type="UDP_P2P_LAN";
				break;
			case EP_TYPE_UDP_RELAY:
				type="UDP_RELAY";
				break;
			case EP_TYPE_TCP_RELAY:
				type="TCP_RELAY";
				break;
			default:
				type="UNKNOWN";
				break;
		}
		if(strlen(endpointsBuf)>10240-1024)
			break;
		sprintf(endpointsBuf+strlen(endpointsBuf), "%s:%u %dms [%s%s]\n", inet_ntoa(endpoints[i]->address), endpoints[i]->port, (int)(endpoints[i]->_averageRtt*1000), type, currentEndpoint==endpoints[i] ? ", IN_USE" : "");
	}
	double avgLate[3];
	if(jitterBuffer)
		jitterBuffer->GetAverageLateCount(avgLate);
	else
		memset(avgLate, 0, 3*sizeof(double));
	snprintf(buffer, len,
			 "Remote endpoints: \n%s"
					 "Jitter buffer: %d/%d | %.1f, %.1f, %.1f\n"
					 "RTT avg/min: %d/%d\n"
					 "Congestion window: %d/%d bytes\n"
					 "Key fingerprint: %02hhX%02hhX%02hhX%02hhX%02hhX%02hhX%02hhX%02hhX\n"
					 "Last sent/ack'd seq: %u/%u\n"
					 "Last recvd seq: %u\n"
					 "Send/recv losses: %u/%u (%d%%)\n"
					 "Audio bitrate: %d kbit\n"
//					 "Packet grouping: %d\n"
					"Frame size out/in: %d/%d\n"
					 "Bytes sent/recvd: %llu/%llu",
			 endpointsBuf,
			 jitterBuffer ? jitterBuffer->GetMinPacketCount() : 0, jitterBuffer ? jitterBuffer->GetCurrentDelay() : 0, avgLate[0], avgLate[1], avgLate[2],
			// (int)(GetAverageRTT()*1000), 0,
			 (int)(conctl->GetAverageRTT()*1000), (int)(conctl->GetMinimumRTT()*1000),
			 conctl->GetInflightDataSize(), conctl->GetCongestionWindow(),
			 keyFingerprint[0],keyFingerprint[1],keyFingerprint[2],keyFingerprint[3],keyFingerprint[4],keyFingerprint[5],keyFingerprint[6],keyFingerprint[7],
				lastSentSeq, lastRemoteAckSeq, lastRemoteSeq,
			 conctl->GetSendLossCount(), recvLossCount, encoder ? encoder->GetPacketLoss() : 0,
			 encoder ? (encoder->GetBitrate()/1000) : 0,
//			 audioPacketGrouping,
			 outgoingStreams[0]->frameDuration, incomingStreams.size()>0 ? incomingStreams[0]->frameDuration : 0,
			stats.bytesSentMobile+stats.bytesSentWifi, stats.bytesRecvdMobile+stats.bytesRecvdWifi);
}


void CVoIPController::SendPublicEndpointsRequest(){
	LOGI("Sending public endpoints request");
	voip_endpoint_t* relay=GetEndpointByType(EP_TYPE_UDP_RELAY);
	if(!relay)
		return;
	publicEndpointsReqTime=GetCurrentTime();
	waitingForRelayPeerInfo=true;
	char buf[32];
	memcpy(buf, relay->peerTag, 16);
	memset(buf+16, 0xFF, 16);
	sockaddr_in6 dst(MakeInetAddress(relay->address, relay->port));
	int res=sendto(udpSocket, buf, 32, 0, (const sockaddr *) &dst, sizeof(dst));
	if(res<0){
		LOGE("error sending: %d / %s", errno, strerror(errno));
	}
}


void CVoIPController::SendP2pPing(int endpointType){
	LOGD("Sending ping for p2p, endpoint type %d", endpointType);
	voip_endpoint_t* endpoint=GetEndpointByType(endpointType);
	if(!endpoint)
		return;
	lastP2pPingTime=GetCurrentTime();
	CBufferOutputStream pkt(32);
	uint32_t seq=WritePacketHeader(&pkt, PKT_PING, 0);
	SendPacket(pkt.GetBuffer(), pkt.GetLength(), endpoint);
}


void CVoIPController::GetLocalNetworkItfInfo(in_addr *outAddr, char *outName){
	struct ifconf ifc;
	struct ifreq* ifr;
	char buf[16384];
	int sd;
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
						if(strcmp(ifr->ifr_name, "lo0")!=0 && strcmp(ifr->ifr_name, "lo")!=0 && addr->sin_addr.s_addr!=inet_addr("127.0.0.1")){
							if(outAddr)
								memcpy(outAddr, &addr->sin_addr, sizeof(in_addr));
							if(outName)
								strcpy(outName, ifr->ifr_name);
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
}


voip_endpoint_t *CVoIPController::GetEndpointByType(int type){
	if(type==EP_TYPE_UDP_RELAY && preferredRelay)
		return preferredRelay;
	int i;
	for(i=0;i<endpoints.size();i++){
		if(endpoints[i]->type==type)
			return endpoints[i];
	}
	return NULL;
}


float CVoIPController::GetOutputLevel(){
    if(!audioOutput || !audioOutStarted){
        return 0.0;
    }
    return audioOutput->GetLevel();
}


void CVoIPController::SendPacketReliably(unsigned char type, unsigned char *data, size_t len, double retryInterval, double timeout){
	LOGD("Send reliably, type=%u, len=%u, retry=%.3llf, timeout=%.3llf", type, len, retryInterval, timeout);
	voip_queued_packet_t* pkt=(voip_queued_packet_t *) malloc(sizeof(voip_queued_packet_t));
	memset(pkt, 0, sizeof(voip_queued_packet_t));
	pkt->type=type;
	if(data){
		pkt->data=(unsigned char *) malloc(len);
		memcpy(pkt->data, data, len);
		pkt->length=len;
	}
	pkt->retryInterval=retryInterval;
	pkt->timeout=timeout;
	pkt->firstSentTime=0;
	pkt->lastSentTime=0;
	lock_mutex(queuedPacketsMutex);
	queuedPackets.push_back(pkt);
	unlock_mutex(queuedPacketsMutex);
}


void CVoIPController::SetConfig(voip_config_t *cfg){
	memcpy(&config, cfg, sizeof(voip_config_t));
	if(tgvoipLogFile){
		fclose(tgvoipLogFile);
	}
	if(strlen(cfg->logFilePath))
		tgvoipLogFile=fopen(cfg->logFilePath, "w");
	UpdateDataSavingState();
	UpdateAudioBitrate();
}


void CVoIPController::UpdateDataSavingState(){
	if(config.data_saving==DATA_SAVING_ALWAYS){
		dataSavingMode=true;
	}else if(config.data_saving==DATA_SAVING_MOBILE){
		dataSavingMode=networkType==NET_TYPE_GPRS || networkType==NET_TYPE_EDGE ||
		   networkType==NET_TYPE_3G || networkType==NET_TYPE_HSPA || networkType==NET_TYPE_LTE || networkType==NET_TYPE_OTHER_MOBILE;
	}else{
		dataSavingMode=false;
	}
	LOGI("update data saving mode, config %d, enabled %d, reqd by peer %d", config.data_saving, dataSavingMode, dataSavingRequestedByPeer);
}


void CVoIPController::DebugCtl(int request, int param){
	if(request==1){ // set bitrate
		maxBitrate=param;
		if(encoder){
			encoder->SetBitrate(maxBitrate);
		}
	}else if(request==2){ // set packet loss
		if(encoder){
			encoder->SetPacketLoss(param);
		}
	}else if(request==3){ // force enable/disable p2p
		allowP2p=param==1;
		if(!allowP2p && currentEndpoint && currentEndpoint->type!=EP_TYPE_UDP_RELAY){
			currentEndpoint=preferredRelay;
			needSendP2pPing=false;
		}else if(allowP2p){
			SendPublicEndpointsRequest();
		}
		CBufferOutputStream s(4);
		s.WriteInt32(dataSavingMode ? INIT_FLAG_DATA_SAVING_ENABLED : 0);
		SendPacketReliably(PKT_NETWORK_CHANGED, s.GetBuffer(), s.GetLength(), 1, 20);
	}else if(request==4){
		if(echoCanceller)
			echoCanceller->Enable(param==1);
	}
}


const char* CVoIPController::GetVersion(){
	return LIBTGVOIP_VERSION;
}


int64_t CVoIPController::GetPreferredRelayID(){
	if(preferredRelay)
		return preferredRelay->id;
	return 0;
}


int CVoIPController::GetLastError(){
	return lastError;
}


void CVoIPController::GetStats(voip_stats_t *stats){
	memcpy(stats, &this->stats, sizeof(voip_stats_t));
}


uint16_t CVoIPController::GenerateLocalUDPPort(){
	uint16_t rnd;
	crypto.rand_bytes((uint8_t *) &rnd, 2);
	return (uint16_t) ((rnd%(MAX_UDP_PORT-MIN_UDP_PORT))+MIN_UDP_PORT);
}

#ifdef TGVOIP_USE_AUDIO_SESSION
void CVoIPController::SetAcquireAudioSession(void (^completion)(void (^)())) {
    this->acquireAudioSession = [completion copy];
}

void CVoIPController::ReleaseAudioSession(void (^completion)()) {
    completion();
}
#endif

void CVoIPController::LogDebugInfo(){
	std::string json="{\"endpoints\":[";
	for(std::vector<voip_endpoint_t*>::iterator itr=endpoints.begin();itr!=endpoints.end();++itr){
		voip_endpoint_t* e=*itr;
		char buffer[1024];
		const char* typeStr="unknown";
		switch(e->type){
			case EP_TYPE_UDP_RELAY:
				typeStr="udp_relay";
				break;
			case EP_TYPE_UDP_P2P_INET:
				typeStr="udp_p2p_inet";
				break;
			case EP_TYPE_UDP_P2P_LAN:
				typeStr="udp_p2p_lan";
				break;
		}
		snprintf(buffer, 1024, "{\"address\":\"%s\",\"port\":%u,\"type\":\"%s\",\"rtt\":%u%s%s}", inet_ntoa(e->address), e->port, typeStr, (unsigned int)round(e->_averageRtt*1000), currentEndpoint==e ? ",\"in_use\":true" : "", preferredRelay==e ? ",\"preferred\":true" : "");
		json+=buffer;
		if(std::next(itr)!=endpoints.end())
			json+=",";
	}
	json+="],";
	char buffer[1024];
	const char* netTypeStr;
	switch(networkType){
		case NET_TYPE_WIFI:
			netTypeStr="wifi";
			break;
		case NET_TYPE_GPRS:
			netTypeStr="gprs";
			break;
		case NET_TYPE_EDGE:
			netTypeStr="edge";
			break;
		case NET_TYPE_3G:
			netTypeStr="3g";
			break;
		case NET_TYPE_HSPA:
			netTypeStr="hspa";
			break;
		case NET_TYPE_LTE:
			netTypeStr="lte";
			break;
		case NET_TYPE_ETHERNET:
			netTypeStr="ethernet";
			break;
		case NET_TYPE_OTHER_HIGH_SPEED:
			netTypeStr="other_high_speed";
			break;
		case NET_TYPE_OTHER_LOW_SPEED:
			netTypeStr="other_low_speed";
			break;
		case NET_TYPE_DIALUP:
			netTypeStr="dialup";
			break;
		case NET_TYPE_OTHER_MOBILE:
			netTypeStr="other_mobile";
			break;
		default:
			netTypeStr="unknown";
			break;
	}
	snprintf(buffer, 1024, "\"time\":%u,\"network_type\":\"%s\"}", (unsigned int)time(NULL), netTypeStr);
	json+=buffer;
	debugLogs.push_back(json);
}

std::string CVoIPController::GetDebugLog(){
	std::string log="{\"events\":[";

	for(std::vector<std::string>::iterator itr=debugLogs.begin();itr!=debugLogs.end();++itr){
		log+=(*itr);
		if(std::next(itr)!=debugLogs.end())
			log+=",";
	}
	log+="],\"libtgvoip_version\":\"" LIBTGVOIP_VERSION "\"}";
	return log;
}

void CVoIPController::GetDebugLog(char *buffer){
	strcpy(buffer, GetDebugLog().c_str());
}

size_t CVoIPController::GetDebugLogLength(){
	size_t len=128;
	for(std::vector<std::string>::iterator itr=debugLogs.begin();itr!=debugLogs.end();++itr){
		len+=(*itr).length()+1;
	}
	return len;
}


sockaddr_in6 CVoIPController::MakeInetAddress(in_addr addr, uint16_t port){
	// TODO: refactor the hell out of this by at least moving sockets to a separate class
	if(needUpdateNat64Prefix){
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
	sockaddr_in6 r;
	memset(&r, 0, sizeof(sockaddr_in6));
	r.sin6_port=htons(port);
	r.sin6_family=AF_INET6;
	*((in_addr*)&r.sin6_addr.s6_addr[12])=addr;
	if(nat64Present)
		memcpy(r.sin6_addr.s6_addr, nat64Prefix, 12);
	else
		r.sin6_addr.s6_addr[11]=r.sin6_addr.s6_addr[10]=0xFF;
	//r.sin6_len=sizeof(sa_family_t);
	return r;
}
