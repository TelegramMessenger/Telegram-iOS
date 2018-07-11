#include"vdasher.h"
#include"vbezier.h"

class VLine
{
public:
    VLine():mX1(0),mY1(0),mX2(0),mY2(0){}
    VLine(float x1, float y1, float x2, float y2):mX1(x1),mY1(y1),mX2(x2),mY2(y2){}
    VLine(const VPointF &p1, const VPointF &p2):mX1(p1.x()),mY1(p1.y()),mX2(p2.x()),mY2(p2.y()){}
    float length() const;
    void splitAtLength(float length, VLine &left, VLine &right) const;
    VPointF p1() const {return VPointF(mX1, mY1);}
    VPointF p2() const {return VPointF(mX2, mY2);}
private:
    float mX1;
    float mY1;
    float mX2;
    float mY2;
};

// approximate sqrt(x*x + y*y) using alpha max plus beta min algorithm.
// With alpha = 1, beta = 3/8, giving results with the largest error less
// than 7% compared to the exact value.
float
VLine::length() const
{
   float x = mX2 - mX1;
   float y = mY2 - mY1;
   x = x < 0 ? -x : x;
   y = y < 0 ? -y : y;
   return (x > y ? x + 0.375 * y : y + 0.375 * x);
}

void
VLine::splitAtLength(float lengthAt, VLine &left, VLine &right) const
{
   float len = length();
   double dx = ((mX2 - mX1)/len) *lengthAt;
   double dy = ((mY2 - mY1)/len) *lengthAt;

   left.mX1 = mX1;
   left.mY1 = mY1;
   left.mX2 = left.mX1 + dx;
   left.mY2 = left.mY1 + dy;

   right.mX1 = left.mX2;
   right.mY1 = left.mY2;
   right.mX2 = mX2;
   right.mY2 = mY2;
}

VDasher::VDasher(const float *dashArray, int size)
{
    if (!(size % 2))
        vCritical<<"invalid dashArray format";

    mDashArray = reinterpret_cast<const VDasher::Dash *>(dashArray);
    mArraySize = size/2;
    mDashOffset = dashArray[size-1];
    mCurrentDashIndex = 0;
    mCurrentDashLength = 0;
    mIsCurrentOperationGap = false;
}

void VDasher::moveTo(const VPointF &p)
{
    mIsCurrentOperationGap = false;
    mStartPt = p;
    mCurPt = p;

    if (!floatCmp(mDashOffset, 0.0)) {
        float totalLength = 0.0;
        for (int i = 0; i < mArraySize ; i++) {
            totalLength = mDashArray[i].length + mDashArray[i].gap;
        }
        float normalizeLen = fmod(mDashOffset, totalLength);
        if (normalizeLen < 0.0 ) {
            normalizeLen = totalLength + normalizeLen;
        }
        // now the length is less than total length and +ve
        // findout the current dash index , dashlength and gap.
        for (int i = 0; i < mArraySize; i++) {
            if (normalizeLen < mDashArray[i].length) {
                mCurrentDashIndex = i;
                mCurrentDashLength = mDashArray[i].length - normalizeLen;
                mIsCurrentOperationGap = false;
                break;
            }
            normalizeLen -= mDashArray[i].length;
            if (normalizeLen < mDashArray[i].gap) {
                mCurrentDashIndex = i;
                mCurrentDashLength = mDashArray[i].gap - normalizeLen;
                mIsCurrentOperationGap = true;
                break;
            }
            normalizeLen -= mDashArray[i].gap;
        }
    } else {
        mCurrentDashIndex = 0;
        mCurrentDashLength = mDashArray[0].length;
    }
}

