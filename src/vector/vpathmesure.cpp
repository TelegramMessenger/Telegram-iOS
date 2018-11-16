#include "vpathmesure.h"
#include "vbezier.h"
#include "vdasher.h"
#include <limits>

V_BEGIN_NAMESPACE

VPath oneSegment(float start, float end, const VPath & path)
{
    if (start > end) {
        std::swap(start, end);
    }
    float   array[5] = {0.0f, start, end - start, std::numeric_limits<float>::max(), 0.0f};
    VDasher dasher(array, 5);
    return dasher.dashed(path);
}

VPath VPathMesure::trim(const VPath &path)
{
    if (vCompare(mStart, mEnd)) return VPath();

    if ((vCompare(mStart, 0.0f) && (vCompare(mEnd, 1.0f))) ||
        (vCompare(mStart, 1.0f) && (vCompare(mEnd, 0.0f)))) return path;

    if (vIsZero(mOffset)) {
        float length = path.length();
        return oneSegment(length * mStart, length * mEnd, path);
    } else {
        float length = path.length();
        float offset = length * mOffset;
        float start = length * mStart;
        float end  = length * mEnd;
        start += offset;
        end +=offset;

        if (start < 0 && end < 0) {
            return oneSegment(length + start, length + end, path);
        } else if (start > 0 && end > 0) {
            if (start > length && end > length)
                return oneSegment(start - length, end - length, path);
            else if (start < length && end < length)
                return oneSegment(start, end, path);
            else {
                float len1 = start > end ? start - length : end - length;
                float start2 = start < end ? start : end;
                float gap1 = start2 - len1;
                float   array[5] = {len1, gap1, length - start2, 1000, 0.0f};
                VDasher dasher(array, 5);
                return dasher.dashed(path);
            }
        } else {
            float len1 = start > end ? start : end;
            float start2 = start < end ? length + start : length + end;
            float gap1 = start2 - len1;
            float   array[5] = {len1, gap1, length - start2, 1000, 0.0f};
            VDasher dasher(array, 5);
            return dasher.dashed(path);
        }
    }
}

V_END_NAMESPACE
