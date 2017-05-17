//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//


#include <assert.h>
#include <dlfcn.h>
#include <unistd.h>
#include "AudioInputPulse.h"
#include "../../logging.h"
#include "../../VoIPController.h"

#define BUFFER_SIZE 960
#define CHECK_ERROR(res, msg) if(res!=0){LOGE(msg " failed: %s", pa_strerror(res)); failed=true; return;}
#define CHECK_DL_ERROR(res, msg) if(!res){LOGE(msg ": %s", dlerror()); failed=true; return;}
#define LOAD_DL_FUNCTION(name) {_import_##name=(typeof(_import_##name))dlsym(lib, #name); CHECK_DL_ERROR(_import_##name, "Error getting entry point for " #name);}

#define pa_threaded_mainloop_new _import_pa_threaded_mainloop_new
#define pa_threaded_mainloop_get_api _import_pa_threaded_mainloop_get_api
#define pa_context_new _import_pa_context_new
#define pa_context_set_state_callback _import_pa_context_set_state_callback
#define pa_threaded_mainloop_lock _import_pa_threaded_mainloop_lock
#define pa_threaded_mainloop_unlock _import_pa_threaded_mainloop_unlock
#define pa_threaded_mainloop_start _import_pa_threaded_mainloop_start
#define pa_context_connect _import_pa_context_connect
#define pa_context_get_state _import_pa_context_get_state
#define pa_threaded_mainloop_wait _import_pa_threaded_mainloop_wait
#define pa_stream_new _import_pa_stream_new
#define pa_stream_set_state_callback _import_pa_stream_set_state_callback
#define pa_stream_set_read_callback _import_pa_stream_set_read_callback
#define pa_stream_connect_record _import_pa_stream_connect_record
#define pa_operation_unref _import_pa_operation_unref
#define pa_stream_cork _import_pa_stream_cork
#define pa_threaded_mainloop_stop _import_pa_threaded_mainloop_stop
#define pa_stream_disconnect _import_pa_stream_disconnect
#define pa_stream_unref _import_pa_stream_unref
#define pa_context_disconnect _import_pa_context_disconnect
#define pa_context_unref _import_pa_context_unref
#define pa_threaded_mainloop_free _import_pa_threaded_mainloop_free
#define pa_threaded_mainloop_signal _import_pa_threaded_mainloop_signal
#define pa_stream_peek _import_pa_stream_peek
#define pa_stream_drop _import_pa_stream_drop
#define pa_strerror _import_pa_strerror
#define pa_stream_get_state _import_pa_stream_get_state

using namespace tgvoip::audio;

AudioInputPulse::AudioInputPulse(std::string devID){
	isRecording=false;
	isConnected=false;

	mainloop=NULL;
	mainloopApi=NULL;
	context=NULL;
	stream=NULL;
	remainingDataSize=0;

	lib=dlopen("libpulse.so.0", RTLD_LAZY);
	if(!lib)
		lib=dlopen("libpulse.so", RTLD_LAZY);
	if(!lib){
		LOGE("Error loading libpulse: %s", dlerror());
		failed=true;
		return;
	}

	LOAD_DL_FUNCTION(pa_threaded_mainloop_new);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_get_api);
	LOAD_DL_FUNCTION(pa_context_new);
	LOAD_DL_FUNCTION(pa_context_set_state_callback);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_lock);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_unlock);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_start);
	LOAD_DL_FUNCTION(pa_context_connect);
	LOAD_DL_FUNCTION(pa_context_get_state);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_wait);
	LOAD_DL_FUNCTION(pa_stream_new);
	LOAD_DL_FUNCTION(pa_stream_set_state_callback);
	LOAD_DL_FUNCTION(pa_stream_set_read_callback);
	LOAD_DL_FUNCTION(pa_stream_connect_record);
	LOAD_DL_FUNCTION(pa_operation_unref);
	LOAD_DL_FUNCTION(pa_stream_cork);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_stop);
	LOAD_DL_FUNCTION(pa_stream_disconnect);
	LOAD_DL_FUNCTION(pa_stream_unref);
	LOAD_DL_FUNCTION(pa_context_disconnect);
	LOAD_DL_FUNCTION(pa_context_unref);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_free);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_signal);
	LOAD_DL_FUNCTION(pa_stream_peek);
	LOAD_DL_FUNCTION(pa_stream_drop);
	LOAD_DL_FUNCTION(pa_stream_get_state);
	LOAD_DL_FUNCTION(pa_strerror);

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
	pa_context_set_state_callback(context, AudioInputPulse::ContextStateCallback, this);
	int err=pa_threaded_mainloop_start(mainloop);
	CHECK_ERROR(err, "pa_threaded_mainloop_start");

	err=pa_context_connect(context, NULL, PA_CONTEXT_NOAUTOSPAWN, NULL);
	CHECK_ERROR(err, "pa_context_connect");

	while(true){
		pa_threaded_mainloop_lock(mainloop);
		pa_context_state_t contextState=pa_context_get_state(context);
		pa_threaded_mainloop_unlock(mainloop);
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

	stream=pa_stream_new(context, "libtgvoip capture", &sample_specifications, NULL);
	if(!stream){
		LOGE("Error initializing PulseAudio (pa_stream_new)");
		failed=true;
		return;
	}
	pa_stream_set_state_callback(stream, AudioInputPulse::StreamStateCallback, this);
	pa_stream_set_read_callback(stream, AudioInputPulse::StreamReadCallback, this);

	SetCurrentDevice(devID);
}

