//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_AUDIOOUTPUTWASAPI_H
#define LIBTGVOIP_AUDIOOUTPUTWASAPI_H

#include <windows.h>
#include <string>
#include <vector>
#pragma warning(push)
#pragma warning(disable : 4201)
#include <mmdeviceapi.h>
#include <audiopolicy.h>
#pragma warning(pop)
#include "../../audio/AudioOutput.h"

namespace tgvoip{
namespace audio{

class AudioOutputWASAPI : public AudioOutput, IMMNotificationClient, IAudioSessionEvents{
public:
	AudioOutputWASAPI(std::string deviceID);
	virtual ~AudioOutputWASAPI();
	virtual void Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels);
	virtual void Start();
	virtual void Stop();
	virtual bool IsPlaying();
	virtual void SetCurrentDevice(std::string deviceID);
	static void EnumerateDevices(std::vector<AudioOutputDevice>& devs);
	STDMETHOD_(ULONG, AddRef)();
	STDMETHOD_(ULONG, Release)();

private:
	void ActuallySetCurrentDevice(std::string deviceID);
	static DWORD StartThread(void* arg);
	void RunThread();
	WAVEFORMATEX format;
	bool isPlaying;
	HANDLE shutdownEvent;
	HANDLE audioSamplesReadyEvent;
	HANDLE streamSwitchEvent;
	HANDLE thread;
	IAudioClient* audioClient;
	IAudioRenderClient* renderClient;
	IMMDeviceEnumerator* enumerator;
	IAudioSessionControl* audioSessionControl;
	IMMDevice* device;
	unsigned char remainingData[10240];
	size_t remainingDataLen;
	bool isDefaultDevice;
	ULONG refCount;
	std::string streamChangeToDevice;

	STDMETHOD(OnDisplayNameChanged) (LPCWSTR /*NewDisplayName*/, LPCGUID /*EventContext*/) { return S_OK; };
	STDMETHOD(OnIconPathChanged) (LPCWSTR /*NewIconPath*/, LPCGUID /*EventContext*/) { return S_OK; };
	STDMETHOD(OnSimpleVolumeChanged) (float /*NewSimpleVolume*/, BOOL /*NewMute*/, LPCGUID /*EventContext*/) { return S_OK; }
	STDMETHOD(OnChannelVolumeChanged) (DWORD /*ChannelCount*/, float /*NewChannelVolumes*/[], DWORD /*ChangedChannel*/, LPCGUID /*EventContext*/) { return S_OK; };
	STDMETHOD(OnGroupingParamChanged) (LPCGUID /*NewGroupingParam*/, LPCGUID /*EventContext*/) { return S_OK; };
	STDMETHOD(OnStateChanged) (AudioSessionState /*NewState*/) { return S_OK; };
	STDMETHOD(OnSessionDisconnected) (AudioSessionDisconnectReason DisconnectReason);
	STDMETHOD(OnDeviceStateChanged) (LPCWSTR /*DeviceId*/, DWORD /*NewState*/) { return S_OK; }
	STDMETHOD(OnDeviceAdded) (LPCWSTR /*DeviceId*/) { return S_OK; };
	STDMETHOD(OnDeviceRemoved) (LPCWSTR /*DeviceId(*/) { return S_OK; };
	STDMETHOD(OnDefaultDeviceChanged) (EDataFlow Flow, ERole Role, LPCWSTR NewDefaultDeviceId);
	STDMETHOD(OnPropertyValueChanged) (LPCWSTR /*DeviceId*/, const PROPERTYKEY /*Key*/) { return S_OK; };

	//
	//  IUnknown
	//
	STDMETHOD(QueryInterface)(REFIID iid, void **pvObject);
};

}
}

#endif //LIBTGVOIP_AUDIOOUTPUTWASAPI_H
