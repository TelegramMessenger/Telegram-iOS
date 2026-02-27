#import "ocr.h"

#include <vector>
#include <utility>
#include <string>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "fast-edge.h"
#include "genann.h"

#import "LegacyComponentsInternal.h"

#ifndef max
#define max(a, b) (a>b ? a : b)
#define min(a, b) (a<b ? a : b)
#endif

namespace ocr{
	struct line{
		double theta;
		double r;
	};

	std::vector<line> detectLines(struct image* img, int threshold){
		// The size of the neighbourhood in which to search for other local maxima
		const int neighbourhoodSize = 4;

		// How many discrete values of theta shall we check?
		const int maxTheta = 180;

		// Using maxTheta, work out the step
		const double thetaStep = M_PI / maxTheta;

		int width=img->width;
		int height=img->height;
		// Calculate the maximum height the hough array needs to have
		int houghHeight = (int) (sqrt(2.0) * max(height, width)) / 2;

		// Double the height of the hough array to cope with negative r values
		int doubleHeight = 2 * houghHeight;

		// Create the hough array
		int* houghArray = new int[maxTheta*doubleHeight];
		memset(houghArray, 0, sizeof(int)*maxTheta*doubleHeight);

		// Find edge points and vote in array
		int centerX = width / 2;
		int centerY = height / 2;

		// Count how many points there are
		int numPoints = 0;

		// cache the values of sin and cos for faster processing
		double* sinCache = new double[maxTheta];
		double* cosCache = new double[maxTheta];
		for (int t = 0; t < maxTheta; t++) {
			double realTheta = t * thetaStep;
			sinCache[t] = sin(realTheta);
			cosCache[t] = cos(realTheta);
		}

		// Now find edge points and update the hough array
		for (int x = 0; x < width; x++) {
			for (int y = 0; y < height; y++) {
				// Find non-black pixels
				if ((img->pixel_data[y*width+x] & 0x000000ff) != 0) {
					// Go through each value of theta
					for (int t = 0; t < maxTheta; t++) {

						//Work out the r values for each theta step
						int r = (int) (((x - centerX) * cosCache[t]) + ((y - centerY) * sinCache[t]));

						// this copes with negative values of r
						r += houghHeight;

						if (r < 0 || r >= doubleHeight) continue;

						// Increment the hough array
						houghArray[t*doubleHeight+r]++;

					}

					numPoints++;
				}
			}
		}

		// Initialise the vector of lines that we'll return
		std::vector<line> lines;

		// Only proceed if the hough array is not empty
		if (numPoints == 0){
			delete[] houghArray;
			delete[] sinCache;
			delete[] cosCache;
			return lines;
		}

		// Search for local peaks above threshold to draw
		for (int t = 0; t < maxTheta; t++) {
			//loop:
			for (int r = neighbourhoodSize; r < doubleHeight - neighbourhoodSize; r++) {

				// Only consider points above threshold
				if (houghArray[t*doubleHeight+r] > threshold) {

					int peak = houghArray[t*doubleHeight+r];

					// Check that this peak is indeed the local maxima
					for (int dx = -neighbourhoodSize; dx <= neighbourhoodSize; dx++) {
						for (int dy = -neighbourhoodSize; dy <= neighbourhoodSize; dy++) {
							int dt = t + dx;
							int dr = r + dy;
							if (dt < 0) dt = dt + maxTheta;
							else if (dt >= maxTheta) dt = dt - maxTheta;
							if (houghArray[dt*doubleHeight+dr] > peak) {
								// found a bigger point nearby, skip
								goto loop;
							}
						}
					}

					// calculate the true value of theta
					double theta = t * thetaStep;

					// add the line to the vector
					line l={theta, (double)r-houghHeight};
					lines.push_back(l);

				}
				loop:
				continue;
			}
		}

		delete[] houghArray;
		delete[] sinCache;
		delete[] cosCache;
		return lines;
	}
    
