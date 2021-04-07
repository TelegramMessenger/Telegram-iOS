#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGPhotoPaintFont : NSObject

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) CGFloat titleInset;

@property (nonatomic, readonly) NSString *fontName;
@property (nonatomic, readonly) NSString *previewFontName;

@property (nonatomic, readonly) CGFloat sizeCorrection;

+ (NSArray *)availableFonts;

@end
