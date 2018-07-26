#include"vraster.h"
#include"v_ft_raster.h"
#include"v_ft_stroker.h"
#include"vpath.h"
#include"vmatrix.h"
#include<cstring>
#include"vdebug.h"
#include"vtaskqueue.h"
#include<thread>

V_BEGIN_NAMESPACE

struct FTOutline
{
public:
    FTOutline():mMemory(nullptr){}
    ~FTOutline(){delete[] mMemory;}
    void releaseMemory() {
        if (mMemory) delete [] mMemory;
        mMemory = nullptr;
        mPointSize = 0;
        mSegmentSize = 0;
    }
    void reset();
    void grow(int, int);
    void convert(const VPath &path);
    void convert(CapStyle, JoinStyle, float, float);
    void moveTo(const VPointF &pt);
    void lineTo(const VPointF &pt);
    void cubicTo(const VPointF &ctr1, const VPointF &ctr2, const VPointF end);
    void close();
    void end();
    void transform(const VMatrix &m);
    SW_FT_Outline            ft;
    SW_FT_Vector            *mMemory{nullptr};
    int                      mPointSize{0};
    int                      mSegmentSize{0};
    bool                     closed{false};
    SW_FT_Stroker_LineCap    ftCap;
    SW_FT_Stroker_LineJoin   ftJoin;
    int                      ftWidth;
    int                      ftMeterLimit;
    SW_FT_Bool               ftClosed;
};

void FTOutline::reset()
{
    ft.n_points = ft.n_contours = 0;
    ft.flags = 0x0;
}

void FTOutline::grow(int points, int segments)
{
    reset();
    if (mPointSize >= points && mSegmentSize >= segments)
        return;

    // release old memory
    releaseMemory();

    //update book keeping
    mPointSize = points;
    mSegmentSize = segments;

    int point_size = (points + segments);
    int contour_size = ((sizeof(short) * segments) / sizeof(SW_FT_Vector)) + 1;
    int tag_size = ((sizeof(char) * (points + segments)) / sizeof(SW_FT_Vector)) + 1;

    /*
     * Optimization, instead of allocating 3 different buffer
     * allocate one big buffer and divide the buffer into 3 different
     * segment.
     */
    mMemory = new SW_FT_Vector[point_size + contour_size + tag_size];
    ft.points = reinterpret_cast<SW_FT_Vector *>(mMemory);
    ft.tags = reinterpret_cast<char *>(mMemory + point_size);
    ft.contours = reinterpret_cast<short *>(mMemory + point_size + tag_size);
}

