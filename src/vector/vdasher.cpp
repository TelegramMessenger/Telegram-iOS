/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the LGPL License, Version 2.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.gnu.org/licenses/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "vdasher.h"
#include "vbezier.h"
#include "vline.h"

V_BEGIN_NAMESPACE

VDasher::VDasher(const float *dashArray, int size)
{
    mDashArray = reinterpret_cast<const VDasher::Dash *>(dashArray);
    mArraySize = size / 2;
    if (size % 2)
        mDashOffset = dashArray[size - 1];
    mIndex = 0;
    mCurrentLength = 0;
    mDiscard = false;
}

void VDasher::moveTo(const VPointF &p)
{
    mDiscard = false;
    mStartNewSegment = true;
    mCurPt = p;
    mIndex = 0;

    if (!vCompare(mDashOffset, 0.0f)) {
        float totalLength = 0.0;
        for (int i = 0; i < mArraySize; i++) {
            totalLength = mDashArray[i].length + mDashArray[i].gap;
        }
        float normalizeLen = fmod(mDashOffset, totalLength);
        if (normalizeLen < 0.0) {
            normalizeLen = totalLength + normalizeLen;
        }
        // now the length is less than total length and +ve
        // findout the current dash index , dashlength and gap.
        for (int i = 0; i < mArraySize; i++) {
            if (normalizeLen < mDashArray[i].length) {
                mIndex = i;
                mCurrentLength = mDashArray[i].length - normalizeLen;
                mDiscard = false;
                break;
            }
            normalizeLen -= mDashArray[i].length;
            if (normalizeLen < mDashArray[i].gap) {
                mIndex = i;
                mCurrentLength = mDashArray[i].gap - normalizeLen;
                mDiscard = true;
                break;
            }
            normalizeLen -= mDashArray[i].gap;
        }
    } else {
        mCurrentLength = mDashArray[mIndex].length;
    }
    if (vIsZero(mCurrentLength)) updateActiveSegment();
}

void VDasher::addLine(const VPointF &p)
{
   if (mDiscard) return;

   if (mStartNewSegment) {
        mResult.moveTo(mCurPt);
        mStartNewSegment = false;
   }
   mResult.lineTo(p);
}

void VDasher::updateActiveSegment()
{
    mStartNewSegment = true;

    if (mDiscard) {
        mDiscard = false;
        mIndex = (mIndex + 1) % mArraySize;
        mCurrentLength = mDashArray[mIndex].length;
    } else {
        mDiscard = true;
        mCurrentLength = mDashArray[mIndex].gap;
    }
    if (vIsZero(mCurrentLength)) updateActiveSegment();
}

void VDasher::lineTo(const VPointF &p)
{
    VLine left, right;
    VLine line(mCurPt, p);
    float length = line.length();

    if (length <= mCurrentLength) {
        mCurrentLength -= length;
        addLine(p);
    } else {
        while (length > mCurrentLength) {
            length -= mCurrentLength;
            line.splitAtLength(mCurrentLength, left, right);

            addLine(left.p2());
            updateActiveSegment();

            line = right;
            mCurPt = line.p1();
        }
        // handle remainder
        if (length > 1.0) {
            mCurrentLength -= length;
            addLine(line.p2());
        }
    }

    if (mCurrentLength < 1.0) updateActiveSegment();

    mCurPt = p;
}

void VDasher::addCubic(const VPointF &cp1, const VPointF &cp2, const VPointF &e)
{
    if (mDiscard) return;

    if (mStartNewSegment) {
        mResult.moveTo(mCurPt);
        mStartNewSegment = false;
    }
    mResult.cubicTo(cp1, cp2, e);
}

void VDasher::cubicTo(const VPointF &cp1, const VPointF &cp2, const VPointF &e)
{
    VBezier left, right;
    float   bezLen = 0.0;
    VBezier b = VBezier::fromPoints(mCurPt, cp1, cp2, e);
    bezLen = b.length();

    if (bezLen <= mCurrentLength) {
        mCurrentLength -= bezLen;
        addCubic(cp1, cp2, e);
    } else {
        while (bezLen > mCurrentLength) {
            bezLen -= mCurrentLength;
            b.splitAtLength(mCurrentLength, &left, &right);

            addCubic(left.pt2(), left.pt3(), left.pt4());
            updateActiveSegment();

            b = right;
            mCurPt = b.pt1();
        }
        // handle remainder
        if (bezLen > 1.0) {
            mCurrentLength -= bezLen;
            addCubic(b.pt2(), b.pt3(), b.pt4());
        }
    }

    if (mCurrentLength < 1.0) updateActiveSegment();

    mCurPt = e;
}

VPath VDasher::dashed(const VPath &path)
{
    if (path.empty()) return VPath();

    mResult = VPath();
    mIndex = 0;
    const std::vector<VPath::Element> &elms = path.elements();
    const std::vector<VPointF> &       pts = path.points();
    const VPointF *                    ptPtr = pts.data();

    for (auto &i : elms) {
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
    return std::move(mResult);
}

V_END_NAMESPACE
