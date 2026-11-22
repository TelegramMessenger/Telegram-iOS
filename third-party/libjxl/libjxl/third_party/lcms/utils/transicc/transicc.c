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

#include "utils.h"

#ifndef _MSC_VER 
#    include <unistd.h> 
#endif 

#ifdef CMS_IS_WINDOWS_
#    include <io.h>
#endif

#define MAX_INPUT_BUFFER 4096

// Global options

static cmsBool           InHexa                 = FALSE;
static cmsBool           GamutCheck             = FALSE;
static cmsBool           Width16                = FALSE;
static cmsBool           BlackPointCompensation = FALSE;
static cmsBool           lIsDeviceLink          = FALSE;
static cmsBool           lQuantize              = FALSE;
static cmsBool           lUnbounded             = TRUE;
static cmsBool           lIsFloat               = TRUE;

static cmsUInt32Number   Intent           = INTENT_PERCEPTUAL;
static cmsUInt32Number   ProofingIntent   = INTENT_PERCEPTUAL;

static int PrecalcMode  = 0;

// --------------------------------------------------------------

static char *cInProf   = NULL;
static char *cOutProf  = NULL;
static char *cProofing = NULL;

static char *IncludePart = NULL;

static cmsHANDLE hIT8in = NULL;        // CGATS input 
static cmsHANDLE hIT8out = NULL;       // CGATS output

static char CGATSPatch[1024];   // Actual Patch Name
static char CGATSoutFilename[cmsMAX_PATH];

static int nMaxPatches;

static cmsHTRANSFORM hTrans, hTransXYZ, hTransLab;
static cmsBool InputNamedColor = FALSE;

static cmsColorSpaceSignature InputColorSpace, OutputColorSpace;

static cmsNAMEDCOLORLIST* InputColorant = NULL;
static cmsNAMEDCOLORLIST* OutputColorant = NULL;

static cmsFloat64Number InputRange, OutputRange;


// isatty replacement
#ifdef _MSC_VER
#define xisatty(x) _isatty( _fileno( (x) ) )
#else
#define xisatty(x) isatty( fileno( (x) ) )
#endif

//---------------------------------------------------------------------------------------------------

// Print usage to stderr
static
void Help(void)
{           

    fprintf(stderr, "usage: transicc [flags] [CGATS input] [CGATS output]\n\n");

    fprintf(stderr, "flags:\n\n");
    fprintf(stderr, "%cv<0..3> - Verbosity level\n", SW); 

    fprintf(stderr, "%ce[op] - Encoded representation of numbers\n", SW);
    fprintf(stderr, "\t%cw - use 16 bits\n", SW);     
    fprintf(stderr, "\t%cx - Hexadecimal\n\n", SW);

    fprintf(stderr, "%cs - bounded mode (clip negatives and highliths)\n", SW);
    fprintf(stderr, "%cq - Quantize (round decimals)\n\n", SW);

    fprintf(stderr, "%ci<profile> - Input profile (defaults to sRGB)\n", SW);
    fprintf(stderr, "%co<profile> - Output profile (defaults to sRGB)\n", SW);   
    fprintf(stderr, "%cl<profile> - Transform by device-link profile\n", SW);   

    fprintf(stderr, "\nYou can use '*Lab', '*xyz' and others as built-in profiles\n\n");

    PrintRenderingIntents();

    fprintf(stderr, "\n");

    fprintf(stderr, "%cd<0..1> - Observer adaptation state (abs.col. only)\n\n", SW);

    fprintf(stderr, "%cb - Black point compensation\n", SW);

    fprintf(stderr, "%cc<0,1,2,3> Precalculates transform (0=Off, 1=Normal, 2=Hi-res, 3=LoRes)\n\n", SW);     
    fprintf(stderr, "%cn - Terse output, intended for pipe usage\n", SW);

    fprintf(stderr, "%cp<profile> - Soft proof profile\n", SW);
    fprintf(stderr, "%cm<0,1,2,3> - Soft proof intent\n", SW);
    fprintf(stderr, "%cg - Marks out-of-gamut colors on softproof\n\n", SW);



    fprintf(stderr, "This program is intended to be a demo of the little cms\n"
        "engine. Both lcms and this program are freeware. You can\n"
        "obtain both in source code at http://www.littlecms.com\n"
        "For suggestions, comments, bug reports etc. send mail to\n"
        "info@littlecms.com\n\n");
}



// The toggles stuff

