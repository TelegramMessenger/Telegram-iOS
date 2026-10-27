#include "LayerTreePainter.h"

#include <cmath>
#include <variant>
#include <vector>

#include "CoreTextRenderHost.h"
#include "Sources/Render/LayerTree.h"
#include "third-party/twidget/LiteHTML/LHHostSupport.h"

namespace wr::ios {

namespace {

constexpr size_t kMaxSide = 4096;

CGContextRef createBitmap(size_t width, size_t height) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(nullptr, width, height, 8, 0, space,
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(space);
    return context;
}

// One walk of a tree's layers into one LHHostContainer, in paint order. A backdrop's source is the same tree walked
// again up to the backdrop (`stopAt`), into a bitmap of the rect behind it, as LHDocument's backdropLockedForOwner
// draws the document with every later item skipped.
class Walk {
public:
    Walk(const LayerTree& tree, LHHostContainer& host, const PaintItem* stopAt)
        : m_tree(tree), m_host(host), m_container(host.container()), m_stopAt(stopAt) {}

    bool stopped() const { return m_stopped; }

    void layer(const Layer& layer, CGContextRef ctx) {
        for (const auto& entry : layer.entries) {
            if (m_stopped) {
                return;
            }
            if (const PaintItem* item = std::get_if<PaintItem>(&entry)) {
                this->item(*item, ctx);
                continue;
            }
            const Layer& child = *std::get<std::unique_ptr<Layer>>(entry);
            const litehtml::uint_ptr hdc = reinterpret_cast<litehtml::uint_ptr>(ctx);
            switch (child.kind) {
            case Layer::Kind::Root:
                this->layer(child, ctx);
                break;
            case Layer::Kind::Group:
                m_container.begin_group(hdc, child.group);
                this->layer(child, ctx);
                m_container.end_group(hdc);
                break;
            case Layer::Kind::Filter: {
                // The filter's bitmap spans what litehtml's ink hands LHDocument's draw_filtered: the contents grown by
                // the filter's reach (a blur bleeds out by 3 × its radius, a drop shadow by its offset too). The
                // contents alone cut a blurred circle off at its square.
                const float reach = litehtml::filter_reach(child.filter);
                litehtml::filter_paint filter;
                filter.steps = &child.filter;
                filter.box = child.box;
                filter.bounds = child.box;
                if (reach > 0 && child.box.width.value() > 0 && child.box.height.value() > 0) {
                    filter.bounds = litehtml::position(child.box.x - litehtml::pixel_t(reach), child.box.y - litehtml::pixel_t(reach),
                                                       child.box.width + litehtml::pixel_t(2 * reach),
                                                       child.box.height + litehtml::pixel_t(2 * reach));
                }
                filter.owner = &child;
                m_container.draw_filtered(hdc, filter, [&](litehtml::uint_ptr inner) {
                    this->layer(child, reinterpret_cast<CGContextRef>(inner));
                });
                break;
            }
            case Layer::Kind::Isolated:
                m_container.draw_isolated(hdc, child.box, [&](litehtml::uint_ptr inner) {
                    this->layer(child, reinterpret_cast<CGContextRef>(inner));
                });
                break;
            }
        }
    }

private:
    void item(const PaintItem& item, CGContextRef ctx) {
        if (&item == m_stopAt) {
            m_stopped = true;
            return;
        }
        const litehtml::uint_ptr hdc = reinterpret_cast<litehtml::uint_ptr>(ctx);
        switch (item.kind) {
        case PaintItem::Kind::Text: {
            const auto& text = std::get<TextItem>(item.payload);
            if (const auto* font = dynamic_cast<const IOSHostFont*>(text.font.get())) {
                m_container.draw_text(hdc, text.text.c_str(), font->handle, text.color, text.pos);
            }
            break;
        }
        case PaintItem::Kind::ListMarker: {
            const auto& marker = std::get<ListMarkerItem>(item.payload);
            if (marker.image) {
                if (const auto* image = dynamic_cast<const IOSHostImage*>(marker.image->image.get())) {
                    m_host.drawListMarkerImage(ctx, marker.marker, image->image);
                }
                break;
            }
            litehtml::list_marker copy = marker.marker;
            const auto* font = dynamic_cast<const IOSHostFont*>(marker.font.get());
            copy.font = font ? font->handle : 0;
            m_container.draw_list_marker(hdc, copy);
            break;
        }
        case PaintItem::Kind::Image: {
            const auto& image = std::get<ImageItem>(item.payload);
            if (const auto* decoded = dynamic_cast<const IOSHostImage*>(image.image.image.get())) {
                m_host.drawImage(ctx, image.layer, decoded->image, decoded->serial);
            }
            break;
        }
        case PaintItem::Kind::SolidFill: {
            const auto& fill = std::get<FillItem>(item.payload);
            m_container.draw_solid_fill(hdc, fill.layer, fill.color);
            break;
        }
        case PaintItem::Kind::LinearGradient: {
            const auto& g = std::get<LinearGradientItem>(item.payload);
            m_container.draw_linear_gradient(hdc, g.layer, g.gradient);
            break;
        }
        case PaintItem::Kind::RadialGradient: {
            const auto& g = std::get<RadialGradientItem>(item.payload);
            m_container.draw_radial_gradient(hdc, g.layer, g.gradient);
            break;
        }
        case PaintItem::Kind::ConicGradient: {
            const auto& g = std::get<ConicGradientItem>(item.payload);
            m_container.draw_conic_gradient(hdc, g.layer, g.gradient);
            break;
        }
        case PaintItem::Kind::Borders: {
            const auto& b = std::get<BordersItem>(item.payload);
            m_container.draw_borders(hdc, b.borders, b.drawPos, b.root);
            break;
        }
        case PaintItem::Kind::BoxShadow: {
            const auto& s = std::get<BoxShadowItem>(item.payload);
            m_container.draw_box_shadow(hdc, s.box, s.radius, s.shadow);
            break;
        }
        case PaintItem::Kind::Path:
            m_container.draw_path(hdc, std::get<PathItem>(item.payload).path);
            break;
        case PaintItem::Kind::Backdrop: {
            const auto& b = std::get<BackdropItem>(item.payload);
            litehtml::filter_paint filter;
            filter.steps = &b.steps;
            filter.bounds = b.bounds;
            filter.box = b.box;
            filter.radius = b.radius;
            filter.owner = &item;
            m_container.draw_backdrop(hdc, filter);
            break;
        }
        case PaintItem::Kind::SetClip: {
            const auto& clip = std::get<ClipItem>(item.payload);
            m_container.set_clip(clip.pos, clip.radius);
            break;
        }
        case PaintItem::Kind::DelClip:
            m_container.del_clip();
            break;
        case PaintItem::Kind::SuspendClips:
            m_container.suspend_clips();
            break;
        case PaintItem::Kind::ResumeClips:
            m_container.resume_clips();
            break;
        case PaintItem::Kind::SetClipPath:
            m_container.set_clip_path(std::get<ClipPathItem>(item.payload).path);
            break;
        }
    }

