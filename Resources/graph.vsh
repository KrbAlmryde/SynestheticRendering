#version 150

in vec3 vertexPosition;
uniform mat4 model;
void main() {
    // does not alter the verticies at all
    gl_Position = model*vec4(vertexPosition, 1);
    gl_PointSize = 3.0;
}