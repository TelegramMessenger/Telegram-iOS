#include "vbezier.h"

#include<cmath>

// Approximate sqrt(x*x + y*y) using the alpha max plus beta min algorithm.
// This uses alpha = 1, beta = 3/8, which results in a maximum error of less
// than 7% compared to the correct value.
static inline float
lineLength(float x1, float y1, float x2, float y2)
{
   float x = x2 - x1;
   float y = y2 - y1;

   x = x < 0 ? -x : x;
   y = y < 0 ? -y : y;

   return (x > y ? x + 0.375 * y : y + 0.375 * x);
}

VBezier VBezier::fromPoints(const VPointF &p1, const VPointF &p2,
                            const VPointF &p3, const VPointF &p4)
{
    VBezier b;
    b.x1 = p1.x();
    b.y1 = p1.y();
    b.x2 = p2.x();
    b.y2 = p2.y();
    b.x3 = p3.x();
    b.y3 = p3.y();
    b.x4 = p4.x();
    b.y4 = p4.y();
    return b;
}

float
VBezier::length()const
{
   VBezier left, right; /* bez poly splits */
   float len = 0.0; /* arc length */
   float chord; /* chord length */
   float length;

   len = len + lineLength(x1, y1, x2, y2);
   len = len + lineLength(x2, y2, x3, y3);
   len = len + lineLength(x3, y3, x4, y4);

   chord = lineLength(x1, y1, x4, y4);

   if (!floatCmp(len, chord)) {
      split(&left, &right); /* split in two */
      length =
               left.length() + /* try left side */
               right.length(); /* try right side */

      return length;
   }

   return len;
}

VBezier VBezier::onInterval(float t0, float t1) const
{
    if (t0 == 0 && t1 == 1)
        return *this;

    VBezier bezier = *this;

    VBezier result;
    bezier.parameterSplitLeft(t0, &result);
    float trueT = (t1-t0)/(1-t0);
    bezier.parameterSplitLeft(trueT, &result);

    return result;
}

float VBezier::tAtLength(float l) const
{
    float len = length();
    float t   = 1.0;
    const float error = 0.01;
    if (l > len || floatCmp(l, len))
        return t;

    t *= 0.5;

    float lastBigger = 1.0;
    while (1) {
        VBezier right = *this;
        VBezier left;
        right.parameterSplitLeft(t, &left);
        float lLen = left.length();
        if (fabs(lLen - l) < error)
            break;

        if (lLen < l) {
            t += (lastBigger - t) * 0.5;
        } else {
            lastBigger = t;
            t -= t * 0.5;
        }
    }
    return t;
}

void
VBezier::splitAtLength(float len, VBezier *left, VBezier *right)
{
   float t;

   *right = *this;
   t =  right->tAtLength(len);
   right->parameterSplitLeft(t, left);
}



