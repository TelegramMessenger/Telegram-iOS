//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "CongestionControl.h"
#include "VoIPController.h"
#include "logging.h"
#include "VoIPServerConfig.h"
#include <math.h>
#include <assert.h>

using namespace tgvoip;

CongestionControl::CongestionControl(){
	memset(rttHistory, 0, sizeof(rttHistory));
	memset(inflightPackets, 0, sizeof(inflightPackets));
	memset(inflightHistory, 0, sizeof(inflightHistory));
	tmpRtt=0;
	tmpRttCount=0;
	rttHistorySize=0;
	rttHistoryTop=0;
	lastSentSeq=0;
	inflightHistoryTop=0;
	state=TGVOIP_CONCTL_STARTUP;
	lastActionTime=0;
	lastActionRtt=0;
	stateTransitionTime=0;
	inflightDataSize=0;
	lossCount=0;
	cwnd=(size_t) ServerConfig::GetSharedInstance()->GetInt("audio_congestion_window", 1024);
	init_mutex(mutex);
}

CongestionControl::~CongestionControl(){
	free_mutex(mutex);
}

size_t CongestionControl::GetAcknowledgedDataSize(){
	return 0;
}

double CongestionControl::GetAverageRTT(){
	if(rttHistorySize==0)
		return 0;
	double avg=0;
	int i;
	for(i=0;i<30 && i<rttHistorySize;i++){
		int x=(rttHistoryTop-i-1)%100;
		avg+=rttHistory[x>=0 ? x : (100+x)];
		//LOGV("adding [%d] %f", x>=0 ? x : (100+x), rttHistory[x>=0 ? x : (100+x)]);
	}
	return avg/i;
}

size_t CongestionControl::GetInflightDataSize(){
	size_t avg=0;
	int i;
	for(i=0;i<30;i++){
		avg+=inflightHistory[i];
	}
	return avg/30;
}


size_t CongestionControl::GetCongestionWindow(){
	return cwnd;
}

double CongestionControl::GetMinimumRTT(){
	int i;
	double min=INFINITY;
	for(i=0;i<100;i++){
		if(rttHistory[i]>0 && rttHistory[i]<min)
			min=rttHistory[i];
	}
	return min;
}

void CongestionControl::PacketAcknowledged(uint32_t seq){
	MutexGuard sync(mutex);
	int i;
	for(i=0;i<100;i++){
		if(inflightPackets[i].seq==seq && inflightPackets[i].sendTime>0){
			tmpRtt+=(VoIPController::GetCurrentTime()-inflightPackets[i].sendTime);
			tmpRttCount++;
			inflightPackets[i].sendTime=0;
			inflightDataSize-=inflightPackets[i].size;
			break;
		}
	}
}

void CongestionControl::PacketSent(uint32_t seq, size_t size){
	if(!seqgt(seq, lastSentSeq) || seq==lastSentSeq){
		LOGW("Duplicate outgoing seq %u", seq);
		return;
	}
	lastSentSeq=seq;
	MutexGuard sync(mutex);
	double smallestSendTime=INFINITY;
	tgvoip_congestionctl_packet_t* slot=NULL;
	int i;
	for(i=0;i<100;i++){
		if(inflightPackets[i].sendTime==0){
			slot=&inflightPackets[i];
			break;
		}
		if(smallestSendTime>inflightPackets[i].sendTime){
			slot=&inflightPackets[i];
			smallestSendTime=slot->sendTime;
		}
	}
	assert(slot!=NULL);
	if(slot->sendTime>0){
		inflightDataSize-=slot->size;
		lossCount++;
		LOGD("Packet with seq %u was not acknowledged", slot->seq);
	}
	slot->seq=seq;
	slot->size=size;
	slot->sendTime=VoIPController::GetCurrentTime();
	inflightDataSize+=size;
}


void CongestionControl::Tick(){
	tickCount++;
	MutexGuard sync(mutex);
	if(tmpRttCount>0){
		rttHistory[rttHistoryTop]=tmpRtt/tmpRttCount;
		rttHistoryTop=(rttHistoryTop+1)%100;
		if(rttHistorySize<100)
			rttHistorySize++;
		tmpRtt=0;
		tmpRttCount=0;
	}
	int i;
	for(i=0;i<100;i++){
		if(inflightPackets[i].sendTime!=0 && VoIPController::GetCurrentTime()-inflightPackets[i].sendTime>2){
			inflightPackets[i].sendTime=0;
			inflightDataSize-=inflightPackets[i].size;
			lossCount++;
			LOGD("Packet with seq %u was not acknowledged", inflightPackets[i].seq);
		}
	}
	inflightHistory[inflightHistoryTop]=inflightDataSize;
	inflightHistoryTop=(inflightHistoryTop+1)%30;
}


int CongestionControl::GetBandwidthControlAction(){
	if(VoIPController::GetCurrentTime()-lastActionTime<1)
		return TGVOIP_CONCTL_ACT_NONE;
	size_t inflightAvg=GetInflightDataSize();
	size_t max=cwnd+cwnd/10;
	size_t min=cwnd-cwnd/10;
	if(inflightAvg<min){
		lastActionTime=VoIPController::GetCurrentTime();
		return TGVOIP_CONCTL_ACT_INCREASE;
	}
	if(inflightAvg>max){
		lastActionTime=VoIPController::GetCurrentTime();
		return TGVOIP_CONCTL_ACT_DECREASE;
	}
	return TGVOIP_CONCTL_ACT_NONE;
}


uint32_t CongestionControl::GetSendLossCount(){
	return lossCount;
}
