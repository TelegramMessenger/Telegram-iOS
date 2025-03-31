int ? = Int;
long ? = Long;
double ? = Double;
string ? = String;

bytes = Bytes;

boolFalse = Bool;
boolTrue = Bool;

true#3fedd339 = True;

vector {t:Type} # [ t ] = Vector t;

decryptedMessage8#1f814f1f random_id:long random_bytes:bytes message:string media:DecryptedMessageMedia = DecryptedMessage;
decryptedMessageService8#aa48327d random_id:long random_bytes:bytes action:DecryptedMessageAction = DecryptedMessage;
decryptedMessageMediaEmpty#89f5c4a = DecryptedMessageMedia;
decryptedMessageMediaPhoto8#32798a8c thumb:bytes thumb_w:int thumb_h:int w:int h:int size:int key:bytes iv:bytes = DecryptedMessageMedia;
decryptedMessageMediaVideo8#4cee6ef3 thumb:bytes thumb_w:int thumb_h:int duration:int w:int h:int size:int key:bytes iv:bytes = DecryptedMessageMedia;
decryptedMessageMediaGeoPoint#35480a59 lat:double long:double = DecryptedMessageMedia;
decryptedMessageMediaContact#588a0a97 phone_number:string first_name:string last_name:string user_id:int = DecryptedMessageMedia;
decryptedMessageActionSetMessageTTL#a1733aec ttl_seconds:int = DecryptedMessageAction;
decryptedMessageMediaDocument8#b095434b thumb:bytes thumb_w:int thumb_h:int file_name:string mime_type:string size:int key:bytes iv:bytes = DecryptedMessageMedia;
decryptedMessageMediaAudio8#6080758f duration:int size:int key:bytes iv:bytes = DecryptedMessageMedia;
decryptedMessageActionReadMessages#c4f40be random_ids:Vector<long> = DecryptedMessageAction;
decryptedMessageActionDeleteMessages#65614304 random_ids:Vector<long> = DecryptedMessageAction;
decryptedMessageActionScreenshotMessages#8ac1f475 random_ids:Vector<long> = DecryptedMessageAction;
decryptedMessageActionFlushHistory#6719e45c = DecryptedMessageAction;

// layer 23

decryptedMessage23#204d3878 random_id:long ttl:int message:string media:DecryptedMessageMedia = DecryptedMessage;
decryptedMessageService#73164160 random_id:long action:DecryptedMessageAction = DecryptedMessage;
decryptedMessageMediaVideo23#524a415d thumb:bytes thumb_w:int thumb_h:int duration:int mime_type:string w:int h:int size:int key:bytes iv:bytes = DecryptedMessageMedia;
decryptedMessageMediaAudio#57e0a9cb duration:int mime_type:string size:int key:bytes iv:bytes = DecryptedMessageMedia;
decryptedMessageLayer#1be31789 random_bytes:bytes layer:int in_seq_no:int out_seq_no:int message:DecryptedMessage = DecryptedMessageLayer;

sendMessageTypingAction#16bf744e = SendMessageAction;
sendMessageCancelAction#fd5ec8f5 = SendMessageAction;
sendMessageRecordVideoAction#a187d66f = SendMessageAction;
sendMessageUploadVideoAction#92042ff7 = SendMessageAction;
sendMessageRecordAudioAction#d52f73f7 = SendMessageAction;
sendMessageUploadAudioAction#e6ac8a6f = SendMessageAction;
sendMessageUploadPhotoAction#990a3c1a = SendMessageAction;
sendMessageUploadDocumentAction#8faee98e = SendMessageAction;
sendMessageGeoLocationAction#176f8ba1 = SendMessageAction;
sendMessageChooseContactAction#628cbc6f = SendMessageAction;

decryptedMessageActionResend#511110b0 start_seq_no:int end_seq_no:int = DecryptedMessageAction;
decryptedMessageActionNotifyLayer#f3048883 layer:int = DecryptedMessageAction;
decryptedMessageActionTyping#ccb27641 action:SendMessageAction = DecryptedMessageAction;

decryptedMessageActionRequestKey#f3c9611b exchange_id:long g_a:bytes = DecryptedMessageAction;
decryptedMessageActionAcceptKey#6fe1735b exchange_id:long g_b:bytes key_fingerprint:long = DecryptedMessageAction;
decryptedMessageActionAbortKey#dd05ec6b exchange_id:long = DecryptedMessageAction;
decryptedMessageActionCommitKey#ec2e0b9b exchange_id:long key_fingerprint:long = DecryptedMessageAction;
decryptedMessageActionNoop#a82fdd63 = DecryptedMessageAction;

