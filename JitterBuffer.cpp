//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "VoIPController.h"
#include "JitterBuffer.h"
#include "logging.h"
#include "VoIPServerConfig.h"
#include <math.h>

CJitterBuffer::CJitterBuffer(CMediaStreamItf *out, uint32_t step):bufferPool(JITTER_SLOT_SIZE, JITTER_SLOT_COUNT){
	if(out)
		out->SetCallback(CJitterBuffer::CallbackOut, this);
	this->step=step;
	memset(slots, 0, sizeof(jitter_packet_t)*JITTER_SLOT_COUNT);
	minDelay=6;
	lostCount=0;
	needBuffering=true;
	tickCount=0;
	dontIncMinDelay=0;
	dontDecMinDelay=0;
	lostPackets=0;
	if(step<30){
		minMinDelay=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_min_delay_20", 6);
		maxMinDelay=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_max_delay_20", 25);
		maxUsedSlots=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_max_slots_20", 50);
	}else if(step<50){
		minMinDelay=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_min_delay_40", 4);
		maxMinDelay=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_max_delay_40", 15);
		maxUsedSlots=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_max_slots_40", 30);
	}else{
		minMinDelay=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_min_delay_60", 1);
		maxMinDelay=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_max_delay_60", 10);
		maxUsedSlots=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_max_slots_60", 20);
	}
	lossesToReset=(uint32_t) CVoIPServerConfig::GetSharedInstance()->GetInt("jitter_losses_to_reset", 20);
	resyncThreshold=CVoIPServerConfig::GetSharedInstance()->GetDouble("jitter_resync_threshold", 1.0);
	Reset();
	init_mutex(mutex);
}

CJitterBuffer::~CJitterBuffer(){
	Reset();
	free_mutex(mutex);
}

void CJitterBuffer::SetMinPacketCount(uint32_t count){
	if(minDelay==count)
		return;
	minDelay=count;
	Reset();
}

int CJitterBuffer::GetMinPacketCount(){
	return minDelay;
}

size_t CJitterBuffer::CallbackIn(unsigned char *data, size_t len, void *param){
	//((CJitterBuffer*)param)->HandleInput(data, len);
	return 0;
}

size_t CJitterBuffer::CallbackOut(unsigned char *data, size_t len, void *param){
	return ((CJitterBuffer*)param)->HandleOutput(data, len, 0);
}

void CJitterBuffer::HandleInput(unsigned char *data, size_t len, uint32_t timestamp){
	jitter_packet_t pkt;
	pkt.size=len;
	pkt.buffer=data;
	pkt.timestamp=timestamp;
	lock_mutex(mutex);
	PutInternal(&pkt);
	unlock_mutex(mutex);
	//LOGV("in, ts=%d", timestamp);
}

void CJitterBuffer::Reset(){
	wasReset=true;
	needBuffering=true;
	lastPutTimestamp=0;
	int i;
	for(i=0;i<JITTER_SLOT_COUNT;i++){
		if(slots[i].buffer){
			bufferPool.Reuse(slots[i].buffer);
			slots[i].buffer=NULL;
		}
	}
	memset(delayHistory, 0, sizeof(delayHistory));
	memset(lateHistory, 0, sizeof(lateHistory));
	adjustingDelay=false;
	lostSinceReset=0;
	gotSinceReset=0;
	expectNextAtTime=0;
	memset(deviationHistory, 0, sizeof(deviationHistory));
	deviationPtr=0;
}


size_t CJitterBuffer::HandleOutput(unsigned char *buffer, size_t len, int offsetInSteps){
	jitter_packet_t pkt;
	pkt.buffer=buffer;
	pkt.size=len;
	lock_mutex(mutex);
	int result=GetInternal(&pkt, offsetInSteps);
	unlock_mutex(mutex);
	if(result==JR_OK){
		return pkt.size;
	}else{
		return 0;
	}
}


int CJitterBuffer::GetInternal(jitter_packet_t* pkt, int offset){
	/*if(needBuffering && lastPutTimestamp<nextTimestamp){
		LOGV("jitter: don't have timestamp %lld, buffering", nextTimestamp);
		Advance();
		return JR_BUFFERING;
	}*/

	//needBuffering=false;

	int64_t timestampToGet=nextTimestamp+offset*(int32_t)step;

	int i;
	for(i=0;i<JITTER_SLOT_COUNT;i++){
		if(slots[i].buffer!=NULL && slots[i].timestamp==timestampToGet){
			break;
		}
	}

	if(i<JITTER_SLOT_COUNT){
		if(pkt && pkt->size<slots[i].size){
			LOGE("jitter: packet won't fit into provided buffer of %d (need %d)", slots[i].size, pkt->size);
		}else{
			if(pkt) {
				pkt->size = slots[i].size;
				pkt->timestamp = slots[i].timestamp;
				memcpy(pkt->buffer, slots[i].buffer, slots[i].size);
			}
		}
		bufferPool.Reuse(slots[i].buffer);
		slots[i].buffer=NULL;
		if(offset==0)
			Advance();
		lostCount=0;
		needBuffering=false;
		return JR_OK;
	}

	LOGW("jitter: found no packet for timestamp %lld (last put = %d, lost = %d)", timestampToGet, lastPutTimestamp, lostCount);

	if(offset==0)
		Advance();

	if(!needBuffering){
		lostCount++;
		if(offset==0){
			lostPackets++;
			lostSinceReset++;
		}
		if(lostCount>=lossesToReset || (gotSinceReset>minDelay*25 && lostSinceReset>gotSinceReset/2)){
			LOGW("jitter: lost %d packets in a row, resetting", lostCount);
			//minDelay++;
			dontIncMinDelay=16;
			dontDecMinDelay+=128;
			if(GetCurrentDelay()<minDelay)
				nextTimestamp-=(minDelay-GetCurrentDelay());
			lostCount=0;
			Reset();
		}

		return JR_MISSING;
	}
	return JR_BUFFERING;
}

