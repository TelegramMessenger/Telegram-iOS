//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef _WIN32
#include <unistd.h>
#include <sys/time.h>
#endif
#include <errno.h>
#include <string.h>
#include <wchar.h>
#include "VoIPController.h"
#include "logging.h"
#include "threading.h"
#include "Buffers.h"
#include "OpusEncoder.h"
#include "OpusDecoder.h"
#include "VoIPServerConfig.h"
#include "PrivateDefines.h"
#include <assert.h>
#include <time.h>
#include <math.h>
#include <exception>
#include <stdexcept>
#include <algorithm>
#include <inttypes.h>
#include <float.h>


inline int pad4(int x){
	int r=PAD4(x);
	if(r==4)
		return 0;
	return r;
}


using namespace tgvoip;
using namespace std;

#ifdef __APPLE__
#include "os/darwin/AudioUnitIO.h"
#include <mach/mach_time.h>
double VoIPController::machTimebase=0;
uint64_t VoIPController::machTimestart=0;
#endif

#ifdef _WIN32
int64_t VoIPController::win32TimeScale = 0;
bool VoIPController::didInitWin32TimeScale = false;
#endif

#ifndef TGVOIP_USE_CUSTOM_CRYPTO
extern "C" {
#include <openssl/sha.h>
#include <openssl/aes.h>
#include <openssl/modes.h>
#include <openssl/rand.h>
}

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

void tgvoip_openssl_aes_ctr_encrypt(uint8_t* inout, size_t length, uint8_t* key, uint8_t* iv, uint8_t* ecount, uint32_t* num){
	AES_KEY akey;
	AES_set_encrypt_key(key, 32*8, &akey);
	CRYPTO_ctr128_encrypt(inout, inout, length, &akey, iv, ecount, num, (block128_f) AES_encrypt);
}

void tgvoip_openssl_aes_cbc_encrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
	AES_KEY akey;
	AES_set_encrypt_key(key, 256, &akey);
	AES_cbc_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

void tgvoip_openssl_aes_cbc_decrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
	AES_KEY akey;
	AES_set_decrypt_key(key, 256, &akey);
	AES_cbc_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

CryptoFunctions VoIPController::crypto={
		tgvoip_openssl_rand_bytes,
		tgvoip_openssl_sha1,
		tgvoip_openssl_sha256,
		tgvoip_openssl_aes_ige_encrypt,
		tgvoip_openssl_aes_ige_decrypt,
		tgvoip_openssl_aes_ctr_encrypt,
		tgvoip_openssl_aes_cbc_encrypt,
		tgvoip_openssl_aes_cbc_decrypt

};
#else
CryptoFunctions VoIPController::crypto; // set it yourself upon initialization
#endif


extern FILE* tgvoipLogFile;

VoIPController::VoIPController() : activeNetItfName(""),
								   currentAudioInput("default"),
								   currentAudioOutput("default"),
								   proxyAddress(""),
								   proxyUsername(""),
								   proxyPassword(""){
	seq=1;
	lastRemoteSeq=0;
	state=STATE_WAIT_INIT;
	audioInput=NULL;
	audioOutput=NULL;
	encoder=NULL;
	audioOutStarted=false;
	audioTimestampIn=0;
	audioTimestampOut=0;
	stopping=false;
	sendQueue=new BlockingQueue<PendingOutgoingPacket>(21);
	memset(recvPacketTimes, 0, sizeof(double)*32);
	memset(&stats, 0, sizeof(TrafficStats));
	lastRemoteAckSeq=0;
	lastSentSeq=0;
	recvLossCount=0;
	packetsReceived=0;
	waitingForAcks=false;
	networkType=NET_TYPE_UNKNOWN;
	echoCanceller=NULL;
	dontSendPackets=0;
	micMuted=false;
	currentEndpoint=NULL;
	waitingForRelayPeerInfo=false;
	allowP2p=true;
	dataSavingMode=false;
	publicEndpointsReqTime=0;
	connectionInitTime=0;
	lastRecvPacketTime=0;
	dataSavingRequestedByPeer=false;
	peerVersion=0;
	conctl=new CongestionControl();
	prevSendLossCount=0;
	receivedInit=false;
	receivedInitAck=false;
	peerPreferredRelay=NULL;
	statsDump=NULL;
	useTCP=false;
	useUDP=true;
	didAddTcpRelays=false;
	udpPingCount=0;
	lastUdpPingTime=0;
	openingTcpSocket=NULL;

	proxyProtocol=PROXY_NONE;
	proxyPort=0;
	resolvedProxyAddress=NULL;

	selectCanceller=SocketSelectCanceller::Create();
	udpSocket=NetworkSocket::Create(PROTO_UDP);
	realUdpSocket=udpSocket;
	udpConnectivityState=UDP_UNKNOWN;
	echoCancellationStrength=1;

	outputAGC=NULL;
	outputAGCEnabled=false;
	peerCapabilities=0;
	callbacks={0};
	didReceiveGroupCallKey=false;
	didReceiveGroupCallKeyAck=false;
	didSendGroupCallKey=false;
	didSendUpgradeRequest=false;
	didInvokeUpgradeCallback=false;

	connectionMaxLayer=0;
	useMTProto2=false;
	setCurrentEndpointToTCP=false;
	useIPv6=false;
	peerIPv6Available=false;
	shittyInternetMode=false;
	didAddIPv6Relays=false;
	didSendIPv6Endpoint=false;
	unsentStreamPackets.store(0);

	sendThread=NULL;
	recvThread=NULL;

	maxAudioBitrate=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_max_bitrate", 20000);
	maxAudioBitrateGPRS=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_max_bitrate_gprs", 8000);
	maxAudioBitrateEDGE=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_max_bitrate_edge", 16000);
	maxAudioBitrateSaving=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_max_bitrate_saving", 8000);
	initAudioBitrate=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_init_bitrate", 16000);
	initAudioBitrateGPRS=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_init_bitrate_gprs", 8000);
	initAudioBitrateEDGE=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_init_bitrate_edge", 8000);
	initAudioBitrateSaving=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_init_bitrate_saving", 8000);
	audioBitrateStepIncr=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_bitrate_step_incr", 1000);
	audioBitrateStepDecr=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_bitrate_step_decr", 1000);
	minAudioBitrate=(uint32_t) ServerConfig::GetSharedInstance()->GetInt("audio_min_bitrate", 8000);
	relaySwitchThreshold=ServerConfig::GetSharedInstance()->GetDouble("relay_switch_threshold", 0.8);
	p2pToRelaySwitchThreshold=ServerConfig::GetSharedInstance()->GetDouble("p2p_to_relay_switch_threshold", 0.6);
	relayToP2pSwitchThreshold=ServerConfig::GetSharedInstance()->GetDouble("relay_to_p2p_switch_threshold", 0.8);
	reconnectingTimeout=ServerConfig::GetSharedInstance()->GetDouble("reconnecting_state_timeout", 2.0);

#ifdef __APPLE__
	machTimestart=0;
#endif

	sendQueue->SetOverflowCallback([](PendingOutgoingPacket p){
		LOGW("Dropping outgoing packet (type %d seq %d) from queue", p.type, p.seq);
	});

	shared_ptr<Stream> stm=make_shared<Stream>();
	stm->id=1;
	stm->type=STREAM_TYPE_AUDIO;
	stm->codec=CODEC_OPUS;
	stm->enabled=1;
	stm->frameDuration=60;
	outgoingStreams.push_back(stm);

	/*Stream vstm={0};
	vstm.id=2;
	vstm.type=STREAM_TYPE_VIDEO;
	vstm.codec=CODEC_AVC;
	vstm.enabled=1;
	outgoingStreams.push_back(vstm);*/
}

VoIPController::~VoIPController(){
	LOGD("Entered VoIPController::~VoIPController");
	if(!stopping){
		LOGE("!!!!!!!!!!!!!!!!!!!! CALL controller->Stop() BEFORE DELETING THE CONTROLLER OBJECT !!!!!!!!!!!!!!!!!!!!!!!1");
		abort();
	}
	LOGD("before close socket");
	if(udpSocket)
		delete udpSocket;
	if(udpSocket!=realUdpSocket)
		delete realUdpSocket;
	for(vector<shared_ptr<Stream>>::iterator _stm=incomingStreams.begin();_stm!=incomingStreams.end();++_stm){
		//LOGD("before delete jitter buffer");
		shared_ptr<Stream> stm=*_stm;
		/*if(stm->jitterBuffer){
			delete stm->jitterBuffer;
		}*/
		LOGD("before stop decoder");
		if(stm->decoder){
			stm->decoder->Stop();
		}
	}
	//LOGD("before delete audio input");
	//if(audioInput){
	//	delete audioInput;
	//}
	LOGD("before delete encoder");
	if(encoder){
		encoder->Stop();
		delete encoder;
	}
	//LOGD("before delete audio output");
	//if(audioOutput){
		//delete audioOutput;
		//audioOutput.reset();
	//}
	/*for(vector<shared_ptr<Stream>>::iterator stm=incomingStreams.begin();stm!=incomingStreams.end();++stm){
		LOGD("before delete decoder");
		if((*stm)->decoder){
			delete (*stm)->decoder;
		}
	}*/
	LOGD("before delete echo canceller");
	if(echoCanceller){
		echoCanceller->Stop();
		delete echoCanceller;
	}
	delete sendQueue;
	/*for(i=0;i<queuedPackets.size();i++){
		if(queuedPackets[i]->data)
			free(queuedPackets[i]->data);
		free(queuedPackets[i]);
	}*/
	delete conctl;
	/*for(vector<Endpoint*>::iterator itr=endpoints.begin();itr!=endpoints.end();++itr){
		if((*itr)->socket){
			(*itr)->socket->Close();
			delete (*itr)->socket;
		}
		delete *itr;
	}*/
	if(tgvoipLogFile){
		FILE* log=tgvoipLogFile;
		tgvoipLogFile=NULL;
		fclose(log);
	}
	if(statsDump)
		fclose(statsDump);
	if(resolvedProxyAddress)
		delete resolvedProxyAddress;
	delete selectCanceller;
	if(outputAGC)
		delete outputAGC;
	LOGD("Left VoIPController::~VoIPController");
}

void VoIPController::Stop(){
	LOGD("Entered VoIPController::Stop");
	stopping=true;
	runReceiver=false;
	LOGD("before shutdown socket");
	if(udpSocket)
		udpSocket->Close();
	if(realUdpSocket!=udpSocket)
		realUdpSocket->Close();
	selectCanceller->CancelSelect();
	sendQueue->Put(PendingOutgoingPacket{0});
	if(openingTcpSocket)
		openingTcpSocket->Close();
	LOGD("before join sendThread");
	if(sendThread){
		sendThread->Join();
		delete sendThread;
	}
	LOGD("before join recvThread");
	if(recvThread){
		recvThread->Join();
		delete recvThread;
	}
	LOGD("before stop messageThread");
	messageThread.Stop();
	{
		LOGD("Before stop audio I/O");
		MutexGuard m(audioIOMutex);
		if(audioInput)
			audioInput->Stop();
		if(audioOutput)
			audioOutput->Stop();
	}
	LOGD("Left VoIPController::Stop");
}

void VoIPController::SetRemoteEndpoints(vector<Endpoint> endpoints, bool allowP2p, int32_t connectionMaxLayer){
	LOGW("Set remote endpoints, allowP2P=%d, connectionMaxLayer=%u", allowP2p ? 1 : 0, connectionMaxLayer);
	preferredRelay=NULL;
	{
		MutexGuard m(endpointsMutex);
		this->endpoints.clear();
		didAddTcpRelays=false;
		useTCP=true;
		for(vector<Endpoint>::iterator itrtr=endpoints.begin();itrtr!=endpoints.end();++itrtr){
			this->endpoints.push_back(make_shared<Endpoint>(*itrtr));
			if(itrtr->type==Endpoint::TYPE_TCP_RELAY)
				didAddTcpRelays=true;
			if(itrtr->type==Endpoint::TYPE_UDP_RELAY)
				useTCP=false;
			LOGV("Adding endpoint: %s:%d, %s", itrtr->address.ToString().c_str(), itrtr->port, itrtr->type==Endpoint::TYPE_UDP_RELAY ? "UDP" : "TCP");
		}
	}
	currentEndpoint=this->endpoints[0];
	preferredRelay=currentEndpoint;
	this->allowP2p=allowP2p;
	this->connectionMaxLayer=connectionMaxLayer;
	if(connectionMaxLayer>=74){
		useMTProto2=true;
	}
	AddIPv6Relays();
}

void VoIPController::Start(){
	LOGW("Starting voip controller");
	udpSocket->Open();
	if(udpSocket->IsFailed()){
		SetState(STATE_FAILED);
		return;
	}

	//SendPacket(NULL, 0, currentEndpoint);

	runReceiver=true;
	recvThread=new Thread(new MethodPointer<VoIPController>(&VoIPController::RunRecvThread, this), NULL);
	recvThread->SetName("VoipRecv");
	recvThread->Start();
	sendThread=new Thread(new MethodPointer<VoIPController>(&VoIPController::RunSendThread, this), NULL);
	sendThread->SetName("VoipSend");
	sendThread->Start();

	messageThread.Start();
}

void VoIPController::AudioInputCallback(unsigned char* data, size_t length, unsigned char* secondaryData, size_t secondaryLength, void* param){
	((VoIPController*)param)->HandleAudioInput(data, length, secondaryData, secondaryLength);
}

void VoIPController::HandleAudioInput(unsigned char *data, size_t len, unsigned char* secondaryData, size_t secondaryLen){
	if(stopping)
		return;
	if(waitingForAcks || dontSendPackets>0 || (unsigned int)unsentStreamPackets>=2){
		LOGV("waiting for queue, dropping outgoing audio packet");
		return;
	}
	//LOGV("Audio packet size %u", (unsigned int)len);

	BufferOutputStream pkt(1500);

	unsigned char flags=(unsigned char) (len>255 ? STREAM_DATA_FLAG_LEN16 : 0);
	pkt.WriteByte((unsigned char) (1 | flags)); // streamID + flags
	if(len>255)
		pkt.WriteInt16((int16_t) len);
	else
		pkt.WriteByte((unsigned char) len);
	pkt.WriteInt32(audioTimestampOut);
	pkt.WriteBytes(data, len);

	unsentStreamPackets++;
	PendingOutgoingPacket p{
			/*.seq=*/GenerateOutSeq(),
			/*.type=*/PKT_STREAM_DATA,
			/*.len=*/pkt.GetLength(),
			/*.data=*/Buffer(move(pkt)),
			/*.endpoint=*/0,
	};
	sendQueue->Put(move(p));
	if(secondaryData && secondaryLen && shittyInternetMode){
		Buffer ecBuf(secondaryLen);
		ecBuf.CopyFrom(secondaryData, 0, secondaryLen);
		ecAudioPackets.push_back(move(ecBuf));
		while(ecAudioPackets.size()>4)
			ecAudioPackets.erase(ecAudioPackets.begin());
		pkt=BufferOutputStream(1500);
		pkt.WriteByte(outgoingStreams[0]->id);
		pkt.WriteInt32(audioTimestampOut);
		pkt.WriteByte((unsigned char)ecAudioPackets.size());
		for(Buffer& ecData:ecAudioPackets){
			pkt.WriteByte((unsigned char)ecData.Length());
			pkt.WriteBytes(ecData);
		}

		PendingOutgoingPacket p{
				GenerateOutSeq(),
				PKT_STREAM_EC,
				pkt.GetLength(),
				Buffer(move(pkt)),
				0
		};
		sendQueue->Put(move(p));
	}

	audioTimestampOut+=outgoingStreams[0]->frameDuration;
}

