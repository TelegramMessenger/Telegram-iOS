import CoreML

/// Model Prediction Input Type
@available(macOS 13.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
class U2netpInput : MLFeatureProvider {

    /// in_0 as color (kCVPixelFormatType_32BGRA) image buffer, 320 pixels wide by 320 pixels high
    var in_0: CVPixelBuffer

    var featureNames: Set<String> {
        get {
            return ["in_0"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "in_0") {
            return MLFeatureValue(pixelBuffer: in_0)
        }
        return nil
    }
    
    init(in_0: CVPixelBuffer) {
        self.in_0 = in_0
    }

    convenience init(in_0With in_0: CGImage) throws {
        self.init(in_0: try MLFeatureValue(cgImage: in_0, pixelsWide: 320, pixelsHigh: 320, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!)
    }

    convenience init(in_0At in_0: URL) throws {
        self.init(in_0: try MLFeatureValue(imageAt: in_0, pixelsWide: 320, pixelsHigh: 320, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!)
    }

    func setIn_0(with in_0: CGImage) throws  {
        self.in_0 = try MLFeatureValue(cgImage: in_0, pixelsWide: 320, pixelsHigh: 320, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

    func setIn_0(with in_0: URL) throws  {
        self.in_0 = try MLFeatureValue(imageAt: in_0, pixelsWide: 320, pixelsHigh: 320, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

}


/// Model Prediction Output Type
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
class U2netpOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// out_p0 as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 320 pixels wide by 320 pixels high
    lazy var out_p0: CVPixelBuffer = {
        [unowned self] in return self.provider.featureValue(for: "out_p0")!.imageBufferValue
    }()!

    /// out_p1 as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 320 pixels wide by 320 pixels high
    lazy var out_p1: CVPixelBuffer = {
        [unowned self] in return self.provider.featureValue(for: "out_p1")!.imageBufferValue
    }()!

    /// out_p2 as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 320 pixels wide by 320 pixels high
    lazy var out_p2: CVPixelBuffer = {
        [unowned self] in return self.provider.featureValue(for: "out_p2")!.imageBufferValue
    }()!

    /// out_p3 as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 320 pixels wide by 320 pixels high
    lazy var out_p3: CVPixelBuffer = {
        [unowned self] in return self.provider.featureValue(for: "out_p3")!.imageBufferValue
    }()!

    /// out_p4 as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 320 pixels wide by 320 pixels high
    lazy var out_p4: CVPixelBuffer = {
        [unowned self] in return self.provider.featureValue(for: "out_p4")!.imageBufferValue
    }()!

    /// out_p5 as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 320 pixels wide by 320 pixels high
    lazy var out_p5: CVPixelBuffer = {
        [unowned self] in return self.provider.featureValue(for: "out_p5")!.imageBufferValue
    }()!

    /// out_p6 as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 320 pixels wide by 320 pixels high
    lazy var out_p6: CVPixelBuffer = {
        [unowned self] in return self.provider.featureValue(for: "out_p6")!.imageBufferValue
    }()!

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(out_p0: CVPixelBuffer, out_p1: CVPixelBuffer, out_p2: CVPixelBuffer, out_p3: CVPixelBuffer, out_p4: CVPixelBuffer, out_p5: CVPixelBuffer, out_p6: CVPixelBuffer) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["out_p0" : MLFeatureValue(pixelBuffer: out_p0), "out_p1" : MLFeatureValue(pixelBuffer: out_p1), "out_p2" : MLFeatureValue(pixelBuffer: out_p2), "out_p3" : MLFeatureValue(pixelBuffer: out_p3), "out_p4" : MLFeatureValue(pixelBuffer: out_p4), "out_p5" : MLFeatureValue(pixelBuffer: out_p5), "out_p6" : MLFeatureValue(pixelBuffer: out_p6)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
class U2netp {
    let model: MLModel

    /**
        Construct U2netp instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of U2netp.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `U2netp.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct U2netp instance with explicit path to mlmodelc file
        - parameters:
           - modelURL: the file url of the model

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL) throws {
        try self.init(model: MLModel(contentsOf: modelURL))
    }

    /**
        Construct a model with URL of the .mlmodelc directory and configuration

        - parameters:
           - modelURL: the file url of the model
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }

    /**
        Construct U2netp instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<U2netp, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(U2netp(model: model)))
            }
        }
    }

    /**
        Construct U2netp instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> U2netp {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return U2netp(model: model)
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as U2netpInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as U2netpOutput
    */
    func prediction(input: U2netpInput) throws -> U2netpOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as U2netpInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as U2netpOutput
    */
    func prediction(input: U2netpInput, options: MLPredictionOptions) throws -> U2netpOutput {
        let outFeatures = try model.prediction(from: input, options:options)
        return U2netpOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        - parameters:
            - in_0 as color (kCVPixelFormatType_32BGRA) image buffer, 320 pixels wide by 320 pixels high

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as U2netpOutput
    */
    func prediction(in_0: CVPixelBuffer) throws -> U2netpOutput {
        let input_ = U2netpInput(in_0: in_0)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        - parameters:
           - inputs: the inputs to the prediction as [U2netpInput]
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [U2netpOutput]
    */
    func predictions(inputs: [U2netpInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [U2netpOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [U2netpOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result = U2netpOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
