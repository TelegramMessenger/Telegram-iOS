//---------------------------------------------------------------------------------
//
//  Little Color Management System
//  Copyright (c) 1998-2017 Marti Maria Saguer
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//---------------------------------------------------------------------------------
//


#include "testcms2.h"


// ZOO checks ------------------------------------------------------------------------------------------------------------


#ifdef CMS_IS_WINDOWS_

static char ZOOfolder[cmsMAX_PATH] = "c:\\colormaps\\";
static char ZOOwrite[cmsMAX_PATH]  = "c:\\colormaps\\write\\";
static char ZOORawWrite[cmsMAX_PATH]  = "c:\\colormaps\\rawwrite\\";


// Read all tags on a profile given by its handle
static
void ReadAllTags(cmsHPROFILE h)
{
    cmsInt32Number i, n;
    cmsTagSignature sig;

    n = cmsGetTagCount(h);
    for (i=0; i < n; i++) {

        sig = cmsGetTagSignature(h, i);
        if (cmsReadTag(h, sig) == NULL) return;
    }
}


// Read all tags on a profile given by its handle
static
void ReadAllRAWTags(cmsHPROFILE h)
{
    cmsInt32Number i, n;
    cmsTagSignature sig;
    cmsInt32Number len;

    n = cmsGetTagCount(h);
    for (i=0; i < n; i++) {

        sig = cmsGetTagSignature(h, i);
        len = cmsReadRawTag(h, sig, NULL, 0);
    }
}


static
void PrintInfo(cmsHPROFILE h, cmsInfoType Info)
{
    wchar_t* text;
    cmsInt32Number len;
    cmsContext id = 0;

    len = cmsGetProfileInfo(h, Info, "en", "US", NULL, 0);
    if (len == 0) return;

    text = _cmsMalloc(id, len);
    cmsGetProfileInfo(h, Info, "en", "US", text, len);

    wprintf(L"%s\n", text);
    _cmsFree(id, text);
}


static
void PrintAllInfos(cmsHPROFILE h)
{
     PrintInfo(h, cmsInfoDescription);
     PrintInfo(h, cmsInfoManufacturer);
     PrintInfo(h, cmsInfoModel);
     PrintInfo(h, cmsInfoCopyright);
     printf("\n\n");
}

static
void ReadAllLUTS(cmsHPROFILE h)
{
    cmsPipeline* a;
    cmsCIEXYZ Black;

    a = _cmsReadInputLUT(h, INTENT_PERCEPTUAL);
    if (a) cmsPipelineFree(a);

    a = _cmsReadInputLUT(h, INTENT_RELATIVE_COLORIMETRIC);
    if (a) cmsPipelineFree(a);

    a = _cmsReadInputLUT(h, INTENT_SATURATION);
    if (a) cmsPipelineFree(a);

    a = _cmsReadInputLUT(h, INTENT_ABSOLUTE_COLORIMETRIC);
    if (a) cmsPipelineFree(a);


    a = _cmsReadOutputLUT(h, INTENT_PERCEPTUAL);
    if (a) cmsPipelineFree(a);

    a = _cmsReadOutputLUT(h, INTENT_RELATIVE_COLORIMETRIC);
    if (a) cmsPipelineFree(a);

    a = _cmsReadOutputLUT(h, INTENT_SATURATION);
    if (a) cmsPipelineFree(a);

    a = _cmsReadOutputLUT(h, INTENT_ABSOLUTE_COLORIMETRIC);
    if (a) cmsPipelineFree(a);


    a = _cmsReadDevicelinkLUT(h, INTENT_PERCEPTUAL);
    if (a) cmsPipelineFree(a);

    a = _cmsReadDevicelinkLUT(h, INTENT_RELATIVE_COLORIMETRIC);
    if (a) cmsPipelineFree(a);

    a = _cmsReadDevicelinkLUT(h, INTENT_SATURATION);
    if (a) cmsPipelineFree(a);

    a = _cmsReadDevicelinkLUT(h, INTENT_ABSOLUTE_COLORIMETRIC);
    if (a) cmsPipelineFree(a);


    cmsDetectDestinationBlackPoint(&Black, h, INTENT_PERCEPTUAL, 0);
    cmsDetectDestinationBlackPoint(&Black, h, INTENT_RELATIVE_COLORIMETRIC, 0);
    cmsDetectDestinationBlackPoint(&Black, h, INTENT_SATURATION, 0);
    cmsDetectDestinationBlackPoint(&Black, h, INTENT_ABSOLUTE_COLORIMETRIC, 0);
    cmsDetectTAC(h);
}

