// Sources/SubcodecObjC/include/SCMuxSurface.h
#import <Foundation/Foundation.h>
#import "SCSpriteRegion.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCCompactionInfo : NSObject
@property (nonatomic, readonly) int activeSprites;
@property (nonatomic, readonly) int maxSlots;
@property (nonatomic, readonly) int currentGridMbs;
@property (nonatomic, readonly) int minGridMbs;
- (instancetype)initWithActiveSprites:(int)active
                             maxSlots:(int)max
                       currentGridMbs:(int)current
                          minGridMbs:(int)min;
@end

@interface SCResizeResult : NSObject
@property (nonatomic, readonly) NSArray<SCSpriteRegion *> *regions;
- (instancetype)initWithRegions:(NSArray<SCSpriteRegion *> *)regions;
@end

@interface SCMuxSurface : NSObject

@property (nonatomic, readonly) int widthMbs;
@property (nonatomic, readonly) int heightMbs;

+ (nullable SCMuxSurface *)createWithSpriteWidth:(int)width
                                    spriteHeight:(int)height
                                        maxSlots:(int)slots
                                              qp:(int)qp
                                            sink:(void (^)(NSData *))sink
                                           error:(NSError **)error;

- (nullable SCSpriteRegion *)addSpriteAtPath:(NSString *)path
                                       error:(NSError **)error;

- (void)removeSpriteAtSlot:(int)slot;

- (void)advanceSpriteAtSlot:(int)slot;
- (BOOL)emitFrameIfNeededWithSink:(void (^)(NSData *))sink
                            error:(NSError **)error;

- (BOOL)advanceFrameWithSink:(void (^)(NSData *))sink
                       error:(NSError **)error;

- (nullable SCResizeResult *)resizeToMaxSlots:(int)newMaxSlots
                                       yPlane:(NSData *)yPlane
                                      cbPlane:(NSData *)cbPlane
                                      crPlane:(NSData *)crPlane
                                 decodedWidth:(int)decodedWidth
                                decodedHeight:(int)decodedHeight
                                      strideY:(int)strideY
                                     strideCb:(int)strideCb
                                     strideCr:(int)strideCr
                                     withSink:(void (^)(NSData *))sink
                                        error:(NSError **)error;

- (SCCompactionInfo *)checkCompactionOpportunity;

@end

NS_ASSUME_NONNULL_END
