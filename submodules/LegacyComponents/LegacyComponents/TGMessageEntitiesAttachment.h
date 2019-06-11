#import "TGMediaAttachment.h"

#import <LegacyComponents/TGMessageEntityUrl.h>
#import <LegacyComponents/TGMessageEntityEmail.h>
#import <LegacyComponents/TGMessageEntityTextUrl.h>
#import <LegacyComponents/TGMessageEntityMention.h>
#import <LegacyComponents/TGMessageEntityHashtag.h>
#import <LegacyComponents/TGMessageEntityBotCommand.h>
#import <LegacyComponents/TGMessageEntityBold.h>
#import <LegacyComponents/TGMessageEntityItalic.h>
#import <LegacyComponents/TGMessageEntityCode.h>
#import <LegacyComponents/TGMessageEntityPre.h>
#import <LegacyComponents/TGMessageEntityMentionName.h>
#import <LegacyComponents/TGMessageEntityPhone.h>
#import <LegacyComponents/TGMessageEntityCashtag.h>

#define TGMessageEntitiesAttachmentType ((int)0x8C2E3CCE)

@interface TGMessageEntitiesAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic, strong) NSArray *entities;

@end