void VDasher::lineTo(const VPointF &p)
{
    VLine left, right;
    VLine line(mCurPt, p);
    float length = line.length();
    if (length < mCurrentDashLength) {
         mCurrentDashLength -= length;
         if (!mIsCurrentOperationGap) {
             mDashedPath.moveTo(mCurPt);
             mDashedPath.lineTo(p);
         }
    } else {
         while (length > mCurrentDashLength) {
              length -= mCurrentDashLength;
              line.splitAtLength(mCurrentDashLength, left, right);
              if (!mIsCurrentOperationGap) {
                  mDashedPath.moveTo(left.p1());
                  mDashedPath.lineTo(left.p2());
                  mCurrentDashLength = mDashArray[mCurrentDashIndex].gap;
              } else {
                  mCurrentDashIndex = (mCurrentDashIndex +1) % mArraySize ;
                  mCurrentDashLength = mDashArray[mCurrentDashIndex].length;
              }
              mIsCurrentOperationGap = !mIsCurrentOperationGap;
              line = right;
              mCurPt = line.p1();
         }
         // remainder
         mCurrentDashLength -= length;
         if (!mIsCurrentOperationGap) {
             mDashedPath.moveTo(line.p1());
             mDashedPath.lineTo(line.p2());
         }
         if (mCurrentDashLength < 1.0) {
              // move to next dash
              if (!mIsCurrentOperationGap) {
                   mIsCurrentOperationGap = true;
                   mCurrentDashLength = mDashArray[mCurrentDashIndex].gap;
              } else {
                   mIsCurrentOperationGap = false;
                   mCurrentDashIndex = (mCurrentDashIndex +1) % mArraySize;
                   mCurrentDashLength = mDashArray[mCurrentDashIndex].length;
              }
         }
    }
    mCurPt = p;
}

void VDasher::cubicTo(const VPointF &cp1, const VPointF &cp2, const VPointF &e)
{
    VBezier left, right;
    float bezLen = 0.0;
    VBezier b = VBezier::fromPoints(mCurPt, cp1, cp2, e);
    bezLen = b.length();
    if (bezLen < mCurrentDashLength) {
         mCurrentDashLength -= bezLen;
         if (!mIsCurrentOperationGap) {
              mDashedPath.moveTo(mCurPt);
              mDashedPath.cubicTo(cp1, cp2, e);
         }
    } else {
         while (bezLen > mCurrentDashLength) {
              bezLen -= mCurrentDashLength;
              b.splitAtLength(mCurrentDashLength, &left, &right);
              if (!mIsCurrentOperationGap) {
                   mDashedPath.moveTo(left.pt1());
                   mDashedPath.cubicTo(left.pt2(), left.pt3(), left.pt4());;
                   mCurrentDashLength = mDashArray[mCurrentDashIndex].gap;
              } else {
                   mCurrentDashIndex = (mCurrentDashIndex +1) % mArraySize ;
                   mCurrentDashLength = mDashArray[mCurrentDashIndex].length;
              }
              mIsCurrentOperationGap = !mIsCurrentOperationGap;
              b = right;
              mCurPt = b.pt1();
        }
          // remainder
         mCurrentDashLength -= bezLen;
         if (!mIsCurrentOperationGap) {
              mDashedPath.moveTo(b.pt1());
              mDashedPath.cubicTo(b.pt2(), b.pt3(), b.pt4());
         }
         if (mCurrentDashLength < 1.0) {
              // move to next dash
              if (!mIsCurrentOperationGap)
                {
                   mIsCurrentOperationGap = true;
                   mCurrentDashLength = mDashArray[mCurrentDashIndex].gap;
                }
              else
                {
                   mIsCurrentOperationGap = false;
                   mCurrentDashIndex = (mCurrentDashIndex +1) % mArraySize;
                   mCurrentDashLength = mDashArray[mCurrentDashIndex].length;
                }
         }
    }
    mCurPt = e;
}


VPath VDasher::dashed(const VPath &path)
{
    if (path.isEmpty()) return VPath();

    mDashedPath = VPath();
    const std::vector<VPath::Element> &elms = path.elements();
    const std::vector<VPointF> &pts = path.points();
    const VPointF *ptPtr = pts.data();

    for (auto i : elms) {
        switch (i) {
            case VPath::Element::MoveTo: {
                moveTo(*ptPtr++);
                break;
            }
            case VPath::Element::LineTo: {
                lineTo(*ptPtr++);
                break;
            }
            case VPath::Element::CubicTo: {
                cubicTo(*ptPtr, *(ptPtr + 1), *(ptPtr + 2));
                ptPtr += 3;
                break;
            }
            case VPath::Element::Close: {
                // The point is already joined to start point in VPath
                // no need to do anything here.
                break;
            }
            default:
                break;
        }
    }
    return mDashedPath;
}