void VoIPController::HandleVideoInput(EncodedVideoFrame& frame){
	if(stopping)
		return;
	if(waitingForAcks || dontSendPackets>0 || networkType==NET_TYPE_EDGE || networkType==NET_TYPE_GPRS){
		LOGV("dropping outgoing video packet");
		return;
	}


}

void VoIPController::Connect(){
	assert(state!=STATE_WAIT_INIT_ACK);
	if(proxyProtocol==PROXY_SOCKS5){
		resolvedProxyAddress=NetworkSocket::ResolveDomainName(proxyAddress);
		if(!resolvedProxyAddress){
			LOGW("Error resolving proxy address %s", proxyAddress.c_str());
			SetState(STATE_FAILED);
			return;
		}
		InitUDPProxy();
	}
	connectionInitTime=GetCurrentTime();
	if(config.initTimeout==0.0){
		LOGE("Init timeout is 0 -- did you forget to set config?");
		config.initTimeout=30.0;
	}

	InitializeTimers();
	SendInit();
}

void VoIPController::InitializeTimers(){
	initTimeoutID=messageThread.Post([this]{
		LOGW("Init timeout, disconnecting");
		lastError=ERROR_TIMEOUT;
		SetState(STATE_FAILED);
	}, config.initTimeout);

	if(!config.statsDumpFilePath.empty()){
		messageThread.Post([this]{
			if(statsDump && incomingStreams.size()==1){
				shared_ptr<JitterBuffer>& jitterBuffer=incomingStreams[0]->jitterBuffer;
				//fprintf(statsDump, "Time\tRTT\tLISeq\tLASeq\tCWnd\tBitrate\tJitter\tJDelay\tAJDelay\n");
				fprintf(statsDump, "%.3f\t%.3f\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.3f\t%.3f\t%.3f\n",
						GetCurrentTime()-connectionInitTime,
						currentEndpoint->rtts[0],
						lastRemoteSeq,
						seq,
						lastRemoteAckSeq,
						recvLossCount,
						conctl ? conctl->GetSendLossCount() : 0,
						conctl ? (int)conctl->GetInflightDataSize() : 0,
						encoder ? encoder->GetBitrate() : 0,
						encoder ? encoder->GetPacketLoss() : 0,
						jitterBuffer ? jitterBuffer->GetLastMeasuredJitter() : 0,
						jitterBuffer ? jitterBuffer->GetLastMeasuredDelay()*0.06 : 0,
						jitterBuffer ? jitterBuffer->GetAverageDelay()*0.06 : 0);
			}
		}, 0.1, 0.1);
	}

	udpConnectivityState=UDP_PING_PENDING;
	udpPingTimeoutID=messageThread.Post(std::bind(&VoIPController::SendUdpPings, this), 0.0, 0.5);
	messageThread.Post(std::bind(&VoIPController::SendRelayPings, this), 0.0, 2.0);
}


void VoIPController::SetEncryptionKey(char *key, bool isOutgoing){
	memcpy(encryptionKey, key, 256);
	uint8_t sha1[SHA1_LENGTH];
	crypto.sha1((uint8_t*) encryptionKey, 256, sha1);
	memcpy(keyFingerprint, sha1+(SHA1_LENGTH-8), 8);
	uint8_t sha256[SHA256_LENGTH];
	crypto.sha256((uint8_t*) encryptionKey, 256, sha256);
	memcpy(callID, sha256+(SHA256_LENGTH-16), 16);
	this->isOutgoing=isOutgoing;
}

uint32_t VoIPController::GenerateOutSeq(){
	return seq++;
}

void VoIPController::WritePacketHeader(uint32_t pseq, BufferOutputStream *s, unsigned char type, uint32_t length){
	uint32_t acks=0;
	int i;
	for(i=0;i<32;i++){
		if(recvPacketTimes[i]>0)
			acks|=1;
		if(i<31)
			acks<<=1;
	}

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
		if(peerVersion>=6){
			MutexGuard m(queuedPacketsMutex);
			if(currentExtras.empty()){
				s->WriteByte(0);
			}else{
				s->WriteByte(XPFLAG_HAS_EXTRA);
				s->WriteByte(static_cast<unsigned char>(currentExtras.size()));
				for(vector<UnacknowledgedExtraData>::iterator x=currentExtras.begin();x!=currentExtras.end();++x){
					LOGV("Writing extra into header: type %u, length %lu", x->type, x->data.Length());
					assert(x->data.Length()<=254);
					s->WriteByte(static_cast<unsigned char>(x->data.Length()+1));
					s->WriteByte(x->type);
					s->WriteBytes(*x->data, x->data.Length());
					if(x->firstContainingSeq==0)
						x->firstContainingSeq=pseq;
				}
			}
		}
	}

	if(type==PKT_STREAM_DATA || type==PKT_STREAM_DATA_X2 || type==PKT_STREAM_DATA_X3)
		conctl->PacketSent(pseq, length);

	MutexGuard m(queuedPacketsMutex);
	recentOutgoingPackets.push_back(RecentOutgoingPacket{
			pseq,
			0,
			GetCurrentTime(),
			0
	});
	while(recentOutgoingPackets.size()>MAX_RECENT_PACKETS)
		recentOutgoingPackets.erase(recentOutgoingPackets.begin());
	lastSentSeq=pseq;
	//LOGI("packet header size %d", s->GetLength());
}


