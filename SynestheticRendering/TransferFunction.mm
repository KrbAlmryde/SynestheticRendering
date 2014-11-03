//
//  TransferFunction.m
//  SynestheticRendering
//
//  Created by Kyle Reese Almryde on 11/2/14.
//  Copyright (c) 2014 Kyle Reese Almryde. All rights reserved.
//

#import <Aluminum/Aluminum.h>
#include "colorTable.hpp"

using namespace std;
using namespace glm;
using namespace aluminum;

class TransferFunction {
public:
    Texture lut;
    
    //transfer function (lookup table) colour values
    const glm::vec4 jet_values[9]={	glm::vec4(0,0,0.5,0),
								glm::vec4(0,0,1,0.1),
								glm::vec4(0,0.5,1,0.3),
								glm::vec4(0,1,1,0.5),
								glm::vec4(0.5,1,0.5,0.75),
								glm::vec4(1,1,0,0.8),
								glm::vec4(1,0.5,0,0.6),
								glm::vec4(1,0,0,0.5),
								glm::vec4(0.5,0,0,0.0)};

    vector<vec2> tModel;  // Our graph model
    
    TransferFunction() {};
    
    void init(vector<GLubyte> data) {
        tModel.resize(data.size());
        for (int i = 0 ; i < data.size(); i++){
            if (data[i] > max) max = data[i];
            if (data[i] < min) min = data[i];
            float x = i; //(k/100.0);
            float y = data[i];
            tModel[i] = vec2(x,y);
        }
        LoadTransferFunction();
    }
    
    void setLUT(GLubyte* lookupTable){
        lut.updateData(lookupTable);
    }
    
    void setLUT(GLfloat* lookupTable){
        lut.updateData(lookupTable);
    }

    void bind(GLenum textureUnit) {
        lut.bind(textureUnit);
    }
    
    void unbind(GLenum textureUnit) {
        lut.unbind(textureUnit);
    }
    /*----------------------------------------------------------------------------------
     LoadTransferFunction:
     
     function to generate interpolated colours from the set of colour values (jet_values)
     this function first calculates the amount of increments for each component and the
     index difference. Then it linearly interpolates the adjacent values to get the
     interpolated result.
     -----------------------------------------------------------------------------------*/
    void LoadTransferFunction() {
        int indices[9];
        
        //fill the colour values at the place where the colour should be after interpolation
        for(int i=0;i<9;i++) {
            int index = i*28;
            jetTable[index][0] = jet_values[i].x;
            jetTable[index][1] = jet_values[i].y;
            jetTable[index][2] = jet_values[i].z;
            jetTable[index][3] = jet_values[i].w;
            indices[i] = index;
        }
        
        //for each adjacent pair of colours, find the difference in the rgba values and then interpolate
        for(int j=0;j<9-1;j++)
        {
            float dDataR = (jetTable[indices[j+1]][0] - jetTable[indices[j]][0]);
            float dDataG = (jetTable[indices[j+1]][1] - jetTable[indices[j]][1]);
            float dDataB = (jetTable[indices[j+1]][2] - jetTable[indices[j]][2]);
            float dDataA = (jetTable[indices[j+1]][3] - jetTable[indices[j]][3]);
            int dIndex = indices[j+1]-indices[j];
            
            float dDataIncR = dDataR/float(dIndex);
            float dDataIncG = dDataG/float(dIndex);
            float dDataIncB = dDataB/float(dIndex);
            float dDataIncA = dDataA/float(dIndex);
            for(int i=indices[j]+1;i<indices[j+1];i++)
            {
                jetTable[i][0] = (jetTable[i-1][0] + dDataIncR);
                jetTable[i][1] = (jetTable[i-1][1] + dDataIncG);
                jetTable[i][2] = (jetTable[i-1][2] + dDataIncB);
                jetTable[i][3] = (jetTable[i-1][3] + dDataIncA);
            }
        }
        
        lut = Texture((GLfloat *)jetTable, 256, GL_RGBA, GL_RGBA, GL_FLOAT);
    }


    
    
    void drawGraph(Program shader, int index){
        
        mat4 model = translate(vec3(-0.1,-0.6,0.0)) * scale(vec3(0.8,1.0,1.0));
        shader.bind();
        {
            glUniformMatrix4fv(shader.uniform("model"), 1, 0, value_ptr(model));
            glUniform4fv(shader.uniform("g_color"), 1, value_ptr(vec4(1.0)));
            glBindVertexArray(vaoG);
            //        glDrawArrays(GL_LINE_STRIP, 0, gModel.size());  // Uncomment this line if you want the entire model all at once
            glDrawArrays(GL_LINE_STRIP, 0, index);
            glBindVertexArray(0);
        }
        shader.unbind();
    }

private :
    
    GLuint vaoB, vaoC, vaoG, vaoQ; // vertex array objects
    GLuint vboB, vboC, vboG, vboQ; // vertex buffer objects
    
    // int index = 0;
    bool indexFlag = true;
    
    float min, max = 0.0;  // min and max values
    double integral = 0.0;
    
    TransferFunction initGraph();
    TransferFunction initBorder();
    TransferFunction initCircle();
    TransferFunction initQuadrant();
    std::string join(const vector<std::string> vec, const std::string delim=".");
    std::vector<std::string> &split(const std::string &s, char delim, std::vector<std::string> &elems);
    std::vector<std::string> split(const std::string &s, char delim);
    
    
};