AudioInputPulse::~AudioInputPulse(){
	if(mainloop)
		pa_threaded_mainloop_stop(mainloop);
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
	
	if(lib)
		dlclose(lib);
}

bool AudioInputPulse::IsAvailable(){
	void* lib=dlopen("libpulse.so.0", RTLD_LAZY);
	if(!lib)
		lib=dlopen("libpulse.so", RTLD_LAZY);
	if(lib){
		dlclose(lib);
		return true;
	}
	return false;
}

void AudioInputPulse::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	
}

void AudioInputPulse::Start(){
	if(failed || isRecording)
		return;

	isRecording=true;
	pa_operation_unref(pa_stream_cork(stream, 0, AudioInputPulse::StreamSuccessCallback, mainloop));
}

void AudioInputPulse::Stop(){
	if(!isRecording)
		return;

	isRecording=false;
	pa_operation_unref(pa_stream_cork(stream, 1, AudioInputPulse::StreamSuccessCallback, mainloop));
}

bool AudioInputPulse::IsRecording(){
	return isRecording;
}

void AudioInputPulse::SetCurrentDevice(std::string devID){
	currentDevice=devID;
	if(isRecording && isConnected){
		pa_stream_disconnect(stream);
		isConnected=false;
	}

	pa_buffer_attr bufferAttr={
		.maxlength=960*6,
		.tlength=960*2,
		.prebuf=0,
		.minreq=960*2
	};
	int streamFlags=PA_STREAM_START_CORKED | PA_STREAM_INTERPOLATE_TIMING | 
		PA_STREAM_NOT_MONOTONIC | PA_STREAM_AUTO_TIMING_UPDATE | PA_STREAM_ADJUST_LATENCY;

	int err=pa_stream_connect_record(stream, devID=="default" ? NULL : devID.c_str(), &bufferAttr, (pa_stream_flags_t)streamFlags);
	if(err!=0 && devID!="default"){
		SetCurrentDevice("default");
		return;
	}
	CHECK_ERROR(err, "pa_stream_connect_record");

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

	if(isRecording){
		pa_operation_unref(pa_stream_cork(stream, 0, AudioInputPulse::StreamSuccessCallback, mainloop));
	}
}

void AudioInputPulse::EnumerateDevices(std::vector<AudioInputDevice>& devs){
	
}

void AudioInputPulse::ContextStateCallback(pa_context* context, void* arg) {
	AudioInputPulse* self=(AudioInputPulse*) arg;
	self->pa_threaded_mainloop_signal(self->mainloop, 0);
}

void AudioInputPulse::StreamStateCallback(pa_stream *s, void* arg) {
	AudioInputPulse* self=(AudioInputPulse*) arg;
	self->pa_threaded_mainloop_signal(self->mainloop, 0);
}

void AudioInputPulse::StreamReadCallback(pa_stream *stream, size_t requestedBytes, void *userdata){
	((AudioInputPulse*)userdata)->StreamReadCallback(stream, requestedBytes);
}

void AudioInputPulse::StreamReadCallback(pa_stream *stream, size_t requestedBytes) {
	int bytesRemaining = requestedBytes;
	uint8_t *buffer = NULL;
	while (bytesRemaining > 0) {
		size_t bytesToFill = 102400;
		size_t i;

		if (bytesToFill > bytesRemaining) bytesToFill = bytesRemaining;

		int err=pa_stream_peek(stream, (const void**) &buffer, &bytesToFill);
		CHECK_ERROR(err, "pa_stream_peek");

		if(isRecording){
			if(remainingDataSize+bytesToFill>sizeof(remainingData)){
				LOGE("Capture buffer is too big (%d)", (int)bytesToFill);
			}
			memcpy(remainingData+remainingDataSize, buffer, bytesToFill);
			remainingDataSize+=bytesToFill;
			while(remainingDataSize>=960*2){
				InvokeCallback(remainingData, 960*2);
				memmove(remainingData, remainingData+960*2, remainingDataSize-960*2);
				remainingDataSize-=960*2;
			}
		}

		err=pa_stream_drop(stream);
		CHECK_ERROR(err, "pa_stream_drop");

		bytesRemaining -= bytesToFill;
	}
}

void AudioInputPulse::StreamSuccessCallback(pa_stream *stream, int success, void *userdata) {
	return;
}