    const LayerTree& m_tree;
    LHHostContainer& m_host;
    litehtml::document_container& m_container;
    const PaintItem* m_stopAt;
    bool m_stopped = false;
};

void paintWith(const LayerTree& tree, CGContextRef context, const PaintItem* stopAt, int depth, LHEffectStore* effects);

// The tree's backdrops in paint order.
void collectBackdrops(const Layer& layer, std::vector<const void*>& owners) {
    for (const auto& entry : layer.entries) {
        if (const PaintItem* item = std::get_if<PaintItem>(&entry)) {
            if (item->kind == PaintItem::Kind::Backdrop) {
                owners.push_back(item);
            }
            continue;
        }
        collectBackdrops(*std::get<std::unique_ptr<Layer>>(entry), owners);
    }
}

// The source of the backdrop `owner`: the tree painted up to it, inside `rect`, at the filter target's scales.
CGImageRef backdropSource(const LayerTree& tree, const void* owner, CGRect rect, CGFloat sx, CGFloat sy, bool flipped,
                          int depth) {
    if (depth > 0 || !owner) {
        return nullptr;
    }
    const size_t pw = size_t(std::llround(rect.size.width * sx));
    const size_t ph = size_t(std::llround(rect.size.height * sy));
    if (pw == 0 || ph == 0 || pw * ph > (16u << 20)) {
        return nullptr;
    }
    CGContextRef ctx = createBitmap(pw, ph);
    if (!ctx) {
        return nullptr;
    }
    if (flipped) {
        CGContextTranslateCTM(ctx, 0, ph);
        CGContextScaleCTM(ctx, sx, -sy);
    } else {
        CGContextScaleCTM(ctx, sx, sy);
    }
    CGContextTranslateCTM(ctx, -rect.origin.x, -rect.origin.y);
    CGContextSetAllowsFontSmoothing(ctx, false);
    CGContextSetShouldAntialias(ctx, true);
    paintWith(tree, ctx, static_cast<const PaintItem*>(owner), depth + 1, nullptr);
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return image;
}

// `effects` only for the paint of a tile: a backdrop's source, painted while its backdrop is made, makes its own, so that
// no making waits for another that may be waiting for it.
void paintWith(const LayerTree& tree, CGContextRef context, const PaintItem* stopAt, int depth, LHEffectStore* effects) {
    LHHostContainer host;
    host.setBackdropSource([&tree, depth](const void* owner, CGRect r, CGFloat sx, CGFloat sy, bool flipped) {
        return backdropSource(tree, owner, r, sx, sy, flipped, depth);
    });
    host.setEffectStore(effects);
    std::vector<const void*> backdrops;
    collectBackdrops(tree.root(), backdrops);
    host.allowBackdrops(backdrops);
    CGContextSaveGState(context);
    host.beginPaint(context);
    Walk walk(tree, host, stopAt);
    walk.layer(tree.root(), context);
    host.endPaint();
    CGContextRestoreGState(context);
}

} // namespace

void LayerTreePainter::paint(const LayerTree& tree, CGContextRef context, CGRect rect, CGFloat scale, LHEffectStore* effects) {
    CGContextSaveGState(context);
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
    paintWith(tree, context, nullptr, 0, effects);
    CGContextRestoreGState(context);
}

CGImageRef LayerTreePainter::copyImage(const LayerTree& tree, CGRect rect, CGFloat scale, LHEffectStore* effects) {
    const size_t pw = size_t(std::ceil(rect.size.width * scale));
    const size_t ph = size_t(std::ceil(rect.size.height * scale));
    if (pw == 0 || ph == 0 || pw > kMaxSide || ph > kMaxSide) {
        return nullptr;
    }
    CGContextRef ctx = createBitmap(pw, ph);
    if (!ctx) {
        return nullptr;
    }
    // y down, as LHDocument's copyImage draws: flip, then the rect's origin at the top-left.
    CGContextTranslateCTM(ctx, 0, ph);
    CGContextScaleCTM(ctx, 1, -1);
    CGContextSetAllowsFontSmoothing(ctx, false);
    CGContextSetShouldAntialias(ctx, true);
    LayerTreePainter::paint(tree, ctx, rect, scale, effects);
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return image;
}

} // namespace wr::ios
