

#import <LegacyComponents/TGMediaAttachment.h>

#define TGLocationMediaAttachmentType 0x0C9ED06E

@interface TGVenueAttachment : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *address;
@property (nonatomic, strong, readonly) NSString *provider;
@property (nonatomic, strong, readonly) NSString *venueId;
@property (nonatomic, strong, readonly) NSString *type;

- (instancetype)initWithTitle:(NSString *)title address:(NSString *)address provider:(NSString *)provider venueId:(NSString *)venueId type:(NSString *)type;

@end

@interface TGLocationMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic) double latitude;
@property (nonatomic) double longitude;

@property (nonatomic, strong) TGVenueAttachment *venue;

@property (nonatomic) int32_t period;

- (bool)isLiveLocation;

@end