void VoIPController::UpdateAudioBitrateLimit(){
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


void VoIPController::SendInit(){
	{
		MutexGuard m(endpointsMutex);
		uint32_t initSeq=GenerateOutSeq();
		for(shared_ptr<Endpoint>& e:endpoints){
			if(e->type==Endpoint::TYPE_TCP_RELAY && !useTCP)
				continue;
			BufferOutputStream out(1024);
			out.WriteInt32(PROTOCOL_VERSION);
			out.WriteInt32(MIN_PROTOCOL_VERSION);
			uint32_t flags=0;
			if(config.enableCallUpgrade)
				flags|=INIT_FLAG_GROUP_CALLS_SUPPORTED;
			if(dataSavingMode)
				flags|=INIT_FLAG_DATA_SAVING_ENABLED;
			out.WriteInt32(flags);
			if(connectionMaxLayer<74){
				out.WriteByte(2); // audio codecs count
				out.WriteByte(CODEC_OPUS_OLD);
				out.WriteByte(0);
				out.WriteByte(0);
				out.WriteByte(0);
				out.WriteInt32(CODEC_OPUS);
				out.WriteByte(0); // video codecs count (decode)
				out.WriteByte(0); // video codecs count (encode)
			}else{
				out.WriteByte(1);
				out.WriteInt32(CODEC_OPUS);
				/*out.WriteByte(1);
				out.WriteInt32(CODEC_AVC);
				out.WriteByte(1);
				out.WriteInt32(CODEC_AVC);*/
				out.WriteByte(0);
				out.WriteByte(0);
			}
			sendQueue->Put(PendingOutgoingPacket{
					/*.seq=*/initSeq,
					/*.type=*/PKT_INIT,
					/*.len=*/out.GetLength(),
					/*.data=*/Buffer(move(out)),
					/*.endpoint=*/e->id
			});
		}
	}
	if(state==STATE_WAIT_INIT)
		SetState(STATE_WAIT_INIT_ACK);
	messageThread.Post([this]{
		if(state==STATE_WAIT_INIT_ACK){
			SendInit();
		}
	}, 0.5);
}

void VoIPController::InitUDPProxy(){
	if(realUdpSocket!=udpSocket){
		udpSocket->Close();
		delete udpSocket;
		udpSocket=realUdpSocket;
	}
	NetworkSocket* tcp=NetworkSocket::Create(PROTO_TCP);
	tcp->Connect(resolvedProxyAddress, proxyPort);
	if(tcp->IsFailed()){
		lastError=ERROR_PROXY;
		SetState(STATE_FAILED);
		tcp->Close();
		delete tcp;
		return;
	}
	NetworkSocketSOCKS5Proxy* udpProxy=new NetworkSocketSOCKS5Proxy(tcp, udpSocket, proxyUsername, proxyPassword);
	udpProxy->InitConnection();
	udpProxy->Open();
	if(udpProxy->IsFailed()){
		udpProxy->Close();
		delete udpProxy;
		useTCP=true;
		useUDP=false;
		udpConnectivityState=UDP_NOT_AVAILABLE;
	}else{
		udpSocket=udpProxy;
	}
}

void VoIPController::RunRecvThread(void* arg){
	LOGI("Receive thread starting");
	unsigned char *buffer = (unsigned char *)malloc(1500);
	NetworkPacket packet={0};
	while(runReceiver){
		packet.data=buffer;
		packet.length=1500;

		vector<NetworkSocket*> readSockets;
		vector<NetworkSocket*> errorSockets;
		readSockets.push_back(udpSocket);
		errorSockets.push_back(realUdpSocket);

		{
			MutexGuard m(endpointsMutex);
			for(shared_ptr<Endpoint>& e:endpoints){
				if(e->type==Endpoint::TYPE_TCP_RELAY){
					if(e->socket){
						readSockets.push_back(e->socket);
						errorSockets.push_back(e->socket);
					}
				}
			}
		}

		{
			MutexGuard m(socketSelectMutex);
			bool selRes=NetworkSocket::Select(readSockets, errorSockets, selectCanceller);
			if(!selRes){
				LOGV("Select canceled");
				continue;
			}
		}
		if(!runReceiver)
			return;

		if(!errorSockets.empty()){
			if(find(errorSockets.begin(), errorSockets.end(), realUdpSocket)!=errorSockets.end()){
				LOGW("UDP socket failed");
				SetState(STATE_FAILED);
				return;
			}
			MutexGuard m(endpointsMutex);
			for(vector<NetworkSocket*>::iterator itr=errorSockets.begin();itr!=errorSockets.end();++itr){
				for(shared_ptr<Endpoint>& e:endpoints){
					if(e->socket && e->socket==*itr){
						e->socket->Close();
						delete e->socket;
						e->socket=NULL;
						LOGI("Closing failed TCP socket for %s:%u", e->GetAddress().ToString().c_str(), e->port);
					}
				}
			}
			continue;
		}

		//NetworkSocket* socket=NULL;

		/*if(find(readSockets.begin(), readSockets.end(), realUdpSocket)!=readSockets.end()){
			socket=udpSocket;
		}else if(readSockets.size()>0){
			socket=readSockets[0];
		}else{
			LOGI("no sockets to read from");
			continue;
		}*/

		for(NetworkSocket*& socket:readSockets){
			socket->Receive(&packet);
			if(!packet.address){
				LOGE("Packet has null address. This shouldn't happen.");
				continue;
			}
			size_t len=packet.length;
			if(!len){
				LOGE("Packet has zero length.");
				continue;
			}
			//LOGV("Received %d bytes from %s:%d at %.5lf", len, packet.address->ToString().c_str(), packet.port, GetCurrentTime());
			shared_ptr<Endpoint> srcEndpoint;

			IPv4Address *src4=dynamic_cast<IPv4Address *>(packet.address);
			if(src4){
				MutexGuard m(endpointsMutex);
				for(shared_ptr<Endpoint> &e:endpoints){
					if(e->address==*src4 && e->port==packet.port){
						if((e->type!=Endpoint::TYPE_TCP_RELAY && packet.protocol==PROTO_UDP) || (e->type==Endpoint::TYPE_TCP_RELAY && packet.protocol==PROTO_TCP)){
							srcEndpoint=e;
							break;
						}
					}
				}
			}else{
				IPv6Address *src6=dynamic_cast<IPv6Address *>(packet.address);
				if(src6){
					MutexGuard m(endpointsMutex);
					for(shared_ptr<Endpoint> &e:endpoints){
						if(e->v6address==*src6 && e->port==packet.port && e->address.IsEmpty()){
							if((e->type!=Endpoint::TYPE_TCP_RELAY && packet.protocol==PROTO_UDP) || (e->type==Endpoint::TYPE_TCP_RELAY && packet.protocol==PROTO_TCP)){
								srcEndpoint=e;
								break;
							}
						}
					}
				}
			}

			if(!srcEndpoint){
				LOGW("Received a packet from unknown source %s:%u", packet.address->ToString().c_str(), packet.port);
				continue;
			}
			if(len<=0){
				//LOGW("error receiving: %d / %s", errno, strerror(errno));
				continue;
			}
			if(IS_MOBILE_NETWORK(networkType))
				stats.bytesRecvdMobile+=(uint64_t) len;
			else
				stats.bytesRecvdWifi+=(uint64_t) len;
			try{
				ProcessIncomingPacket(packet, srcEndpoint);
			}catch(out_of_range& x){
				LOGW("Error parsing packet: %s", x.what());
			}
		}
	}
	free(buffer);
	LOGI("=== recv thread exiting ===");
}

void VoIPController::RunSendThread(void* arg){
	unsigned char buf[1500];
	while(runReceiver){
		PendingOutgoingPacket pkt=sendQueue->GetBlocking();
		//if(pkt.data.Length()){
			shared_ptr<Endpoint> endpoint;
			if(pkt.endpoint){
				endpoint=GetEndpointByID(pkt.endpoint);
			}
			if(!endpoint){ // either packet has no endpoint specified or it no longer exists
				endpoint=currentEndpoint;
			}
			if((endpoint->type==Endpoint::TYPE_TCP_RELAY && useTCP) || (endpoint->type!=Endpoint::TYPE_TCP_RELAY && useUDP)){
				BufferOutputStream p(buf, sizeof(buf));
				WritePacketHeader(pkt.seq, &p, pkt.type, (uint32_t)pkt.len);
				p.WriteBytes(pkt.data);
				if(pkt.type==PKT_STREAM_DATA){
					unsentStreamPackets--;
				}
				SendPacket(p.GetBuffer(), p.GetLength(), endpoint, pkt);
			}
		//}else{
		//	LOGE("tried to send null packet");
		//}
	}
	LOGI("=== send thread exiting ===");
}

void VoIPController::ProcessIncomingPacket(NetworkPacket &packet, shared_ptr<Endpoint> srcEndpoint){
	unsigned char* buffer=packet.data;
	size_t len=packet.length;
	BufferInputStream in(buffer, (size_t)len);
	if(memcmp(buffer, srcEndpoint->type==Endpoint::TYPE_UDP_RELAY || srcEndpoint->type==Endpoint::TYPE_TCP_RELAY ? (void*)srcEndpoint->peerTag : (void*)callID, 16)!=0){
		LOGW("Received packet has wrong peerTag");
		return;
	}
	in.Seek(16);
	if(in.Remaining()>=16 && (srcEndpoint->type==Endpoint::TYPE_UDP_RELAY || srcEndpoint->type==Endpoint::TYPE_TCP_RELAY)
	   && *reinterpret_cast<uint64_t*>(buffer+16)==0xFFFFFFFFFFFFFFFFLL && *reinterpret_cast<uint32_t*>(buffer+24)==0xFFFFFFFF){
		// relay special request response
		in.Seek(16+12);
		uint32_t tlid=(uint32_t) in.ReadInt32();

		if(tlid==TLID_UDP_REFLECTOR_SELF_INFO){
			if(srcEndpoint->type==Endpoint::TYPE_UDP_RELAY /*&& udpConnectivityState==UDP_PING_SENT*/ && in.Remaining()>=32){
				int32_t date=in.ReadInt32();
				int64_t queryID=in.ReadInt64();
				unsigned char myIP[16];
				in.ReadBytes(myIP, 16);
				int32_t myPort=in.ReadInt32();
				//udpConnectivityState=UDP_AVAILABLE;
				LOGV("Received UDP ping reply from %s:%d: date=%d, queryID=%ld, my IP=%s, my port=%d", srcEndpoint->address.ToString().c_str(), srcEndpoint->port, date, (long int)queryID, IPv4Address(*reinterpret_cast<uint32_t*>(myIP+12)).ToString().c_str(), myPort);
				srcEndpoint->udpPongCount++;
				if(srcEndpoint->IsIPv6Only() && !didSendIPv6Endpoint){
					IPv6Address realAddr(myIP);
					if(realAddr==myIPv6){
						LOGI("Public IPv6 matches local address");
						useIPv6=true;
						if(allowP2p){
							didSendIPv6Endpoint=true;
							BufferOutputStream o(18);
							o.WriteBytes(myIP, 16);
							o.WriteInt16(udpSocket->GetLocalPort());
							Buffer b(move(o));
							SendExtra(b, EXTRA_TYPE_IPV6_ENDPOINT);
						}
					}
				}
			}
		}else if(tlid==TLID_UDP_REFLECTOR_PEER_INFO){
			if(waitingForRelayPeerInfo && in.Remaining()>=16){
				MutexGuard _m(endpointsMutex);
				uint32_t myAddr=(uint32_t) in.ReadInt32();
				uint32_t myPort=(uint32_t) in.ReadInt32();
				uint32_t peerAddr=(uint32_t) in.ReadInt32();
				uint32_t peerPort=(uint32_t) in.ReadInt32();
				for(vector<shared_ptr<Endpoint>>::iterator itrtr=endpoints.begin(); itrtr!=endpoints.end(); ++itrtr){
					shared_ptr<Endpoint>  ep=*itrtr;
					if(ep->type==Endpoint::TYPE_UDP_P2P_INET && !ep->IsIPv6Only()){
						if(currentEndpoint==ep)
							currentEndpoint=preferredRelay;
						endpoints.erase(itrtr);
						break;
					}
				}
				for(vector<shared_ptr<Endpoint>>::iterator itrtr=endpoints.begin(); itrtr!=endpoints.end(); ++itrtr){
					shared_ptr<Endpoint> ep=*itrtr;
					if(ep->type==Endpoint::TYPE_UDP_P2P_LAN){
						if(currentEndpoint==ep)
							currentEndpoint=preferredRelay;
						endpoints.erase(itrtr);
						break;
					}
				}
				IPv4Address _peerAddr(peerAddr);
				IPv6Address emptyV6(string("::0"));
				unsigned char peerTag[16];
				endpoints.push_back(make_shared<Endpoint>((int64_t)(FOURCC('P','2','P','4')) << 32, (uint16_t) peerPort, _peerAddr, emptyV6, Endpoint::TYPE_UDP_P2P_INET, peerTag));
				LOGW("Received reflector peer info, my=%08X:%u, peer=%08X:%u", myAddr, myPort, peerAddr, peerPort);
				if(myAddr==peerAddr){
					LOGW("Detected LAN");
					IPv4Address lanAddr(0);
					udpSocket->GetLocalInterfaceInfo(&lanAddr, NULL);

					BufferOutputStream pkt(8);
					pkt.WriteInt32(lanAddr.GetAddress());
					pkt.WriteInt32(udpSocket->GetLocalPort());
					if(peerVersion<6){
						SendPacketReliably(PKT_LAN_ENDPOINT, pkt.GetBuffer(), pkt.GetLength(), 0.5, 10);
					}else{
						Buffer buf(move(pkt));
						SendExtra(buf, EXTRA_TYPE_LAN_ENDPOINT);
					}
				}
				waitingForRelayPeerInfo=false;
			}
		}else{
			LOGV("Received relay response with unknown tl id: 0x%08X", tlid);
		}
		return;
	}
	if(in.Remaining()<40){
		LOGV("Received packet is too small");
		return;
	}

	bool retryWith2=false;

	if(!useMTProto2){
		unsigned char fingerprint[8], msgHash[16];
		in.ReadBytes(fingerprint, 8);
		in.ReadBytes(msgHash, 16);
		if(memcmp(fingerprint, keyFingerprint, 8)!=0){
			LOGW("Received packet has wrong key fingerprint");
			return;
		}
		unsigned char key[32], iv[32];
		KDF(msgHash, isOutgoing ? 8 : 0, key, iv);
		unsigned char aesOut[MSC_STACK_FALLBACK(in.Remaining(), 1500)];
		if(in.Remaining()>sizeof(aesOut))
			return;
		crypto.aes_ige_decrypt((unsigned char *) buffer+in.GetOffset(), aesOut, in.Remaining(), key, iv);
		BufferInputStream _in(aesOut, in.Remaining());
		unsigned char sha[SHA1_LENGTH];
		uint32_t _len=(uint32_t) _in.ReadInt32();
		if(_len>_in.Remaining())
			_len=_in.Remaining();
		crypto.sha1((uint8_t *) (aesOut), (size_t) (_len+4), sha);
		if(memcmp(msgHash, sha+(SHA1_LENGTH-16), 16)!=0){
			LOGW("Received packet has wrong hash after decryption");
			if(state==STATE_WAIT_INIT || state==STATE_WAIT_INIT_ACK)
				retryWith2=true;
			else
				return;
		}else{
			memcpy(buffer+in.GetOffset(), aesOut, in.Remaining());
			in.ReadInt32();
		}
	}

	if(useMTProto2 || retryWith2){
		in.Seek(16); // peer tag

		unsigned char fingerprint[8], msgKey[16];
		in.ReadBytes(fingerprint, 8);
		if(memcmp(fingerprint, keyFingerprint, 8)!=0){
			LOGW("Received packet has wrong key fingerprint");
			return;
		}
		in.ReadBytes(msgKey, 16);

		unsigned char decrypted[1500];
		unsigned char aesKey[32], aesIv[32];
		KDF2(msgKey, isOutgoing ? 8 : 0, aesKey, aesIv);
		size_t decryptedLen=in.Remaining();
		if(decryptedLen>sizeof(decrypted))
			return;
		//LOGV("-> MSG KEY: %08x %08x %08x %08x, hashed %u", *reinterpret_cast<int32_t*>(msgKey), *reinterpret_cast<int32_t*>(msgKey+4), *reinterpret_cast<int32_t*>(msgKey+8), *reinterpret_cast<int32_t*>(msgKey+12), decryptedLen-4);

		/*uint8_t *decryptOffset = packet.data + in.GetOffset();
		if ((((intptr_t)decryptOffset) % sizeof(long)) != 0) {
			LOGE("alignment2 packet.data+in.GetOffset()");
		}
		if (decryptedLen % sizeof(long) != 0) {
			LOGE("alignment2 decryptedLen");
		}*/
		crypto.aes_ige_decrypt(packet.data+in.GetOffset(), decrypted, decryptedLen, aesKey, aesIv);

		in=BufferInputStream(decrypted, decryptedLen);
		//LOGD("received packet length: %d", in.ReadInt32());

		BufferOutputStream buf(decryptedLen+32);
		size_t x=isOutgoing ? 8 : 0;
		buf.WriteBytes(encryptionKey+88+x, 32);
		buf.WriteBytes(decrypted+4, decryptedLen-4);
		unsigned char msgKeyLarge[32];
		crypto.sha256(buf.GetBuffer(), buf.GetLength(), msgKeyLarge);

		if(memcmp(msgKey, msgKeyLarge+8, 16)!=0){
			LOGW("Received packet has wrong hash");
			return;
		}

		uint32_t innerLen=(uint32_t) in.ReadInt32();
		if(innerLen>decryptedLen-4){
			LOGW("Received packet has wrong inner length (%d with total of %u)", (int)innerLen, (unsigned int)decryptedLen);
			return;
		}
		if(decryptedLen-innerLen<12){
			LOGW("Received packet has too little padding (%u)", (unsigned int)(decryptedLen-innerLen));
			return;
		}
		memcpy(buffer, decrypted+4, innerLen);
		in=BufferInputStream(buffer, (size_t) innerLen);
		if(retryWith2){
			LOGD("Successfully decrypted packet in MTProto2.0 fallback, upgrading");
			useMTProto2=true;
		}
	}

	lastRecvPacketTime=GetCurrentTime();

	if(state==STATE_RECONNECTING){
		LOGI("Received a valid packet while reconnecting - setting state to established");
		SetState(STATE_ESTABLISHED);
	}

	/*decryptedAudioBlock random_id:long random_bytes:string flags:# voice_call_id:flags.2?int128 in_seq_no:flags.4?int out_seq_no:flags.4?int
 * recent_received_mask:flags.5?int proto:flags.3?int extra:flags.1?string raw_data:flags.0?string = DecryptedAudioBlock
simpleAudioBlock random_id:long random_bytes:string raw_data:string = DecryptedAudioBlock;
*/
	uint32_t ackId, pseq, acks;
	unsigned char type, pflags;
	uint32_t tlid=(uint32_t) in.ReadInt32();
	uint32_t packetInnerLen=0;
	if(tlid==TLID_DECRYPTED_AUDIO_BLOCK){
		in.ReadInt64(); // random id
		uint32_t randLen=(uint32_t) in.ReadTlLength();
		in.Seek(in.GetOffset()+randLen+pad4(randLen));
		uint32_t flags=(uint32_t) in.ReadInt32();
		type=(unsigned char) ((flags >> 24) & 0xFF);
		if(!(flags & PFLAG_HAS_SEQ && flags & PFLAG_HAS_RECENT_RECV)){
			LOGW("Received packet doesn't have PFLAG_HAS_SEQ, PFLAG_HAS_RECENT_RECV, or both");

			return;
		}
		if(flags & PFLAG_HAS_CALL_ID){
			unsigned char pktCallID[16];
			in.ReadBytes(pktCallID, 16);
			if(memcmp(pktCallID, callID, 16)!=0){
				LOGW("Received packet has wrong call id");

				lastError=ERROR_UNKNOWN;
				SetState(STATE_FAILED);
				return;
			}
		}
		ackId=(uint32_t) in.ReadInt32();
		pseq=(uint32_t) in.ReadInt32();
		acks=(uint32_t) in.ReadInt32();
		if(flags & PFLAG_HAS_PROTO){
			uint32_t proto=(uint32_t) in.ReadInt32();
			if(proto!=PROTOCOL_NAME){
				LOGW("Received packet uses wrong protocol");

				lastError=ERROR_INCOMPATIBLE;
				SetState(STATE_FAILED);
				return;
			}
		}
		if(flags & PFLAG_HAS_EXTRA){
			uint32_t extraLen=(uint32_t) in.ReadTlLength();
			in.Seek(in.GetOffset()+extraLen+pad4(extraLen));
		}
		if(flags & PFLAG_HAS_DATA){
			packetInnerLen=in.ReadTlLength();
		}
		pflags=0;
	}else if(tlid==TLID_SIMPLE_AUDIO_BLOCK){
		in.ReadInt64(); // random id
		uint32_t randLen=(uint32_t) in.ReadTlLength();
		in.Seek(in.GetOffset()+randLen+pad4(randLen));
		packetInnerLen=in.ReadTlLength();
		type=in.ReadByte();
		ackId=(uint32_t) in.ReadInt32();
		pseq=(uint32_t) in.ReadInt32();
		acks=(uint32_t) in.ReadInt32();
		if(peerVersion>=6)
			pflags=in.ReadByte();
		else
			pflags=0;
	}else{
		LOGW("Received a packet of unknown type %08X", tlid);

		return;
	}
	packetsReceived++;
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

			return;
		}
		recvPacketTimes[lastRemoteSeq-pseq]=GetCurrentTime();
	}else if(lastRemoteSeq-pseq>=32){
		LOGW("Packet %u is out of order and too late", pseq);

		return;
	}
	if(seqgt(ackId, lastRemoteAckSeq)){
		//uint32_t diff=ackId-lastRemoteAckSeq;
		/*if(diff>31){
			memset(remoteAcks, 0, 32*sizeof(double));
		}else{
			memmove(&remoteAcks[diff], remoteAcks, (32-diff)*sizeof(double));
			if(diff>1){
				memset(remoteAcks, 0, diff*sizeof(double));
			}
			remoteAcks[0]=GetCurrentTime();
		}*/
		MutexGuard _m(queuedPacketsMutex);
		if(waitingForAcks && lastRemoteAckSeq>=firstSentPing){
			rttHistory.Reset();
			waitingForAcks=false;
			dontSendPackets=10;
			messageThread.Post([this]{
				dontSendPackets=0;
			}, 1.0);
			LOGI("resuming sending");
		}
		lastRemoteAckSeq=ackId;
		conctl->PacketAcknowledged(ackId);
		unsigned int i;
		for(i=0;i<31;i++){
			for(vector<RecentOutgoingPacket>::iterator itr=recentOutgoingPackets.begin();itr!=recentOutgoingPackets.end();++itr){
				if(itr->ackTime!=0)
					continue;
				if(((acks >> (31-i)) & 1) && itr->seq==ackId-(i+1)){
					itr->ackTime=GetCurrentTime();
					conctl->PacketAcknowledged(itr->seq);
				}
			}
			/*if(remoteAcks[i+1]==0){
				if((acks >> (31-i)) & 1){
					remoteAcks[i+1]=GetCurrentTime();
					conctl->PacketAcknowledged(ackId-(i+1));
				}
			}*/
		}
		for(i=0;i<queuedPackets.size();i++){
			QueuedPacket& qp=queuedPackets[i];
			int j;
			bool didAck=false;
			for(j=0;j<16;j++){
				LOGD("queued packet %u, seq %u=%u", i, j, qp.seqs[j]);
				if(qp.seqs[j]==0)
					break;
				int remoteAcksIndex=lastRemoteAckSeq-qp.seqs[j];
				//LOGV("remote acks index %u, value %f", remoteAcksIndex, remoteAcksIndex>=0 && remoteAcksIndex<32 ? remoteAcks[remoteAcksIndex] : -1);
				if(seqgt(lastRemoteAckSeq, qp.seqs[j]) && remoteAcksIndex>=0 && remoteAcksIndex<32){
					for(RecentOutgoingPacket& opkt:recentOutgoingPackets){
						if(opkt.seq==qp.seqs[j] && opkt.ackTime>0){
							LOGD("did ack seq %u, removing", qp.seqs[j]);
							didAck=true;
							break;
						}
					}
					if(didAck)
						break;
				}
			}
			if(didAck){
				queuedPackets.erase(queuedPackets.begin()+i);
				i--;
				continue;
			}
		}
		for(vector<UnacknowledgedExtraData>::iterator x=currentExtras.begin();x!=currentExtras.end();){
			if(x->firstContainingSeq!=0 && (lastRemoteAckSeq==x->firstContainingSeq || seqgt(lastRemoteAckSeq, x->firstContainingSeq))){
				LOGV("Peer acknowledged extra type %u length %lu", x->type, x->data.Length());
				ProcessAcknowledgedOutgoingExtra(*x);
				x=currentExtras.erase(x);
				continue;
			}
			++x;
		}
	}

	if(srcEndpoint!=currentEndpoint && (srcEndpoint->type==Endpoint::TYPE_UDP_RELAY || srcEndpoint->type==Endpoint::TYPE_TCP_RELAY) && ((currentEndpoint->type!=Endpoint::TYPE_UDP_RELAY && currentEndpoint->type!=Endpoint::TYPE_TCP_RELAY) || currentEndpoint->averageRTT==0)){
		if(seqgt(lastSentSeq-32, lastRemoteAckSeq)){
			currentEndpoint=srcEndpoint;
			LOGI("Peer network address probably changed, switching to relay");
			if(allowP2p)
				SendPublicEndpointsRequest();
		}
	}

	if(pflags & XPFLAG_HAS_EXTRA){
		unsigned char extraCount=in.ReadByte();
		for(int i=0;i<extraCount;i++){
			size_t extraLen=in.ReadByte();
			Buffer xbuffer(extraLen);
			in.ReadBytes(*xbuffer, extraLen);
			ProcessExtraData(xbuffer);
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
			if((srcEndpoint->type==Endpoint::TYPE_UDP_RELAY && udpConnectivityState!=UDP_BAD && udpConnectivityState!=UDP_NOT_AVAILABLE) || srcEndpoint->type==Endpoint::TYPE_TCP_RELAY){
				currentEndpoint=srcEndpoint;
				if(srcEndpoint->type==Endpoint::TYPE_UDP_RELAY || (useTCP && srcEndpoint->type==Endpoint::TYPE_TCP_RELAY))
					preferredRelay=srcEndpoint;
			}
			LogDebugInfo();
			peerVersion=(uint32_t) in.ReadInt32();
			LOGI("Peer version is %d", peerVersion);
			uint32_t minVer=(uint32_t) in.ReadInt32();
			if(minVer>PROTOCOL_VERSION || peerVersion<MIN_PROTOCOL_VERSION){
				lastError=ERROR_INCOMPATIBLE;

				SetState(STATE_FAILED);
				return;
			}
			uint32_t flags=(uint32_t) in.ReadInt32();
			if(flags & INIT_FLAG_DATA_SAVING_ENABLED){
				dataSavingRequestedByPeer=true;
				UpdateDataSavingState();
				UpdateAudioBitrateLimit();
			}
			if(flags & INIT_FLAG_GROUP_CALLS_SUPPORTED){
				peerCapabilities|=TGVOIP_PEER_CAP_GROUP_CALLS;
			}

			unsigned int i;
			unsigned int numSupportedAudioCodecs=in.ReadByte();
			for(i=0; i<numSupportedAudioCodecs; i++){
				if(peerVersion<5)
					in.ReadByte(); // ignore for now
				else
					in.ReadInt32();
			}
			unsigned int numSupportedVideoCodecs=in.ReadByte();
			for(i=0; i<numSupportedVideoCodecs; i++){
				if(peerVersion<5)
					in.ReadByte(); // ignore for now
				else
					in.ReadInt32();
			}

			BufferOutputStream out(1024);

			out.WriteInt32(PROTOCOL_VERSION);
			out.WriteInt32(MIN_PROTOCOL_VERSION);

			out.WriteByte((unsigned char) outgoingStreams.size());
			for(vector<shared_ptr<Stream>>::iterator s=outgoingStreams.begin(); s!=outgoingStreams.end(); ++s){
				out.WriteByte((*s)->id);
				out.WriteByte((*s)->type);
				if(peerVersion<5)
					out.WriteByte((unsigned char) ((*s)->codec==CODEC_OPUS ? CODEC_OPUS_OLD : 0));
				else
					out.WriteInt32((*s)->codec);
				out.WriteInt16((*s)->frameDuration);
				out.WriteByte((unsigned char) ((*s)->enabled ? 1 : 0));
			}
			sendQueue->Put(PendingOutgoingPacket{
					/*.seq=*/GenerateOutSeq(),
					/*.type=*/PKT_INIT_ACK,
					/*.len=*/out.GetLength(),
					/*.data=*/Buffer(move(out)),
					/*.endpoint=*/0
			});
		}
	}
	if(type==PKT_INIT_ACK){
		LOGD("Received init ack");

		if(!receivedInitAck){
			receivedInitAck=true;

			messageThread.Cancel(initTimeoutID);
			initTimeoutID=MessageThread::INVALID_ID;

			if(packetInnerLen>10){
				peerVersion=in.ReadInt32();
				uint32_t minVer=(uint32_t) in.ReadInt32();
				if(minVer>PROTOCOL_VERSION || peerVersion<MIN_PROTOCOL_VERSION){
					lastError=ERROR_INCOMPATIBLE;

					SetState(STATE_FAILED);
					return;
				}
			}else{
				peerVersion=1;
			}

			LOGI("peer version from init ack %d", peerVersion);

			unsigned char streamCount=in.ReadByte();
			if(streamCount==0)
				return;

			int i;
			shared_ptr<Stream> incomingAudioStream=NULL;
			for(i=0; i<streamCount; i++){
				shared_ptr<Stream> stm=make_shared<Stream>();
				stm->id=in.ReadByte();
				stm->type=in.ReadByte();
				if(peerVersion<5){
					unsigned char codec=in.ReadByte();
					if(codec==CODEC_OPUS_OLD)
						stm->codec=CODEC_OPUS;
				}else{
					stm->codec=(uint32_t) in.ReadInt32();
				}
				stm->frameDuration=(uint16_t) in.ReadInt16();
				stm->enabled=in.ReadByte()==1;
				if(stm->type==STREAM_TYPE_AUDIO){
					stm->jitterBuffer=make_shared<JitterBuffer>(nullptr, stm->frameDuration);
					if(stm->frameDuration>50)
						stm->jitterBuffer->SetMinPacketCount((uint32_t) ServerConfig::GetSharedInstance()->GetInt("jitter_initial_delay_60", 3));
					else if(stm->frameDuration>30)
						stm->jitterBuffer->SetMinPacketCount((uint32_t) ServerConfig::GetSharedInstance()->GetInt("jitter_initial_delay_40", 4));
					else
						stm->jitterBuffer->SetMinPacketCount((uint32_t) ServerConfig::GetSharedInstance()->GetInt("jitter_initial_delay_20", 6));
					stm->decoder=NULL;
				}else if(stm->type==STREAM_TYPE_VIDEO){
					if(!stm->packetReassembler){
						stm->packetReassembler=make_shared<PacketReassembler>();
					}
				}else{
					LOGW("Unknown incoming stream type: %d", stm->type);
					continue;
				}
				incomingStreams.push_back(stm);
				if(stm->type==STREAM_TYPE_AUDIO && !incomingAudioStream)
					incomingAudioStream=stm;
			}
			if(!incomingAudioStream)
				return;

			if(peerVersion>=5 && !useMTProto2){
				useMTProto2=true;
				LOGD("MTProto2 wasn't initially enabled for whatever reason but peer supports it; upgrading");
			}

			{
				MutexGuard m(audioIOMutex);
				if(!audioInput){
					StartAudio();
				}
			}
			messageThread.Post([this]{
				if(state==STATE_WAIT_INIT_ACK){
					SetState(STATE_ESTABLISHED);
				}
			}, ServerConfig::GetSharedInstance()->GetDouble("established_delay_if_no_stream_data", 1.5));
			if(allowP2p)
				SendPublicEndpointsRequest();
		}
	}
	if(type==PKT_STREAM_DATA || type==PKT_STREAM_DATA_X2 || type==PKT_STREAM_DATA_X3){
		if(!receivedFirstStreamPacket){
			receivedFirstStreamPacket=true;
			if(state!=STATE_ESTABLISHED && receivedInitAck){
				messageThread.Post([this](){
					SetState(STATE_ESTABLISHED);
				}, .5);
				LOGW("First audio packet - setting state to ESTABLISHED");
			}
		}
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
		if(srcEndpoint->type==Endpoint::TYPE_UDP_RELAY && srcEndpoint!=peerPreferredRelay){
			peerPreferredRelay=srcEndpoint;
		}
		for(i=0;i<count;i++){
			unsigned char streamID=in.ReadByte();
			unsigned char flags=(unsigned char) (streamID & 0xC0);
			uint16_t sdlen=(uint16_t) (flags & STREAM_DATA_FLAG_LEN16 ? in.ReadInt16() : in.ReadByte());
			uint32_t pts=(uint32_t) in.ReadInt32();
			//LOGD("stream data, pts=%d, len=%d, rem=%d", pts, sdlen, in.Remaining());
			audioTimestampIn=pts;
			if(!audioOutStarted && audioOutput){
				MutexGuard m(audioIOMutex);
				audioOutput->Start();
				audioOutStarted=true;
			}
			if(in.GetOffset()+sdlen>len){
				return;
			}
			if(incomingStreams.size()>0 && incomingStreams[0]->jitterBuffer /*&& !incomingStreams[0]->extraECEnabled*/)
				incomingStreams[0]->jitterBuffer->HandleInput((unsigned char*) (buffer+in.GetOffset()), sdlen, pts, false);
			if(i<count-1)
				in.Seek(in.GetOffset()+sdlen);
		}
	}
	if(type==PKT_PING){
		//LOGD("Received ping from %s:%d", srcEndpoint->address.ToString().c_str(), srcEndpoint->port);
		if(srcEndpoint->type!=Endpoint::TYPE_UDP_RELAY && srcEndpoint->type!=Endpoint::TYPE_TCP_RELAY && !allowP2p){
			LOGW("Received p2p ping but p2p is disabled by manual override");
			return;
		}
		BufferOutputStream pkt(128);
		pkt.WriteInt32(pseq);
		sendQueue->Put(PendingOutgoingPacket{
				/*.seq=*/GenerateOutSeq(),
				/*.type=*/PKT_PONG,
				/*.len=*/pkt.GetLength(),
				/*.data=*/Buffer(move(pkt)),
				/*.endpoint=*/srcEndpoint->id,
		});
	}
	if(type==PKT_PONG){
		if(packetInnerLen>=4){
			uint32_t pingSeq=(uint32_t) in.ReadInt32();
			if(pingSeq==srcEndpoint->lastPingSeq){
				srcEndpoint->rtts.Add(GetCurrentTime()-srcEndpoint->lastPingTime);
				srcEndpoint->averageRTT=srcEndpoint->rtts.NonZeroAverage();
				LOGD("Current RTT via %s: %.3f, average: %.3f", packet.address->ToString().c_str(), srcEndpoint->rtts[0], srcEndpoint->averageRTT);
			}
		}
	}
	if(type==PKT_STREAM_STATE){
		unsigned char id=in.ReadByte();
		unsigned char enabled=in.ReadByte();
		for(vector<shared_ptr<Stream>>::iterator s=incomingStreams.begin();s!=incomingStreams.end();++s){
			if((*s)->id==id){
				(*s)->enabled=enabled==1;
				UpdateAudioOutputState();
				break;
			}
		}
	}
	if(type==PKT_LAN_ENDPOINT){
		LOGV("received lan endpoint");
		uint32_t peerAddr=(uint32_t) in.ReadInt32();
		uint16_t peerPort=(uint16_t) in.ReadInt32();
		MutexGuard m(endpointsMutex);
		bool found=false;
		for(shared_ptr<Endpoint>& e:endpoints){
			if(e->type==Endpoint::TYPE_UDP_P2P_LAN){
				if(currentEndpoint==e)
					currentEndpoint=preferredRelay;
				found=true;
				e->address=peerAddr;
				break;
			}
		}
		if(!found){
			IPv4Address v4addr(peerAddr);
			IPv6Address v6addr(string("::0"));
			unsigned char peerTag[16];
			endpoints.push_back(make_shared<Endpoint>((int64_t)(FOURCC('L','A','N','4')) << 32, peerPort, v4addr, v6addr, Endpoint::TYPE_UDP_P2P_LAN, peerTag));
		}
	}
	if(type==PKT_NETWORK_CHANGED && currentEndpoint->type!=Endpoint::TYPE_UDP_RELAY && currentEndpoint->type!=Endpoint::TYPE_TCP_RELAY){
		currentEndpoint=preferredRelay;
		if(allowP2p)
			SendPublicEndpointsRequest();
		if(peerVersion>=2){
			uint32_t flags=(uint32_t) in.ReadInt32();
			dataSavingRequestedByPeer=(flags & INIT_FLAG_DATA_SAVING_ENABLED)==INIT_FLAG_DATA_SAVING_ENABLED;
			UpdateDataSavingState();
			UpdateAudioBitrateLimit();
			ResetEndpointPingStats();
		}
	}
	if(type==PKT_STREAM_EC){
		unsigned char streamID=in.ReadByte();
		uint32_t lastTimestamp=(uint32_t)in.ReadInt32();
		unsigned char count=in.ReadByte();
		for(shared_ptr<Stream>& stm:incomingStreams){
			if(stm->id==streamID){
				for(unsigned int i=0;i<count;i++){
					unsigned char dlen=in.ReadByte();
					unsigned char data[256];
					in.ReadBytes(data, dlen);
					if(stm->jitterBuffer){
						stm->jitterBuffer->HandleInput(data, dlen, lastTimestamp-(count-i-1)*stm->frameDuration, true);
					}
				}
				break;
			}
		}
	}
}

