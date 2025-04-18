attribute vec4 inPosition;
attribute mediump vec4 inTexcoord;
varying mediump vec2 varTexcoord;

void main()
{
	gl_Position = inPosition;
	varTexcoord = inTexcoord.xy;
}

