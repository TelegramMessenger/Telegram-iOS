#import "WidgetRuntimeIOS/WRSession.h"

#import <QuartzCore/QuartzCore.h>
#import <Security/Security.h>

#include <algorithm>
#include <cmath>
#include <exception>
#include <memory>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include "CoreTextRenderHost.h"
#include "LayerTreePainter.h"
#include "third-party/twidget/LiteHTML/LHHostSupport.h"
#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/Boot.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Host.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace {

NSString* text(std::string_view s) {
    return [[NSString alloc] initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding] ?: @"";
}

std::string utf8(NSString* s) {
    return std::string(s.UTF8String ?: "");
}

/// SDK v1 §2.3: the palette as given, in key order (the runtime keeps a THEME_KEYS key with a #rrggbb value).
wr::ThemePalette palette(NSDictionary<NSString*, NSString*>* params) {
    wr::ThemePalette out;
    for (NSString* key in [params.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id value = params[key];
        if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
            out.emplace_back(utf8(key), utf8(value));
        }
    }
    return out;
}

/// SDK v1 §2.4: the tokens as given (the runtime checks each against its grammar).
wr::ThemeButtonTokens buttonTokens(NSDictionary<NSString*, id>* tokens) {
    wr::ThemeButtonTokens out;
    const auto string = [&](NSString* key) -> std::optional<std::string> {
        id value = tokens[key];
        return [value isKindOfClass:[NSString class]] ? std::optional<std::string>(utf8(value)) : std::nullopt;
    };
    const auto number = [&](NSString* key) -> std::optional<double> {
        id value = tokens[key];
        return [value isKindOfClass:[NSNumber class]] ? std::optional<double>([value doubleValue]) : std::nullopt;
    };
    out.bg = string(@"bg");
    out.text = string(@"text");
    out.radius = string(@"radius");
    out.font = string(@"font");
    out.padding = string(@"padding");
    out.height = string(@"height");
    out.pressedOpacity = number(@"pressedOpacity");
    out.disabledOpacity = number(@"disabledOpacity");
    return out;
}

/// SDK v1 §2.4 (v0.1.1): the text tokens as given (the runtime checks each and stands the reference value for the rest).
wr::ThemeTextTokens textTokens(NSDictionary<NSString*, id>* tokens) {
    wr::ThemeTextTokens out;
    const auto number = [&](NSString* key) -> std::optional<double> {
        id value = tokens[key];
        return [value isKindOfClass:[NSNumber class]] ? std::optional<double>([value doubleValue]) : std::nullopt;
    };
    out.fontSize = number(@"fontSize");
    out.lineHeight = number(@"lineHeight");
    id padding = tokens[@"padding"];
    if ([padding isKindOfClass:[NSString class]]) {
        out.padding = utf8(padding);
    }
    return out;
}

/// [key, value] pairs, in order; a malformed entry is skipped.
std::vector<std::pair<std::string, std::string>> pairs(NSArray<NSArray<NSString*>*>* entries) {
    std::vector<std::pair<std::string, std::string>> out;
    for (id entry in entries) {
        if ([entry isKindOfClass:[NSArray class]] && [entry count] == 2 && [entry[0] isKindOfClass:[NSString class]] &&
            [entry[1] isKindOfClass:[NSString class]]) {
            out.emplace_back(utf8(entry[0]), utf8(entry[1]));
        }
    }
    return out;
}

} // namespace

/// The production wr::Host: CACurrentMediaTime's milliseconds as the monotonic clock (the `now` steps are given on),
/// the wall clock, and everything else to the session's delegate.
class WRProductionHost final : public wr::Host {
public:
    explicit WRProductionHost(WRSession* session) : m_session(session) {}
    double monotonicNow() override { return CACurrentMediaTime() * 1000; }
    double wallClockNow() override { return [NSDate date].timeIntervalSince1970 * 1000; }
    void log(wr::LogLevel level, std::string_view line) override;
    void diagnostic(std::string_view kind, std::string_view detail) override;
    void bridgeCall(std::string_view method, std::string_view argsJson) override;
    std::vector<std::pair<std::string, std::string>> storageArea(std::string_view area) override {
        return area == "session" ? m_sessionPreload : area == "local" ? m_localPreload : std::vector<std::pair<std::string, std::string>>{};
    }
    void storageCommit(std::string_view area, const std::vector<std::pair<std::string, std::string>>& entries) override;
    std::string intl(std::string_view requestJson) override;
    /// The client's stored areas (setStoragePreloadLocal:session:), read once at the widget's first touch of each.
    std::vector<std::pair<std::string, std::string>> m_localPreload;
    std::vector<std::pair<std::string, std::string>> m_sessionPreload;
    __weak WRSession* m_session;
    __weak id<WRSessionDelegate> delegate;
};

@interface WREffectStore ()
- (LHEffectStore*)store;
@end

@interface WRTree () {
@public
    std::shared_ptr<const wr::LayerTree> _tree;
}
- (instancetype)initWithTree:(std::shared_ptr<const wr::LayerTree>)tree;
@end

@interface WRSelectableText ()
- (instancetype)initWithText:(NSString*)text runs:(NSData*)runs carets:(NSData*)carets;
@end

@implementation WRSelectableText

