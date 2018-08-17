#ifndef _LOTPLAYER_H_
#define _LOTPLAYER_H_

#include <future>
#include <vector>

#include "lotcommon.h"

//TODO: Hide this.
class LOTPlayerPrivate;
#define _LOTPLAYER_DECLARE_PRIVATE(A) \
   class A##Private *d;

namespace lotplayer {

class LOT_EXPORT LOTPlayer {
public:
    ~LOTPlayer();
    LOTPlayer();

    bool setFilePath(const char *filePath);

    float playTime() const;

    float pos();

    const std::vector<LOTNode *> &renderList(float pos) const;

    // TODO: Consider correct position...
    void              setSize(int width, int height);
    void              size(int &width, int &height) const;
    std::future<bool> render(float pos, LOTBuffer buffer, bool forceRender = false);
    bool              renderSync(float pos, LOTBuffer buffer, bool forceRender = false);

private:
    _LOTPLAYER_DECLARE_PRIVATE(LOTPlayer);
};

}  // namespace lotplayer

#endif  // _LOTPLAYER_H_
