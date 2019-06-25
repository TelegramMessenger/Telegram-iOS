#pragma once
#include "platform_gl.h"

typedef struct {
	GLuint program;

	GLint a_position_location;
	GLint a_texture_coordinates_location;
	GLint u_mvp_matrix_location;
	GLint u_texture_unit_location;
    GLint u_alpha_loaction;
} TextureProgram;

typedef struct {
	GLuint program;

	GLint a_position_location;
	GLint u_mvp_matrix_location;
	GLint u_color_location;
    GLint u_alpha_loaction;
} ColorProgram;

typedef struct {
	GLuint program;
    
	GLint a_position_location;
	GLint u_mvp_matrix_location;
	GLint a_color_location;
    GLint u_alpha_loaction;
} GradientProgram;




TextureProgram get_texture_program(GLuint program);
ColorProgram get_color_program(GLuint program);
GradientProgram get_gradient_program(GLuint program);