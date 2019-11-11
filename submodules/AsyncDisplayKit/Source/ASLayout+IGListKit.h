//
//  ASLayout+IGListKit.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if AS_IG_LIST_KIT
#import <AsyncDisplayKit/ASLayout.h>
#import <IGListKit/IGListKit.h>
@interface ASLayout(IGListKit) <IGListDiffable>
@end

#endif // AS_IG_LIST_KIT
