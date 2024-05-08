#ifndef QOILoader_h
#define QOILoader_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NSData * _Nullable encodeImageQOI(UIImage * _Nonnull image);
UIImage * _Nullable decodeImageQOI(NSData * _Nonnull data);

#endif /* QOILoader_h */
