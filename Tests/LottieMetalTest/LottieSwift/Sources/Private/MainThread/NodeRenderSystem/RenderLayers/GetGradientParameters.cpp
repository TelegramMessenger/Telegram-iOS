#include "GetGradientParameters.hpp"

namespace lottie {

void getGradientParameters(int numberOfColors, GradientColorSet const &colors, std::vector<Color> &outColors, std::vector<double> &outLocations) {
    std::vector<Color> alphaColors;
    std::vector<double> alphaValues;
    std::vector<double> alphaLocations;
    
    std::vector<Color> gradientColors;
    std::vector<double> colorLocations;
    
    for (int i = 0; i < numberOfColors; i++) {
        int ix = i * 4;
        if (colors.colors.size() > ix) {
            Color color(
                colors.colors[ix + 1],
                colors.colors[ix + 2],
                colors.colors[ix + 3],
                1
            );
            gradientColors.push_back(color);
            colorLocations.push_back(colors.colors[ix]);
        }
    }
    
    bool drawMask = false;
    for (int i = numberOfColors * 4; i < (int)colors.colors.size(); i += 2) {
        double alpha = colors.colors[i + 1];
        if (alpha < 1.0) {
            drawMask = true;
        }
        alphaLocations.push_back(colors.colors[i]);
        alphaColors.push_back(Color(alpha, alpha, alpha, 1.0));
        alphaValues.push_back(alpha);
    }
    
    if (drawMask) {
        std::vector<double> locations;
        for (size_t i = 0; i < std::min(gradientColors.size(), colorLocations.size()); i++) {
            if (std::find(locations.begin(), locations.end(), colorLocations[i]) == locations.end()) {
                locations.push_back(colorLocations[i]);
            }
        }
        for (size_t i = 0; i < std::min(alphaValues.size(), alphaLocations.size()); i++) {
            if (std::find(locations.begin(), locations.end(), alphaLocations[i]) == locations.end()) {
                locations.push_back(alphaLocations[i]);
            }
        }
        
        std::sort(locations.begin(), locations.end());
        if (locations[0] != 0.0) {
            locations.insert(locations.begin(), 0.0);
        }
        if (locations[locations.size() - 1] != 1.0) {
            locations.push_back(1.0);
        }
        
        std::vector<Color> colors;
        
        for (const auto location : locations) {
            Color color = gradientColors[0];
            for (size_t i = 0; i < std::min(gradientColors.size(), colorLocations.size()) - 1; i++) {
                if (location >= colorLocations[i] && location <= colorLocations[i + 1]) {
                    double localLocation = 0.0;
                    if (colorLocations[i] != colorLocations[i + 1]) {
                        localLocation = remapDouble(location, colorLocations[i], colorLocations[i + 1], 0.0, 1.0);
                    }
                    color = ValueInterpolator<Color>::interpolate(gradientColors[i], gradientColors[i + 1], localLocation, std::nullopt, std::nullopt);
                    break;
                }
            }
            
            double alpha = 1.0;
            for (size_t i = 0; i < std::min(alphaValues.size(), alphaLocations.size()) - 1; i++) {
                if (location >= alphaLocations[i] && location <= alphaLocations[i + 1]) {
                    double localLocation = 0.0;
                    if (alphaLocations[i] != alphaLocations[i + 1]) {
                        localLocation = remapDouble(location, alphaLocations[i], alphaLocations[i + 1], 0.0, 1.0);
                    }
                    alpha = ValueInterpolator<double>::interpolate(alphaValues[i], alphaValues[i + 1], localLocation, std::nullopt, std::nullopt);
                    break;
                }
            }
            
            color.a = alpha;
            
            colors.push_back(color);
        }
        
        gradientColors = colors;
        colorLocations = locations;
    }
    
    outColors = gradientColors;
    outLocations = colorLocations;
}

}