static
void HandleSwitches(int argc, char *argv[])
{
    int s;

    while ((s = xgetopt(argc, argv,
        "bBC:c:d:D:eEgGI:i:L:l:m:M:nNO:o:p:P:QqSsT:t:V:v:WwxX!:")) != EOF) {

    switch (s){

        case '!': 
            IncludePart = xoptarg;
            break;

        case 'b':
        case 'B': 
            BlackPointCompensation = TRUE;
            break;

        case 'c':
        case 'C':
            PrecalcMode = atoi(xoptarg);
            if (PrecalcMode < 0 || PrecalcMode > 3)
                FatalError("Unknown precalc mode '%d'", PrecalcMode);
            break;

        case 'd':
        case 'D': {
            cmsFloat64Number ObserverAdaptationState = atof(xoptarg);
            if (ObserverAdaptationState < 0 || 
                ObserverAdaptationState > 1.0)
                FatalError("Adaptation states should be between 0 and 1");

            cmsSetAdaptationState(ObserverAdaptationState);
                  }
                  break;

        case 'e':
        case 'E': 
            lIsFloat = FALSE;
            break;

        case 'g':
        case 'G':
            GamutCheck = TRUE;
            break;

        case 'i':
        case 'I':
            if (lIsDeviceLink)
                FatalError("icctrans: Device-link already specified");

            cInProf = xoptarg;
            break;  

        case 'l':
        case 'L': 
            cInProf = xoptarg;
            lIsDeviceLink = TRUE;
            break;

            // No extra intents for proofing
        case 'm':
        case 'M':
            ProofingIntent = atoi(xoptarg);
            if (ProofingIntent > 3)
                FatalError("Unknown Proofing Intent '%d'", ProofingIntent);        
            break;      

            // For compatibility
        case 'n':
        case 'N':
            Verbose = 0;
            break;

            // Output profile        
        case 'o':
        case 'O':
            if (lIsDeviceLink)
                FatalError("icctrans: Device-link already specified"); 
            cOutProf = xoptarg;
            break;

            // Proofing profile
        case 'p':
        case 'P':
            cProofing = xoptarg;
            break;      

            // Quantize (get rid of decimals)
        case 'q':
        case 'Q': 
            lQuantize = TRUE;
            break;

            // Inhibit unbounded mode
        case 's':
        case 'S':
               lUnbounded = FALSE;
               break;

            // The intent
        case 't':
        case 'T':
            Intent = atoi(xoptarg);            
            break;

            // Verbosity level
        case 'V':
        case 'v':
            Verbose = atoi(xoptarg);
            if (Verbose < 0 || Verbose > 3) {
                FatalError("Unknown verbosity level '%d'", Verbose);
            }
            break;

            // Wide (16 bits)
        case 'W':
        case 'w':
            Width16 = TRUE;
            break;

            // Hexadecimal        
        case 'x':
        case 'X':
            InHexa = TRUE;
            break;

        default:            
            FatalError("Unknown option - run without args to see valid ones.\n");
            }       
    }


    // If output CGATS involved, switch to float
    if ((argc - xoptind) > 2) {
        lIsFloat = TRUE;
    }
}



static
void SetRange(cmsFloat64Number range, cmsBool IsInput)
{
    if (IsInput)
        InputRange = range;
    else
        OutputRange = range;
}

// Populate a named color list with usual component names. 
// I am using the first Colorant channel to store the range, but it works since 
// this space is not used anyway.
static
cmsNAMEDCOLORLIST* ComponentNames(cmsColorSpaceSignature space, cmsBool IsInput)
{
    cmsNAMEDCOLORLIST* out;
    int i, n;
    char Buffer[cmsMAX_PATH];

    out = cmsAllocNamedColorList(0, 12, cmsMAXCHANNELS, "", "");
    if (out == NULL) return NULL;

    switch (space) {

    case cmsSigXYZData:
        SetRange(100, IsInput);
        cmsAppendNamedColor(out, "X", NULL, NULL);
        cmsAppendNamedColor(out, "Y", NULL, NULL);
        cmsAppendNamedColor(out, "Z", NULL, NULL);
        break;

    case cmsSigLabData:
        SetRange(1, IsInput);
        cmsAppendNamedColor(out, "L*", NULL, NULL);
        cmsAppendNamedColor(out, "a*", NULL, NULL);
        cmsAppendNamedColor(out, "b*", NULL, NULL);
        break;

    case cmsSigLuvData:
        SetRange(1, IsInput);
        cmsAppendNamedColor(out, "L", NULL, NULL);
        cmsAppendNamedColor(out, "u", NULL, NULL);
        cmsAppendNamedColor(out, "v", NULL, NULL);
        break;

    case cmsSigYCbCrData:
        SetRange(255, IsInput);
        cmsAppendNamedColor(out, "Y", NULL, NULL );
        cmsAppendNamedColor(out, "Cb", NULL, NULL);
        cmsAppendNamedColor(out, "Cr", NULL, NULL);
        break;


    case cmsSigYxyData:
        SetRange(1, IsInput);
        cmsAppendNamedColor(out, "Y", NULL, NULL);
        cmsAppendNamedColor(out, "x", NULL, NULL);
        cmsAppendNamedColor(out, "y", NULL, NULL);
        break;

    case cmsSigRgbData:
        SetRange(255, IsInput);
        cmsAppendNamedColor(out, "R", NULL, NULL);
        cmsAppendNamedColor(out, "G", NULL, NULL);
        cmsAppendNamedColor(out, "B", NULL, NULL);
        break;

    case cmsSigGrayData:
        SetRange(255, IsInput);
        cmsAppendNamedColor(out, "G", NULL, NULL);      
        break;

    case cmsSigHsvData:
        SetRange(255, IsInput);
        cmsAppendNamedColor(out, "H", NULL, NULL);
        cmsAppendNamedColor(out, "s", NULL, NULL);
        cmsAppendNamedColor(out, "v", NULL, NULL);
        break;

    case cmsSigHlsData:
        SetRange(255, IsInput);
        cmsAppendNamedColor(out, "H", NULL, NULL);
        cmsAppendNamedColor(out, "l", NULL, NULL);
        cmsAppendNamedColor(out, "s", NULL, NULL);
        break;

    case cmsSigCmykData:
        SetRange(1, IsInput);
        cmsAppendNamedColor(out, "C", NULL, NULL);
        cmsAppendNamedColor(out, "M", NULL, NULL);
        cmsAppendNamedColor(out, "Y", NULL, NULL);                     
        cmsAppendNamedColor(out, "K", NULL, NULL);
        break;

    case cmsSigCmyData:
        SetRange(1, IsInput);
        cmsAppendNamedColor(out, "C", NULL, NULL);
        cmsAppendNamedColor(out, "M", NULL, NULL);
        cmsAppendNamedColor(out, "Y", NULL, NULL);
        break;

    default:

        SetRange(1, IsInput);

        n = cmsChannelsOf(space);

        for (i=0; i < n; i++) {

            sprintf(Buffer, "Channel #%d", i + 1);
            cmsAppendNamedColor(out, Buffer, NULL, NULL);
        }
    }

    return out;

}