- (instancetype)initWithText:(NSString*)text runs:(NSData*)runs carets:(NSData*)carets {
    if ((self = [super init])) {
        _text = [text copy];
        _runs = [runs copy];
        _carets = [carets copy];
    }
    return self;
}

@end

@implementation WREffectStore {
    std::unique_ptr<LHEffectStore> _store;
}

- (instancetype)init {
    if ((self = [super init])) {
        _store = std::make_unique<LHEffectStore>();
    }
    return self;
}

- (NSUInteger)made {
    return _store->made();
}

- (LHEffectStore*)store {
    return _store.get();
}

@end

@implementation WRTree

- (instancetype)initWithTree:(std::shared_ptr<const wr::LayerTree>)tree {
    if ((self = [super init])) {
        _tree = std::move(tree);
    }
    return self;
}

- (CGSize)size {
    return CGSizeMake(_tree->width(), _tree->height());
}

- (uint32_t)canvasColor {
    const litehtml::web_color& color = _tree->canvasColor();
    return uint32_t(color.red) << 24 | uint32_t(color.green) << 16 | uint32_t(color.blue) << 8 | uint32_t(color.alpha);
}

- (CGImageRef)copyImageOfRect:(CGRect)rect scale:(CGFloat)scale effects:(WREffectStore*)effects {
    try {
        return wr::ios::LayerTreePainter::copyImage(*_tree, rect, scale, [effects store]);
    } catch (...) {
        return nullptr;
    }
}

@end

@implementation WRWidgetViewer

- (instancetype)initWithId:(int64_t)userId firstName:(NSString*)firstName lastName:(NSString*)lastName username:(NSString*)username isPremium:(BOOL)isPremium {
    if (self = [super init]) {
        _userId = userId;
        _firstName = [firstName copy];
        _lastName = [lastName copy];
        _username = [username copy];
        _isPremium = isPremium;
    }
    return self;
}

@end

@implementation WRCpuLimits

- (instancetype)initWithCpuLimitMs:(double)cpuLimitMs
                        cpuQuotaMs:(double)cpuQuotaMs
                  cpuQuotaWindowMs:(double)cpuQuotaWindowMs
                    cpuKillAfterMs:(double)cpuKillAfterMs
                 mainThreadQuotaMs:(double)mainThreadQuotaMs {
    if (!(self = [super init])) {
        return nil;
    }
    _cpuLimitMs = cpuLimitMs;
    _cpuQuotaMs = cpuQuotaMs;
    _cpuQuotaWindowMs = cpuQuotaWindowMs;
    _cpuKillAfterMs = cpuKillAfterMs;
    _mainThreadQuotaMs = mainThreadQuotaMs;
    return self;
}

+ (instancetype)productLimits {
    const wr::CpuLimits product;
    return [[WRCpuLimits alloc] initWithCpuLimitMs:product.cpuLimitMs
                                        cpuQuotaMs:product.cpuQuotaMs
                                  cpuQuotaWindowMs:product.cpuQuotaWindowMs
                                    cpuKillAfterMs:product.cpuKillAfterMs
                                 mainThreadQuotaMs:product.mainThreadQuotaMs];
}

@end

@interface WRSessionStats ()
@property (nonatomic, readwrite) uint64_t totalOps;
@property (nonatomic, readwrite) uint64_t maxBatchOps;
@property (nonatomic, readwrite) uint64_t layoutQueries;
@property (nonatomic, readwrite) double flushMilliseconds;
@property (nonatomic, readwrite) uint64_t heapBytes;
@property (nonatomic, readwrite) uint64_t nodes;
@property (nonatomic, readwrite) uint64_t throttledSteps;
@property (nonatomic, readwrite) double queryMilliseconds;
@property (nonatomic, readwrite) double jsMilliseconds;
@property (nonatomic, readwrite) double largestStepMilliseconds;
@end

@implementation WRSessionStats
@end

@implementation WRSession {
    std::recursive_mutex _lock;
    std::unique_ptr<WRProductionHost> _host;
    std::unique_ptr<wr::ios::CoreTextRenderHost> _render;
    std::unique_ptr<wr::Runtime> _runtime;
    BOOL _failed;
    BOOL _booted;
    /// Guarded calls running: a delegate calling back from inside one (against the contract) gets the empty default.
    int _depth;
    WRStopReason _latchedStop;
    NSString* _latchedDetail;
    NSUInteger _memoryLimitBytes;
    uint64_t _refusedLoads;
    /// The last tree published, kept after the runtime goes, and the object that hands it out.
    std::shared_ptr<const wr::LayerTree> _lastTree;
    WRTree* _lastTreeObject;
    CGSize _contentSize;
    /// The tree the changed rects were last gathered from, and what has changed since the last changedRects call:
    /// nullopt for everything.
    std::shared_ptr<const wr::LayerTree> _seenTree;
    std::optional<std::vector<CGRect>> _pending;
}

namespace {

struct Depth {
    int& depth;
    explicit Depth(int& d) : depth(d) { depth++; }
    ~Depth() { depth--; }
};

} // namespace