    void binarizeBitmapPart(uint8_t* inPixels, unsigned char* outPixels, size_t width, size_t height, size_t inBytesPerRow, size_t outBytesPerRow){
        uint32_t histogram[256]={0};
        uint32_t intensitySum=0;
        for(unsigned int y=0;y<height;y++){
            for(unsigned int x=0;x<width;x++){
                uint8_t *px = inPixels + (inBytesPerRow * y) + x * 4;
                uint8_t r = *(px + 1);
                uint8_t g = *(px + 2);
                uint8_t b = *(px + 3);
                
                int l = (r + g + b)/3.0;
                outPixels[(outBytesPerRow * y) + x]=l;
                histogram[l]++;
                intensitySum+=l;
            }
        }
        int threshold=0;
        double best_sigma = 0.0;
        
        int first_class_pixel_count = 0;
        int first_class_intensity_sum = 0;
        
        for (int thresh = 0; thresh < 255; ++thresh) {
            first_class_pixel_count += histogram[thresh];
            first_class_intensity_sum += thresh * histogram[thresh];
            
            double first_class_prob = first_class_pixel_count / (double) (width*height);
            double second_class_prob = 1.0 - first_class_prob;
            
            double first_class_mean = first_class_intensity_sum / (double) first_class_pixel_count;
            double second_class_mean = (intensitySum - first_class_intensity_sum)
            / (double) ((width*height) - first_class_pixel_count);
            
            double mean_delta = first_class_mean - second_class_mean;
            
            double sigma = first_class_prob * second_class_prob * mean_delta * mean_delta;
            
            if (sigma > best_sigma) {
                best_sigma = sigma;
                threshold = thresh;
            }
        }
        
        for(unsigned int y=0;y<height;y++){
            for(unsigned int x=0;x<width;x++){
                uint8_t *px = inPixels + (inBytesPerRow * y) + x * 4;
                uint8_t r = *(px + 1);
                uint8_t g = *(px + 2);
                uint8_t b = *(px + 3);
                outPixels[(outBytesPerRow * y) + x]=(r<threshold && g<threshold && b<threshold) ? (unsigned char)255 : (unsigned char)0;
            }
        }
    }
}

