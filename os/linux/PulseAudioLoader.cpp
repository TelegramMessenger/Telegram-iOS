//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "PulseAudioLoader.h"
#include <dlfcn.h>
#include "../../logging.h"

#define DECLARE_DL_FUNCTION(name) typeof(name)* PulseAudioLoader::_import_##name=NULL
#define CHECK_DL_ERROR(res, msg) if(!res){LOGE(msg ": %s", dlerror()); dlclose(lib); return false;}
#define LOAD_DL_FUNCTION(name) {_import_##name=(typeof(_import_##name))dlsym(lib, #name); CHECK_DL_ERROR(_import_##name, "Error getting entry point for " #name);}

using namespace tgvoip;

int PulseAudioLoader::refCount=0;
void* PulseAudioLoader::lib=NULL;

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
DECLARE_DL_FUNCTION(pa_stream_set_read_callback);
DECLARE_DL_FUNCTION(pa_stream_connect_record);
DECLARE_DL_FUNCTION(pa_stream_peek);
DECLARE_DL_FUNCTION(pa_stream_drop);
DECLARE_DL_FUNCTION(pa_mainloop_new);
DECLARE_DL_FUNCTION(pa_mainloop_get_api);
DECLARE_DL_FUNCTION(pa_mainloop_iterate);
DECLARE_DL_FUNCTION(pa_mainloop_free);
DECLARE_DL_FUNCTION(pa_context_get_sink_info_list);
DECLARE_DL_FUNCTION(pa_context_get_source_info_list);
DECLARE_DL_FUNCTION(pa_operation_get_state);

bool PulseAudioLoader::IncRef(){
	if(refCount==0){
		lib=dlopen("libpulse.so.0", RTLD_LAZY);
		if(!lib)
			lib=dlopen("libpulse.so", RTLD_LAZY);
		if(!lib){
			LOGE("Error loading libpulse: %s", dlerror());
			return false;
		}
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
	LOAD_DL_FUNCTION(pa_stream_set_write_callback);
	LOAD_DL_FUNCTION(pa_stream_connect_playback);
	LOAD_DL_FUNCTION(pa_operation_unref);
	LOAD_DL_FUNCTION(pa_stream_cork);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_stop);
	LOAD_DL_FUNCTION(pa_stream_disconnect);
	LOAD_DL_FUNCTION(pa_stream_unref);
	LOAD_DL_FUNCTION(pa_context_disconnect);
	LOAD_DL_FUNCTION(pa_context_unref);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_free);
	LOAD_DL_FUNCTION(pa_threaded_mainloop_signal);
	LOAD_DL_FUNCTION(pa_stream_begin_write);
	LOAD_DL_FUNCTION(pa_stream_write);
	LOAD_DL_FUNCTION(pa_stream_get_state);
	LOAD_DL_FUNCTION(pa_strerror);
	LOAD_DL_FUNCTION(pa_stream_set_read_callback);
	LOAD_DL_FUNCTION(pa_stream_connect_record);
	LOAD_DL_FUNCTION(pa_stream_peek);
	LOAD_DL_FUNCTION(pa_stream_drop);
	LOAD_DL_FUNCTION(pa_mainloop_new);
	LOAD_DL_FUNCTION(pa_mainloop_get_api);
	LOAD_DL_FUNCTION(pa_mainloop_iterate);
	LOAD_DL_FUNCTION(pa_mainloop_free);
	LOAD_DL_FUNCTION(pa_context_get_sink_info_list);
	LOAD_DL_FUNCTION(pa_context_get_source_info_list);
	LOAD_DL_FUNCTION(pa_operation_get_state);

	refCount++;
	return true;
}

void PulseAudioLoader::DecRef(){
	if(refCount>0)
		refCount--;
	if(refCount==0){
		dlclose(lib);
		lib=NULL;
	}
}