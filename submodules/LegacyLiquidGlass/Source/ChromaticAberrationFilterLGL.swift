import CoreImage
import Metal

final class ChromaticAberrationFilterLGL: CIFilter {

    enum FilterStrategy {
        case colorKernel(_ kernel: CIKernel)
        case coreImage
        case none
    }

    // MARK: - Properties

    private var filter: FilterStrategy = .none

    // MARK: - Input Parameters

//    @objc dynamic var inputImage: CIImage?
//    @objc dynamic var inputCenter: CIVector?
//    @objc dynamic var inputRadius: CGFloat = 0
//    @objc dynamic var inputRedShiftX: CGFloat = 0.02
//    @objc dynamic var inputRedShiftY: CGFloat = 0.01
//    @objc dynamic var inputGreenShiftX: CGFloat = 0.0
//    @objc dynamic var inputGreenShiftY: CGFloat = 0.0
//    @objc dynamic var inputBlueShiftX: CGFloat = -0.02
//    @objc dynamic var inputBlueShiftY: CGFloat = -0.01

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
        redShift: CGPoint = CGPoint(x: 0.02, y: 0.01),
        greenShift: CGPoint = CGPoint(x: 0.0, y: 0.0),
        blueShift: CGPoint = CGPoint(x: -0.02, y: -0.01)
    ) {
        switch filter {
        case let .colorKernel(kernel):
            let center = center ?? CIVector(x: inputImage.extent.midX, y: inputImage.extent.midY)
            let radius = radius ?? sqrt(pow(inputImage.extent.width, 2) + pow(inputImage.extent.height, 2)) / 2
            guard let kernelImage = kernel.apply(
                extent: inputImage.extent,
                roiCallback: { _, rect in rect },
                arguments: [
                    inputImage,
                    center,
                    radius,
                    redShift.x,
                    redShift.y,
                    greenShift.x,
                    greenShift.y,
                    blueShift.x,
                    blueShift.y
                ]) else { return }
            inputImage = kernelImage
        case .coreImage, .none:
            break
        }
    }
}

// MARK: - Config

private extension ChromaticAberrationFilterLGL {

    func setupFilterStrategy() {
        filter = createFilterStrategy()
    }

    func createFilterStrategy() -> FilterStrategy {
        let kernelString = """
        kernel vec4 chromaticAberration(
            sampler image,
            vec2 center,
            float radius,
            float redShiftX,
            float redShiftY,
            float greenShiftX,
            float greenShiftY,
            float blueShiftX,
            float blueShiftY
        ) {
            vec2 uv = samplerCoord(image);
            vec2 offset = uv - center;
            float distance = length(offset);
            
            float strength = 0.0;
            if (distance > radius * 0.7) {
                strength = smoothstep(radius * 0.7, radius, distance);
            }
            
            vec2 direction = normalize(offset);
            
            vec2 perpendicular = vec2(-direction.y, direction.x);
            
            vec2 redUV = uv + perpendicular * vec2(redShiftX, redShiftY) * strength;
            vec2 greenUV = uv + direction * vec2(greenShiftX, greenShiftY) * strength;
            vec2 blueUV = uv - perpendicular * vec2(blueShiftX, blueShiftY) * strength;
            
            float red = sample(image, redUV).r;
            float green = sample(image, greenUV).g;
            float blue = sample(image, blueUV).b;
            
            float alpha = sample(image, uv).a;
            
            return vec4(red, green, blue, alpha);
        }
        """

        guard let kernel = CIKernel(source: kernelString) else {
            return .coreImage
        }
        return .colorKernel(kernel)
    }
}