// Every entry: once a C++ failure was caught, nothing runs; a failure caught now latches it. A call from inside another
// (a delegate calling back) runs nothing either: it would change the runtime under the running call's stack.
#define WR_GUARD(fallback, ...)                                                                                   \
    do {                                                                                                           \
        std::lock_guard<std::recursive_mutex> guard(_lock);                                                        \
        if (_failed || _depth > 0) {                                                                               \
            return fallback;                                                                                       \
        }                                                                                                          \
        Depth depth(_depth);                                                                                       \
        try {                                                                                                      \
            __VA_ARGS__                                                                                            \
        } catch (const std::exception& error) {                                                                    \
            NSLog(@"WRSession: %s", error.what());                                                                 \
            [self latchFailure];                                                                                   \
        } catch (...) {                                                                                            \
            NSLog(@"WRSession: an unknown C++ failure");                                                           \
            [self latchFailure];                                                                                   \
        }                                                                                                          \
        return fallback;                                                                                           \
    } while (0)

- (instancetype)initWithWidth:(CGFloat)width dark:(BOOL)dark scale:(CGFloat)scale delegate:(id<WRSessionDelegate>)delegate {
    return [self initWithWidth:width dark:dark themeParams:@{} buttonTokens:@{} textTokens:@{} scale:scale delegate:delegate];
}

- (instancetype)initWithWidth:(CGFloat)width
                         dark:(BOOL)dark
                  themeParams:(NSDictionary<NSString*, NSString*>*)themeParams
                 buttonTokens:(NSDictionary<NSString*, id>*)tokens
                   textTokens:(NSDictionary<NSString*, id>*)text
                        scale:(CGFloat)scale
                     delegate:(id<WRSessionDelegate>)delegate {
    return [self initWithWidth:width dark:dark themeParams:themeParams buttonTokens:tokens textTokens:text scale:scale delegate:delegate
                        policy:WRLimitPolicyStrict];
}

- (instancetype)initWithWidth:(CGFloat)width
                         dark:(BOOL)dark
                  themeParams:(NSDictionary<NSString*, NSString*>*)themeParams
                 buttonTokens:(NSDictionary<NSString*, id>*)tokens
                   textTokens:(NSDictionary<NSString*, id>*)text
                        scale:(CGFloat)scale
                     delegate:(id<WRSessionDelegate>)delegate
                       policy:(WRLimitPolicy)policy {
    return [self initWithWidth:width dark:dark themeParams:themeParams buttonTokens:tokens textTokens:text scale:scale delegate:delegate
                        policy:policy
                     cpuLimits:[WRCpuLimits productLimits]];
}

- (instancetype)initWithWidth:(CGFloat)width
                         dark:(BOOL)dark
                  themeParams:(NSDictionary<NSString*, NSString*>*)themeParams
                 buttonTokens:(NSDictionary<NSString*, id>*)tokens
                   textTokens:(NSDictionary<NSString*, id>*)text
                        scale:(CGFloat)scale
                     delegate:(id<WRSessionDelegate>)delegate
                       policy:(WRLimitPolicy)policy
                    cpuLimits:(WRCpuLimits*)cpuLimits {
    if (!(self = [super init])) {
        return nil;
    }
    try {
        _host = std::make_unique<WRProductionHost>(self);
        _host->delegate = delegate;
        _render = std::make_unique<wr::ios::CoreTextRenderHost>();
        wr::Runtime::Options options;
        options.interfaces = &wr::idl::kTable;
        options.host = _host.get();
        options.limits = policy == WRLimitPolicyCompat ? wr::Limits::compat() : wr::Limits::strict();
        options.memoryLimitBytes = options.limits.memoryBytes;
        _memoryLimitBytes = options.memoryLimitBytes;
        options.maxStackBytes = size_t(1) << 20;
        options.cpu.cpuLimitMs = cpuLimits.cpuLimitMs;
        options.cpu.cpuQuotaMs = cpuLimits.cpuQuotaMs;
        options.cpu.cpuQuotaWindowMs = cpuLimits.cpuQuotaWindowMs;
        options.cpu.cpuKillAfterMs = cpuLimits.cpuKillAfterMs;
        options.cpu.mainThreadQuotaMs = cpuLimits.mainThreadQuotaMs;
        uint64_t seed = 1;
        if (SecRandomCopyBytes(kSecRandomDefault, sizeof(seed), &seed) != errSecSuccess) {
            seed = uint64_t(CACurrentMediaTime() * 1e6);
        }
        options.randomSeed = seed;
        _runtime = wr::Runtime::create(options);
        JSContext* ctx = _runtime->context();
        wr::installDOM(ctx, wr::Document::createHTML(ctx));
        // TelegramWidget.theme reads the host's theme, the scheme the render tree folds into the CSS its own.
        wr::installHost(ctx).setInitialTheme(dark ? wr::Theme::Dark : wr::Theme::Light, palette(themeParams), buttonTokens(tokens),
                                             textTokens(text));
        wr::RenderOptions renderOptions;
        renderOptions.width = width;
        renderOptions.theme = dark ? wr::Theme::Dark : wr::Theme::Light;
        renderOptions.pixelSnapScale = scale;
        wr::installRender(ctx, *_render, renderOptions);
    } catch (...) {
        _runtime.reset();
        return nil;
    }
    return self;
}

- (void)latchFailure {
    _failed = YES;
    _latchedStop = WRStopReasonInternal;
    [self dropRuntime];
}

