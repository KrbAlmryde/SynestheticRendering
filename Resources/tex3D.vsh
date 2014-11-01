

#version 150

uniform mat4 model;
uniform mat4 VP;


in vec4 vertexPosition;
in vec4 vertexTexCoord;

out vec3 texCoord;

void main() {
  texCoord = (model * vertexTexCoord).xyz;
//  gl_Position = proj * view * model * vertexPosition;
  gl_Position = VP * vertexPosition;

}

