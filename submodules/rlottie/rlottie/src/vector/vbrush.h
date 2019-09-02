/* 
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifndef VBRUSH_H
#define VBRUSH_H

#include <vector>
#include "vglobal.h"
#include "vmatrix.h"
#include "vpoint.h"
#include "vbitmap.h"

V_BEGIN_NAMESPACE

using VGradientStop = std::pair<float, VColor>;
using VGradientStops = std::vector<VGradientStop>;
class VGradient {
public:
    enum class Mode { Absolute, Relative };
    enum class Spread { Pad, Repeat, Reflect };
    enum class Type { Linear, Radial };
    explicit VGradient(VGradient::Type type);
    void setStops(const VGradientStops &stops);
    void setAlpha(float alpha) {mAlpha = alpha;}
    float alpha() const {return mAlpha;}

public:
    static constexpr int colorTableSize = 1024;
    VGradient::Type      mType{Type::Linear};
    VGradient::Spread    mSpread{Spread::Pad};
    VGradient::Mode      mMode{Mode::Absolute};
    VGradientStops       mStops;
    float                mAlpha{1.0};
    struct Linear{
        float x1{0}, y1{0}, x2{0}, y2{0};
    };
    struct Radial{
        float cx{0}, cy{0}, fx{0}, fy{0}, cradius{0}, fradius{0};
    };
    union {
        Linear linear;
        Radial radial;
    };
    VMatrix mMatrix;
};

class VBrush {
public:
    enum class Type { NoBrush, Solid, LinearGradient, RadialGradient, Texture };
    VBrush() = default;
    explicit VBrush(const VColor &color);
    explicit VBrush(const VGradient *gradient);
    explicit VBrush(uchar r, uchar g, uchar b, uchar a);
    explicit VBrush(const VBitmap &texture);
    inline VBrush::Type type() const { return mType; }
    void setMatrix(const VMatrix &m);
public:
    VBrush::Type     mType{Type::NoBrush};
    VColor           mColor;
    const VGradient *mGradient{nullptr};
    VBitmap          mTexture;
    VMatrix          mMatrix;
};

V_END_NAMESPACE

#endif  // VBRUSH_H
