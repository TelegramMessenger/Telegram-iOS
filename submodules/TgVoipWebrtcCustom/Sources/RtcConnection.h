#ifndef RTCCONNECTION_H
#define RTCCONNECTION_H

#import <Foundation/Foundation.h>

@interface RtcConnection : NSObject

- (instancetype)initWithDiscoveredIceCandidate:(void (^)(NSString *, int, NSString *))discoveredIceCandidate connectionStateChanged:(void (^)(bool))connectionStateChanged;

- (void)close;

- (void)getOffer:(void (^)(NSString *, NSString *))completion;
- (void)getAnswer:(void (^)(NSString *, NSString *))completion;
- (void)setLocalDescription:(NSString *)serializedDescription type:(NSString *)type completion:(void (^)())completion;
- (void)setRemoteDescription:(NSString *)serializedDescription type:(NSString *)type completion:(void (^)())completion;
- (void)addIceCandidateWithSdp:(NSString *)sdp sdpMLineIndex:(int)sdpMLineIndex sdpMid:(NSString *)sdpMid;

@end

#endif
