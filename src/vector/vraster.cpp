/* 
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "vraster.h"
#include <cstring>
#include <memory>
#include "v_ft_raster.h"
#include "v_ft_stroker.h"
#include "vdebug.h"
#include "vmatrix.h"
#include "vpath.h"
#include "vrle.h"
#include "config.h"

V_BEGIN_NAMESPACE

template<typename T>
class dyn_array
{
public:
    dyn_array(size_t size):mCapacity(size),mData(std::make_unique<T[]>(mCapacity)){}
    void reserve(size_t size)
    {
        if (mCapacity > size) return;
        mCapacity = size;
        mData = std::make_unique<T[]>(mCapacity);
    }
    T* data() const {return mData.get();}

private:
    size_t                 mCapacity{0};
    std::unique_ptr<T[]>   mData{nullptr};
};

struct FTOutline {
public:
    void reset();
    void grow(size_t, size_t);
    void convert(const VPath &path);
    void convert(CapStyle, JoinStyle, float, float);
    void moveTo(const VPointF &pt);
    void lineTo(const VPointF &pt);
    void cubicTo(const VPointF &ctr1, const VPointF &ctr2, const VPointF end);
    void close();
    void end();
    void transform(const VMatrix &m);
    SW_FT_Outline          ft;
    bool                   closed{false};
    SW_FT_Stroker_LineCap  ftCap;
    SW_FT_Stroker_LineJoin ftJoin;
    SW_FT_Fixed            ftWidth;
    SW_FT_Fixed            ftMeterLimit;
    dyn_array<SW_FT_Vector> mPointMemory{100};
    dyn_array<char>         mTagMemory{100};
    dyn_array<short>        mContourMemory{10};
    dyn_array<char>         mContourFlagMemory{10};
};

void FTOutline::reset()
{
    ft.n_points = ft.n_contours = 0;
    ft.flags = 0x0;
}

void FTOutline::grow(size_t points, size_t segments)
{
    reset();
    mPointMemory.reserve(points + segments);
    mTagMemory.reserve(points + segments);
    mContourMemory.reserve(segments);
    mContourFlagMemory.reserve(segments);

    ft.points = mPointMemory.data();
    ft.tags = mTagMemory.data();
    ft.contours = mContourMemory.data();
    ft.contours_flag = mContourFlagMemory.data();
}

void FTOutline::convert(const VPath &path)
{
    const std::vector<VPath::Element> &elements = path.elements();
    const std::vector<VPointF> &       points = path.points();

    grow(points.size(), path.segments());

    size_t index = 0;
    for (auto element : elements) {
        switch (element) {
        case VPath::Element::MoveTo:
            moveTo(points[index]);
            index++;
            break;
        case VPath::Element::LineTo:
            lineTo(points[index]);
            index++;
            break;
        case VPath::Element::CubicTo:
            cubicTo(points[index], points[index + 1], points[index + 2]);
            index = index + 3;
            break;
        case VPath::Element::Close:
            close();
            break;
        default:
            break;
        }
    }
    end();
}

void FTOutline::convert(CapStyle cap, JoinStyle join, float width,
                        float meterLimit)
{
    // map strokeWidth to freetype. It uses as the radius of the pen not the
    // diameter
    width = width / 2.0;
    // convert to freetype co-ordinate
    // IMP: stroker takes radius in 26.6 co-ordinate
    ftWidth = SW_FT_Fixed(width * (1 << 6));
    // IMP: stroker takes meterlimit in 16.16 co-ordinate
    ftMeterLimit = SW_FT_Fixed(meterLimit * (1 << 16));

    // map to freetype capstyle
    switch (cap) {
    case CapStyle::Square:
        ftCap = SW_FT_STROKER_LINECAP_SQUARE;
        break;
    case CapStyle::Round:
        ftCap = SW_FT_STROKER_LINECAP_ROUND;
        break;
    default:
        ftCap = SW_FT_STROKER_LINECAP_BUTT;
        break;
    }
    switch (join) {
    case JoinStyle::Bevel:
        ftJoin = SW_FT_STROKER_LINEJOIN_BEVEL;
        break;
    case JoinStyle::Round:
        ftJoin = SW_FT_STROKER_LINEJOIN_ROUND;
        break;
    default:
        ftJoin = SW_FT_STROKER_LINEJOIN_MITER;
        break;
    }
}

#define TO_FT_COORD(x) ((x)*64)  // to freetype 26.6 coordinate.

void FTOutline::moveTo(const VPointF &pt)
{
    ft.points[ft.n_points].x = TO_FT_COORD(pt.x());
    ft.points[ft.n_points].y = TO_FT_COORD(pt.y());
    ft.tags[ft.n_points] = SW_FT_CURVE_TAG_ON;
    if (ft.n_points) {
        ft.contours[ft.n_contours] = ft.n_points - 1;
        ft.n_contours++;
    }
    // mark the current contour as open
    // will be updated if ther is a close tag at the end.
    ft.contours_flag[ft.n_contours] = 1;

    ft.n_points++;
}

void FTOutline::lineTo(const VPointF &pt)
{
    ft.points[ft.n_points].x = TO_FT_COORD(pt.x());
    ft.points[ft.n_points].y = TO_FT_COORD(pt.y());
    ft.tags[ft.n_points] = SW_FT_CURVE_TAG_ON;
    ft.n_points++;
}

void FTOutline::cubicTo(const VPointF &cp1, const VPointF &cp2,
                        const VPointF ep)
{
    ft.points[ft.n_points].x = TO_FT_COORD(cp1.x());
    ft.points[ft.n_points].y = TO_FT_COORD(cp1.y());
    ft.tags[ft.n_points] = SW_FT_CURVE_TAG_CUBIC;
    ft.n_points++;

    ft.points[ft.n_points].x = TO_FT_COORD(cp2.x());
    ft.points[ft.n_points].y = TO_FT_COORD(cp2.y());
    ft.tags[ft.n_points] = SW_FT_CURVE_TAG_CUBIC;
    ft.n_points++;

    ft.points[ft.n_points].x = TO_FT_COORD(ep.x());
    ft.points[ft.n_points].y = TO_FT_COORD(ep.y());
    ft.tags[ft.n_points] = SW_FT_CURVE_TAG_ON;
    ft.n_points++;
}
void FTOutline::close()
{
    // mark the contour as a close path.
    ft.contours_flag[ft.n_contours] = 0;

    int index;
    if (ft.n_contours) {
        index = ft.contours[ft.n_contours - 1] + 1;
    } else {
        index = 0;
    }

    // make sure atleast 1 point exists in the segment.
    if (ft.n_points == index) {
        closed = false;
        return;
    }

    ft.points[ft.n_points].x = ft.points[index].x;
    ft.points[ft.n_points].y = ft.points[index].y;
    ft.tags[ft.n_points] = SW_FT_CURVE_TAG_ON;
    ft.n_points++;
}

void FTOutline::end()
{
    if (ft.n_points) {
        ft.contours[ft.n_contours] = ft.n_points - 1;
        ft.n_contours++;
    }
}

struct SpanInfo {
    VRle::Span *spans;
    int         size;
};

static void rleGenerationCb(int count, const SW_FT_Span *spans, void *user)
{
    VRle *      rle = (VRle *)user;
    VRle::Span *rleSpan = (VRle::Span *)spans;
    rle->addSpan(rleSpan, count);
}

static void bboxCb(int x, int y, int w, int h, void *user)
{
    VRle *      rle = (VRle *)user;
    rle->setBoundingRect({x, y, w, h});
}

struct RleTask {
    RleShare           mRlePromise;
    VPath              path;
    VRle               rle;
    float              width;
    float              meterLimit;
    VRect              clip;
    FillRule           fillRule;
    CapStyle           cap;
    JoinStyle          join;
    bool               stroke;
    VRle               operator()(FTOutline &outRef, SW_FT_Stroker &stroker);
    void               render(FTOutline &outRef);
    RleTask() {}
    RleTask(RleShare &apromise, VPath &&apath, VRle &&arle, FillRule afillRule, const VRect &aclip)
    {
        path = std::move(apath);
        rle = std::move(arle);
        fillRule = afillRule;
        clip = aclip;
        stroke = false;
        mRlePromise = apromise;
    }
    RleTask(RleShare &apromise, VPath &&apath, VRle &&arle, CapStyle acap, JoinStyle ajoin,
            float awidth, float ameterLimit, const VRect &aclip)
    {
        stroke = true;
        path = std::move(apath);
        rle = std::move(arle);
        cap = acap;
        join = ajoin;
        width = awidth;
        meterLimit = ameterLimit;
        clip = aclip;
        mRlePromise = apromise;
    }

};

void RleTask::render(FTOutline &outRef)
{
    SW_FT_Raster_Params params;

    params.flags = SW_FT_RASTER_FLAG_DIRECT | SW_FT_RASTER_FLAG_AA;
    params.gray_spans = &rleGenerationCb;
    params.bbox_cb = &bboxCb;
    params.user = &rle;
    params.source = &outRef.ft;

    if (!clip.empty()) {
        params.flags |= SW_FT_RASTER_FLAG_CLIP;

        params.clip_box.xMin =  clip.left();
        params.clip_box.yMin =  clip.top();
        params.clip_box.xMax =  clip.right();
        params.clip_box.yMax =  clip.bottom();
    }
    // compute rle
    sw_ft_grays_raster.raster_render(nullptr, &params);
}

VRle RleTask::operator()(FTOutline &outRef, SW_FT_Stroker &stroker)
{
    rle.reset();
    if (stroke) {  // Stroke Task
        outRef.convert(path);
        outRef.convert(cap, join, width, meterLimit);

        uint points, contors;

        SW_FT_Stroker_Set(stroker, outRef.ftWidth, outRef.ftCap, outRef.ftJoin,
                          outRef.ftMeterLimit);
        SW_FT_Stroker_ParseOutline(stroker, &outRef.ft);
        SW_FT_Stroker_GetCounts(stroker, &points, &contors);

        outRef.grow(points, contors);

        SW_FT_Stroker_Export(stroker, &outRef.ft);

    } else {  // Fill Task
        outRef.convert(path);
        int fillRuleFlag = SW_FT_OUTLINE_NONE;
        switch (fillRule) {
        case FillRule::EvenOdd:
            fillRuleFlag = SW_FT_OUTLINE_EVEN_ODD_FILL;
            break;
        default:
            fillRuleFlag = SW_FT_OUTLINE_NONE;
            break;
        }
        outRef.ft.flags = fillRuleFlag;
    }

    render(outRef);

    path = VPath();

    return std::move(rle);
}

#ifdef LOTTIE_THREAD_SUPPORT

#include "vtaskqueue.h"
#include <thread>

class RleTaskScheduler {
    const unsigned                  _count{std::thread::hardware_concurrency()};
    std::vector<std::thread>        _threads;
    std::vector<TaskQueue<RleTask>> _q{_count};
    std::atomic<unsigned>           _index{0};

    void run(unsigned i)
    {
        /*
         * initalize  per thread objects.
         */
        FTOutline     outlineRef;
        SW_FT_Stroker stroker;
        SW_FT_Stroker_New(&stroker);

        // Task Loop
        RleTask task;
        while (true) {
            bool success = false;

            for (unsigned n = 0; n != _count * 32; ++n) {
                if (_q[(i + n) % _count].try_pop(task)) {
                    success = true;
                    break;
                }
            }

            if (!success && !_q[i].pop(task)) break;

            task.mRlePromise->set_value((task)(outlineRef, stroker));
        }

        // cleanup
        SW_FT_Stroker_Done(stroker);
    }

    RleTaskScheduler()
    {
        for (unsigned n = 0; n != _count; ++n) {
            _threads.emplace_back([&, n] { run(n); });
        }
    }
