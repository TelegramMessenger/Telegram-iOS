//
//  RefreshingSectionControllerType.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol RefreshingSectionControllerType

- (void)refreshContentWithCompletion:(nullable void(^)())completion;

@end

NS_ASSUME_NONNULL_END
