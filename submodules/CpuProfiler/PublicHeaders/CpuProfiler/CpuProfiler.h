#ifndef CpuProfiler_h
#define CpuProfiler_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// An in-process sampling profiler.
///
/// On each tick every thread is inspected for its accumulated CPU time, and the ones
/// the kernel reports as running are suspended just long enough to read their registers
/// and walk the frame-pointer chain. Nothing is allocated and no lock is taken while a
/// thread is suspended: if the suspended thread happens to hold the allocator lock, a
/// single malloc in the sampler deadlocks the process.
@interface CpuProfiler : NSObject

/// Samples all threads for `duration` seconds at `sampleRate` samples per second and
/// produces a text report: per-thread CPU shares followed by a merged call tree per
/// thread, with a Binary Images footer so the frames can be symbolicated offline
/// against the matching dSYM.
///
/// The completion runs on the main queue. If a profile is already running, it is
/// called immediately with nil.
+ (void)collectProfileWithDuration:(NSTimeInterval)duration
                        sampleRate:(double)sampleRate
                        completion:(void (^)(NSString * _Nullable report))completion;

@property (class, nonatomic, readonly) BOOL isRunning;

@end

NS_ASSUME_NONNULL_END

#endif /* CpuProfiler_h */
