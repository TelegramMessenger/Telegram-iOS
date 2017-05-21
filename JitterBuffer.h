//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_JITTERBUFFER_H
#define LIBTGVOIP_JITTERBUFFER_H

#include <stdlib.h>
#include <vector>
#include <stdio.h>
#include "MediaStreamItf.h"
#include "BlockingQueue.h"
#include "BufferPool.h"
#include "threading.h"

#define JITTER_SLOT_COUNT 64
#define JITTER_SLOT_SIZE 1024
#define JR_OK 1
#define JR_MISSING 2
#define JR_BUFFERING 3

struct jitter_packet_t{
	unsigned char* buffer;
	size_t size;
	uint32_t timestamp;
	double recvTimeDiff;
};
typedef struct jitter_packet_t jitter_packet_t;

namespace tgvoip{
class JitterBuffer{
public:
	JitterBuffer(MediaStreamItf* out, uint32_t step);
	~JitterBuffer();
	void SetMinPacketCount(uint32_t count);
	int GetMinPacketCount();
	int GetCurrentDelay();
	double GetAverageDelay();
	void Reset();
	void HandleInput(unsigned char* data, size_t len, uint32_t timestamp);
	size_t HandleOutput(unsigned char* buffer, size_t len, int offsetInSteps, int* playbackScaledDuration);
	void Tick();
	void GetAverageLateCount(double* out);
	int GetAndResetLostPacketCount();
	double GetLastMeasuredJitter();
	double GetLastMeasuredDelay();

private:
	static size_t CallbackIn(unsigned char* data, size_t len, void* param);
	static size_t CallbackOut(unsigned char* data, size_t len, void* param);
	void PutInternal(jitter_packet_t* pkt);
	int GetInternal(jitter_packet_t* pkt, int offset);
	void Advance();

	BufferPool bufferPool;
	tgvoip_mutex_t mutex;
	jitter_packet_t slots[JITTER_SLOT_COUNT];
	int64_t nextTimestamp;
	uint32_t step;
	uint32_t minDelay;
	uint32_t minMinDelay;
	uint32_t maxMinDelay;
	uint32_t maxUsedSlots;
	uint32_t lastPutTimestamp;
	uint32_t lossesToReset;
	double resyncThreshold;
	int lostCount;
	int lostSinceReset;
	int gotSinceReset;
	bool wasReset;
	bool needBuffering;
	int delayHistory[64];
	int lateHistory[64];
	bool adjustingDelay;
	unsigned int tickCount;
	unsigned int latePacketCount;
	unsigned int dontIncMinDelay;
	unsigned int dontDecMinDelay;
	int lostPackets;
	double prevRecvTime;
	double expectNextAtTime;
	double deviationHistory[64];
	int deviationPtr;
	double lastMeasuredJitter;
	double lastMeasuredDelay;
	int outstandingDelayChange;
	unsigned int dontChangeDelay;
	double avgDelay;
	//FILE* dump;
};
}

#endif //LIBTGVOIP_JITTERBUFFER_H