// Creates all needed color transforms
static
cmsBool OpenTransforms(void)
{
    cmsHPROFILE hInput, hOutput, hProof;
    cmsUInt32Number dwIn, dwOut, dwFlags;
    cmsNAMEDCOLORLIST* List;
    int i;

    // We don't need cache
    dwFlags = cmsFLAGS_NOCACHE;

    if (lIsDeviceLink) {

        hInput  = OpenStockProfile(0, cInProf);
        if (hInput == NULL) return FALSE; 
        hOutput = NULL;
        hProof  = NULL;

        if (cmsGetDeviceClass(hInput) == cmsSigNamedColorClass) {
            OutputColorSpace  = cmsGetColorSpace(hInput);
            InputColorSpace = cmsGetPCS(hInput);
        }
        else {
            InputColorSpace  = cmsGetColorSpace(hInput);
            OutputColorSpace = cmsGetPCS(hInput);
        }

        // Read colorant tables if present
        if (cmsIsTag(hInput, cmsSigColorantTableTag)) {
            List = cmsReadTag(hInput, cmsSigColorantTableTag);
            InputColorant = cmsDupNamedColorList(List);
            InputRange = 1;
        }
        else InputColorant = ComponentNames(InputColorSpace, TRUE);

        if (cmsIsTag(hInput, cmsSigColorantTableOutTag)){

            List = cmsReadTag(hInput, cmsSigColorantTableOutTag);
            OutputColorant = cmsDupNamedColorList(List);
            OutputRange = 1;
        }
        else OutputColorant = ComponentNames(OutputColorSpace, FALSE);

    }
    else {

        hInput  = OpenStockProfile(0, cInProf);
        if (hInput == NULL) return FALSE;

        hOutput = OpenStockProfile(0, cOutProf);    
        if (hOutput == NULL) return FALSE;
        hProof  = NULL;


        if (cmsGetDeviceClass(hInput) == cmsSigLinkClass ||
            cmsGetDeviceClass(hOutput) == cmsSigLinkClass)   
            FatalError("Use %cl flag for devicelink profiles!\n", SW);


        InputColorSpace   = cmsGetColorSpace(hInput);
        OutputColorSpace  = cmsGetColorSpace(hOutput);

        // Read colorant tables if present
        if (cmsIsTag(hInput, cmsSigColorantTableTag)) {
            List = cmsReadTag(hInput, cmsSigColorantTableTag);
            InputColorant = cmsDupNamedColorList(List);
            if (cmsNamedColorCount(InputColorant) <= 3) 
                SetRange(255, TRUE);
            else
                SetRange(1, TRUE);  // Inks are already divided by 100 in the formatter

        }
        else InputColorant = ComponentNames(InputColorSpace, TRUE);

        if (cmsIsTag(hOutput, cmsSigColorantTableTag)){

            List = cmsReadTag(hOutput, cmsSigColorantTableTag);
            OutputColorant = cmsDupNamedColorList(List);
            if (cmsNamedColorCount(OutputColorant) <= 3) 
                SetRange(255, FALSE);
            else
                SetRange(1, FALSE);  // Inks are already divided by 100 in the formatter
        }
        else OutputColorant = ComponentNames(OutputColorSpace, FALSE);


        if (cProofing != NULL) {

            hProof = OpenStockProfile(0, cProofing);
            if (hProof == NULL) return FALSE;
            dwFlags |= cmsFLAGS_SOFTPROOFING;
        }
    }

    // Print information on profiles
    if (Verbose > 2) {

        printf("Profile:\n");
        PrintProfileInformation(hInput);

        if (hOutput) {

            printf("Output profile:\n");
            PrintProfileInformation(hOutput);
        }  

        if (hProof != NULL) {
            printf("Proofing profile:\n");
            PrintProfileInformation(hProof);
        }
    }


    // Input is always in floating point
    dwIn  = cmsFormatterForColorspaceOfProfile(hInput, 0, TRUE);

    if (lIsDeviceLink) {

        dwOut = cmsFormatterForPCSOfProfile(hInput, lIsFloat ? 0 : 2, lIsFloat);
    }
    else {

        // 16 bits or floating point (only on output)   
        dwOut = cmsFormatterForColorspaceOfProfile(hOutput, lIsFloat ? 0 : 2, lIsFloat);
    }

    // For named color, there is a specialized formatter
    if (cmsGetDeviceClass(hInput) == cmsSigNamedColorClass) {
        
        dwIn = TYPE_NAMED_COLOR_INDEX;
        InputNamedColor = TRUE;
    }

    // Precision mode
    switch (PrecalcMode) {

       case 0: dwFlags |= cmsFLAGS_NOOPTIMIZE; break;
       case 2: dwFlags |= cmsFLAGS_HIGHRESPRECALC; break;
       case 3: dwFlags |= cmsFLAGS_LOWRESPRECALC; break;
       case 1: break;

       default: 
           FatalError("Unknown precalculation mode '%d'", PrecalcMode);
    }


    if (BlackPointCompensation) 
        dwFlags |= cmsFLAGS_BLACKPOINTCOMPENSATION;


    if (GamutCheck) {

        cmsUInt16Number Alarm[cmsMAXCHANNELS];

        if (hProof == NULL)
            FatalError("I need proofing profile -p for gamut checking!");

        for (i=0; i < cmsMAXCHANNELS; i++)
            Alarm[i] = 0xFFFF;

        cmsSetAlarmCodes(Alarm);
        dwFlags |= cmsFLAGS_GAMUTCHECK;            
    }


    // The main transform
    hTrans = cmsCreateProofingTransform(hInput,  dwIn, hOutput, dwOut, hProof, Intent, ProofingIntent, dwFlags);

    if (hProof) cmsCloseProfile(hProof);

    if (hTrans == NULL) return FALSE;


    // PCS Dump if requested
    hTransXYZ = NULL; hTransLab = NULL;

    if (hOutput && Verbose > 1) {

        cmsHPROFILE hXYZ = cmsCreateXYZProfile();
        cmsHPROFILE hLab = cmsCreateLab4Profile(NULL);

        hTransXYZ = cmsCreateTransform(hInput, dwIn, hXYZ,  lIsFloat ? TYPE_XYZ_DBL : TYPE_XYZ_16, Intent, cmsFLAGS_NOCACHE);        
        if (hTransXYZ == NULL) return FALSE;

        hTransLab = cmsCreateTransform(hInput, dwIn, hLab,  lIsFloat? TYPE_Lab_DBL : TYPE_Lab_16, Intent, cmsFLAGS_NOCACHE);    
        if (hTransLab == NULL) return FALSE;

        cmsCloseProfile(hXYZ);
        cmsCloseProfile(hLab);
    } 

    if (hInput) cmsCloseProfile(hInput);
    if (hOutput) cmsCloseProfile(hOutput); 

    return TRUE;
}


