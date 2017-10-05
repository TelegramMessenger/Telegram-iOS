#import <UIKit/UIKit.h>
#import <SSignalKit/SSignalKit.h>

@class TGUser;
@class TGMessage;

@interface TGLocationLiveCell : UITableViewCell

@property (nonatomic, copy) void (^longPressed)(void);

@property (nonatomic, readonly) int32_t messageId;
@property (nonatomic, weak) UIImageView *edgeView;

- (void)configureWithPeer:(id)peer message:(TGMessage *)message remaining:(SSignal *)remaining userLocationSignal:(SSignal *)userLocationSignal;
- (void)configureForStart;
- (void)configureForStopWithMessage:(TGMessage *)message remaining:(SSignal *)remaining;

@end

extern NSString *const TGLocationLiveCellKind;
extern const CGFloat TGLocationLiveCellHeight;
