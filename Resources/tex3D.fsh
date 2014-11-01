
#version 150

uniform sampler3D tex0;

in vec3 texCoord;
out vec4 outputFrag;

void main(){

    vec4 outColor;

    outColor = texture(tex0, texCoord);

    outputFrag = vec4(outColor.rgb, 0.5);

}


