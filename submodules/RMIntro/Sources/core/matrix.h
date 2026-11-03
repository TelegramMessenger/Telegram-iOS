#include "linmath.h"
#include <math.h>
#include <string.h>

/* Adapted from Android's OpenGL Matrix.java. */

static inline void mat4x4_perspective(mat4x4 m, float y_fov_in_degrees, float aspect, float n, float f)
{
	const float angle_in_radians = (float) (y_fov_in_degrees * M_PI / 180.0);
	const float a = (float) (1.0 / tan(angle_in_radians / 2.0));

	m[0][0] = a / aspect;
	m[1][0] = 0.0f;
	m[2][0] = 0.0f;
	m[3][0] = 0.0f;

	m[1][0] = 0.0f;
	m[1][1] = a;
	m[1][2] = 0.0f;
	m[1][3] = 0.0f;

	m[2][0] = 0.0f;
	m[2][1] = 0.0f;
	m[2][2] = -((f + n) / (f - n));
	m[2][3] = -1.0f;

	m[3][0] = 0.0f;
	m[3][1] = 0.0f;
	m[3][2] = -((2.0f * f * n) / (f - n));
	m[3][3] = 0.0f;
}

static inline void mat4x4_translate_in_place(mat4x4 m, float x, float y, float z)
{
	int i;
    for (i = 0; i < 4; ++i) {
        m[3][i] += m[0][i] * x
        		+  m[1][i] * y
        		+  m[2][i] * z;
    }
}

static inline void mat4x4_look_at(mat4x4 m,
		float eyeX, float eyeY, float eyeZ,
		float centerX, float centerY, float centerZ,
		float upX, float upY, float upZ)
{
	// See the OpenGL GLUT documentation for gluLookAt for a description
	// of the algorithm. We implement it in a straightforward way:

	float fx = centerX - eyeX;
	float fy = centerY - eyeY;
	float fz = centerZ - eyeZ;

	// Normalize f
	vec3 f_vec = {fx, fy, fz};
	float rlf = 1.0f / vec3_len(f_vec);
	fx *= rlf;
	fy *= rlf;
	fz *= rlf;

	// compute s = f x up (x means "cross product")
	float sx = fy * upZ - fz * upY;
	float sy = fz * upX - fx * upZ;
	float sz = fx * upY - fy * upX;

	// and normalize s
	vec3 s_vec = {sx, sy, sz};
	float rls = 1.0f / vec3_len(s_vec);
	sx *= rls;
	sy *= rls;
	sz *= rls;

	// compute u = s x f
	float ux = sy * fz - sz * fy;
	float uy = sz * fx - sx * fz;
	float uz = sx * fy - sy * fx;

	m[0][0] = sx;
	m[0][1] = ux;
	m[0][2] = -fx;
	m[0][3] = 0.0f;

	m[1][0] = sy;
	m[1][1] = uy;
	m[1][2] = -fy;
	m[1][3] = 0.0f;

	m[2][0] = sz;
	m[2][1] = uz;
	m[2][2] = -fz;
	m[2][3] = 0.0f;

	m[3][0] = 0.0f;
	m[3][1] = 0.0f;
	m[3][2] = 0.0f;
	m[3][3] = 1.0f;

	mat4x4_translate_in_place(m, -eyeX, -eyeY, -eyeZ);
}
