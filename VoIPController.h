//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef __VOIPCONTROLLER_H
#define __VOIPCONTROLLER_H

#ifndef _WIN32
#include <arpa/inet.h>
#include <netinet/in.h>
#endif
#ifdef __APPLE__
#include <TargetConditionals.h>
#endif
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
#include "NetworkSocket.h"

#define LIBTGVOIP_VERSION "1.0"

#define STATE_WAIT_INIT 1
#define STATE_WAIT_INIT_ACK 2
#define STATE_ESTABLISHED 3
#define STATE_FAILED 4
#define STATE_RECONNECTING 5

#define TGVOIP_ERROR_UNKNOWN 0
#define TGVOIP_ERROR_INCOMPATIBLE 1
#define TGVOIP_ERROR_TIMEOUT 2
#define TGVOIP_ERROR_AUDIO_IO 3

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

#define EP_TYPE_UDP_P2P_INET 1
#define EP_TYPE_UDP_P2P_LAN 2
#define EP_TYPE_UDP_RELAY 3
#define EP_TYPE_TCP_RELAY 4

#define DATA_SAVING_NEVER 0
#define DATA_SAVING_MOBILE 1
#define DATA_SAVING_ALWAYS 2

#ifdef _WIN32
#undef GetCurrentTime
#endif

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
	char statsDumpFilePath[256];

	bool enableAEC;
	bool enableNS;
	bool enableAGC;
};
typedef struct voip_config_t voip_config_t;

#if defined(__APPLE__) && TARGET_OS_IPHONE
// temporary fix for nasty linking errors
struct voip_legacy_endpoint_t{
	const char* address;
	const char* address6;
	uint16_t port;
	int64_t id;
	unsigned char peerTag[16];
};
typedef struct voip_legacy_endpoint_t voip_legacy_endpoint_t;
#endif

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
	void (*aes_ctr_encrypt)(uint8_t* inout, size_t length, uint8_t* key, uint8_t* iv, uint8_t* ecount, uint32_t* num);
};
typedef struct voip_crypto_functions_t voip_crypto_functions_t;

#define SEQ_MAX 0xFFFFFFFF

inline bool seqgt(uint32_t s1, uint32_t s2){
	return ((s1>s2) && (s1-s2<=SEQ_MAX/2)) || ((s1<s2) && (s2-s1>SEQ_MAX/2));
}

namespace tgvoip{

	enum{
		PROXY_NONE=0,
		PROXY_SOCKS5,
		//PROXY_HTTP
	};

class Endpoint{
	friend class VoIPController;
public:
	Endpoint(int64_t id, uint16_t port, IPv4Address& address, IPv6Address& v6address, char type, unsigned char* peerTag);
	Endpoint();
	int64_t id;
	uint16_t port;
	IPv4Address address;
	IPv6Address v6address;
	char type;
	unsigned char peerTag[16];

private:
	double lastPingTime;
	uint32_t lastPingSeq;
	double rtts[6];
	double averageRTT;
	NetworkSocket* socket;
};

class AudioDevice{
public:
	std::string id;
	std::string displayName;
};

class AudioOutputDevice : public AudioDevice{

};

class AudioInputDevice : public AudioDevice{

};

class VoIPController
{
public:
	VoIPController();
	~VoIPController();

	/**
	 * Set the initial endpoints (relays)
	 * @param endpoints Endpoints converted from phone.PhoneConnection TL objects
	 * @param allowP2p Whether p2p connectivity is allowed
	 */
	void SetRemoteEndpoints(std::vector<Endpoint> endpoints, bool allowP2p);
	/**
	 * Initialize and start all the internal threads
	 */
	void Start();
	/**
	 * Initiate connection
	 */
	void Connect();
	Endpoint& GetRemoteEndpoint();
	/**
	 * Get the debug info string to be displayed in client UI
	 * @param buffer The buffer to put the string into
	 * @param len The length of the buffer
	 */
	void GetDebugString(char* buffer, size_t len);
	/**
	 * Notify the library of network type change
	 * @param type The new network type
	 */
	void SetNetworkType(int type);
	/**
	 * Get the average round-trip time for network packets
	 * @return
	 */
	double GetAverageRTT();
	/**
	 * Set the function to be called whenever the connection state changes
	 * @param f
	 */
	void SetStateCallback(void (*f)(VoIPController*, int));
	static double GetCurrentTime();
	/**
	 * Use this field to store any of your context data associated with this call
	 */
	void* implData;
	/**
	 *
	 * @param mute
	 */
	void SetMicMute(bool mute);
	/**
	 *
	 * @param key
	 * @param isOutgoing
	 */
	void SetEncryptionKey(char* key, bool isOutgoing);
	/**
	 *
	 * @param cfg
	 */
	void SetConfig(voip_config_t* cfg);
    float GetOutputLevel();
	void DebugCtl(int request, int param);
	/**
	 *
	 * @param stats
	 */
	void GetStats(voip_stats_t* stats);
	/**
	 *
	 * @return
	 */
	int64_t GetPreferredRelayID();
	/**
	 *
	 * @return
	 */
	int GetLastError();
	/**
	 *
	 */
	static voip_crypto_functions_t crypto;
	/**
	 *
	 * @return
	 */
	static const char* GetVersion();
#ifdef TGVOIP_USE_AUDIO_SESSION
    void SetAcquireAudioSession(void (^)(void (^)()));
    void ReleaseAudioSession(void (^completion)());
#endif
		/**
		 *
		 * @return
		 */
	std::string GetDebugLog();
		/**
		 *
		 * @param buffer
		 */
	void GetDebugLog(char* buffer);
	size_t GetDebugLogLength();
		/**
		 *
		 * @return
		 */
	static std::vector<AudioInputDevice> EnumerateAudioInputs();
		/**
		 *
		 * @return
		 */
	static std::vector<AudioOutputDevice> EnumerateAudioOutputs();
		/**
		 *
		 * @param id
		 */
	void SetCurrentAudioInput(std::string id);
		/**
		 *
		 * @param id
		 */
	void SetCurrentAudioOutput(std::string id);
		/**
		 *
		 * @return
		 */
	std::string GetCurrentAudioInputID();
		/**
		 *
		 * @return
		 */
	std::string GetCurrentAudioOutputID();
	/**
	 * Set the proxy server to route the data through. Call this before connecting.
	 * @param protocol PROXY_NONE, PROXY_SOCKS4, or PROXY_SOCKS5
	 * @param address IP address or domain name of the server
	 * @param port Port of the server
	 * @param username Username; empty string for anonymous
	 * @param password Password; empty string if none
	 */
	void SetProxy(int protocol, std::string address, uint16_t port, std::string username, std::string password);

private:
	struct PendingOutgoingPacket{
		uint32_t seq;
		unsigned char type;
		size_t len;
		unsigned char* data;
		Endpoint* endpoint;
	};
	enum{
		UDP_UNKNOWN=0,
		UDP_PING_SENT,
		UDP_AVAILABIE,
		UDP_NOT_AVAILABLE
	};

