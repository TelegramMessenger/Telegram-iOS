precision mediump float;

varying mediump vec2 varTexcoord;
uniform sampler2D texture;

void main()
{
    gl_FragColor = texture2D(texture, varTexcoord);
}
