//
//  ASTip.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

NS_ASSUME_NONNULL_BEGIN

@class ASDisplayNode;

typedef NS_ENUM (NSInteger, ASTipKind) {
  ASTipKindEnableLayerBacking
};

AS_SUBCLASSING_RESTRICTED
@interface ASTip : NSObject

- (instancetype)initWithNode:(ASDisplayNode *)node
                        kind:(ASTipKind)kind
                      format:(NSString *)format, ... NS_FORMAT_FUNCTION(3, 4);

/**
 * The kind of tip this is.
 */
@property (nonatomic, readonly) ASTipKind kind;

/**
 * The node that this tip applies to.
 */
@property (nonatomic, readonly) ASDisplayNode *node;

/**
 * The text to show the user.
 */
@property (nonatomic, readonly) NSString *text;

@end

NS_ASSUME_NONNULL_END

#endif // AS_ENABLE_TIPS