// Drops the runtime and keeps its last tree. The runtime goes before the host it was given. noteTree drops it itself on
// a memory stop; a failure gathering the rects only makes them everything.
- (void)dropRuntime {
    if (!_runtime) {
        return;
    }
    try {
        [self noteTree];
    } catch (...) {
        _pending.reset();
    }
    if (_runtime) {
        _latchedDetail = detailOf(*_runtime);
        _runtime.reset();
    }
}

static NSString* _Nullable detailOf(const wr::Runtime& runtime) {
    // The stops in upstream's words (Limit, Cpu, LayoutQuery) carry their reason; the others none.
    if (runtime.stopReason() == wr::StopReason::None || runtime.stopDetail().empty()) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:runtime.stopDetail().data() length:runtime.stopDetail().size() encoding:NSUTF8StringEncoding];
}

static WRStopReason stopOf(wr::StopReason reason) {
    switch (reason) {
    case wr::StopReason::None:
        return WRStopReasonNone;
    case wr::StopReason::Memory:
        return WRStopReasonMemory;
    case wr::StopReason::Internal:
        return WRStopReasonInternal;
    case wr::StopReason::LayoutQuery:
        return WRStopReasonLayoutQuery;
    case wr::StopReason::Limit:
        return WRStopReasonLimit;
    case wr::StopReason::Cpu:
        return WRStopReasonCpu;
    }
    return WRStopReasonInternal;
}

static WRStepResult stepOf(wr::StepResult result) {
    switch (result) {
    case wr::StepResult::Ran:
        return WRStepResultRan;
    case wr::StepResult::Idle:
        return WRStepResultIdle;
    case wr::StepResult::Stopped:
        return WRStepResultStopped;
    case wr::StepResult::Deferred:
        return WRStepResultDeferred;
    }
    return WRStepResultStopped;
}

- (wr::RenderTree*)renderTree {
    return _runtime ? wr::HostState::of(_runtime->context()).render() : nullptr;
}

// After anything that may have published: gathers the changed rects since the tree last seen, and keeps the tree. A
// memory stop is fatal: the runtime goes now (spec §13 M1d), keeping that tree. It takes the union of every publish
// since the last time (RenderTree::takeChangedRects): a layout query (flushForQuery) publishes mid-step, before the
// step's own flush (V3 plan, Task 3).
- (void)noteTree {
    wr::RenderTree* render = [self renderTree];
    if (!render) {
        return;
    }
    std::shared_ptr<const wr::LayerTree> tree = render->layerTree();
    if (tree && tree != _seenTree) {
        // The size the header reports is the content's, which the tree's (the layout width) does not show.
        CGSize size = _contentSize;
        if (std::optional<wr::ContentSize> content = render->contentSize()) {
            size = CGSizeMake(content->width, content->height);
        }
        const bool resized = !_seenTree || _seenTree->width() != tree->width() || _seenTree->height() != tree->height() ||
                             !CGSizeEqualToSize(size, _contentSize);
        const std::optional<std::vector<litehtml::position>> rects = render->takeChangedRects();
        if (resized || !rects) {
            _pending.reset();
        } else if (_pending) {
            for (const litehtml::position& r : *rects) {
                _pending->push_back(CGRectMake(r.x.value(), r.y.value(), r.width.value(), r.height.value()));
            }
        }
        _seenTree = tree;
        _lastTree = tree;
        _lastTreeObject = [[WRTree alloc] initWithTree:tree];
        _contentSize = size;
    }
    _refusedLoads = render->refusedLoads();
    if (_runtime->stopReason() == wr::StopReason::Memory && !_failed) {
        _latchedStop = WRStopReasonMemory;
        // Not dropRuntime: that calls back here.
        _runtime.reset();
    }
}

- (BOOL)bootWithSource:(NSString*)source {
    WR_GUARD(NO, {
        if (!_runtime || _booted) {
            return NO;
        }
        _booted = YES;
        NSData* utf8 = [source dataUsingEncoding:NSUTF8StringEncoding];
        if (!utf8) {
            return NO;
        }
        JSContext* ctx = _runtime->context();
        wr::boot(ctx, wr::BootOptions{std::string_view(static_cast<const char*>(utf8.bytes), utf8.length)});
        // The boot's scripts and lifecycle, each task on a slice of its own, up to the task that makes the document
        // complete (its load and pageshow run in it), and one slice of CPU in all, as a core drain: a chain of
        // follow-ups that doubles at every script runs before the next one (the fix wave's review I-A). What is left
        // runs on the core's wakes; the boot has started once its parsed markup is published.
        wr::EventLoop& loop = wr::EventLoop::of(ctx);
        const wr::Document& document = wr::DOMState::of(ctx).document();
        const double cpuStart = loop.cpuMsTotal();
        while (_runtime && _runtime->stopReason() == wr::StopReason::None &&
               document.readiness() != wr::DocumentReadiness::Complete &&
               loop.cpuMsTotal() - cpuStart < _runtime->cpuLimits().cpuLimitMs) {
            if (loop.runNextTask(_host->monotonicNow()) != wr::StepResult::Ran) {
                break;
            }
        }
        [self noteTree];
        // Started when its parsed markup was published: a stop before that leaves nothing to show.
        return _lastTree != nullptr;
    });
}

- (WRStepResult)runNextTaskAt:(double)nowMs {
    WR_GUARD(WRStepResultStopped, {
        if (!_runtime) {
            return WRStepResultStopped;
        }
        WRStepResult result = stepOf(wr::EventLoop::of(_runtime->context()).runNextTask(nowMs));
        [self noteTree];
        return _runtime ? result : WRStepResultStopped;
    });
}

