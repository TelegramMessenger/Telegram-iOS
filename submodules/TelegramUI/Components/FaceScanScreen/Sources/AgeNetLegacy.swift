//
// AgeNetLegacy.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class AgeNetLegacyInput : MLFeatureProvider {

    /// input as color (kCVPixelFormatType_32BGRA) image buffer, 112 pixels wide by 112 pixels high
    var input: CVPixelBuffer

    var featureNames: Set<String> { ["input"] }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "input" {
            return MLFeatureValue(pixelBuffer: input)
        }
        return nil
    }

    init(input: CVPixelBuffer) {
        self.input = input
    }

    convenience init(inputWith input: CGImage) throws {
        self.init(input: try MLFeatureValue(cgImage: input, pixelsWide: 112, pixelsHigh: 112, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!)
    }

    convenience init(inputAt input: URL) throws {
        self.init(input: try MLFeatureValue(imageAt: input, pixelsWide: 112, pixelsHigh: 112, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!)
    }

    func setInput(with input: CGImage) throws  {
        self.input = try MLFeatureValue(cgImage: input, pixelsWide: 112, pixelsHigh: 112, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

    func setInput(with input: URL) throws  {
        self.input = try MLFeatureValue(imageAt: input, pixelsWide: 112, pixelsHigh: 112, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

}


/// Model Prediction Output Type
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class AgeNetLegacyOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// Identity as multidimensional array of floats
    var Identity: MLMultiArray {
        provider.featureValue(for: "Identity")!.multiArrayValue!
    }

    /// Identity as multidimensional array of floats
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    var IdentityShapedArray: MLShapedArray<Float> {
        MLShapedArray<Float>(Identity)
    }

    var featureNames: Set<String> {
        provider.featureNames
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        provider.featureValue(for: featureName)
    }

    init(Identity: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["Identity" : MLFeatureValue(multiArray: Identity)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class AgeNetLegacy {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: "AgeNetLegacy", withExtension:"mlmodelc")!
    }

    /**
        Construct AgeNetLegacy instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of AgeNetLegacy.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `AgeNetLegacy.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct AgeNetLegacy instance by automatically loading the model from the app's bundle.
    */
    @available(*, deprecated, message: "Use init(configuration:) instead and handle errors appropriately.")
    convenience init() {
        try! self.init(contentsOf: type(of:self).urlOfModelInThisBundle)
    }

    /**
        Construct a model with configuration

        - parameters:
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(configuration: MLModelConfiguration) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct AgeNetLegacy instance with explicit path to mlmodelc file
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
        Construct AgeNetLegacy instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, visionOS 1.0, *)
    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<AgeNetLegacy, Error>) -> Void) {
        load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
    }

    /**
        Construct AgeNetLegacy instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
    */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    class func load(configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> AgeNetLegacy {
        try await load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct AgeNetLegacy instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, visionOS 1.0, *)
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<AgeNetLegacy, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(AgeNetLegacy(model: model)))
            }
        }
    }

    /**
        Construct AgeNetLegacy instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> AgeNetLegacy {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return AgeNetLegacy(model: model)
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as AgeNetLegacyInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as AgeNetLegacyOutput
    */
    func prediction(input: AgeNetLegacyInput) throws -> AgeNetLegacyOutput {
        try prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as AgeNetLegacyInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as AgeNetLegacyOutput
    */
    func prediction(input: AgeNetLegacyInput, options: MLPredictionOptions) throws -> AgeNetLegacyOutput {
        let outFeatures = try model.prediction(from: input, options: options)
        return AgeNetLegacyOutput(features: outFeatures)
    }

    /**
        Make an asynchronous prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as AgeNetLegacyInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as AgeNetLegacyOutput
    */
    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    func prediction(input: AgeNetLegacyInput, options: MLPredictionOptions = MLPredictionOptions()) async throws -> AgeNetLegacyOutput {
        let outFeatures = try await model.prediction(from: input, options: options)
        return AgeNetLegacyOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        It uses the default function if the model has multiple functions.

        - parameters:
            - input: color (kCVPixelFormatType_32BGRA) image buffer, 112 pixels wide by 112 pixels high

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as AgeNetLegacyOutput
    */
    func prediction(input: CVPixelBuffer) throws -> AgeNetLegacyOutput {
        let input_ = AgeNetLegacyInput(input: input)
        return try prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - inputs: the inputs to the prediction as [AgeNetLegacyInput]
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [AgeNetLegacyOutput]
    */
    func predictions(inputs: [AgeNetLegacyInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [AgeNetLegacyOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [AgeNetLegacyOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  AgeNetLegacyOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
