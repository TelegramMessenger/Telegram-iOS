# Usage (Telegram on the simulator, at the screen to measure):
#   lldb: command script import inject_probe.py; process attach --pid <pid>; expression -l objc -- @import UIKit;
#         injectprobe; detach
# Starts a 240 Hz NSTimer in the app that logs, every tick, each bar capsule on the right (x > 290 pt): our
# GlassContextExtractableContainer ("C", whose transform is our pulse) and its UIVisualEffectView ("E", whose window
# frame is what is drawn, UIKit's press included) as "kind:address:midX,midY,width,height,m11,m22,opacity" to
# <app data>/tmp/probe3.txt. probe_series.py --ours reads it. CACurrentMediaTime is the clock; in lldb's Python
# time.clock_gettime(time.CLOCK_UPTIME_RAW) reads the same one, so a breakpoint can mark events on it.
#
# Written to survive lldb's expression compiler: it compiles without ARC, so every object the timer keeps is pinned
# with CFRetain; it finds views by walking UIView subviews (walking CALayer delegates crashed: some are dangling);
# CGRects go through NSValue temporaries (assigning a message result straight to a CGRect does not compile there).
import lldb
EXPR = r'''
__unsafe_unretained UIWindow *zWin = nil;
for (UIWindowScene *zS in [[UIApplication sharedApplication] connectedScenes]) { for (UIWindow *zX in zS.windows) { if (zX.isKeyWindow) zWin = zX; } }
__block NSMutableArray *zLines = [NSMutableArray array]; CFRetain((__bridge CFTypeRef)zLines);
__block double zLastFlush = 0;
__block double zLastFind = 0;
__block NSArray *zViews = @[]; CFRetain((__bridge CFTypeRef)zViews);
NSString *zPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"probe3.txt"]; CFRetain((__bridge CFTypeRef)zPath);
[[NSFileManager defaultManager] removeItemAtPath:zPath error:nil];
NSTimer *zTimer = [NSTimer timerWithTimeInterval:(1.0 / 240.0) repeats:YES block:^(NSTimer *t) {
  double zNow = CACurrentMediaTime();
  if (zNow - zLastFind > 0.25) {
    zLastFind = zNow;
    NSMutableArray *zFound = [NSMutableArray array];
    NSMutableArray *zStack = [NSMutableArray arrayWithObject:zWin];
    while (zStack.count > 0) {
      UIView *zV = zStack.lastObject; [zStack removeLastObject];
      NSString *zC = NSStringFromClass([zV class]);
      if ([zC containsString:@"GlassContextExtractableContainer"] || [zC isEqualToString:@"UIVisualEffectView"]) {
        CALayer *zVp = zV.layer.presentationLayer ?: zV.layer; CALayer *zWp = zWin.layer.presentationLayer ?: zWin.layer;
        NSValue *zV2 = [NSValue valueWithCGRect:[zVp convertRect:zVp.bounds toLayer:zWp]];
        CGRect zR2 = zV2.CGRectValue;
        if (zR2.origin.y < 140 && zR2.origin.x > 290 && zR2.size.width < 200) [zFound addObject:zV];
      }
      for (UIView *zSub in zV.subviews) [zStack addObject:zSub];
    }
    CFRetain((__bridge CFTypeRef)zFound); NSArray *zOld = zViews; zViews = zFound; CFRelease((__bridge CFTypeRef)zOld);
  }
  CALayer *zWl = zWin.layer.presentationLayer ?: zWin.layer;
  NSMutableArray *zOut = [NSMutableArray array];
  for (UIView *zV in zViews) {
    CALayer *zP = zV.layer.presentationLayer ?: zV.layer;
    NSValue *zV3 = [NSValue valueWithCGRect:[zP convertRect:zP.bounds toLayer:zWl]];
    CGRect zR = zV3.CGRectValue;
    CATransform3D zT = zP.transform;
    BOOL zIsContainer = [NSStringFromClass([zV class]) containsString:@"GlassContextExtractableContainer"];
    [zOut addObject:[NSString stringWithFormat:@"%@:%p:%.2f,%.2f,%.2f,%.2f,%.4f,%.4f,%.2f", zIsContainer ? @"C" : @"E", zV, zR.origin.x + zR.size.width * 0.5, zR.origin.y + zR.size.height * 0.5, zR.size.width, zR.size.height, zT.m11, zT.m22, zP.opacity]];
  }
  [zLines addObject:[NSString stringWithFormat:@"%.4f OURS %@", zNow, [zOut componentsJoinedByString:@";"]]];
  if (zNow - zLastFlush > 0.5) { zLastFlush = zNow; [[zLines componentsJoinedByString:@"\n"] writeToFile:zPath atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
}];
[[NSRunLoop mainRunLoop] addTimer:zTimer forMode:NSRunLoopCommonModes];
zPath;
'''
def inject(debugger, command, result, internal_dict):
    frame = debugger.GetSelectedTarget().GetProcess().GetSelectedThread().GetSelectedFrame()
    opts = lldb.SBExpressionOptions()
    opts.SetLanguage(lldb.eLanguageTypeObjC_plus_plus)
    opts.SetTimeoutInMicroSeconds(30 * 1000000)
    v = frame.EvaluateExpression(EXPR, opts)
    print(v.GetObjectDescription() or str(v.GetError()))
def __lldb_init_module(debugger, d):
    debugger.HandleCommand('command script add -f inject_probe.inject injectprobe')
