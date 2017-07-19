/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <LegacyComponents/TGMediaAttachment.h>

#import <LegacyComponents/TGImageInfo.h>

#define TGImageMediaAttachmentType 0x269BD8A8

@interface TGImageMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCopying, NSCoding>

@property (nonatomic) int64_t imageId;
@property (nonatomic, readonly) int64_t localImageId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int date;
@property (nonatomic) bool hasLocation;
@property (nonatomic) double locationLatitude;
@property (nonatomic) double locationLongitude;
@property (nonatomic, strong) TGImageInfo *imageInfo;
@property (nonatomic) NSString *caption;
@property (nonatomic) bool hasStickers;
@property (nonatomic, strong) NSArray *embeddedStickerDocuments;

@property (nonatomic, readonly) NSArray *textCheckingResults;

+ (int64_t)localImageIdForImageInfo:(TGImageInfo *)imageInfo;

- (CGSize)dimensions;

@end
