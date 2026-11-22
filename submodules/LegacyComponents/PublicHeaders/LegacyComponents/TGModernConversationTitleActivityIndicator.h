#import <UIKit/UIKit.h>

@interface TGModernConversationTitleActivityIndicator : UIView

- (void)setColor:(UIColor *)color;

- (void)setNone;
- (void)setTyping;
- (void)setAudioRecording;
- (void)setVideoRecording;
- (void)setUploading;
- (void)setPlaying;

@end
