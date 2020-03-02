#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
    
UIColor *TGAccentColor();
UIColor *TGDestructiveAccentColor();
UIColor *TGSelectionColor();
UIColor *TGSeparatorColor();

UIColor *TGColorWithHex(int hex);
UIColor *TGColorWithHexAndAlpha(int hex, CGFloat alpha);

#ifdef __cplusplus
}
#endif
