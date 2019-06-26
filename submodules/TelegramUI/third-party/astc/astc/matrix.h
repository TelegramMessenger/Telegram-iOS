#ifndef ASTC_MATRIX_H_
#define ASTC_MATRIX_H_

#include <cstddef>

#include "vector.h"

struct mat3x3f_t {
 public:
  mat3x3f_t() {}

  mat3x3f_t(float m00,
            float m01,
            float m02,
            float m10,
            float m11,
            float m12,
            float m20,
            float m21,
            float m22) {
    m[0] = vec3f_t(m00, m01, m02);
    m[1] = vec3f_t(m10, m11, m12);
    m[2] = vec3f_t(m20, m21, m22);
  }

  const vec3f_t& row(size_t i) const { return m[i]; }

  float& at(size_t i, size_t j) { return m[i].components[j]; }
  const float& at(size_t i, size_t j) const { return m[i].components[j]; }

 private:
  vec3f_t m[3];
};

inline vec3f_t operator*(const mat3x3f_t& a, vec3f_t b) {
  vec3f_t tmp;
  tmp.x = dot(a.row(0), b);
  tmp.y = dot(a.row(1), b);
  tmp.z = dot(a.row(2), b);
  return tmp;
}

void eigen_vector(const mat3x3f_t& a, vec3f_t& eig);

#endif  // ASTC_MATRIX_H_
