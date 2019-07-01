#include "matrix.h"

void eigen_vector(const mat3x3f_t& a, vec3f_t& eig) {
  vec3f_t b = signorm(vec3f_t(1, 5, 2));  // FIXME: Magic number
  for (size_t i = 0; i < 8; ++i) {
    b = signorm(a * b);
  }

  eig = b;
}
