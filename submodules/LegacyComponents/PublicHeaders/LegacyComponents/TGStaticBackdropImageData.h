#import <UIKit/UIKit.h>

@class TGStaticBackdropAreaData;

extern NSString *TGStaticBackdropMessageActionCircle;
extern NSString *TGStaticBackdropMessageTimestamp;
extern NSString *TGStaticBackdropMessageAdditionalData;

@interface TGStaticBackdropImageData : NSObject

- (TGStaticBackdropAreaData *)backdropAreaForKey:(NSString *)key;
- (void)setBackdropArea:(TGStaticBackdropAreaData *)backdropArea forKey:(NSString *)key;

@end
