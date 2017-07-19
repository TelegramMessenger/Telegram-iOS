#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>
#import <LegacyComponents/TGMessageEntity.h>

@interface TGDatabaseMessageDraft : NSObject <PSCoding>

@property (nonatomic, strong, readonly) NSString *text;
@property (nonatomic, strong, readonly) NSArray<TGMessageEntity *> *entities;
@property (nonatomic, readonly) bool disableLinkPreview;
@property (nonatomic, readonly) int32_t replyToMessageId;
@property (nonatomic, readonly) int32_t date;

- (instancetype)initWithText:(NSString *)text entities:(NSArray<TGMessageEntity *> *)entities disableLinkPreview:(bool)disableLinkPreview replyToMessageId:(int32_t)replyToMessageId date:(int32_t)date;

- (bool)isEmpty;

- (TGDatabaseMessageDraft *)updateDate:(int32_t)date;

@end
