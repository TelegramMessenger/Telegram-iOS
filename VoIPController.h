#ifndef __VOIPCONTROLLER_H
#define __VOIPCONTROLLER_H

#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdint.h>
#include <vector>
#include <string>
#include <map>
#include "audio/AudioInput.h"
#include "BlockingQueue.h"
#include "BufferOutputStream.h"
#include "audio/AudioOutput.h"
#include "JitterBuffer.h"
#include "OpusDecoder.h"
#include "OpusEncoder.h"
#include "EchoCanceller.h"
#include "CongestionControl.h"

#ifdef __APPLE__
#import <Foundation/Foundation.h>
#endif

#define LIBTGVOIP_VERSION "0.3.1"

#define PKT_INIT 1
#define PKT_INIT_ACK 2
#define PKT_STREAM_STATE 3
#define PKT_STREAM_DATA 4
#define PKT_UPDATE_STREAMS 5
#define PKT_PING 6
#define PKT_PONG 7
#define PKT_STREAM_DATA_X2 8
#define PKT_STREAM_DATA_X3 9
#define PKT_LAN_ENDPOINT 10
#define PKT_NETWORK_CHANGED 11
#define PKT_SWITCH_PREF_RELAY 12
#define PKT_SWITCH_TO_P2P 13
#define PKT_NOP 14

#define STATE_WAIT_INIT 1
#define STATE_WAIT_INIT_ACK 2
#define STATE_ESTABLISHED 3
#define STATE_FAILED 4

#define ERROR_UNKNOWN 0
#define ERROR_INCOMPATIBLE 1
#define ERROR_TIMEOUT 2
#define ERROR_AUDIO_IO 3

#define NET_TYPE_UNKNOWN 0
#define NET_TYPE_GPRS 1
#define NET_TYPE_EDGE 2
#define NET_TYPE_3G 3
#define NET_TYPE_HSPA 4
#define NET_TYPE_LTE 5
#define NET_TYPE_WIFI 6
#define NET_TYPE_ETHERNET 7
#define NET_TYPE_OTHER_HIGH_SPEED 8
#define NET_TYPE_OTHER_LOW_SPEED 9
#define NET_TYPE_DIALUP 10
#define NET_TYPE_OTHER_MOBILE 11

#define IS_MOBILE_NETWORK(x) (x==NET_TYPE_GPRS || x==NET_TYPE_EDGE || x==NET_TYPE_3G || x==NET_TYPE_HSPA || x==NET_TYPE_LTE || x==NET_TYPE_OTHER_MOBILE)

#define PROTOCOL_NAME 0x50567247 // "GrVP" in little endian (reversed here)
#define PROTOCOL_VERSION 3
#define MIN_PROTOCOL_VERSION 3
#define MIN_UDP_PORT 16384
#define MAX_UDP_PORT 32768

#define STREAM_DATA_FLAG_LEN16 0x40
#define STREAM_DATA_FLAG_HAS_MORE_FLAGS 0x80

#define STREAM_TYPE_AUDIO 1
#define STREAM_TYPE_VIDEO 2

#define CODEC_OPUS 1

#define EP_TYPE_UDP_P2P_INET 1
#define EP_TYPE_UDP_P2P_LAN 2
#define EP_TYPE_UDP_RELAY 3
#define EP_TYPE_TCP_RELAY 4

/*flags:# voice_call_id:flags.2?int128 in_seq_no:flags.4?int out_seq_no:flags.4?int
	 * recent_received_mask:flags.5?int proto:flags.3?int extra:flags.1?string raw_data:flags.0?string*/
#define PFLAG_HAS_DATA 1
#define PFLAG_HAS_EXTRA 2
#define PFLAG_HAS_CALL_ID 4
#define PFLAG_HAS_PROTO 8
#define PFLAG_HAS_SEQ 16
#define PFLAG_HAS_RECENT_RECV 32

#define INIT_FLAG_DATA_SAVING_ENABLED 1

#define DATA_SAVING_NEVER 0
#define DATA_SAVING_MOBILE 1
#define DATA_SAVING_ALWAYS 2

#define TLID_DECRYPTED_AUDIO_BLOCK 0xDBF948C1
#define TLID_SIMPLE_AUDIO_BLOCK 0xCC0D0E76
#define TLID_UDP_REFLECTOR_PEER_INFO 0x27D9371C
#define PAD4(x) (4-(x+(x<=253 ? 1 : 0))%4)

