#include "vrle.h"
#include"vglobal.h"
#include<vrect.h>
#include<cstdlib>
#include<vector>
#include<array>
#include<algorithm>
#include"vdebug.h"
#include"vregion.h"

V_BEGIN_NAMESPACE

struct VRleHelper
{
   ushort        alloc;
   ushort        size;
   VRle::Span  *spans;
};

#define VMIN(a,b) ((a) < (b) ? (a) : (b))
#define VMAX(a,b) ((a) > (b) ? (a) : (b))

static inline uchar
divBy255(int x) { return (x + (x>>8) + 0x80) >> 8; }

/*
 * This function will clip a rle list with another rle object
 * tmp_clip  : The rle list that will be use to clip the rle
 * tmp_obj   : holds the list of spans that has to be clipped
 * result    : will hold the result after the processing
 * NOTE: if the algorithm runs out of the result buffer list
 *       it will stop and update the tmp_obj with the span list
 *       that are yet to be processed as well as the tpm_clip object
 *       with the unprocessed clip spans.
 */
static void
rleIntersectWithRle(VRleHelper *tmp_clip,
                    int clip_offset_x,
                    int clip_offset_y,
                    VRleHelper *tmp_obj,
                    VRleHelper *result)
{
    VRle::Span *out = result->spans;
    int available = result->alloc;
    VRle::Span *spans = tmp_obj->spans;
    VRle::Span *end = tmp_obj->spans + tmp_obj->size;
    VRle::Span *clipSpans = tmp_clip->spans;
    VRle::Span *clipEnd = tmp_clip->spans + tmp_clip->size;
    int sx1, sx2, cx1, cx2, x, len;


   while (available && spans < end )
     {
        if (clipSpans >= clipEnd)
          {
             spans = end;
             break;
          }
        if ((clipSpans->y + clip_offset_y) > spans->y)
          {
             ++spans;
             continue;
          }
        if (spans->y != (clipSpans->y + clip_offset_y))
          {
             ++clipSpans;
             continue;
          }
        //assert(spans->y == (clipSpans->y + clip_offset_y));
        sx1 = spans->x;
        sx2 = sx1 + spans->len;
        cx1 = (clipSpans->x + clip_offset_x);
        cx2 = cx1 + clipSpans->len;

        if (cx1 < sx1 && cx2 < sx1)
          {
             ++clipSpans;
             continue;
          }
        else if (sx1 < cx1 && sx2 < cx1)
          {
             ++spans;
             continue;
          }
        x = VMAX(sx1, cx1);
        len = VMIN(sx2, cx2) - x;
        if (len)
          {
             out->x = VMAX(sx1, cx1);
             out->len = ( VMIN(sx2, cx2) - out->x);
             out->y = spans->y;
             out->coverage = divBy255(spans->coverage * clipSpans->coverage);
             ++out;
             --available;
          }
        if (sx2 < cx2)
          {
             ++spans;
          }
        else
          {
             ++clipSpans;
          }
     }

   // update the span list that yet to be processed
   tmp_obj->spans = spans;
   tmp_obj->size = end - spans;

   // update the clip list that yet to be processed
   tmp_clip->spans = clipSpans;
   tmp_clip->size = clipEnd - clipSpans;

   // update the result
   result->size = result->alloc - available;
}

/*
 * This function will clip a rle list with a given rect
 * clip      : The clip rect that will be use to clip the rle
 * tmp_obj   : holds the list of spans that has to be clipped
 * result    : will hold the result after the processing
 * NOTE: if the algorithm runs out of the result buffer list
 *       it will stop and update the tmp_obj with the span list
 *       that are yet to be processed
 */
static void
rleIntersectWithRect(const VRect &clip,
                     VRleHelper *tmp_obj,
                     VRleHelper *result)
{
   VRle::Span *out = result->spans;
   int available = result->alloc;
   VRle::Span *spans = tmp_obj->spans;
   VRle::Span *end = tmp_obj->spans + tmp_obj->size;
   short minx, miny, maxx, maxy;

   minx = clip.left();
   miny = clip.top();
   maxx = clip.right() - 1;
   maxy = clip.bottom() - 1;

   while (available && spans < end )
     {
        if (spans->y > maxy)
          {
             spans = end;// update spans so that we can breakout
             break;
          }
        if (spans->y < miny
            || spans->x > maxx
            || spans->x + spans->len <= minx)
          {
             ++spans;
             continue;
          }
        if (spans->x < minx)
          {
             out->len = VMIN(spans->len - (minx - spans->x), maxx - minx + 1);
             out->x = minx;
          }
        else
          {
             out->x = spans->x;
             out->len = VMIN(spans->len, (maxx - spans->x + 1));
          }
        if (out->len != 0)
          {
             out->y = spans->y;
             out->coverage = spans->coverage;
             ++out;
          }
        ++spans;
        --available;
     }

   // update the span list that yet to be processed
   tmp_obj->spans = spans;
   tmp_obj->size = end - spans;

   // update the result
   result->size = result->alloc - available;
}

