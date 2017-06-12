//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//


#include <assert.h>
#include <dlfcn.h>
#include <unistd.h>
#include "AudioOutputPulse.h"
#include "../../logging.h"
#include "../../VoIPController.h"
#define TGVOIP_IN_AUDIO_IO
#include "PulseAudioLoader.h"
#undef TGVOIP_IN_AUDIO_IO

#define BUFFER_SIZE 960
#define CHECK_ERROR(res, msg) if(res!=0){LOGE(msg " failed: %s", pa_strerror(res)); failed=true; return;}

using namespace tgvoip;
using namespace tgvoip::audio;

using tgvoip::PulseAudioLoader;

AudioOutputPulse::AudioOutputPulse(std::string devID){
	isPlaying=false;
	isConnected=false;
	didStart=false;
	isLocked=false;

	mainloop=NULL;
	mainloopApi=NULL;
	context=NULL;
	stream=NULL;
	remainingDataSize=0;

	if(!PulseAudioLoader::IncRef()){
		failed=true;
		return;
	}

	mainloop=pa_threaded_mainloop_new();
	if(!mainloop){
		LOGE("Error initializing PulseAudio (pa_threaded_mainloop_new)");
		failed=true;
		return;
	}
	mainloopApi=pa_threaded_mainloop_get_api(mainloop);
	char exePath[MAXPATHLEN];
	char exeName[MAXPATHLEN];
	ssize_t lres=readlink("/proc/self/exe", exePath, sizeof(exePath));
	if(lres==-1)
		lres=readlink("/proc/curproc/file", exePath, sizeof(exePath));
	if(lres==-1)
		lres=readlink("/proc/curproc/exe", exePath, sizeof(exePath));
	if(lres>0){
		strcpy(exeName, basename(exePath));
	}else{
		snprintf(exeName, sizeof(exeName), "Process %d", getpid());
	}
	context=pa_context_new(mainloopApi, exeName);
	if(!context){
		LOGE("Error initializing PulseAudio (pa_context_new)");
		failed=true;
		return;
	}
	pa_context_set_state_callback(context, AudioOutputPulse::ContextStateCallback, this);
	pa_threaded_mainloop_lock(mainloop);
	isLocked=true;
	int err=pa_threaded_mainloop_start(mainloop);
	CHECK_ERROR(err, "pa_threaded_mainloop_start");
	didStart=true;

	err=pa_context_connect(context, NULL, PA_CONTEXT_NOAUTOSPAWN, NULL);
	CHECK_ERROR(err, "pa_context_connect");

	while(true){
		pa_context_state_t contextState=pa_context_get_state(context);
		if(!PA_CONTEXT_IS_GOOD(contextState)){
			LOGE("Error initializing PulseAudio (PA_CONTEXT_IS_GOOD)");
			failed=true;
			return;
		}
		if(contextState==PA_CONTEXT_READY)
			break;
		pa_threaded_mainloop_wait(mainloop);
	}

	pa_sample_spec sample_specifications{
		.format=PA_SAMPLE_S16LE,
		.rate=48000,
		.channels=1
	};

	stream=pa_stream_new(context, "libtgvoip playback", &sample_specifications, NULL);
	if(!stream){
		LOGE("Error initializing PulseAudio (pa_stream_new)");
		failed=true;
		return;
	}
	pa_stream_set_state_callback(stream, AudioOutputPulse::StreamStateCallback, this);
	pa_stream_set_write_callback(stream, AudioOutputPulse::StreamWriteCallback, this);
	pa_threaded_mainloop_unlock(mainloop);
	isLocked=false;

	SetCurrentDevice(devID);
}

AudioOutputPulse::~AudioOutputPulse(){
	if(mainloop && didStart){
		if(isLocked)
			pa_threaded_mainloop_unlock(mainloop);
		pa_threaded_mainloop_stop(mainloop);
	}
	if(stream){
		pa_stream_disconnect(stream);
		pa_stream_unref(stream);
	}
	if(context){
		pa_context_disconnect(context);
		pa_context_unref(context);
	}
	if(mainloop)
		pa_threaded_mainloop_free(mainloop);
	
	PulseAudioLoader::DecRef();
}

