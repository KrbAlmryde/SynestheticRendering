#version 150

out vec4 finalColor;
uniform vec4 g_color;

void main() {
    //set every drawn pixel to white
    finalColor = g_color;
}