void drawSpanlineMul(VRle::Span *spans, int count, uchar *buffer, int offsetX)
{
    uchar *ptr;
    while (count--) {
        int x = spans->x + offsetX;
        int l = spans->len;
        ptr = buffer + x;
        while (l--) {
            uchar cov = *ptr;
            *ptr++ = divBy255(spans->coverage * cov);
        }
        spans++;
    }
}

void drawSpanline(VRle::Span *spans, int count, uchar *buffer, int offsetX)
{
    uchar *ptr;
    while (count--) {
        int x = spans->x + offsetX;
        int l = spans->len;
        ptr = buffer + x;
        while (l--) {
            *ptr++ = spans->coverage;
        }
        spans++;
    }
}

int bufferToRle(uchar *buffer, int size, int offsetX, int y, VRle::Span *out)
{
    int count = 0;
    uchar value = buffer[0];
    int curIndex = 0;
    for (int i = 0; i < size ; i++) {
        uchar curValue = buffer[0];
        if (value != curValue) {
            out->y = y;
            out->x = offsetX + curIndex;
            out->len = i - curIndex;
            out->coverage = value;
            out++;
            curIndex = i;
            value = curValue;
            count++;
        }
        buffer++;
    }
    out->y = y;
    out->x = offsetX + curIndex;
    out->len = size - curIndex;
    out->coverage = value;
    count++;
    return count;
}

static void
rleAddWithRle1(VRleHelper *tmp_clip,
              VRleHelper *tmp_obj,
              VRleHelper *result)
{
    std::array<VRle::Span,256> rleHolder;
    VRle::Span *out = result->spans;
    int available = result->alloc;
    VRle::Span *spans = tmp_obj->spans;
    VRle::Span *end = tmp_obj->spans + tmp_obj->size;
    VRle::Span *clipSpans = tmp_clip->spans;
    VRle::Span *clipEnd = tmp_clip->spans + tmp_clip->size;

    while (available && spans < end && clipSpans < clipEnd) {
        if (spans->y < clipSpans->y) {
            *out++ = *spans++;
            available--;
        } else if (clipSpans->y < spans->y) {
            *out++ = *clipSpans++;
            available--;
        } else { // same y
            int y = spans->y;
            VRle::Span *spanPtr = spans;
            VRle::Span *clipPtr = clipSpans;

            while (spanPtr < end && spanPtr->y == y) spanPtr++;
            while (clipPtr < clipEnd && clipPtr->y == y) clipPtr++;

            int spanLength = (spanPtr-1)->x + (spanPtr-1)->len - spans->x;
            int clipLength = (clipPtr-1)->x + (clipPtr-1)->len - clipSpans->x;
            int offsetX = VMIN(spans->x, clipSpans->x);
            std::array<uchar,1024> array = {0};
            drawSpanline(spans, (spanPtr - spans), array.data(), -offsetX);
            drawSpanlineMul(clipSpans, (clipPtr - clipSpans), array.data(), -offsetX);
            VRle::Span *rleHolderPtr = rleHolder.data();
            int size = bufferToRle(array.data(), VMAX(spanLength, clipLength),
                                   offsetX, y, rleHolderPtr);
            if (available >= size) {
                while(size--) {
                    *out++ = *rleHolderPtr++;
                    available--;
                }
            } else {
                break;
            }
            spans = spanPtr;
            clipSpans = clipPtr;
        }
    }
    // update the span list that yet to be processed
    tmp_obj->spans = spans;
    tmp_obj->size = end - spans;

    // update the clip list that yet to be processed
    tmp_clip->spans = clipSpans;
    tmp_clip->size = clipEnd - clipSpans;

    // update the result
    result->size = result->alloc - available;
}


