//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <dlfcn.h>
#include "AudioInputALSA.h"
#include "../../logging.h"

using namespace tgvoip::audio;

#define BUFFER_SIZE 960
#define CHECK_ERROR(res, msg) if(res<0){LOGE(msg ": %s", _snd_strerror(res));}
#define CHECK_DL_ERROR(res, msg) if(!res){LOGE(msg ": %s", dlerror()); failed=true; return;}
#define LOAD_FUNCTION(lib, name, ref) {ref=(typeof(ref))dlsym(lib, name); CHECK_DL_ERROR(ref, "Error getting entry point for " name);}

AudioInputALSA::AudioInputALSA(){
	isRecording=false;

	lib=dlopen("libasound.so", RTLD_LAZY);
	if(!lib){
		LOGE("Error loading libasound: %s", dlerror());
		failed=true;
		return;
	}

	LOAD_FUNCTION(lib, "snd_pcm_open", _snd_pcm_open);
	LOAD_FUNCTION(lib, "snd_pcm_set_params", _snd_pcm_set_params);
	LOAD_FUNCTION(lib, "snd_pcm_close", _snd_pcm_close);
	LOAD_FUNCTION(lib, "snd_pcm_readi", _snd_pcm_readi);
	LOAD_FUNCTION(lib, "snd_pcm_recover", _snd_pcm_recover);
	LOAD_FUNCTION(lib, "snd_strerror", _snd_strerror);

	int res=_snd_pcm_open(&handle, "default", SND_PCM_STREAM_CAPTURE, 0);
	CHECK_ERROR(res, "snd_pcm_open failed");

	res=_snd_pcm_set_params(handle, SND_PCM_FORMAT_S16, SND_PCM_ACCESS_RW_INTERLEAVED, 1, 48000, 1, 100000);
	CHECK_ERROR(res, "snd_pcm_set_params failed");
}

AudioInputALSA::~AudioInputALSA(){
	_snd_pcm_close(handle);
	dlclose(lib);
}

void AudioInputALSA::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	
}

void AudioInputALSA::Start(){
	if(failed || isRecording)
		return;

	isRecording=true;
	start_thread(thread, AudioInputALSA::StartThread, this);
}

void AudioInputALSA::Stop(){
	if(!isRecording)
		return;

	isRecording=false;
	join_thread(thread);
}

void* AudioInputALSA::StartThread(void* arg){
	((AudioInputALSA*)arg)->RunThread();
}

void AudioInputALSA::RunThread(){
	unsigned char buffer[BUFFER_SIZE*2];
	snd_pcm_sframes_t frames;
	while(isRecording){
		frames=_snd_pcm_readi(handle, buffer, BUFFER_SIZE);
		if (frames < 0){
			frames = _snd_pcm_recover(handle, frames, 0);
		}
		if (frames < 0) {
			LOGE("snd_pcm_readi failed: %s\n", _snd_strerror(frames));
			break;
		}
		InvokeCallback(buffer, sizeof(buffer));
	}
}