// Free open resources
static
void CloseTransforms(void)
{
    if (InputColorant) cmsFreeNamedColorList(InputColorant);
    if (OutputColorant) cmsFreeNamedColorList(OutputColorant);

    if (hTrans) cmsDeleteTransform(hTrans);
    if (hTransLab) cmsDeleteTransform(hTransLab);
    if (hTransXYZ) cmsDeleteTransform(hTransXYZ);

}

// ---------------------------------------------------------------------------------------------------

// Get input from user
static
void GetLine(char* Buffer, const char* frm, ...)
{    
    int res;
    va_list args;

    va_start(args, frm);

    do {
        if (xisatty(stdin)) 
            vfprintf(stderr, frm, args);

        res = scanf("%4095s", Buffer);

        if (res < 0 || toupper(Buffer[0]) == 'Q') { // Quit?

            CloseTransforms();

            if (xisatty(stdin))  
                fprintf(stderr, "Done.\n");

            exit(0);        
        }
    } while (res == 0);

    va_end(args);  
}


// Print a value which is given in double floating point
static
void PrintFloatResults(cmsFloat64Number Value[])
{
    cmsUInt32Number i, n;
    char ChannelName[cmsMAX_PATH];
    cmsFloat64Number v;

    n = cmsChannelsOf(OutputColorSpace);
    for (i=0; i < n; i++) {

        if (OutputColorant != NULL) {

            cmsNamedColorInfo(OutputColorant, i, ChannelName, NULL, NULL, NULL, NULL);         
        }
        else {
            OutputRange = 1;
            sprintf(ChannelName, "Channel #%u", i + 1);
        }

        v = (cmsFloat64Number) Value[i]* OutputRange;

        if (lQuantize) 
            v = floor(v + 0.5);

        if (!lUnbounded) {

               if (v < 0)
                      v = 0;
               if (v > OutputRange)
                      v = OutputRange;
        }

        if (Verbose <= 0)
            printf("%.4f ", v);
        else
            printf("%s=%.4f ", ChannelName, v);
    }   

    printf("\n");
}


