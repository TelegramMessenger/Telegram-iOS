#ifndef __OPUSENC_H
#define __OPUSENC_H

#import <Foundation/Foundation.h>

@class TGDataItem;

@interface TGOggOpusWriter : NSObject

- (bool)beginWithDataItem:(TGDataItem *)dataItem;
- (bool)writeFrame:(uint8_t *)framePcmBytes frameByteCount:(NSUInteger)frameByteCount;
- (NSUInteger)encodedBytes;
- (NSTimeInterval)encodedDuration;

@end

#endif /* __OPUSENC_H */
