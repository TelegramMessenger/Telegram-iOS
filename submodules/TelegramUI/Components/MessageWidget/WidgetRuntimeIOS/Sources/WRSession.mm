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

// The work budgets (MessageWidgetCore's, the old runtime's values): the parse is ours, under its ceiling; the boot's
// scripts and lifecycle share one budget.
constexpr uint64_t kParseUnits = 400000000;
constexpr uint64_t kBootUnits = 48000000;
constexpr uint64_t kWorkReportUnits = 10000;

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

@interface WRTree () {
@public
    std::shared_ptr<const wr::LayerTree> _tree;
}
- (instancetype)initWithTree:(std::shared_ptr<const wr::LayerTree>)tree;
@end

@interface WRSelectableText ()
- (instancetype)initWithText:(NSString*)text runs:(NSData*)runs carets:(NSData*)carets units:(uint64_t)units;
@end

@implementation WRSelectableText

- (instancetype)initWithText:(NSString*)text runs:(NSData*)runs carets:(NSData*)carets units:(uint64_t)units {
    if ((self = [super init])) {
        _text = [text copy];
        _runs = [runs copy];
        _carets = [carets copy];
        _units = units;
    }
    return self;
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

- (CGImageRef)copyImageOfRect:(CGRect)rect scale:(CGFloat)scale {
    try {
        return wr::ios::LayerTreePainter::copyImage(*_tree, rect, scale);
    } catch (...) {
        return nullptr;
    }
}

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
    uint64_t _latchedUnits;
    uint64_t _parseUnits;
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
        options.memoryLimitBytes = size_t(64) << 20;
        options.maxStackBytes = size_t(1) << 20;
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
        __weak WRSession* weakSelf = self;
        _runtime->setWorkObserver(
            [weakSelf](uint64_t total) {
                WRSession* session = weakSelf;
                WRProductionHost* host = session ? session->_host.get() : nullptr;
                id<WRSessionDelegate> d = host ? host->delegate : nil;
                [d session:session didWork:total];
            },
            kWorkReportUnits);
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
        _latchedUnits = JS_GetWorkUnits(_runtime->jsRuntime());
        _runtime.reset();
    }
}

static WRStopReason stopOf(wr::StopReason reason) {
    switch (reason) {
    case wr::StopReason::None:
        return WRStopReasonNone;
    case wr::StopReason::Budget:
        return WRStopReasonBudget;
    case wr::StopReason::Memory:
        return WRStopReasonMemory;
    case wr::StopReason::Internal:
        return WRStopReasonInternal;
    case wr::StopReason::LayoutQuery:
        return WRStopReasonLayoutQuery;
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
        _latchedUnits = JS_GetWorkUnits(_runtime->jsRuntime());
        // Not dropRuntime: that calls back here.
        _runtime.reset();
    }
}

- (BOOL)bootWithSource:(NSString*)source {
    return [self bootWithSource:source parseUnits:kParseUnits bootUnits:kBootUnits];
}

- (BOOL)bootWithSource:(NSString*)source parseUnits:(uint64_t)parseUnits bootUnits:(uint64_t)bootUnits {
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
        JSRuntime* rt = _runtime->jsRuntime();
        const uint64_t start = JS_GetWorkUnits(rt);
        _runtime->setWorkLimit(start + parseUnits);
        wr::boot(ctx, wr::BootOptions{std::string_view(static_cast<const char*>(utf8.bytes), utf8.length)});
        _parseUnits = JS_GetWorkUnits(rt) - start;
        // The boot's scripts and lifecycle, on one budget, up to the task that makes the document complete (its load
        // and pageshow run in it).
        _runtime->setWorkLimit(JS_GetWorkUnits(rt) + bootUnits);
        wr::EventLoop& loop = wr::EventLoop::of(ctx);
        const wr::Document& document = wr::DOMState::of(ctx).document();
        while (_runtime && _runtime->stopReason() == wr::StopReason::None &&
               document.readiness() != wr::DocumentReadiness::Complete) {
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

- (void)setWorkLimitAfter:(uint64_t)units {
    WR_GUARD(, {
        if (_runtime) {
            _runtime->setWorkLimit(JS_GetWorkUnits(_runtime->jsRuntime()) + units);
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

- (void)setVisible:(BOOL)visible {
    WR_GUARD(, {
        if (_runtime) {
            wr::HostState::of(_runtime->context()).setVisible(_runtime->context(), visible);
            [self noteTree];
        }
    });
}

- (void)pointer:(WRPointerPhase)phase at:(CGPoint)point pointerId:(int32_t)pointerId primary:(BOOL)primary {
    WR_GUARD(, {
        if (_runtime) {
            static const wr::PointerPhase kPhases[] = {wr::PointerPhase::Down, wr::PointerPhase::Move,
                                                       wr::PointerPhase::Up, wr::PointerPhase::Cancel};
            JSContext* ctx = _runtime->context();
            wr::HostState::of(ctx).pointer(ctx, kPhases[std::clamp<NSInteger>(phase, 0, 3)], point.x, point.y,
                                           pointerId, primary);
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
    return (claim.x ? WRGestureAxesHorizontal : 0) | (claim.y ? WRGestureAxesVertical : 0);
}

- (BOOL)pressTakesTaps {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (_failed || !_runtime) {
        return NO;
    }
    return wr::HostState::of(_runtime->context()).pressTakesTaps();
}

- (WRStopReason)stopReason {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (_failed || !_runtime) {
        return _failed ? WRStopReasonInternal : (_latchedStop != WRStopReasonNone ? _latchedStop : WRStopReasonInternal);
    }
    return stopOf(_runtime->stopReason());
}

- (uint64_t)workUnits {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    return _runtime ? JS_GetWorkUnits(_runtime->jsRuntime()) : _latchedUnits;
}

- (CGSize)contentSize {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    return _contentSize;
}

- (BOOL)failed {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    return _failed;
}

- (uint64_t)parseUnits {
    std::lock_guard<std::recursive_mutex> guard(_lock);
    return _parseUnits;
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
        try {
            bool threw = false;
            // A stop inside the script throws Aborted: the stop is latched, and is the widget's, not a failure here.
            result = _runtime->evaluateToString(code.UTF8String ?: "", "evaluateForTesting", &threw);
        } catch (const wr::Aborted&) {
        }
        wr::HostState::of(ctx).flushRender(ctx);
        [self noteTree];
        return result ? text(*result) : nil;
    });
}

- (WRSelectableText*)selectableTextWithBudget:(uint64_t)units visibleHeight:(CGFloat)visibleHeight {
    WR_GUARD(nil, {
        wr::RenderTree* render = [self renderTree];
        if (!render) {
            return nil;
        }
        std::optional<wr::SelectableText> exported;
        try {
            // A read of the published layout: a failure here is the export's, never the widget's (no latch).
            exported = render->selectableText(units, double(visibleHeight));
        } catch (...) {
            return nil;
        }
        if (!exported) {
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
        return [[WRSelectableText alloc] initWithText:text runs:runs carets:carets units:exported->units];
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

- (void)stopForTesting:(WRStopReason)reason {
    WR_GUARD(, {
        if (_runtime) {
            _runtime->stop(reason == WRStopReasonMemory ? wr::StopReason::Memory
                                                        : reason == WRStopReasonBudget ? wr::StopReason::Budget
                                                                                       : wr::StopReason::Internal);
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
