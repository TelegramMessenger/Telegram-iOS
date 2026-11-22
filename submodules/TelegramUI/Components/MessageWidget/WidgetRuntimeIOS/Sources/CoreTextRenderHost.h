// The iOS RenderHost (M1d plan, Task 5): WidgetRuntime's layout questions answered by LHContainer's CoreText and ImageIO
// code (third-party/twidget/LiteHTML/LHHostSupport.h), so a widget lays out as LHDocument laid it out. Its fonts and
// images outlive it: a published layer tree holds them.
#pragma once

#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>

#include <atomic>
#include <memory>

#include "Sources/Render/RenderHost.h"

class LHHostContainer;

namespace wr::ios {

/// LHContainer's font handle (LHHostSupport.h), and the letter spacing its description gave: what shape() and the
/// painter's text draw with.
class IOSHostFont final : public HostFont {
public:
    IOSHostFont(litehtml::uint_ptr handle, double kern) : handle(handle), kern(kern) {}
    ~IOSHostFont() override;
    IOSHostFont(const IOSHostFont&) = delete;
    IOSHostFont& operator=(const IOSHostFont&) = delete;
    CTFontRef font() const;

    const litehtml::uint_ptr handle;
    const double kern;
};

/// A decoded image: the CGImage the painter draws, and a process-unique serial. The raster cache keys a drawing by the
/// serial: it keeps rasters, not images, so a freed image's address can come back holding another one (Task 7 review X1).
/// It holds `bytes` of its host's decoded-image total until it is freed.
class IOSHostImage final : public HostImage {
public:
    IOSHostImage(CGImageRef adopted, std::shared_ptr<std::atomic<uint64_t>> total, uint64_t bytes);
    ~IOSHostImage() override;
    IOSHostImage(const IOSHostImage&) = delete;
    IOSHostImage& operator=(const IOSHostImage&) = delete;

    const CGImageRef image;
    const uint64_t serial;

private:
    const std::shared_ptr<std::atomic<uint64_t>> m_total;
    const uint64_t m_bytes;
};

class CoreTextRenderHost final : public RenderHost {
public:
    CoreTextRenderHost();
    ~CoreTextRenderHost() override;

    std::shared_ptr<const HostFont> createFont(const litehtml::font_description& description,
                                               litehtml::font_metrics& metrics) override;
    double textWidth(const HostFont& font, std::string_view utf8) override;
    std::shared_ptr<litehtml::text_breaker> createTextBreaker(const HostFont& font, const std::string& utf8) override;
    ShapedText shape(const HostFont& font, std::string_view utf8) override;
    /// LHContainer's own placement of the text (twidget edit 52): the simple shaper's or the CTLine's, as it draws.
    std::vector<float> caretOffsets(const HostFont& font, std::string_view utf8) override;
    void transformText(std::string& utf8, litehtml::text_transform transform) override;
    double defaultFontSize() const override;
    std::string defaultFontName() const override;
    std::optional<DecodedImage> decodeImage(std::string_view mimeType, std::span<const uint8_t> bytes) override;
    bool pathContains(const litehtml::vector_path& path, double x, double y) override;
    /// An IOSCanvasBitmap (CanvasBitmap.h).
    std::unique_ptr<HostCanvas> createCanvas(int width, int height) override;

    /// The pixel bytes of the decoded images one session holds at once: today's ImageStore figure
    /// (LHContainer.mm's kMaxDataImageBytes), which bounded the whole process; here it bounds each widget. An image
    /// whose raster would pass what is left is refused before it is drawn.
    static constexpr uint64_t kMaxDecodedImageBytes = uint64_t(24) << 20;

private:
    std::unique_ptr<LHHostContainer> m_container;
    /// The pixel bytes of the images this host decoded that are still alive (a published tree can outlive the host).
    std::shared_ptr<std::atomic<uint64_t>> m_decodedBytes = std::make_shared<std::atomic<uint64_t>>(0);
};

} // namespace wr::ios
