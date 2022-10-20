precision highp float;

varying vec2 varTexcoord;

uniform sampler2D mask;
uniform vec4 color;

void main (void)
{
    vec3 maskColor = texture2D(mask, varTexcoord.st, 0.0).rgb;
    float srcAlpha = color.a * clamp(maskColor.r + maskColor.b, 0.0, 1.0);
    
    vec3 borderColor = vec3(1.0, 1.0, 1.0);
    //vec3 finalColor = mix(color.rgb, borderColor, maskColor.g);
    vec3 finalColor = mix(color.rgb, vec3(1.0, 1.0, 1.0), maskColor.b);
    
    gl_FragColor.rgb = (finalColor * srcAlpha) / srcAlpha;
    gl_FragColor.a = srcAlpha;

    gl_FragColor.rgb *= gl_FragColor.a;
}
