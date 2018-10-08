//
//  _ASScopeTimer.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#pragma once

/**
 Must compile as c++ for this to work.

 Usage:
 // Can be an ivar or local variable
 NSTimeInterval placeToStoreTiming;

 {
   // some scope
   ASDisplayNode::ScopeTimer t(placeToStoreTiming);
   DoPotentiallySlowWork();
   MorePotentiallySlowWork();
 }

 */

namespace ASDN {
  struct ScopeTimer {
    NSTimeInterval begin;
    NSTimeInterval &outT;
    ScopeTimer(NSTimeInterval &outRef) : outT(outRef) {
      begin = CACurrentMediaTime();
    }
    ~ScopeTimer() {
      outT = CACurrentMediaTime() - begin;
    }
  };

  // variant where repeated calls are summed
  struct SumScopeTimer {
    NSTimeInterval begin;
    NSTimeInterval &outT;
    BOOL enable;
    SumScopeTimer(NSTimeInterval &outRef, BOOL enable = YES) : outT(outRef), enable(enable) {
      if (enable) {
        begin = CACurrentMediaTime();
      }
    }
    ~SumScopeTimer() {
      if (enable) {
        outT += CACurrentMediaTime() - begin;
      }
    }
  };
}
