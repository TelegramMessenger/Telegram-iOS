#import <UIKit/UIKit.h>
#import <SSignalKit/SSignalKit.h>

@class TGLocationMediaAttachment;

@interface TGLocationInfoCell : UITableViewCell

@property (nonatomic, copy) void (^locatePressed)(void);
@property (nonatomic, copy) void (^directionsPressed)(void);

- (void)setLocation:(TGLocationMediaAttachment *)location messageId:(int32_t)messageId userLocationSignal:(SSignal *)userLocationSignal;

@end

extern NSString *const TGLocationInfoCellKind;
extern const CGFloat TGLocationInfoCellHeight;

