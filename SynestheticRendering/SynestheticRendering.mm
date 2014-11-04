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

    const int XDIM = 75;
    const int YDIM = 75;
    const int ZDIM = 75;
    const int SIZE = XDIM*YDIM*ZDIM;
    const int MAX_SLICES = ZDIM * 2;
    
    //for floating point inaccuracy
    const float EPSILON = 0.0001f;

    
    /* Definition of Global Vars */
    Texture tex,  // cube texture
            lut;  // lookup table

    Camera camera;

    Program rayShader,
            isoShader,
            sliceShader;

    ResourceHandler rh;

    TransferFunction tf;

    MeshData md;
    MeshBuffer cubeMB, sliceMB;
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

    vec3 camPos, viewDir;  // Camera Position and View direction, respectively

    GLuint  posLoc = 0,
            texCoordLoc = 1;
    
    int num_slices = 72;
    int renderMode = 0;
    bool filtering = false;
    bool wrapping = false;
    bool bViewRotated = false;

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

    
    //unit cube edges
    int edgeList[8][12] = {
        { 0,1,5,6,   4,8,11,9,  3,7,2,10 }, // v0 is front
        { 0,4,3,11,  1,2,6,7,   5,9,8,10 }, // v1 is front
        { 1,5,0,8,   2,3,7,4,   6,10,9,11}, // v2 is front
        { 7,11,10,8, 2,6,1,9,   3,0,4,5  }, // v3 is front
        { 8,5,9,1,   11,10,7,6, 4,3,0,2  }, // v4 is front
        { 9,6,10,2,  8,11,4,7,  5,0,1,3  }, // v5 is front
        { 9,8,5,4,   6,1,2,0,   10,7,11,3}, // v6 is front
        { 10,9,6,5,  7,2,3,1,   11,4,8,0 }  // v7 is front
    };
    
    const int edges[12][2]= {{0,1},{1,2},{2,3},{3,0},{0,4},{1,5},{2,6},{3,7},{4,5},{5,6},{6,7},{7,4}};

    
    /*----------------------------------------------------------------------------------
     onCreate:

     ----------------------------------------------------------------------------------*/
    virtual void onCreate()
    {
        
        rh.loadProgram(rayShader, "raycast", posLoc, -1, -1, -1);
        rh.loadProgram(isoShader, "isoRay", posLoc, -1, -1, -1);
        rh.loadProgram(sliceShader, "tex3D", posLoc, -1, -1, -1);
        
        
        camera = Camera(radians(60.0), (float)width / (float)height, 0.01, 100.0).translateZ(-2);
        
        Rx = rotate(radians(rX), vec3(1.0,0.,0.));
        Ry = rotate(radians(rY), vec3(0.,1.0,0.));
        Rz = rotate(radians(rZ), vec3(0.,0.,1.));
        M = Rx * Ry * Rz;
        MV = camera.view * M;
        VP = camera.projection * camera.view;
        MVP = VP * M;

        //get the camera position
        camPos = glm::vec3(glm::inverse(MV) * glm::vec4(0, 0, 0, 1));
        //get the current view direction vector
        viewDir = -glm::vec3(MV[0][2], MV[1][2], MV[2][2]);

//        LoadTextVolume("MaryShelleyFrankenstein.txt", tex);
        LoadTestVolume(tex);

        addCube(md, 0.5);
        cubeMB.init(md, posLoc, -1, -1, -1);
        sliceMB.init(md, posLoc, -1, -1, -1);
        
//        createSlices();
        SliceVolume();
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
        //get the current view direction vector
        viewDir = -glm::vec3(MV[0][2], MV[1][2], MV[2][2]);

        glScissor(0, 0, width, height);
        glViewport(0, 0, (GLsizei) width, (GLsizei) height);

        if(bViewRotated)
        {
            SliceVolume();
        }
        
        switch (renderMode) {
            case 0:
                DrawRayCast(rayShader);;
                break;
            case 1:
                DrawISORayCast(isoShader);
                break;
            case 2:
                DrawSliceVolume(sliceShader);
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
        vector<GLubyte> data(SIZE,0);
        for (int i = 0; i < SIZE; i++) {

            data[i] = (GLubyte) rand(); // assign a color value to the char.
            printf("\tData[i]: %d\n", data[i]);
        }
        tf.init(data);
        tex = Texture(data.data(), XDIM, YDIM, ZDIM, GL_RGBA, GL_RED, GL_UNSIGNED_BYTE);
    }


    /*----------------------------------------------------------------------------------
     createSlices:

     -int num
     ----------------------------------------------------------------------------------*/
    void createSlices() {

        //if DEPTH_TEST is enables, must sort back to front
        mbXSlice.clear(); mbXSlice.resize(num_slices);
        mbYSlice.clear(); mbYSlice.resize(num_slices);
        mbZSlice.clear(); mbZSlice.resize(num_slices);
        
        float dxPos = -1.0;
        float dxStep = 2.0 / (float)num_slices;
        
        for (int slice = 0; slice < num_slices; slice++) {
            MeshData mdX = MeshUtils::makeRectangle(vec3(dxPos, -1.0, -1.0), vec3(dxPos, -1.0, 1.0), vec3(dxPos, 1.0, 1.0), vec3(dxPos, 1.0, -1.0));
            MeshData mdY = MeshUtils::makeRectangle(vec3(-1.0, dxPos, -1.0), vec3(-1.0, dxPos, 1.0), vec3(1.0, dxPos, 1.0), vec3(1.0, dxPos, -1.0));
            MeshData mdZ = MeshUtils::makeRectangle(vec3(-1.0, -1.0, dxPos), vec3(-1.0, 1.0, dxPos), vec3(1.0, 1.0, dxPos), vec3(1.0, -1.0, dxPos));
            mbXSlice[slice].init(mdX, posLoc, -1, texCoordLoc, -1);
            mbYSlice[slice].init(mdY, posLoc, -1, texCoordLoc, -1);
            mbZSlice[slice].init(mdZ, posLoc, -1, texCoordLoc, -1);
            dxPos += dxStep;
        }
    }
    
    
    //main slicing function
    void SliceVolume() {
        MeshData slice;
        
        //get the max and min distance of each vertex of the unit cube in the viewing direction
        float max_dist = glm::dot(viewDir, md.vertices()[0]);
        float min_dist = max_dist;
        int max_index = 0;
//        int count = 0;
        
        for(int i=1;i<8;i++) {
            //get the distance between the current unit cube vertex and the view vector by dot product
            float dist = glm::dot(viewDir, md.vertices()[i]);
            
            //if distance is > max_dist, store the value and index
            if(dist > max_dist) {
                max_dist = dist;
                max_index = i;
            }
            
            //if distance is < min_dist, store the value
            if(dist<min_dist)
                min_dist = dist;
        }
        
        //find tha abs maximum of the view direction vector
//        int max_dim = FindAbsMax(viewDir);
        
        //expand it a little bit
        min_dist -= EPSILON;
        max_dist += EPSILON;
        
        //local variables to store the start, direction vectors, lambda intersection values
        glm::vec3 vecStart[12];
        glm::vec3 vecDir[12];
        float lambda[12];
        float lambda_inc[12];
        float denom = 0;
        
        //set the minimum distance as the plane_dist
        //subtract the max and min distances and divide by the total number of slices
        //to get the plane increment
        float plane_dist = min_dist;
        float plane_dist_inc = (max_dist-min_dist)/float(num_slices);
        
        //for all edges
        for(int i=0;i<12;i++) {
            //get the start position vertex by table lookup
            vecStart[i] = md.vertices()[edges[edgeList[max_index][i]][0]];
            
            //get the direction by table lookup
            vecDir[i] = md.vertices()[edges[edgeList[max_index][i]][1]]-vecStart[i];
            
            //do a dot of vecDir with the view direction vector
            denom = glm::dot(vecDir[i], viewDir);
            
            //determine the plane intersection parameter (lambda) and
            //plane intersection parameter increment (lambda_inc)
            if (1.0 + denom != 1.0) {
                lambda_inc[i] =  plane_dist_inc/denom;
                lambda[i]     = (plane_dist - glm::dot(vecStart[i],viewDir))/denom;
            } else {
                lambda[i]     = -1.0;
                lambda_inc[i] =  0.0;
            }
        }
        
        //local variables to store the intesected points
        //note that for a plane and sub intersection, we can have
        //a minimum of 3 and a maximum of 6 vertex polygon
        glm::vec3 intersection[6];
        float dL[12];
        
        //loop through all slices
        for(int i=num_slices-1;i>=0;i--) {
            
            //determine the lambda value for all edges
            for(int e = 0; e < 12; e++)
            {
                dL[e] = lambda[e] + i*lambda_inc[e];
            }
            
            //if the values are between 0-1, we have an intersection at the current edge
            //repeat the same for all 12 edges
            if  ((dL[0] >= 0.0) && (dL[0] < 1.0))	{
                intersection[0] = vecStart[0] + dL[0]*vecDir[0];
            }
            else if ((dL[1] >= 0.0) && (dL[1] < 1.0))	{
                intersection[0] = vecStart[1] + dL[1]*vecDir[1];
            }
            else if ((dL[3] >= 0.0) && (dL[3] < 1.0))	{
                intersection[0] = vecStart[3] + dL[3]*vecDir[3];
            }
            else continue;
            
            if ((dL[2] >= 0.0) && (dL[2] < 1.0)){
                intersection[1] = vecStart[2] + dL[2]*vecDir[2];
            }
            else if ((dL[0] >= 0.0) && (dL[0] < 1.0)){
                intersection[1] = vecStart[0] + dL[0]*vecDir[0];
            }
            else if ((dL[1] >= 0.0) && (dL[1] < 1.0)){
                intersection[1] = vecStart[1] + dL[1]*vecDir[1];
            } else {
                intersection[1] = vecStart[3] + dL[3]*vecDir[3];
            }
            
            if  ((dL[4] >= 0.0) && (dL[4] < 1.0)){
                intersection[2] = vecStart[4] + dL[4]*vecDir[4];
            }
            else if ((dL[5] >= 0.0) && (dL[5] < 1.0)){
                intersection[2] = vecStart[5] + dL[5]*vecDir[5];
            } else {
                intersection[2] = vecStart[7] + dL[7]*vecDir[7];
            }
            if	((dL[6] >= 0.0) && (dL[6] < 1.0)){
                intersection[3] = vecStart[6] + dL[6]*vecDir[6];
            }
            else if ((dL[4] >= 0.0) && (dL[4] < 1.0)){
                intersection[3] = vecStart[4] + dL[4]*vecDir[4];
            }
            else if ((dL[5] >= 0.0) && (dL[5] < 1.0)){
                intersection[3] = vecStart[5] + dL[5]*vecDir[5];
            } else {
                intersection[3] = vecStart[7] + dL[7]*vecDir[7];
            }
            if	((dL[8] >= 0.0) && (dL[8] < 1.0)){
                intersection[4] = vecStart[8] + dL[8]*vecDir[8];
            }
            else if ((dL[9] >= 0.0) && (dL[9] < 1.0)){
                intersection[4] = vecStart[9] + dL[9]*vecDir[9];
            } else {
                intersection[4] = vecStart[11] + dL[11]*vecDir[11];
            }
            
            if ((dL[10]>= 0.0) && (dL[10]< 1.0)){
                intersection[5] = vecStart[10] + dL[10]*vecDir[10];
            }
            else if ((dL[8] >= 0.0) && (dL[8] < 1.0)){
                intersection[5] = vecStart[8] + dL[8]*vecDir[8];
            }
            else if ((dL[9] >= 0.0) && (dL[9] < 1.0)){
                intersection[5] = vecStart[9] + dL[9]*vecDir[9];
            } else {
                intersection[5] = vecStart[11] + dL[11]*vecDir[11];
            }
            
            //after all 6 possible intersection vertices are obtained,
            //we calculated the proper polygon indices by using indices of a triangular fan
            int indices[]={0,1,2, 0,2,3, 0,3,4, 0,4,5};
            
            //using the indices, pass the intersection vertices to the vTextureSlices vector
            for(int i=0;i<12;i++)
                slice.vertex(intersection[indices[i]]);
        }
        
        //update buffer object with the new vertices
        sliceMB.update(slice);
        
//        glBindBuffer(GL_ARRAY_BUFFER, tex.id());
//        glBufferSubData(GL_ARRAY_BUFFER, 0,  sizeof(vTextureSlices), &(vTextureSlices[0].x));
    }

    /*----------------------------------------------------------------------------------
     DrawRayCast:

     -Program shader

     Performs Composite ray casting
     Uses Lookup table to define some of the colors
     ----------------------------------------------------------------------------------*/
    void DrawRayCast(Program shader)
    {
        glClearColor(0.5,0.5,1,1);

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
     DrawISORayCast:

     -Program shader

     Performs ISO surface ray casting
     Uses Lookup table to define some of the colors
     ----------------------------------------------------------------------------------*/
    void DrawISORayCast(Program shader)
    {
        glClearColor(0.5,0.5,1,1);

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
     DrawSlices:
     
     -Program shader
     
     Performs rendering to Texture via Proxy geometry
     Uses Lookup table to define some of the colors
     ----------------------------------------------------------------------------------*/
    void DrawSliceVolume(Program shader)
    {
        glClearColor(0.5,0.5,1,1);
        
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
            glUniform1i(shader.uniform("volume"), 0);
            glUniform1i(shader.uniform("lut"), 1);
            
            
            tex.bind(GL_TEXTURE0);
            tf.bind(GL_TEXTURE1);
            {
                sliceMB.draw();
            }
            tex.unbind(GL_TEXTURE0);
            tf.unbind(GL_TEXTURE1);
        }
        shader.unbind();
        
        glDisable(GL_DEPTH_TEST);
    }
    /*----------------------------------------------------------------------------------
     DrawSlices:
     
     -Program shader
     
     Performs rendering to Texture via Proxy geometry
     Uses Lookup table to define some of the colors
     ----------------------------------------------------------------------------------*/
//    void DrawSlices(Program shader)
//    {
//        glClearColor(0.5,0.5,1,1);
//        
//        glClear(GL_COLOR_BUFFER_BIT| GL_DEPTH_BUFFER_BIT);
//        
//        //enable blending and bind the cube vertex array object
//        glEnable(GL_BLEND);
//        
//        //enable depth test
//        glEnable(GL_DEPTH_TEST);
//        
//        //set the over blending function
//        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
//        
//        shader.bind();
//        {
//            glUniformMatrix4fv(shader.uniform("MVP"), 1, 0, ptr(MVP));
//            glUniform1i(shader.uniform("volume"), 0);
//            glUniform1i(shader.uniform("lut"), 1);
//            
//            
//            tex.bind(GL_TEXTURE0);
//            tf.bind(GL_TEXTURE1);
//            {
//                for (int i = 0; i < num_slices; i++) {
//                    mbXSlice[i].draw();
//                }
//            }
//            tex.unbind(GL_TEXTURE0);
//            tf.unbind(GL_TEXTURE1);
//        }
//        shader.unbind();
//        
//        glDisable(GL_DEPTH_TEST);
//    }
    /*----------------------------------------------------------------------------------
     handleKeys:

     -----------------------------------------------------------------------------------*/
    virtual void handleKeys() {

        if (keysDown[kVK_ANSI_Equal]){
            keysDown[kVK_ANSI_Equal] = false;
            num_slices += 1;
            num_slices = std::min(MAX_SLICES, std::max(num_slices,3));
            printf("num_slices: %d\n", num_slices);
            SliceVolume();
        }
        
        if (keysDown[kVK_ANSI_Minus]){
            keysDown[kVK_ANSI_Minus] = false;
            num_slices -= 1;
            num_slices = std::min(MAX_SLICES, std::max(num_slices,3));
            printf("num_slices: %d\n", num_slices);
            SliceVolume();
        }

        
        
        if (keysDown[kVK_ANSI_RightBracket]){
            keysDown[kVK_ANSI_RightBracket] = false;
            renderMode += 1;

            if(renderMode > 2)
                renderMode = 0;
            printf("renderMode: %d\n", renderMode);
        }

        if (keysDown[kVK_ANSI_LeftBracket]){
            keysDown[kVK_ANSI_LeftBracket] = false;
            renderMode -= 1;
            if(renderMode < 0)
                renderMode = 2;
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
            bViewRotated = true;

            if (movingLeft)
                rZ -= 2.0;
            else if (movingRight)
                rZ += 2.0;


            if (movingUp){
                rX += 2.0;
                bViewRotated = false;
            }
            else if (movingDown)
                rX -= 2.0;

            rX -= 0.5;
            rY -= 0.5;
            rZ -= 0.5;
        }

        if (isMoving)
            isMoving = !isMoving; //isn't a listener that can hear when a mouse *stops*?
    }

    
//private:
//
//    //function to get the max (abs) dimension of the given vertex v
//    int FindAbsMax(glm::vec3 v) {
//        v = glm::abs(v);
//        int max_dim = 0;
//        float val = v.x;
//        if(v.y>val) {
//            val = v.y;
//            max_dim = 1;
//        }
//        if(v.z > val) {
//            val = v.z;
//            max_dim = 2;
//        }
//        return max_dim;
//    }

};





int main(int argc, const char * argv[]) {

    return SynestheticRendering().start();
}
