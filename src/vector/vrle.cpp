#include "vrle.h"
#include <vrect.h>
#include <algorithm>
#include <array>
#include <cstdlib>
#include <vector>
#include "vdebug.h"
#include "vglobal.h"
#include "vregion.h"

V_BEGIN_NAMESPACE

struct VRleHelper {
    ushort      alloc;
    ushort      size;
    VRle::Span *spans;
};
static void rleIntersectWithRle(VRleHelper *, int, int, VRleHelper *,
                                VRleHelper *);
static void rleIntersectWithRect(const VRect &, VRleHelper *, VRleHelper *);
static void rleAddWithRle(VRleHelper *, VRleHelper *, VRleHelper *);

static inline uchar divBy255(int x)
{
    return (x + (x >> 8) + 0x80) >> 8;
}

inline static void copyArrayToVector(const VRle::Span *span, int count,
                                     std::vector<VRle::Span> &v)
{
    // make sure enough memory available
    if (v.capacity() < v.size() + count) v.reserve(v.size() + count);
    std::copy(span, span + count, back_inserter(v));
}

void VRle::VRleData::addSpan(const VRle::Span *span, int count)
{
    copyArrayToVector(span, count, mSpans);
    mBboxDirty = true;
}

VRect VRle::VRleData::bbox() const
{
    updateBbox();
    return mBbox;
}

void VRle::VRleData::reset()
{
    mSpans.clear();
    mBbox = VRect();
    mOffset = VPoint();
    mBboxDirty = false;
}

void VRle::VRleData::translate(const VPoint &p)
{
    // take care of last offset if applied
    mOffset = p - mOffset;
    int x = mOffset.x();
    int y = mOffset.y();
    for (auto &i : mSpans) {
        i.x = i.x + x;
        i.y = i.y + y;
    }
    updateBbox();
    mBbox.translate(mOffset.x(), mOffset.y());
}

void VRle::VRleData::addRect(const VRect &rect)
{
    int x = rect.left();
    int y = rect.top();
    int width = rect.width();
    int height = rect.height();

    mSpans.reserve(height);

    VRle::Span span;
    for (int i = 0; i < height; i++) {
        span.x = x;
        span.y = y + i;
        span.len = width;
        span.coverage = 255;
        mSpans.push_back(span);
    }
    updateBbox();
}

void VRle::VRleData::updateBbox() const
{
    if (!mBboxDirty) return;

    mBboxDirty = false;

    int i, l = 0, t = 0, r = 0, b = 0, sz;
    l = std::numeric_limits<int>::max();
    const VRle::Span *span = mSpans.data();

    mBbox = VRect();
    sz = mSpans.size();
    if (sz) {
        t = span[0].y;
        b = span[sz - 1].y;
        for (i = 0; i < sz; i++) {
            if (span[i].x < l) l = span[i].x;
            if (span[i].x + span[i].len > r) r = span[i].x + span[i].len;
        }
        mBbox = VRect(l, t, r - l, b - t + 1);
    }
}

void VRle::VRleData::invert()
{
    for (auto &i : mSpans) {
        i.coverage = 255 - i.coverage;
    }
}

void VRle::VRleData::operator*=(int alpha)
{
    alpha &= 0xff;
    for (auto &i : mSpans) {
        i.coverage = divBy255(i.coverage * alpha);
    }
}

void VRle::VRleData::opIntersect(const VRect &r, VRle::VRleSpanCb cb,
                                 void *userData) const
{
    VRect clip = r;

    VRleHelper                  tresult, tmp_obj;
    std::array<VRle::Span, 256> array;

    // setup the tresult object
    tresult.size = array.size();
    tresult.alloc = array.size();
    tresult.spans = array.data();

    // setup tmp object
    tmp_obj.size = mSpans.size();
    tmp_obj.spans = const_cast<VRle::Span *>(mSpans.data());

    // run till all the spans are processed
    while (tmp_obj.size) {
        rleIntersectWithRect(clip, &tmp_obj, &tresult);
        if (tresult.size) {
            cb(tresult.size, tresult.spans, userData);
        }
        tresult.size = 0;
    }
}

