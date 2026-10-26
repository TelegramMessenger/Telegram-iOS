#pragma once
#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

namespace gift {
struct PerformanceSample {
    double fps=0;
    double frameP95Ms=std::numeric_limits<double>::quiet_NaN();
    double renderMs=std::numeric_limits<double>::quiet_NaN();
    double animationCpuMs=std::numeric_limits<double>::quiet_NaN();
    double cpuPercent=std::numeric_limits<double>::quiet_NaN();
};
// Main-thread, bounded samples (HUD: 0.5 s, diagnostic benchmark: 30 s). FPS counts submitted render frames;
// frame intervals measure pacing, not GPU execution. CPU uses process CPU time.
class PerformanceMetrics {
    double windowStart=0,lastFrame=-1,lastCPU=-1,renderSum=0,animationSum=0;
    size_t frames=0;
    std::vector<double> intervals;
public:
    void reset(double now,double cpuSeconds) {
        windowStart=now;lastFrame=-1;lastCPU=cpuSeconds;frames=0;
        renderSum=animationSum=0;intervals.clear();intervals.reserve(4096);
    }
    void record(double start,double renderMs,double animationCpuMs,bool continuous=true) {
        if(continuous && lastFrame>=0 && start>lastFrame && intervals.size()<4096)
            intervals.push_back((start-lastFrame)*1000);
        lastFrame=continuous?start:-1;++frames;renderSum+=renderMs;animationSum+=animationCpuMs;
    }
    PerformanceSample sample(double now,double cpuSeconds) {
        PerformanceSample s;double elapsed=now-windowStart;
        if(elapsed<=0)return s;
        s.fps=frames/elapsed;
        if(frames){s.renderMs=renderSum/frames;s.animationCpuMs=animationSum/frames;}
        if(!intervals.empty()) {
            size_t index=size_t(std::ceil(intervals.size()*.95))-1;
            std::nth_element(intervals.begin(),intervals.begin()+index,intervals.end());
            s.frameP95Ms=intervals[index];
        }
        if(lastCPU>=0 && cpuSeconds>=lastCPU)s.cpuPercent=(cpuSeconds-lastCPU)/elapsed*100;
        lastCPU=cpuSeconds;windowStart=now;frames=0;renderSum=animationSum=0;intervals.clear();
        return s;
    }
};
}
