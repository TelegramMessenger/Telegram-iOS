//
//  ASDisplayNode+CatDeals.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0

#import "ASDisplayNode+CatDeals.h"

#import <AsyncDisplayKit/ASThread.h>

// A place to store info on any display node in this app.
struct CatDealsNodeContext {
  NSString *loggingID = nil;
};

// Convenience to cast _displayNodeContext into our struct reference.
NS_INLINE CatDealsNodeContext &GetNodeContext(ASDisplayNode *node) {
  return *static_cast<CatDealsNodeContext *>(node->_displayNodeContext);
}

@implementation ASDisplayNode (CatDeals)

- (void)baseDidInit
{
  _displayNodeContext = new CatDealsNodeContext;
}

- (void)baseWillDealloc
{
  delete &GetNodeContext(self);
}

- (void)setCatsLoggingID:(NSString *)catsLoggingID
{
  NSString *copy = [catsLoggingID copy];
  ASLockScopeSelf();
  GetNodeContext(self).loggingID = copy;
}

- (NSString *)catsLoggingID
{
  ASLockScopeSelf();
  return GetNodeContext(self).loggingID;
}

- (void)didEnterVisibleState
{
  if (NSString *loggingID = self.catsLoggingID) {
    NSLog(@"Visible: %@", loggingID);
  }
}

- (void)didExitVisibleState
{
  if (NSString *loggingID = self.catsLoggingID) {
    NSLog(@"NotVisible: %@", loggingID);
  }
}

@end