inline int pad4(int x){
	int r=PAD4(x);
	if(r==4)
		return 0;
	return r;
}

struct voip_endpoint_t{ // make this a class maybe?
	int64_t id;
	uint32_t port;
	in_addr address;
	in6_addr address6;
	char type;
	unsigned char peerTag[16];

	double _lastPingTime;
	uint32_t _lastPingSeq;
	double _rtts[6];
	double _averageRtt;
};
typedef struct voip_endpoint_t voip_endpoint_t;

struct voip_stream_t{
	int32_t userID;
	unsigned char id;
	unsigned char type;
	unsigned char codec;
	bool enabled;
	uint16_t frameDuration;
};
typedef struct voip_stream_t voip_stream_t;

struct voip_queued_packet_t{
	unsigned char type;
	unsigned char* data;
	size_t length;
	uint32_t seqs[16];
	double firstSentTime;
	double lastSentTime;
	double retryInterval;
	double timeout;
};
typedef struct voip_queued_packet_t voip_queued_packet_t;

struct voip_config_t{
	double init_timeout;
	double recv_timeout;
	int data_saving;
	char logFilePath[256];

	bool enableAEC;
	bool enableNS;
	bool enableAGC;
};
typedef struct voip_config_t voip_config_t;

struct voip_stats_t{
	uint64_t bytesSentWifi;
	uint64_t bytesRecvdWifi;
	uint64_t bytesSentMobile;
	uint64_t bytesRecvdMobile;
};
typedef struct voip_stats_t voip_stats_t;

struct voip_crypto_functions_t{
	void (*rand_bytes)(uint8_t* buffer, size_t length);
	void (*sha1)(uint8_t* msg, size_t length, uint8_t* output);
	void (*sha256)(uint8_t* msg, size_t length, uint8_t* output);
	void (*aes_ige_encrypt)(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv);
	void (*aes_ige_decrypt)(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv);
};
typedef struct voip_crypto_functions_t voip_crypto_functions_t;

#define SEQ_MAX 0xFFFFFFFF

inline bool seqgt(uint32_t s1, uint32_t s2){
	return ((s1>s2) && (s1-s2<=SEQ_MAX/2)) || ((s1<s2) && (s2-s1>SEQ_MAX/2));
}

class CVoIPController
{
public:
	CVoIPController();
	~CVoIPController();

