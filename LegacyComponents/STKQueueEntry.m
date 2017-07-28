//
//  STKQueueEntry.m
//  StreamingKit
//
//  Created by Thong Nguyen on 30/01/2014.
//  Copyright (c) 2014 Thong Nguyen. All rights reserved.
//

#import "STKQueueEntry.h"
#import "STKDataSource.h"

#define STK_BIT_RATE_ESTIMATION_MIN_PACKETS_MIN (2)
#define STK_BIT_RATE_ESTIMATION_MIN_PACKETS_PREFERRED (64)

@implementation STKQueueEntry

-(id) initWithDataSource:(STKDataSource*)dataSourceIn andQueueItemId:(NSObject*)queueItemIdIn
{
    if (self = [super init])
    {
        self->spinLock = OS_SPINLOCK_INIT;
        
        self.dataSource = dataSourceIn;
        self.queueItemId = queueItemIdIn;
        self->lastFrameQueued = -1;
    }
    
    return self;
}

-(void) reset
{
    OSSpinLockLock(&self->spinLock);
    self->framesQueued = 0;
    self->framesPlayed = 0;
    self->lastFrameQueued = -1;
    OSSpinLockUnlock(&self->spinLock);
}

-(double) calculatedBitRate
{
    double retval;
    
    if (packetDuration > 0)
	{
		if (processedPacketsCount > STK_BIT_RATE_ESTIMATION_MIN_PACKETS_PREFERRED || (audioStreamBasicDescription.mBytesPerFrame == 0 && processedPacketsCount > STK_BIT_RATE_ESTIMATION_MIN_PACKETS_MIN))
		{
			double averagePacketByteSize = processedPacketsSizeTotal / processedPacketsCount;
			
			retval = averagePacketByteSize / packetDuration * 8;
			
			return retval;
		}
	}
	
    retval = (audioStreamBasicDescription.mBytesPerFrame * audioStreamBasicDescription.mSampleRate) * 8;
    
    return retval;
}

-(double) duration
{
    if (self->sampleRate <= 0)
    {
        return 0;
    }
    
    UInt64 audioDataLengthInBytes = [self audioDataLengthInBytes];
    
    double calculatedBitRate = [self calculatedBitRate];
    
    if (calculatedBitRate < 1.0 || self.dataSource.length == 0)
    {
        return 0;
    }
    
    return audioDataLengthInBytes / (calculatedBitRate / 8);
}

-(UInt64) audioDataLengthInBytes
{
    if (audioDataByteCount)
    {
        return audioDataByteCount;
    }
    else
    {
        if (!self.dataSource.length)
        {
            return 0;
        }
        
        return self.dataSource.length - audioDataOffset;
    }
}

-(BOOL) isDefinitelyCompatible:(AudioStreamBasicDescription*)basicDescription
{
    if (self->audioStreamBasicDescription.mSampleRate == 0)
    {
        return NO;
    }
    
    return (memcmp(&(self->audioStreamBasicDescription), basicDescription, sizeof(*basicDescription)) == 0);
}

-(Float64) progressInFrames
{
    OSSpinLockLock(&self->spinLock);
    Float64 retval = self->seekTime + self->framesPlayed;
    OSSpinLockUnlock(&self->spinLock);
    
    return retval;
}

-(NSString*) description
{
    return [[self queueItemId] description];
}

@end