#ifndef _LOTPLAYER_CAPI_H_
#define _LOTPLAYER_CAPI_H_

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <lotcommon.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lotplayer_s LOTPlayer;

LOT_EXPORT LOTPlayer *lotplayer_create(void);
LOT_EXPORT int lotplayer_destroy(LOTPlayer *player);
LOT_EXPORT int lotplayer_set_file(LOTPlayer *player, const char *file);
LOT_EXPORT int lotplayer_set_size(LOTPlayer *player, int w, int h);
LOT_EXPORT int lotplayer_get_size(const LOTPlayer *player, int* w, int* h);
LOT_EXPORT float lotplayer_get_playtime(const LOTPlayer *player);
LOT_EXPORT long lotplayer_get_totalframe(const LOTPlayer *player);
LOT_EXPORT float lotplayer_get_framerate(const LOTPlayer *player);
LOT_EXPORT float lotplayer_get_pos(const LOTPlayer *player);
LOT_EXPORT size_t lotplayer_get_node_count(const LOTPlayer *player, float pos);
LOT_EXPORT const LOTNode* lotplayer_get_node(LOTPlayer *player, float pos, size_t idx);

#ifdef __cplusplus
}
#endif

#endif //_LOTPLAYER_CAPI_H_

