//
//  main.m
//  SynestheticRendering
//
//  Created by Kyle Reese Almryde on 10/28/14.
//  Copyright (c) 2014 Kyle Reese Almryde. All rights reserved.
//

#import <Aluminum/Aluminum.h>
#include "colorTable.hpp"
#include "TransferFunction.mm"


using namespace std;
using namespace glm;

class SynestheticRendering: public RendererOSX {
public:

    /* Definition of Global Vars */
    Texture tex,  // cube texture
            lut;  // lookup table

    Camera camera;

    Program rayShader,
            isoShader;

    ResourceHandler rh;

    TransferFunction tf;

    MeshData md;
    MeshBuffer cubeMB;
    vector <MeshBuffer> mbXSlice,
                        mbYSlice,
                        mbZSlice;

    // Setup our Matrices
    float tX, tY, tZ = 0.0;
    float rX, rY, rZ = 0.0;


    float iso = 40;
    float DELTA = 0.01;

    // Setup our Matrices
    mat4 Rx, Ry, Rz, Tr;
    mat4 M, MV, VP;
    mat4 MVP;
    vec3 camPos;

    GLuint  posLoc = 0,
            texCoordLoc = 1;

    int renderMode = 0;
    bool filtering = false;
    bool wrapping = false;

    const static int XDIM = 75;
    const static int YDIM = 75;
    const static int ZDIM = 75;
    const static int SIZE = XDIM*YDIM*ZDIM;

    //transfer function (lookup table) colour values
    const glm::vec4 jet_values[9]= {
        glm::vec4(0,0,0.5,0),
        glm::vec4(0,0,1,0.1),
        glm::vec4(0,0.5,1,0.3),
        glm::vec4(0,1,1,0.5),
        glm::vec4(0.5,1,0.5,0.75),
        glm::vec4(1,1,0,0.8),
        glm::vec4(1,0.5,0,0.6),
        glm::vec4(1,0,0,0.5),
        glm::vec4(0.5,0,0,0.0)
    };

    /*----------------------------------------------------------------------------------
     onCreate:

     ----------------------------------------------------------------------------------*/
    virtual void onCreate()
    {
        camera = Camera(radians(60.0), (float)width / (float)height, 0.01, 100.0).translateZ(-2);
        rh.loadProgram(rayShader, "raycast", posLoc, -1, -1, -1);
        rh.loadProgram(isoShader, "isoRay", posLoc, -1, -1, -1);
        
        LoadTextVolume("MaryShelleyFrankenstein.txt", tex);
        LoadTestVolume(tex);
        
        //        LoadTransferFunction();

        addCube(md, 1.0);
        cubeMB.init(MeshUtils::makeCube(0.5), 0, -1, -1, -1);

//        lut.updateData((GLfloat *)vowelTable);
    }


    /*----------------------------------------------------------------------------------
     onFrame:

     ----------------------------------------------------------------------------------*/
    virtual void onFrame() {
        handleKeys();
        handleMouse();

        if (camera.isTransformed) {
            camera.transform();
        }
        //set the model transform
        Rx = rotate(radians(rX), vec3(1.0,0.,0.));
        Ry = rotate(radians(rY), vec3(0.,1.0,0.));
        Rz = rotate(radians(rZ), vec3(0.,0.,1.));
        M = Rx * Ry * Rz;
        MV = camera.view * M;
        VP = camera.projection * camera.view;
        MVP = VP * M;

        //get the camera position
        camPos = glm::vec3(glm::inverse(MV) * glm::vec4(0, 0, 0, 1));

        glScissor(0, 0, width, height);
        glViewport(0, 0, (GLsizei) width, (GLsizei) height);

        switch (renderMode) {
            case 0:
                DrawRayCast(rayShader);;
                break;
            case 1:
                DrawISORayCast(isoShader);
                break;
            case 2:
                DrawRayCast(rayShader);
                break;
            default:
                break;
        }
    }



