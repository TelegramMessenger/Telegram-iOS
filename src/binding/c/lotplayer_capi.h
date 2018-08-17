#ifndef _LOTPLAYER_CAPI_H_
#define _LOTPLAYER_CAPI_H_

#include <lotcommon.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lotplayer_s lotplayer;

LOT_EXPORT lotplayer *lotplayer_create(void);
LOT_EXPORT int lotplayer_destroy(lotplayer *player);
LOT_EXPORT int lotplayer_set_file(lotplayer *player, const char *file);
LOT_EXPORT int lotplayer_set_size(lotplayer *player, int w, int h);
LOT_EXPORT int lotplayer_get_size(const lotplayer *player, int* w, int* h);
LOT_EXPORT float lotplayer_get_playtime(const lotplayer *player);
LOT_EXPORT float lotplayer_get_pos(const lotplayer *player);
LOT_EXPORT size_t lotplayer_get_node_count(const lotplayer *player, float pos);
LOT_EXPORT const lotnode* lotplayer_get_node(lotplayer *player, float pos, size_t idx);

#ifdef __cplusplus
}
#endif

#endif //_LOTPLAYER_CAPI_H_

