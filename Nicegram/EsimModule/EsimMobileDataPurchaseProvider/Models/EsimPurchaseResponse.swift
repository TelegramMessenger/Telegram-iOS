import EsimDTO

public struct EsimPurchaseResponse {
    public let esim: UserEsimDTO
    
    public init(esim: UserEsimDTO) {
        self.esim = esim
    }
}