void VRle::VRleData::opAdd(const VRle::VRleData &obj1,
                           const VRle::VRleData &obj2)
{
    // This routine assumes, obj1(span_y) < obj2(span_y).

    // reserve some space for the result vector.
    mSpans.reserve(obj1.mSpans.size() + obj2.mSpans.size());

    // if two rle are disjoint
    if (!obj1.bbox().intersects(obj2.bbox())) {
        copyArrayToVector(obj1.mSpans.data(), obj1.mSpans.size(), mSpans);
        copyArrayToVector(obj2.mSpans.data(), obj2.mSpans.size(), mSpans);
    } else {
        VRle::Span *ptr = const_cast<VRle::Span *>(obj1.mSpans.data());
        int         otherY = obj2.mBbox.top();
        // 1. forward till both y intersect
        while (ptr->y < otherY) ptr++;
        int spanToCopy = ptr - obj1.mSpans.data();
        copyArrayToVector(obj1.mSpans.data(), spanToCopy, mSpans);

        // 2. calculate the intersect region
        VRleHelper                  tresult, tmp_obj, tmp_other;
        std::array<VRle::Span, 256> array;

        // setup the tresult object
        tresult.size = array.size();
        tresult.alloc = array.size();
        tresult.spans = array.data();

        // setup tmp object
        tmp_obj.size = obj1.mSpans.size() - spanToCopy;
        tmp_obj.spans = ptr;

        // setup tmp clip object
        tmp_other.size = obj2.mSpans.size();
        tmp_other.spans = const_cast<VRle::Span *>(obj2.mSpans.data());

        // run till all the spans are processed
        while (tmp_obj.size && tmp_other.size) {
            rleAddWithRle(&tmp_other, &tmp_obj, &tresult);
            if (tresult.size) {
                copyArrayToVector(tresult.spans, tresult.size, mSpans);
            }
            tresult.size = 0;
        }
        // 3. copy the rest
        if (tmp_other.size) {
            copyArrayToVector(tmp_other.spans, tmp_other.size, mSpans);
        }
        if (tmp_obj.size) {
            copyArrayToVector(tmp_obj.spans, tmp_obj.size, mSpans);
        }
    }

    // update result bounding box
    VRegion reg(obj1.bbox());
    reg += obj2.bbox();
    mBbox = reg.boundingRect();
    mBboxDirty = false;
}

void VRle::VRleData::opIntersect(const VRle::VRleData &obj1,
                                 const VRle::VRleData &obj2)
{
    VRleHelper                  result, source, clip;
    std::array<VRle::Span, 256> array;

    // setup the tresult object
    result.size = array.size();
    result.alloc = array.size();
    result.spans = array.data();

    // setup tmp object
    source.size = obj1.mSpans.size();
    source.spans = const_cast<VRle::Span *>(obj1.mSpans.data());

    // setup tmp clip object
    clip.size = obj2.mSpans.size();
    clip.spans = const_cast<VRle::Span *>(obj2.mSpans.data());

    // run till all the spans are processed
    while (source.size) {
        rleIntersectWithRle(&clip, 0, 0, &source, &result);
        if (result.size) {
            copyArrayToVector(result.spans, result.size, mSpans);
        }
        result.size = 0;
    }
    updateBbox();
}

