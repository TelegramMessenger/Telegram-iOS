// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
    SSIMULACRA - Structural SIMilarity Unveiling Local And Compression Related Artifacts

    Cloudinary's variant of DSSIM, based on Philipp Klaus Krause's adaptation of Rabah Mehdi's SSIM implementation,
    using ideas from Kornel Lesinski's DSSIM implementation as well as several new ideas.




    Changes compared to Krause's SSIM implementation:
    - Use C++ OpenCV API
    - Convert sRGB to linear RGB and then to L*a*b*, to get a perceptually more accurate color space
    - Multi-scale (6 scales)
    - Extra penalty for specific kinds of artifacts:
        - local artifacts
        - grid-like artifacts (blockiness)
        - introducing edges where the original is smooth (blockiness / color banding / ringing / mosquito noise)

    Known limitations:
    - Color profiles are ignored; input images are assumed to be sRGB.
    - Both input images need to have the same number of channels (Grayscale / RGB / RGBA)
*/

/*
    This DSSIM program has been created by Philipp Klaus Krause based on
    Rabah Mehdi's C++ implementation of SSIM (http://mehdi.rabah.free.fr/SSIM).
    Originally it has been created for the VMV '09 paper
    "ftc - floating precision texture compression" by Philipp Klaus Krause.

    The latest version of this program can probably be found somewhere at
    http://www.colecovision.eu.

    It can be compiled using g++ -I/usr/include/opencv -lcv -lhighgui dssim.cpp
    Make sure OpenCV is installed (e.g. for Debian/ubuntu: apt-get install
    libcv-dev libhighgui-dev).

    DSSIM is described in
    "Structural Similarity-Based Object Tracking in Video Sequences" by Loza et al.
    however setting all Ci to 0 as proposed there results in numerical instabilities.
    Thus this implementation used the Ci from the SSIM implementation.
    SSIM is described in
    "Image quality assessment: from error visibility to structural similarity" by Wang et al.
*/

