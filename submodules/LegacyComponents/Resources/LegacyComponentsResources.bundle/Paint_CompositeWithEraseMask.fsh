precision highp float;

varying vec2 varTexcoord;

uniform sampler2D texture;
uniform sampler2D mask;

void main (void)
{
    gl_FragColor = texture2D(texture, varTexcoord.st, 0.0);
    float srcAlpha = 1.0 - texture2D(mask, varTexcoord.st, 0.0).a;
    gl_FragColor.a *= srcAlpha;
}