#define VMIN(a, b) ((a) < (b) ? (a) : (b))
#define VMAX(a, b) ((a) > (b) ? (a) : (b))

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
static void rleIntersectWithRle(VRleHelper *tmp_clip, int clip_offset_x,
                                int clip_offset_y, VRleHelper *tmp_obj,
                                VRleHelper *result)
{
    VRle::Span *out = result->spans;
    int         available = result->alloc;
    VRle::Span *spans = tmp_obj->spans;
    VRle::Span *end = tmp_obj->spans + tmp_obj->size;
    VRle::Span *clipSpans = tmp_clip->spans;
    VRle::Span *clipEnd = tmp_clip->spans + tmp_clip->size;
    int         sx1, sx2, cx1, cx2, x, len;

    while (available && spans < end) {
        if (clipSpans >= clipEnd) {
            spans = end;
            break;
        }
        if ((clipSpans->y + clip_offset_y) > spans->y) {
            ++spans;
            continue;
        }
        if (spans->y != (clipSpans->y + clip_offset_y)) {
            ++clipSpans;
            continue;
        }
        // assert(spans->y == (clipSpans->y + clip_offset_y));
        sx1 = spans->x;
        sx2 = sx1 + spans->len;
        cx1 = (clipSpans->x + clip_offset_x);
        cx2 = cx1 + clipSpans->len;

        if (cx1 < sx1 && cx2 < sx1) {
            ++clipSpans;
            continue;
        } else if (sx1 < cx1 && sx2 < cx1) {
            ++spans;
            continue;
        }
        x = VMAX(sx1, cx1);
        len = VMIN(sx2, cx2) - x;
        if (len) {
            out->x = VMAX(sx1, cx1);
            out->len = (VMIN(sx2, cx2) - out->x);
            out->y = spans->y;
            out->coverage = divBy255(spans->coverage * clipSpans->coverage);
            ++out;
            --available;
        }
        if (sx2 < cx2) {
            ++spans;
        } else {
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
static void rleIntersectWithRect(const VRect &clip, VRleHelper *tmp_obj,
                                 VRleHelper *result)
{
    VRle::Span *out = result->spans;
    int         available = result->alloc;
    VRle::Span *spans = tmp_obj->spans;
    VRle::Span *end = tmp_obj->spans + tmp_obj->size;
    short       minx, miny, maxx, maxy;

    minx = clip.left();
    miny = clip.top();
    maxx = clip.right() - 1;
    maxy = clip.bottom() - 1;

    while (available && spans < end) {
        if (spans->y > maxy) {
            spans = end;  // update spans so that we can breakout
            break;
        }
        if (spans->y < miny || spans->x > maxx ||
            spans->x + spans->len <= minx) {
            ++spans;
            continue;
        }
        if (spans->x < minx) {
            out->len = VMIN(spans->len - (minx - spans->x), maxx - minx + 1);
            out->x = minx;
        } else {
            out->x = spans->x;
            out->len = VMIN(spans->len, (maxx - spans->x + 1));
        }
        if (out->len != 0) {
            out->y = spans->y;
            out->coverage = spans->coverage;
            ++out;
            --available;
        }
        ++spans;
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
    int   count = 0;
    uchar value = buffer[0];
    int   curIndex = 0;
    for (int i = 0; i < size; i++) {
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

static void rleAddWithRle(VRleHelper *tmp_clip, VRleHelper *tmp_obj,
                          VRleHelper *result)
{
    std::array<VRle::Span, 256> rleHolder;
    VRle::Span *                out = result->spans;
    int                         available = result->alloc;
    VRle::Span *                spans = tmp_obj->spans;
    VRle::Span *                end = tmp_obj->spans + tmp_obj->size;
    VRle::Span *                clipSpans = tmp_clip->spans;
    VRle::Span *                clipEnd = tmp_clip->spans + tmp_clip->size;

    while (available && spans < end && clipSpans < clipEnd) {
        if (spans->y < clipSpans->y) {
            *out++ = *spans++;
            available--;
        } else if (clipSpans->y < spans->y) {
            *out++ = *clipSpans++;
            available--;
        } else {  // same y
            int         y = spans->y;
            VRle::Span *spanPtr = spans;
            VRle::Span *clipPtr = clipSpans;

            while (spanPtr < end && spanPtr->y == y) spanPtr++;
            while (clipPtr < clipEnd && clipPtr->y == y) clipPtr++;

            int spanLength = (spanPtr - 1)->x + (spanPtr - 1)->len - spans->x;
            int clipLength =
                (clipPtr - 1)->x + (clipPtr - 1)->len - clipSpans->x;
            int                     offsetX = VMIN(spans->x, clipSpans->x);
            std::array<uchar, 1024> array = {0};
            drawSpanline(spans, (spanPtr - spans), array.data(), -offsetX);
            drawSpanlineMul(clipSpans, (clipPtr - clipSpans), array.data(),
                            -offsetX);
            VRle::Span *rleHolderPtr = rleHolder.data();
            int size = bufferToRle(array.data(), VMAX(spanLength, clipLength),
                                   offsetX, y, rleHolderPtr);
            if (available >= size) {
                while (size--) {
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

VRle VRle::toRle(const VRect &rect)
{
    if (rect.isEmpty()) return VRle();

    VRle result;
    result.d.write().addRect(rect);
    return result;
}

V_END_NAMESPACE
