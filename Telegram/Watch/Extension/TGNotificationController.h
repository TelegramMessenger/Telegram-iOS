#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface TGNotificationController : WKUserNotificationInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *forwardHeaderGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *forwardTitleLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *forwardFromLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *replyHeaderGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *replyHeaderImageGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *replyAuthorNameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *replyMessageTextLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *nameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *messageTextLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *chatTitleLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *mediaGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *captionGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *captionLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *wrapperGroup;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *mapGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceMap *map;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *durationGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *durationLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *titleLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *subtitleLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *audioGroup;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *fileGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *fileIconGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *venueIcon;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *stickerWrapperGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *stickerGroup;

@end
