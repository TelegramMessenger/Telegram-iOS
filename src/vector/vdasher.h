/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the Flora License, Version 1.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://floralicense.org/license/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef VDASHER_H
#define VDASHER_H
#include "vpath.h"

V_BEGIN_NAMESPACE

class VDasher {
public:
    VDasher(const float *dashArray, int size);
    VPath dashed(const VPath &path);

private:
    void moveTo(const VPointF &p);
    void lineTo(const VPointF &p);
    void cubicTo(const VPointF &cp1, const VPointF &cp2, const VPointF &e);
    void close();
    void addLine(const VPointF &p);
    void addCubic(const VPointF &cp1, const VPointF &cp2, const VPointF &e);
    void updateActiveSegment();

private:
    struct Dash {
        float length;
        float gap;
    };
    const VDasher::Dash *mDashArray;
    int                  mArraySize{0};
    VPointF              mCurPt;
    int                  mIndex{0}; /* index to the dash Array */
    float                mCurrentLength;
    bool                 mDiscard;
    float                mDashOffset{0};
    VPath                mResult;
    bool                 mStartNewSegment=true;
};

V_END_NAMESPACE

#endif  // VDASHER_H
