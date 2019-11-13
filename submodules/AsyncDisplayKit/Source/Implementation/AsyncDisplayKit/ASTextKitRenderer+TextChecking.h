//
//  ASTextKitRenderer+TextChecking.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTextKitRenderer.h>

#if AS_ENABLE_TEXTNODE

/**
 Application extensions to NSTextCheckingType. We're allowed to do this (see NSTextCheckingAllCustomTypes).
 */
static uint64_t const ASTextKitTextCheckingTypeEntity =               1ULL << 33;
static uint64_t const ASTextKitTextCheckingTypeTruncation =           1ULL << 34;

@class ASTextKitEntityAttribute;

@interface ASTextKitTextCheckingResult : NSTextCheckingResult
@property (nonatomic, readonly) ASTextKitEntityAttribute *entityAttribute;
@end

@interface ASTextKitRenderer (TextChecking)

- (NSTextCheckingResult *)textCheckingResultAtPoint:(CGPoint)point;

@end

#endif