// Check one specimen in the ZOO

static
cmsInt32Number CheckSingleSpecimen(const char* Profile)
{
    char BuffSrc[256];
    char BuffDst[256];
    cmsHPROFILE h;

    sprintf(BuffSrc, "%s%s", ZOOfolder, Profile);
    sprintf(BuffDst, "%s%s", ZOOwrite,  Profile);

    h = cmsOpenProfileFromFile(BuffSrc, "r");
    if (h == NULL) return 0;

    printf("%s\n", Profile);

    PrintAllInfos(h);  
    ReadAllTags(h);    
    ReadAllLUTS(h);
 // ReadAllRAWTags(h);


    cmsSaveProfileToFile(h, BuffDst);
    cmsCloseProfile(h);

    h = cmsOpenProfileFromFile(BuffDst, "r");
    if (h == NULL) return 0;
    ReadAllTags(h);


    cmsCloseProfile(h);

    return 1;
}

static
cmsInt32Number CheckRAWSpecimen(const char* Profile)
{
    char BuffSrc[256];
    char BuffDst[256];
    cmsHPROFILE h;

    sprintf(BuffSrc, "%s%s", ZOOfolder, Profile);
    sprintf(BuffDst, "%s%s", ZOORawWrite,  Profile);

    h = cmsOpenProfileFromFile(BuffSrc, "r");
    if (h == NULL) return 0;

    ReadAllTags(h);
    ReadAllRAWTags(h);
    cmsSaveProfileToFile(h, BuffDst);
    cmsCloseProfile(h);

    h = cmsOpenProfileFromFile(BuffDst, "r");
    if (h == NULL) return 0;
    ReadAllTags(h);
    cmsCloseProfile(h);

    return 1;
}


static int input = 0, 
           disp = 0,
           output = 0,
           link = 0,
           abst = 0,
           color = 0, 
           named = 0;

static int rgb = 0,
           cmyk = 0,
           gray = 0,
           other = 0;



static
int count_stats(const char* Profile)
{
    char BuffSrc[256];
    cmsHPROFILE h;
    cmsCIEXYZ Black;

    sprintf(BuffSrc, "%s%s", ZOOfolder, Profile);
   
    h = cmsOpenProfileFromFile(BuffSrc, "r");
    if (h == NULL) return 0;

  
    switch (cmsGetDeviceClass(h)) { 

    case cmsSigInputClass        : input++; break;
    case cmsSigDisplayClass      : disp++; break;
    case cmsSigOutputClass       : output++; break;
    case cmsSigLinkClass         : link++;  break;
    case cmsSigAbstractClass     : abst++; break;
    case cmsSigColorSpaceClass   : color++; break;
    case cmsSigNamedColorClass   : named ++; break;
    }


    switch (cmsGetColorSpace(h)) {

    case cmsSigRgbData: rgb++; break;
    case cmsSigCmykData: cmyk++; break;
    case cmsSigGrayData: gray++; break;
    default: other++;
    }

    cmsDetectDestinationBlackPoint(&Black, h, INTENT_PERCEPTUAL, 0);
    cmsDetectDestinationBlackPoint(&Black, h, INTENT_RELATIVE_COLORIMETRIC, 0);
    cmsDetectDestinationBlackPoint(&Black, h, INTENT_SATURATION, 0);
   
    cmsCloseProfile(h);
   
    return 1;
}



void CheckProfileZOO(void)
{

    struct _finddata_t c_file;
    intptr_t hFile;

    cmsSetLogErrorHandler(NULL);

    if ( (hFile = _findfirst("c:\\colormaps\\*.*", &c_file)) == -1L )
        printf("No files in current directory");
    else
    {
        do
        {
            if (strcmp(c_file.name, ".") != 0 &&
                strcmp(c_file.name, "..") != 0) {

                    CheckSingleSpecimen( c_file.name);
                    CheckRAWSpecimen( c_file.name);

                    count_stats(c_file.name);

                    TestMemoryLeaks(FALSE);

            }

        } while ( _findnext(hFile, &c_file) == 0 );

        _findclose(hFile);
    }

     ResetFatalError();
}

#endif