bool AudioOutputPulse::IsAvailable(){
	void* lib=dlopen("libpulse.so.0", RTLD_LAZY);
	if(!lib)
		lib=dlopen("libpulse.so", RTLD_LAZY);
	if(lib){
		dlclose(lib);
		return true;
	}
	return false;
}

void AudioOutputPulse::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	
}

void AudioOutputPulse::Start(){
	if(failed || isPlaying)
		return;

	isPlaying=true;
	pa_operation_unref(pa_stream_cork(stream, 0, AudioOutputPulse::StreamSuccessCallback, mainloop));
}

void AudioOutputPulse::Stop(){
	if(!isPlaying)
		return;

	isPlaying=false;
	pa_operation_unref(pa_stream_cork(stream, 1, AudioOutputPulse::StreamSuccessCallback, mainloop));
}

bool AudioOutputPulse::IsPlaying(){
	return isPlaying;
}

void AudioOutputPulse::SetCurrentDevice(std::string devID){
	currentDevice=devID;
	if(isPlaying && isConnected){
		pa_stream_disconnect(stream);
		isConnected=false;
	}

	pa_buffer_attr bufferAttr={
		.maxlength=960*6,
		.tlength=960*6,
		.prebuf=0,
		.minreq=960*2
	};
	int streamFlags=PA_STREAM_START_CORKED | PA_STREAM_INTERPOLATE_TIMING | 
		PA_STREAM_NOT_MONOTONIC | PA_STREAM_AUTO_TIMING_UPDATE | PA_STREAM_ADJUST_LATENCY;

	int err=pa_stream_connect_playback(stream, devID=="default" ? NULL : devID.c_str(), &bufferAttr, (pa_stream_flags_t)streamFlags, NULL, NULL);
	if(err!=0 && devID!="default"){
		SetCurrentDevice("default");
		return;
	}
	CHECK_ERROR(err, "pa_stream_connect_playback");

	while(true){
		pa_threaded_mainloop_lock(mainloop);
		pa_stream_state_t streamState=pa_stream_get_state(stream);
		pa_threaded_mainloop_unlock(mainloop);
		if(!PA_STREAM_IS_GOOD(streamState)){
			LOGE("Error connecting to audio device '%s'", devID.c_str());
			failed=true;
			return;
		}
		if(streamState==PA_STREAM_READY)
			break;
		pa_threaded_mainloop_wait(mainloop);
	}

	isConnected=true;

	if(isPlaying){
		pa_operation_unref(pa_stream_cork(stream, 0, AudioOutputPulse::StreamSuccessCallback, mainloop));
	}
}

bool AudioOutputPulse::EnumerateDevices(std::vector<AudioOutputDevice>& devs){
	if(!PulseAudioLoader::IncRef())
		return false;

	pa_mainloop* ml;
	pa_mainloop_api* mlAPI;
	pa_context* ctx;
	pa_operation* op=NULL;
	int state=0;
	int paReady=0;

	ml=pa_mainloop_new();
	mlAPI=pa_mainloop_get_api(ml);
	ctx=pa_context_new(mlAPI, "libtgvoip");

	pa_context_connect(ctx, NULL, PA_CONTEXT_NOFLAGS, NULL);
	pa_context_set_state_callback(ctx, AudioOutputPulse::ContextStateCallbackEnum, &paReady);

	while(true){
		if(paReady==0){
			pa_mainloop_iterate(ml, 1, NULL);
			continue;
		}
		if(paReady==2){
			pa_context_disconnect(ctx);
			pa_context_unref(ctx);
			pa_mainloop_free(ml);
			PulseAudioLoader::DecRef();
			return false;
		}
		if(!op){
			op=pa_context_get_sink_info_list(ctx, AudioOutputPulse::DeviceEnumCallback, &devs);
			continue;
		}
		if(pa_operation_get_state(op)==PA_OPERATION_DONE){
			pa_operation_unref(op);
			pa_context_disconnect(ctx);
			pa_context_unref(ctx);
			pa_mainloop_free(ml);
			PulseAudioLoader::DecRef();
			return true;
		}
		pa_mainloop_iterate(ml, 1, NULL);
	}
}

