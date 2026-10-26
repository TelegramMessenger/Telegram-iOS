// The iOS canvas bitmap (V5d plan, Task 2): a premultiplied BGRA CGBitmapContext that runs CanvasOps. Ported from
// twidget's CoreGraphics backend (platform/apple/coregraphics.cpp at e10b2f5: CGBackend::canvas_run, canvas_op,
// canvas_paint and canvas_image), without compositing, shadows and putImageData, which profile 1 never draws.
#pragma once

#include <CoreGraphics/CoreGraphics.h>

#include <atomic>
#include <memory>

#include "Sources/Render/RenderHost.h"

namespace wr::ios {

class IOSCanvasBitmap final : public HostCanvas {
public:
    /// nullptr when CoreGraphics cannot allocate the bitmap.
    static std::unique_ptr<IOSCanvasBitmap> create(int width, int height);
    ~IOSCanvasBitmap() override;
    IOSCanvasBitmap(const IOSCanvasBitmap&) = delete;
    IOSCanvasBitmap& operator=(const IOSCanvasBitmap&) = delete;

    void run(std::span<const canvas::CanvasOp> ops) override;
    /// CGBitmapContextCreateImage, which shares the pixels until the next draw copies them: drawing a canvas onto
    /// itself reads the pixels from before the draw. Not charged to the host's decoded-image total (the canvas
    /// allowance bounds a canvas's bitmap and the one older snapshot a published tree keeps).
    std::shared_ptr<const HostImage> snapshot() override;

private:
    IOSCanvasBitmap(CGContextRef context, int width, int height);
    void op(const canvas::CanvasOp& op);
    void paint(const canvas::CanvasOp& op);

    CGContextRef m_context;
    CGColorSpaceRef m_space;
    int m_width, m_height;
    std::shared_ptr<const HostImage> m_snapshot;
    /// What IOSHostImage counts against: a snapshot holds 0 bytes of it.
    std::shared_ptr<std::atomic<uint64_t>> m_uncounted = std::make_shared<std::atomic<uint64_t>>(0);
};

} // namespace wr::ios