- (BOOL)wantsAnimationFrame {
    WR_GUARD(NO, { return _runtime && wr::EventLoop::of(_runtime->context()).wantsAnimationFrame(); });
}

- (WRStepResult)runAnimationFrameAt:(double)nowMs {
    WR_GUARD(WRStepResultStopped, {
        if (!_runtime) {
            return WRStepResultStopped;
        }
        WRStepResult result = stepOf(wr::EventLoop::of(_runtime->context()).runAnimationFrame(nowMs));
        [self noteTree];
        return _runtime ? result : WRStepResultStopped;
    });
}

- (BOOL)hasRunnableTaskAt:(double)nowMs {
    WR_GUARD(NO, { return _runtime && wr::EventLoop::of(_runtime->context()).hasRunnableTask(nowMs); });
}

- (NSNumber*)nextTimerDeadline {
    WR_GUARD(nil, {
        if (!_runtime) {
            return nil;
        }
        std::optional<double> deadline = wr::EventLoop::of(_runtime->context()).nextTimerDeadline();
        return deadline ? @(*deadline) : nil;
    });
}

- (double)bootCpuMilliseconds {
    WR_GUARD(0, {
        if (!_runtime) {
            return 0;
        }
        return wr::EventLoop::of(_runtime->context()).bootLinkCpuMsTotal();
    });
}

- (double)stepCpuMilliseconds {
    WR_GUARD(0, {
        if (!_runtime) {
            return 0;
        }
        return wr::EventLoop::of(_runtime->context()).cpuMsTotal();
    });
}

- (void)setCpuClockForTesting:(double (^)(void))cpu wall:(double (^)(void))wall {
    WR_GUARD(, {
        if (_runtime) {
            _runtime->setCpuClock(wr::CpuClock{[cpu] { return cpu(); }, [wall] { return wall(); }, {}});
        }
    });
}

- (void)setWidth:(CGFloat)width {
    WR_GUARD(, {
        if ([self renderTree]) {
            JSContext* ctx = _runtime->context();
            // Also queues the rendering update's task (media changes, observers), which the host's drain runs.
            wr::HostState::of(ctx).setWidth(ctx, width);
            wr::HostState::of(ctx).flushRender(ctx);
            [self noteTree];
        }
    });
}

- (void)setDark:(BOOL)dark {
    WR_GUARD(, {
        if (_runtime) {
            JSContext* ctx = _runtime->context();
            wr::HostState::of(ctx).themeChanged(ctx, dark ? wr::Theme::Dark : wr::Theme::Light);
            wr::HostState::of(ctx).flushRender(ctx);
            [self noteTree];
        }
    });
}

- (void)setReducedMotion:(BOOL)reduced {
    WR_GUARD(, {
        if (_runtime) {
            JSContext* ctx = _runtime->context();
            if (!_booted) {
                // The first build's option: nothing is built yet to flush, nor listening to report to.
                if (wr::RenderTree* render = wr::HostState::of(ctx).render()) {
                    render->setReducedMotion(ctx, reduced);
                }
            } else {
                wr::HostState::of(ctx).setReducedMotion(ctx, reduced);
                wr::HostState::of(ctx).flushRender(ctx);
                [self noteTree];
            }
        }
    });
}

- (void)setDark:(BOOL)dark
     themeParams:(NSDictionary<NSString*, NSString*>*)themeParams
    buttonTokens:(NSDictionary<NSString*, id>*)tokens
      textTokens:(NSDictionary<NSString*, id>*)text {
    WR_GUARD(, {
        if (_runtime) {
            JSContext* ctx = _runtime->context();
            wr::HostState::of(ctx).setTheme(ctx, dark ? wr::Theme::Dark : wr::Theme::Light, palette(themeParams), buttonTokens(tokens),
                                            textTokens(text));
            wr::HostState::of(ctx).flushRender(ctx);
            [self noteTree];
        }
    });
}

- (void)setStoragePreloadLocal:(NSArray<NSArray<NSString*>*>*)local session:(NSArray<NSArray<NSString*>*>*)session {
    if (_host) {
        _host->m_localPreload = pairs(local);
        _host->m_sessionPreload = pairs(session);
    }
}

- (void)setLocale:(NSString*)locale {
    WR_GUARD(, {
        if (_runtime) {
            wr::HostState::of(_runtime->context()).setLocale(locale.UTF8String ?: "");
        }
    });
}

- (void)setContextCopy:(BOOL)isCopy canQuery:(BOOL)canQuery backgroundQuery:(BOOL)backgroundQuery chatType:(NSString*)chatType viewer:(WRWidgetViewer*)viewer preview:(BOOL)preview wallet:(BOOL)wallet {
    WR_GUARD(, {
        if (_runtime) {
            twidget::WidgetContext context;
            context.isCopy = isCopy;
            context.canQuery = canQuery;
            context.backgroundQuery = backgroundQuery;
            context.chatType = chatType.UTF8String ?: "";
            context.preview = preview;
            context.wallet = wallet;
            if (viewer) {
                twidget::WidgetViewer checked;
                checked.id = viewer.userId;
                if (viewer.firstName) {
                    checked.firstName = std::string(viewer.firstName.UTF8String ?: "");
                }
                if (viewer.lastName) {
                    checked.lastName = std::string(viewer.lastName.UTF8String ?: "");
                }
                if (viewer.username) {
                    checked.username = std::string(viewer.username.UTF8String ?: "");
                }
                checked.isPremium = viewer.isPremium;
                context.viewer = checked;
            }
            JSContext* ctx = _runtime->context();
            wr::HostState::of(ctx).setContext(ctx, context);
        }
    });
}