void AudioOutputPulse::ContextStateCallback(pa_context* context, void* arg) {
	AudioOutputPulse* self=(AudioOutputPulse*) arg;
	pa_threaded_mainloop_signal(self->mainloop, 0);
}

void AudioOutputPulse::StreamStateCallback(pa_stream *s, void* arg) {
	AudioOutputPulse* self=(AudioOutputPulse*) arg;
	pa_threaded_mainloop_signal(self->mainloop, 0);
}

void AudioOutputPulse::StreamWriteCallback(pa_stream *stream, size_t requestedBytes, void *userdata){
	((AudioOutputPulse*)userdata)->StreamWriteCallback(stream, requestedBytes);
}

void AudioOutputPulse::StreamWriteCallback(pa_stream *stream, size_t requestedBytes) {
	int bytesRemaining = requestedBytes;
	uint8_t *buffer = NULL;
	while (bytesRemaining > 0) {
		size_t bytesToFill = 102400;
		size_t i;

		if (bytesToFill > bytesRemaining) bytesToFill = bytesRemaining;

		int err=pa_stream_begin_write(stream, (void**) &buffer, &bytesToFill);
		CHECK_ERROR(err, "pa_stream_begin_write");

		if(isPlaying){
			while(remainingDataSize<bytesToFill){
				if(remainingDataSize+960*2>=sizeof(remainingData)){
					LOGE("Can't provide %d bytes of audio data at a time", (int)bytesToFill);
					failed=true;
					pa_threaded_mainloop_unlock(mainloop);
					return;
				}
				InvokeCallback(remainingData+remainingDataSize, 960*2);
				remainingDataSize+=960*2;
			}
			memcpy(buffer, remainingData, bytesToFill);
			memmove(remainingData, remainingData+bytesToFill, remainingDataSize-bytesToFill);
			remainingDataSize-=bytesToFill;
		}else{
			memset(buffer, 0, bytesToFill);
		}

		err=pa_stream_write(stream, buffer, bytesToFill, NULL, 0LL, PA_SEEK_RELATIVE);
		CHECK_ERROR(err, "pa_stream_write");

		bytesRemaining -= bytesToFill;
	}
}

void AudioOutputPulse::StreamSuccessCallback(pa_stream *stream, int success, void *userdata) {
	return;
}

void AudioOutputPulse::ContextStateCallbackEnum(pa_context* context, void* arg){
	pa_context_state_t state;
	int* pa_ready=(int*)arg;

	state=pa_context_get_state(context);
	switch(state){
		case PA_CONTEXT_UNCONNECTED:
		case PA_CONTEXT_CONNECTING:
		case PA_CONTEXT_AUTHORIZING:
		case PA_CONTEXT_SETTING_NAME:
		default:
			break;
		case PA_CONTEXT_FAILED:
		case PA_CONTEXT_TERMINATED:
			*pa_ready=2;
			break;
		case PA_CONTEXT_READY:
			*pa_ready=1;
			break;
	}
}

void AudioOutputPulse::DeviceEnumCallback(pa_context* ctx, const pa_sink_info* info, int eol, void* userdata){
	if(eol>0)
		return;
	std::vector<AudioOutputDevice>* devs=(std::vector<AudioOutputDevice>*)userdata;
	AudioOutputDevice dev;
	dev.id=std::string(info->name);
	dev.displayName=std::string(info->description);
	devs->push_back(dev);
}
