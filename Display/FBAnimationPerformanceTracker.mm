//
//  FBAnimationPerformanceTracker.m
//  Display
//
//  Created by Peter on 3/16/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

#import "FBAnimationPerformanceTracker.h"

#import <dlfcn.h>
#import <map>
#import <pthread.h>

#import <QuartzCore/CADisplayLink.h>

#import <mach-o/dyld.h>

#import "execinfo.h"

#include <mach/mach_time.h>

static BOOL _signalSetup;
static pthread_t _mainThread;
static NSThread *_trackerThread;

static std::map<void *, NSString *, std::greater<void *>> _imageNames;

#ifdef __LP64__
typedef mach_header_64 fb_mach_header;
typedef segment_command_64 fb_mach_segment_command;
#define LC_SEGMENT_ARCH LC_SEGMENT_64
#else
typedef mach_header fb_mach_header;
typedef segment_command fb_mach_segment_command;
#define LC_SEGMENT_ARCH LC_SEGMENT
#endif

static volatile BOOL _scrolling;
pthread_mutex_t _scrollingMutex;
pthread_cond_t _scrollingCondVariable;
dispatch_queue_t _symbolicationQueue;

// We record at most 16 frames since I cap the number of frames dropped measured at 15.
// Past 15, something went very wrong (massive contention, priority inversion, rpc call going wrong...) .
// It will only pollute the data to get more.
static const int callstack_max_number = 16;

static int callstack_i;
static bool callstack_dirty;
static int callstack_size[callstack_max_number];
static void *callstacks[callstack_max_number][128];
uint64_t callstack_time_capture;

static void _callstack_signal_handler(int signr, siginfo_t *info, void *secret)
{
    // This is run on the main thread every 16 ms or so during scroll.
    
    // Signals are run one by one so there is no risk of concurrency of a signal
    // by the same signal.
    
    // The backtrace call is technically signal-safe on Unix-based system
    // See: http://www.unix.com/man-page/all/3c/walkcontext/
    
    // WARNING: this is signal handler, no memory allocation is safe.
    // Essentially nothing is safe unless specified it is.
    callstack_size[callstack_i] = backtrace(callstacks[callstack_i], 128);
    callstack_i = (callstack_i + 1) & (callstack_max_number - 1); // & is a cheap modulo (only works for power of 2)
    callstack_dirty = true;
}

@interface FBCallstack : NSObject
@property (nonatomic, readonly, assign) int size;
@property (nonatomic, readonly, assign) void **callstack;
- (instancetype)initWithSize:(int)size callstack:(void *)callstack;
@end

@implementation FBCallstack
- (instancetype)initWithSize:(int)size callstack:(void *)callstack
{
    if (self = [super init]) {
        _size = size;
        _callstack = (void **)malloc(size * sizeof(void *));
        memcpy(_callstack, callstack, size * sizeof(void *));
    }
    return self;
}

- (void)dealloc
{
    free(_callstack);
}
@end

@implementation FBAnimationPerformanceTracker
{
    FBAnimationPerformanceTrackerConfig _config;
    
    BOOL _tracking;
    BOOL _firstUpdate;
    NSTimeInterval _previousFrameTimestamp;
    CADisplayLink *_displayLink;
    BOOL _prepared;
    
    // numbers used to track the performance metrics
    double _durationTotal;
    double _maxFrameTime;
    double _smallDrops;
    double _largeDrops;
}

- (instancetype)initWithConfig:(FBAnimationPerformanceTrackerConfig)config
{
    if (self = [super init]) {
        // Stack trace logging is not working well in debug mode
        // We don't want the data anyway. So let's bail.
#if defined(DEBUG)
        config.reportStackTraces = NO;
#endif
        _config = config;
        if (config.reportStackTraces) {
            [self _setupSignal];
        }
    }
    return self;
}

+ (FBAnimationPerformanceTrackerConfig)standardConfig
{
    FBAnimationPerformanceTrackerConfig config = {
        .smallDropEventFrameNumber = 1,
        .largeDropEventFrameNumber = 4,
        .maxFrameDropAccount = 15,
        .reportStackTraces = NO
    };
    return config;
}