void CJitterBuffer::PutInternal(jitter_packet_t* pkt){
	if(pkt->size>JITTER_SLOT_SIZE){
		LOGE("The packet is too big to fit into the jitter buffer");
		return;
	}
	gotSinceReset++;
	int i;
	if(wasReset){
		wasReset=false;
		nextTimestamp=((int64_t)pkt->timestamp)-step*minDelay;
		LOGI("jitter: resyncing, next timestamp = %lld (step=%d, minDelay=%d)", nextTimestamp, step, minDelay);
	}
	
	for(i=0;i<JITTER_SLOT_COUNT;i++){
		if(slots[i].buffer!=NULL){
			if(slots[i].timestamp<nextTimestamp-1){
				bufferPool.Reuse(slots[i].buffer);
				slots[i].buffer=NULL;
			}
		}
	}

	/*double prevTime=0;
	uint32_t closestTime=0;
	for(i=0;i<JITTER_SLOT_COUNT;i++){
		if(slots[i].buffer!=NULL && pkt->timestamp-slots[i].timestamp<pkt->timestamp-closestTime){
			closestTime=slots[i].timestamp;
			prevTime=slots[i].recvTime;
		}
	}*/
	double time=CVoIPController::GetCurrentTime();
	if(expectNextAtTime!=0){
		double dev=expectNextAtTime-time;
		//LOGV("packet dev %f", dev);
		deviationHistory[deviationPtr]=dev;
		deviationPtr=(deviationPtr+1)%64;
		expectNextAtTime+=step/1000.0;
	}else{
		expectNextAtTime=time+step/1000.0;
	}

	if(pkt->timestamp<nextTimestamp){
		LOGW("jitter: would drop packet with timestamp %d because it is late but not hopelessly", pkt->timestamp);
		latePacketCount++;
		lostPackets--;
	}else if(pkt->timestamp<nextTimestamp-1){
		LOGW("jitter: dropping packet with timestamp %d because it is too late", pkt->timestamp);
		latePacketCount++;
		return;
	}

	if(pkt->timestamp>lastPutTimestamp)
		lastPutTimestamp=pkt->timestamp;

	for(i=0;i<JITTER_SLOT_COUNT;i++){
		if(slots[i].buffer==NULL)
			break;
	}
	if(i==JITTER_SLOT_COUNT || GetCurrentDelay()>=maxUsedSlots){
		int toRemove=JITTER_SLOT_COUNT;
		uint32_t bestTimestamp=0xFFFFFFFF;
		for(i=0;i<JITTER_SLOT_COUNT;i++){
			if(slots[i].buffer!=NULL && slots[i].timestamp<bestTimestamp){
				toRemove=i;
				bestTimestamp=slots[i].timestamp;
			}
		}
		Advance();
		bufferPool.Reuse(slots[toRemove].buffer);
		slots[toRemove].buffer=NULL;
		i=toRemove;
	}
	slots[i].timestamp=pkt->timestamp;
	slots[i].size=pkt->size;
	slots[i].buffer=bufferPool.Get();
	slots[i].recvTimeDiff=time-prevRecvTime;
	if(slots[i].buffer)
		memcpy(slots[i].buffer, pkt->buffer, pkt->size);
	else
		LOGE("WTF!!");
	prevRecvTime=time;
}


void CJitterBuffer::Advance(){
	nextTimestamp+=step;
}


int CJitterBuffer::GetCurrentDelay(){
	int delay=0;
	int i;
	for(i=0;i<JITTER_SLOT_COUNT;i++){
		if(slots[i].buffer!=NULL)
			delay++;
	}
	return delay;
}

