#import <Foundation/Foundation.h>

/*
 * This is an example provided by Facebook are for non-commercial testing and
 * evaluation purposes only.
 *
 * Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NON INFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 * AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 *
 * FBAnimationPerformanceTracker
 * -----------------------------------------------------------------------
 *
 * This class provides animation performance tracking functionality.  It basically
 * measures the app's frame rate during an operation, and reports this information.
 *
 * 1) In Foo's designated initializer, construct a tracker object
 *
 * 2) Add calls to -start and -stop in appropriate places, e.g. for a ScrollView
 *
 * - (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
 *   [_apTracker start];
 * }
 *
 * - (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
 * {
 *   if (!scrollView.dragging) {
 *     [_apTracker stop];
 *   }
 * }
 *
 * - (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
 *   if (!decelerate) {
 *     [_apTracker stop];
 *   }
 * }
 *
 * Notes
 * -----
 * [] The tracker operates by creating a CADisplayLink object to measure the frame rate of the display
 * during start/stop interval.
 *
 * [] Calls to -stop that were not preceded by a matching call to -start have no effect.
 *
 * [] 2 calls to -start in a row will trash the data accumulated so far and not log anything.
 *
 *
 * Configuration object for the core tracker
 *
 * ===============================================================================
 * I highly recommend for you to use the standard configuration provided
 * These are essentially here so that the computation of the metric is transparent
 * and you can feel confident in what the numbers mean.
 * ===============================================================================
 */
struct FBAnimationPerformanceTrackerConfig
{
    // Number of frame drop that defines a "small" drop event. By default, 1.
    NSInteger smallDropEventFrameNumber;
    // Number of frame drop that defines a "large" drop event. By default, 4.
    NSInteger largeDropEventFrameNumber;
    // Number of maximum frame drops to which the drop will be trimmed down to. Currently 15.
    NSInteger maxFrameDropAccount;
    
    // If YES, will report stack traces
    BOOL reportStackTraces;
};
typedef struct FBAnimationPerformanceTrackerConfig FBAnimationPerformanceTrackerConfig;


@protocol FBAnimationPerformanceTrackerDelegate <NSObject>

/**
 * Core Metric
 *
 * You are responsible for the aggregation of these metrics (it being on the client or the server). I recommend to implement both
 * to limit the payload you are sending to the server.
 *
 * The final recommended metric being: - SUM(duration) / SUM(smallDropEvent) aka the number of seconds between one frame drop or more
 *                                     - SUM(duration) / SUM(largeDropEvent) aka the number of seconds between four frame drops or more
 *
 * The first metric will tell you how smooth is your scroll view.
 * The second metric will tell you how clowny your scroll view can get.
 *
 * Every time stop is called, this event will fire reporting the performance.
 *
 * NOTE on this metric:
 * - It has been tested at scale on many Facebook apps.
 * - It follows the curves of devices.
 * - You will need about 100K calls for the number to converge.
 * - It is perfectly correlated to X = Percentage of time spent at 60fps. Number of seconds between one frame drop = 1 / ( 1 - Time spent at 60 fps)
 * - We report fraction of drops. 7 frame drop = 1.75 of a large frame drop if a large drop is 4 frame drop.
 *   This is to preserve the correlation mentionned above.
 */
- (void)reportDurationInMS:(NSInteger)duration smallDropEvent:(double)smallDropEvent largeDropEvent:(double)largeDropEvent;

/**
 * Stack traces
 *
 * Dark magic of the animation tracker. In case of a frame drop, this will return a stack trace.
 * This will NOT be reported on the main-thread, but off-main thread to save a few CPU cycles.
 *
 * The slide is constant value that needs to be reported with the stack for processing.
 * This currently only allows for symbolication of your own image.
 *
 * Future work includes symbolicating all modules. I personnaly find it usually
 * good enough to know the name of the module.
 *
 * The stack will have the following format:
 * Foundation:0x123|MyApp:0x234|MyApp:0x345|
 *
 * The slide will have the following format:
 * 0x456
 */
- (void)reportStackTrace:(NSString *)stack withSlide:(NSString *)slide;

@end

@interface FBAnimationPerformanceTracker : NSObject

- (instancetype)initWithConfig:(FBAnimationPerformanceTrackerConfig)config;

+ (FBAnimationPerformanceTrackerConfig)standardConfig;

@property (weak, nonatomic, readwrite) id<FBAnimationPerformanceTrackerDelegate> delegate;

- (void)start;
- (void)stop;

@end