public:
    static RleTaskScheduler& instance()
    {
         static RleTaskScheduler singleton;
         return singleton;
    }

    ~RleTaskScheduler()
    {
        for (auto &e : _q) e.done();

        for (auto &e : _threads) e.join();
    }

    void process(RleTask &&task)
    {
        auto i = _index++;

        for (unsigned n = 0; n != _count; ++n) {
            if (_q[(i + n) % _count].try_push(std::move(task))) return;
        }

        if (_count > 0) {
            _q[i % _count].push(std::move(task));
        }
    }
};

#else

class RleTaskScheduler {
public:
    FTOutline     outlineRef;
    SW_FT_Stroker stroker;
public:
    static RleTaskScheduler& instance()
    {
         static RleTaskScheduler singleton;
         return singleton;
    }

    RleTaskScheduler()
    {
        SW_FT_Stroker_New(&stroker);
    }

    ~RleTaskScheduler()
    {
        SW_FT_Stroker_Done(stroker);
    }

    void process(RleTask &&task)
    {
        task.mRlePromise->set_value((task)(outlineRef, stroker));
    }
};
#endif

void VRaster::generateFillInfo(RleShare &promise, VPath &&path, VRle &&rle,
                                            FillRule fillRule, const VRect &clip)
{
    if (path.empty()) {
        promise->set_value(VRle());
        return;
    }
    return RleTaskScheduler::instance().process(RleTask(promise, std::move(path), std::move(rle), fillRule, clip));
}

void VRaster::generateStrokeInfo(RleShare &promise, VPath &&path, VRle &&rle, CapStyle cap,
                                 JoinStyle join, float width,
                                 float meterLimit, const VRect &clip)
{
    if (path.empty()) {
        promise->set_value(VRle());
        return;
    }
    return RleTaskScheduler::instance().process(RleTask(promise, std::move(path), std::move(rle), cap, join, width, meterLimit, clip));
}

V_END_NAMESPACE
