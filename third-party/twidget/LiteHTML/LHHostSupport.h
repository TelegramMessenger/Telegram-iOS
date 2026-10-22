// What WidgetRuntime's iOS side reuses of LHContainer (M1d plan, Tasks 5 and 6): one LHContainer, owned and driven
// without an LHDocument. Its layout half (fonts, measuring, breaking, text transforms, clip-path containment, image
// decoding) is the iOS RenderHost; its painting half replays a layer tree's items through the same CoreGraphics code
// LHDocument draws with. C++ (textual), so it stays out of the module Swift imports.
#pragma once

#include <litehtml.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>

#include <cstddef>
#include <functional>
#include <memory>
#include <string>
#include <vector>

class LHHostContainer
{
  public:
    LHHostContainer();
    ~LHHostContainer();
    LHHostContainer(const LHHostContainer&)            = delete;
    LHHostContainer& operator=(const LHHostContainer&) = delete;

    // Layout (Task 5). The font handle is LHContainer's: it stays valid after this container is gone, until
    // deleteFont, and any LHHostContainer can measure or draw with it.
    litehtml::uint_ptr                      createFont(const litehtml::font_description& descr, litehtml::font_metrics* metrics);
    static void                             deleteFont(litehtml::uint_ptr font);
    static CTFontRef                        nativeFont(litehtml::uint_ptr font);
    double                                  textWidth(const char* text, litehtml::uint_ptr font);
    // Edit 52: where the painter draws each UTF-16 boundary of `text` (LHContainer::caret_offsets).
    std::vector<float>                      caretOffsets(const char* text, litehtml::uint_ptr font);
    std::shared_ptr<litehtml::text_breaker> createTextBreaker(const std::string& text, litehtml::uint_ptr font);
    void                                    transformText(std::string& text, litehtml::text_transform transform);
    bool                                    pathContains(const litehtml::vector_path& path, float x, float y);
    double                                  defaultFontSize() const;
    const char*                             defaultFontName() const;
    /// Today's image policy (LHContainer's LoadImageFromData): PNG, JPEG, GIF or WebP, at most 4096 px a side and
    /// 16 Mpx, sniffed by ImageIO whatever the type says; SVG through LHCreateSVGImage. At most 24 MiB of bytes, and
    /// nullptr without drawing when the image's raster would take more than maxPixelBytes (4 bytes a pixel: an SVG's
    /// once it is laid out, any other's from its header). A +1 image and its size in CSS px, or nullptr.
    static CGImageRef createImage(const void* bytes, size_t length, bool svg, CGSize* size, size_t maxPixelBytes);

    // Painting (Task 6): the container's own draw calls, through litehtml's interface, with `hdc` the CGContextRef.
    litehtml::document_container& container();
    /// What LHDocument's drawLockedInContext does around a draw: pixel snapping from the CTM, the source-filter
    /// scope and text batching. endPaint flushes the batched text.
    void beginPaint(CGContextRef ctx);
    void endPaint();
    /// draw_image's and draw_list_marker's drawing, for an image the host already decoded (no URL lookup). `identity`
    /// keys the raster cache: unique for the process, never an address the image may leave to another.
    void drawImage(CGContextRef ctx, const litehtml::background_layer& layer, CGImageRef image, uint64_t identity);
    void drawListMarkerImage(CGContextRef ctx, const litehtml::list_marker& marker, CGImageRef image);
    /// draw_backdrop's source: what was painted behind a backdrop (owner: the backdrop's identity), as LHDocument's
    /// backdropLockedForOwner gives it. +1 or nullptr.
    void setBackdropSource(std::function<CGImageRef(const void* owner, CGRect rect, CGFloat sx, CGFloat sy, bool flipped)> source);

  private:
    struct Impl;
    Impl* m_impl;
};
