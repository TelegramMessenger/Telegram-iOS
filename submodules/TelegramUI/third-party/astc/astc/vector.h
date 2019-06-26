#ifndef ASTC_VECTOR_H_
#define ASTC_VECTOR_H_

#include <algorithm>
#include <cmath>

#include "dcheck.h"

template <typename T>
union vec3_t {
 public:
  vec3_t() {}
  vec3_t(T x_, T y_, T z_) : x(x_), y(y_), z(z_) {}

  struct {
    T x, y, z;
  };
  struct {
    T r, g, b;
  };
  T components[3];
};

typedef vec3_t<float> vec3f_t;
typedef vec3_t<int> vec3i_t;

template <typename T>
vec3_t<T> operator+(vec3_t<T> a, vec3_t<T> b) {
  vec3_t<T> result;
  result.x = a.x + b.x;
  result.y = a.y + b.y;
  result.z = a.z + b.z;
  return result;
}

template <typename T>
vec3_t<T> operator-(vec3_t<T> a, vec3_t<T> b) {
  vec3_t<T> result;
  result.x = a.x - b.x;
  result.y = a.y - b.y;
  result.z = a.z - b.z;
  return result;
}

template <typename T>
vec3_t<T> operator*(vec3_t<T> a, vec3_t<T> b) {
  vec3_t<T> result;
  result.x = a.x * b.x;
  result.y = a.y * b.y;
  result.z = a.z * b.z;
  return result;
}

template <typename T>
vec3_t<T> operator*(vec3_t<T> a, T b) {
  vec3_t<T> result;
  result.x = a.x * b;
  result.y = a.y * b;
  result.z = a.z * b;
  return result;
}

template <typename T>
vec3_t<T> operator/(vec3_t<T> a, T b) {
  vec3_t<T> result;
  result.x = a.x / b;
  result.y = a.y / b;
  result.z = a.z / b;
  return result;
}

template <typename T>
vec3_t<T> operator/(vec3_t<T> a, vec3_t<T> b) {
  vec3_t<T> result;
  result.x = a.x / b.x;
  result.y = a.y / b.y;
  result.z = a.z / b.z;
  return result;
}

template <typename T>
bool operator==(vec3_t<T> a, vec3_t<T> b) {
  return a.x == b.x && a.y == b.y && a.z == b.z;
}

template <typename T>
bool operator!=(vec3_t<T> a, vec3_t<T> b) {
  return a.x != b.x || a.y != b.y || a.z != b.z;
}

template <typename T>
T dot(vec3_t<T> a, vec3_t<T> b) {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

template <typename T>
T quadrance(vec3_t<T> a) {
  return dot(a, a);
}

template <typename T>
T norm(vec3_t<T> a) {
  return static_cast<T>(sqrt(quadrance(a)));
}

template <typename T>
T distance(vec3_t<T> a, vec3_t<T> b) {
  return norm(a - b);
}

template <typename T>
T qd(vec3_t<T> a, vec3_t<T> b) {
  return quadrance(a - b);
}

template <typename T>
vec3_t<T> signorm(vec3_t<T> a) {
  T x = norm(a);
  DCHECK(x != 0.0);
  return a / x;
}

template <typename T>
vec3_t<T> vecmin(vec3_t<T> a, vec3_t<T> b) {
  vec3_t<T> result;
  result.x = std::min(a.x, b.x);
  result.y = std::min(a.y, b.y);
  result.z = std::min(a.z, b.z);
  return result;
}

template <typename T>
vec3_t<T> vecmax(vec3_t<T> a, vec3_t<T> b) {
  vec3_t<T> result;
  result.x = std::max(a.x, b.x);
  result.y = std::max(a.y, b.y);
  result.z = std::max(a.z, b.z);
  return result;
}

template <typename T>
T qd_to_line(vec3_t<T> m, vec3_t<T> k, T kk, vec3_t<T> p) {
  T t = dot(p - m, k) / kk;
  vec3_t<T> q = k * t + m;
  return qd(p, q);
}

#endif  // ASTC_VECTOR_H_
