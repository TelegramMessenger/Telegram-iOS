//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_CONGESTIONCONTROL_H
#define LIBTGVOIP_CONGESTIONCONTROL_H

#include <stdlib.h>
#include <stdint.h>
#include "threading.h"

#define TGVOIP_CONCTL_STARTUP 0
#define TGVOIP_CONCTL_DRAIN 1
#define TGVOIP_CONCTL_PROBE_BW 2
#define TGVOIP_CONCTL_PROBE_RTT 3

#define TGVOIP_CONCTL_ACT_INCREASE 1
#define TGVOIP_CONCTL_ACT_DECREASE 2
#define TGVOIP_CONCTL_ACT_NONE 0

namespace tgvoip{

struct tgvoip_congestionctl_packet_t{
	uint32_t seq;
	double sendTime;
	size_t size;
};
typedef struct tgvoip_congestionctl_packet_t tgvoip_congestionctl_packet_t;

class CongestionControl{
public:
	CongestionControl();
	~CongestionControl();

	void PacketSent(uint32_t seq, size_t size);
	void PacketAcknowledged(uint32_t seq);

	double GetAverageRTT();
	double GetMinimumRTT();
	size_t GetInflightDataSize();
	size_t GetCongestionWindow();
	size_t GetAcknowledgedDataSize();
	void Tick();
	int GetBandwidthControlAction();
	uint32_t GetSendLossCount();

private:
	double rttHistory[100];
	tgvoip_congestionctl_packet_t inflightPackets[100];
	size_t inflightHistory[30];
	int state;
	uint32_t lossCount;
	double tmpRtt;
	double lastActionTime;
	double lastActionRtt;
	double stateTransitionTime;
	int tmpRttCount;
	char rttHistorySize;
	unsigned int rttHistoryTop;
	unsigned int inflightHistoryTop;
	uint32_t lastSentSeq;
	uint32_t tickCount;
	size_t inflightDataSize;
	size_t cwnd;
	tgvoip_mutex_t mutex;
};
}

#endif //LIBTGVOIP_CONGESTIONCONTROL_H