	void SetRemoteEndpoints(voip_endpoint_t* endpoints, size_t count, bool allowP2p);
	void Start();
	void Connect();
	voip_endpoint_t* GetRemoteEndpoint();
	void GetDebugString(char* buffer, size_t len);
	void SetNetworkType(int type);
	double GetAverageRTT();
	void SetStateCallback(void (*f)(CVoIPController*, int));
	static double GetCurrentTime();
	void* implData;
	void SetMicMute(bool mute);
	void SetEncryptionKey(char* key, bool isOutgoing);
	void SetConfig(voip_config_t* cfg);
    float GetOutputLevel();
	void DebugCtl(int request, int param);
	void GetStats(voip_stats_t* stats);
	int64_t GetPreferredRelayID();
	int GetLastError();
	static voip_crypto_functions_t crypto;
	static const char* GetVersion();
#ifdef TGVOIP_USE_AUDIO_SESSION
    void SetAcquireAudioSession(void (^)(void (^)()));
    void ReleaseAudioSession(void (^completion)());
#endif
	std::string GetDebugLog();
	void GetDebugLog(char* buffer);
	size_t GetDebugLogLength();

private:
	static void* StartRecvThread(void* arg);
	static void* StartSendThread(void* arg);
	static void* StartTickThread(void* arg);
	void RunRecvThread();
	void RunSendThread();
	void RunTickThread();
	void SendPacket(unsigned char* data, size_t len, voip_endpoint_t* ep);
	void HandleAudioInput(unsigned char* data, size_t len);
	void UpdateAudioBitrate();
	void SetState(int state);
	void UpdateAudioOutputState();
	void SendInit();
	void SendInitAck();
	void UpdateDataSavingState();
	void SendP2pPing(int endpointType);
	void KDF(unsigned char* msgKey, size_t x, unsigned char* aesKey, unsigned char* aesIv);
	void GetLocalNetworkItfInfo(in_addr *addr, char *outName);
	uint16_t GenerateLocalUDPPort();
	CBufferOutputStream* GetOutgoingPacketBuffer();
	uint32_t WritePacketHeader(CBufferOutputStream* s, unsigned char type, uint32_t length);
	static size_t AudioInputCallback(unsigned char* data, size_t length, void* param);
	void SendPublicEndpointsRequest();
	voip_endpoint_t* GetEndpointByType(int type);
	void SendPacketReliably(unsigned char type, unsigned char* data, size_t len, double retryInterval, double timeout);
	void LogDebugInfo();
	sockaddr_in6 MakeInetAddress(in_addr addr, uint16_t port);
	int state;
	int udpSocket;
	std::vector<voip_endpoint_t*> endpoints;
	voip_endpoint_t* currentEndpoint;
	voip_endpoint_t* preferredRelay;
	bool runReceiver;
	uint32_t seq;
	uint32_t lastRemoteSeq;
	uint32_t lastRemoteAckSeq;
	uint32_t lastSentSeq;
	double remoteAcks[32];
	double sentPacketTimes[32];
	double recvPacketTimes[32];
	uint32_t sendLossCountHistory[32];
	uint32_t audioTimestampIn;
	uint32_t audioTimestampOut;
	CAudioInput* audioInput;
	CAudioOutput* audioOutput;
	CJitterBuffer* jitterBuffer;
	COpusDecoder* decoder;
	COpusEncoder* encoder;
	CBlockingQueue* sendQueue;
	CEchoCanceller* echoCanceller;
	std::vector<CBufferOutputStream*> emptySendBuffers;
    tgvoip_mutex_t sendBufferMutex;
	bool stopping;
	bool audioOutStarted;
	tgvoip_thread_t recvThread;
	tgvoip_thread_t sendThread;
	tgvoip_thread_t tickThread;
	uint32_t packetsRecieved;
	uint32_t recvLossCount;
	uint32_t prevSendLossCount;
	uint32_t firstSentPing;
	double rttHistory[32];
	bool waitingForAcks;
	int networkType;
	int audioPacketGrouping;
	int audioPacketsWritten;
	int dontSendPackets;
	int lastError;
	bool micMuted;
	uint32_t maxBitrate;
	CBufferOutputStream* currentAudioPacket;
	void (*stateCallback)(CVoIPController*, int);
	std::vector<voip_stream_t*> outgoingStreams;
	std::vector<voip_stream_t*> incomingStreams;
	unsigned char encryptionKey[256];
	unsigned char keyFingerprint[8];
	unsigned char callID[16];
	double stateChangeTime;
	bool needSendP2pPing;
	bool waitingForRelayPeerInfo;
	double relayPeerInfoReqTime;
	double lastP2pPingTime;
	int p2pPingCount;
	uint16_t localUdpPort;
	bool allowP2p;
	bool dataSavingMode;
	bool dataSavingRequestedByPeer;
	char activeNetItfName[32];
	double publicEndpointsReqTime;
	std::vector<voip_queued_packet_t*> queuedPackets;
	tgvoip_mutex_t queuedPacketsMutex;
	double connectionInitTime;
	double lastRecvPacketTime;
	voip_config_t config;
	int32_t peerVersion;
	CCongestionControl* conctl;
	voip_stats_t stats;
	bool receivedInit;
	bool receivedInitAck;
	std::vector<std::string> debugLogs;
	bool isOutgoing;
	
	unsigned char nat64Prefix[12];
	bool needUpdateNat64Prefix;
	bool nat64Present;

	/*** server config values ***/
	uint32_t maxAudioBitrate;
	uint32_t maxAudioBitrateEDGE;
	uint32_t maxAudioBitrateGPRS;
	uint32_t maxAudioBitrateSaving;
	uint32_t initAudioBitrate;
	uint32_t initAudioBitrateEDGE;
	uint32_t initAudioBitrateGPRS;
	uint32_t initAudioBitrateSaving;
	uint32_t minAudioBitrate;
	uint32_t audioBitrateStepIncr;
	uint32_t audioBitrateStepDecr;
	double relaySwitchThreshold;
	double p2pToRelaySwitchThreshold;
	double relayToP2pSwitchThreshold;

#ifdef TGVOIP_USE_AUDIO_SESSION
    void (^acquireAudioSession)(void (^)());
	bool needNotifyAcquiredAudioSession;
#endif

#ifdef __APPLE__
public:
	static double machTimebase;
	static uint64_t machTimestart;
#endif
};

#endif
