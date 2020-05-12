#ifndef RTCCONNECTION_H
#define RTCCONNECTION_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RtcConnection : NSObject

- (instancetype _Nonnull)initWithDiscoveredIceCandidate:(void (^_Nonnull)(NSString *, int, NSString * _Nonnull))discoveredIceCandidate connectionStateChanged:(void (^_Nonnull)(bool))connectionStateChanged;

- (void)close;

- (void)setIsMuted:(bool)isMuted;

- (void)getOffer:(void (^_Nonnull)(NSString * _Nonnull, NSString * _Nonnull))completion;
- (void)getAnswer:(void (^_Nonnull)(NSString * _Nonnull, NSString * _Nonnull))completion;
- (void)setLocalDescription:(NSString * _Nonnull)serializedDescription type:(NSString * _Nonnull)type completion:(void (^_Nonnull)())completion;
- (void)setRemoteDescription:(NSString * _Nonnull)serializedDescription type:(NSString * _Nonnull)type completion:(void (^_Nonnull)())completion;
- (void)addIceCandidateWithSdp:(NSString * _Nonnull)sdp sdpMLineIndex:(int)sdpMLineIndex sdpMid:(NSString * _Nullable)sdpMid;

- (void)getRemoteCameraView:(void (^_Nonnull)(UIView * _Nullable))completion;

@end

#endif
