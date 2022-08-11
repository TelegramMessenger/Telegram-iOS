public protocol EcommpaySignatureProvider {
    func getSignature(params: String, completion: @escaping (Result<String, Error>) -> ())
}