/// The server's bytes as the policy reads them (it decides what is text); none for nil.
static std::optional<std::string> bytesOf(NSData* data) {
    if (!data) {
        return std::nullopt;
    }
    return std::string(static_cast<const char*>(data.bytes), data.length);
}

- (void)setChatData:(NSData*)chatData publicData:(NSData*)publicData {
    WR_GUARD(, {
        if (_runtime) {
            twidget::WidgetData data;
            data.chatData = bytesOf(chatData);
            data.publicData = bytesOf(publicData);
            JSContext* ctx = _runtime->context();
            if (_booted) {
                wr::HostState::of(ctx).setData(ctx, data);
                // Queuing the task can latch a memory stop, which drops the runtime as a step's does.
                [self noteTree];
            } else {
                wr::HostState::of(ctx).setInitialData(ctx, data);
            }
        }
    });
}

- (void)setContentSafeAreaTop:(double)top right:(double)right bottom:(double)bottom left:(double)left cornerLeft:(double)cornerLeft cornerRight:(double)cornerRight {
    WR_GUARD(, {
        if (_runtime) {
            wr::ContentSafeArea area;
            area.top = top;
            area.right = right;
            area.bottom = bottom;
            area.left = left;
            area.cornerLeft = cornerLeft;
            area.cornerRight = cornerRight;
            JSContext* ctx = _runtime->context();
            if (_booted) {
                wr::HostState::of(ctx).setContentSafeArea(ctx, area);
                // The layout changed at the call, and queuing the task can latch a memory stop.
                [self noteTree];
            } else {
                wr::HostState::of(ctx).setInitialContentSafeArea(ctx, area);
            }
        }
    });
}

- (void)completeRequest:(int64_t)requestId result:(NSData*)result failure:(WRRequestFailure)failure {
    WR_GUARD(, {
        if (_runtime) {
            twidget::WidgetRequestOutcome outcome;
            switch (failure) {
            case WRRequestFailureNone:
                outcome.failure = twidget::WidgetRequestFailure::None;
                outcome.answer.result = bytesOf(result);
                break;
            case WRRequestFailureTimeout:
                outcome.failure = twidget::WidgetRequestFailure::Timeout;
                break;
            case WRRequestFailureRateLimited:
                outcome.failure = twidget::WidgetRequestFailure::RateLimited;
                break;
            case WRRequestFailureFailed:
                outcome.failure = twidget::WidgetRequestFailure::Failed;
                break;
            case WRRequestFailureRejected:
                outcome.failure = twidget::WidgetRequestFailure::Rejected;
                break;
            case WRRequestFailureBadRequest:
                outcome.failure = twidget::WidgetRequestFailure::BadRequest;
                break;
            }
            JSContext* ctx = _runtime->context();
            wr::HostState::of(ctx).completeRequest(ctx, requestId, outcome);
            [self noteTree];
        }
    });
}

- (void)setVisible:(BOOL)visible {
    WR_GUARD(, {
        if (_runtime) {
            wr::HostState::of(_runtime->context()).setVisible(_runtime->context(), visible);
            [self noteTree];
        }
    });
}

- (void)pointer:(WRPointerPhase)phase at:(CGPoint)point pointerId:(int32_t)pointerId primary:(BOOL)primary {
    [self pointer:phase at:point pointerId:pointerId primary:primary mouse:NO button:0];
}

- (void)pointer:(WRPointerPhase)phase at:(CGPoint)point pointerId:(int32_t)pointerId primary:(BOOL)primary mouse:(BOOL)mouse button:(NSInteger)button {
    WR_GUARD(, {
        if (_runtime) {
            static const wr::PointerPhase kPhases[] = {wr::PointerPhase::Down, wr::PointerPhase::Move,
                                                       wr::PointerPhase::Up, wr::PointerPhase::Cancel,
                                                       wr::PointerPhase::Retract};
            JSContext* ctx = _runtime->context();
            wr::HostState::of(ctx).pointer(ctx, kPhases[std::clamp<NSInteger>(phase, 0, 4)], point.x, point.y,
                                           pointerId, primary, mouse ? twidget::PointerKind::Mouse : twidget::PointerKind::Touch,
                                           int16_t(std::clamp<NSInteger>(button, 0, 4)));
            // Queuing the task can latch a memory stop, which drops the runtime as a step's does.
            [self noteTree];
        }
    });
}

- (WRGestureAxes)gestureClaim {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (_failed || !_runtime) {
        return 0;
    }
    const wr::GestureClaim claim = wr::HostState::of(_runtime->context()).gestureClaim();
    return (claim.x ? WRGestureAxesHorizontal : 0) | (claim.y ? WRGestureAxesVertical : 0) | (claim.hold ? WRGestureAxesHold : 0);
}

- (BOOL)pressDownPending {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (_failed || !_runtime) {
        return NO;
    }
    return wr::HostState::of(_runtime->context()).pressDownPending();
}

