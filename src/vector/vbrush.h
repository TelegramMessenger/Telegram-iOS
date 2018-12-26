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

#ifndef VBRUSH_H
#define VBRUSH_H

#include <vector>
#include "vglobal.h"
#include "vmatrix.h"
#include "vpoint.h"

V_BEGIN_NAMESPACE

typedef std::pair<float, VColor>   VGradientStop;
typedef std::vector<VGradientStop> VGradientStops;
class VGradient {
public:
    enum class Mode { Absolute, Relative };
    enum class Spread { Pad, Repeat, Reflect };
    enum class Type { Linear, Radial };
    VGradient(VGradient::Type type);
    void setStops(const VGradientStops &stops);
    void setAlpha(float alpha) {mAlpha = alpha;}
    float alpha() const {return mAlpha;}
    VGradient() = default;

public:
    static constexpr int colorTableSize = 1024;
    VGradient::Type      mType;
    VGradient::Spread    mSpread;
    VGradient::Mode      mMode;
    VGradientStops       mStops;
    float                mAlpha{1.0};
    union {
        struct {
            float x1, y1, x2, y2;
        } linear;
        struct {
            float cx, cy, fx, fy, cradius, fradius;
        } radial;
    };
    VMatrix mMatrix;
};

class VLinearGradient : public VGradient {
public:
    VLinearGradient(const VPointF &start, const VPointF &stop);
    VLinearGradient(float xStart, float yStart, float xStop, float yStop);
};

class VRadialGradient : public VGradient {
public:
    VRadialGradient(const VPointF &center, float cradius,
                    const VPointF &focalPoint, float fradius);
    VRadialGradient(float cx, float cy, float cradius, float fx, float fy,
                    float fradius);
};

class VBrush {
public:
    enum class Type { NoBrush, Solid, LinearGradient, RadialGradient, Texture };
    VBrush() = default;
    VBrush(const VColor &color);
    VBrush(const VGradient *gradient);
    VBrush(int r, int g, int b, int a);
    inline VBrush::Type type() const { return mType; }

public:
    VBrush::Type     mType{Type::NoBrush};
    VColor           mColor;
    const VGradient *mGradient{nullptr};
};

V_END_NAMESPACE

#endif  // VBRUSH_H
