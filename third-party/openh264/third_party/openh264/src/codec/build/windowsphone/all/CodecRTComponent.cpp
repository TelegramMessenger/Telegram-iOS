// CodecRTComponent.cpp
#include <string.h>
#include <iostream>
#include "typedefs.h"
#include "CodecRTComponent.h"

using namespace CodecRTComponent;
using namespace Platform;
using namespace Windows::Storage;

extern "C" int EncMain (int argc, char** argv);
extern int32_t DecMain (int32_t iArgC, char* pArgV[]);
//encoder info
extern float   g_fFPS;
extern double  g_dEncoderTime;
extern int     g_iEncodedFrame;

//decoder info
extern double g_dDecTime;
extern float  g_fDecFPS;
extern int    g_iDecodedFrameNum;


CodecRunTimeComponent::CodecRunTimeComponent() {
}

float CodecRunTimeComponent::GetEncFPS() {
  return g_fFPS;
}
double CodecRunTimeComponent::GetEncTime() {
  return g_dEncoderTime;
}
int  CodecRunTimeComponent::GetEncodedFrameNum() {
  return g_iEncodedFrame;
}

int CodecRunTimeComponent::Encode() {
  int iRet = 0;
  int argc = 6;
  char* argv[6];
  int iSize = 0;

  //App test data files' path
  char InputPath[256] = { 0 };
  char InputWelsEncCfgPath[256] = { 0 };
  char InputCfgPath[256] = { 0 };
  char InputYUVPath[256] = { 0 };
  char OutputPath[256] = { 0 };
  char Output264Path[256] = { 0 };

  //App data location
  Windows::Storage::StorageFolder^ InputLocation;
  Platform::String^ InputLocationPath;
  Windows::Storage::StorageFolder^ OutputLocation;
  Platform::String^ OutputLocationPath;

  //set input file path
  InputLocation = Windows::ApplicationModel::Package::Current->InstalledLocation;
  InputLocationPath = Platform::String::Concat (InputLocation->Path, "\\");
  const wchar_t* pWcharInputFile = InputLocationPath->Data();

  iSize = wcslen (pWcharInputFile);
  InputPath[iSize] = 0;
  for (int y = 0; y < iSize; y++) {
    InputPath[y] = (char)pWcharInputFile[y];
  }

  //set output file path
  OutputLocation = ApplicationData::Current->LocalFolder;
  OutputLocationPath = Platform::String::Concat (OutputLocation->Path, "\\");
  const wchar_t* pWcharOutputFile = OutputLocationPath->Data();

  iSize = wcslen (pWcharOutputFile);
  OutputPath[iSize] = 0;
  for (int y = 0; y < iSize; y++) {
    OutputPath[y] = (char)pWcharOutputFile[y];
  }

  //App
  strcpy (InputWelsEncCfgPath, InputPath);
  strcat (InputWelsEncCfgPath, "welsenc.cfg");

  strcpy (InputYUVPath, InputPath);
  strcat (InputYUVPath, "CiscoVT2people_160x96_6fps.yuv");

  // single layer only
  strcpy (InputCfgPath, InputPath);
  strcat (InputCfgPath, "layer2.cfg");
  // for multiple layers
  /*
  strcpy(InputCfg0Path, InputPath);
  strcat(InputCfg0Path, "layer0.cfg");
  strcpy(InputCfg1Path, InputPath);
  strcat(InputCfg1Path, "layer1.cfg");
  ...
  */

  strcpy (Output264Path, OutputPath);
  strcat (Output264Path, "WP8_Test_CiscoVT2people_160x96_6fps.264");

  argv[0] = (char*) ("EncoderApp");
  argv[1] = InputWelsEncCfgPath;
  argv[2] = (char*) ("-org");
  argv[3] = InputYUVPath;
  argv[4] = (char*) ("-bf");
  argv[5] = Output264Path;

  argc = 6;
  iRet = EncMain (argc, argv);

  return iRet;
}


float CodecRunTimeComponent::GetDecFPS() {
  return g_fDecFPS;
}
double CodecRunTimeComponent::GetDecTime() {
  return g_dDecTime;
}
int CodecRunTimeComponent::GetDecodedFrameNum() {
  return g_iDecodedFrameNum;
}

int CodecRunTimeComponent::Decode() {
  int iRet = 0;
  int argc = 3;
  char* argv[3];
  int size = 0;

  //App data files' path
  char InputPath[256] = { 0 };
  char OutputPath[256] = { 0 };
  char InputBitstreamPath[256] = { 0 };
  char OutputYUVPath[256] = { 0 };

  //App data location
  Windows::Storage::StorageFolder^ InputLocation;
  Platform::String^ InputLocationPath;

  Windows::Storage::StorageFolder^ OutputLocation;
  Platform::String^ OutputLocationPath;

  //set input file path
  InputLocation = Windows::ApplicationModel::Package::Current->InstalledLocation;
  InputLocationPath = Platform::String::Concat (InputLocation->Path, "\\");
  const wchar_t* pWcharInputFile = InputLocationPath->Data();

  size = wcslen (pWcharInputFile);
  InputPath[size] = 0;
  for (int y = 0; y < size; y++) {
    InputPath[y] = (char)pWcharInputFile[y];
  }

  //set output file path
  OutputLocation = ApplicationData::Current->LocalFolder;
  OutputLocationPath = Platform::String::Concat (OutputLocation->Path, "\\");
  const wchar_t* pWcharOutputFile = OutputLocationPath->Data();

  size = wcslen (pWcharOutputFile);
  OutputPath[size] = 0;
  for (int y = 0; y < size; y++) {
    OutputPath[y] = (char)pWcharOutputFile[y];
  }

  //App test setting
  strcpy_s (InputBitstreamPath, InputPath);
  strcat_s (InputBitstreamPath, "BA_MW_D.264");

  strcpy_s (OutputYUVPath, OutputPath);
  strcat_s (OutputYUVPath, "WP8_Dec_BA_MW_D.yuv");

  argv[0] = (char*) ("DecoderApp");
  argv[1] = InputBitstreamPath;
  argv[2] = OutputYUVPath;

  argc = 3;
  iRet = DecMain (argc, argv);

  return iRet;
}
