//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_AUDIOINPUTPULSE_H
#define LIBTGVOIP_AUDIOINPUTPULSE_H

#include "../../audio/AudioInput.h"
#include "../../threading.h"
#include <pulse/pulseaudio.h>

#define DECLARE_DL_FUNCTION(name) typeof(name)* _import_##name

namespace tgvoip{
namespace audio{

class AudioInputPulse : public AudioInput{
public:
	AudioInputPulse(std::string devID);
	virtual ~AudioInputPulse();
	virtual void Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels);
	virtual void Start();
	virtual void Stop();
	virtual bool IsRecording();
	virtual void SetCurrentDevice(std::string devID);
	static bool EnumerateDevices(std::vector<AudioInputDevice>& devs);
	static bool IsAvailable();

private:
	static void ContextStateCallback(pa_context* context, void* arg);
	static void ContextStateCallbackEnum(pa_context* context, void* arg);
	static void StreamStateCallback(pa_stream* s, void* arg);
	static void StreamSuccessCallback(pa_stream* stream, int success, void* userdata);
	static void StreamReadCallback(pa_stream* stream, size_t requested_bytes, void* userdata);
	static void DeviceEnumCallback(pa_context* ctx, const pa_source_info* info, int eol, void* userdata);
	void StreamReadCallback(pa_stream* stream, size_t requestedBytes);

	pa_threaded_mainloop* mainloop;
	pa_mainloop_api* mainloopApi;
	pa_context* context;
	pa_stream* stream;

	bool isRecording;
	bool isConnected;
	bool didStart;
	bool isLocked;
	unsigned char remainingData[960*8*2];
	size_t remainingDataSize;
};

}
}

#undef DECLARE_DL_FUNCTION

#endif //LIBTGVOIP_AUDIOINPUTPULSE_H
