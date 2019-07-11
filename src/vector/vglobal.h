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

#ifndef VGLOBAL_H
#define VGLOBAL_H

#include <cmath>
#include <cstdint>
#include <iostream>
#include <type_traits>
#include <utility>

using uint   = uint32_t;
using ushort = uint16_t;
using uchar  = uint8_t;

#if !defined(V_NAMESPACE)

#define V_USE_NAMESPACE
#define V_BEGIN_NAMESPACE
#define V_END_NAMESPACE

#else /* user namespace */

#define V_USE_NAMESPACE using namespace ::V_NAMESPACE;
#define V_BEGIN_NAMESPACE namespace V_NAMESPACE {
#define V_END_NAMESPACE }

#endif

#ifndef __has_attribute
# define __has_attribute(x) 0
#endif /* !__has_attribute */

#if __has_attribute(unused)
# define V_UNUSED __attribute__((__unused__))
#else
# define V_UNUSED
#endif /* V_UNUSED */

#if __has_attribute(warn_unused_result)
# define V_REQUIRED_RESULT __attribute__((__warn_unused_result__))
#else
# define V_REQUIRED_RESULT
#endif /* V_REQUIRED_RESULT */

#define V_CONSTEXPR constexpr
#define V_NOTHROW noexcept

#include "vdebug.h"

#if __GNUC__ >= 7
#define VECTOR_FALLTHROUGH __attribute__ ((fallthrough));
#else
#define VECTOR_FALLTHROUGH
#endif

#include <atomic>
class RefCount {
public:
    explicit RefCount(int i) : atomic(i) {}
    inline bool ref()
    {
        int count = atomic.load();
        if (count == 0)  // !isSharable
            return false;
        if (count != -1)  // !isStatic
            atomic.fetch_add(1);
        return true;
    }
    inline bool deref()
    {
        int count = atomic.load();
        if (count == 0)  // !isSharable
            return false;
        if (count == -1)  // isStatic
            return true;
        atomic.fetch_sub(1);
        return (--count == 0);
    }
    bool isShared() const
    {
        int count = atomic.load();
        return (count != 1) && (count != 0);
    }
    bool isStatic() const
    {
        // Persistent object, never deleted
        int count = atomic.load();
        return count == -1;
    }
    inline int count() const { return atomic; }
    void       setOwned() { atomic.store(1); }

private:
    std::atomic<int> atomic;
};

template <typename T>
V_CONSTEXPR inline const T &vMin(const T &a, const T &b)
{
    return (a < b) ? a : b;
}
template <typename T>
V_CONSTEXPR inline const T &vMax(const T &a, const T &b)
{
    return (a < b) ? b : a;
}

static const double EPSILON_DOUBLE = 0.000000000001f;
static const float  EPSILON_FLOAT = 0.000001f;

static inline bool vCompare(float p1, float p2)
{
    return (std::abs(p1 - p2) < EPSILON_FLOAT);
}

static inline bool vIsZero(float f)
{
    return (std::abs(f) <= EPSILON_FLOAT);
}

static inline bool vIsZero(double f)
{
    return (std::abs(f) <= EPSILON_DOUBLE);
}

class vFlagHelper {
    int i;

public:
    explicit constexpr inline vFlagHelper(int ai) noexcept : i(ai) {}
    constexpr inline operator int() const noexcept { return i; }

    explicit constexpr inline vFlagHelper(uint ai) noexcept : i(int(ai)) {}
    explicit constexpr inline vFlagHelper(short ai) noexcept : i(int(ai)) {}
    explicit constexpr inline vFlagHelper(ushort ai) noexcept : i(int(uint(ai))) {}
    constexpr inline operator uint() const noexcept { return uint(i); }
};

template <typename Enum>
class vFlag {
public:
    static_assert(
        (sizeof(Enum) <= sizeof(int)),
        "vFlag only supports int as storage so bigger type will overflow");
    static_assert((std::is_enum<Enum>::value),
                  "vFlag is only usable on enumeration types.");

    using Int = typename std::conditional<
        std::is_unsigned<typename std::underlying_type<Enum>::type>::value,
        unsigned int, signed int>::type;

    using  enum_type = Enum;
    // compiler-generated copy/move ctor/assignment operators are fine!

    vFlag() = default;
    constexpr vFlag(Enum f) noexcept : i(Int(f)) {}
    explicit constexpr vFlag(vFlagHelper f) noexcept : i(f) {}

