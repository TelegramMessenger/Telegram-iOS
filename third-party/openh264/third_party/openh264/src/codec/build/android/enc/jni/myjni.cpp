#include <string.h>
#include <stdlib.h>
#include <jni.h>
#include <android/log.h>

#define LOG_TAG "welsdec"
#define LOGI(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

extern "C" int EncMain (int argc, char* argv[]);
extern "C"
JNIEXPORT void JNICALL Java_com_wels_enc_WelsEncTest_DoEncoderAutoTest
(JNIEnv* env, jobject thiz, jstring jsIncfgName, jstring jsInlayerName, jstring jsInyuvName, jstring jsOutbitName) {
  /**************** Add the native codes/API *****************/
  const char* argv[] = {
    (char*) ("encConsole.exe"),
    (char*) ((*env).GetStringUTFChars (jsIncfgName, NULL)),
    (char*) ("-org"),
    (char*) ((*env).GetStringUTFChars (jsInyuvName, NULL)),
    (char*) ("-bf"),
    (char*) ((*env).GetStringUTFChars (jsOutbitName, NULL)),
    (char*) ("-numl"),
    (char*) ("1"),
    (char*) ("-lconfig"),
    (char*) ("0"),
    (char*) ((*env).GetStringUTFChars (jsInlayerName, NULL))
  };
  LOGI ("Start to run JNI module!+++");
  EncMain (sizeof (argv) / sizeof (argv[0]), (char**)&argv[0]);
  LOGI ("End to run JNI module!+++");
}

JNIEXPORT void JNICALL Java_com_wels_enc_WelsEncTest_DoEncoderTest
(JNIEnv* env, jobject thiz, jstring jsFileNameIn) {
  /**************** Add the native codes/API *****************/
  char* argv[2];
  int  argc = 2;
  argv[0] = (char*) ("encConsole.exe");
  argv[1] = (char*) ((*env).GetStringUTFChars (jsFileNameIn, NULL));
  LOGI ("Start to run JNI module!+++");
  EncMain (argc, argv);
  LOGI ("End to run JNI module!+++");

}


