#import <UIKit/UIKit.h>

@class TGImageLuminanceMap;
@class TGStaticBackdropImageData;

@interface UIImage (TG)

- (NSDictionary *)attachmentsDictionary;
- (void)setAttachmentsFromDictionary:(NSDictionary *)attachmentsDictionary;

- (TGStaticBackdropImageData *)staticBackdropImageData;
- (void)setStaticBackdropImageData:(TGStaticBackdropImageData *)staticBackdropImageData;

- (UIEdgeInsets)extendedEdgeInsets;
- (void)setExtendedEdgeInsets:(UIEdgeInsets)edgeInsets;

- (bool)degraded;
- (void)setDegraded:(bool)degraded;

- (bool)edited;
- (void)setEdited:(bool)edited;

- (bool)fromCloud;
- (void)setFromCloud:(bool)fromCloud;

@end