    /*----------------------------------------------------------------------------------
     LoadTextVolume:

     -string filename
     -Texture &tex
     -----------------------------------------------------------------------------------*/
    void LoadTextVolume(string filename, Texture &tex)
    {
        int i = 0;
        char c = ' ';
        vector<GLubyte> data(SIZE,0);
        ifstream infile(filename, ios::binary);

        while (infile >> c) {
            printf("%d, %c, %d, %f, %f",i, c, c, c / 128.0, (c / 128.0)*255);
            data[i] = (GLubyte)(( c / 128.0 ) * 255); // assign a color value to the char.
            printf("\tData[i]: %d\n", data[i]);
            if (i++ > SIZE) break;
        }

        tf.init(data);
        tex = Texture(data.data(), XDIM, YDIM, ZDIM, GL_RGBA, GL_RED, GL_UNSIGNED_BYTE);
        tex.wrapMode(GL_CLAMP_TO_EDGE);
        tex.minFilter(GL_LINEAR);
        tex.maxFilter(GL_LINEAR);
    }

    /*----------------------------------------------------------------------------------
     LoadTestVolume:

     -Texture &tex
     ----------------------------------------------------------------------------------*/
    void LoadTestVolume(Texture &tex)
    {
        GLubyte* data = new GLubyte[SIZE];
        vector<GLubyte> vdata(SIZE,0);
        for (int i = 0; i < SIZE; i++) {

            data[i] = (GLubyte) rand(); // assign a color value to the char.
            printf("\tData[i]: %d\n", data[i]);
        }
        delete[] data;
        tex = Texture(data, XDIM, YDIM, ZDIM, GL_RGBA, GL_RED, GL_UNSIGNED_BYTE);
    }


    /*----------------------------------------------------------------------------------
     createSlices:

     -int num
     ----------------------------------------------------------------------------------*/
    void createSlices(int num) {

        //if DEPTH_TEST is enables, must sort back to front

        int numSlices = num;
        mbXSlice.clear(); mbXSlice.resize(XDIM);
        mbYSlice.clear(); mbYSlice.resize(YDIM);
        mbZSlice.clear(); mbZSlice.resize(ZDIM);
        
        float dxPos = -1.0;
        float dxStep = 2.0 / (float)XDIM;
        
        
        
        float zSt = 1.0 / 2.0;  // Z-slice thickness?
        float zInc = (1.0) / ((float) numSlices - 1);  // Z Increment?

        float sz = 4.0; //0.5;  Size? Of something...

        float tczInc = 1.0 / ((float) numSlices - 1);


        for (int i = 0; i < numSlices; i++) {
            MeshData md = MeshUtils::makeRectangle(vec3(-sz, -sz, zSt - (zInc * i)), //
                                                   vec3(sz, sz, zSt - (zInc * i)),   //
                                                   vec3(-0.15, -0.15, tczInc * i),   //
                                                   vec3(1.15, 1.15, tczInc * i));      //

            mbXSlice[i].init(md, posLoc, -1, texCoordLoc, -1);
        }
    }

    /*----------------------------------------------------------------------------------
     DrawRayCast:

     -Program shader

     Performs Composite ray casting
     Uses Lookup table to define some of the colors
     ----------------------------------------------------------------------------------*/
    void DrawRayCast(Program shader)
    {
        glClearColor(0.5,0.1,0.4,0.5);

        glClear(GL_COLOR_BUFFER_BIT| GL_DEPTH_BUFFER_BIT);

        //enable blending and bind the cube vertex array object
        glEnable(GL_BLEND);

        //enable depth test
        glEnable(GL_DEPTH_TEST);

        //set the over blending function
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        shader.bind();
        {
            glUniformMatrix4fv(shader.uniform("MVP"), 1, 0, ptr(MVP));
            glUniform3fv(shader.uniform("camPos"),  1, ptr(camPos));
            glUniform3f(shader.uniform("step_size"), 1.f/XDIM, 1.f/YDIM, 1.f/ZDIM);
            glUniform1i(shader.uniform("volume"), 0);
            glUniform1i(shader.uniform("lut"), 1);


            tex.bind(GL_TEXTURE0);
            tf.bind(GL_TEXTURE1);
            {
                cubeMB.draw();
            }
            tex.unbind(GL_TEXTURE0);
            tf.unbind(GL_TEXTURE1);
        }
        shader.unbind();

        glDisable(GL_DEPTH_TEST);
    }