class VRleImpl
{
public:
    inline VRleImpl():m_bbox(),m_spans(), mOffset(), mBboxDirty(true){}
    VRleImpl &operator=(const VRleImpl &);
    void addSpan(const VRle::Span *span, int count);
    void updateBbox();
    bool operator ==(const VRleImpl &) const;
    void intersected(const VRect &r, VRleImpl &result);
    void intersected(const VRleImpl &clip, VRleImpl &result);
    friend VDebug& operator<<(VDebug& os, const VRleImpl& object);
    void invert();
    void alphaMul(int alpha);
    void translate(const VPoint &pt);
    void opAdd(const VRleImpl &other, VRleImpl &res);
    VRect bbox();
public:
    VRect                   m_bbox;
    std::vector<VRle::Span> m_spans;// array of Spanlines.
    VPoint                  mOffset;
    bool                     mBboxDirty;
};

inline static void
copyArrayToVector(const VRle::Span *span, int count, std::vector<VRle::Span> &v)
{
    // make sure enough memory available
    v.reserve(v.size() + count);
    std::copy(span, span + count, back_inserter(v));
}

VDebug& operator<<(VDebug& os, const VRleImpl& o)
{
    os<<"[bbox="<< o.m_bbox<<"]"<<"[offset="<<o.mOffset<<"]"<<
        "[span count ="<<o.m_spans.size()<<"]\n";
    os<<"[rle spans = {x y len coverage}";
    for(auto sp : o.m_spans)
        os<<"{"<<sp.x<<" "<<sp.y<<" "<<sp.len<<" "<<sp.coverage<<"}";
    os<<"]";
    return os;
}

VRect VRleImpl::bbox()
{
    updateBbox();
    return m_bbox;
}

void VRleImpl::translate(const VPoint &pt)
{
    //take care of last offset if applied
    mOffset = pt - mOffset;
    int x = mOffset.x();
    int y = mOffset.y();
    for (auto &i : m_spans) {
        i.x = i.x + x;
        i.y = i.y + y;
    }
    updateBbox();
    m_bbox.translate(mOffset.x(), mOffset.y());
}

void VRleImpl::invert()
{
    for (auto &i : m_spans) {
        i.coverage = 255 - i.coverage;
    }
}

void VRleImpl::alphaMul(int alpha)
{
    alpha &= 0xff;

    for (auto &i : m_spans) {
        i.coverage = divBy255(i.coverage * alpha);
    }
}

void VRleImpl::intersected(const VRect &r, VRleImpl &result)
{
    VRect clip = r;

    VRleHelper tresult, tmp_obj;
    std::array<VRle::Span,256> array;

    //setup the tresult object
    tresult.size = array.size();
    tresult.alloc = array.size();
    tresult.spans = array.data();

    // setup tmp object
    tmp_obj.size = m_spans.size();
    tmp_obj.spans = m_spans.data();

    // run till all the spans are processed
    while (tmp_obj.size)
      {
         rleIntersectWithRect(clip, &tmp_obj, &tresult);
         if (tresult.size) {
             copyArrayToVector(tresult.spans, tresult.size, result.m_spans);
         }
         tresult.size = 0;
      }
    result.updateBbox();
}

void VRleImpl::intersected(const VRleImpl &clip, VRleImpl &result)
{
    VRleHelper tresult, tmp_obj, tmp_clip;
    std::array<VRle::Span,256> array;

    //setup the tresult object
    tresult.size = array.size();
    tresult.alloc = array.size();
    tresult.spans = array.data();

    // setup tmp object
    tmp_obj.size = m_spans.size();
    tmp_obj.spans = m_spans.data();

    //setup tmp clip object
    tmp_clip.size = clip.m_spans.size();
    tmp_clip.spans = const_cast<VRle::Span *>(clip.m_spans.data());

    // run till all the spans are processed
    while (tmp_obj.size)
      {
         rleIntersectWithRle(&tmp_clip, 0, 0, &tmp_obj, &tresult);
         if (tresult.size) {
             copyArrayToVector(tresult.spans, tresult.size, result.m_spans);
         }
         tresult.size = 0;
      }
    result.updateBbox();
}