- (BOOL)pressTakesTaps {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (_failed || !_runtime) {
        return NO;
    }
    return wr::HostState::of(_runtime->context()).pressTakesTaps();
}

- (WRResizeAnchor)resizeAnchor {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (_failed || !_runtime) {
        return WRResizeAnchorTop;
    }
    return wr::HostState::of(_runtime->context()).resizeAnchor() == wr::ResizeAnchor::Bottom ? WRResizeAnchorBottom : WRResizeAnchorTop;
}

- (WRStopReason)stopReason {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (_failed || !_runtime) {
        return _failed ? WRStopReasonInternal : (_latchedStop != WRStopReasonNone ? _latchedStop : WRStopReasonInternal);
    }
    return stopOf(_runtime->stopReason());
}

- (NSUInteger)memoryLimitBytes {
    return _memoryLimitBytes;
}

- (WRSessionStats*)stats {
    WR_GUARD(nil, {
        if (!_runtime) {
            return nil;
        }
        WRSessionStats* stats = [WRSessionStats new];
        stats.totalOps = _runtime->totalOps();
        stats.maxBatchOps = _runtime->maxBatchOps();
        stats.layoutQueries = _runtime->layoutQueries();
        stats.flushMilliseconds = _runtime->flushMilliseconds();
        JSMemoryUsage usage;
        JS_ComputeMemoryUsage(_runtime->jsRuntime(), &usage);
        stats.heapBytes = uint64_t(std::max<int64_t>(0, usage.malloc_size));
        // Statistics only: a walk the widget is never charged for.
        wr::Document& document = wr::DOMState::of(_runtime->context()).document();
        uint64_t nodes = 1;
        for (wr::Node* n = document.firstChildNode(); n; n = n->nextInTreeOrder(&document)) {
            nodes++;
        }
        stats.nodes = nodes;
        wr::EventLoop& loop = wr::EventLoop::of(_runtime->context());
        stats.throttledSteps = loop.throttledSteps();
        stats.queryMilliseconds = loop.queryMsTotal();
        stats.jsMilliseconds = loop.jsMsTotal();
        stats.largestStepMilliseconds = loop.largestStepMs();
        return stats;
    });
}

- (NSString*)stopDetail {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (_failed || !_runtime) {
        return _failed ? nil : _latchedDetail;
    }
    return detailOf(*_runtime);
}

- (CGSize)contentSize {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    return _contentSize;
}

- (BOOL)failed {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    return _failed;
}

- (uint64_t)refusedLoads {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    return _refusedLoads;
}

- (WRTree*)tree {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    return _lastTreeObject;
}

- (NSArray<NSValue*>*)changedRects {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (!_pending) {
        _pending.emplace();
        return nil;
    }
    // The tree's extent: the layout width, which a block reaches whatever its content's own width (contentSize's).
    const CGFloat width = std::max<CGFloat>(_contentSize.width, _lastTree ? _lastTree->width() : 0);
    const CGFloat height = std::max<CGFloat>(_contentSize.height, _lastTree ? _lastTree->height() : 0);
    const CGRect content = CGRectMake(0, 0, width, height);
    NSMutableArray<NSValue*>* out = [NSMutableArray arrayWithCapacity:_pending->size()];
    for (const CGRect& rect : *_pending) {
        // Unclipped by the runtime (an SVG can report far outside), and without glyph overhang: pad, then clip.
        CGRect clipped = CGRectIntersection(CGRectInset(rect, -2, -2), content);
        if (!CGRectIsNull(clipped) && !CGRectIsEmpty(clipped)) {
            [out addObject:[NSValue valueWithBytes:&clipped objCType:@encode(CGRect)]];
        }
    }
    _pending->clear();
    return out;
}

- (void)teardown {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (_depth > 0) {
        // From a delegate, inside a call: the runtime is on the stack.
        return;
    }
    if (_runtime) {
        _latchedStop = stopOf(_runtime->stopReason());
        if (_latchedStop == WRStopReasonNone) {
            _latchedStop = WRStopReasonInternal;
        }
    }
    [self dropRuntime];
}

- (NSString*)evaluateForTesting:(NSString*)code {
    WR_GUARD(nil, {
        if (!_runtime) {
            return nil;
        }
        JSContext* ctx = _runtime->context();
        JS_UpdateStackTop(_runtime->jsRuntime());
        std::optional<std::string> result;
        std::string source = code.UTF8String ?: "";
        // One event-kind step: the script runs on its CPU slice, as the widget's own events do.
        wr::EventLoop::of(ctx).runNow(wr::TaskKind::Event, _host->monotonicNow(), [&] {
            try {
                bool threw = false;
                // A stop inside the script throws Aborted: the stop is latched, and is the widget's, not a failure here.
                result = _runtime->evaluateToString(source, "evaluateForTesting", &threw);
            } catch (const wr::Aborted&) {
            }
            wr::HostState::of(ctx).flushRender(ctx);
        });
        [self noteTree];
        return result ? text(*result) : nil;
    });
}

