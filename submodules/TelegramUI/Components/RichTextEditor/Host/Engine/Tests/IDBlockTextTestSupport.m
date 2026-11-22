#import "IDBlockTextTestSupport.h"

#import "IDBlockDocument.h"

NSDictionary<NSAttributedStringKey, id> *IDBlockTextTestAttributes(void) {
    return @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
        NSForegroundColorAttributeName: UIColor.labelColor,
    };
}

NSAttributedString *IDBlockTextTestAttributedString(NSString *string) {
    return [[NSAttributedString alloc] initWithString:string
                                           attributes:IDBlockTextTestAttributes()];
}

IDBlockDocument *IDBlockTextTestDocument(NSArray<NSString *> *blocks) {
    NSMutableArray<NSAttributedString *> *attributedBlocks = [NSMutableArray array];
    for (NSString *block in blocks) {
        [attributedBlocks addObject:IDBlockTextTestAttributedString(block)];
    }
    return [[IDBlockDocument alloc] initWithAttributedBlocks:attributedBlocks
                                           defaultAttributes:IDBlockTextTestAttributes()];
}