// Get a named-color index
static
cmsUInt16Number GetIndex(void)
{
    char Buffer[4096], Name[cmsMAX_PATH], Prefix[40], Suffix[40];
    int index, max;
    const cmsNAMEDCOLORLIST* NamedColorList;
    
    NamedColorList = cmsGetNamedColorList(hTrans);
    if (NamedColorList == NULL) return 0;

    max = cmsNamedColorCount(NamedColorList)-1;

    GetLine(Buffer, "Color index (0..%d)? ", max);
    index = atoi(Buffer);

    if (index > max)
        FatalError("Named color %d out of range!", index);

    cmsNamedColorInfo(NamedColorList, index, Name, Prefix, Suffix, NULL, NULL);

    printf("\n%s %s %s\n", Prefix, Name, Suffix);

    return (cmsUInt16Number) index;
}

// Read values from a text file or terminal
static
void TakeFloatValues(cmsFloat64Number Float[])
{
    cmsUInt32Number i, n;
    char ChannelName[cmsMAX_PATH];
    char Buffer[4096];

    if (xisatty(stdin))
        fprintf(stderr, "\nEnter values, 'q' to quit\n");

    if (InputNamedColor) {

        // This is named color index, which is always cmsUInt16Number
        cmsUInt16Number index = GetIndex();
        memcpy(Float, &index, sizeof(cmsUInt16Number));
        return;
    }

    n = cmsChannelsOf(InputColorSpace);
    for (i=0; i < n; i++) {

        if (InputColorant) {
            cmsNamedColorInfo(InputColorant, i, ChannelName, NULL, NULL, NULL, NULL);          
        }
        else {
            InputRange = 1;
            sprintf(ChannelName, "Channel #%u", i+1);
        }

        GetLine(Buffer, "%s? ", ChannelName);

        Float[i] = (cmsFloat64Number) atof(Buffer) / InputRange;
    }       

    if (xisatty(stdin))
        fprintf(stderr, "\n");
}

static
void PrintPCSFloat(cmsFloat64Number Input[])
{
    if (Verbose > 1 && hTransXYZ && hTransLab) {

        cmsCIEXYZ XYZ = { 0, 0, 0 };
        cmsCIELab Lab = { 0, 0, 0 };

        if (hTransXYZ) cmsDoTransform(hTransXYZ, Input, &XYZ, 1);
        if (hTransLab) cmsDoTransform(hTransLab, Input, &Lab, 1);

        printf("[PCS] Lab=(%.4f,%.4f,%.4f) XYZ=(%.4f,%.4f,%.4f)\n", Lab.L, Lab.a, Lab.b, 
            XYZ.X * 100.0, XYZ.Y * 100.0, XYZ.Z * 100.0);

    }
}




// -----------------------------------------------------------------------------------------------

static
void PrintEncodedResults(cmsUInt16Number Encoded[])
{
    cmsUInt32Number i, n;
    char ChannelName[cmsMAX_PATH];
    cmsUInt32Number v;

    n = cmsChannelsOf(OutputColorSpace);
    for (i=0; i < n; i++) {

        if (OutputColorant != NULL) {

            cmsNamedColorInfo(OutputColorant, i, ChannelName, NULL, NULL, NULL, NULL);          
        }
        else {          
            sprintf(ChannelName, "Channel #%u", i + 1);
        }

        if (Verbose > 0)
            printf("%s=", ChannelName);

        v = Encoded[i];

        if (InHexa) {

            if (Width16)
                printf("0x%04X ", (int) floor(v + .5));
            else
                printf("0x%02X ", (int) floor(v / 257. + .5));

        } else {

            if (Width16)
                printf("%d ", (int) floor(v + .5));
            else
                printf("%d ", (int) floor(v / 257. + .5));
        }

    }   

    printf("\n");
}

// Print XYZ/Lab values on verbose mode

static
void PrintPCSEncoded(cmsFloat64Number Input[])
{
    if (Verbose > 1 && hTransXYZ && hTransLab) {

        cmsUInt16Number XYZ[3], Lab[3];

        if (hTransXYZ) cmsDoTransform(hTransXYZ, Input, XYZ, 1);
        if (hTransLab) cmsDoTransform(hTransLab, Input, Lab, 1);

        printf("[PCS] Lab=(0x%04X,0x%04X,0x%04X) XYZ=(0x%04X,0x%04X,0x%04X)\n", Lab[0], Lab[1], Lab[2], 
            XYZ[0], XYZ[1], XYZ[2]);

    }
}


// --------------------------------------------------------------------------------------



// Take a value from IT8 and scale it accordly to fill a cmsUInt16Number (0..FFFF)

