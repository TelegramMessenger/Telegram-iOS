#include "program.h"
#include "platform_gl.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

TextureProgram get_texture_program(GLuint program)
{
	return (TextureProgram) {
			program,
			glGetAttribLocation(program, "a_Position"),
			glGetAttribLocation(program, "a_TextureCoordinates"),
			glGetUniformLocation(program, "u_MvpMatrix"),
			glGetUniformLocation(program, "u_TextureUnit"),
            glGetUniformLocation(program, "u_Alpha")};
}

ColorProgram get_color_program(GLuint program)
{
	return (ColorProgram) {
			program,
			glGetAttribLocation(program, "a_Position"),
			glGetUniformLocation(program, "u_MvpMatrix"),
			glGetUniformLocation(program, "u_Color"),
            glGetUniformLocation(program, "u_Alpha")};
}

GradientProgram get_gradient_program(GLuint program)
{
	return (GradientProgram) {
        program,
        glGetAttribLocation(program, "a_Position"),
        glGetUniformLocation(program, "u_MvpMatrix"),
        glGetAttribLocation(program, "a_Color"),
        glGetUniformLocation(program, "u_Alpha")};
}

#pragma clang diagnostic pop
