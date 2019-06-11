#import <LegacyComponents/TGModernButton.h>

#import "TGPasscodeBackground.h"

@interface TGPasscodeButtonView : TGModernButton

- (void)setAbsoluteOffset:(CGPoint)absoluteOffset;

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle;
- (void)setBackground:(id<TGPasscodeBackground>)background;

@end
