#ifndef CompoundBezierPath_hpp
#define CompoundBezierPath_hpp

#include "Lottie/Private/Utility/Primitives/BezierPath.hpp"

namespace lottie {

/// A collection of BezierPath objects that can be trimmed and added.
///
class CompoundBezierPath: public std::enable_shared_from_this<CompoundBezierPath> {
public:
    CompoundBezierPath() :
    paths({}) {
    }
    
    CompoundBezierPath(BezierPath const &path) :
    paths({ path }) {
    }
    
    CompoundBezierPath(std::vector<BezierPath> paths_, std::optional<double> length_) :
    paths(paths_), _length(length_) {
    }
    
    CompoundBezierPath(std::vector<BezierPath> paths_) :
    paths(paths_) {
    }
    
public:
    std::vector<BezierPath> paths;
    
    double length() {
        if (_length.has_value()) {
            return _length.value();
        } else {
            double l = 0.0;
            for (auto &path : paths) {
                l += path.length();
            }
            _length = l;
            return l;
        }
    }
    
private:
    std::optional<double> _length;
    
public:
    std::shared_ptr<CompoundBezierPath> addingPath(BezierPath const &path) const {
        auto newPaths = paths;
        newPaths.push_back(path);
        return std::make_shared<CompoundBezierPath>(newPaths);
    }
    
    void appendPath(BezierPath const &path) {
        paths.push_back(path);
        _length.reset();
    }
    
    std::shared_ptr<CompoundBezierPath> combine(std::shared_ptr<CompoundBezierPath> compoundBezier) {
        auto newPaths = paths;
        for (const auto &path : compoundBezier->paths) {
            newPaths.push_back(path);
        }
        return std::make_shared<CompoundBezierPath>(newPaths);
    }
    
    std::shared_ptr<CompoundBezierPath> trim(double fromPosition, double toPosition, double offset) {
        if (fromPosition == toPosition) {
            return std::make_shared<CompoundBezierPath>();
        }
        
        /*bool trimSimultaneously = false;
        if (trimSimultaneously) {
            /// Trim each path individually.
            std::vector<BezierPath> newPaths;
            for (auto &path : paths) {
                auto trimmedPaths = path.trim(fromPosition * path.length(), toPosition * path.length(), offset * path.length());
                for (const auto &trimmedPath : trimmedPaths) {
                    newPaths.push_back(trimmedPath);
                }
            }
            return std::make_shared<CompoundBezierPath>(newPaths);
        }*/
        
        double lengthValue = length();
        
        /// Normalize lengths to the curve length.
        double startPosition = fmod(fromPosition + offset, 1.0);
        double endPosition = fmod(toPosition + offset, 1.0);
        
        if (startPosition < 0.0) {
            startPosition = 1.0 + startPosition;
        }
        
        if (endPosition < 0.0) {
            endPosition = 1.0 + endPosition;
        }
        
        if (startPosition == 1.0) {
            startPosition = 0.0;
        }
        if (endPosition == 0.0) {
            endPosition = 1.0;
        }
        
        if ((startPosition == 0.0 && endPosition == 1.0) ||
            startPosition == endPosition ||
            (startPosition == 1.0 && endPosition == 0.0)) {
            /// The trim encompasses the entire path. Return.
            return shared_from_this();
        }
        
        std::vector<BezierTrimPathPosition> positions;
        if (endPosition < startPosition) {
            positions = {
                BezierTrimPathPosition(0.0, endPosition * lengthValue),
                BezierTrimPathPosition(startPosition * lengthValue, lengthValue)
            };
        } else {
            positions = { BezierTrimPathPosition(startPosition * lengthValue, endPosition * lengthValue) };
        }
        
        auto compoundPath = std::make_shared<CompoundBezierPath>();
        auto trim = positions[0];
        positions.erase(positions.begin());
        double pathStartPosition = 0.0;
        
        bool finishedTrimming = false;
        int i = 0;
        
        while (!finishedTrimming) {
            if (paths.size() <= i) {
                /// Rounding errors
                finishedTrimming = true;
                continue;
            }
            auto path = paths[i];
            
            auto pathEndPosition = pathStartPosition + path.length();
            
            if (pathEndPosition < trim.start) {
                /// Path is not included in the trim, continue.
                pathStartPosition = pathEndPosition;
                i = i + 1;
                continue;
            } else if (trim.start <= pathStartPosition && pathEndPosition <= trim.end) {
                /// Full Path is inside of trim. Add full path.
                compoundPath = compoundPath->addingPath(path);
            } else {
                auto trimPaths = path.trim(trim.start > pathStartPosition ? (trim.start - pathStartPosition) : 0, trim.end < pathEndPosition ? (trim.end - pathStartPosition) : path.length(), 0.0);
                if (!trimPaths.empty()) {
                    compoundPath = compoundPath->addingPath(trimPaths[0]);
                }
            }
            
            if (trim.end <= pathEndPosition) {
                /// We are done with the current trim.
                /// Advance trim but remain on the same path in case the next trim overlaps it.
                if (positions.size() > 0) {
                    trim = positions[0];
                    positions.erase(positions.begin());
                } else {
                    finishedTrimming = true;
                }
            } else {
                pathStartPosition = pathEndPosition;
                i = i + 1;
            }
        }
        return compoundPath;
    }
};

}

#endif /* CompoundBezierPath_hpp */