+ (void)_trackerLoop
{
    while (true) {
        // If you are confused by this part,
        // Check out https://computing.llnl.gov/tutorials/pthreads/#ConditionVariables
        
        // Lock the mutex
        pthread_mutex_lock(&_scrollingMutex);
        while (!_scrolling) {
            // Unlock the mutex and sleep until the conditional variable is signaled
            pthread_cond_wait(&_scrollingCondVariable, &_scrollingMutex);
            // The conditional variable was signaled, but we need to check _scrolling
            // As nothing guarantees that it is still true
        }
        // _scrolling is true, go ahead and capture traces for a while.
        pthread_mutex_unlock(&_scrollingMutex);
        
        // We are scrolling, yay, capture traces
        while (_scrolling) {
            usleep(16000);
            
            // Here I use SIGPROF which is a signal supposed to be used for profiling
            // I haven't stumbled upon any collision so far.
            // There is no guarantee that it won't impact the system in unpredicted ways.
            // Use wisely.
            
            pthread_kill(_mainThread, SIGPROF);
        }
    }
}

- (void)_setupSignal
{
    if (!_signalSetup) {
        // The signal hook should be setup once and only once
        _signalSetup = YES;
        
        // I actually don't know if the main thread can die. If it does, well,
        // this is not going to work.
        // UPDATE 4/2015: on iOS8, it looks like the main-thread never dies, and this pointer is correct
        _mainThread = pthread_self();
        
        callstack_i = 0;
        
        // Setup the signal
        struct sigaction sa;
        sigfillset(&sa.sa_mask);
        sa.sa_flags = SA_SIGINFO;
        sa.sa_sigaction = _callstack_signal_handler;
        sigaction(SIGPROF, &sa, NULL);
        
        pthread_mutex_init(&_scrollingMutex, NULL);
        pthread_cond_init (&_scrollingCondVariable, NULL);
        
        // Setup the signal firing loop
        _trackerThread = [[NSThread alloc] initWithTarget:[self class] selector:@selector(_trackerLoop) object:nil];
        // We wanna be higher priority than the main thread
        // On iOS8 : this will roughly stick us at priority 61, while the main thread oscillates between 20 and 47
        _trackerThread.threadPriority = 1.0;
        [_trackerThread start];
        
        _symbolicationQueue = dispatch_queue_create("com.facebook.symbolication", DISPATCH_QUEUE_SERIAL);
        dispatch_async(_symbolicationQueue, ^(void) {[self _setupSymbolication];});
    }
}

- (void)_setupSymbolication
{
    // This extract the starting slide of every module in the app
    // This is used to know which module an instruction pointer belongs to.
    
    // These operations is NOT thread-safe according to Apple docs
    // Do not call this multiple times
    int images = _dyld_image_count();
    
    for (int i = 0; i < images; i ++) {
        intptr_t imageSlide = _dyld_get_image_vmaddr_slide(i);
        
        // Here we extract the module name from the full path
        // Typically it looks something like: /path/to/lib/UIKit
        // And I just extract UIKit
        NSString *fullName = [NSString stringWithUTF8String:_dyld_get_image_name(i)];
        NSRange range = [fullName rangeOfString:@"/" options:NSBackwardsSearch];
        NSUInteger startP = (range.location != NSNotFound) ? range.location + 1 : 0;
        NSString *imageName = [fullName substringFromIndex:startP];
        
        // This is parsing the mach header in order to extract the slide.
        // See https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/MachORuntime/index.html
        // For the structure of mach headers
        fb_mach_header *header = (fb_mach_header*)_dyld_get_image_header(i);
        if (!header) {
            continue;
        }
        
        const struct load_command *cmd =
        reinterpret_cast<const struct load_command *>(header + 1);
        
        for (unsigned int c = 0; cmd && (c < header->ncmds); c++) {
            if (cmd->cmd == LC_SEGMENT_ARCH) {
                const fb_mach_segment_command *seg =
                reinterpret_cast<const fb_mach_segment_command *>(cmd);
                
                if (!strcmp(seg->segname, "__TEXT")) {
                    _imageNames[(void *)(seg->vmaddr + imageSlide)] = imageName;
                    break;
                }
            }
            cmd = reinterpret_cast<struct load_command*>((char *)cmd + cmd->cmdsize);
        }
    }
}

- (void)dealloc
{
    if (_prepared) {
        [self _tearDownCADisplayLink];
    }
}

#pragma mark - Tracking

- (void)start
{
    if (!_tracking) {
        if ([self prepare]) {
            _displayLink.paused = NO;
            _tracking = YES;
            [self _reset];
            
            if (_config.reportStackTraces) {
                pthread_mutex_lock(&_scrollingMutex);
                _scrolling = YES;
                // Signal the tracker thread to start firing the signals
                pthread_cond_signal(&_scrollingCondVariable);
                pthread_mutex_unlock(&_scrollingMutex);
            }
        }
    }
}