void VRleImpl::opAdd(const VRleImpl &other, VRleImpl &result)
{
    // reserve some space for the result vector.
    result.m_spans.reserve(m_spans.size() + other.m_spans.size());
    // if two rle are disjoint
    if (!m_bbox.intersects(other.m_bbox)) {
        result.m_spans = m_spans;
        copyArrayToVector(other.m_spans.data(), other.m_spans.size(), result.m_spans);
    } else {
        VRle::Span *ptr = m_spans.data();
        int otherY = other.m_bbox.top();
        // 1. forward till both y intersect
        while (ptr->y < otherY)  ptr++;
        int spanToCopy = ptr - m_spans.data();
        copyArrayToVector(m_spans.data(), spanToCopy, result.m_spans);

        // 2. calculate the intersect region
        VRleHelper tresult, tmp_obj, tmp_other;
        std::array<VRle::Span,256> array;

        //setup the tresult object
        tresult.size = array.size();
        tresult.alloc = array.size();
        tresult.spans = array.data();

        // setup tmp object
        tmp_obj.size = m_spans.size() - spanToCopy;
        tmp_obj.spans = ptr;

        //setup tmp clip object
        tmp_other.size = other.m_spans.size();
        tmp_other.spans = const_cast<VRle::Span *>(other.m_spans.data());

        // run till all the spans are processed
        while (tmp_obj.size && tmp_other.size)
          {
             rleAddWithRle1(&tmp_other, &tmp_obj, &tresult);
             if (tresult.size) {
                 copyArrayToVector(tresult.spans, tresult.size, result.m_spans);
             }
             tresult.size = 0;
          }
        //3. copy the rest
        if (tmp_other.size) {
            copyArrayToVector(tmp_other.spans, tmp_other.size, result.m_spans);
        }
        if (tmp_obj.size) {
            copyArrayToVector(tmp_obj.spans, tmp_obj.size, result.m_spans);
        }
    }

    // update result bounding box
    VRegion reg(m_bbox);
    reg += other.m_bbox;
    result.m_bbox = reg.boundingRect();
    result.mBboxDirty = false;
}


VRleImpl &VRleImpl::operator=(const VRleImpl &other)
{
    m_spans = other.m_spans;
    m_bbox = other.m_bbox;
    mOffset = other.mOffset;
    return *this;
}

bool VRleImpl::operator ==(const VRleImpl &other) const
{
    if (m_spans.size() != other.m_spans.size())
        return false;
    const VRle::Span *spans = m_spans.data();
    const VRle::Span *o_spans = other.m_spans.data();
    int sz = m_spans.size();

    for (int i = 0; i < sz; i++) {
        if (spans[i].x != o_spans[i].x ||
            spans[i].y != o_spans[i].y ||
            spans[i].len != o_spans[i].len ||
            spans[i].coverage != o_spans[i].coverage)
            return false;
    }
    return true;
}


void VRleImpl::updateBbox()
{
    if (!mBboxDirty) return;

    mBboxDirty = false;

    int i, l = 0, t = 0, r = 0, b = 0, sz;
    l = std::numeric_limits<int>::max();
    const VRle::Span *span = m_spans.data();

    m_bbox = VRect();
    sz = m_spans.size();
    if (sz)
      {
         t = span[0].y;
         b = span[sz-1].y;
         for (i = 0; i < sz; i++)
           {
              if (span[i].x < l) l = span[i].x;
              if (span[i].x + span[i].len > r) r = span[i].x + span[i].len;
           }
         m_bbox = VRect(l, t, r - l, b - t + 1);
      }
}

void VRleImpl::addSpan(const VRle::Span *span, int count)
{
    copyArrayToVector(span, count, m_spans);
    mBboxDirty = true;
}

struct VRleData
{
    RefCount    ref;
    VRleImpl   impl;
};

static const struct VRleData shared_empty = {RefCount(-1),
                                              VRleImpl()};

inline void VRle::cleanUp(VRleData *d)
{
    delete d;
}

void VRle::detach()
{
    if (d->ref.isShared())
        *this = copy();
}

VRle VRle::copy() const
{
    VRle other;

    other.d = new VRleData;
    other.d->impl = d->impl;
    other.d->ref.setOwned();
    return other;
}

VRle::~VRle()
{
    if (!d->ref.deref())
        cleanUp(d);
}

VRle::VRle()
    : d(const_cast<VRleData*>(&shared_empty))
{
}

VRle::VRle(const VRle &other)
{
    d = other.d;
    d->ref.ref();
}

VRle::VRle(VRle &&other): d(other.d)
{
    other.d = const_cast<VRleData*>(&shared_empty);
}

