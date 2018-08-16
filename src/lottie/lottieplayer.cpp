#include <lottieplayer.h>

#include "lottieitem.h"
#include "lottieloader.h"
#include "lottiemodel.h"

#include <fstream>

class LOTPlayerPrivate {

public:
    LOTPlayerPrivate();
    bool                          update(float pos);
    bool                          setFilePath(std::string path);
    void                          setSize(const VSize &sz);
    void                          setPos(float pos);
    VSize                         size() const;
    float                         playTime() const;
    float                         pos();
    const std::vector<LOTNode *> &renderList(float pos);
    bool                          render(float pos, const LOTBuffer &buffer, bool forceRender);

private:
    std::string                  mFilePath;
    std::shared_ptr<LOTModel>    mModel;
    std::unique_ptr<LOTCompItem> mCompItem;
    VSize                        mSize;
    std::atomic<bool>            mRenderInProgress;
    float                        mPos = 0.0;
};

void LOTPlayerPrivate::setSize(const VSize &sz)
{
     mSize = sz;
}

VSize LOTPlayerPrivate::size() const
{
    if (!mCompItem) {
        return mSize;
    } else {
        return mCompItem->size();
    }
}

const std::vector<LOTNode *> &LOTPlayerPrivate::renderList(float pos)
{
    if (!mCompItem) {
        static std::vector<LOTNode *> empty;
        return empty;
    }

    update(pos);

    return mCompItem->renderList();
}

float LOTPlayerPrivate::playTime() const
{
    if (!mModel || mModel->isStatic()) return 0;
    return float(mModel->frameDuration()) / float(mModel->frameRate());
}

float LOTPlayerPrivate::pos()
{
    return mPos;
}

void LOTPlayerPrivate::setPos(float pos)
{
    if (pos > 1.0) pos = 1.0;
    if (pos < 0) pos = 0;
    mPos = pos;
}

bool LOTPlayerPrivate::update(float pos)
{
   if (!mCompItem) return false;

   mCompItem->resize(mSize);
   setPos(pos);

   int frameNumber;
   if (mModel->isStatic()) frameNumber = 0;
   else frameNumber = mModel->startFrame() + pos() * mModel->frameDuration();

   return mCompItem->update(frameNumber);
}

bool LOTPlayerPrivate::render(float pos, const LOTBuffer &buffer, bool forceRender)
{
    if (!mCompItem) return false;

    bool renderInProgress = mRenderInProgress.load();
    if (renderInProgress)
      {
        vCritical << "Already Rendering Scheduled for this Player";
      }

    bool result = true;

    if (update(pos) || forceRender)
      {
         mRenderInProgress.store(true);
         result = mCompItem->render(buffer);
         mRenderInProgress.store(false);
      }

    return result;
}

LOTPlayerPrivate::LOTPlayerPrivate() : mRenderInProgress(false) {}

bool LOTPlayerPrivate::setFilePath(std::string path)
{
    if (path.empty()) {
        vWarning << "File path is empty";
        return false;
    }

    LottieLoader loader;
    if (loader.load(path)) {
        mModel = loader.model();
        mCompItem = std::make_unique<LOTCompItem>(mModel.get());
        return true;
    }
    return false;
}

/*
 * Implement a task stealing schduler to perform render task
 * As each player draws into its own buffer we can delegate this
 * task to a slave thread. The scheduler creates a threadpool depending
 * on the number of cores available in the system and does a simple fair
 * scheduling by assigning the task in a round-robin fashion. Each thread
 * in the threadpool has its own queue. once it finishes all the task on its
 * own queue it goes through rest of the queue and looks for task if it founds
 * one it steals the task from it and executes. if it couldn't find one then it
 * just waits for new task on its own queue.
 */
struct RenderTask {
    RenderTask() { receiver = sender.get_future(); }
    std::promise<bool> sender;
    std::future<bool>  receiver;
    LOTPlayerPrivate * playerImpl;
    float              pos;
    LOTBuffer          buffer;
    bool               forceRender;
};

#include <vtaskqueue.h>
class RenderTaskScheduler {
    const unsigned           _count{std::thread::hardware_concurrency()};
    std::vector<std::thread> _threads;
    std::vector<TaskQueue<RenderTask>> _q{_count};
    std::atomic<unsigned>              _index{0};

    void run(unsigned i)
    {
        while (true) {
            RenderTask *task = nullptr;

            for (unsigned n = 0; n != _count * 32; ++n) {
                if (_q[(i + n) % _count].try_pop(task)) break;
            }
            if (!task && !_q[i].pop(task)) break;

            bool result = task->playerImpl->render(task->pos, task->buffer, task->forceRender);
            task->sender.set_value(result);
            delete task;
        }
    }

public:
    RenderTaskScheduler()
    {
        for (unsigned n = 0; n != _count; ++n) {
            _threads.emplace_back([&, n] { run(n); });
        }
    }

    ~RenderTaskScheduler()
    {
        for (auto &e : _q) e.done();

        for (auto &e : _threads) e.join();
    }

    std::future<bool> async(RenderTask *task)
    {
        auto receiver = std::move(task->receiver);
        auto i = _index++;

        for (unsigned n = 0; n != _count; ++n) {
            if (_q[(i + n) % _count].try_push(task)) return receiver;
        }

        _q[i % _count].push(task);

        return receiver;
    }

    std::future<bool> render(LOTPlayerPrivate *impl, float pos,
                             LOTBuffer &&buffer, bool forceRender)
    {
        RenderTask *task = new RenderTask();
        task->playerImpl = impl;
        task->pos = pos;
        task->buffer = std::move(buffer);
        task->forceRender = forceRender;
        return async(task);
    }
};
static RenderTaskScheduler render_scheduler;

LOTPlayer::LOTPlayer() : d(new LOTPlayerPrivate()) {}

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
    VSize sz = d->size();

    width = sz.width();
    height = sz.height();
}

float LOTPlayer::playTime() const
{
    return d->playTime();
}

float LOTPlayer::pos()
{
    return d->pos();
}

const std::vector<LOTNode *> &LOTPlayer::renderList(float pos) const
{
    return d->renderList(pos);
}

std::future<bool> LOTPlayer::render(float pos, LOTBuffer buffer, bool forceRender)
{
    return render_scheduler.render(d, pos, std::move(buffer), forceRender);
}

bool LOTPlayer::renderSync(float pos, LOTBuffer buffer, bool forceRender)
{
    return d->render(pos, buffer, forceRender);
}

void initLogging()
{
#if defined(__ARM_NEON__)
    set_log_level(LogLevel::OFF);
#else
    initialize(GuaranteedLogger(), "/tmp/", "lotti-player", 1);
    set_log_level(LogLevel::INFO);
#endif
}

V_CONSTRUCTOR_FUNCTION(initLogging)
