import Foundation
import AppBundle
import StringPluralization

private let fallbackDict: [String: String] = {
    guard let mainPath = getAppBundle().path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: mainPath) else {
        return [:]
    }
    guard let path = bundle.path(forResource: "Localizable", ofType: "strings") else {
        return [:]
    }
    guard let dict = NSDictionary(contentsOf: URL(fileURLWithPath: path)) as? [String: String] else {
        return [:]
    }
    return dict
}()

private extension PluralizationForm {
    var canonicalSuffix: String {
        switch self {
            case .zero:
                return "_0"
            case .one:
                return "_1"
            case .two:
                return "_2"
            case .few:
                return "_3_10"
            case .many:
                return "_many"
            case .other:
                return "_any"
        }
    }
}

public final class WalletStringsComponent {
    public let languageCode: String
    public let localizedName: String
    public let pluralizationRulesCode: String?
    public let dict: [String: String]
    
    public init(languageCode: String, localizedName: String, pluralizationRulesCode: String?, dict: [String: String]) {
        self.languageCode = languageCode
        self.localizedName = localizedName
        self.pluralizationRulesCode = pluralizationRulesCode
        self.dict = dict
    }
}
        
private func getValue(_ primaryComponent: WalletStringsComponent, _ secondaryComponent: WalletStringsComponent?, _ key: String) -> String {
    if let value = primaryComponent.dict[key] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[key] {
        return value
    } else if let value = fallbackDict[key] {
        return value
    } else {
        return key
    }
}

private func getValueWithForm(_ primaryComponent: WalletStringsComponent, _ secondaryComponent: WalletStringsComponent?, _ key: String, _ form: PluralizationForm) -> String {
    let builtKey = key + form.canonicalSuffix
    if let value = primaryComponent.dict[builtKey] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[builtKey] {
        return value
    } else if let value = fallbackDict[builtKey] {
        return value
    }
    return key
}
        
private let argumentRegex = try! NSRegularExpression(pattern: "%(((\\d+)\\$)?)([@df])", options: [])
private func extractArgumentRanges(_ value: String) -> [(Int, NSRange)] {
    var result: [(Int, NSRange)] = []
    let string = value as NSString
    let matches = argumentRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    var index = 0
    for match in matches {
        var currentIndex = index
        if match.range(at: 3).location != NSNotFound {
            currentIndex = Int(string.substring(with: match.range(at: 3)))! - 1
        }
        result.append((currentIndex, match.range(at: 0)))
        index += 1
    }
    result.sort(by: { $0.1.location < $1.1.location })
    return result
}
    
public func formatWithArgumentRanges(_ value: String, _ ranges: [(Int, NSRange)], _ arguments: [String]) -> (String, [(Int, NSRange)]) {
    let string = value as NSString
    
    var resultingRanges: [(Int, NSRange)] = []

    var currentLocation = 0

    let result = NSMutableString()
    for (index, range) in ranges {
        if currentLocation < range.location {
            result.append(string.substring(with: NSRange(location: currentLocation, length: range.location - currentLocation)))
        }
        resultingRanges.append((index, NSRange(location: result.length, length: (arguments[index] as NSString).length)))
        result.append(arguments[index])
        currentLocation = range.location + range.length
    }
    if currentLocation != string.length {
        result.append(string.substring(with: NSRange(location: currentLocation, length: string.length - currentLocation)))
    }
    return (result as String, resultingRanges)
}
        
private final class DataReader {
    private let data: Data
    private var ptr: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    func readInt32() -> Int32 {
        assert(self.ptr + 4 <= self.data.count)
        let result = self.data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Int32 in
            var value: Int32 = 0
            memcpy(&value, bytes.advanced(by: self.ptr), 4)
            return value
        }
        self.ptr += 4
        return result
    }

    func readString() -> String {
        let length = Int(self.readInt32())
        assert(self.ptr + length <= self.data.count)
        let value = String(data: self.data.subdata(in: self.ptr ..< self.ptr + length), encoding: .utf8)!
        self.ptr += length
        return value
    }
}
        
