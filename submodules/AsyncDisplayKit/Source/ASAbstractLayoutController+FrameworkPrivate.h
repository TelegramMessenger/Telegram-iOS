//
//  ASAbstractLayoutController+FrameworkPrivate.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

//
// The following methods are ONLY for use by _ASDisplayLayer, _ASDisplayView, and ASDisplayNode.
// These methods must never be called or overridden by other classes.
//

#include <vector>

@interface ASAbstractLayoutController (FrameworkPrivate)

+ (std::vector<std::vector<ASRangeTuningParameters>>)defaultTuningParameters; 

@end
