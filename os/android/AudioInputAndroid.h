//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_AUDIOINPUTANDROID_H
#define LIBTGVOIP_AUDIOINPUTANDROID_H

#include <jni.h>
#include "../../audio/AudioInput.h"
#include "../../threading.h"

namespace tgvoip{ namespace audio{
class AudioInputAndroid : public AudioInput{

public:
	AudioInputAndroid();
	virtual ~AudioInputAndroid();
	virtual void Start();
	virtual void Stop();
	void HandleCallback(JNIEnv* env, jobject buffer);
	static jmethodID initMethod;
	static jmethodID releaseMethod;
	static jmethodID startMethod;
	static jmethodID stopMethod;
	static jclass jniClass;

private:
	jobject javaObject;
	bool running;
	Mutex mutex;

};
}}

#endif //LIBTGVOIP_AUDIOINPUTANDROID_H