private func loadMapping() -> ([Int], [String], [Int], [Int], [String]) {
    guard let filePath = getAppBundle().path(forResource: "WalletStrings", ofType: "mapping") else {
        fatalError()
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        fatalError()
    }

    let reader = DataReader(data)

    let idCount = Int(reader.readInt32())
    var sIdList: [Int] = []
    var sKeyList: [String] = []
    var sArgIdList: [Int] = []
    for _ in 0 ..< idCount {
        let id = Int(reader.readInt32())
        sIdList.append(id)
        sKeyList.append(reader.readString())
        if reader.readInt32() != 0 {
            sArgIdList.append(id)
        }
    }

    let pCount = Int(reader.readInt32())
    var pIdList: [Int] = []
    var pKeyList: [String] = []
    for _ in 0 ..< Int(pCount) {
        pIdList.append(Int(reader.readInt32()))
        pKeyList.append(reader.readString())
    }

    return (sIdList, sKeyList, sArgIdList, pIdList, pKeyList)
}

private let keyMapping: ([Int], [String], [Int], [Int], [String]) = loadMapping()
        
public final class WalletStrings: Equatable {
    public let lc: UInt32
    
    public let primaryComponent: WalletStringsComponent
    public let secondaryComponent: WalletStringsComponent?
    public let baseLanguageCode: String
    public let groupingSeparator: String
        
