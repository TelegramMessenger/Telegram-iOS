//
//  ASCGImageBuffer.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <CoreGraphics/CGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASCGImageBuffer : NSObject

/// Init a zero-filled buffer with the given length.
- (instancetype)initWithLength:(NSUInteger)length;

@property (readonly) void *mutableBytes NS_RETURNS_INNER_POINTER;

/// Don't do any drawing or call any methods after calling this.
- (CGDataProviderRef)createDataProviderAndInvalidate CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