void VoIPController::ProcessExtraData(Buffer &data){
	BufferInputStream in(*data, data.Length());
	unsigned char type=in.ReadByte();
	unsigned char fullHash[SHA1_LENGTH];
	crypto.sha1(*data, data.Length(), fullHash);
	uint64_t hash=*reinterpret_cast<uint64_t*>(fullHash);
	if(lastReceivedExtrasByType[type]==hash){
		return;
	}
	lastReceivedExtrasByType[type]=hash;
	if(type==EXTRA_TYPE_STREAM_FLAGS){
		unsigned char id=in.ReadByte();
		uint32_t flags=static_cast<uint32_t>(in.ReadInt32());
		for(shared_ptr<Stream>& s:incomingStreams){
			if(s->id==id){
				s->enabled=(flags & STREAM_FLAG_ENABLED)==STREAM_FLAG_ENABLED;
				if(flags & STREAM_FLAG_EXTRA_EC){
					if(!s->extraECEnabled){
						s->extraECEnabled=true;
						if(s->jitterBuffer)
							s->jitterBuffer->SetMinPacketCount(4);
					}
				}else{
					if(s->extraECEnabled){
						s->extraECEnabled=false;
						if(s->jitterBuffer)
							s->jitterBuffer->SetMinPacketCount(2);
					}
				}
				UpdateAudioOutputState();
				break;
			}
		}
	}else if(type==EXTRA_TYPE_STREAM_CSD){

	}else if(type==EXTRA_TYPE_LAN_ENDPOINT){
		if(!allowP2p)
			return;
		LOGV("received lan endpoint (extra)");
		uint32_t peerAddr=(uint32_t) in.ReadInt32();
		uint16_t peerPort=(uint16_t) in.ReadInt32();
		MutexGuard m(endpointsMutex);
		bool found=false;
		for(shared_ptr<Endpoint>& e:endpoints){
			if(e->type==Endpoint::TYPE_UDP_P2P_LAN){
				if(currentEndpoint==e)
					currentEndpoint=preferredRelay;
				found=true;
				e->address=peerAddr;
				break;
			}
		}
		if(!found){
			IPv4Address v4addr(peerAddr);
			IPv6Address v6addr(string("::0"));
			unsigned char peerTag[16];
			endpoints.push_back(make_shared<Endpoint>((int64_t)(FOURCC('L','A','N','4')) << 32, peerPort, v4addr, v6addr, Endpoint::TYPE_UDP_P2P_LAN, peerTag));
		}
	}else if(type==EXTRA_TYPE_NETWORK_CHANGED){
		LOGI("Peer network changed");
		if(currentEndpoint->type!=Endpoint::TYPE_UDP_RELAY && currentEndpoint->type!=Endpoint::TYPE_TCP_RELAY)
			currentEndpoint=preferredRelay;
		if(allowP2p)
			SendPublicEndpointsRequest();
		uint32_t flags=(uint32_t) in.ReadInt32();
		dataSavingRequestedByPeer=(flags & INIT_FLAG_DATA_SAVING_ENABLED)==INIT_FLAG_DATA_SAVING_ENABLED;
		UpdateDataSavingState();
		UpdateAudioBitrateLimit();
		ResetEndpointPingStats();
	}else if(type==EXTRA_TYPE_GROUP_CALL_KEY){
		if(!didReceiveGroupCallKey && !didSendGroupCallKey){
			unsigned char groupKey[256];
			in.ReadBytes(groupKey, 256);
			messageThread.Post([this, groupKey]{
				if(callbacks.groupCallKeyReceived)
					callbacks.groupCallKeyReceived(this, groupKey);
			});
			didReceiveGroupCallKey=true;
		}
	}else if(type==EXTRA_TYPE_REQUEST_GROUP){
		if(!didInvokeUpgradeCallback){
			messageThread.Post([this]{
				if(callbacks.upgradeToGroupCallRequested)
					callbacks.upgradeToGroupCallRequested(this);
			});
			didInvokeUpgradeCallback=true;
		}
	}else if(type==EXTRA_TYPE_IPV6_ENDPOINT){
		if(!allowP2p)
			return;
		unsigned char _addr[16];
		in.ReadBytes(_addr, 16);
		IPv6Address addr(_addr);
		uint16_t port=static_cast<uint16_t>(in.ReadInt16());
		MutexGuard m(endpointsMutex);
		peerIPv6Available=true;
		for(shared_ptr<Endpoint>& e:endpoints){
			if(e->type==Endpoint::TYPE_UDP_P2P_INET && e->IsIPv6Only()){
				e->v6address=addr;
				if(!myIPv6.IsEmpty())
					currentEndpoint=e;
				return;
			}
		}
		shared_ptr<Endpoint> ep=make_shared<Endpoint>();
		ep->type=Endpoint::TYPE_UDP_P2P_INET;
		ep->port=port;
		ep->v6address=addr;
		ep->id=(int64_t)(FOURCC('P','2','P','6')) << 32;
		endpoints.push_back(ep);
		if(!myIPv6.IsEmpty())
			currentEndpoint=ep;
	}
}