    private let _s: [Int: String]
    private let _r: [Int: [(Int, NSRange)]]
    private let _ps: [Int: String]
    public var Wallet_Updated_JustNow: String { return self._s[0]! }
    public var Wallet_WordCheck_IncorrectText: String { return self._s[1]! }
    public var Wallet_Month_ShortNovember: String { return self._s[2]! }
    public var Wallet_Configuration_BlockchainIdPlaceholder: String { return self._s[3]! }
    public var Wallet_Info_Send: String { return self._s[4]! }
    public var Wallet_TransactionInfo_SendGrams: String { return self._s[5]! }
    public func Wallet_Info_TransactionBlockchainFee(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[6]!, self._r[6]!, [_0])
    }
    public var Wallet_Sent_Title: String { return self._s[7]! }
    public var Wallet_Receive_ShareUrlInfo: String { return self._s[8]! }
    public var Wallet_RestoreFailed_Title: String { return self._s[9]! }
    public var Wallet_TransactionInfo_CopyAddress: String { return self._s[11]! }
    public var Wallet_Settings_BackupWallet: String { return self._s[12]! }
    public var Wallet_Send_NetworkErrorTitle: String { return self._s[13]! }
    public var Wallet_Month_ShortJune: String { return self._s[14]! }
    public var Wallet_TransactionInfo_StorageFeeInfo: String { return self._s[15]! }
    public var Wallet_Created_Title: String { return self._s[16]! }
    public func Wallet_Configuration_ApplyErrorTextURLUnreachable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[17]!, self._r[17]!, [_0])
    }
    public var Wallet_Send_SyncInProgress: String { return self._s[18]! }
    public var Wallet_Info_YourBalance: String { return self._s[19]! }
    public var Wallet_Configuration_ApplyErrorTextURLInvalidData: String { return self._s[20]! }
    public var Wallet_TransactionInfo_CommentHeader: String { return self._s[21]! }
    public var Wallet_TransactionInfo_OtherFeeHeader: String { return self._s[22]! }
    public func Wallet_Time_PreciseDate_m3(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[23]!, self._r[23]!, [_1, _2, _3])
    }
    public var Wallet_Settings_ConfigurationInfo: String { return self._s[24]! }
    public var Wallet_WordImport_IncorrectText: String { return self._s[25]! }
    public var Wallet_Month_GenJanuary: String { return self._s[26]! }
    public var Wallet_Send_OwnAddressAlertTitle: String { return self._s[27]! }
    public var Wallet_Receive_ShareAddress: String { return self._s[28]! }
    public var Wallet_WordImport_Title: String { return self._s[29]! }
    public var Wallet_TransactionInfo_Title: String { return self._s[30]! }
    public var Wallet_Words_NotDoneText: String { return self._s[32]! }
    public var Wallet_RestoreFailed_EnterWords: String { return self._s[33]! }
    public var Wallet_WordImport_Text: String { return self._s[34]! }
    public var Wallet_RestoreFailed_Text: String { return self._s[36]! }
    public var Wallet_TransactionInfo_NoAddress: String { return self._s[37]! }
    public var Wallet_Navigation_Back: String { return self._s[38]! }
    public var Wallet_Intro_Terms: String { return self._s[39]! }
    public func Wallet_Send_Balance(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[40]!, self._r[40]!, [_0])
    }
    public func Wallet_Time_PreciseDate_m8(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[41]!, self._r[41]!, [_1, _2, _3])
    }
    public var Wallet_TransactionInfo_AddressCopied: String { return self._s[42]! }
    public func Wallet_Info_TransactionDateHeaderYear(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[43]!, self._r[43]!, [_1, _2, _3])
    }
    public var Wallet_Send_NetworkErrorText: String { return self._s[44]! }
    public var Wallet_VoiceOver_Editing_ClearText: String { return self._s[45]! }
    public var Wallet_Intro_ImportExisting: String { return self._s[46]! }
    public var Wallet_Receive_CommentInfo: String { return self._s[47]! }
    public var Wallet_WordCheck_Continue: String { return self._s[48]! }
    public var Wallet_Send_EncryptComment: String { return self._s[49]! }
    public var Wallet_Receive_InvoiceUrlCopied: String { return self._s[50]! }
    public var Wallet_Completed_Text: String { return self._s[51]! }
    public var Wallet_WordCheck_IncorrectHeader: String { return self._s[53]! }
    public var Wallet_Configuration_SourceHeader: String { return self._s[54]! }
    public var Wallet_TransactionInfo_StorageFeeInfoUrl: String { return self._s[55]! }
    public var Wallet_Receive_Title: String { return self._s[56]! }
    public var Wallet_Info_WalletCreated: String { return self._s[57]! }
    public var Wallet_Navigation_Cancel: String { return self._s[58]! }
    public var Wallet_CreateInvoice_Title: String { return self._s[59]! }
    public func Wallet_WordCheck_Text(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[60]!, self._r[60]!, [_1, _2, _3])
    }
    public var Wallet_TransactionInfo_SenderHeader: String { return self._s[61]! }
    public func Wallet_Time_PreciseDate_m4(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[62]!, self._r[62]!, [_1, _2, _3])
    }
    public var Wallet_Month_GenAugust: String { return self._s[63]! }
    public var Wallet_Info_UnknownTransaction: String { return self._s[64]! }
    public var Wallet_Receive_CreateInvoice: String { return self._s[65]! }
    public var Wallet_Month_GenSeptember: String { return self._s[66]! }
    public var Wallet_Month_GenJuly: String { return self._s[67]! }
    public var Wallet_Receive_AddressHeader: String { return self._s[68]! }
    public var Wallet_Send_AmountText: String { return self._s[69]! }
    public var Wallet_SecureStorageNotAvailable_Text: String { return self._s[70]! }
    public func Wallet_Time_PreciseDate_m12(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[71]!, self._r[71]!, [_1, _2, _3])
    }
    public func Wallet_Updated_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[72]!, self._r[72]!, [_0])
    }
    public var Wallet_Configuration_Title: String { return self._s[74]! }
    public var Wallet_Configuration_BlockchainIdHeader: String { return self._s[75]! }
    public var Wallet_Words_Title: String { return self._s[76]! }
    public var Wallet_Month_ShortMay: String { return self._s[77]! }
    public var Wallet_WordCheck_Title: String { return self._s[78]! }
    public var Wallet_Words_NotDoneResponse: String { return self._s[79]! }
    public var Wallet_Configuration_SourceURL: String { return self._s[80]! }
    public var Wallet_Send_ErrorNotEnoughFundsText: String { return self._s[81]! }
    public var Wallet_Receive_CreateInvoiceInfo: String { return self._s[82]! }
    public func Wallet_Time_PreciseDate_m9(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[83]!, self._r[83]!, [_1, _2, _3])
    }
    public var Wallet_Info_Address: String { return self._s[84]! }
    public var Wallet_Intro_CreateWallet: String { return self._s[85]! }
    public var Wallet_SecureStorageChanged_PasscodeText: String { return self._s[86]! }
    public func Wallet_SecureStorageReset_BiometryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[87]!, self._r[87]!, [_0])
    }
    public var Wallet_Send_SendAnyway: String { return self._s[88]! }
    public var Wallet_UnknownError: String { return self._s[89]! }
    public var Wallet_Configuration_ApplyErrorTextURLInvalid: String { return self._s[90]! }
    public var Wallet_SecureStorageChanged_ImportWallet: String { return self._s[91]! }
    public var Wallet_SecureStorageChanged_CreateWallet: String { return self._s[93]! }
    public var Wallet_Configuration_SourceInfo: String { return self._s[94]! }
    public var Wallet_Words_NotDoneOk: String { return self._s[95]! }
    public var Wallet_Intro_Title: String { return self._s[96]! }
    public var Wallet_Info_Receive: String { return self._s[97]! }
    public var Wallet_Completed_ViewWallet: String { return self._s[98]! }
    public var Wallet_Month_ShortJuly: String { return self._s[99]! }
    public var Wallet_Month_ShortApril: String { return self._s[100]! }
    public func Wallet_Info_TransactionDateHeader(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[101]!, self._r[101]!, [_1, _2])
    }
    public var Wallet_Receive_ShareInvoiceUrl: String { return self._s[102]! }
    public func Wallet_Time_PreciseDate_m10(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[103]!, self._r[103]!, [_1, _2, _3])
    }
    public var Wallet_Send_UninitializedText: String { return self._s[105]! }
    public func Wallet_Sent_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[106]!, self._r[106]!, [_0])
    }
    public var Wallet_Month_GenNovember: String { return self._s[107]! }
    public func Wallet_Time_PreciseDate_m5(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[108]!, self._r[108]!, [_1, _2, _3])
    }
    public var Wallet_Month_GenApril: String { return self._s[109]! }
    public var Wallet_Month_ShortMarch: String { return self._s[110]! }
    public var Wallet_Month_GenFebruary: String { return self._s[111]! }
    public var Wallet_Qr_ScanCode: String { return self._s[112]! }
    public var Wallet_Receive_AddressCopied: String { return self._s[113]! }
    public var Wallet_Send_UninitializedTitle: String { return self._s[114]! }
    public var Wallet_AccessDenied_Title: String { return self._s[115]! }
    public var Wallet_AccessDenied_Settings: String { return self._s[116]! }
    public var Wallet_Send_Send: String { return self._s[117]! }
    public var Wallet_Info_RefreshErrorTitle: String { return self._s[118]! }
    public var Wallet_Month_GenJune: String { return self._s[119]! }
    public var Wallet_Send_AddressHeader: String { return self._s[120]! }
    public var Wallet_SecureStorageReset_BiometryTouchId: String { return self._s[121]! }
    public var Wallet_Send_Confirmation: String { return self._s[122]! }
    public var Wallet_Completed_Title: String { return self._s[123]! }
    public var Wallet_Alert_OK: String { return self._s[124]! }
    public var Wallet_Settings_DeleteWallet: String { return self._s[125]! }
    public var Wallet_SecureStorageReset_PasscodeText: String { return self._s[126]! }
    public var Wallet_Month_ShortSeptember: String { return self._s[127]! }
    public var Wallet_Info_TransactionTo: String { return self._s[128]! }
    public var Wallet_Send_ConfirmationConfirm: String { return self._s[129]! }
    public var Wallet_TransactionInfo_OtherFeeInfo: String { return self._s[130]! }
    public var Wallet_Receive_AmountText: String { return self._s[131]! }
    public var Wallet_Receive_CopyAddress: String { return self._s[132]! }
    public var Wallet_Intro_Text: String { return self._s[134]! }
    public var Wallet_Configuration_Apply: String { return self._s[135]! }
    public func Wallet_SecureStorageChanged_BiometryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[136]!, self._r[136]!, [_0])
    }
    public func Wallet_Time_PreciseDate_m1(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[137]!, self._r[137]!, [_1, _2, _3])
    }
    public var Wallet_RestoreFailed_CreateWallet: String { return self._s[138]! }
    public var Wallet_Weekday_Yesterday: String { return self._s[139]! }
    public var Wallet_Receive_AmountHeader: String { return self._s[140]! }
    public var Wallet_TransactionInfo_OtherFeeInfoUrl: String { return self._s[141]! }
    public var Wallet_Month_ShortFebruary: String { return self._s[142]! }
    public var Wallet_Configuration_SourceJSON: String { return self._s[143]! }
    public var Wallet_Alert_Cancel: String { return self._s[144]! }
    public var Wallet_TransactionInfo_RecipientHeader: String { return self._s[145]! }
    public var Wallet_Configuration_ApplyErrorTextJSONInvalidData: String { return self._s[146]! }
    public var Wallet_Info_TransactionFrom: String { return self._s[147]! }
    public var Wallet_Send_ErrorDecryptionFailed: String { return self._s[148]! }
    public var Wallet_Send_OwnAddressAlertText: String { return self._s[149]! }
    public var Wallet_Words_NotDoneTitle: String { return self._s[150]! }
    public var Wallet_Month_ShortOctober: String { return self._s[151]! }
    public var Wallet_Month_GenMay: String { return self._s[152]! }
    public var Wallet_Intro_CreateErrorTitle: String { return self._s[153]! }
    public var Wallet_SecureStorageReset_BiometryFaceId: String { return self._s[154]! }
    public var Wallet_Month_ShortJanuary: String { return self._s[155]! }
    public var Wallet_Month_GenMarch: String { return self._s[156]! }
    public var Wallet_AccessDenied_Camera: String { return self._s[157]! }
    public var Wallet_Sending_Text: String { return self._s[158]! }
    public var Wallet_Month_GenOctober: String { return self._s[159]! }
    public var Wallet_Receive_CopyInvoiceUrl: String { return self._s[160]! }
    public var Wallet_ContextMenuCopy: String { return self._s[161]! }
    public func Wallet_Time_PreciseDate_m6(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[162]!, self._r[162]!, [_1, _2, _3])
    }
    public var Wallet_Info_Updating: String { return self._s[164]! }
    public var Wallet_Created_ExportErrorTitle: String { return self._s[165]! }
    public var Wallet_SecureStorageNotAvailable_Title: String { return self._s[166]! }
    public var Wallet_Sending_Title: String { return self._s[167]! }
    public var Wallet_Navigation_Done: String { return self._s[168]! }
    public var Wallet_Configuration_BlockchainIdInfo: String { return self._s[169]! }
    public var Wallet_Configuration_BlockchainNameChangedTitle: String { return self._s[170]! }
    public var Wallet_Settings_Title: String { return self._s[171]! }
    public func Wallet_Receive_ShareInvoiceUrlInfo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[172]!, self._r[172]!, [_0])
    }
    public var Wallet_Info_RefreshErrorNetworkText: String { return self._s[173]! }
    public var Wallet_Weekday_Today: String { return self._s[175]! }
    public var Wallet_Month_ShortDecember: String { return self._s[176]! }
    public var Wallet_Words_Text: String { return self._s[177]! }
    public var Wallet_Configuration_BlockchainNameChangedProceed: String { return self._s[178]! }
    public var Wallet_WordCheck_ViewWords: String { return self._s[179]! }
    public var Wallet_Send_AddressInfo: String { return self._s[180]! }
    public func Wallet_Updated_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[181]!, self._r[181]!, [_0])
    }
    public var Wallet_Intro_NotNow: String { return self._s[182]! }
    public var Wallet_Send_OwnAddressAlertProceed: String { return self._s[183]! }
    public var Wallet_Navigation_Close: String { return self._s[184]! }
    public var Wallet_Month_GenDecember: String { return self._s[186]! }
    public var Wallet_Send_ErrorNotEnoughFundsTitle: String { return self._s[187]! }
    public var Wallet_WordImport_IncorrectTitle: String { return self._s[188]! }
    public var Wallet_Send_AddressText: String { return self._s[189]! }
    public var Wallet_Receive_AmountInfo: String { return self._s[190]! }
    public func Wallet_Time_PreciseDate_m2(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[191]!, self._r[191]!, [_1, _2, _3])
    }
    public var Wallet_Month_ShortAugust: String { return self._s[192]! }
    public var Wallet_Qr_Title: String { return self._s[193]! }
    public var Wallet_Settings_Configuration: String { return self._s[194]! }
    public var Wallet_WordCheck_TryAgain: String { return self._s[195]! }
    public var Wallet_Info_TransactionPendingHeader: String { return self._s[196]! }
    public var Wallet_Receive_InvoiceUrlHeader: String { return self._s[197]! }
    public var Wallet_Configuration_ApplyErrorTitle: String { return self._s[198]! }
    public var Wallet_Send_TransactionInProgress: String { return self._s[199]! }
    public var Wallet_Created_Text: String { return self._s[200]! }
    public var Wallet_Created_Proceed: String { return self._s[201]! }
    public var Wallet_Words_Done: String { return self._s[202]! }
    public var Wallet_WordImport_Continue: String { return self._s[203]! }
    public var Wallet_TransactionInfo_StorageFeeHeader: String { return self._s[204]! }
    public var Wallet_WordImport_CanNotRemember: String { return self._s[205]! }
    public func Wallet_Time_PreciseDate_m11(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[206]!, self._r[206]!, [_1, _2, _3])
    }
    public func Wallet_Send_ConfirmationText(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[207]!, self._r[207]!, [_1, _2, _3])
    }
    public var Wallet_Created_ExportErrorText: String { return self._s[209]! }
    public func Wallet_Updated_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[210]!, self._r[210]!, [_0])
    }
    public var Wallet_Settings_DeleteWalletInfo: String { return self._s[211]! }
    public var Wallet_Intro_CreateErrorText: String { return self._s[212]! }
    public var Wallet_Sent_ViewWallet: String { return self._s[213]! }
    public var Wallet_Send_ErrorInvalidAddress: String { return self._s[214]! }
    public var Wallet_Configuration_BlockchainNameChangedText: String { return self._s[215]! }
    public func Wallet_Time_PreciseDate_m7(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[216]!, self._r[216]!, [_1, _2, _3])
    }
    public var Wallet_Send_Title: String { return self._s[217]! }
    public var Wallet_Info_RefreshErrorText: String { return self._s[218]! }
    public var Wallet_SecureStorageReset_Title: String { return self._s[219]! }
    public var Wallet_Receive_CommentHeader: String { return self._s[220]! }
    public var Wallet_Info_ReceiveGrams: String { return self._s[221]! }
    public func Wallet_Updated_MinutesAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = walletStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[0 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Wallet_Updated_HoursAgo(_ value: Int32) -> String {
        let form = getPluralizationForm(self.lc, value)
        let stringValue = walletStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[1 * 6 + Int(form.rawValue)]!, stringValue)
    }
        
    public init(primaryComponent: WalletStringsComponent, secondaryComponent: WalletStringsComponent?, groupingSeparator: String) {
        self.primaryComponent = primaryComponent
        self.secondaryComponent = secondaryComponent
        self.groupingSeparator = groupingSeparator
        
        self.baseLanguageCode = secondaryComponent?.languageCode ?? primaryComponent.languageCode
        
        let languageCode = primaryComponent.pluralizationRulesCode ?? primaryComponent.languageCode
        var rawCode = languageCode as NSString
        var range = rawCode.range(of: "_")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        range = rawCode.range(of: "-")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        rawCode = rawCode.lowercased as NSString
        var lc: UInt32 = 0
        for i in 0 ..< rawCode.length {
            lc = (lc << 8) + UInt32(rawCode.character(at: i))
        }
        self.lc = lc

        var _s: [Int: String] = [:]
        var _r: [Int: [(Int, NSRange)]] = [:]
        
        let loadedKeyMapping = keyMapping
        
        let sIdList: [Int] = loadedKeyMapping.0
        let sKeyList: [String] = loadedKeyMapping.1
        let sArgIdList: [Int] = loadedKeyMapping.2
        for i in 0 ..< sIdList.count {
            _s[sIdList[i]] = getValue(primaryComponent, secondaryComponent, sKeyList[i])
        }
        for i in 0 ..< sArgIdList.count {
            _r[sArgIdList[i]] = extractArgumentRanges(_s[sArgIdList[i]]!)
        }
        self._s = _s
        self._r = _r

        var _ps: [Int: String] = [:]
        let pIdList: [Int] = loadedKeyMapping.3
        let pKeyList: [String] = loadedKeyMapping.4
        for i in 0 ..< pIdList.count {
            for form in 0 ..< 6 {
                _ps[pIdList[i] * 6 + form] = getValueWithForm(primaryComponent, secondaryComponent, pKeyList[i], PluralizationForm(rawValue: Int32(form))!)
            }
        }
        self._ps = _ps
    }
    
    public static func ==(lhs: WalletStrings, rhs: WalletStrings) -> Bool {
        return lhs === rhs
    }
}

