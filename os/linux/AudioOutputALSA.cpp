//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//


#include <assert.h>
#include <dlfcn.h>
#include "AudioOutputALSA.h"
#include "../../logging.h"

#define BUFFER_SIZE 960
#define CHECK_ERROR(res, msg) if(res<0){LOGE(msg ": %s", _snd_strerror(res));}
#define CHECK_DL_ERROR(res, msg) if(!res){LOGE(msg ": %s", dlerror()); failed=true; return;}
#define LOAD_FUNCTION(lib, name, ref) {ref=(typeof(ref))dlsym(lib, name); CHECK_DL_ERROR(ref, "Error getting entry point for " name);}

using namespace tgvoip::audio;

AudioOutputALSA::AudioOutputALSA(){
	isPlaying=false;

	lib=dlopen("libasound.so", RTLD_LAZY);
	if(!lib){
		LOGE("Error loading libasound: %s", dlerror());
		failed=true;
		return;
	}

	LOAD_FUNCTION(lib, "snd_pcm_open", _snd_pcm_open);
	LOAD_FUNCTION(lib, "snd_pcm_set_params", _snd_pcm_set_params);
	LOAD_FUNCTION(lib, "snd_pcm_close", _snd_pcm_close);
	LOAD_FUNCTION(lib, "snd_pcm_writei", _snd_pcm_writei);
	LOAD_FUNCTION(lib, "snd_pcm_recover", _snd_pcm_recover);
	LOAD_FUNCTION(lib, "snd_strerror", _snd_strerror);

	int res=_snd_pcm_open(&handle, "default", SND_PCM_STREAM_PLAYBACK, 0);
	CHECK_ERROR(res, "snd_pcm_open failed");

	res=_snd_pcm_set_params(handle, SND_PCM_FORMAT_S16, SND_PCM_ACCESS_RW_INTERLEAVED, 1, 48000, 1, 100000);
	CHECK_ERROR(res, "snd_pcm_set_params failed");
}

AudioOutputALSA::~AudioOutputALSA(){
	_snd_pcm_close(handle);
	dlclose(lib);
}

void AudioOutputALSA::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	
}

void AudioOutputALSA::Start(){
	if(failed || isPlaying)
		return;

	isPlaying=true;
	start_thread(thread, AudioOutputALSA::StartThread, this);
}

void AudioOutputALSA::Stop(){
	if(!isPlaying)
		return;

	isPlaying=false;
	join_thread(thread);
}

bool AudioOutputALSA::IsPlaying(){
	return isPlaying;
}

void* AudioOutputALSA::StartThread(void* arg){
	((AudioOutputALSA*)arg)->RunThread();
}

void AudioOutputALSA::RunThread(){
	unsigned char buffer[BUFFER_SIZE*2];
	snd_pcm_sframes_t frames;
	while(isPlaying){
		InvokeCallback(buffer, sizeof(buffer));
		frames=_snd_pcm_writei(handle, buffer, BUFFER_SIZE);
		if (frames < 0){
			frames = _snd_pcm_recover(handle, frames, 0);
		}
		if (frames < 0) {
			LOGE("snd_pcm_writei failed: %s\n", _snd_strerror(frames));
			break;
		}
	}
}