    /*----------------------------------------------------------------------------------
     DrawRayCast:

     -Program shader

     Performs ISO surface ray casting
     Uses Lookup table to define some of the colors
     ----------------------------------------------------------------------------------*/
    void DrawISORayCast(Program shader)
    {
        glClearColor(0.5,0.1,0.4,0.5);

        glClear(GL_COLOR_BUFFER_BIT| GL_DEPTH_BUFFER_BIT);

        //enable blending and bind the cube vertex array object
        glEnable(GL_BLEND);

        //enable depth test
        glEnable(GL_DEPTH_TEST);

        //set the over blending function
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        shader.bind();
        {
            glUniformMatrix4fv(shader.uniform("MVP"), 1, 0, ptr(MVP));
            glUniform3fv(shader.uniform("camPos"),  1, ptr(camPos));
            glUniform3f(shader.uniform("step_size"), 1.f/XDIM, 1.f/YDIM, 1.f/ZDIM);
            glUniform1f(shader.uniform("iso"), iso);
            glUniform1f(shader.uniform("DELTA"), DELTA);
            glUniform1i(shader.uniform("volume"), 0);
            glUniform1i(shader.uniform("lut"), 1);


            tex.bind(GL_TEXTURE0);
            tf.bind(GL_TEXTURE1);
            {
                cubeMB.draw();
            }
            tex.unbind(GL_TEXTURE0);
            tf.unbind(GL_TEXTURE1);
        }
        shader.unbind();

        glDisable(GL_DEPTH_TEST);
    }


