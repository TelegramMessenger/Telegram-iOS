@import UIKit;

@class IDBlockDocument;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSDictionary<NSAttributedStringKey, id> *IDBlockTextTestAttributes(void);
FOUNDATION_EXPORT NSAttributedString *IDBlockTextTestAttributedString(NSString *string);
FOUNDATION_EXPORT IDBlockDocument *IDBlockTextTestDocument(NSArray<NSString *> *blocks);

NS_ASSUME_NONNULL_END