void FTOutline::convert(const VPath &path)
{
    const std::vector<VPath::Element> &elements = path.elements();
    const std::vector<VPointF> &points = path.points();

    grow(points.size(), path.segments());

    int index = 0;
    for(auto element : elements) {
        switch (element){
        case VPath::Element::MoveTo:
            moveTo(points[index]);
            index++;
            break;
        case VPath::Element::LineTo:
            lineTo(points[index]);
            index++;
            break;
        case VPath::Element::CubicTo:
            cubicTo(points[index], points[index+1], points[index+2]);
            index = index+3;
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

void FTOutline::convert(CapStyle cap, JoinStyle join,
                        float width, float meterLimit)
{
    ftClosed = (SW_FT_Bool) closed;

    // map strokeWidth to freetype. It uses as the radius of the pen not the diameter
    width = width/2.0;
    // convert to freetype co-ordinate
    ftWidth = int(width * 64);
    ftMeterLimit = int(meterLimit * 64);

    // map to freetype capstyle
    switch (cap)
      {
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
    switch (join)
      {
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


#define TO_FT_COORD(x) ((x) * 64) // to freetype 26.6 coordinate.

void FTOutline::moveTo(const VPointF &pt)
{
    ft.points[ft.n_points].x = TO_FT_COORD(pt.x());
    ft.points[ft.n_points].y = TO_FT_COORD(pt.y());
    ft.tags[ft.n_points] = SW_FT_CURVE_TAG_ON;
    if (ft.n_points) {
        ft.contours[ft.n_contours] = ft.n_points - 1;
        ft.n_contours++;
    }
    ft.n_points++;
    closed = false;
}

void FTOutline::lineTo(const VPointF &pt)
{
    ft.points[ft.n_points].x = TO_FT_COORD(pt.x());
    ft.points[ft.n_points].y = TO_FT_COORD(pt.y());
    ft.tags[ft.n_points] = SW_FT_CURVE_TAG_ON;
    ft.n_points++;
    closed = false;
}

void FTOutline::cubicTo(const VPointF &cp1, const VPointF &cp2, const VPointF ep)
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
    closed = false;
}
void FTOutline::close()
{
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
    closed = true;
}

void FTOutline::end()
{
    if (ft.n_points) {
        ft.contours[ft.n_contours] = ft.n_points - 1;
        ft.n_contours++;
    }
}

struct SpanInfo
{
  VRle::Span *spans;
  int          size;
};

static void
rleGenerationCb( int count, const SW_FT_Span*  spans,void *user)
{
   VRle *rle = (VRle *) user;
   VRle::Span *rleSpan = (VRle::Span *)spans;
   rle->addSpan(rleSpan, count);
}

struct RleTask
{
    RleTask() {
        receiver = sender.get_future();
    }
    std::promise<VRle>       sender;
    std::future<VRle>        receiver;
    bool                     stroke;
    VPath                    path;
    FillRule                 fillRule;
    CapStyle                 cap;
    JoinStyle                join;
    float                    width;
    float                    meterLimit;
    VRle operator()(FTOutline &outRef, SW_FT_Stroker &stroker);
};

VRle RleTask::operator()(FTOutline &outRef, SW_FT_Stroker &stroker)
{
    if (stroke) { //Stroke Task
        outRef.convert(path);
        outRef.convert(cap, join, width, meterLimit);

        uint points,contors;

        SW_FT_Stroker_Set(stroker, outRef.ftWidth, outRef.ftCap, outRef.ftJoin, outRef.ftMeterLimit);
        SW_FT_Stroker_ParseOutline(stroker, &outRef.ft, !outRef.ftClosed);
        SW_FT_Stroker_GetCounts(stroker,&points, &contors);

        FTOutline strokeOutline;
        strokeOutline.grow(points, contors);

        SW_FT_Stroker_Export(stroker, &strokeOutline.ft);

        VRle rle;
        SW_FT_Raster_Params params;

        params.flags = SW_FT_RASTER_FLAG_DIRECT | SW_FT_RASTER_FLAG_AA ;
        params.gray_spans = &rleGenerationCb;
        params.user = &rle;
        params.source = &strokeOutline;

        sw_ft_grays_raster.raster_render(nullptr, &params);

        return rle;
    } else { //Fill Task
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
        outRef.ft.flags =  fillRuleFlag;
        VRle rle;
        SW_FT_Raster_Params params;

        params.flags = SW_FT_RASTER_FLAG_DIRECT | SW_FT_RASTER_FLAG_AA ;
        params.gray_spans = &rleGenerationCb;
        params.user = &rle;
        params.source = &outRef.ft;

        sw_ft_grays_raster.raster_render(nullptr, &params);
        return rle;
    }
}

class RleTaskScheduler {
    const unsigned _count{std::thread::hardware_concurrency()};
    std::vector<std::thread> _threads;
    std::vector<TaskQueue<RleTask>> _q{_count};
    std::atomic<unsigned> _index{0};

    void run(unsigned i) {
        /*
         * initalize  per thread objects.
         */
        FTOutline  outlineRef;
        SW_FT_Stroker stroker;
        SW_FT_Stroker_New(&stroker);

        // Task Loop
        while (true) {
            RleTask *task = nullptr;

            for (unsigned n = 0; n != _count * 32; ++n) {
                if (_q[(i + n) % _count].try_pop(task)) break;
            }
            if (!task && !_q[i].pop(task)) break;

            task->sender.set_value((*task)(outlineRef, stroker));
            delete task;
        }

        //cleanup
        SW_FT_Stroker_Done(stroker);
    }

public:
    RleTaskScheduler() {
        for (unsigned n = 0; n != _count; ++n) {
            _threads.emplace_back([&, n] { run(n); });
        }
    }

    ~RleTaskScheduler() {
        for (auto& e : _q)
            e.done();

        for (auto& e : _threads)
            e.join();
    }

    std::future<VRle> async(RleTask *task) {
        auto receiver = std::move(task->receiver);
        auto i = _index++;

        for (unsigned n = 0; n != _count; ++n) {
            if (_q[(i + n) % _count].try_push(task)) return std::move(receiver);
        }

        _q[i % _count].push(task);

        return std::move(receiver);
    }

    std::future<VRle> strokeRle(const VPath &path,
                                CapStyle cap,
                                JoinStyle join,
                                float width,
                                float meterLimit) {
        RleTask *task = new RleTask();
        task->stroke = true;
        task->path = path;
        task->cap = cap;
        task->join = join;
        task->width = width;
        task->meterLimit = meterLimit;
        return async(task);
    }

    std::future<VRle> fillRle(const VPath &path, FillRule fillRule) {
        RleTask *task = new RleTask();
        task->path = path;
        task->fillRule = fillRule;
        task->stroke = false;
        return async(task);
    }
};

static RleTaskScheduler raster_scheduler;

VRaster::VRaster()
{
}

VRaster::~VRaster()
{
}

std::future<VRle>
VRaster::generateFillInfo(const VPath &path, FillRule fillRule)
{
    if (path.isEmpty()) {
        std::promise<VRle> promise;
        promise.set_value(VRle());
        return promise.get_future();
    }
    return std::move(raster_scheduler.fillRle(path, fillRule));
}

std::future<VRle>
VRaster::generateStrokeInfo(const VPath &path, CapStyle cap, JoinStyle join,
                            float width, float meterLimit)
{
    if (path.isEmpty()) {
        std::promise<VRle> promise;
        promise.set_value(VRle());
        return promise.get_future();
    }
    return std::move(raster_scheduler.strokeRle(path, cap, join, width, meterLimit));
}

V_END_NAMESPACE
