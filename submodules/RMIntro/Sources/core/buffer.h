#include "platform_gl.h"

#define BUFFER_OFFSET(i) ((void*)(i))

GLuint create_vbo(const GLsizeiptr size, const GLvoid* data, const GLenum usage);
GLuint create_vbo2(const GLsizeiptr vertex_data_size, const GLvoid* vertex_data, const GLsizeiptr color_data_size, const GLvoid* color_data, const GLenum usage);