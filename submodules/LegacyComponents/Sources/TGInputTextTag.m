#import "TGInputTextTag.h"

#import <CoreText/CoreText.h>

@implementation TGInputTextTag

- (instancetype)initWithUniqueId:(int64_t)uniqueId left:(bool)left attachment:(id)attachment {
    static NSData *imageData = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 1.0f), false, 0.0f);
        imageData = UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());
        UIGraphicsEndImageContext();
    });
    
    self = [super initWithData:imageData ofType:@"public.image"];
    if (self != nil) {
        _uniqueId = uniqueId;
        _left = left;
        _attachment = attachment;
    }
    return self;
}

- (NSTextAttachment *)textAttachment {
    static UIImage *image = nil;
    static NSData *imageData = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 1.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor blueColor].CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 2.0f, 9.0f));
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        imageData = UIImagePNGRepresentation(image);
    });
    
    return nil;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)__unused textContainer proposedLineFragment:(CGRect)__unused lineFrag glyphPosition:(CGPoint)__unused position characterIndex:(NSUInteger)__unused charIndex {
    return CGRectZero;
}

@end

@implementation TGInputTextTagAndRange

- (instancetype)initWithTag:(TGInputTextTag *)tag range:(NSRange)range {
    self = [super init];
    if (self != nil) {
        _tag = tag;
        _range = range;
    }
    return self;
}

@end
