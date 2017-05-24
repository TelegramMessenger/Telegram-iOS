//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_PULSEAUDIOLOADER_H
#define LIBTGVOIP_PULSEAUDIOLOADER_H

#include <pulse/pulseaudio.h>

#define DECLARE_DL_FUNCTION(name) static typeof(name)* _import_##name

namespace tgvoip{
class PulseAudioLoader{
public:
	static bool IncRef();
	static void DecRef();

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

private:
	static void* lib;
	static int refCount;
};
}

#undef DECLARE_DL_FUNCTION

#ifdef TGVOIP_IN_AUDIO_IO
#define pa_threaded_mainloop_new PulseAudioLoader::_import_pa_threaded_mainloop_new
#define pa_threaded_mainloop_get_api PulseAudioLoader::_import_pa_threaded_mainloop_get_api
#define pa_context_new PulseAudioLoader::_import_pa_context_new
#define pa_context_set_state_callback PulseAudioLoader::_import_pa_context_set_state_callback
#define pa_threaded_mainloop_lock PulseAudioLoader::_import_pa_threaded_mainloop_lock
#define pa_threaded_mainloop_unlock PulseAudioLoader::_import_pa_threaded_mainloop_unlock
#define pa_threaded_mainloop_start PulseAudioLoader::_import_pa_threaded_mainloop_start
#define pa_context_connect PulseAudioLoader::_import_pa_context_connect
#define pa_context_get_state PulseAudioLoader::_import_pa_context_get_state
#define pa_threaded_mainloop_wait PulseAudioLoader::_import_pa_threaded_mainloop_wait
#define pa_stream_new PulseAudioLoader::_import_pa_stream_new
#define pa_stream_set_state_callback PulseAudioLoader::_import_pa_stream_set_state_callback
#define pa_stream_set_write_callback PulseAudioLoader::_import_pa_stream_set_write_callback
#define pa_stream_connect_playback PulseAudioLoader::_import_pa_stream_connect_playback
#define pa_operation_unref PulseAudioLoader::_import_pa_operation_unref
#define pa_stream_cork PulseAudioLoader::_import_pa_stream_cork
#define pa_threaded_mainloop_stop PulseAudioLoader::_import_pa_threaded_mainloop_stop
#define pa_stream_disconnect PulseAudioLoader::_import_pa_stream_disconnect
#define pa_stream_unref PulseAudioLoader::_import_pa_stream_unref
#define pa_context_disconnect PulseAudioLoader::_import_pa_context_disconnect
#define pa_context_unref PulseAudioLoader::_import_pa_context_unref
#define pa_threaded_mainloop_free PulseAudioLoader::_import_pa_threaded_mainloop_free
#define pa_threaded_mainloop_signal PulseAudioLoader::_import_pa_threaded_mainloop_signal
#define pa_stream_begin_write PulseAudioLoader::_import_pa_stream_begin_write
#define pa_stream_write PulseAudioLoader::_import_pa_stream_write
#define pa_strerror PulseAudioLoader::_import_pa_strerror
#define pa_stream_get_state PulseAudioLoader::_import_pa_stream_get_state
#define pa_stream_set_read_callback PulseAudioLoader::_import_pa_stream_set_read_callback
#define pa_stream_connect_record PulseAudioLoader::_import_pa_stream_connect_record
#define pa_stream_peek PulseAudioLoader::_import_pa_stream_peek
#define pa_stream_drop PulseAudioLoader::_import_pa_stream_drop
#define pa_mainloop_new PulseAudioLoader::_import_pa_mainloop_new
#define pa_mainloop_get_api PulseAudioLoader::_import_pa_mainloop_get_api
#define pa_mainloop_iterate PulseAudioLoader::_import_pa_mainloop_iterate
#define pa_mainloop_free PulseAudioLoader::_import_pa_mainloop_free
#define pa_context_get_sink_info_list PulseAudioLoader::_import_pa_context_get_sink_info_list
#define pa_context_get_source_info_list PulseAudioLoader::_import_pa_context_get_source_info_list
#define pa_operation_get_state PulseAudioLoader::_import_pa_operation_get_state
#endif

#endif // LIBTGVOIP_PULSEAUDIOLOADER_H