NSDictionary *findCornerPoints(UIImage *bitmap) {
    CGImageRef imageRef = bitmap.CGImage;
    uint32_t width = (uint32_t)CGImageGetWidth(imageRef);
    uint32_t height = (uint32_t)CGImageGetHeight(imageRef);
	
	struct ocr::image imgIn, imgOut;
	imgIn.width = imgOut.width = width;
	imgIn.height = imgOut.height = height;
	imgIn.pixel_data = (uint8_t *)malloc(width * height);
	imgOut.pixel_data = (uint8_t *)calloc(width * height, 1);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    uint8_t *bitmapPixels = (uint8_t *)calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(bitmapPixels, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    
    CGContextRelease(context);
    
	for(unsigned int y=0;y<height;y++){
		for(unsigned int x=0;x<width;x++){
			uint32_t px = bitmapPixels[(bytesPerRow * y) + x];
			imgIn.pixel_data[width*y+x]=(unsigned char) (((px & 0xFF) + ((px & 0xFF00) >> 8) + ((px & 0xFF0000) >> 16))/3);
		}
	}
    
	ocr::canny_edge_detect(&imgIn, &imgOut);

	std::vector<ocr::line> lines=ocr::detectLines(&imgOut, 100);
	for(NSUInteger i = 0; i < width * height; i++) {
		imgOut.pixel_data[i]/=2;
	}
	std::vector<std::vector<ocr::line>> parallelGroups;
	for(int i = 0; i < 36; i++) {
		parallelGroups.emplace_back();
	}
	ocr::line *left = NULL;
	ocr::line *right = NULL;
	ocr::line *top = NULL;
	ocr::line *bottom = NULL;
    for(std::vector<ocr::line>::iterator l = lines.begin(); l!= lines.end();) {
		// remove lines at irrelevant angles
		if(!(l->theta>M_PI*0.4 && l->theta<M_PI*0.6) && !(l->theta<M_PI*0.1 || l->theta>M_PI*0.9)){
			l=lines.erase(l);
			continue;
		}
		// remove vertical lines close to the middle of the image
		if((l->theta<M_PI*0.1 || l->theta>M_PI*0.9) && (uint32_t)abs((int)l->r) < height / 4){
			l=lines.erase(l);
			continue;
		}
		// find the leftmost and rightmost lines
		if(l->theta<M_PI*0.1 || l->theta>M_PI*0.9){
			double rk=l->theta<0.5 ? 1.0 : -1.0;
			if(!left || left->r>l->r*rk){
				left=&*l;
			}
			if(!right || right->r<l->r*rk){
				right=&*l;
			}
		}
		// group parallel-ish lines with 5-degree increments
		parallelGroups[(uint32_t)floor(l->theta / M_PI * 36)].push_back(*l);
		++l;
	}

	// the text on the page tends to produce a lot of parallel lines - so we assume the top & bottom edges of the page
	// are topmost & bottommost lines in the largest group of horizontal lines
	std::vector<ocr::line>& largestParallelGroup=parallelGroups[0];
	for(std::vector<std::vector<ocr::line>>::iterator group=parallelGroups.begin();group!=parallelGroups.end();++group){
		if(largestParallelGroup.size()<group->size())
			largestParallelGroup=*group;
	}

	for(std::vector<ocr::line>::iterator l=largestParallelGroup.begin();l!=largestParallelGroup.end();++l){
		// If the image is horizontal, we assume it's just the data page or an ID card so we're going for the topmost line.
		// If it's vertical, it likely contains both the data page and the page adjacent to it so we're going for the line that is closest to the center of the image.
		// Nobody in their right mind is going to be taking vertical pictures of ID cards, right?
		if(width>height){
			if(!top || top->r>l->r){
				top=&*l;
			}
		}else{
			if(!top || fabs(l->r)<fabs(top->r)){
				top=&*l;
			}
		}
		if(!bottom || bottom->r<l->r){
			bottom=&*l;
		}
	}
    
    bool foundTopLeft=false, foundTopRight=false, foundBottomLeft=false, foundBottomRight=false;
    NSMutableDictionary *points = [[NSMutableDictionary alloc] init];
    
	if(top && bottom && left && right){
		//LOGI("bottom theta %f", bottom->theta);
		if(bottom->theta>1.65 || bottom->theta<1.55){
			//LOGD("left: %f, right: %f\n", left->r, right->r);
			double centerX=width/2.0;
			double centerY=height/2.0;
			double ltsin=sin(left->theta);
			double ltcos=cos(left->theta);
			double rtsin=sin(right->theta);
			double rtcos=cos(right->theta);
			double ttsin=sin(top->theta);
			double ttcos=cos(top->theta);
			double btsin=sin(bottom->theta);
			double btcos=cos(bottom->theta);
			for (int y = -((int)height)/4; y < (int)height; y++) {
				int lx = (int) (((left->r - ((y - centerY) * ltsin)) / ltcos) + centerX);
				int ty = (int) (((top->r - ((lx - centerX) * ttcos)) / ttsin) + centerY);
				if(ty==y){
					points[@0]=@(lx);
					points[@1]=@(y);
					foundTopLeft=true;
					if(foundTopRight)
						break;
				}
				int rx = (int) (((right->r - ((y - centerY) * rtsin)) / rtcos) + centerX);
				ty = (int) (((top->r - ((rx - centerX) * ttcos)) / ttsin) + centerY);
				if(ty==y){
					points[@2]=@(rx);
					points[@3]=@(y);
					foundTopRight=true;
					if(foundTopLeft)
						break;
				}
			}
			for (int y = height+height/3; y>=0; y--) {
				int lx = (int) (((left->r - ((y - centerY) * ltsin)) / ltcos) + centerX);
				int by = (int) (((bottom->r - ((lx - centerX) * btcos)) / btsin) + centerY);
				if(by==y){
					points[@4]=@(lx);
					points[@5]=@(y);
					foundBottomLeft=true;
					if(foundBottomRight)
						break;
				}
				int rx = (int) (((right->r - ((y - centerY) * rtsin)) / rtcos) + centerX);
				by = (int) (((bottom->r - ((rx - centerX) * btcos)) / btsin) + centerY);
				if(by==y){
					points[@6]=@(rx);
					points[@7]=@(y);
					foundBottomRight=true;
					if(foundBottomLeft)
						break;
				}
			}
		}else{
			//LOGD("No perspective correction needed");
		}
	}

	free(imgIn.pixel_data);
	free(imgOut.pixel_data);
    
    if(foundTopLeft && foundTopRight && foundBottomLeft && foundBottomRight) {
        return points;
    }
    return nil;
}

NSArray *binarizeAndFindCharacters(UIImage *inBmp, UIImage **outBinaryImage) {
    CGImageRef imageRef = inBmp.CGImage;
    uint32_t width = (uint32_t)CGImageGetWidth(imageRef);
    uint32_t height = (uint32_t)CGImageGetHeight(imageRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    uint8_t *bitmapPixels = (uint8_t *)calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(bitmapPixels, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaNoneSkipFirst);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    
    CGContextRelease(context);
    
    uint8_t *outPixels = (uint8_t *)malloc(width * height * 1);
    
//    uint32_t histogram[256]={0};
//    uint32_t intensitySum=0;
//    for(unsigned int y=0;y<height;y++){
//        for(unsigned int x=0;x<width;x++){
//            uint8_t *px = bitmapPixels + (bytesPerRow * y) + x * 4;
//            uint8_t r = *(px + 1);
//            uint8_t g = *(px + 2);
//            uint8_t b = *(px + 3);
//            int l = (r + g + b)/3.0;
//            outPixels[(width * y) + x]=l;
//            histogram[l]++;
//            intensitySum+=l;
//        }
//    }
//    uint32_t threshold=0;
//    double best_sigma = 0.0;
//
//    int first_class_pixel_count = 0;
//    int first_class_intensity_sum = 0;
//
//    for (int thresh = 0; thresh < 255; ++thresh) {
//        first_class_pixel_count += histogram[thresh];
//        first_class_intensity_sum += thresh * histogram[thresh];
//
//        double first_class_prob = first_class_pixel_count / (double) (width*height);
//        double second_class_prob = 1.0 - first_class_prob;
//
//        double first_class_mean = first_class_intensity_sum / (double) first_class_pixel_count;
//        double second_class_mean = (intensitySum - first_class_intensity_sum) / (double) ((width*height) - first_class_pixel_count);
//
//        double mean_delta = first_class_mean - second_class_mean;

//        double sigma = first_class_prob * second_class_prob * mean_delta * mean_delta;
//
//        if (sigma > best_sigma) {
//            best_sigma = sigma;
//            threshold = thresh;
//        }
//    }
//
//    for(unsigned int y=0;y<height;y++){
//        for(unsigned int x=0;x<width;x++){
//            uint8_t *px = bitmapPixels + (bytesPerRow * y) + x * 4;
//            uint8_t r = *(px + 1);
//            uint8_t g = *(px + 2);
//            uint8_t b = *(px + 3);
//            outPixels[(width * y) + x]=(r<threshold && g<threshold && b<threshold) ? (unsigned char)255 : (unsigned char)0;
//        }
//    }
    
    for(unsigned int y=0;y<height;y+=120){
        for(unsigned int x=0; x<width; x+=120){
            int partWidth=x+120<width ? 120 : (width-x);
            int partHeight=y+120<height ? 120 : (height-y);
            
            ocr::binarizeBitmapPart((bitmapPixels + (y * bytesPerRow) + x * 4), outPixels + (width * y) + x, partWidth, partHeight, bytesPerRow, width);
        }
    }

	// remove any single pixels without adjacent ones - these are usually noise
	for(unsigned int y=height/2;y<height-1;y++){
        unsigned int yOffset=y*width;
        unsigned int yOffsetPrev=(y-1)*width;
        unsigned int yOffsetNext=(y+1)*width;
		for(unsigned int x=1;x<width-1;x++){
            int pixelCount=0;
            if(outPixels[yOffsetPrev+x-1]!=0)
                pixelCount++;
            if(outPixels[yOffsetPrev+x]!=0)
                pixelCount++;
            if(outPixels[yOffsetPrev+x+1]!=0)
                pixelCount++;
            
            if(outPixels[yOffset+x-1]!=0)
                pixelCount++;
            if(outPixels[yOffset+x]!=0)
                pixelCount++;
            if(outPixels[yOffset+x+1]!=0)
                pixelCount++;
            
            if(outPixels[yOffsetNext+x-1]!=0)
                pixelCount++;
            if(outPixels[yOffsetNext+x]!=0)
                pixelCount++;
            if(outPixels[yOffsetNext+x+1]!=0)
                pixelCount++;
            
            if(pixelCount<3)
                outPixels[yOffset+x]=0;
		}
	}
    
    if (outBinaryImage != nil)
    {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
        CGContextRef context = CGBitmapContextCreate(outPixels, width, height, 8, width, colorSpace, kCGImageAlphaNone);
        CGColorSpaceRelease(colorSpace);
        
        CGImageRef imgRef = CGBitmapContextCreateImage(context);
        UIImage *img = [UIImage imageWithCGImage:imgRef];
        CGImageRelease(imgRef);
        CGContextRelease(context);
        
        *outBinaryImage = img;
    }
	// search from the bottom up for continuous areas of mostly empty pixels
	unsigned int consecutiveEmptyRows=0;
	std::vector<std::pair<unsigned int, unsigned int>> emptyAreaYs;
	for(unsigned int y=height-1;y>=height/2;y--){
		unsigned int consecutiveEmptyPixels=0;
		unsigned int maxEmptyPixels=0;
		for(unsigned int x=0;x<width;x++){
			if(outPixels[width * y + x]==0){
				consecutiveEmptyPixels++;
			}else{
				maxEmptyPixels=max(maxEmptyPixels, consecutiveEmptyPixels);
				consecutiveEmptyPixels=0;
			}
		}
		maxEmptyPixels=max(maxEmptyPixels, consecutiveEmptyPixels);
		if(maxEmptyPixels>width/10*8){
			consecutiveEmptyRows++;
		}else if(consecutiveEmptyRows>0){
			emptyAreaYs.emplace_back(y, y+consecutiveEmptyRows);
			consecutiveEmptyRows=0;
		}
	}

    NSMutableArray *result = [[NSMutableArray alloc] init];
	// using the areas found above, do the same thing but horizontally and between them in an attempt to ultimately find the bounds of the MRZ characters
	for(std::vector<std::pair<unsigned int, unsigned int>>::iterator p=emptyAreaYs.begin();p!=emptyAreaYs.end();++p){
		std::vector<std::pair<unsigned int, unsigned int>>::iterator next=std::next(p);
		if(next!=emptyAreaYs.end()){
			unsigned int lineHeight=p->first-next->second;
			// An MRZ line can't really be this thin so this probably isn't one
			if(lineHeight<10)
				continue;
			unsigned int consecutiveEmptyCols=0;
			std::vector<std::pair<unsigned int, unsigned int>> emptyAreaXs;
			for(unsigned int x=0;x<width;x++){
				unsigned int consecutiveEmptyPixels=0;
				unsigned int maxEmptyPixels=0;
				unsigned int bottomFilledPixels=0; // count these separately because we want those L's recognized correctly
				for(unsigned int y=next->second;y<p->first;y++){
					if(outPixels[width * y + x]==0){
						consecutiveEmptyPixels++;
					}else{
						maxEmptyPixels=max(maxEmptyPixels, consecutiveEmptyPixels);
						consecutiveEmptyPixels=0;
						if(y>p->first-3)
							bottomFilledPixels++;
					}
				}
                maxEmptyPixels=consecutiveEmptyPixels;
                if(lineHeight-maxEmptyPixels<=lineHeight/15 && bottomFilledPixels==0){
					consecutiveEmptyCols++;
				}else if(consecutiveEmptyCols>0){
					emptyAreaXs.emplace_back(x-consecutiveEmptyCols, x);
					consecutiveEmptyCols=0;
				}
			}
			if(consecutiveEmptyCols>0){
				emptyAreaXs.emplace_back(width-consecutiveEmptyCols, width);
			}
			if(emptyAreaXs.size()>30){
				bool foundLeftPadding=false;
                NSMutableArray *rects = [[NSMutableArray alloc] init];
				for(std::vector<std::pair<unsigned int, unsigned int>>::iterator h=emptyAreaXs.begin();h!=emptyAreaXs.end();++h){
					std::vector<std::pair<unsigned int, unsigned int>>::iterator nextH=std::next(h);
					if(!foundLeftPadding && h->second-h->first>width/35){
						foundLeftPadding=true;
					}else if(foundLeftPadding && h->second-h->first>width/30){
						if(rects.count>=30){
							break;
						}else{
							// restart the search because now we've (hopefully) found the real padding
                            [rects removeAllObjects];
						}
					}
					if(nextH!=emptyAreaXs.end() && foundLeftPadding){
						unsigned int top=next->second;
						unsigned int bottom=p->first;
						// move the top and bottom edges towards each other as part of normalization
						for(unsigned int y=top;y<bottom;y++){
							bool found=false;
							for(unsigned int x=h->second; x<nextH->first; x++){
								if(outPixels[width * y + x]!=0){
									top=y;
									found=true;
									break;
								}
							}
							if(found)
								break;
						}
						for(unsigned int y=bottom;y>top;y--){
							bool found=false;
							for(unsigned int x=h->second; x<nextH->first; x++){
								if(outPixels[width * y + x]!=0){
									bottom=y;
									found=true;
									break;
								}
							}
							if(found)
								break;
						}
                        if(bottom-top<lineHeight/4)
							continue;
						if(rects.count < 44){
                            CGRect rect = CGRectMake(h->second, top, nextH->first - h->second, bottom - top);
                            [rects addObject:[NSValue valueWithCGRect:rect]];
						}
					}
				}
                [result addObject:rects];
				if((rects.count>=44 && result.count == 2) || (rects.count>=30 && result.count==3)){
					break;
				}
			}
		}
	}
    
    free(outPixels);
    
	if(result.count == 0)
		return NULL;
    
    return result;
}

NSString *performRecognition(UIImage *bitmap, int numRows, int numCols)
{
    NSString *filePath = TGComponentsPathForResource(@"ocr_nn", @"bin");
    NSData *nnData = [NSData dataWithContentsOfFile:filePath];
    
	struct genann* ann=genann_init(150, 1, 90, 37);
    memcpy(ann->weight, nnData.bytes, sizeof(double)*ann->total_weights);
	
    NSMutableString *res = [[NSMutableString alloc] init];
	const char* alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890<";
    
    CGImageRef imageRef = bitmap.CGImage;
    uint32_t width = (uint32_t)CGImageGetWidth(imageRef);
    uint32_t height = (uint32_t)CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    uint8_t *bitmapPixels = (uint8_t *)calloc(height * width * 1, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 1;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(bitmapPixels, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaNone);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
	double nnInput[150];
	for(int row=0;row<numRows;row++){
		for(int col=0;col<numCols;col++){
			unsigned int offX=static_cast<unsigned int>(col*10);
			unsigned int offY=static_cast<unsigned int>(row*15);
			for(unsigned int y=0;y<15;y++){
				for(unsigned int x=0;x<10;x++){
					nnInput[y*10+x]=(double)bitmapPixels[bytesPerRow * (offY+y) + offX + x]/255.0;
				}
			}
			const double* nnOut=genann_run(ann, nnInput);
			unsigned int bestIndex=0;
			for(unsigned int i=0;i<37;i++){
				if(nnOut[i]>nnOut[bestIndex])
					bestIndex=i;
			}
            
            [res appendString:[NSString stringWithFormat:@"%c", alphabet[bestIndex]]];
		}
		if(row!=numRows-1)
			[res appendString:@"\n"];
	}
	genann_free(ann);
    return res;
}

UIImage *normalizeImage(UIImage *image)
{
    if (image.imageOrientation == UIImageOrientationUp) return image;
    
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalizedImage;
}

NSString *recognizeMRZ(UIImage *input, CGRect *outBoundingRect)
{
    input = normalizeImage(input);
    
    UIImage *binaryImage;
    NSArray *charRects = binarizeAndFindCharacters(input, &binaryImage);
    if (charRects.count == 0)
        return nil;
    
    uint32_t width = 10 * (int)[charRects.firstObject count];
    uint32_t height = 15 * (int)charRects.count;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width, colorSpace, kCGImageAlphaNone);
    CGColorSpaceRelease(colorSpace);
    
    int x, y = 0;
    for (NSArray *line in charRects)
    {
        x = 0;
        for (NSValue *v in line)
        {
            CGRect rect = v.CGRectValue;
            CGRect dest = CGRectMake(x * 10, y * 15, 10, 15);
            
            CGImageRef charImage = CGImageCreateWithImageInRect(binaryImage.CGImage, rect);
            CGContextDrawImage(context, dest, charImage);
            CGImageRelease(charImage);
            
            x++;
        }
        y++;
    }
    
    CGImageRef charsImageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    UIImage *charsImage = [UIImage imageWithCGImage:charsImageRef];
    CGImageRelease(charsImageRef);
    
    NSString *result = performRecognition(charsImage, (int)charRects.count, (int)[charRects.firstObject count]);
    if (result != nil && outBoundingRect != NULL)
    {
        CGRect firstRect = [[charRects.firstObject firstObject] CGRectValue];
        firstRect.origin.y = input.size.height - firstRect.origin.y;
        CGRect lastRect = [[charRects.lastObject lastObject] CGRectValue];
        lastRect.origin.y = input.size.height - lastRect.origin.y;
        CGRect boundingRect = CGRectMake(CGRectGetMinX(firstRect), CGRectGetMinY(firstRect), CGRectGetMaxX(lastRect) - CGRectGetMinX(firstRect), CGRectGetMaxY(lastRect) - CGRectGetMinY(firstRect));
        *outBoundingRect = boundingRect;
    }
    return result;
}
