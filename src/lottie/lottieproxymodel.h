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

#ifndef LOTTIEPROXYMODEL_H
#define LOTTIEPROXYMODEL_H

#include<bitset>
#include "lottiemodel.h"
#include "rlottie.h"

// Naive way to implement std::variant
// refactor it when we move to c++17
// users should make sure proper combination
// of id and value are passed while creating the object.
class LOTVariant
{
public:
    enum Type {Color, Point, Size, Float};
    LOTVariant(rlottie::Property prop, float  v):property_(prop),valueType_(Type::Float),value_(v){}
    LOTVariant(rlottie::Property prop, rlottie::Color  col):property_(prop),valueType_(Type::Color),color_(col){}
    LOTVariant(rlottie::Property prop, rlottie::Point  pt):property_(prop),valueType_(Type::Point),pos_(pt){}
    LOTVariant(rlottie::Property prop, rlottie::Size  sz):property_(prop),valueType_(Type::Size),size_(sz){}
    Type type() const {return valueType_;}
    rlottie::Property property() const {return property_;}
    float value() const {return value_;}
    rlottie::Color color() const {return color_;}
    rlottie::Point pos() const {return pos_;}
    rlottie::Size  size() const {return size_;}
public:
    rlottie::Property property_;
    Type  valueType_;
    union {
      float           value_;
      rlottie::Color  color_;
      rlottie::Point  pos_;
      rlottie::Size   size_;
    };
};

class LOTFilter
{
public:
    void addValue(LOTVariant &value)
    {
        uint index = static_cast<uint>(value.property());
        if (mBitset.test(index)) {
            for (uint i=0; i < mFilters.size(); i++ ) {
                if (mFilters[i].property() == value.property()) {
                    mFilters[i] = value;
                    break;
                }
            }
        } else {
            mBitset.set(index);
            mFilters.push_back(value);
        }
    }

    void removeValue(LOTVariant &value)
    {
        uint index = static_cast<uint>(value.property());
        if (mBitset.test(index)) {
            mBitset.reset(index);
            for (uint i=0; i < mFilters.size(); i++ ) {
                if (mFilters[i].property() == value.property()) {
                    mFilters.erase(mFilters.begin() + i);
                    break;
                }
            }
        }
    }
    bool hasFilter(rlottie::Property prop) const
    {
        return mBitset.test(static_cast<uint>(prop));
    }
    LottieColor color(rlottie::Property prop) const
    {
        rlottie::Color col = data(prop).color();
        return LottieColor(col.mr, col.mg, col.mb);
    }
    float opacity(rlottie::Property prop) const
    {
        float val = data(prop).value();
        return val/100;
    }
    float value(rlottie::Property prop) const
    {
        return data(prop).value();
    }
private:
    LOTVariant data(rlottie::Property prop) const
    {
        for (uint i=0; i < mFilters.size(); i++ ) {
            if (mFilters[i].property() == prop) {
                return mFilters[i];
            }
        }
        return LOTVariant(prop, 0);
    }
    std::vector<LOTVariant>    mFilters;
    std::bitset<32>            mBitset{0};
};

template <typename T>
class LOTProxyModel
{
public:
    LOTProxyModel(T *model): _modelData(model) {}
    LOTFilter& filter() {return mFilter;}
    const std::string & name() const {return _modelData->name();}
    LottieColor color(int frame) const
    {
        if (mFilter.hasFilter(rlottie::Property::StrokeColor)) {
            return mFilter.color(rlottie::Property::StrokeColor);
        }
        return _modelData->color(frame);
    }
    float opacity(int frame) const
    {
        if (mFilter.hasFilter(rlottie::Property::StrokeOpacity)) {
            return mFilter.opacity(rlottie::Property::StrokeOpacity);
        }
        return _modelData->opacity(frame);
    }
    float strokeWidth(int frame) const
    {
        if (mFilter.hasFilter(rlottie::Property::StrokeWidth)) {
            return mFilter.value(rlottie::Property::StrokeWidth);
        }
        return _modelData->strokeWidth(frame);
    }
    float meterLimit() const {return _modelData->meterLimit();}
    CapStyle capStyle() const {return _modelData->capStyle();}
    JoinStyle joinStyle() const {return _modelData->joinStyle();}
    bool hasDashInfo() const { return _modelData->hasDashInfo();}
    int getDashInfo(int frameNo, float *array) const {return _modelData->getDashInfo(frameNo, array);}

private:
    T                         *_modelData;
    LOTFilter                  mFilter;
};

template <>
class LOTProxyModel<LOTFillData>
{
public:
    LOTProxyModel(LOTFillData *model): _modelData(model) {}
    LOTFilter& filter() {return mFilter;}
    const std::string & name() const {return _modelData->name();}
    LottieColor color(int frame) const
    {
        if (mFilter.hasFilter(rlottie::Property::FillColor)) {
            return mFilter.color(rlottie::Property::FillColor);
        }
        return _modelData->color(frame);
    }
    float opacity(int frame) const
    {
        if (mFilter.hasFilter(rlottie::Property::FillOpacity)) {
            return mFilter.opacity(rlottie::Property::FillOpacity);
        }
        return _modelData->opacity(frame);
    }
    FillRule fillRule() const {return _modelData->fillRule();}
private:
    LOTFillData               *_modelData;
    LOTFilter                  mFilter;
};

#endif // LOTTIEITEM_H
