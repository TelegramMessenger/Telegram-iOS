#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>

@interface TGChannelBannedRights : NSObject <PSCoding>

@property (nonatomic, readonly) bool banReadMessages;
@property (nonatomic, readonly) bool banSendMessages;
@property (nonatomic, readonly) bool banSendMedia;
@property (nonatomic, readonly) bool banSendStickers;
@property (nonatomic, readonly) bool banSendGifs;
@property (nonatomic, readonly) bool banSendGames;
@property (nonatomic, readonly) bool banSendInline;
@property (nonatomic, readonly) bool banEmbedLinks;
@property (nonatomic, readonly) int32_t timeout;

- (instancetype)initWithBanReadMessages:(bool)banReadMessages banSendMessages:(bool)banSendMessages banSendMedia:(bool)banSendMedia banSendStickers:(bool)banSendStickers banSendGifs:(bool)banSendGifs banSendGames:(bool)banSendGames banSendInline:(bool)banSendInline banEmbedLinks:(bool)banEmbedLinks timeout:(int32_t)timeout;

- (instancetype)initWithFlags:(int32_t)flags timeout:(int32_t)timeout;

- (int32_t)tlFlags;

- (int32_t)numberOfRestrictions;

@end
