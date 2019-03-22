//
//  texture_helper.m
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 11/03/14.
//  Copyright (c) 2014 Learn OpenGL ES. All rights reserved.
//

#include "texture_helper.h"

#import <UIKit/UIKit.h>

GLuint setup_texture(NSString *fileName, UIColor *color)
{
    CGImageRef spriteImage = [[UIImage imageNamed:fileName] CGImage];
    if (!spriteImage) {
        NSLog(@"Failed to load image %@", fileName);
        return -1;
    }

    
    // 2
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte * spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4, CGImageGetColorSpace(spriteImage), (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    // 3
    if ([fileName isEqualToString:@"telegram_sphere.png"]) {
        CGContextSetFillColorWithColor(spriteContext, color.CGColor);
        CGContextFillRect(spriteContext, CGRectMake(0, 0, width, height));
    }
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    // 4
    GLuint texName;
    
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    
    // use linear filetring
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    // clamp to edge
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    free(spriteData);
    return texName;
}



