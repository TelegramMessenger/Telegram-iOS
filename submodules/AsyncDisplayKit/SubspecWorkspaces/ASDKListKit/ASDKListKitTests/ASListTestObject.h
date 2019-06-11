//
//  ASListTestObject.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASListTestObject : NSObject <IGListDiffable, NSCopying>

- (instancetype)initWithKey:(id <NSCopying>)key value:(id)value;

@property (nonatomic, strong, readonly) id key;
@property (nonatomic, strong) id value;

@end

NS_ASSUME_NONNULL_END