void VoIPController::ProcessAcknowledgedOutgoingExtra(VoIPController::UnacknowledgedExtraData &extra){
	if(extra.type==EXTRA_TYPE_GROUP_CALL_KEY){
		if(!didReceiveGroupCallKeyAck){
			didReceiveGroupCallKeyAck=true;
			messageThread.Post([this]{
				if(callbacks.groupCallKeySent)
					callbacks.groupCallKeySent(this);
			});
		}
	}
}

Endpoint& VoIPController::GetRemoteEndpoint(){
	return *currentEndpoint;
}


void VoIPController::SendPacket(unsigned char *data, size_t len, shared_ptr<Endpoint> ep, PendingOutgoingPacket& srcPacket){
	if(stopping)
		return;
	if(ep->type==Endpoint::TYPE_TCP_RELAY && !useTCP)
		return;
	BufferOutputStream out(len+128);
	if(ep->type==Endpoint::TYPE_UDP_RELAY || ep->type==Endpoint::TYPE_TCP_RELAY)
		out.WriteBytes((unsigned char*)ep->peerTag, 16);
	else
		out.WriteBytes(callID, 16);
	if(len>0){
		if(useMTProto2){
			BufferOutputStream inner(len+128);
			inner.WriteInt32((uint32_t)len);
			inner.WriteBytes(data, len);
			size_t padLen=16-inner.GetLength()%16;
			if(padLen<12)
				padLen+=16;
			unsigned char padding[28];
			crypto.rand_bytes((uint8_t *) padding, padLen);
			inner.WriteBytes(padding, padLen);
			assert(inner.GetLength()%16==0);

			unsigned char key[32], iv[32], msgKey[16];
			out.WriteBytes(keyFingerprint, 8);
			BufferOutputStream buf(len+32);
			size_t x=isOutgoing ? 0 : 8;
			buf.WriteBytes(encryptionKey+88+x, 32);
			buf.WriteBytes(inner.GetBuffer()+4, inner.GetLength()-4);
			unsigned char msgKeyLarge[32];
			crypto.sha256(buf.GetBuffer(), buf.GetLength(), msgKeyLarge);
			memcpy(msgKey, msgKeyLarge+8, 16);
			KDF2(msgKey, isOutgoing ? 0 : 8, key, iv);
			out.WriteBytes(msgKey, 16);
			//LOGV("<- MSG KEY: %08x %08x %08x %08x, hashed %u", *reinterpret_cast<int32_t*>(msgKey), *reinterpret_cast<int32_t*>(msgKey+4), *reinterpret_cast<int32_t*>(msgKey+8), *reinterpret_cast<int32_t*>(msgKey+12), inner.GetLength()-4);

			unsigned char aesOut[MSC_STACK_FALLBACK(inner.GetLength(), 1500)];
			crypto.aes_ige_encrypt(inner.GetBuffer(), aesOut, inner.GetLength(), key, iv);
			out.WriteBytes(aesOut, inner.GetLength());
		}else{
			BufferOutputStream inner(len+128);
			inner.WriteInt32(len);
			inner.WriteBytes(data, len);
			if(inner.GetLength()%16!=0){
				size_t padLen=16-inner.GetLength()%16;
				unsigned char padding[16];
				crypto.rand_bytes((uint8_t *) padding, padLen);
				inner.WriteBytes(padding, padLen);
			}
			assert(inner.GetLength()%16==0);
			unsigned char key[32], iv[32], msgHash[SHA1_LENGTH];
			crypto.sha1((uint8_t *) inner.GetBuffer(), len+4, msgHash);
			out.WriteBytes(keyFingerprint, 8);
			out.WriteBytes((msgHash+(SHA1_LENGTH-16)), 16);
			KDF(msgHash+(SHA1_LENGTH-16), isOutgoing ? 0 : 8, key, iv);
			unsigned char aesOut[MSC_STACK_FALLBACK(inner.GetLength(), 1500)];
			crypto.aes_ige_encrypt(inner.GetBuffer(), aesOut, inner.GetLength(), key, iv);
			out.WriteBytes(aesOut, inner.GetLength());
		}
	}
	//LOGV("Sending %d bytes to %s:%d", out.GetLength(), ep->address.ToString().c_str(), ep->port);

	NetworkPacket pkt={0};
	pkt.address=&ep->GetAddress();
	pkt.port=ep->port;
	pkt.length=out.GetLength();
	pkt.data=out.GetBuffer();
	pkt.protocol=ep->type==Endpoint::TYPE_TCP_RELAY ? PROTO_TCP : PROTO_UDP;
	ActuallySendPacket(pkt, ep);
}

void VoIPController::ActuallySendPacket(NetworkPacket &pkt, shared_ptr<Endpoint> ep){
	//LOGI("Sending packet of %d bytes", pkt.length);
	if(IS_MOBILE_NETWORK(networkType))
		stats.bytesSentMobile+=(uint64_t)pkt.length;
	else
		stats.bytesSentWifi+=(uint64_t)pkt.length;
	if(ep->type==Endpoint::TYPE_TCP_RELAY){
		if(ep->socket && !ep->socket->IsFailed()){
			ep->socket->Send(&pkt);
		}else{
			if(ep->socket){
				LOGD("closing failed TCP socket: %s:%u", ep->address.ToString().c_str(), ep->port);
				ep->socket->Close();
				delete ep->socket;
				ep->socket=NULL;
			}
			LOGI("connecting to tcp: %s:%u", ep->address.ToString().c_str(), ep->port);
			NetworkSocket* s;
			if(proxyProtocol==PROXY_NONE){
				s=NetworkSocket::Create(PROTO_TCP);
			}else if(proxyProtocol==PROXY_SOCKS5){
				NetworkSocket* rawTcp=NetworkSocket::Create(PROTO_TCP);
				openingTcpSocket=rawTcp;
				rawTcp->Connect(resolvedProxyAddress, proxyPort);
				if(rawTcp->IsFailed()){
					openingTcpSocket=NULL;
					rawTcp->Close();
					delete rawTcp;
					LOGW("Error connecting to SOCKS5 proxy");
					return;
				}
				NetworkSocketSOCKS5Proxy* proxy=new NetworkSocketSOCKS5Proxy(rawTcp, NULL, proxyUsername, proxyPassword);
				openingTcpSocket=proxy;
				proxy->InitConnection();
				if(proxy->IsFailed()){
					openingTcpSocket=NULL;
					LOGW("Proxy initialization failed");
					proxy->Close();
					delete proxy;
					return;
				}
				s=proxy;
			}/*else if(proxyProtocol==PROXY_HTTP){
				s=NetworkSocket::Create(PROTO_TCP);
			}*/else{
				LOGE("Unsupported proxy protocol %d", proxyProtocol);
				SetState(STATE_FAILED);
				return;
			}
			s->Connect(&ep->address, ep->port);
			if(s->IsFailed()){
				openingTcpSocket=NULL;
				s->Close();
				delete s;
				LOGW("Error connecting to %s:%u", ep->address.ToString().c_str(), ep->port);
			}else{
				NetworkSocketTCPObfuscated* tcpWrapper=new NetworkSocketTCPObfuscated(s);
				openingTcpSocket=tcpWrapper;
				tcpWrapper->InitConnection();
				openingTcpSocket=NULL;
				if(tcpWrapper->IsFailed()){
					tcpWrapper->Close();
					delete tcpWrapper;
					LOGW("Error initializing connection to %s:%u", ep->address.ToString().c_str(), ep->port);
				}else{
					tcpWrapper->Send(&pkt);
					ep->socket=tcpWrapper;
					selectCanceller->CancelSelect();
				}
			}
		}
	}else{
		udpSocket->Send(&pkt);
	}
}

void VoIPController::SetNetworkType(int type){
	networkType=type;
	UpdateDataSavingState();
	UpdateAudioBitrateLimit();
	myIPv6=IPv6Address();
	string itfName=udpSocket->GetLocalInterfaceInfo(NULL, &myIPv6);
	LOGI("Local IPv6 address: %s", myIPv6.ToString().c_str());
	if(itfName!=activeNetItfName){
		udpSocket->OnActiveInterfaceChanged();
		LOGI("Active network interface changed: %s -> %s", activeNetItfName.c_str(), itfName.c_str());
		bool isFirstChange=activeNetItfName.length()==0 && state!=STATE_ESTABLISHED && state!=STATE_RECONNECTING;
		activeNetItfName=itfName;
		if(isFirstChange)
			return;
		if(currentEndpoint && currentEndpoint->type!=Endpoint::TYPE_UDP_RELAY){
			if(preferredRelay->type==Endpoint::TYPE_UDP_RELAY)
				currentEndpoint=preferredRelay;
			MutexGuard m(endpointsMutex);
			for(vector<shared_ptr<Endpoint>>::iterator itr=endpoints.begin();itr!=endpoints.end();){
				shared_ptr<Endpoint> endpoint=*itr;
				if(endpoint->type==Endpoint::TYPE_UDP_RELAY && useTCP){
					useTCP=false;
					if(preferredRelay->type==Endpoint::TYPE_TCP_RELAY){
						preferredRelay=endpoint;
						currentEndpoint=endpoint;
					}
				}else if(endpoint->type==Endpoint::TYPE_TCP_RELAY && endpoint->socket){
					endpoint->socket->Close();
				}
				//if(endpoint->type==Endpoint::TYPE_UDP_P2P_INET){
					endpoint->averageRTT=0;
				endpoint->rtts.Reset();
				//}
				if(endpoint->type==Endpoint::TYPE_UDP_P2P_LAN){
					itr=endpoints.erase(itr);
				}else{
					++itr;
				}
			}
		}
		lastUdpPingTime=0;
		if(proxyProtocol==PROXY_SOCKS5)
			InitUDPProxy();
		if(allowP2p && currentEndpoint){
			SendPublicEndpointsRequest();
		}
		BufferOutputStream s(4);
		s.WriteInt32(dataSavingMode ? INIT_FLAG_DATA_SAVING_ENABLED : 0);
		if(peerVersion<6){
			SendPacketReliably(PKT_NETWORK_CHANGED, s.GetBuffer(), s.GetLength(), 1, 20);
		}else{
			Buffer buf(move(s));
			SendExtra(buf, EXTRA_TYPE_NETWORK_CHANGED);
		}
		selectCanceller->CancelSelect();
		didSendIPv6Endpoint=false;

		AddIPv6Relays();
		ResetUdpAvailability();
		ResetEndpointPingStats();
	}
	LOGI("set network type: %d, active interface %s", type, activeNetItfName.c_str());
}