	static void* StartRecvThread(void* arg);
	static void* StartSendThread(void* arg);
	static void* StartTickThread(void* arg);
	void RunRecvThread();
	void RunSendThread();
	void RunTickThread();
	void SendPacket(unsigned char* data, size_t len, Endpoint* ep);
	void HandleAudioInput(unsigned char* data, size_t len);
	void UpdateAudioBitrate();
	void SetState(int state);
	void UpdateAudioOutputState();
	void SendInit();
	void InitUDPProxy();
	void UpdateDataSavingState();
	void KDF(unsigned char* msgKey, size_t x, unsigned char* aesKey, unsigned char* aesIv);
	void WritePacketHeader(uint32_t seq, BufferOutputStream* s, unsigned char type, uint32_t length);
	static size_t AudioInputCallback(unsigned char* data, size_t length, void* param);
	void SendPublicEndpointsRequest();
	void SendPublicEndpointsRequest(Endpoint& relay);
	Endpoint* GetEndpointByType(int type);
	void SendPacketReliably(unsigned char type, unsigned char* data, size_t len, double retryInterval, double timeout);
	uint32_t GenerateOutSeq();
	void LogDebugInfo();
	void SendUdpPing(Endpoint* endpoint);
	int state;
	std::vector<Endpoint*> endpoints;
	Endpoint* currentEndpoint;
	Endpoint* preferredRelay;
	Endpoint* peerPreferredRelay;
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
	tgvoip::audio::AudioInput* audioInput;
	tgvoip::audio::AudioOutput* audioOutput;
	JitterBuffer* jitterBuffer;
	OpusDecoder* decoder;
	OpusEncoder* encoder;
	BlockingQueue<PendingOutgoingPacket>* sendQueue;
	EchoCanceller* echoCanceller;
    tgvoip_mutex_t sendBufferMutex;
	tgvoip_mutex_t endpointsMutex;
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
	int dontSendPackets;
	int lastError;
	bool micMuted;
	uint32_t maxBitrate;
	void (*stateCallback)(VoIPController*, int);
	std::vector<voip_stream_t*> outgoingStreams;
	std::vector<voip_stream_t*> incomingStreams;
	unsigned char encryptionKey[256];
	unsigned char keyFingerprint[8];
	unsigned char callID[16];
	double stateChangeTime;
	bool waitingForRelayPeerInfo;
	bool allowP2p;
	bool dataSavingMode;
	bool dataSavingRequestedByPeer;
	std::string activeNetItfName;
	double publicEndpointsReqTime;
	std::vector<voip_queued_packet_t*> queuedPackets;
	tgvoip_mutex_t queuedPacketsMutex;
	double connectionInitTime;
	double lastRecvPacketTime;
	voip_config_t config;
	int32_t peerVersion;
	CongestionControl* conctl;
	voip_stats_t stats;
	bool receivedInit;
	bool receivedInitAck;
	std::vector<std::string> debugLogs;
	bool isOutgoing;
	NetworkSocket* udpSocket;
	NetworkSocket* realUdpSocket;
	FILE* statsDump;
	std::string currentAudioInput;
	std::string currentAudioOutput;
	bool useTCP;
	bool useUDP;
	bool didAddTcpRelays;
	double setEstablishedAt;
	SocketSelectCanceller* selectCanceller;
	NetworkSocket* openingTcpSocket;

	BufferPool outgoingPacketsBufferPool;
	int udpConnectivityState;
	double lastUdpPingTime;
	int udpPingCount;

	int proxyProtocol;
	std::string proxyAddress;
	uint16_t proxyPort;
	std::string proxyUsername;
	std::string proxyPassword;
	IPv4Address* resolvedProxyAddress;
	
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
	double reconnectingTimeout;

#ifdef TGVOIP_USE_AUDIO_SESSION
void (^acquireAudioSession)(void (^)());
bool needNotifyAcquiredAudioSession;
#endif

public:
#ifdef __APPLE__
static double machTimebase;
static uint64_t machTimestart;
#if TARGET_OS_IPHONE
// temporary fix for nasty linking errors
void SetRemoteEndpoints(voip_legacy_endpoint_t* buffer, size_t count, bool allowP2P);
#endif
#endif
#ifdef _WIN32
static int64_t win32TimeScale;
static bool didInitWin32TimeScale;
#endif
};

}

#endif