    inline vFlag &operator&=(int mask) noexcept
    {
        i &= mask;
        return *this;
    }
    inline vFlag &operator&=(uint mask) noexcept
    {
        i &= mask;
        return *this;
    }
    inline vFlag &operator&=(Enum mask) noexcept
    {
        i &= Int(mask);
        return *this;
    }
    inline vFlag &operator|=(vFlag f) noexcept
    {
        i |= f.i;
        return *this;
    }
    inline vFlag &operator|=(Enum f) noexcept
    {
        i |= Int(f);
        return *this;
    }
    inline vFlag &operator^=(vFlag f) noexcept
    {
        i ^= f.i;
        return *this;
    }
    inline vFlag &operator^=(Enum f) noexcept
    {
        i ^= Int(f);
        return *this;
    }

    constexpr inline operator Int() const noexcept { return i; }

    constexpr inline vFlag operator|(vFlag f) const
    {
        return vFlag(vFlagHelper(i | f.i));
    }
    constexpr inline vFlag operator|(Enum f) const noexcept
    {
        return vFlag(vFlagHelper(i | Int(f)));
    }
    constexpr inline vFlag operator^(vFlag f) const noexcept
    {
        return vFlag(vFlagHelper(i ^ f.i));
    }
    constexpr inline vFlag operator^(Enum f) const noexcept
    {
        return vFlag(vFlagHelper(i ^ Int(f)));
    }
    constexpr inline vFlag operator&(int mask) const noexcept
    {
        return vFlag(vFlagHelper(i & mask));
    }
    constexpr inline vFlag operator&(uint mask) const noexcept
    {
        return vFlag(vFlagHelper(i & mask));
    }
    constexpr inline vFlag operator&(Enum f) const noexcept
    {
        return vFlag(vFlagHelper(i & Int(f)));
    }
    constexpr inline vFlag operator~() const noexcept
    {
        return vFlag(vFlagHelper(~i));
    }

    constexpr inline bool operator!() const noexcept { return !i; }

    constexpr inline bool testFlag(Enum f) const noexcept
    {
        return (i & Int(f)) == Int(f) && (Int(f) != 0 || i == Int(f));
    }
    inline vFlag &setFlag(Enum f, bool on = true) noexcept
    {
        return on ? (*this |= f) : (*this &= ~f);
    }

    Int i{0};
};

class VColor {
public:
    VColor() = default;
    explicit VColor(uchar red, uchar green, uchar blue, uchar alpha = 255) noexcept
        :a(alpha), r(red), g(green), b(blue){}
    inline uchar  red() const noexcept { return r; }
    inline uchar  green() const noexcept { return g; }
    inline uchar  blue() const noexcept { return b; }
    inline uchar  alpha() const noexcept { return a; }
    inline void setRed(uchar red) noexcept { r = red; }
    inline void setGreen(uchar green) noexcept { g = green; }
    inline void setBlue(uchar blue) noexcept { b = blue; }
    inline void setAlpha(uchar alpha) noexcept { a = alpha; }
    inline bool isOpaque() const { return a == 255; }
    inline bool operator==(const VColor &o) const
    {
        return ((a == o.a) && (r == o.r) && (g == o.g) && (b == o.b));
    }
    uint premulARGB() const
    {
        int pr = (r * a) / 255;
        int pg = (g * a) / 255;
        int pb = (b * a) / 255;
        return uint((a << 24) | (pr << 16) | (pg << 8) | (pb));
    }

    uint premulARGB(float opacity) const
    {
        int alpha = int(a * opacity);
        int pr = (r * alpha) / 255;
        int pg = (g * alpha) / 255;
        int pb = (b * alpha) / 255;
        return uint((alpha << 24) | (pr << 16) | (pg << 8) | (pb));
    }

public:
    uchar a{0};
    uchar r{0};
    uchar g{0};
    uchar b{0};
};

enum class FillRule: unsigned char { EvenOdd, Winding };
enum class JoinStyle: unsigned char { Miter, Bevel, Round };
enum class CapStyle: unsigned char { Flat, Square, Round };

#ifndef V_CONSTRUCTOR_FUNCTION
#define V_CONSTRUCTOR_FUNCTION0(AFUNC)            \
    namespace {                                   \
    static const struct AFUNC##_ctor_class_ {     \
        inline AFUNC##_ctor_class_() { AFUNC(); } \
    } AFUNC##_ctor_instance_;                     \
    }

#define V_CONSTRUCTOR_FUNCTION(AFUNC) V_CONSTRUCTOR_FUNCTION0(AFUNC)
#endif

#endif  // VGLOBAL_H