void CJitterBuffer::Tick(){
	lock_mutex(mutex);
	int i;

	int count=0;

	memmove(&lateHistory[1], lateHistory, 63*sizeof(int));
	lateHistory[0]=latePacketCount;
	latePacketCount=0;
	bool absolutelyNoLatePackets=true;

	double avgLate64=0, avgLate32=0, avgLate16=0;
	for(i=0;i<64;i++){
		avgLate64+=lateHistory[i];
		if(i<32)
			avgLate32+=lateHistory[i];
		if(i<16){
			avgLate16+=lateHistory[i];
		}
		if(lateHistory[i]>0)
			absolutelyNoLatePackets=false;
	}
	avgLate64/=64;
	avgLate32/=32;
	avgLate16/=16;
	//LOGV("jitter: avg late=%.1f, %.1f, %.1f", avgLate16, avgLate32, avgLate64);
	if(avgLate16>=resyncThreshold){
		wasReset=true;
	}
	/*if(avgLate16>=0.3){
		if(dontIncMinDelay==0 && minDelay<15){
			minDelay++;
			if(GetCurrentDelay()<minDelay)
				nextTimestamp-=(minDelay-GetCurrentDelay());
			dontIncMinDelay=16;
			dontDecMinDelay+=128;
		}
	}else if(absolutelyNoLatePackets){
		if(dontDecMinDelay>0)
			dontDecMinDelay--;
		if(dontDecMinDelay==0 && minDelay>minMinDelay){
			minDelay--;
			dontDecMinDelay=64;
			dontIncMinDelay+=16;
		}
	}

	if(dontIncMinDelay>0)
		dontIncMinDelay--;*/

	if(absolutelyNoLatePackets){
		if(dontDecMinDelay>0)
			dontDecMinDelay--;
	}

	memmove(&delayHistory[1], delayHistory, 63*sizeof(int));
	delayHistory[0]=GetCurrentDelay();

	int avgDelay=0;
	int min=100;
	for(i=0;i<32;i++){
		avgDelay+=delayHistory[i];
		if(delayHistory[i]<min)
			min=delayHistory[i];
	}
	avgDelay/=32;

	double stddev=0;
	double avgdev=0;
	for(i=0;i<64;i++){
		avgdev+=deviationHistory[i];
	}
	avgdev/=64;
	for(i=0;i<64;i++){
		double d=(deviationHistory[i]-avgdev);
		stddev+=(d*d);
	}
	stddev=sqrt(stddev/64);
	uint32_t stddevDelay=(uint32_t)ceil(stddev*2*1000/step);
	if(stddevDelay<minMinDelay)
		stddevDelay=minMinDelay;
	if(stddevDelay>maxMinDelay)
		stddevDelay=maxMinDelay;
	if(stddevDelay!=minDelay){
		int32_t diff=stddevDelay-minDelay;
		if(diff>0){
			dontDecMinDelay=100;
		}
		if(diff<-1)
			diff=-1;
		if(diff>1)
			diff=1;
		if((diff>0 && dontIncMinDelay==0) || (diff<0 && dontDecMinDelay==0)){
			nextTimestamp+=diff*(int32_t)step;
			minDelay+=diff;
			LOGD("new delay from stddev %d", minDelay);
			if(diff<0){
				dontDecMinDelay+=25;
			}
			if(diff>0){
				dontIncMinDelay=25;
			}
		}
	}
	//LOGV("stddev=%.3f, avg=%.3f, ndelay=%d, dontDec=%u", stddev, avgdev, stddevDelay, dontDecMinDelay);

	//LOGV("jitter: avg delay=%d, delay=%d, late16=%.1f, dontDecMinDelay=%d", avgDelay, delayHistory[0], avgLate16, dontDecMinDelay);
	if(!adjustingDelay) {
		if (((minDelay==1 ? (avgDelay>=3) : (avgDelay>=minDelay/2)) && delayHistory[0]>minDelay && avgLate16<=0.1 && absolutelyNoLatePackets && dontDecMinDelay<32 && min>minDelay) /*|| (avgRecvTimeDiff>0 && delayHistory[0]>minDelay/2 && avgRecvTimeDiff*1000<step/2)*/) {
			LOGI("jitter: need adjust");
			adjustingDelay=true;
		}
	}else{
		if(!absolutelyNoLatePackets){
			LOGI("jitter: done adjusting because we're losing packets");
			adjustingDelay=false;
		}else if(tickCount%5==0){
			LOGD("jitter: removing a packet to reduce delay");
			GetInternal(NULL, 0);
			expectNextAtTime=0;
			if(GetCurrentDelay()<=minDelay || min<=minDelay){
				adjustingDelay = false;
				LOGI("jitter: done adjusting");
			}
		}
	}

	tickCount++;

	unlock_mutex(mutex);
}


void CJitterBuffer::GetAverageLateCount(double *out){
	double avgLate64=0, avgLate32=0, avgLate16=0;
	int i;
	for(i=0;i<64;i++){
		avgLate64+=lateHistory[i];
		if(i<32)
			avgLate32+=lateHistory[i];
		if(i<16)
			avgLate16+=lateHistory[i];
	}
	avgLate64/=64;
	avgLate32/=32;
	avgLate16/=16;
	out[0]=avgLate16;
	out[1]=avgLate32;
	out[2]=avgLate64;
}


int CJitterBuffer::GetAndResetLostPacketCount(){
	lock_mutex(mutex);
	int r=lostPackets;
	lostPackets=0;
	unlock_mutex(mutex);
	return r;
}
