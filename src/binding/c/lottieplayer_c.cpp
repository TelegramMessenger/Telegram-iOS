#include <lotplayer.h>
#include "vdebug.h"

extern "C" {

using namespace lottieplayer;

using lotplayer = LOTPlayer;

LOT_EXPORT lotplayer *lotplayer_create(void)
{
   lotplayer* p = new LOTPlayer();
   if (!p) {
      vCritical << "Failed to initialize lotplayer";
   }
   return p;
}

LOT_EXPORT int lotplayer_destroy(lotplayer *player)
{
    if (!player) return LOT_PLAYER_ERROR_INVALID_PARAMETER;
    delete(player);

    return LOT_PLAYER_ERROR_NONE;
}

LOT_EXPORT int lotplayer_set_file(lotplayer *player, const char *file)
{
   if (!player) return LOT_PLAYER_ERROR_INVALID_PARAMETER;
   bool ret = player->setFilePath(file);

   if (!ret) return -1;

   return LOT_PLAYER_ERROR_NONE;
}

LOT_EXPORT int lotplayer_set_size(lotplayer *player, int w, int h)
{
   if (!player) return LOT_PLAYER_ERROR_INVALID_PARAMETER;

   player->setSize(w, h);

   return LOT_PLAYER_ERROR_NONE;
}

LOT_EXPORT int lotplayer_get_size(const lotplayer *player, int* w, int* h)
{
   if (!player) return LOT_PLAYER_ERROR_INVALID_PARAMETER;

   player->size(*w, *h);

   return LOT_PLAYER_ERROR_NONE;
}

LOT_EXPORT float lotplayer_get_pos(const lotplayer *player)
{
   if (!player) {
        vWarning << "Invalid parameter player = nullptr";
        return -1.0f;
   }

   return player->pos();
}

LOT_EXPORT size_t lotplayer_get_node_count(const lotplayer *player, float pos)
{
   if (!player) return LOT_PLAYER_ERROR_NONE;

   return player->renderList(pos).size();
}

LOT_EXPORT float lotplayer_get_playtime(const lotplayer *player)
{
   if (!player) {
        vWarning << "Invalid parameter player = nullptr";
        return 0.0f;
   }

   return player->playTime();
}

LOT_EXPORT const lotnode* lotplayer_get_node(lotplayer *player, float pos, size_t idx)
{
   if (!player) {
        vWarning << "Invalid parameter player = nullptr";
        return nullptr;
   }

   if (idx >= player->renderList(pos).size()) {
      vWarning << "Invalid parameter idx? (0 ~ " << player->renderList(pos).size() << "), given idx = " << idx;
      return nullptr;
   }

   return player->renderList(pos)[idx];
}

}
