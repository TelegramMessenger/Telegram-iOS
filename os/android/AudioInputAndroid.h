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

class CAudioInputAndroid : public CAudioInput{

public:
	CAudioInputAndroid();
	virtual ~CAudioInputAndroid();
	virtual void Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels);
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
	tgvoip_mutex_t mutex;

};


#endif //LIBTGVOIP_AUDIOINPUTANDROID_H