- (WRSelectableText*)selectableTextWithVisibleHeight:(CGFloat)visibleHeight {
    WR_GUARD(nil, {
        wr::RenderTree* render = [self renderTree];
        if (!render) {
            return nil;
        }
        std::optional<wr::SelectableText> exported;
        try {
            // A read of the published layout: a failure here is the export's, never the widget's (no latch).
            exported = render->selectableText(double(visibleHeight));
        } catch (...) {
            return nil;
        }
        NSMutableData* runs = [NSMutableData dataWithLength:exported->runs.size() * sizeof(WRSelectableRun)];
        NSMutableData* carets = [NSMutableData data];
        WRSelectableRun* out = static_cast<WRSelectableRun*>(runs.mutableBytes);
        uint32_t caretIndex = 0;
        for (const wr::SelectableRun& run : exported->runs) {
            const double* t = run.transform;
            *out++ = WRSelectableRun{run.start, run.length, CGRectMake(run.box.x, run.box.y, run.box.width, run.box.height),
                                     CGAffineTransformMake(t[0], t[1], t[2], t[3], t[4], t[5]), run.node, run.nodeOffset,
                                     caretIndex};
            [carets appendBytes:run.carets.data() length:run.carets.size() * sizeof(float)];
            caretIndex += uint32_t(run.carets.size());
        }
        NSString* text = [[NSString alloc] initWithCharacters:reinterpret_cast<const unichar*>(exported->text.data())
                                                       length:exported->text.size()];
        return [[WRSelectableText alloc] initWithText:text runs:runs carets:carets];
    });
}

- (NSString*)documentElementAttribute:(NSString*)name {
    WR_GUARD(nil, {
        if (!_runtime) {
            return nil;
        }
        JSContext* ctx = _runtime->context();
        JS_UpdateStackTop(_runtime->jsRuntime());
        wr::Element* element = wr::DOMState::of(ctx).document().documentElementNode();
        if (!element) {
            return nil;
        }
        std::optional<wr::String> value = element->getAttribute(ctx, wr::String::fromUTF8(ctx, name.UTF8String ?: ""));
        return value ? text(value->utf8()) : nil;
    });
}

- (CGRect)borderBoxForTesting:(NSString*)selector {
    WR_GUARD(CGRectNull, {
        wr::RenderTree* render = [self renderTree];
        if (!render) {
            return CGRectNull;
        }
        JSContext* ctx = _runtime->context();
        JS_UpdateStackTop(_runtime->jsRuntime());
        wr::HostState::of(ctx).flushRender(ctx);
        [self noteTree];
        if (!_runtime) {
            return CGRectNull;
        }
        wr::Element* element = nullptr;
        try {
            element = wr::DOMState::of(ctx).document().querySelector(ctx, wr::String::fromUTF8(ctx, selector.UTF8String ?: ""));
        } catch (const wr::DOMError&) {
            // A selector that does not parse (its SyntaxError, which the bindings would have thrown to script).
            return CGRectNull;
        } catch (const wr::Aborted&) {
            return CGRectNull;
        }
        if (!element) {
            return CGRectNull;
        }
        std::optional<wr::RenderBox> box = render->borderBox(*element);
        return box ? CGRectMake(box->x, box->y, box->width, box->height) : CGRectNull;
    });
}

- (void)stopForTestingWithLimit:(NSString*)detail {
    WR_GUARD(, {
        if (_runtime) {
            _runtime->stopForLimit(std::string(detail.UTF8String ?: ""));
        }
    });
}

- (void)stopForTesting:(WRStopReason)reason {
    WR_GUARD(, {
        if (_runtime) {
            _runtime->stop(reason == WRStopReasonMemory ? wr::StopReason::Memory : wr::StopReason::Internal);
        }
    });
}

- (void)throwForTesting {
    WR_GUARD(, { throw std::runtime_error("forced"); });
}

- (void)dealloc {
    _runtime.reset();
}

@end

void WRProductionHost::log(wr::LogLevel level, std::string_view line) {
    WRSession* session = m_session;
    [delegate session:session log:NSInteger(level) text:text(line)];
}

void WRProductionHost::diagnostic(std::string_view kind, std::string_view detail) {
    WRSession* session = m_session;
    [delegate session:session diagnostic:text(kind) detail:text(detail)];
}

void WRProductionHost::bridgeCall(std::string_view method, std::string_view argsJson) {
    WRSession* session = m_session;
    [delegate session:session bridge:text(method) args:text(argsJson)];
}

std::string WRProductionHost::intl(std::string_view requestJson) {
    WRSession* session = m_session;
    id<WRSessionDelegate> d = delegate;
    if (![d respondsToSelector:@selector(session:intl:)]) {
        return {};
    }
    // By length: a list item's U+0000 is in the answer too.
    NSData* answer = [[d session:session intl:text(requestJson)] dataUsingEncoding:NSUTF8StringEncoding];
    return answer ? std::string(static_cast<const char*>(answer.bytes), answer.length) : std::string();
}

void WRProductionHost::storageCommit(std::string_view area, const std::vector<std::pair<std::string, std::string>>& entries) {
    WRSession* session = m_session;
    id<WRSessionDelegate> d = delegate;
    if (![d respondsToSelector:@selector(session:storageCommit:entries:)]) {
        return;
    }
    NSMutableArray<NSArray<NSString*>*>* list = [NSMutableArray arrayWithCapacity:entries.size()];
    for (const auto& [key, value] : entries) {
        [list addObject:@[ text(key), text(value) ]];
    }
    [d session:session storageCommit:text(area) entries:list];
}