    /*----------------------------------------------------------------------------------
     handleKeys:

     -----------------------------------------------------------------------------------*/
    virtual void handleKeys() {

        if (keysDown[kVK_ANSI_Equal]){
            keysDown[kVK_ANSI_Equal] = false;
            renderMode += 1;

            if(renderMode > 2)
                renderMode = 2;
            printf("renderMode: %d\n", renderMode);
        }

        if (keysDown[kVK_ANSI_Minus]){
            keysDown[kVK_ANSI_Minus] = false;
            renderMode -= 1;
            if(renderMode < 0)
                renderMode = 0;
            printf("renderMode: %d\n", renderMode);
        }


        if (keysDown[kVK_ANSI_Comma]){
            keysDown[kVK_ANSI_Comma] = false;
            iso -= 0.1;
            if(iso < 0)
                iso = 0;
            printf("iso Numerator value: %f\n", iso);
        }

        if (keysDown[kVK_ANSI_Slash]){
            keysDown[kVK_ANSI_Slash] = false;
            iso += 0.1;
            if(iso > 255.0)
                iso = 255.0;
            printf("iso Numerator value: %f\n", iso);
        }

        if (keysDown[kVK_ANSI_1]){
            keysDown[kVK_ANSI_1] = false;
            tf.setLUT((GLfloat*)jetTable);
        }

        if (keysDown[kVK_ANSI_2]){
            keysDown[kVK_ANSI_2] = false;
            tf.setLUT((GLfloat*)colorTable);
        }

        if (keysDown[kVK_ANSI_3]){
            keysDown[kVK_ANSI_3] = false;
            tf.setLUT((GLfloat*)vowelTable);
        }

        if (keysDown[kVK_ANSI_9]){
            keysDown[kVK_ANSI_9] = false;
            wrapping = !wrapping;
            
            if(wrapping){
                tex.wrapMode(GL_REPEAT);
            } else {
                tex.wrapMode(GL_CLAMP_TO_BORDER);
            }
            
        }

        
        if (keysDown[kVK_ANSI_0]){
            keysDown[kVK_ANSI_0] = false;
            filtering = !filtering;

            if(filtering){
                tex.minFilter(GL_LINEAR);
                tex.maxFilter(GL_LINEAR);
            } else {
                tex.minFilter(GL_NEAREST);
                tex.maxFilter(GL_NEAREST);
            }
        }

        if (keysDown[kVK_Space]){
            keysDown[kVK_Space] = false;
            rX = 0; tX = 0;
            rY = 0; tY = 0;
            rZ = 0; tZ = 0;
            camera.printCameraInfo();
        }

        if (keysDown[kVK_ANSI_W]) {
            keysDown[kVK_ANSI_W] = false;
            rX -= 1.0; // Up
            camera.printCameraInfo();
        }
        if (keysDown[kVK_ANSI_S]) {
            keysDown[kVK_ANSI_S] = false;
            rX += 1.0; // Up
            camera.printCameraInfo();
        } // down

        if (keysDown[kVK_ANSI_A]) {
            keysDown[kVK_ANSI_A] = false;
            rY -= 1.0; // Rotate right
            camera.printCameraInfo();
        }

        if (keysDown[kVK_ANSI_D]) {
            keysDown[kVK_ANSI_D] = false;
            rY += 1.0; // Rotate left
            camera.printCameraInfo();
        }

        if (keysDown[kVK_ANSI_E]) {
            keysDown[kVK_ANSI_E] = false;
            rZ -= 1.0; // left
            camera.printCameraInfo();
        }

        if (keysDown[kVK_ANSI_Q]) {
            keysDown[kVK_ANSI_Q] = false;
            rZ += 1.0; // right
            camera.printCameraInfo();
        }

        if (keysDown[kVK_ANSI_Z]) {
            keysDown[kVK_ANSI_Z] = false;
            camera.translateZ(0.01);   // + Zoom
            camera.printCameraInfo();
            printf("translate CameraZ, Z key!!");
        }
        if (keysDown[kVK_ANSI_X]) {
            keysDown[kVK_ANSI_X] = false;
            camera.translateZ(-0.01);  // - Zoom
            camera.printCameraInfo();
            printf("translate CameraX, X key!!");
        }


        if (keysDown[kVK_ANSI_L]) {
            keysDown[kVK_ANSI_L] = false;
            camera.translateX(-0.01);; // Up
            camera.printCameraInfo();
        }
        if (keysDown[kVK_ANSI_Quote]) {
            keysDown[kVK_ANSI_Quote] = false;
            camera.translateX(0.01); // Up
            camera.printCameraInfo();
        } // down

        if (keysDown[kVK_ANSI_O]) {
            keysDown[kVK_ANSI_O] = false;
            camera.translate(vec3(-0.01)); // Rotate right
            camera.printCameraInfo();
        }

        if (keysDown[kVK_ANSI_LeftBracket]) {
            keysDown[kVK_ANSI_LeftBracket] = false;
            camera.translate(vec3(0.01)); // Rotate left
            camera.printCameraInfo();
        }

        if (keysDown[kVK_ANSI_P]) {
            keysDown[kVK_ANSI_P] = false;
            camera.translateY(-0.01); // left
            camera.printCameraInfo();
        }

        if (keysDown[kVK_ANSI_Semicolon]) {
            keysDown[kVK_ANSI_Semicolon] = false;
            camera.translateY(0.01); // right
            camera.printCameraInfo();
        }

    }

    /*=============================
     *        handleMouse()       *
     =============================*/
    virtual void handleMouse() {
        bool movingLeft = false;
        bool movingRight = false;
        bool movingUp = false;
        bool movingDown = false;

        if (abs(mouseX - previousMouseX) > abs(mouseY - previousMouseY)) {
            if (mouseX < previousMouseX) movingLeft = true;
            else movingRight = true;
        } else {
            if (mouseY < previousMouseY) movingUp = true;
            else movingDown = true;

        }
        if (isDragging) {
            rX += 0.5;
            rY += 0.5;
            rZ += 0.5;


            if (movingLeft)
                rZ -= 2.0;
            else if (movingRight)
                rZ += 2.0;


            if (movingUp)
                rX += 2.0;
            else if (movingDown)
                rX -= 2.0;

            rX -= 0.5;
            rY -= 0.5;
            rZ -= 0.5;
        }

        if (isMoving)
            isMoving = !isMoving; //isn't a listener that can hear when a mouse *stops*?
    }

};


int main(int argc, const char * argv[]) {

    return SynestheticRendering().start();
}
