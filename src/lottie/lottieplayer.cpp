#include <lottieplayer.h>

#include "lottiemodel.h"
#include "lottieloader.h"
#include "lottieitem.h"

#include<fstream>


class LOTPlayerPrivate
{
public:
   LOTPlayerPrivate();
   bool setFilePath(std::string path);
   void setSize(const VSize &sz);
   void size(int &w, int &h) const;
   float playTime() const;
   bool seek(float pos);
   const std::vector<LOTNode *>& renderList()const;
   bool render(float pos, const LOTBuffer &buffer);
public:
   std::string                     mFilePath;
   std::shared_ptr<LOTModel>       mModel;
   std::unique_ptr<LOTCompItem>    mCompItem;
   VSize                          mSize;
};

void LOTPlayerPrivate::setSize(const VSize &sz)
{
    if (!mCompItem.get()) {
        vWarning << "Set file first!";
        return;
    }

    mCompItem->resize(sz);
}

void LOTPlayerPrivate::size(int &w, int &h) const
{
    if (!mCompItem.get()) {
        w = 0;
        h = 0;
        return;
    }

    VSize size = mCompItem->size();
    w = size.width();
    h = size.height();
}

const std::vector<LOTNode *>& LOTPlayerPrivate::renderList() const
{
    if (!mCompItem.get()) {
        //FIXME: Reference is not good...
    }

    return mCompItem->renderList();
}

float LOTPlayerPrivate::playTime() const
{
   if (mModel->isStatic()) return 0;
   return float(mModel->frameDuration()) / float(mModel->frameRate());
}

bool LOTPlayerPrivate::seek(float pos)
{
   if (!mModel || !mCompItem) return false;

   if (pos > 1.0) pos = 1.0;
   if (pos < 0) pos = 0;
   if (mModel->isStatic()) pos = 0;
   int frameNumber = mModel->startFrame() + pos * mModel->frameDuration();
   return mCompItem->update(frameNumber);
}

bool LOTPlayerPrivate::render(float pos, const LOTBuffer &buffer)
{
    if (seek(pos)) {
        if (mCompItem->render(buffer))
            return true;
        else
            return false;
    } else {
        return false;
    }
}

LOTPlayerPrivate::LOTPlayerPrivate()
{

}

bool
LOTPlayerPrivate::setFilePath(std::string path)
{
   LottieLoader loader;
   if (loader.load(path)) {
      mModel = loader.model();
      mCompItem =  std::unique_ptr<LOTCompItem>(new LOTCompItem(mModel.get()));
      return true;
   }
   return false;
}

LOTPlayer::LOTPlayer():d(new LOTPlayerPrivate())
{

}

LOTPlayer::~LOTPlayer()
{
   delete d;
}


/**
 * \breif Brief abput the Api.
 * Description about the setFilePath Api
 * @param path  add the details
 */

bool LOTPlayer::setFilePath(const char *filePath)
{
   return d->setFilePath(filePath);
}

void LOTPlayer::setSize(int width, int height)
{
   d->setSize(VSize(width, height));
}

void LOTPlayer::size(int &width, int &height) const
{
   d->size(width, height);
}

float LOTPlayer::playTime() const
{
   return d->playTime();
}

void LOTPlayer::seek(float pos)
{
   d->seek(pos);
}

const std::vector<LOTNode *>& LOTPlayer::renderList()const
{
    return d->renderList();
}

std::future<bool> LOTPlayer::render(float pos, const LOTBuffer &buffer)
{
    return std::async(std::launch::async, &LOTPlayerPrivate::render, d, pos, buffer);
}

bool LOTPlayer::renderSync(float pos, const LOTBuffer &buffer)
{
    return d->render(pos, buffer);
}

LOTNode::~LOTNode()
{
}

LOTNode::LOTNode()
{
}


