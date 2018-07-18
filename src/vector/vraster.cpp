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
    FTOutline() = delete;
    FTOutline(int points, int segments)
    {
        ft.points = new SW_FT_Vector[points + segments];
        ft.tags   = new char[points + segments];
        ft.contours = new short[segments];
        ft.n_points = ft.n_contours = 0;
        ft.flags = 0x0;
    }
    void moveTo(const VPointF &pt);
    void lineTo(const VPointF &pt);
    void cubicTo(const VPointF &ctr1, const VPointF &ctr2, const VPointF end);
    void close();
    void end();
    void transform(const VMatrix &m);
    ~FTOutline()
    {
        delete[] ft.points;
        delete[] ft.tags;
        delete[] ft.contours;
    }
    SW_FT_Outline  ft;
    bool           closed;
};



#define TO_FT_COORD(x) ((x) * 64) // to freetype 26.6 coordinate.

void FTOutline::transform(const VMatrix &m)
{
    VPointF pt;
    if (m.isIdentity()) return;
    for (auto i = 0; i < ft.n_points; i++) {
        pt = m.map(VPointF(ft.points[i].x/64.0, ft.points[i].y/64.0));
        ft.points[i].x = TO_FT_COORD(pt.x());
        ft.points[i].y = TO_FT_COORD(pt.y());
    }
}

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
    FTOutline               *outline;
    SW_FT_Stroker_LineCap    cap;
    SW_FT_Stroker_LineJoin   join;
    int                      width;
    int                      meterLimit;
    SW_FT_Bool               closed;
};

static VRle generateRleAsync(RleTask *task);

class RleTaskScheduler {
    const unsigned _count{std::thread::hardware_concurrency()};
    std::vector<std::thread> _threads;
    std::vector<TaskQueue<RleTask>> _q{_count};
    std::atomic<unsigned> _index{0};

    void run(unsigned i) {
        while (true) {
            RleTask *task = nullptr;

            for (unsigned n = 0; n != _count * 32; ++n) {
                if (_q[(i + n) % _count].try_pop(task)) break;
            }
            if (!task && !_q[i].pop(task)) break;

            VRle rle = generateRleAsync(task);
            task->sender.set_value(std::move(rle));
            delete task;
        }
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

    std::future<VRle> strokeRle(FTOutline *outline,
                                SW_FT_Stroker_LineCap cap,
                                SW_FT_Stroker_LineJoin join,
                                int width,
                                int meterLimit,
                                SW_FT_Bool closed) {
        RleTask *task = new RleTask();
        task->stroke = true;
        task->outline = outline;
        task->cap = cap;
        task->join = join;
        task->width = width;
        task->meterLimit = meterLimit;
        task->closed = closed;
        return async(task);
    }

    std::future<VRle> fillRle(FTOutline *outline) {
        RleTask *task = new RleTask();
        task->stroke = false;
        task->outline = outline;
        return async(task);
    }
};

static RleTaskScheduler raster_scheduler;

static VRle generateRleAsync(RleTask *task)
{
    if (task->stroke) {
        // for stroke generation
        SW_FT_Stroker stroker;
        SW_FT_Stroker_New(&stroker);

        uint points,contors;
        SW_FT_Outline strokeOutline = { 0, 0, nullptr, nullptr, nullptr, SW_FT_OUTLINE_NONE };

        SW_FT_Stroker_Set(stroker, task->width, task->cap, task->join, task->meterLimit);
        SW_FT_Stroker_ParseOutline(stroker, &task->outline->ft, !task->closed);
        SW_FT_Stroker_GetCounts(stroker,&points, &contors);

        strokeOutline.points = (SW_FT_Vector *) calloc(points, sizeof(SW_FT_Vector));
        strokeOutline.tags = (char *) calloc(points, sizeof(char));
        strokeOutline.contours = (short *) calloc(contors, sizeof(short));

        SW_FT_Stroker_Export(stroker, &strokeOutline);

        SW_FT_Stroker_Done(stroker);

        VRle rle;
        SW_FT_Raster_Params params;

        params.flags = SW_FT_RASTER_FLAG_DIRECT | SW_FT_RASTER_FLAG_AA ;
        params.gray_spans = &rleGenerationCb;
        params.user = &rle;
        params.source = &strokeOutline;

        sw_ft_grays_raster.raster_render(nullptr, &params);

        // cleanup the outline data.
        free(strokeOutline.points);
        free(strokeOutline.tags);
        free(strokeOutline.contours);

        return rle;
    } else {
        // fill generation
        VRle rle;
        SW_FT_Raster_Params params;

        params.flags = SW_FT_RASTER_FLAG_DIRECT | SW_FT_RASTER_FLAG_AA ;
        params.gray_spans = &rleGenerationCb;
        params.user = &rle;
        params.source = &task->outline->ft;

        sw_ft_grays_raster.raster_render(nullptr, &params);

        return rle;
    }
}

VRaster::VRaster()
{
}

VRaster::~VRaster()
{
}

void VRaster::deleteFTOutline(FTOutline *outline)
{
    delete outline;
}

FTOutline *VRaster::toFTOutline(const VPath &path)
{
    if (path.isEmpty())
        return nullptr;

    const std::vector<VPath::Element> &elements = path.elements();
    const std::vector<VPointF> &points = path.points();

    FTOutline *outline = new FTOutline(points.size(), path.segments());

    int index = 0;
    for(auto element : elements) {
        switch (element){
        case VPath::Element::MoveTo:
            outline->moveTo(points[index]);
            index++;
            break;
        case VPath::Element::LineTo:
            outline->lineTo(points[index]);
            index++;
            break;
        case VPath::Element::CubicTo:
            outline->cubicTo(points[index], points[index+1], points[index+2]);
            index = index+3;
            break;
        case VPath::Element::Close:
            outline->close();
            break;
        default:
            break;
        }
    }
    outline->end();
    return outline;
}

std::future<VRle>
VRaster::generateFillInfo(FTOutline *outline, FillRule fillRule)
{
    int fillRuleFlag = SW_FT_OUTLINE_NONE;
    switch (fillRule) {
    case FillRule::EvenOdd:
        fillRuleFlag = SW_FT_OUTLINE_EVEN_ODD_FILL;
        break;
    default:
        fillRuleFlag = SW_FT_OUTLINE_NONE;
        break;
    }

    outline->ft.flags =  fillRuleFlag;

    return std::move(raster_scheduler.fillRle(outline));
}

std::future<VRle>
VRaster::generateStrokeInfo(FTOutline *outline, CapStyle cap, JoinStyle join,
                            float width, float meterLimit)
{
    SW_FT_Stroker_LineCap ftCap;
    SW_FT_Stroker_LineJoin ftJoin;
    int ftWidth;
    int ftMeterLimit;
    SW_FT_Bool ftclose = (SW_FT_Bool) outline->closed;

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

    return std::move(raster_scheduler.strokeRle(outline, ftCap, ftJoin,
                                                ftWidth, ftMeterLimit, ftclose));
}

V_END_NAMESPACE