static
cmsFloat64Number GetIT8Val(const char* Name, cmsFloat64Number Max)
{
    const char* Val = cmsIT8GetData(hIT8in, CGATSPatch, Name);

    if (Val == NULL) 
        FatalError("Field '%s' not found", Name);

    return atof(Val) / Max;

}


// Read input values from CGATS file.

static
    void TakeCGATSValues(int nPatch, cmsFloat64Number Float[])
{

    // At first take the name if SAMPLE_ID is present
    if (cmsIT8GetPatchName(hIT8in, nPatch, CGATSPatch) == NULL) {
        FatalError("Sorry, I need 'SAMPLE_ID' on input CGATS to operate.");
    }


    // Special handling for named color profiles. 
    // Lookup the name in the names database (the transform)

    if (InputNamedColor) {

        const cmsNAMEDCOLORLIST* NamedColorList;
        int index;

        NamedColorList = cmsGetNamedColorList(hTrans);
        if (NamedColorList == NULL) 
            FatalError("Malformed named color profile");

        index = cmsNamedColorIndex(NamedColorList, CGATSPatch);
        if (index < 0) 
            FatalError("Named color '%s' not found in the profile", CGATSPatch); 

        Float[0] = index;
        return;
    }

    // Color is not a spot color, proceed.

    switch (InputColorSpace) {

        // Encoding should follow CGATS specification.

    case cmsSigXYZData:
        Float[0] = cmsIT8GetDataDbl(hIT8in, CGATSPatch, "XYZ_X") / 100.0;
        Float[1] = cmsIT8GetDataDbl(hIT8in, CGATSPatch, "XYZ_Y") / 100.0;
        Float[2] = cmsIT8GetDataDbl(hIT8in, CGATSPatch, "XYZ_Z") / 100.0;        
        break;

    case cmsSigLabData:
        Float[0] = cmsIT8GetDataDbl(hIT8in, CGATSPatch, "LAB_L");
        Float[1] = cmsIT8GetDataDbl(hIT8in, CGATSPatch, "LAB_A");
        Float[2] = cmsIT8GetDataDbl(hIT8in, CGATSPatch, "LAB_B");        
        break;


    case cmsSigRgbData:
        Float[0] = GetIT8Val("RGB_R", 255.0);
        Float[1] = GetIT8Val("RGB_G", 255.0);
        Float[2] = GetIT8Val("RGB_B", 255.0);
        break;

    case cmsSigGrayData:
        Float[0] = GetIT8Val("GRAY", 255.0);
        break;

    case cmsSigCmykData:
        Float[0] = GetIT8Val("CMYK_C", 1.0);
        Float[1] = GetIT8Val("CMYK_M", 1.0);
        Float[2] = GetIT8Val("CMYK_Y", 1.0);
        Float[3] = GetIT8Val("CMYK_K", 1.0);
        break;

    case cmsSigCmyData:                        
        Float[0] = GetIT8Val("CMY_C", 1.0);
        Float[1] = GetIT8Val("CMY_M", 1.0);
        Float[2] = GetIT8Val("CMY_Y", 1.0);
        break;

    case cmsSig1colorData:
    case cmsSig2colorData:
    case cmsSig3colorData:
    case cmsSig4colorData:
    case cmsSig5colorData:
    case cmsSig6colorData:
    case cmsSig7colorData:
    case cmsSig8colorData:
    case cmsSig9colorData:
    case cmsSig10colorData:
    case cmsSig11colorData:
    case cmsSig12colorData:
    case cmsSig13colorData:
    case cmsSig14colorData:
    case cmsSig15colorData:
        {
            cmsUInt32Number i, n;

            n = cmsChannelsOf(InputColorSpace);
            for (i=0; i < n; i++) { 

                char Buffer[255];

                sprintf(Buffer, "%uCLR_%u", n, i+1);
                Float[i] = GetIT8Val(Buffer, 100.0);
            }

        }
        break;

    default: 
        {
            cmsUInt32Number i, n;

            n = cmsChannelsOf(InputColorSpace);
            for (i=0; i < n; i++) { 

                char Buffer[255];

                sprintf(Buffer, "CHAN_%u", i+1);
                Float[i] = GetIT8Val(Buffer, 1.0);
            }

        }
    }

}

static
void SetCGATSfld(const char* Col, cmsFloat64Number Val)
{
    if (lQuantize) 
        Val = floor(Val + 0.5);

    if (!cmsIT8SetDataDbl(hIT8out, CGATSPatch, Col, Val)) {
        FatalError("couldn't set '%s' on output cgats '%s'", Col, CGATSoutFilename);
    }
}