documentAttributeImageSize#6c37c15c w:int h:int = DocumentAttribute;
documentAttributeAnimated#11b58939 = DocumentAttribute;
documentAttributeSticker23#fb0a5727 = DocumentAttribute;
documentAttributeVideo23#5910cccb duration:int w:int h:int = DocumentAttribute;
documentAttributeAudio23#51448e5 duration:int = DocumentAttribute;
documentAttributeFilename#15590068 file_name:string = DocumentAttribute;
photoSizeEmpty#e17e23c type:string = PhotoSize;
photoSize#77bfb61b type:string location:FileLocation w:int h:int size:int = PhotoSize;
photoCachedSize#e9a734fa type:string location:FileLocation w:int h:int bytes:bytes = PhotoSize;
fileLocationUnavailable#7c596b46 volume_id:long local_id:int secret:long = FileLocation;
fileLocation#53d69076 dc_id:int volume_id:long local_id:int secret:long = FileLocation;
decryptedMessageMediaExternalDocument#fa95b0dd id:long access_hash:long date:int mime_type:string size:int thumb:PhotoSize dc_id:int attributes:Vector<DocumentAttribute> = DecryptedMessageMedia;

// layer 45

documentAttributeAudio45#ded218e0 duration:int title:string performer:string = DocumentAttribute;

// layer 46

decryptedMessage46#36b091de flags:# random_id:long ttl:int message:string media:flags.9?DecryptedMessageMedia entities:flags.7?Vector<MessageEntity> via_bot_name:flags.11?string reply_to_random_id:flags.3?long = DecryptedMessage;
decryptedMessageMediaPhoto#f1fa8d78 thumb:bytes thumb_w:int thumb_h:int w:int h:int size:int key:bytes iv:bytes caption:string = DecryptedMessageMedia;
decryptedMessageMediaVideo#970c8c0e thumb:bytes thumb_w:int thumb_h:int duration:int mime_type:string w:int h:int size:int key:bytes iv:bytes caption:string = DecryptedMessageMedia;
decryptedMessageMediaDocument46#7afe8ae2 thumb:bytes thumb_w:int thumb_h:int mime_type:string size:int key:bytes iv:bytes attributes:Vector<DocumentAttribute> caption:string = DecryptedMessageMedia;
documentAttributeSticker#3a556302 alt:string stickerset:InputStickerSet = DocumentAttribute;
documentAttributeAudio#9852f9c6 flags:# voice:flags.10?true duration:int title:flags.0?string performer:flags.1?string waveform:flags.2?bytes = DocumentAttribute;
messageEntityUnknown#bb92ba95 offset:int length:int = MessageEntity;
messageEntityMention#fa04579d offset:int length:int = MessageEntity;
messageEntityHashtag#6f635b0d offset:int length:int = MessageEntity;
messageEntityBotCommand#6cef8ac7 offset:int length:int = MessageEntity;
messageEntityUrl#6ed02538 offset:int length:int = MessageEntity;
messageEntityEmail#64e475c2 offset:int length:int = MessageEntity;
messageEntityBold#bd610bc9 offset:int length:int = MessageEntity;
messageEntityItalic#826f8b60 offset:int length:int = MessageEntity;
messageEntityCode#28a20571 offset:int length:int = MessageEntity;
messageEntityPre#73924be0 offset:int length:int language:string = MessageEntity;
messageEntityTextUrl#76a6d327 offset:int length:int url:string = MessageEntity;
messageEntityMentionName#352dca58 offset:int length:int user_id:int = MessageEntity;
messageEntityPhone#9b69e34b offset:int length:int = MessageEntity;
messageEntityCashtag#4c4e743f offset:int length:int = MessageEntity;
messageEntityBankCard#761e6af4 offset:int length:int = MessageEntity;
inputStickerSetShortName#861cc8a0 short_name:string = InputStickerSet;
inputStickerSetEmpty#ffb62b95 = InputStickerSet;
decryptedMessageMediaVenue#8a0df56f lat:double long:double title:string address:string provider:string venue_id:string = DecryptedMessageMedia;
decryptedMessageMediaWebPage#e50511d8 url:string = DecryptedMessageMedia;

// layer 66

sendMessageRecordRoundAction#88f27fbc = SendMessageAction;
sendMessageUploadRoundAction#bb718624 = SendMessageAction;
documentAttributeVideo#ef02ce6 flags:# round_message:flags.0?true duration:int w:int h:int = DocumentAttribute;

// layer 73

decryptedMessage#91cc4674 flags:# silent:flags.5?true random_id:long ttl:int message:string media:flags.9?DecryptedMessageMedia entities:flags.7?Vector<MessageEntity> via_bot_name:flags.11?string reply_to_random_id:flags.3?long grouped_id:flags.17?long = DecryptedMessage;

// layer 101

messageEntityUnderline#9c4e7e8b offset:int length:int = MessageEntity;
messageEntityStrike#bf0693d4 offset:int length:int = MessageEntity;
messageEntityBlockquote#20df5d0 offset:int length:int = MessageEntity;

// layer 143

decryptedMessageMediaDocument#6abd9782 thumb:bytes thumb_w:int thumb_h:int mime_type:string size:long key:bytes iv:bytes attributes:Vector<DocumentAttribute> caption:string = DecryptedMessageMedia;

// layer 144

messageEntitySpoiler#32ca960f offset:int length:int = MessageEntity;
messageEntityCustomEmoji#c8cf05f8 offset:int length:int document_id:long = MessageEntity;

---functions---

test.dummyFunction = Bool;
