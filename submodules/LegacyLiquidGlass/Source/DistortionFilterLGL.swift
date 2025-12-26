import CoreImage

final class DistortionFilterLGL: CIFilter {

    enum FilterStrategy {
        case positionKernel(_ kernel: CIWarpKernel)
        case coreImage
        case none
    }

    // MARK: - Property

    private var filter: FilterStrategy = .none

    // MARK: - LifeCycle

    override init() {
        super.init()
        setupFilterStrategy()
    }

    required init?(coder: NSCoder) {
        super.init()
        setupFilterStrategy()
    }

    // MARK: - Public

    public func applyFilter(
        to inputImage: inout CIImage,
        center: CIVector? = nil,
        radius: CGFloat? = nil,
        intensity: CGFloat = 0.5
    ) {
        switch filter {
        case let .positionKernel(kernel):
            let center: CIVector = center ?? CIVector(x: inputImage.extent.midX, y: inputImage.extent.midY)
            let radius = radius ?? sqrt(pow(inputImage.extent.width, 2) + pow(inputImage.extent.height, 2)) / 2
            guard let kernelImage = kernel.apply(
                extent: inputImage.extent,
                roiCallback: { _, rect in rect },
                image: inputImage,
                arguments: [
                    center,
                    radius,
                    intensity
                ]) else { return }
            inputImage = kernelImage
        case .coreImage, .none:
            break
        }
    }
}

// MARK: - Config

private extension DistortionFilterLGL {

    func setupFilterStrategy() {
        filter = createFilterStrategy()
    }

    func createFilterStrategy() -> FilterStrategy {
        let kernelString = """
        kernel vec2 liquidDistortion(
            vec2 center,
            float radius,
            float intensity
        ) {
            vec2 uv = destCoord();
            vec2 d = uv - center;
            float distance = length(d);
            
            if (distance > radius) {
                return uv;
            }
            
            float t = distance / radius;
            
            float mirrorEffect = 1.0 - t;
            float wave = intensity * 5.0 * sin(mirrorEffect * 20.0) * mirrorEffect;
            
            float newDistance = distance * (1.0 + wave * 0.1);
            
            newDistance = min(newDistance, radius);
            
            vec2 direction = normalize(d);
            vec2 distortedUV = center + direction * newDistance;
            
            return distortedUV;
        }
        """

        guard let wrapKernel = CIWarpKernel(source: kernelString) else {
            return .coreImage
        }
        return .positionKernel(wrapKernel)

//        guard let url = Bundle.main.url(forResource: "DistortionFilterLGL", withExtension: "metal"),
//              let data = try? Data(contentsOf: url) else {
//            return .coreImage
//        }
//
//        do {
//            let metalKernel = try CIWarpKernel(functionName: "distortionLGL", fromMetalLibraryData: data)
//            return .positionKernel(metalKernel)
//        } catch {
//            print("Failed to create Metal kernel: \(error)")
//            return .coreImage
//        }
    }
}


