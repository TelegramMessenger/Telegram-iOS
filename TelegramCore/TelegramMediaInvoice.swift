import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

//flags: Int32, title: String, description: String, photo: Api.WebDocument?, receiptMsgId: Int32?, currency: String, totalAmount: Int64, startParam: String
//messageMediaInvoice#84551347 flags:# shipping_address_requested:flags.1?true test:flags.3?true title:string description:string photo:flags.0?WebDocument receipt_msg_id:flags.2?int currency:string total_amount:long start_param:string = MessageMedia;

public final class TelegramMediaInvoice: Media {
    public var peerIds: [PeerId] = []

    public var id: MediaId? = nil

    public let title:String
    public let description:String
   // public let photo:
    public let receiptMessageId:MessageId?
    public let currency:String
    public let totalAmount:Int64
    public let startParam:String
    public let photo:TelegramMediaWebFile?
    
    public init(title:String, description:String, photo:TelegramMediaWebFile?, receiptMessageId:MessageId?, currency:String, totalAmount:Int64, startParam:String) {
        self.title = title
        self.description = description
        self.photo = photo
        self.receiptMessageId = receiptMessageId
        self.currency = currency
        self.totalAmount = totalAmount
        self.startParam = startParam
    }
    
    
    public init(decoder: Decoder) {
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.description = decoder.decodeStringForKey("d", orElse: "")
        self.currency = decoder.decodeStringForKey("c", orElse: "")
        self.totalAmount = decoder.decodeInt64ForKey("ta", orElse: 0)
        self.startParam = decoder.decodeStringForKey("sp", orElse: "")
        self.photo = decoder.decodeObjectForKey("p") as? TelegramMediaWebFile
        
        if let receiptMessageIdPeerId = decoder.decodeOptionalInt64ForKey("r.p") as Int64?, let receiptMessageIdNamespace = decoder.decodeOptionalInt32ForKey("r.n") as Int32?, let receiptMessageIdId = decoder.decodeOptionalInt32ForKey("r.i") as Int32? {
            self.receiptMessageId = MessageId(peerId: PeerId(receiptMessageIdPeerId), namespace: receiptMessageIdNamespace, id: receiptMessageIdId)
        } else {
            self.receiptMessageId = nil
        }
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.description, forKey: "d")
        encoder.encodeString(self.currency, forKey: "nc")
        encoder.encodeInt64(self.totalAmount, forKey: "ta")
        encoder.encodeString(self.startParam, forKey: "sp")

        if let photo = photo {
            encoder.encodeObject(photo, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }

        if let receiptMessageId = self.receiptMessageId {
            encoder.encodeInt64(receiptMessageId.peerId.toInt64(), forKey: "r.p")
            encoder.encodeInt32(receiptMessageId.namespace, forKey: "r.n")
            encoder.encodeInt32(receiptMessageId.id, forKey: "r.i")
        } else {
            encoder.encodeNil(forKey: "r.p")
            encoder.encodeNil(forKey: "r.n")
            encoder.encodeNil(forKey: "r.i")
        }
    }
    
    public func isEqual(_ other: Media) -> Bool {
        guard let other = other as? TelegramMediaInvoice else {
            return false
        }
        
        if self.title != other.title {
            return false
        }
        
        if self.description != other.description {
            return false
        }
        
        if self.currency != other.currency {
            return false
        }
        
        if self.totalAmount != other.totalAmount {
            return false
        }
        
        if self.startParam != other.startParam {
            return false
        }
        
        if self.receiptMessageId != other.receiptMessageId {
            return false
        }
        
        return true
    }
    
}
