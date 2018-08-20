#ifndef _LOT_PLAYER_H_
#define _LOT_PLAYER_H_

#include <future>
#include <vector>

#include "lotcommon.h"

//TODO: Hide this.
class LOTPlayerPrivate;
#define _LOT_PLAYER_DECLARE_PRIVATE(A) \
   class A##Private *d;

namespace lottieplayer {

class LOT_EXPORT LOTPlayer {
public:
    ~LOTPlayer();
    LOTPlayer();

    bool setFilePath(const char *filePath);

    float playTime() const;

    float pos() const;

    const std::vector<LOTNode *> &renderList(float pos) const;

    // TODO: Consider correct position...
    void              setSize(int width, int height);
    void              size(int &width, int &height) const;
    std::future<bool> render(float pos, LOTBuffer buffer, bool forceRender = false);
    bool              renderSync(float pos, LOTBuffer buffer, bool forceRender = false);

private:
    _LOT_PLAYER_DECLARE_PRIVATE(LOTPlayer);
};

}  // namespace lotplayer

#endif  // _LOT_PLAYER_H_
