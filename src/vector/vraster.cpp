#include"vraster.h"
#include"v_ft_raster.h"
#include"v_ft_stroker.h"
#include"vpath.h"
#include"vmatrix.h"
#include<cstring>
#include"vdebug.h"

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

struct VRasterPrivate
{
public:
    VRle generateFillInfoAsync(const SW_FT_Outline *outline);
    VRle generateStrokeInfoAsync(const SW_FT_Outline *outline, SW_FT_Stroker_LineCap cap,
                                 SW_FT_Stroker_LineJoin join,
                                 int width, int meterLimit,
                                 SW_FT_Bool closed);

    std::mutex        m_rasterAcess;
    std::mutex        m_strokerAcess;
    SW_FT_Raster      m_raster;
    SW_FT_Stroker     m_stroker;
};

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

VRle VRasterPrivate::generateFillInfoAsync(const SW_FT_Outline *outline)
{
    m_rasterAcess.lock();
    VRle rle;
    SW_FT_Raster_Params params;

    params.flags = SW_FT_RASTER_FLAG_DIRECT | SW_FT_RASTER_FLAG_AA ;
    params.gray_spans = &rleGenerationCb;
    params.user = &rle;
    params.source = outline;

    sw_ft_grays_raster.raster_render(m_raster, &params);

    m_rasterAcess.unlock();

    return rle;
}

VRle VRasterPrivate::generateStrokeInfoAsync(const SW_FT_Outline *outline, SW_FT_Stroker_LineCap cap,
                                             SW_FT_Stroker_LineJoin join,
                                             int width, int meterLimit,
                                             SW_FT_Bool closed)
{
    m_strokerAcess.lock();
    uint points,contors;
    SW_FT_Outline strokeOutline = { 0, 0, nullptr, nullptr, nullptr, SW_FT_OUTLINE_NONE };

    SW_FT_Stroker_Set(m_stroker, width, cap, join, meterLimit);
    SW_FT_Stroker_ParseOutline(m_stroker, outline, !closed);
    SW_FT_Stroker_GetCounts(m_stroker,&points, &contors);

    strokeOutline.points = (SW_FT_Vector *) calloc(points, sizeof(SW_FT_Vector));
    strokeOutline.tags = (char *) calloc(points, sizeof(char));
    strokeOutline.contours = (short *) calloc(contors, sizeof(short));

    SW_FT_Stroker_Export(m_stroker, &strokeOutline);

    m_strokerAcess.unlock();

    VRle rle = generateFillInfoAsync(&strokeOutline);

    // cleanup the outline data.
    free(strokeOutline.points);
    free(strokeOutline.tags);
    free(strokeOutline.contours);

    return rle;
}


VRaster::VRaster()
{
    d = new VRasterPrivate;
    sw_ft_grays_raster.raster_new(&d->m_raster);
    SW_FT_Stroker_New(&d->m_stroker);
    SW_FT_Stroker_Set(d->m_stroker, 1 << 6,
                      SW_FT_STROKER_LINECAP_BUTT, SW_FT_STROKER_LINEJOIN_MITER, 0);
}

VRaster::~VRaster()
{
    sw_ft_grays_raster.raster_done(d->m_raster);
    SW_FT_Stroker_Done(d->m_stroker);
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

VRle VRaster::generateFillInfo(const FTOutline *outline, FillRule fillRule)
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
    FTOutline *outlineRef = const_cast<FTOutline *>(outline);
    outlineRef->ft.flags =  fillRuleFlag;
    return d->generateFillInfoAsync(&outlineRef->ft);
}

VRle VRaster::generateStrokeInfo(const FTOutline *outline, CapStyle cap, JoinStyle join,
                                 float width, float meterLimit)
{
    SW_FT_Stroker_LineCap ftCap;
    SW_FT_Stroker_LineJoin ftJoin;
    int ftWidth;
    int ftMeterLimit;
    SW_FT_Bool ftbool = (SW_FT_Bool) outline->closed;

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

    return d->generateStrokeInfoAsync(&outline->ft, ftCap, ftJoin,
                                      ftWidth, ftMeterLimit, ftbool);
}

V_END_NAMESPACE
