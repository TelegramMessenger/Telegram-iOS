//
//  ASImageNode+Private.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#pragma once

@interface ASImageNode (Private)

- (void)_locked_setImage:(UIImage *)image;
- (UIImage *)_locked_Image;

@end
