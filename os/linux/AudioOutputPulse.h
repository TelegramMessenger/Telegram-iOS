//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_AUDIOOUTPUTPULSE_H
#define LIBTGVOIP_AUDIOOUTPUTPULSE_H

#include "../../audio/AudioOutput.h"
#include "../../threading.h"
#include <pulse/pulseaudio.h>

#define DECLARE_DL_FUNCTION(name) typeof(name)* _import_##name

namespace tgvoip{
namespace audio{

class AudioOutputPulse : public AudioOutput{
public:
	AudioOutputPulse(std::string devID);
	virtual ~AudioOutputPulse();
	virtual void Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels);
	virtual void Start();
	virtual void Stop();
	virtual bool IsPlaying();
	virtual void SetCurrentDevice(std::string devID);
	static void EnumerateDevices(std::vector<AudioOutputDevice>& devs);
	static bool IsAvailable();

private:
	static void ContextStateCallback(pa_context* context, void* arg);
	static void StreamStateCallback(pa_stream* s, void* arg);
	static void StreamSuccessCallback(pa_stream* stream, int success, void* userdata);
	static void StreamWriteCallback(pa_stream* stream, size_t requested_bytes, void* userdata);
	void StreamWriteCallback(pa_stream* stream, size_t requestedBytes);

	pa_threaded_mainloop* mainloop;
	pa_mainloop_api* mainloopApi;
	pa_context* context;
	pa_stream* stream;
	void* lib;

	DECLARE_DL_FUNCTION(pa_threaded_mainloop_new);
	DECLARE_DL_FUNCTION(pa_threaded_mainloop_get_api);
	DECLARE_DL_FUNCTION(pa_context_new);
	DECLARE_DL_FUNCTION(pa_context_set_state_callback);
	DECLARE_DL_FUNCTION(pa_threaded_mainloop_lock);
	DECLARE_DL_FUNCTION(pa_threaded_mainloop_unlock);
	DECLARE_DL_FUNCTION(pa_threaded_mainloop_start);
	DECLARE_DL_FUNCTION(pa_context_connect);
	DECLARE_DL_FUNCTION(pa_context_get_state);
	DECLARE_DL_FUNCTION(pa_threaded_mainloop_wait);
	DECLARE_DL_FUNCTION(pa_stream_new);
	DECLARE_DL_FUNCTION(pa_stream_set_state_callback);
	DECLARE_DL_FUNCTION(pa_stream_set_write_callback);
	DECLARE_DL_FUNCTION(pa_stream_connect_playback);
	DECLARE_DL_FUNCTION(pa_operation_unref);
	DECLARE_DL_FUNCTION(pa_stream_cork);
	DECLARE_DL_FUNCTION(pa_threaded_mainloop_stop);
	DECLARE_DL_FUNCTION(pa_stream_disconnect);
	DECLARE_DL_FUNCTION(pa_stream_unref);
	DECLARE_DL_FUNCTION(pa_context_disconnect);
	DECLARE_DL_FUNCTION(pa_context_unref);
	DECLARE_DL_FUNCTION(pa_threaded_mainloop_free);
	DECLARE_DL_FUNCTION(pa_threaded_mainloop_signal);
	DECLARE_DL_FUNCTION(pa_stream_begin_write);
	DECLARE_DL_FUNCTION(pa_stream_write);
	DECLARE_DL_FUNCTION(pa_stream_get_state);
	DECLARE_DL_FUNCTION(pa_strerror);

	bool isPlaying;
	bool isConnected;
	unsigned char remainingData[10240];
	size_t remainingDataSize;
};

}
}

#undef DECLARE_DL_FUNCTION

#endif //LIBTGVOIP_AUDIOOUTPUTPULSE_H
