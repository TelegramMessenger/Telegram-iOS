/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <LegacyComponents/TGMediaAttachment.h>

#define TGLocalMessageMetaMediaAttachmentType 0x944DE6B6

@interface TGLocalMessageMetaMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser>

@property (nonatomic, strong) NSMutableArray *imageInfoList;
@property (nonatomic, strong) NSMutableDictionary *imageUrlToDataFile;
@property (nonatomic) int localMediaId;

@end
