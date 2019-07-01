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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include "vbrush.h"

V_BEGIN_NAMESPACE

VGradient::VGradient(VGradient::Type type)
    : mType(type),
      mSpread(VGradient::Spread::Pad),
      mMode(VGradient::Mode::Absolute)
{
    if (mType == Type::Linear)
        linear.x1 = linear.y1 = linear.x2 = linear.y2 = 0.0f;
    else
        radial.cx = radial.cy = radial.fx =
        radial.fy = radial.cradius = radial.fradius = 0.0f;
}

void VGradient::setStops(const VGradientStops &stops)
{
    mStops = stops;
}

VBrush::VBrush(const VColor &color) : mType(VBrush::Type::Solid), mColor(color)
{
}

VBrush::VBrush(int r, int g, int b, int a)
    : mType(VBrush::Type::Solid), mColor(r, g, b, a)

{
}

VBrush::VBrush(const VGradient *gradient)
{
    if (!gradient) return;

    mGradient = gradient;

    if (gradient->mType == VGradient::Type::Linear) {
        mType = VBrush::Type::LinearGradient;
    } else if (gradient->mType == VGradient::Type::Radial) {
        mType = VBrush::Type::RadialGradient;
    }
}

VBrush::VBrush(const VBitmap &texture)
{
    if (!texture.valid()) return;

    mType = VBrush::Type::Texture;
    mTexture = texture;
}

void VBrush::setMatrix(const VMatrix &m)
{
    mMatrix = m;
}

V_END_NAMESPACE