VRle &VRle::operator=(const VRle &other)
{
    other.d->ref.ref();
    if (!d->ref.deref())
        cleanUp(d);

    d = other.d;
    return *this;
}

inline VRle &VRle::operator=(VRle &&other)
{
    if (!d->ref.deref())
        cleanUp(d);
    d = other.d;
    other.d = const_cast<VRleData*>(&shared_empty);
    return *this;
}

bool VRle::isEmpty()const
{
    return (d == &shared_empty || d->impl.m_spans.empty());
}

void VRle::addSpan(const VRle::Span *span, int count)
{
    detach();
    d->impl.addSpan(span, count);
}

VRect VRle::boundingRect() const
{
    if(isEmpty())
        return VRect();
    return d->impl.bbox();
}

bool VRle::operator ==(const VRle &other) const
{
    if (isEmpty())
        return other.isEmpty();
    if (other.isEmpty())
        return isEmpty();

    if (d == other.d)
        return true;
    else
        return d->impl == other.d->impl;
}

void VRle::translate(const VPoint &p)
{
    if (isEmpty()) return;

    if (d->impl.mOffset == p) return;

    detach();
    d->impl.translate(p);
}

VRle VRle::intersected(const VRect &r) const
{
    if (isEmpty() || r.isEmpty())
        return VRle();

    // check if the bounding rect is contain inside r
    if (r.contains(boundingRect(), true))
        return *this;

    VRle result;
    result.detach();
    d->impl.intersected(r, result.d->impl);
    return result;
}

VRle VRle::intersected(const VRle &other) const
{
    if (isEmpty() || other.isEmpty())
        return VRle();
    // check if the bounding rect are not intersecting
    VRle result;
    result.detach();
    d->impl.intersected(other.d->impl, result.d->impl);
    return result;
}

VRle VRle::operator~() const
{
    if (isEmpty()) return VRle();

    VRle result = *this;
    result.detach();
    result.d->impl.invert();
    return result;
}

VRle VRle::operator+(const VRle &other) const
{
    if (isEmpty()) return other;

    if (other.isEmpty()) return *this;

    VRle result;
    result.detach();
    if (boundingRect().top() < other.boundingRect().top())
       d->impl.opAdd(other.d->impl, result.d->impl);
    else
        other.d->impl.opAdd(d->impl, result.d->impl);
    return result;
}

VRle VRle::operator-(const VRle &other) const
{
    if (isEmpty()) return ~other;

    if (other.isEmpty()) return *this;

    VRle temp = ~other;
    return *this + temp;
}

VRle VRle::operator&(const VRle &o) const
{
    if (isEmpty() || o.isEmpty()) return VRle();

    if (!boundingRect().intersects(o.boundingRect())) return VRle();

    VRle result;
    result.detach();
    d->impl.intersected(o.d->impl, result.d->impl);
    return result;
}



void VRle::intersected(const VRect &r, VRleSpanCb cb, void *userData)
{
    //TODO Implement
}


VRle  &VRle::intersect(const VRect &r)
{
    if (isEmpty() || r.isEmpty())
        return *this = VRle();

    VRle result;
    result.detach();
    d->impl.intersected(r, result.d->impl);
    return *this = result;
}

VRle operator*(const VRle &obj, int alpha)
{
    if (obj.isEmpty()) return obj;

    VRle result = obj;
    result.detach();
    result.d->impl.alphaMul(alpha);
    return result;
}


int VRle::size() const
{
    if (isEmpty()) return 0;
    return d->impl.m_spans.size();
}

const VRle::Span* VRle::data() const
{
    if (isEmpty()) return nullptr;
    return d->impl.m_spans.data();
}

VRle VRle::toRle(const VRectF &rect)
{
    VRle result;
    result.detach();
    int x = rect.left();
    int y = rect.top();
    int width = rect.width();
    int height = rect.height();
    result.d->impl.m_spans.reserve(height);
    VRle::Span span;
    for(int i=0; i < height ; i++) {
        span.x = x;
        span.y = y + i;
        span.len = width;
        span.coverage = 255;
       result.d->impl.m_spans.push_back(span);
    }
    return result;
}

VDebug& operator<<(VDebug& os, const VRle& o)
{
    os<<"[RLE: [dptr = "<<"o.d"<<"]"<<"[ref = "<<o.d->ref.count()<<"]"<<o.d->impl<<"]";
    return os;
}

V_END_NAMESPACE




