precision highp float;

varying vec2 varTexcoord;

uniform sampler2D texture;
uniform sampler2D mask;
uniform vec4 color;

void main (void)
{
    vec4 dst = texture2D(texture, varTexcoord.st, 0.0);
    float srcAlpha = color.a * texture2D(mask, varTexcoord.st, 0.0).a;
    
    float outAlpha = srcAlpha + dst.a * (1.0 - srcAlpha);
    
    gl_FragColor.rgb = (color.rgb * srcAlpha + dst.rgb * dst.a * (1.0 - srcAlpha)) / outAlpha;
    gl_FragColor.a = outAlpha;
}
