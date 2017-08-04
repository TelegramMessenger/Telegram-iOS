precision highp float;

varying vec2 varTexcoord;

uniform sampler2D texture;

void main (void)
{
    gl_FragColor = texture2D(texture, varTexcoord.st, 0.0);
}