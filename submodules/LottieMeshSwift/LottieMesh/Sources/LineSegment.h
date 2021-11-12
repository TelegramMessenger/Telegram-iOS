#pragma once

#include "Vec2.h"
#include <optional>

namespace crushedpixel {

template<typename Vec2>
struct LineSegment {
	LineSegment(const Vec2 &a, const Vec2 &b) :
			a(a), b(b) {}

	Vec2 a, b;

	/**
	 * @return A copy of the line segment, offset by the given vector.
	 */
	LineSegment operator+(const Vec2 &toAdd) const {
		return {Vec2Maths::add(a, toAdd), Vec2Maths::add(b, toAdd)};
	}

	/**
	 * @return A copy of the line segment, offset by the given vector.
	 */
	LineSegment operator-(const Vec2 &toRemove) const {
		return {Vec2Maths::subtract(a, toRemove), Vec2Maths::subtract(b, toRemove)};
	}

	/**
	 * @return The line segment's normal vector.
	 */
	Vec2 normal() const {
		auto dir = direction();

		// return the direction vector
		// rotated by 90 degrees counter-clockwise
		return {-dir.y, dir.x};
	}

	/**
	 * @return The line segment's direction vector.
	 */
	Vec2 direction(bool normalized = true) const {
		auto vec = Vec2Maths::subtract(b, a);

		return normalized
		       ? Vec2Maths::normalized(vec)
		       : vec;
	}

	static Vec2 intersection(const LineSegment &a, const LineSegment &b, bool infiniteLines, bool &success) {
        success = true;
        
		// calculate un-normalized direction vectors
		auto r = a.direction(false);
		auto s = b.direction(false);

		auto originDist = Vec2Maths::subtract(b.a, a.a);

		auto uNumerator = Vec2Maths::cross(originDist, r);
		auto denominator = Vec2Maths::cross(r, s);

		if (std::abs(denominator) < 0.0001f) {
			// The lines are parallel
            success = false;
            return Vec2();
		}

		// solve the intersection positions
		auto u = uNumerator / denominator;
		auto t = Vec2Maths::cross(originDist, s) / denominator;

		if (!infiniteLines && (t < 0 || t > 1 || u < 0 || u > 1)) {
			// the intersection lies outside of the line segments
            success = false;
            return Vec2();
		}

		// calculate the intersection point
		// a.a + r * t;
		return Vec2Maths::add(a.a, Vec2Maths::multiply(r, t));
	}
};


} // namespace crushedpixel