- (void)stop
{
    if (_tracking) {
        _tracking = NO;
        _displayLink.paused = YES;
        if (_durationTotal > 0) {
            [_delegate reportDurationInMS:round(1000.0 * _durationTotal) smallDropEvent:_smallDrops largeDropEvent:_largeDrops];
            if (_config.reportStackTraces) {
                pthread_mutex_lock(&_scrollingMutex);
                _scrolling = NO;
                pthread_mutex_unlock(&_scrollingMutex);
            }
        }
    }
}

- (BOOL)prepare
{
    if (_prepared) {
        return YES;
    }
    
    [self _setUpCADisplayLink];
    _prepared = YES;
    
    return YES;
}

- (void)_setUpCADisplayLink
{
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_update)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _displayLink.paused = YES;
}

- (void)_tearDownCADisplayLink
{
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)_reset
{
    _firstUpdate = YES;
    _previousFrameTimestamp = 0.0;
    _durationTotal = 0;
    _maxFrameTime = 0;
    _largeDrops = 0;
    _smallDrops = 0;
}

- (void)_addFrameTime:(NSTimeInterval)actualFrameTime singleFrameTime:(NSTimeInterval)singleFrameTime
{
    _maxFrameTime = MAX(actualFrameTime, _maxFrameTime);
    
    NSInteger frameDropped = round(actualFrameTime / singleFrameTime) - 1;
    frameDropped = MAX(frameDropped, 0);
    // This is to reduce noise. Massive frame drops will just add noise to your data.
    frameDropped = MIN(_config.maxFrameDropAccount, frameDropped);
    
    _durationTotal += (frameDropped + 1) * singleFrameTime;
    // We account 2 frame drops as 2 small events. This way the metric correlates perfectly with Time at X fps.
    _smallDrops += (frameDropped >= _config.smallDropEventFrameNumber) ? ((double) frameDropped) / (double)_config.smallDropEventFrameNumber : 0.0;
    _largeDrops += (frameDropped >= _config.largeDropEventFrameNumber) ? ((double) frameDropped) / (double)_config.largeDropEventFrameNumber : 0.0;
    
    if (frameDropped >= 1) {
        if (_config.reportStackTraces) {
            callstack_dirty = false;
            for (int ci = 0; ci <= frameDropped ; ci ++) {
                // This is computing the previous indexes
                // callstack - 1 - ci takes us back ci frames
                // I want a positive number so I add callstack_max_number
                // And then just modulo it, with & (callstack_max_number - 1)
                int callstackPreviousIndex = ((callstack_i - 1 - ci) + callstack_max_number) & (callstack_max_number - 1);
                FBCallstack *callstackCopy = [[FBCallstack alloc] initWithSize:callstack_size[callstackPreviousIndex] callstack:callstacks[callstackPreviousIndex]];
                // Check that in between the beginning and the end of the copy the signal did not fire
                if (!callstack_dirty) {
                    // The copy has been made. We are now fine, let's punt the rest off main-thread.
                    __weak FBAnimationPerformanceTracker *weakSelf = self;
                    dispatch_async(_symbolicationQueue, ^(void) {
                        [weakSelf _reportStackTrace:callstackCopy];
                    });
                }
            }
        }
    }
}

- (void)_update
{
    if (!_tracking) {
        return;
    }
    
    if (_firstUpdate) {
        _firstUpdate = NO;
        _previousFrameTimestamp = _displayLink.timestamp;
        return;
    }
    
    NSTimeInterval currentTimestamp = _displayLink.timestamp;
    NSTimeInterval frameTime = currentTimestamp - _previousFrameTimestamp;
    [self _addFrameTime:frameTime singleFrameTime:_displayLink.duration];
    _previousFrameTimestamp = currentTimestamp;
}

- (void)_reportStackTrace:(FBCallstack *)callstack
{
    static NSString *slide;
    static dispatch_once_t slide_predicate;
    
    dispatch_once(&slide_predicate, ^{
        slide = [NSString stringWithFormat:@"%p", (void *)_dyld_get_image_header(0)];
    });
    
    @autoreleasepool {
        NSMutableString *stack = [NSMutableString string];
        
        for (int j = 2; j < callstack.size; j ++) {
            void *instructionPointer = callstack.callstack[j];
            auto it = _imageNames.lower_bound(instructionPointer);
            
            NSString *imageName = (it != _imageNames.end()) ? it->second : @"???";
            
            [stack appendString:imageName];
            [stack appendString:@":"];
            [stack appendString:[NSString stringWithFormat:@"%p", instructionPointer]];
            [stack appendString:@"|"];
        }
        
        [_delegate reportStackTrace:stack withSlide:slide];
    }
}
@end
