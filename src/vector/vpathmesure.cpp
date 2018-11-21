#include "vpathmesure.h"
#include "vbezier.h"
#include "vdasher.h"
#include <limits>

V_BEGIN_NAMESPACE

/*
 * start and end value must be normalized to [0 - 1]
 * Path mesure trims the path from [start --> end]
 * if start > end it treates as a loop and trims as two segment
 *  [0-->end] and [start --> 1]
 */
VPath VPathMesure::trim(const VPath &path)
{
    if (vCompare(mStart, mEnd)) return VPath();

    if ((vCompare(mStart, 0.0f) && (vCompare(mEnd, 1.0f))) ||
        (vCompare(mStart, 1.0f) && (vCompare(mEnd, 0.0f)))) return path;

    float length = path.length();

    if (mStart < mEnd) {
        float   array[4] = {0.0f, length * mStart, //1st segment
                            (mEnd - mStart) * length, std::numeric_limits<float>::max(), //2nd segment
                           };
        VDasher dasher(array, 4);
        return dasher.dashed(path);
    } else {
        float   array[4] = {length * mEnd, (mStart - mEnd) * length, //1st segment
                            (1 - mStart) * length, std::numeric_limits<float>::max(), //2nd segment
                           };
        VDasher dasher(array, 4);
        return dasher.dashed(path);
    }
}

V_END_NAMESPACE
