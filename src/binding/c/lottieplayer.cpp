#include <lotplayer.h>

extern "C" {

using namespace lottieplayer;

using lotplayer = LOTPlayer;

LOT_EXPORT lotplayer *lotplayer_create(void)
{
   lotplayer* p = new LOTPlayer();
   if (!p) {
      //TODO: Print Error
   }
   return p;
}

LOT_EXPORT int lotplayer_destroy(lotplayer *player)
{
    if (!player) return -1;
    delete(player);

    return 0;
}

LOT_EXPORT int lotplayer_set_file(lotplayer *player, const char *file)
{
   if (!player) return -1;
   bool ret = player->setFilePath(file);

   if (!ret) return -1;

   return 0;
}

LOT_EXPORT int lotplayer_set_size(lotplayer *player, int w, int h)
{
   if (!player) return -1;

   player->setSize(w, h);

   return 0;
}

LOT_EXPORT int lotplayer_get_size(const lotplayer *player, int* w, int* h)
{
   if (!player) return -1;

   player->size(*w, *h);

   return 0;
}

LOT_EXPORT float lotplayer_get_pos(const lotplayer *player)
{
   if (!player) return -1.0f;

   return player->pos();
}

LOT_EXPORT size_t lotplayer_get_node_count(const lotplayer *player, float pos)
{
   if (!player) return 0;

   return player->renderList(pos).size();
}

LOT_EXPORT float lotplayer_get_playtime(const lotplayer *player)
{
   if (!player) return 0.0f;

   return player->playTime();
}

LOT_EXPORT const lotnode* lotplayer_get_node(lotplayer *player, float pos, size_t idx)
{
   if (!player) return nullptr;

   if (idx >= player->renderList(pos).size()) {
      return nullptr;
   }

   return player->renderList(pos)[idx];
}

}