void VoIPController::AddIPv6Relays(){
	if(!myIPv6.IsEmpty() && !didAddIPv6Relays){
		unordered_map<string, vector<shared_ptr<Endpoint>>> endpointsByAddress;
		MutexGuard m(endpointsMutex);
		for(shared_ptr<Endpoint>& e:endpoints){
			if((e->type==Endpoint::TYPE_UDP_RELAY || e->type==Endpoint::TYPE_TCP_RELAY) && !e->v6address.IsEmpty() && !e->address.IsEmpty()){
				endpointsByAddress[e->v6address.ToString()].push_back(e);
			}
		}
		//int globalId=callID[15];
		for(unordered_map<string, vector<shared_ptr<Endpoint>>>::iterator addr=endpointsByAddress.begin();addr!=endpointsByAddress.end();++addr){
			shared_ptr<Endpoint> best=NULL;
			//int bestDiff=256;
			for(shared_ptr<Endpoint>& e:addr->second){
				//int epId=(int) (e->id & 0xFF);
				//int diff=abs(globalId-epId);
				//if(diff<bestDiff){
					best=e;
				//	bestDiff=diff;
				//}
				//}
				if(best){
					didAddIPv6Relays=true;
					shared_ptr<Endpoint> v6only=make_shared<Endpoint>(*best);
					v6only->address=IPv4Address(0);
					v6only->id=v6only->id ^ ((int64_t)(FOURCC('I','P','v','6')) << 32);
					endpoints.push_back(v6only);
					LOGD("Adding IPv6-only endpoint [%s]:%u", v6only->v6address.ToString().c_str(), v6only->port);
				}
			}
		}
	}
}

void VoIPController::AddTCPRelays(){
	if(!didAddTcpRelays){
		MutexGuard m(endpointsMutex);
		vector<shared_ptr<Endpoint>> relays;
		for(shared_ptr<Endpoint> &e:endpoints){
			if(e->type!=Endpoint::TYPE_UDP_RELAY)
				continue;
			shared_ptr<Endpoint> tcpRelay=make_shared<Endpoint>(*e);
			tcpRelay->type=Endpoint::TYPE_TCP_RELAY;
			tcpRelay->averageRTT=0;
			tcpRelay->lastPingSeq=0;
			tcpRelay->lastPingTime=0;
			tcpRelay->rtts.Reset();
			tcpRelay->udpPongCount=0;
			tcpRelay->id=tcpRelay->id ^ ((int64_t) (FOURCC('T', 'C', 'P', 0)) << 32);
			if(setCurrentEndpointToTCP && currentEndpoint->type!=Endpoint::TYPE_TCP_RELAY){
				setCurrentEndpointToTCP=false;
				currentEndpoint=tcpRelay;
				preferredRelay=tcpRelay;
			}
			relays.push_back(tcpRelay);
		}
		endpoints.insert(endpoints.end(), relays.begin(), relays.end());
		didAddTcpRelays=true;
	}
}