static
void PutCGATSValues(cmsFloat64Number Float[])
{   
    cmsIT8SetData(hIT8out, CGATSPatch, "SAMPLE_ID", CGATSPatch);
    switch (OutputColorSpace) {


    // Encoding should follow CGATS specification.

    case cmsSigXYZData:

        SetCGATSfld("XYZ_X", Float[0] * 100.0);
        SetCGATSfld("XYZ_Y", Float[1] * 100.0);
        SetCGATSfld("XYZ_Z", Float[2] * 100.0);                    
        break;

    case cmsSigLabData:

        SetCGATSfld("LAB_L", Float[0]);
        SetCGATSfld("LAB_A", Float[1]);
        SetCGATSfld("LAB_B", Float[2]);                    
        break;


    case cmsSigRgbData:
        SetCGATSfld("RGB_R", Float[0] * 255.0);
        SetCGATSfld("RGB_G", Float[1] * 255.0);
        SetCGATSfld("RGB_B", Float[2] * 255.0);
        break;

    case cmsSigGrayData:
        SetCGATSfld("GRAY", Float[0] * 255.0);                    
        break;

    case cmsSigCmykData:
        SetCGATSfld("CMYK_C", Float[0]);
        SetCGATSfld("CMYK_M", Float[1]);
        SetCGATSfld("CMYK_Y", Float[2]);
        SetCGATSfld("CMYK_K", Float[3]);
        break;

    case cmsSigCmyData:
        SetCGATSfld("CMY_C", Float[0]);
        SetCGATSfld("CMY_M", Float[1]);
        SetCGATSfld("CMY_Y", Float[2]);                 
        break;

    case cmsSig1colorData:
    case cmsSig2colorData:
    case cmsSig3colorData:
    case cmsSig4colorData:
    case cmsSig5colorData:
    case cmsSig6colorData:
    case cmsSig7colorData:
    case cmsSig8colorData:
    case cmsSig9colorData:
    case cmsSig10colorData:
    case cmsSig11colorData:
    case cmsSig12colorData:
    case cmsSig13colorData:
    case cmsSig14colorData:
    case cmsSig15colorData:
        {

            cmsUInt32Number i, n;

            n = cmsChannelsOf(InputColorSpace);
            for (i=0; i < n; i++) { 

                char Buffer[255];

                sprintf(Buffer, "%uCLR_%u", n, i+1);

                SetCGATSfld(Buffer, Float[i] * 100.0);
            }
        }
        break;

    default: 
        {

            cmsUInt32Number i, n;

            n = cmsChannelsOf(InputColorSpace);
            for (i=0; i < n; i++) { 

                char Buffer[255];

                sprintf(Buffer, "CHAN_%u", i+1);

                SetCGATSfld(Buffer, Float[i]);
            }
        }
    }
}



// Create data format 
static
void SetOutputDataFormat(void) 
{
    cmsIT8DefineDblFormat(hIT8out, "%.4g");
    cmsIT8SetPropertyStr(hIT8out, "ORIGINATOR", "icctrans");

    if (IncludePart != NULL) 
        cmsIT8SetPropertyStr(hIT8out, ".INCLUDE", IncludePart);

    cmsIT8SetComment(hIT8out, "Data follows");
    cmsIT8SetPropertyDbl(hIT8out, "NUMBER_OF_SETS", nMaxPatches);


    switch (OutputColorSpace) {


        // Encoding should follow CGATS specification.

    case cmsSigXYZData:
        cmsIT8SetPropertyDbl(hIT8out, "NUMBER_OF_FIELDS", 4);
        cmsIT8SetDataFormat(hIT8out, 0, "SAMPLE_ID");
        cmsIT8SetDataFormat(hIT8out, 1, "XYZ_X");
        cmsIT8SetDataFormat(hIT8out, 2, "XYZ_Y");
        cmsIT8SetDataFormat(hIT8out, 3, "XYZ_Z");
        break;

    case cmsSigLabData:
        cmsIT8SetPropertyDbl(hIT8out, "NUMBER_OF_FIELDS", 4);
        cmsIT8SetDataFormat(hIT8out, 0, "SAMPLE_ID");
        cmsIT8SetDataFormat(hIT8out, 1, "LAB_L");
        cmsIT8SetDataFormat(hIT8out, 2, "LAB_A");
        cmsIT8SetDataFormat(hIT8out, 3, "LAB_B");
        break;


    case cmsSigRgbData:
        cmsIT8SetPropertyDbl(hIT8out, "NUMBER_OF_FIELDS", 4);
        cmsIT8SetDataFormat(hIT8out, 0, "SAMPLE_ID");
        cmsIT8SetDataFormat(hIT8out, 1, "RGB_R");
        cmsIT8SetDataFormat(hIT8out, 2, "RGB_G");
        cmsIT8SetDataFormat(hIT8out, 3, "RGB_B");
        break;

    case cmsSigGrayData:                
        cmsIT8SetPropertyDbl(hIT8out, "NUMBER_OF_FIELDS", 2);
        cmsIT8SetDataFormat(hIT8out, 0, "SAMPLE_ID");
        cmsIT8SetDataFormat(hIT8out, 1, "GRAY");
        break;

    case cmsSigCmykData:
        cmsIT8SetPropertyDbl(hIT8out, "NUMBER_OF_FIELDS", 5);
        cmsIT8SetDataFormat(hIT8out, 0, "SAMPLE_ID");
        cmsIT8SetDataFormat(hIT8out, 1, "CMYK_C");
        cmsIT8SetDataFormat(hIT8out, 2, "CMYK_M");
        cmsIT8SetDataFormat(hIT8out, 3, "CMYK_Y");
        cmsIT8SetDataFormat(hIT8out, 4, "CMYK_K");
        break;

    case cmsSigCmyData:
        cmsIT8SetPropertyDbl(hIT8out, "NUMBER_OF_FIELDS", 4);
        cmsIT8SetDataFormat(hIT8out, 0, "SAMPLE_ID");
        cmsIT8SetDataFormat(hIT8out, 1, "CMY_C");
        cmsIT8SetDataFormat(hIT8out, 2, "CMY_M");
        cmsIT8SetDataFormat(hIT8out, 3, "CMY_Y");                   
        break;

    case cmsSig1colorData:
    case cmsSig2colorData:
    case cmsSig3colorData:
    case cmsSig4colorData:
    case cmsSig5colorData:
    case cmsSig6colorData:
    case cmsSig7colorData:
    case cmsSig8colorData:
    case cmsSig9colorData:
    case cmsSig10colorData:
    case cmsSig11colorData:
    case cmsSig12colorData:
    case cmsSig13colorData:
    case cmsSig14colorData:
    case cmsSig15colorData:
        {
            int i, n;
            char Buffer[255];

            n = cmsChannelsOf(OutputColorSpace);
            cmsIT8SetPropertyDbl(hIT8out, "NUMBER_OF_FIELDS", n+1);
            cmsIT8SetDataFormat(hIT8out, 0, "SAMPLE_ID");

            for (i=1; i <= n; i++) {
                sprintf(Buffer, "%dCLR_%d", n, i);
                cmsIT8SetDataFormat(hIT8out, i, Buffer);
            }
        }
        break;

    default: {

        int i, n;
        char Buffer[255];

        n = cmsChannelsOf(OutputColorSpace);
        cmsIT8SetPropertyDbl(hIT8out, "NUMBER_OF_FIELDS", n+1);
        cmsIT8SetDataFormat(hIT8out, 0, "SAMPLE_ID");

        for (i=1; i <= n; i++) {
            sprintf(Buffer, "CHAN_%d", i);
            cmsIT8SetDataFormat(hIT8out, i, Buffer);
        }
    }
    }
}

