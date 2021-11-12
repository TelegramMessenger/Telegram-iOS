#ifndef Point_h
#define Point_h

#include <math.h>
#include <cmath>

namespace MeshGenerator {

struct Point {
    float x = 0.0f;
    float y = 0.0f;

    Point(float x_, float y_) :
    x(x_), y(y_) {
    }
    
    Point() : Point(0.0f, 0.0f) {
    }

    bool isEqual(Point const &other, float epsilon = 0.0001f) const {
        return std::abs(x - other.x) <= epsilon && std::abs(y - other.y) <= epsilon;
    }

    float distance(Point const &other) const {
        float dx = x - other.x;
        float dy = y - other.y;
        return sqrtf(dx * dx + dy * dy);
    }

    bool operator< (Point const &other) const {
        if (x < other.x) {
            return true;
        }
        if (x > other.x) {
            return false;
        }
        return y < other.y;
    }

    bool operator== (Point const &other) const {
        return isEqual(other);
    }
};

}

#endif