double VoIPController::GetAverageRTT(){
	if(lastSentSeq>=lastRemoteAckSeq){
		uint32_t diff=lastSentSeq-lastRemoteAckSeq;
		//LOGV("rtt diff=%u", diff);
		if(diff<32){
			double res=0;
			int count=0;
			/*for(i=diff;i<32;i++){
				if(remoteAcks[i-diff]>0){
					res+=(remoteAcks[i-diff]-sentPacketTimes[i]);
					count++;
				}
			}*/
			MutexGuard m(queuedPacketsMutex);
			for(std::vector<RecentOutgoingPacket>::iterator itr=recentOutgoingPackets.begin();itr!=recentOutgoingPackets.end();++itr){
				if(itr->ackTime>0){
					res+=(itr->ackTime-itr->sendTime);
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
	VoIPController::machTimebase = tb.numer;
	VoIPController::machTimebase /= tb.denom;
	VoIPController::machTimestart = mach_absolute_time();
}
#endif

double VoIPController::GetCurrentTime(){
#if defined(__linux__)
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec+(double)ts.tv_nsec/1000000000.0;
#elif defined(__APPLE__)
	static pthread_once_t token = PTHREAD_ONCE_INIT;
	pthread_once(&token, &initMachTimestart);
	return (mach_absolute_time() - machTimestart) * machTimebase / 1000000000.0f;
#elif defined(_WIN32)
	if(!didInitWin32TimeScale){
		LARGE_INTEGER scale;
		QueryPerformanceFrequency(&scale);
		win32TimeScale=scale.QuadPart;
		didInitWin32TimeScale=true;
	}
	LARGE_INTEGER t;
	QueryPerformanceCounter(&t);
	return (double)t.QuadPart/(double)win32TimeScale;
#endif
}

void VoIPController::SetState(int state){
	this->state=state;
	LOGV("Call state changed to %d", state);
	stateChangeTime=GetCurrentTime();
	messageThread.Post([this, state]{
		if(callbacks.connectionStateChanged)
			callbacks.connectionStateChanged(this, state);
	});
	if(state==STATE_ESTABLISHED){
		SetMicMute(micMuted);
		if(!wasEstablished){
			wasEstablished=true;
			messageThread.Post(std::bind(&VoIPController::UpdateRTT, this), 0.1, 0.5);
			messageThread.Post(std::bind(&VoIPController::UpdateAudioBitrate, this), 0.0, 0.3);
			messageThread.Post(std::bind(&VoIPController::UpdateCongestion, this), 0.0, 1.0);
			messageThread.Post(std::bind(&VoIPController::UpdateSignalBars, this), 1.0, 1.0);
			messageThread.Post(std::bind(&VoIPController::TickJitterBufferAngCongestionControl, this), 0.0, 0.1);
		}
	}
}


void VoIPController::SetMicMute(bool mute){
	if(micMuted==mute)
		return;
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
	if(state==STATE_ESTABLISHED){
		for(shared_ptr<Stream>& s:outgoingStreams){
			if(s->type==STREAM_TYPE_AUDIO){
				s->enabled=!mute;
				if(peerVersion<6){
					unsigned char buf[2];
					buf[0]=s->id;
					buf[1]=(char) (mute ? 0 : 1);
					SendPacketReliably(PKT_STREAM_STATE, buf, 2, .5f, 20);
				}else{
					SendStreamFlags(*s);
				}
			}
		}
	}
	if(mute){
		if(noStreamsNopID==MessageThread::INVALID_ID)
			noStreamsNopID=messageThread.Post(std::bind(&VoIPController::SendNopPacket, this), 0.2, 0.2);
	}else{
		if(noStreamsNopID!=MessageThread::INVALID_ID){
			messageThread.Cancel(noStreamsNopID);
			noStreamsNopID=MessageThread::INVALID_ID;
		}
	}
}


void VoIPController::UpdateAudioOutputState(){
	bool areAnyAudioStreamsEnabled=false;
	for(vector<shared_ptr<Stream>>::iterator s=incomingStreams.begin();s!=incomingStreams.end();++s){
		if((*s)->type==STREAM_TYPE_AUDIO && (*s)->enabled)
			areAnyAudioStreamsEnabled=true;
	}
	/*if(jitterBuffer){
		jitterBuffer->Reset();
	}
	if(decoder){
		decoder->ResetQueue();
	}*/
	if(audioOutput){
		if(audioOutput->IsPlaying()!=areAnyAudioStreamsEnabled){
			if(areAnyAudioStreamsEnabled)
				audioOutput->Start();
			else
				audioOutput->Stop();
		}
	}
}

void VoIPController::SendStreamFlags(Stream& stream){
	BufferOutputStream s(5);
	s.WriteByte(stream.id);
	uint32_t flags=0;
	if(stream.enabled)
		flags|=STREAM_FLAG_ENABLED;
	if(stream.extraECEnabled)
		flags|=STREAM_FLAG_EXTRA_EC;
	s.WriteInt32(flags);
	Buffer buf(move(s));
	SendExtra(buf, EXTRA_TYPE_STREAM_FLAGS);
}

void VoIPController::KDF(unsigned char* msgKey, size_t x, unsigned char* aesKey, unsigned char* aesIv){
	uint8_t sA[SHA1_LENGTH], sB[SHA1_LENGTH], sC[SHA1_LENGTH], sD[SHA1_LENGTH];
	BufferOutputStream buf(128);
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

void VoIPController::KDF2(unsigned char* msgKey, size_t x, unsigned char *aesKey, unsigned char *aesIv){
	uint8_t sA[32], sB[32];
	BufferOutputStream buf(128);
	buf.WriteBytes(msgKey, 16);
	buf.WriteBytes(encryptionKey+x, 36);
	crypto.sha256(buf.GetBuffer(), buf.GetLength(), sA);
	buf.Reset();
	buf.WriteBytes(encryptionKey+40+x, 36);
	buf.WriteBytes(msgKey, 16);
	crypto.sha256(buf.GetBuffer(), buf.GetLength(), sB);
	buf.Reset();
	buf.WriteBytes(sA, 8);
	buf.WriteBytes(sB+8, 16);
	buf.WriteBytes(sA+24, 8);
	memcpy(aesKey, buf.GetBuffer(), 32);
	buf.Reset();
	buf.WriteBytes(sB, 8);
	buf.WriteBytes(sA+8, 16);
	buf.WriteBytes(sB+24, 8);
	memcpy(aesIv, buf.GetBuffer(), 32);
}

string VoIPController::GetDebugString(){
	string r="Remote endpoints: \n";
	char buffer[2048];
	MutexGuard m(endpointsMutex);
	for(shared_ptr<Endpoint>& endpoint:endpoints){
		const char* type;
		switch(endpoint->type){
			case Endpoint::TYPE_UDP_P2P_INET:
				type="UDP_P2P_INET";
				break;
			case Endpoint::TYPE_UDP_P2P_LAN:
				type="UDP_P2P_LAN";
				break;
			case Endpoint::TYPE_UDP_RELAY:
				type="UDP_RELAY";
				break;
			case Endpoint::TYPE_TCP_RELAY:
				type="TCP_RELAY";
				break;
			default:
				type="UNKNOWN";
				break;
		}
		snprintf(buffer, sizeof(buffer), "%s:%u %dms %d 0x%" PRIx64 " [%s%s]\n", endpoint->address.IsEmpty() ? ("["+endpoint->v6address.ToString()+"]").c_str() : endpoint->address.ToString().c_str(), endpoint->port, (int)(endpoint->averageRTT*1000), endpoint->udpPongCount, (uint64_t)endpoint->id, type, currentEndpoint==endpoint ? ", IN_USE" : "");
		r+=buffer;
	}
	if(shittyInternetMode){
		r+="ShittyInternetMode enabled\n";
	}
	double avgLate[3];
	shared_ptr<JitterBuffer> jitterBuffer=incomingStreams.size()==1 ? incomingStreams[0]->jitterBuffer : NULL;
	if(jitterBuffer)
		jitterBuffer->GetAverageLateCount(avgLate);
	else
		memset(avgLate, 0, 3*sizeof(double));
	snprintf(buffer, sizeof(buffer),
					 "Jitter buffer: %d/%.2f | %.1f, %.1f, %.1f\n"
					 "RTT avg/min: %d/%d\n"
					 "Congestion window: %d/%d bytes\n"
					 "Key fingerprint: %02hhX%02hhX%02hhX%02hhX%02hhX%02hhX%02hhX%02hhX%s\n"
					 "Last sent/ack'd seq: %u/%u\n"
					 "Last recvd seq: %u\n"
					 "Send/recv losses: %u/%u (%d%%)\n"
					 "Audio bitrate: %d kbit\n"
					 "Outgoing queue: %u\n"
//					 "Packet grouping: %d\n"
					"Frame size out/in: %d/%d\n"
					 "Bytes sent/recvd: %llu/%llu",
			 jitterBuffer ? jitterBuffer->GetMinPacketCount() : 0, jitterBuffer ? jitterBuffer->GetAverageDelay() : 0, avgLate[0], avgLate[1], avgLate[2],
			// (int)(GetAverageRTT()*1000), 0,
			 (int)(conctl->GetAverageRTT()*1000), (int)(conctl->GetMinimumRTT()*1000),
			 int(conctl->GetInflightDataSize()), int(conctl->GetCongestionWindow()),
			 keyFingerprint[0],keyFingerprint[1],keyFingerprint[2],keyFingerprint[3],keyFingerprint[4],keyFingerprint[5],keyFingerprint[6],keyFingerprint[7],
			 useMTProto2 ? " (MTProto2.0)" : "",
			 lastSentSeq, lastRemoteAckSeq, lastRemoteSeq,
			 conctl->GetSendLossCount(), recvLossCount, encoder ? encoder->GetPacketLoss() : 0,
			 encoder ? (encoder->GetBitrate()/1000) : 0,
			 static_cast<unsigned int>(unsentStreamPackets),
//			 audioPacketGrouping,
			 outgoingStreams[0]->frameDuration, incomingStreams.size()>0 ? incomingStreams[0]->frameDuration : 0,
			 (long long unsigned int)(stats.bytesSentMobile+stats.bytesSentWifi),
			 (long long unsigned int)(stats.bytesRecvdMobile+stats.bytesRecvdWifi));
	r+=buffer;
	return r;
}


void VoIPController::SendPublicEndpointsRequest(Endpoint& relay){
	if(!useUDP)
		return;
	LOGD("Sending public endpoints request to %s:%d", relay.address.ToString().c_str(), relay.port);
	publicEndpointsReqTime=GetCurrentTime();
	waitingForRelayPeerInfo=true;
	unsigned char buf[32];
	memcpy(buf, relay.peerTag, 16);
	memset(buf+16, 0xFF, 16);
	NetworkPacket pkt={0};
	pkt.data=buf;
	pkt.length=32;
	pkt.address=(NetworkAddress*)&relay.address;
	pkt.port=relay.port;
	pkt.protocol=PROTO_UDP;
	udpSocket->Send(&pkt);
}

shared_ptr<Endpoint> VoIPController::GetEndpointByType(int type){
	if(type==Endpoint::TYPE_UDP_RELAY && preferredRelay)
		return preferredRelay;
	for(shared_ptr<Endpoint>& e:endpoints){
		if(e->type==type)
			return e;
	}
	return NULL;
}

shared_ptr<Endpoint> VoIPController::GetEndpointByID(int64_t id){
	for(shared_ptr<Endpoint>& e:endpoints){
		if(e->id==id)
			return e;
	}
	return NULL;
}


void VoIPController::SendPacketReliably(unsigned char type, unsigned char *data, size_t len, double retryInterval, double timeout){
	LOGD("Send reliably, type=%u, len=%u, retry=%.3f, timeout=%.3f", type, unsigned(len), retryInterval, timeout);
	QueuedPacket pkt;
	if(data){
		Buffer b(len);
		b.CopyFrom(data, 0, len);
		pkt={move(b)};
	}
	pkt.type=type;
	pkt.retryInterval=retryInterval;
	pkt.timeout=timeout;
	pkt.firstSentTime=0;
	pkt.lastSentTime=0;
	{
		MutexGuard m(queuedPacketsMutex);
		queuedPackets.push_back(move(pkt));
	}
	messageThread.Post(std::bind(&VoIPController::UpdateQueuedPackets, this));
	if(timeout>0.0){
		messageThread.Post(std::bind(&VoIPController::UpdateQueuedPackets, this), timeout);
	}
}

void VoIPController::SendExtra(Buffer &data, unsigned char type){
	MutexGuard m(queuedPacketsMutex);
	LOGV("Sending extra type %u length %lu", type, data.Length());
	for(vector<UnacknowledgedExtraData>::iterator x=currentExtras.begin();x!=currentExtras.end();++x){
		if(x->type==type){
			x->firstContainingSeq=0;
			x->data=move(data);
			return;
		}
	}
	UnacknowledgedExtraData xd={type, move(data), 0};
	currentExtras.push_back(move(xd));
}


void VoIPController::SetConfig(const Config& cfg){
	config=cfg;
	if(tgvoipLogFile){
		fclose(tgvoipLogFile);
		tgvoipLogFile=NULL;
	}
	if(!config.logFilePath.empty()){
		tgvoipLogFile=fopen(config.logFilePath.c_str(), "a");
		tgvoip_log_file_write_header(tgvoipLogFile);
	}else{
		tgvoipLogFile=NULL;
	}
	if(statsDump){
		fclose(statsDump);
		statsDump=NULL;
	}
	if(!config.statsDumpFilePath.empty()){
		statsDump=fopen(config.statsDumpFilePath.c_str(), "w");
		if(statsDump)
			fprintf(statsDump, "Time\tRTT\tLRSeq\tLSSeq\tLASeq\tLostR\tLostS\tCWnd\tBitrate\tLoss%%\tJitter\tJDelay\tAJDelay\n");
		else
			LOGW("Failed to open stats dump file %s for writing", config.statsDumpFilePath.c_str());
	}else{
		statsDump=NULL;
	}
	UpdateDataSavingState();
	UpdateAudioBitrateLimit();
}


void VoIPController::UpdateDataSavingState(){
	if(config.dataSaving==DATA_SAVING_ALWAYS){
		dataSavingMode=true;
	}else if(config.dataSaving==DATA_SAVING_MOBILE){
		dataSavingMode=networkType==NET_TYPE_GPRS || networkType==NET_TYPE_EDGE ||
		   networkType==NET_TYPE_3G || networkType==NET_TYPE_HSPA || networkType==NET_TYPE_LTE || networkType==NET_TYPE_OTHER_MOBILE;
	}else{
		dataSavingMode=false;
	}
	LOGI("update data saving mode, config %d, enabled %d, reqd by peer %d", config.dataSaving, dataSavingMode, dataSavingRequestedByPeer);
}


void VoIPController::DebugCtl(int request, int param){
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
		if(!allowP2p && currentEndpoint && currentEndpoint->type!=Endpoint::TYPE_UDP_RELAY){
			currentEndpoint=preferredRelay;
		}else if(allowP2p){
			SendPublicEndpointsRequest();
		}
		BufferOutputStream s(4);
		s.WriteInt32(dataSavingMode ? INIT_FLAG_DATA_SAVING_ENABLED : 0);
		SendPacketReliably(PKT_NETWORK_CHANGED, s.GetBuffer(), s.GetLength(), 1, 20);
	}else if(request==4){
		if(echoCanceller)
			echoCanceller->Enable(param==1);
	}
}


const char* VoIPController::GetVersion(){
	return LIBTGVOIP_VERSION;
}


int64_t VoIPController::GetPreferredRelayID(){
	if(preferredRelay)
		return preferredRelay->id;
	return 0;
}


int VoIPController::GetLastError(){
	return lastError;
}


void VoIPController::GetStats(TrafficStats *stats){
	memcpy(stats, &this->stats, sizeof(TrafficStats));
}

#ifdef TGVOIP_USE_AUDIO_SESSION
void VoIPController::SetAcquireAudioSession(void (^completion)(void (^)())) {
	this->acquireAudioSession = [completion copy];
}

void VoIPController::ReleaseAudioSession(void (^completion)()) {
	completion();
}
#endif

void VoIPController::LogDebugInfo(){
	string json="{\"endpoints\":[";
	for(vector<shared_ptr<Endpoint>>::iterator itr=endpoints.begin();itr!=endpoints.end();++itr){
		shared_ptr<Endpoint> e=*itr;
		char buffer[1024];
		const char* typeStr="unknown";
		switch(e->type){
			case Endpoint::TYPE_UDP_RELAY:
				typeStr="udp_relay";
				break;
			case Endpoint::TYPE_UDP_P2P_INET:
				typeStr="udp_p2p_inet";
				break;
			case Endpoint::TYPE_UDP_P2P_LAN:
				typeStr="udp_p2p_lan";
				break;
			case Endpoint::TYPE_TCP_RELAY:
				typeStr="tcp_relay";
				break;
		}
		snprintf(buffer, 1024, "{\"address\":\"%s\",\"port\":%u,\"type\":\"%s\",\"rtt\":%u%s%s}", e->address.ToString().c_str(), e->port, typeStr, (unsigned int)round(e->averageRTT*1000), currentEndpoint==e ? ",\"in_use\":true" : "", preferredRelay==e ? ",\"preferred\":true" : "");
		json+=buffer;
		if(itr!=endpoints.end()-1)
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

string VoIPController::GetDebugLog(){
	string log="{\"events\":[";

	for(vector<string>::iterator itr=debugLogs.begin();itr!=debugLogs.end();++itr){
		log+=(*itr);
		if((itr+1)!=debugLogs.end())
			log+=",";
	}
	log+="],\"libtgvoip_version\":\"" LIBTGVOIP_VERSION "\"}";
	return log;
}

void VoIPController::GetDebugLog(char *buffer){
	strcpy(buffer, GetDebugLog().c_str());
}

size_t VoIPController::GetDebugLogLength(){
	size_t len=128;
	for(vector<string>::iterator itr=debugLogs.begin();itr!=debugLogs.end();++itr){
		len+=(*itr).length()+1;
	}
	return len;
}

vector<AudioInputDevice> VoIPController::EnumerateAudioInputs(){
	vector<AudioInputDevice> devs;
	audio::AudioInput::EnumerateDevices(devs);
	return devs;
}

vector<AudioOutputDevice> VoIPController::EnumerateAudioOutputs(){
	vector<AudioOutputDevice> devs;
	audio::AudioOutput::EnumerateDevices(devs);
	return devs;
}

void VoIPController::SetCurrentAudioInput(string id){
	currentAudioInput=id;
	if(audioInput)
		audioInput->SetCurrentDevice(id);
}

void VoIPController::SetCurrentAudioOutput(string id){
	currentAudioOutput=id;
	if(audioOutput)
		audioOutput->SetCurrentDevice(id);
}

string VoIPController::GetCurrentAudioInputID(){
	return currentAudioInput;
}

string VoIPController::GetCurrentAudioOutputID(){
	return currentAudioOutput;
}

void VoIPController::SetProxy(int protocol, string address, uint16_t port, string username, string password){
	proxyProtocol=protocol;
	proxyAddress=address;
	proxyPort=port;
	proxyUsername=username;
	proxyPassword=password;
}

void VoIPController::SendUdpPing(shared_ptr<Endpoint> endpoint){
	if(endpoint->type!=Endpoint::TYPE_UDP_RELAY)
		return;
	LOGV("Sending UDP ping to %s:%d", endpoint->GetAddress().ToString().c_str(), endpoint->port);
	BufferOutputStream p(1024);
	p.WriteBytes(endpoint->peerTag, 16);
	p.WriteInt32(-1);
	p.WriteInt32(-1);
	p.WriteInt32(-1);
	p.WriteInt32(-2);
	p.WriteInt64(12345);
	NetworkPacket pkt={0};
	pkt.address=&endpoint->GetAddress();
	pkt.port=endpoint->port;
	pkt.protocol=PROTO_UDP;
	pkt.data=p.GetBuffer();
	pkt.length=p.GetLength();
	udpSocket->Send(&pkt);
}


void VoIPController::StartAudio(){
	shared_ptr<Stream>& outgoingAudioStream=outgoingStreams[0];
	LOGI("before create audio io");
	audioIO=audio::AudioIO::Create();
	audioInput=audioIO->GetInput();
	audioOutput=audioIO->GetOutput();
	LOGI("AEC: %d NS: %d AGC: %d", config.enableAEC, config.enableNS, config.enableAGC);
	echoCanceller=new EchoCanceller(config.enableAEC, config.enableNS, config.enableAGC);
	encoder=new OpusEncoder(audioInput, peerVersion>=6);
	encoder->SetCallback(AudioInputCallback, this);
	encoder->SetOutputFrameDuration(outgoingAudioStream->frameDuration);
	encoder->SetEchoCanceller(echoCanceller);
	encoder->SetSecondaryEncoderEnabled(false);

	encoder->Start();
	if(!micMuted){
		audioInput->Start();
		if(!audioInput->IsInitialized()){
			LOGE("Erorr initializing audio capture");
			lastError=ERROR_AUDIO_IO;

			SetState(STATE_FAILED);
			return;
		}
	}
	if(!audioOutput->IsInitialized()){
		LOGE("Erorr initializing audio playback");
		lastError=ERROR_AUDIO_IO;

		SetState(STATE_FAILED);
		return;
	}
	UpdateAudioBitrateLimit();

	/*voip_stream_t* incomingAudioStream=incomingStreams[0];
	jitterBuffer=new JitterBuffer(NULL, incomingAudioStream->frameDuration);
	decoder=new OpusDecoder(audioOutput);
	decoder->SetEchoCanceller(echoCanceller);
	decoder->SetJitterBuffer(jitterBuffer);
	decoder->SetFrameDuration(incomingAudioStream->frameDuration);
	decoder->Start();
	if(incomingAudioStream->frameDuration>50)
		jitterBuffer->SetMinPacketCount((uint32_t) ServerConfig::GetSharedInstance()->GetInt("jitter_initial_delay_60", 3));
	else if(incomingAudioStream->frameDuration>30)
		jitterBuffer->SetMinPacketCount((uint32_t) ServerConfig::GetSharedInstance()->GetInt("jitter_initial_delay_40", 4));
	else
		jitterBuffer->SetMinPacketCount((uint32_t) ServerConfig::GetSharedInstance()->GetInt("jitter_initial_delay_20", 6));*/
	//audioOutput->Start();
	OnAudioOutputReady();
}

void VoIPController::OnAudioOutputReady(){
	LOGI("Audio I/O ready");
	shared_ptr<Stream>& stm=incomingStreams[0];
	outputAGC=new AutomaticGainControl();
	outputAGC->SetPassThrough(!outputAGCEnabled);
	stm->decoder=make_shared<OpusDecoder>(audioOutput, true, peerVersion>=6);
	stm->decoder->AddAudioEffect(outputAGC);
	stm->decoder->SetEchoCanceller(echoCanceller);
	stm->decoder->SetJitterBuffer(stm->jitterBuffer);
	stm->decoder->SetFrameDuration(stm->frameDuration);
	stm->decoder->Start();
}

int VoIPController::GetSignalBarsCount(){
	return signalBarsHistory.NonZeroAverage();
}

void VoIPController::SetCallbacks(VoIPController::Callbacks callbacks){
	this->callbacks=callbacks;
	if(callbacks.connectionStateChanged)
		callbacks.connectionStateChanged(this, state);
}

void VoIPController::SetAudioOutputGainControlEnabled(bool enabled){
	LOGD("New output AGC state: %d", enabled);
	outputAGCEnabled=enabled;
	if(outputAGC)
		outputAGC->SetPassThrough(!enabled);
}

uint32_t VoIPController::GetPeerCapabilities(){
	return peerCapabilities;
}

void VoIPController::SendGroupCallKey(unsigned char *key){
	if(!(peerCapabilities & TGVOIP_PEER_CAP_GROUP_CALLS)){
		LOGE("Tried to send group call key but peer isn't capable of them");
		return;
	}
	if(didSendGroupCallKey){
		LOGE("Tried to send a group call key repeatedly");
		return;
	}
	if(!isOutgoing){
		LOGE("You aren't supposed to send group call key in an incoming call, use VoIPController::RequestCallUpgrade() instead");
		return;
	}
	didSendGroupCallKey=true;
	Buffer buf(256);
	buf.CopyFrom(key, 0, 256);
	SendExtra(buf, EXTRA_TYPE_GROUP_CALL_KEY);
}

void VoIPController::RequestCallUpgrade(){
	if(!(peerCapabilities & TGVOIP_PEER_CAP_GROUP_CALLS)){
		LOGE("Tried to send group call key but peer isn't capable of them");
		return;
	}
	if(didSendUpgradeRequest){
		LOGE("Tried to send upgrade request repeatedly");
		return;
	}
	if(isOutgoing){
		LOGE("You aren't supposed to send an upgrade request in an outgoing call, generate an encryption key and use VoIPController::SendGroupCallKey instead");
		return;
	}
	didSendUpgradeRequest=true;
	Buffer empty(0);
	SendExtra(empty, EXTRA_TYPE_REQUEST_GROUP);
}

void VoIPController::SetEchoCancellationStrength(int strength){
	echoCancellationStrength=strength;
	if(echoCanceller)
		echoCanceller->SetAECStrength(strength);
}

void VoIPController::ResetUdpAvailability(){
	LOGI("Resetting UDP availability");
	if(udpPingTimeoutID!=MessageThread::INVALID_ID){
		messageThread.Cancel(udpPingTimeoutID);
	}
	{
		MutexGuard m(endpointsMutex);
		for(shared_ptr<Endpoint>& e:endpoints){
			e->udpPongCount=0;
		}
	}
	udpPingCount=0;
	udpConnectivityState=UDP_PING_PENDING;
	udpPingTimeoutID=messageThread.Post(std::bind(&VoIPController::SendUdpPings, this), 0.0, 0.5);
}

void VoIPController::ResetEndpointPingStats(){
	MutexGuard m(endpointsMutex);
	for(shared_ptr<Endpoint>& e:endpoints){
		e->averageRTT=0.0;
		e->rtts.Reset();
	}
}

#pragma mark - Timer methods

void VoIPController::SendUdpPings(){
	for(shared_ptr<Endpoint>& e:endpoints){
		if(e->type==Endpoint::TYPE_UDP_RELAY){
			SendUdpPing(e);
		}
	}
	if(udpConnectivityState==UDP_UNKNOWN || udpConnectivityState==UDP_PING_PENDING)
		udpConnectivityState=UDP_PING_SENT;
	udpPingCount++;
	if(udpPingCount==4 || udpPingCount==10){
		messageThread.CancelSelf();
		udpPingTimeoutID=messageThread.Post(std::bind(&VoIPController::EvaluateUdpPingResults, this), 1.0);
	}
}

void VoIPController::EvaluateUdpPingResults(){
	double avgPongs=0;
	int count=0;
	for(shared_ptr<Endpoint>& e:endpoints){
		if(e->type==Endpoint::TYPE_UDP_RELAY){
			if(e->udpPongCount>0){
				avgPongs+=(double) e->udpPongCount;
				count++;
			}
		}
	}
	if(count>0)
		avgPongs/=(double)count;
	else
		avgPongs=0.0;
	LOGI("UDP ping reply count: %.2f", avgPongs);
	bool configUseTCP=ServerConfig::GetSharedInstance()->GetBoolean("use_tcp", true);
	if(configUseTCP){
		if(avgPongs==0.0 || (udpConnectivityState==UDP_BAD && avgPongs<7.0)){
			udpConnectivityState=UDP_NOT_AVAILABLE;
			useTCP=true;
			AddTCPRelays();
			useUDP=false;
			waitingForRelayPeerInfo=false;
			if(currentEndpoint->type!=Endpoint::TYPE_TCP_RELAY)
				setCurrentEndpointToTCP=true;
		}else if(avgPongs<3.0){
			udpConnectivityState=UDP_BAD;
			useTCP=true;
			AddTCPRelays();
			setCurrentEndpointToTCP=true;
			udpPingTimeoutID=messageThread.Post(std::bind(&VoIPController::SendUdpPings, this), 0.5, 0.5);
		}else{
			udpPingTimeoutID=MessageThread::INVALID_ID;
			udpConnectivityState=UDP_AVAILABLE;
		}
	}else{
		udpPingTimeoutID=MessageThread::INVALID_ID;
		udpConnectivityState=UDP_NOT_AVAILABLE;
	}
}

void VoIPController::SendRelayPings(){
	MutexGuard m(endpointsMutex);
	if((state==STATE_ESTABLISHED || state==STATE_RECONNECTING) && endpoints.size()>1){
		shared_ptr<Endpoint> minPingRelay=preferredRelay;
		double minPing=preferredRelay->averageRTT*(preferredRelay->type==Endpoint::TYPE_TCP_RELAY ? 2 : 1);
		if(minPing==0.0) // force the switch to an available relay, if any
			minPing=DBL_MAX;
		for(shared_ptr<Endpoint>& endpoint:endpoints){
			if(endpoint->type==Endpoint::TYPE_TCP_RELAY && !useTCP)
				continue;
			if(GetCurrentTime()-endpoint->lastPingTime>=10){
				LOGV("Sending ping to %s", endpoint->GetAddress().ToString().c_str());
				sendQueue->Put(PendingOutgoingPacket{
						/*.seq=*/(endpoint->lastPingSeq=GenerateOutSeq()),
						/*.type=*/PKT_PING,
						/*.len=*/0,
						/*.data=*/Buffer(),
						/*.endpoint=*/endpoint->id
				});
				endpoint->lastPingTime=GetCurrentTime();
			}
			if(endpoint->type==Endpoint::TYPE_UDP_RELAY || (useTCP && endpoint->type==Endpoint::TYPE_TCP_RELAY)){
				double k=endpoint->type==Endpoint::TYPE_UDP_RELAY ? 1 : 2;
				if(endpoint->averageRTT>0 && endpoint->averageRTT*k<minPing*relaySwitchThreshold){
					minPing=endpoint->averageRTT*k;
					minPingRelay=endpoint;
				}
			}
		}
		if(minPingRelay!=preferredRelay){
			preferredRelay=minPingRelay;
			LOGV("set preferred relay to %s", preferredRelay->address.ToString().c_str());
			if(currentEndpoint->type==Endpoint::TYPE_UDP_RELAY || currentEndpoint->type==Endpoint::TYPE_TCP_RELAY)
				currentEndpoint=preferredRelay;
			LogDebugInfo();
		}
		if(currentEndpoint->type==Endpoint::TYPE_UDP_RELAY){
			shared_ptr<Endpoint> p2p=GetEndpointByType(Endpoint::TYPE_UDP_P2P_INET);
			if(p2p){
				shared_ptr<Endpoint> lan=GetEndpointByType(Endpoint::TYPE_UDP_P2P_LAN);
				if(lan && lan->averageRTT>0 && lan->averageRTT<minPing*relayToP2pSwitchThreshold){
					currentEndpoint=lan;
					LOGI("Switching to p2p (LAN)");
					LogDebugInfo();
				}else{
					if(p2p->averageRTT>0 && p2p->averageRTT<minPing*relayToP2pSwitchThreshold){
						currentEndpoint=p2p;
						LOGI("Switching to p2p (Inet)");
						LogDebugInfo();
					}
				}
			}
		}else{
			if(minPing>0 && minPing<currentEndpoint->averageRTT*p2pToRelaySwitchThreshold){
				LOGI("Switching to relay");
				currentEndpoint=preferredRelay;
				LogDebugInfo();
			}
		}
	}
}

void VoIPController::UpdateRTT(){
	rttHistory.Add(GetAverageRTT());
	//double v=rttHistory.Average();
	if(rttHistory[0]>10.0 && rttHistory[8]>10.0 && (networkType==NET_TYPE_EDGE || networkType==NET_TYPE_GPRS)){
		waitingForAcks=true;
	}else{
		waitingForAcks=false;
	}
	//LOGI("%.3lf/%.3lf, rtt diff %.3lf, waiting=%d, queue=%d", rttHistory[0], rttHistory[8], v, waitingForAcks, sendQueue->Size());
	for(vector<shared_ptr<Stream>>::iterator stm=incomingStreams.begin();stm!=incomingStreams.end();++stm){
		if((*stm)->jitterBuffer){
			int lostCount=(*stm)->jitterBuffer->GetAndResetLostPacketCount();
			if(lostCount>0 || (lostCount<0 && recvLossCount>((uint32_t) -lostCount)))
				recvLossCount+=lostCount;
		}
	}
}

void VoIPController::UpdateCongestion(){
	if(conctl && encoder){
		uint32_t sendLossCount=conctl->GetSendLossCount();
		sendLossCountHistory.Add(sendLossCount-prevSendLossCount);
		prevSendLossCount=sendLossCount;
		double packetsPerSec=1000/(double) outgoingStreams[0]->frameDuration;
		double avgSendLossCount=sendLossCountHistory.Average()/packetsPerSec;
		//LOGV("avg send loss: %.1f%%", avgSendLossCount*100);

		if(avgSendLossCount>0.125 && networkType!=NET_TYPE_GPRS && networkType!=NET_TYPE_EDGE){
			encoder->SetPacketLoss(40);
			if(!shittyInternetMode){
				// Shitty Internet Mode™. Redundant redundancy you can trust.
				shittyInternetMode=true;
				for(shared_ptr<Stream> &s:outgoingStreams){
					if(s->type==STREAM_TYPE_AUDIO){
						s->extraECEnabled=true;
						SendStreamFlags(*s);
						break;
					}
				}
				if(encoder)
					encoder->SetSecondaryEncoderEnabled(true);
				LOGW("Enabling extra EC");
			}
		}else if(avgSendLossCount>0.1){
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

		if((avgSendLossCount<0.15 || networkType==NET_TYPE_EDGE || networkType==NET_TYPE_GPRS) && shittyInternetMode){
			shittyInternetMode=false;
			for(shared_ptr<Stream> &s:outgoingStreams){
				if(s->type==STREAM_TYPE_AUDIO){
					s->extraECEnabled=false;
					SendStreamFlags(*s);
					break;
				}
			}
			if(encoder)
				encoder->SetSecondaryEncoderEnabled(false);
			LOGW("Disabling extra EC");
		}
	}
}

void VoIPController::UpdateAudioBitrate(){
	if(encoder && conctl){
		double time=GetCurrentTime();
		if((audioInput && !audioInput->IsInitialized()) || (audioOutput && !audioOutput->IsInitialized())){
			LOGE("Audio I/O failed");
			lastError=ERROR_AUDIO_IO;
			SetState(STATE_FAILED);
		}

		int act=conctl->GetBandwidthControlAction();
		if(shittyInternetMode){
			encoder->SetBitrate(8000);
		}else if(act==TGVOIP_CONCTL_ACT_DECREASE){
			uint32_t bitrate=encoder->GetBitrate();
			if(bitrate>8000)
				encoder->SetBitrate(bitrate<(minAudioBitrate+audioBitrateStepDecr) ? minAudioBitrate : (bitrate-audioBitrateStepDecr));
		}else if(act==TGVOIP_CONCTL_ACT_INCREASE){
			uint32_t bitrate=encoder->GetBitrate();
			if(bitrate<maxBitrate)
				encoder->SetBitrate(bitrate+audioBitrateStepIncr);
		}

		if(state==STATE_ESTABLISHED && time-lastRecvPacketTime>=reconnectingTimeout){
			SetState(STATE_RECONNECTING);
			ResetUdpAvailability();
		}

		if(state==STATE_ESTABLISHED || state==STATE_RECONNECTING){
			if(time-lastRecvPacketTime>=config.recvTimeout){
				if(currentEndpoint && currentEndpoint->type!=Endpoint::TYPE_UDP_RELAY && currentEndpoint->type!=Endpoint::TYPE_TCP_RELAY){
					LOGW("Packet receive timeout, switching to relay");
					currentEndpoint=preferredRelay;
					for(shared_ptr<Endpoint>& e:endpoints){
						if(e->type==Endpoint::TYPE_UDP_P2P_INET || e->type==Endpoint::TYPE_UDP_P2P_LAN){
							e->averageRTT=0;
							e->rtts.Reset();
						}
					}
					if(allowP2p){
						SendPublicEndpointsRequest();
					}
					UpdateDataSavingState();
					UpdateAudioBitrateLimit();
					BufferOutputStream s(4);
					s.WriteInt32(dataSavingMode ? INIT_FLAG_DATA_SAVING_ENABLED : 0);
					if(peerVersion<6){
						SendPacketReliably(PKT_NETWORK_CHANGED, s.GetBuffer(), s.GetLength(), 1, 20);
					}else{
						Buffer buf(move(s));
						SendExtra(buf, EXTRA_TYPE_NETWORK_CHANGED);
					}
					lastRecvPacketTime=time;
				}else{
					LOGW("Packet receive timeout, disconnecting");
					lastError=ERROR_TIMEOUT;
					SetState(STATE_FAILED);
				}
			}
		}
	}
}

void VoIPController::UpdateSignalBars(){
	int prevSignalBarCount=GetSignalBarsCount();
	double packetsPerSec=1000/(double) outgoingStreams[0]->frameDuration;
	double avgSendLossCount=sendLossCountHistory.Average()/packetsPerSec;

	int signalBarCount=4;
	if(state==STATE_RECONNECTING || waitingForAcks)
		signalBarCount=1;
	if(currentEndpoint->type==Endpoint::TYPE_TCP_RELAY){
		signalBarCount=MIN(signalBarCount, 3);
	}
	if(avgSendLossCount>0.1){
		signalBarCount=1;
	}else if(avgSendLossCount>0.0625){
		signalBarCount=MIN(signalBarCount, 2);
	}else if(avgSendLossCount>0.025){
		signalBarCount=MIN(signalBarCount, 3);
	}

	for(shared_ptr<Stream>& stm:incomingStreams){
		if(stm->jitterBuffer){
			double avgLateCount[3];
			stm->jitterBuffer->GetAverageLateCount(avgLateCount);
			if(avgLateCount[2]>=0.2)
				signalBarCount=1;
			else if(avgLateCount[2]>=0.1)
				signalBarCount=MIN(signalBarCount, 2);
		}
	}

	signalBarsHistory.Add(static_cast<unsigned char>(signalBarCount));
	//LOGV("Signal bar count history %08X", *reinterpret_cast<uint32_t *>(&signalBarsHistory));
	int _signalBarCount=GetSignalBarsCount();
	if(_signalBarCount!=prevSignalBarCount){
		LOGD("SIGNAL BAR COUNT CHANGED: %d", _signalBarCount);
		if(callbacks.signalBarCountChanged)
			callbacks.signalBarCountChanged(this, _signalBarCount);
	}
}

void VoIPController::UpdateQueuedPackets(){
	MutexGuard m(queuedPacketsMutex);
	for(std::vector<QueuedPacket>::iterator qp=queuedPackets.begin();qp!=queuedPackets.end();){
		if(qp->timeout>0 && qp->firstSentTime>0 && GetCurrentTime()-qp->firstSentTime>=qp->timeout){
			LOGD("Removing queued packet because of timeout");
			qp=queuedPackets.erase(qp);
			continue;
		}
		if(GetCurrentTime()-qp->lastSentTime>=qp->retryInterval){
			messageThread.Post(std::bind(&VoIPController::UpdateQueuedPackets, this), qp->retryInterval);
			uint32_t seq=GenerateOutSeq();
			qp->seqs.Add(seq);
			qp->lastSentTime=GetCurrentTime();
			//LOGD("Sending queued packet, seq=%u, type=%u, len=%u", seq, qp.type, qp.data.Length());
			Buffer buf(qp->data.Length());
			if(qp->firstSentTime==0)
				qp->firstSentTime=qp->lastSentTime;
			if(qp->data.Length())
				buf.CopyFrom(qp->data, qp->data.Length());
			sendQueue->Put(PendingOutgoingPacket{
					/*.seq=*/seq,
					/*.type=*/qp->type,
					/*.len=*/qp->data.Length(),
					/*.data=*/move(buf),
					/*.endpoint=*/0
			});
		}
		++qp;
	}
}

void VoIPController::SendNopPacket(){
	sendQueue->Put(PendingOutgoingPacket{
			/*.seq=*/(firstSentPing=GenerateOutSeq()),
			/*.type=*/PKT_NOP,
			/*.len=*/0,
			/*.data=*/Buffer(),
			/*.endpoint=*/0
	});
}

void VoIPController::SendPublicEndpointsRequest(){
	if(!allowP2p)
		return;
	LOGI("Sending public endpoints request");
	MutexGuard m(endpointsMutex);
	for(shared_ptr<Endpoint>& e:endpoints){
		if(e->type==Endpoint::TYPE_UDP_RELAY && !e->IsIPv6Only()){
			SendPublicEndpointsRequest(*e);
		}
	}
	publicEndpointsReqCount++;
	if(publicEndpointsReqCount<10){
		messageThread.Post([this]{
			if(waitingForRelayPeerInfo){
				LOGW("Resending peer relay info request");
				SendPublicEndpointsRequest();
			}
		}, 5.0);
	}else{
		publicEndpointsReqCount=0;
	}
}

void VoIPController::TickJitterBufferAngCongestionControl(){
	// TODO get rid of this and update states of these things internally and retroactively
	for(shared_ptr<Stream>& stm:incomingStreams){
		if(stm->jitterBuffer){
			stm->jitterBuffer->Tick();
		}
	}
	if(conctl){
		conctl->Tick();
	}
}

#pragma mark - Endpoint

Endpoint::Endpoint(int64_t id, uint16_t port, IPv4Address& _address, IPv6Address& _v6address, char type, unsigned char peerTag[16]) : address(_address), v6address(_v6address){
	this->id=id;
	this->port=port;
	this->type=type;
	memcpy(this->peerTag, peerTag, 16);
	if(type==TYPE_UDP_RELAY && ServerConfig::GetSharedInstance()->GetBoolean("force_tcp", false))
		this->type=TYPE_TCP_RELAY;

	lastPingSeq=0;
	lastPingTime=0;
	averageRTT=0;
	socket=NULL;
	udpPongCount=0;
}

Endpoint::Endpoint() : address(0), v6address(string("::0")) {
	lastPingSeq=0;
	lastPingTime=0;
	averageRTT=0;
	socket=NULL;
	udpPongCount=0;
}

NetworkAddress &Endpoint::GetAddress(){
	return IsIPv6Only() ? (NetworkAddress&)v6address : (NetworkAddress&)address;
}

bool Endpoint::IsIPv6Only(){
	return address.IsEmpty() && !v6address.IsEmpty();
}

Endpoint::~Endpoint(){
	if(socket){
		socket->Close();
		delete socket;
	}
}