// Open CGATS if specified

static
void OpenCGATSFiles(int argc, char *argv[])
{    
    int nParams = argc - xoptind;

    if (nParams >= 1)  {

        hIT8in = cmsIT8LoadFromFile(0, argv[xoptind]);

        if (hIT8in == NULL) 
            FatalError("'%s' is not recognized as a CGATS file", argv[xoptind]);

        nMaxPatches = (int) cmsIT8GetPropertyDbl(hIT8in, "NUMBER_OF_SETS");     
    }

    if (nParams == 2) {

        hIT8out = cmsIT8Alloc(NULL);            
        SetOutputDataFormat();
        strncpy(CGATSoutFilename, argv[xoptind+1], cmsMAX_PATH-1);      
    }

    if (nParams > 2) FatalError("Too many CGATS files");
}



// The main sink
int main(int argc, char *argv[])
{    
    cmsUInt16Number Output[cmsMAXCHANNELS];
    cmsFloat64Number OutputFloat[cmsMAXCHANNELS];
    cmsFloat64Number InputFloat[cmsMAXCHANNELS];

    int nPatch = 0;

    fprintf(stderr, "LittleCMS ColorSpace conversion calculator - 4.3 [LittleCMS %2.2f]\n", LCMS_VERSION / 1000.0);

    InitUtils("transicc");

    Verbose = 1;

    if (argc == 1) {

        Help();              
        return 0;
    }

    HandleSwitches(argc, argv);

    // Open profiles, create transforms
    if (!OpenTransforms()) return 1;

    // Open CGATS input if specified
    OpenCGATSFiles(argc, argv);

    // Main loop: read all values and convert them
    for(;;) {

        if (hIT8in != NULL) {

            if (nPatch >= nMaxPatches) break;
            TakeCGATSValues(nPatch++, InputFloat);

        } else {

            if (feof(stdin)) break;         
            TakeFloatValues(InputFloat);

        }

        if (lIsFloat) 
            cmsDoTransform(hTrans, InputFloat, OutputFloat, 1);
        else
            cmsDoTransform(hTrans, InputFloat, Output, 1);


        if (hIT8out != NULL) {

            PutCGATSValues(OutputFloat);
        }
        else {

            if (lIsFloat) {
                PrintFloatResults(OutputFloat); PrintPCSFloat(InputFloat);
            }
            else {
                PrintEncodedResults(Output);   PrintPCSEncoded(InputFloat);      
            }

        }
    }


    // Cleanup
    CloseTransforms();

    if (hIT8in)
        cmsIT8Free(hIT8in);

    if (hIT8out) {      
        cmsIT8SaveToFile(hIT8out, CGATSoutFilename);
        cmsIT8Free(hIT8out);
    }

    // All is ok
    return 0;     
}


