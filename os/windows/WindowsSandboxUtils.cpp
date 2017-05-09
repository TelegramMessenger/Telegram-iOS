
//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "WindowsSandboxUtils.h"
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <windows.h>

using namespace tgvoip;
using namespace Microsoft::WRL;

IAudioClient* WindowsSandboxUtils::ActivateAudioDevice(const wchar_t* devID, HRESULT* callRes, HRESULT* actRes){
	// Did I say that I hate pointlessly asynchronous things?
	HANDLE event = CreateEventEx(NULL, NULL, 0, 0);
	ActivationHandler activationHandler(event);
	Windows::ApplicationModel::Core::CoreApplication::GetCurrentView()->CoreWindow->Dispatcher->RunAsync(Windows::UI::Core::CoreDispatcherPriority::Normal, ref new Windows::UI::Core::DispatchedHandler([devID, callRes, actRes, activationHandler](){
		ComPtr<IActivateAudioInterfaceAsyncOperation> actHandler;
		Platform::String^ sel=Windows::Media::Devices::MediaDevice::GetDefaultAudioRenderId(Windows::Media::Devices::AudioDeviceRole::Communications);
		HRESULT cr=ActivateAudioInterfaceAsync(sel->Data(), __uuidof(IAudioClient), NULL, (IActivateAudioInterfaceCompletionHandler*)&activationHandler, &actHandler);
		if(callRes)
			*callRes=cr;
	}));
	WaitForSingleObjectEx(event, INFINITE, false);
	CloseHandle(event);
	if(actRes)
		*actRes=activationHandler.actResult;
	return activationHandler.client;
}

STDMETHODIMP ActivationHandler::ActivateCompleted(IActivateAudioInterfaceAsyncOperation* op){
	HRESULT res = op->GetActivateResult(&actResult, (IUnknown**)&client);
	SetEvent(event);

	return S_OK;
}
