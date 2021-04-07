#import <LegacyImageProcessors/LegacyImageProcessors.h>

#import <LegacyComponents/LegacyComponents.h>

@implementation LegacyImageProcessors

+ (void)load {
    [TGRemoteImageView registerImageUniversalProcessor:^UIImage *(NSString *name, UIImage *source) {
        CGSize size = CGSizeZero;
        int n = 7;
        bool invalid = false;
        for (int i = n; i < (int)name.length; i++) {
            unichar c = [name characterAtIndex:i];
            if (c == 'x')
            {
                if (i == n)
                    invalid = true;
                else
                {
                    size.width = [[name substringWithRange:NSMakeRange(n, i - n)] intValue];
                    n = i + 1;
                }
                break;
            }
            else if (c < '0' || c > '9')
            {
                invalid = true;
                break;
            }
        }
        if (!invalid)
        {
            for (int i = n; i < (int)name.length; i++)
            {
                unichar c = [name characterAtIndex:i];
                if (c < '0' || c > '9')
                {
                    invalid = true;
                    break;
                }
                else if (i == (int)name.length - 1)
                {
                    size.height = [[name substringFromIndex:n] intValue];
                }
            }
        }
        if (!invalid)
        {
            return TGScaleAndRoundCornersWithOffsetAndFlags(source, size, CGPointZero, size, (int)size.width / 2, nil, false, nil, TGScaleImageScaleSharper);
        }
        
        return nil;
    } withBaseName:@"circle"];
}

@end