/*
    Copyright (c) 2005, Rabah Mehdi <mehdi.rabah@gmail.com>

    Feel free to use it as you want and to drop me a mail
    if it has been useful to you. Please let me know if you enhance it.
    I'm not responsible if this program destroy your life & blablabla :)

    Copyright (c) 2009, Philipp Klaus Krause <philipp@colecovision.eu>

    Permission to use, copy, modify, and/or distribute this software for any
    purpose with or without fee is hereby granted, provided that the above
    copyright notice and this permission notice appear in all copies.

    THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
    WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
    MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
    ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
    WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
    ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
    OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/

#include <cv.hpp>
#include <highgui.h>
#include <stdio.h>
#include <set>

// comment this in to produce debug images that show the differences at each scale
#define DEBUG_IMAGES 1
using namespace std;
using namespace cv;

// All of the constants below are more or less arbitrary.
// Some amount of tweaking/calibration was done, but there is certainly room for improvement.

// SSIM constants. Original C2 was 0.0009, but a smaller value seems to work slightly better.
const double C1 = 0.0001, C2 = 0.0004;

// Weight of each scale. Somewhat arbitrary.
// These are based on the values used in IW-SSIM and Kornel's DSSIM.
// It seems weird to give so little weight to the full-size scale, but then again,
// differences in more zoomed-out scales have more visual impact.
// Anyway, these weights seem to work.
// Added one more scale compared to IW-SSIM and Kornel's DSSIM.
// Weights for chroma are modified to give more weight to larger scales (similar to Kornel's subsampled chroma)
const float scale_weights[4][6] = {
    // 1:1   1:2     1:4     1:8     1:16    1:32
    {0.0448, 0.2856, 0.3001, 0.2363, 0.1333, 0.1  },
    {0.015,  0.0448, 0.2856, 0.3001, 0.3363, 0.25 },
    {0.015,  0.0448, 0.2856, 0.3001, 0.3363, 0.25 },
    {0.0448, 0.2856, 0.3001, 0.2363, 0.1333, 0.1  },
    };

// higher value means more importance to chroma (weights above are multiplied by this factor for chroma and alpha)
const double chroma_weight = 0.2;

// Weights for the worst-case (minimum) score at each scale.
// Higher value means more importance to worst artifacts, lower value means more importance to average artifacts.
const float mscale_weights[4][6] = {
    // 1:4   1:8     1:16    1:32   1:64   1:128
    {0.2,    0.3,    0.25,   0.2,   0.12,  0.05},
    {0.01,   0.05,   0.2,    0.3,   0.35,  0.35},
    {0.01,   0.05,   0.2,    0.3,   0.35,  0.35},
    {0.2,    0.3,    0.25,   0.2,   0.12,  0.05},
    };


// higher value means more importance to worst local artifacts
const double min_weight[4] = {0.1,0.005,0.005,0.005};

// higher value means more importance to artifact-edges (edges where original is smooth)
const double extra_edges_weight[4] = {1.5, 0.1, 0.1, 0.5};

// higher value means more importance to grid-like artifacts (blockiness)
const double worst_grid_weight[2][4] = 
    { {1.0, 0.1, 0.1, 0.5},             // on ssim heatmap
      {1.0, 0.1, 0.1, 0.5} };           // on extra_edges heatmap


// Convert linear RGB to L*a*b* (all in 0..1 range)
inline void rgb2lab(Vec3f &p) __attribute__ ((hot));
inline void rgb2lab(Vec3f &p) {
    const float epsilon = 0.00885645167903563081f;
    const float s = 0.13793103448275862068f;
    const float k = 7.78703703703703703703f;

    // D65 adjustment included
    float fx = (p[2] * 0.43393624408206207259f + p[1] * 0.37619779063650710152f + p[0] * .18983429773803261441f) ;
    float fy = (p[2] * 0.2126729f + p[1] * 0.7151522f + p[0] * 0.0721750f);
    float fz = (p[2] * 0.01775381083562901744f + p[1] * 0.10945087235996326905f + p[0] * 0.87263921028466483011f) ;

    float X = (fx > epsilon) ? powf(fx,1.0f/3.0f) - s : k * fx;
    float Y = (fy > epsilon) ? powf(fy,1.0f/3.0f) - s : k * fy;
    float Z = (fz > epsilon) ? powf(fz,1.0f/3.0f) - s : k * fz;

    p[0] = Y * 1.16f;
    p[1] = (0.39181818181818181818f + 2.27272727272727272727f * (X - Y));
    p[2] = (0.49045454545454545454f + 0.90909090909090909090f * (Y - Z));
}


int main(int argc, char** argv) {

    if(argc!=3) {
        fprintf(stderr, "Usage: %s orig_image distorted_image\n", argv[0]);
        fprintf(stderr, "Returns a value between 0 (images are identical) and 1 (images are very different)\n");
        fprintf(stderr, "If the value is above 0.1 (or so), the distortion is likely to be perceptible / annoying.\n");
        fprintf(stderr, "If the value is below 0.01 (or so), the distortion is likely to be imperceptible.\n");
        return(-1);
    }

    Scalar sC1 = {C1,C1,C1,C1}, sC2 = {C2,C2,C2,C2};

    Mat img1, img2, img1_img2, img1_temp, img2_temp, img1_sq, img2_sq, mu1, mu2, mu1_sq, mu2_sq, mu1_mu2, sigma1_sq, sigma2_sq, sigma12, ssim_map;

    // read and validate input images

    img1_temp = imread(argv[1],-1);
    img2_temp = imread(argv[2],-1);

    int nChan = img1_temp.channels();
    if (nChan != img2_temp.channels()) {
        fprintf(stderr, "Image file %s has %i channels, while\n", argv[1], nChan);
        fprintf(stderr, "image file %s has %i channels. Can't compare.\n", argv[2], img2_temp.channels());
        return -1;
    }
    if (img1_temp.size() != img2_temp.size()) {
        fprintf(stderr,  "Image dimensions have to be identical.\n");
        return -1;
    }
    if (img1_temp.cols < 8 || img1_temp.rows < 8) {
        fprintf(stderr,  "Image is too small; need at least 8 rows and columns.\n");
        return -1;
    }
    int pixels = img1_temp.rows * img1_temp.cols;
    if (nChan == 4) {
        // blend to a gray background to have a fair comparison of semi-transparent RGB values
        for( int i=0 ; i < pixels; i++ ) {
            Vec4b & p = img1_temp.at<Vec4b>(i);
            p[0] = (p[3]*p[0] + (255-p[3])*128 ) / 255;
            p[1] = (p[3]*p[1] + (255-p[3])*128 ) / 255;
            p[2] = (p[3]*p[2] + (255-p[3])*128 ) / 255;
        }
        for( int i=0 ; i < pixels; i++ ) {
            Vec4b & p = img2_temp.at<Vec4b>(i);
            p[0] = (p[3]*p[0] + (255-p[3])*128 ) / 255;
            p[1] = (p[3]*p[1] + (255-p[3])*128 ) / 255;
            p[2] = (p[3]*p[2] + (255-p[3])*128 ) / 255;
        }
    }


    if (nChan > 1) {
    // Create lookup table to convert 8-bit sRGB to linear RGB
    Mat sRGB_gamma_LUT(1, 256, CV_32FC1);
    for (int i = 0; i < 256; i++) {
        float c = i / 255.0;
        sRGB_gamma_LUT.at<float>(i) = (c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4));
    }

    // Convert from sRGB to linear RGB
    LUT(img1_temp, sRGB_gamma_LUT, img1);
    LUT(img2_temp, sRGB_gamma_LUT, img2);
    } else {
        img1 = Mat(img1_temp.rows, img1_temp.cols, CV_32FC1);
        img2 = Mat(img1_temp.rows, img1_temp.cols, CV_32FC1);
    }

    // Convert from linear RGB to Lab in a 0..1 range
    if (nChan == 3) {
      for( int i=0 ; i < pixels; i++ ) rgb2lab(img1.at<Vec3f>(i));
      for( int i=0 ; i < pixels; i++ ) rgb2lab(img2.at<Vec3f>(i));
    } else if (nChan == 4) {
      for( int i=0 ; i < pixels; i++ ) { Vec3f p = {img1.at<Vec4f>(i)[0],img1.at<Vec4f>(i)[1],img1.at<Vec4f>(i)[2]}; rgb2lab(p); img1.at<Vec4f>(i)[0] = p[0]; img1.at<Vec4f>(i)[1] = p[1]; img1.at<Vec4f>(i)[2] = p[2];}
      for( int i=0 ; i < pixels; i++ ) { Vec3f p = {img2.at<Vec4f>(i)[0],img2.at<Vec4f>(i)[1],img2.at<Vec4f>(i)[2]}; rgb2lab(p); img2.at<Vec4f>(i)[0] = p[0]; img2.at<Vec4f>(i)[1] = p[1]; img2.at<Vec4f>(i)[2] = p[2];}
    } else if (nChan == 1) {
      for( int i=0 ; i < pixels; i++ ) { img1.at<float>(i) = img1_temp.at<uchar>(i)/255.0;}
      for( int i=0 ; i < pixels; i++ ) { img2.at<float>(i) = img2_temp.at<uchar>(i)/255.0;}
    } else {
        fprintf(stderr, "Can only deal with Grayscale, RGB or RGBA input.\n");
        return(-1);
    }


    double dssim=0, dssim_max=0;

    for (int scale = 0; scale < 6; scale++) {

      if (img1.cols < 8 || img1.rows < 8) break;
      if (scale) {
        // scale down 50% in each iteration.
        resize(img1, img1, Size(), 0.5, 0.5, INTER_AREA);
        resize(img2, img2, Size(), 0.5, 0.5, INTER_AREA);
      }

      // Standard SSIM computation
      cv::pow( img1, 2, img1_sq );
      cv::pow( img2, 2, img2_sq );

      multiply( img1, img2, img1_img2, 1 );

      GaussianBlur(img1, mu1, Size(11,11), 1.5);
      GaussianBlur(img2, mu2, Size(11,11), 1.5);

      cv::pow( mu1, 2, mu1_sq );
      cv::pow( mu2, 2, mu2_sq );
      multiply( mu1, mu2, mu1_mu2, 1 );

      GaussianBlur(img1_sq, sigma1_sq, Size(11,11), 1.5);
      addWeighted( sigma1_sq, 1, mu1_sq, -1, 0, sigma1_sq );

      GaussianBlur(img2_sq, sigma2_sq, Size(11,11), 1.5);
      addWeighted( sigma2_sq, 1, mu2_sq, -1, 0, sigma2_sq );

      GaussianBlur(img1_img2, sigma12, Size(11,11), 1.5);
      addWeighted( sigma12, 1, mu1_mu2, -1, 0, sigma12 );

      ssim_map = ((2*mu1_mu2 + sC1).mul(2*sigma12 + sC2))/((mu1_sq + mu2_sq + sC1).mul(sigma1_sq + sigma2_sq + sC2));


      // optional: write a nice debug image that shows the problematic areas
#ifdef DEBUG_IMAGES
      Mat ssim_image;
      ssim_map.convertTo(ssim_image,CV_8UC3,255);
        for( int i=0 ; i < ssim_image.rows * ssim_image.cols; i++ ) {
            Vec3b &p = ssim_image.at<Vec3b>(i);
            p = {(uchar)(255-p[2]),(uchar)(255-p[0]),(uchar)(255-p[1])};
        }
      imwrite("debug-scale"+to_string(scale)+".png",ssim_image);
#endif


      // average ssim over the entire image
      Scalar avg = mean( ssim_map );
      for(unsigned int i = 0; i < nChan; i++) {
        printf("avg: %i  %f\n",i,avg[i]);
        dssim += (i>0?chroma_weight:1.0) * avg[i] * scale_weights[i][scale];
        dssim_max += (i>0?chroma_weight:1.0) * scale_weights[i][scale];
      }

//      resize(ssim_map, ssim_map, Size(), 0.5, 0.5, INTER_AREA);


      // the edge/blockiness penalty is only done for the fullsize images
      if (scale == 0) {

        // asymmetric: penalty for introducing edges where there are none (e.g. blockiness), no penalty for smoothing away edges
        Mat edgediff = max(abs(img2 - mu2) - abs(img1 - mu1), 0);   // positive if img2 has an edge where img1 is smooth

        // optional: write a nice debug image that shows the artifact edges
#ifdef DEBUG_IMAGES
        Mat edgediff_image;
        edgediff.convertTo(edgediff_image,CV_8UC3,5000); // multiplying by more than 255 to make things easier to see
        for( int i=0 ; i < pixels; i++ ) {
            Vec3b &p = edgediff_image.at<Vec3b>(i);
            p = {(uchar)(p[1]+p[2]),p[0],p[0]};
        }
        imwrite("debug-edgediff.png",edgediff_image);
#endif

        edgediff = Scalar(1.0,1.0,1.0,1.0) - edgediff;

        avg = mean(edgediff);
        for(unsigned int i = 0; i < nChan; i++) {
          printf("extra_edges: %i  %f\n",i,avg[i]);
          dssim +=  extra_edges_weight[i] * avg[i];
          dssim_max +=  extra_edges_weight[i];
        }

        // grid-like artifact detection
        // do the things below twice: once for the SSIM map, once for the artifact-edge map
        Mat errormap;
        for(int twice=0; twice < 2; twice++) {
          if (twice == 0) errormap = ssim_map;
          else errormap = edgediff;

          // Find the 2nd percentile worst row. If the compression uses blocks, there will be artifacts around the block edges,
          // so even with 32x32 blocks, the 2nd percentile will likely be one of the rows with block borders
          multiset<double> row_scores[4];
          for (int y = 0; y < errormap.rows; y++) {
            Mat roi = errormap(Rect(0,y,errormap.cols,1));
            Scalar ravg = mean(roi);
            for (unsigned int i = 0; i < nChan; i++) row_scores[i].insert(ravg[i]);
          }
          for(unsigned int i = 0; i < nChan; i++) {
            int k=0; for (const double& s : row_scores[i]) { if (k++ >= errormap.rows/50) { dssim += worst_grid_weight[twice][i] * s; 
          printf("grid row %s %i:  %f\n",(twice?"edgediff":"ssimmap"),i,s);

 break; } }
            dssim_max += worst_grid_weight[twice][i];
          }
          // Find the 2nd percentile worst column. Same concept as above.
          multiset<double> col_scores[4];
          for (int x = 0; x < errormap.cols; x++) {
            Mat roi = errormap(Rect(x,0,1,errormap.rows));
            Scalar cavg = mean(roi);
            for (unsigned int i = 0; i < nChan; i++) col_scores[i].insert(cavg[i]);
          }
          for(unsigned int i = 0; i < nChan; i++) {
            int k=0; for (const double& s : col_scores[i]) { if (k++ >= errormap.cols/50) { dssim += worst_grid_weight[twice][i] * s; 
          printf("grid col %s %i:  %f\n",(twice?"edgediff":"ssimmap"),i,s);

break; } }
            dssim_max += worst_grid_weight[twice][i];
          }
        }
      }

      // worst ssim in a particular 4x4 block (larger blocks are considered too because of multi-scale)
      resize(ssim_map, ssim_map, Size(), 0.25, 0.25, INTER_AREA);
//      resize(ssim_map, ssim_map, Size(), 0.5, 0.5, INTER_AREA);

      Mat ssim_map_c[4];
      split(ssim_map, ssim_map_c);
      for (unsigned int i=0; i < nChan; i++) {
        double minVal;
        minMaxLoc(ssim_map_c[i], &minVal);
          printf("worst %i:  %f\n",i,minVal);
        dssim += min_weight[i]  * minVal * mscale_weights[i][scale];
        dssim_max += min_weight[i]  * mscale_weights[i][scale];
      }

    }


    dssim = dssim_max / dssim - 1;
    if (dssim < 0) dssim = 0; // should not happen
    if (dssim > 1) dssim = 1; // very different images

    printf("%.8f\n", dssim);

    return(0);
}
