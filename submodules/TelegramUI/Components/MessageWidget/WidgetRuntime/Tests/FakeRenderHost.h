// The deterministic RenderHost of the host tests (M1c plan, Task 3): litehtml_test::TestContainer's metrics
// (third-party/twidget/tests/test_container.h), so a document laid out through WidgetContainer over it lays out as
// through the test container. It counts every call that matters to a test and every font and image alive.
#pragma once

#include <functional>

#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include "Sources/Render/RenderHost.h"

namespace wr_test {

/// The fake canvas bitmap (V5d plan, Task 2): it draws nothing and logs one line per op, its bounds in canvas px
/// rounded to whole pixels: `fill 16,16 80x60 #cc3333ff`, `stroke … #rrggbbaa w=4` (` dash=<entries>` when dashed), `clear 0,0 10x10`, `text "Ag" 6,18`,
/// `image 20x20 -> 44,26 30x30`, `reset`; a gradient paint is `linear` or `radial`, and `alpha=0.5` and `clips=2`
/// follow when they apply. Its snapshot is a fake image, the same one until the next run.
class FakeCanvas final : public wr::HostCanvas {
public:
    FakeCanvas(int width, int height);
    ~FakeCanvas() override;
    FakeCanvas(const FakeCanvas&) = delete;
    FakeCanvas& operator=(const FakeCanvas&) = delete;
    void run(std::span<const wr::canvas::CanvasOp> ops) override;
    std::shared_ptr<const wr::HostImage> snapshot() override;

    const int width, height;
    std::vector<std::string> log;
    /// The runs so far.
    uint64_t runs = 0;
    /// Every FakeCanvas alive, oldest first.
    static const std::vector<FakeCanvas*>& live();

private:
    std::shared_ptr<const wr::HostImage> m_snapshot;
};

class FakeRenderHost final : public wr::RenderHost {
public:
    /// The MIME type of every decodeImage call, in order.
    std::vector<std::string> decodedMimeTypes;
    /// The image/svg+xml decodes whose bytes were not the 48 px placeholder's (V4 plan, Task 6: none should be).
    size_t foreignSVGs = 0;
    /// The createFont calls so far.
    size_t fontsCreated = 0;
    /// Every font createFont made, with the description it was made for, in order (weak: this log keeps nothing alive).
    struct CreatedFont {
        litehtml::font_description description;
        std::weak_ptr<const wr::HostFont> font;
    };
    std::vector<CreatedFont> createdFonts;
    /// The shape calls so far: one per text item recorded (Task 10b counts what a flush re-captures).
    size_t shapeCalls = 0;
    /// The textWidth calls so far (the layout's measure, which the iOS host caches; canvas text must not use it).
    size_t textWidthCalls = 0;
    /// Called at every textWidth, before it measures (a test that makes the layout take time on the fake clock).
    std::function<void()> onTextWidth;

    /// The HostFont and HostImage objects alive now, made by any FakeRenderHost. Each is self-contained, so it
    /// stays alive (and counted) after the host that made it is gone.
    static size_t liveFonts();
    static size_t liveImages();

    /// Font size `description.size`; ascent 12, descent 4, height 16; x-height 6, ch width 8; sub shift 2, super
    /// shift 4; no space drawing.
    std::shared_ptr<const wr::HostFont> createFont(const litehtml::font_description& description,
                                                   litehtml::font_metrics& metrics) override;
    /// 8 px per UTF-8 byte.
    double textWidth(const wr::HostFont& font, std::string_view utf8) override;
    /// Breaks between code points, never inside one, at 8 px per byte.
    std::shared_ptr<litehtml::text_breaker> createTextBreaker(const wr::HostFont& font, const std::string& utf8) override;
    /// One glyph per byte (the byte's value), each 8 px.
    wr::ShapedText shape(const wr::HostFont& font, std::string_view utf8) override;
    /// 8 px per byte, as textWidth measures; the bytes of one code point all count before its end.
    std::vector<float> caretOffsets(const wr::HostFont& font, std::string_view utf8) override;
    /// ASCII only: upper, lower, or each word's first letter upper.
    void transformText(std::string& utf8, litehtml::text_transform transform) override;
    double defaultFontSize() const override { return 16; }
    std::string defaultFontName() const override { return "sans-serif"; }
    /// A PNG's IHDR size or a GIF's logical screen size, whatever `mimeType` says; nullopt for anything else.
    std::optional<wr::DecodedImage> decodeImage(std::string_view mimeType, std::span<const uint8_t> bytes) override;
    /// Whether (x, y) lies in the bounding box of the path's points, edges included.
    bool pathContains(const litehtml::vector_path& path, double x, double y) override;
    /// A FakeCanvas; nullptr while `refuseCanvases` is set.
    std::unique_ptr<wr::HostCanvas> createCanvas(int width, int height) override;
    bool refuseCanvases = false;
    /// The FakeCanvas objects alive now, made by any FakeRenderHost.
    static size_t liveCanvases() { return FakeCanvas::live().size(); }
};

} // namespace wr_test
