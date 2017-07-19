/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <LegacyComponents/TGMediaAttachment.h>

#import <LegacyComponents/TGVideoInfo.h>
#import <LegacyComponents/TGImageInfo.h>

#define TGVideoMediaAttachmentType ((int)0x338EAA20)

@interface TGVideoMediaAttachment : TGMediaAttachment <NSCoding, TGMediaAttachmentParser>

@property (nonatomic) int64_t videoId;
@property (nonatomic) int64_t accessHash;

@property (nonatomic) int64_t localVideoId;

@property (nonatomic) int duration;
@property (nonatomic) CGSize dimensions;

@property (nonatomic, strong) TGVideoInfo *videoInfo;
@property (nonatomic, strong) TGImageInfo *thumbnailInfo;

@property (nonatomic) NSString *caption;
@property (nonatomic) bool hasStickers;
@property (nonatomic, strong) NSArray *embeddedStickerDocuments;

@property (nonatomic, readonly) NSArray *textCheckingResults;

@property (nonatomic) bool loopVideo;
@property (nonatomic) bool roundMessage;

@end
