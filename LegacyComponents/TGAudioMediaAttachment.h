/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <LegacyComponents/TGMediaAttachment.h>

#define TGAudioMediaAttachmentType 0x3A0E7A32

@interface TGAudioMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser>

@property (nonatomic) int64_t audioId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int32_t datacenterId;

@property (nonatomic) int64_t localAudioId;

@property (nonatomic) int32_t duration;
@property (nonatomic) int32_t fileSize;

@property (nonatomic, strong) NSString *audioUri;

/*- (NSString *)localFilePath;

+ (NSString *)localAudioFileDirectoryForLocalAudioId:(int64_t)audioId;
+ (NSString *)localAudioFileDirectoryForRemoteAudioId:(int64_t)audioId;
+ (NSString *)localAudioFilePathForLocalAudioId:(int64_t)audioId;
+ (NSString *)localAudioFilePathForRemoteAudioId:(int64_t)audioId;*/

@end
