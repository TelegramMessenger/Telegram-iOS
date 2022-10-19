import EsimPayments

public protocol EcommpayEsimSignatureProvider {
    func getSignature(signatureParams: String, regionId: Int, bundleId: Int, icc: String?, completion: @escaping (Result<String, EcommpaySignatureError>) -> ())
}
