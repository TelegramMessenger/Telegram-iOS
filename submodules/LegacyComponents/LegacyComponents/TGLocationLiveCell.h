#import <UIKit/UIKit.h>
#import <SSignalKit/SSignalKit.h>

@class TGUser;
@class TGMessage;
@class TGLocationPallete;

@interface TGLocationLiveCell : UITableViewCell

@property (nonatomic, strong) TGLocationPallete *pallete;
@property (nonatomic, assign) UIEdgeInsets safeInset;
@property (nonatomic, copy) void (^longPressed)(void);

@property (nonatomic, readonly) int32_t messageId;
@property (nonatomic, weak) UIImageView *edgeView;

- (void)configureWithPeer:(id)peer message:(TGMessage *)message remaining:(SSignal *)remaining userLocationSignal:(SSignal *)userLocationSignal;
- (void)configureForStart;
- (void)configureForStopWithMessage:(TGMessage *)message remaining:(SSignal *)remaining;

@end

extern NSString *const TGLocationLiveCellKind;
extern const CGFloat TGLocationLiveCellHeight;
