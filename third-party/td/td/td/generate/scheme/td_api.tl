double ? = Double;
string ? = String;

int32 = Int32;
int53 = Int53;
int64 = Int64;
bytes = Bytes;

boolFalse = Bool;
boolTrue = Bool;

vector {t:Type} # [ t ] = Vector t;


//@description An object of this type can be returned on every function call, in case of an error
//@code Error code; subject to future changes. If the error code is 406, the error message must not be processed in any way and must not be displayed to the user
//@message Error message; subject to future changes
error code:int32 message:string = Error;


//@description An object of this type is returned on a successful function call for certain functions
ok = Ok;


//@class AuthenticationCodeType @description Provides information about the method by which an authentication code is delivered to the user

//@description A digit-only authentication code is delivered via a private Telegram message, which can be viewed from another active session
//@length Length of the code
authenticationCodeTypeTelegramMessage length:int32 = AuthenticationCodeType;

//@description A digit-only authentication code is delivered via an SMS message to the specified phone number; non-official applications may not receive this type of code
//@length Length of the code
authenticationCodeTypeSms length:int32 = AuthenticationCodeType;

//@description An authentication code is a word delivered via an SMS message to the specified phone number; non-official applications may not receive this type of code
//@first_letter The first letters of the word if known
authenticationCodeTypeSmsWord first_letter:string = AuthenticationCodeType;

//@description An authentication code is a phrase from multiple words delivered via an SMS message to the specified phone number; non-official applications may not receive this type of code
//@first_word The first word of the phrase if known
authenticationCodeTypeSmsPhrase first_word:string = AuthenticationCodeType;

//@description A digit-only authentication code is delivered via a phone call to the specified phone number
//@length Length of the code
authenticationCodeTypeCall length:int32 = AuthenticationCodeType;

//@description An authentication code is delivered by an immediately canceled call to the specified phone number. The phone number that calls is the code that must be entered automatically
//@pattern Pattern of the phone number from which the call will be made
authenticationCodeTypeFlashCall pattern:string = AuthenticationCodeType;

//@description An authentication code is delivered by an immediately canceled call to the specified phone number. The last digits of the phone number that calls are the code that must be entered manually by the user
//@phone_number_prefix Prefix of the phone number from which the call will be made
//@length Number of digits in the code, excluding the prefix
authenticationCodeTypeMissedCall phone_number_prefix:string length:int32 = AuthenticationCodeType;

//@description A digit-only authentication code is delivered to https://fragment.com. The user must be logged in there via a wallet owning the phone number's NFT
//@url URL to open to receive the code
//@length Length of the code
authenticationCodeTypeFragment url:string length:int32 = AuthenticationCodeType;

//@description A digit-only authentication code is delivered via Firebase Authentication to the official Android application
//@device_verification_parameters Parameters to be used for device verification
//@length Length of the code
authenticationCodeTypeFirebaseAndroid device_verification_parameters:FirebaseDeviceVerificationParameters length:int32 = AuthenticationCodeType;

//@description A digit-only authentication code is delivered via Firebase Authentication to the official iOS application
//@receipt Receipt of successful application token validation to compare with receipt from push notification
//@push_timeout Time after the next authentication method is expected to be used if verification push notification isn't received, in seconds
//@length Length of the code
authenticationCodeTypeFirebaseIos receipt:string push_timeout:int32 length:int32 = AuthenticationCodeType;


//@description Information about the authentication code that was sent
//@phone_number A phone number that is being authenticated
//@type The way the code was sent to the user
//@next_type The way the next code will be sent to the user; may be null
//@timeout Timeout before the code can be re-sent, in seconds
authenticationCodeInfo phone_number:string type:AuthenticationCodeType next_type:AuthenticationCodeType timeout:int32 = AuthenticationCodeInfo;

//@description Information about the email address authentication code that was sent
//@email_address_pattern Pattern of the email address to which an authentication code was sent
//@length Length of the code; 0 if unknown
emailAddressAuthenticationCodeInfo email_address_pattern:string length:int32 = EmailAddressAuthenticationCodeInfo;


//@class EmailAddressAuthentication @description Contains authentication data for an email address

//@description An authentication code delivered to a user's email address @code The code
emailAddressAuthenticationCode code:string = EmailAddressAuthentication;

//@description An authentication token received through Apple ID @token The token
emailAddressAuthenticationAppleId token:string = EmailAddressAuthentication;

//@description An authentication token received through Google ID @token The token
emailAddressAuthenticationGoogleId token:string = EmailAddressAuthentication;


//@class EmailAddressResetState @description Describes reset state of an email address

//@description Email address can be reset after the given period. Call resetAuthenticationEmailAddress to reset it and allow the user to authorize with a code sent to the user's phone number
//@wait_period Time required to wait before the email address can be reset; 0 if the user is subscribed to Telegram Premium
emailAddressResetStateAvailable wait_period:int32 = EmailAddressResetState;

//@description Email address reset has already been requested. Call resetAuthenticationEmailAddress to check whether immediate reset is possible
//@reset_in Left time before the email address will be reset, in seconds. updateAuthorizationState is not sent when this field changes
emailAddressResetStatePending reset_in:int32 = EmailAddressResetState;


//@description Represents a part of the text that needs to be formatted in some unusual way @offset Offset of the entity, in UTF-16 code units @length Length of the entity, in UTF-16 code units @type Type of the entity
textEntity offset:int32 length:int32 type:TextEntityType = TextEntity;

//@description Contains a list of text entities @entities List of text entities
textEntities entities:vector<textEntity> = TextEntities;

//@description A text with some entities @text The text @entities Entities contained in the text. Entities can be nested, but must not mutually intersect with each other.
//-Pre, Code and PreCode entities can't contain other entities. BlockQuote entities can't contain other BlockQuote entities. Bold, Italic, Underline, Strikethrough, and Spoiler entities can contain and can be part of any other entities. All other entities can't contain each other
formattedText text:string entities:vector<textEntity> = FormattedText;


//@description Contains Telegram terms of service @text Text of the terms of service @min_user_age The minimum age of a user to be able to accept the terms; 0 if age isn't restricted @show_popup True, if a blocking popup with terms of service must be shown to the user
termsOfService text:formattedText min_user_age:int32 show_popup:Bool = TermsOfService;


//@class AuthorizationState @description Represents the current authorization state of the TDLib client

//@description Initialization parameters are needed. Call setTdlibParameters to provide them
authorizationStateWaitTdlibParameters = AuthorizationState;

//@description TDLib needs the user's phone number to authorize. Call setAuthenticationPhoneNumber to provide the phone number, or use requestQrCodeAuthentication or checkAuthenticationBotToken for other authentication options
authorizationStateWaitPhoneNumber = AuthorizationState;

//@description TDLib needs the user's email address to authorize. Call setAuthenticationEmailAddress to provide the email address, or directly call checkAuthenticationEmailCode with Apple ID/Google ID token if allowed
//@allow_apple_id True, if authorization through Apple ID is allowed
//@allow_google_id True, if authorization through Google ID is allowed
authorizationStateWaitEmailAddress allow_apple_id:Bool allow_google_id:Bool = AuthorizationState;

//@description TDLib needs the user's authentication code sent to an email address to authorize. Call checkAuthenticationEmailCode to provide the code
//@allow_apple_id True, if authorization through Apple ID is allowed
//@allow_google_id True, if authorization through Google ID is allowed
//@code_info Information about the sent authentication code
//@email_address_reset_state Reset state of the email address; may be null if the email address can't be reset
authorizationStateWaitEmailCode allow_apple_id:Bool allow_google_id:Bool code_info:emailAddressAuthenticationCodeInfo email_address_reset_state:EmailAddressResetState = AuthorizationState;

//@description TDLib needs the user's authentication code to authorize. Call checkAuthenticationCode to check the code @code_info Information about the authorization code that was sent
authorizationStateWaitCode code_info:authenticationCodeInfo = AuthorizationState;

//@description The user needs to confirm authorization on another logged in device by scanning a QR code with the provided link @link A tg:// URL for the QR code. The link will be updated frequently
authorizationStateWaitOtherDeviceConfirmation link:string = AuthorizationState;

//@description The user is unregistered and need to accept terms of service and enter their first name and last name to finish registration. Call registerUser to accept the terms of service and provide the data @terms_of_service Telegram terms of service
authorizationStateWaitRegistration terms_of_service:termsOfService = AuthorizationState;

//@description The user has been authorized, but needs to enter a 2-step verification password to start using the application.
//-Call checkAuthenticationPassword to provide the password, or requestAuthenticationPasswordRecovery to recover the password, or deleteAccount to delete the account after a week
//@password_hint Hint for the password; may be empty
//@has_recovery_email_address True, if a recovery email address has been set up
//@has_passport_data True, if some Telegram Passport elements were saved
//@recovery_email_address_pattern Pattern of the email address to which the recovery email was sent; empty until a recovery email has been sent
authorizationStateWaitPassword password_hint:string has_recovery_email_address:Bool has_passport_data:Bool recovery_email_address_pattern:string = AuthorizationState;

//@description The user has been successfully authorized. TDLib is now ready to answer general requests
authorizationStateReady = AuthorizationState;

//@description The user is currently logging out
authorizationStateLoggingOut = AuthorizationState;

//@description TDLib is closing, all subsequent queries will be answered with the error 500. Note that closing TDLib can take a while. All resources will be freed only after authorizationStateClosed has been received
authorizationStateClosing = AuthorizationState;

//@description TDLib client is in its final state. All databases are closed and all resources are released. No other updates will be received after this. All queries will be responded to
//-with error code 500. To continue working, one must create a new instance of the TDLib client
authorizationStateClosed = AuthorizationState;


//@class FirebaseDeviceVerificationParameters @description Describes parameters to be used for device verification

//@description Device verification must be performed with the SafetyNet Attestation API @nonce Nonce to pass to the SafetyNet Attestation API
firebaseDeviceVerificationParametersSafetyNet nonce:bytes = FirebaseDeviceVerificationParameters;

//@description Device verification must be performed with the classic Play Integrity verification (https://developer.android.com/google/play/integrity/classic)
//@nonce Base64url-encoded nonce to pass to the Play Integrity API
//@cloud_project_number Cloud project number to pass to the Play Integrity API
firebaseDeviceVerificationParametersPlayIntegrity nonce:string cloud_project_number:int64 = FirebaseDeviceVerificationParameters;


//@description Represents the current state of 2-step verification
//@has_password True, if a 2-step verification password is set
//@password_hint Hint for the password; may be empty
//@has_recovery_email_address True, if a recovery email is set
//@has_passport_data True, if some Telegram Passport elements were saved
//@recovery_email_address_code_info Information about the recovery email address to which the confirmation email was sent; may be null
//@login_email_address_pattern Pattern of the email address set up for logging in
//@pending_reset_date If not 0, point in time (Unix timestamp) after which the 2-step verification password can be reset immediately using resetPassword
passwordState has_password:Bool password_hint:string has_recovery_email_address:Bool has_passport_data:Bool recovery_email_address_code_info:emailAddressAuthenticationCodeInfo login_email_address_pattern:string pending_reset_date:int32 = PasswordState;

//@description Contains information about the current recovery email address @recovery_email_address Recovery email address
recoveryEmailAddress recovery_email_address:string = RecoveryEmailAddress;


//@description Returns information about the availability of a temporary password, which can be used for payments @has_password True, if a temporary password is available @valid_for Time left before the temporary password expires, in seconds
temporaryPasswordState has_password:Bool valid_for:int32 = TemporaryPasswordState;


//@description Represents a local file
//@path Local path to the locally available file part; may be empty
//@can_be_downloaded True, if it is possible to download or generate the file
//@can_be_deleted True, if the file can be deleted
//@is_downloading_active True, if the file is currently being downloaded (or a local copy is being generated by some other means)
//@is_downloading_completed True, if the local copy is fully available
//@download_offset Download will be started from this offset. downloaded_prefix_size is calculated from this offset
//@downloaded_prefix_size If is_downloading_completed is false, then only some prefix of the file starting from download_offset is ready to be read. downloaded_prefix_size is the size of that prefix in bytes
//@downloaded_size Total downloaded file size, in bytes. Can be used only for calculating download progress. The actual file size may be bigger, and some parts of it may contain garbage
localFile path:string can_be_downloaded:Bool can_be_deleted:Bool is_downloading_active:Bool is_downloading_completed:Bool download_offset:int53 downloaded_prefix_size:int53 downloaded_size:int53 = LocalFile;

//@description Represents a remote file
//@id Remote file identifier; may be empty. Can be used by the current user across application restarts or even from other devices. Uniquely identifies a file, but a file can have a lot of different valid identifiers.
//-If the identifier starts with "http://" or "https://", it represents the HTTP URL of the file. TDLib is currently unable to download files if only their URL is known.
//-If downloadFile/addFileToDownloads is called on such a file or if it is sent to a secret chat, TDLib starts a file generation process by sending updateFileGenerationStart to the application with the HTTP URL in the original_path and "#url#" as the conversion string.
//-Application must generate the file by downloading it to the specified location
//@unique_id Unique file identifier; may be empty if unknown. The unique file identifier which is the same for the same file even for different users and is persistent over time
//@is_uploading_active True, if the file is currently being uploaded (or a remote copy is being generated by some other means)
//@is_uploading_completed True, if a remote copy is fully available
//@uploaded_size Size of the remote available part of the file, in bytes; 0 if unknown
remoteFile id:string unique_id:string is_uploading_active:Bool is_uploading_completed:Bool uploaded_size:int53 = RemoteFile;

//@description Represents a file
//@id Unique file identifier
//@size File size, in bytes; 0 if unknown
//@expected_size Approximate file size in bytes in case the exact file size is unknown. Can be used to show download/upload progress
//@local Information about the local copy of the file
//@remote Information about the remote copy of the file
file id:int32 size:int53 expected_size:int53 local:localFile remote:remoteFile = File;


//@class InputFile @description Points to a file

//@description A file defined by its unique identifier @id Unique file identifier
inputFileId id:int32 = InputFile;

//@description A file defined by its remote identifier. The remote identifier is guaranteed to be usable only if the corresponding file is still accessible to the user and known to TDLib.
//-For example, if the file is from a message, then the message must be not deleted and accessible to the user. If the file database is disabled, then the corresponding object with the file must be preloaded by the application
//@id Remote file identifier
inputFileRemote id:string = InputFile;

//@description A file defined by a local path @path Local path to the file
inputFileLocal path:string = InputFile;

//@description A file generated by the application. The application must handle updates updateFileGenerationStart and updateFileGenerationStop to generate the file when asked by TDLib
//@original_path Local path to a file from which the file is generated. The path doesn't have to be a valid path and is used by TDLib only to detect name and MIME type of the generated file
//@conversion String specifying the conversion applied to the original file; must be persistent across application restarts. Conversions beginning with '#' are reserved for internal TDLib usage
//@expected_size Expected size of the generated file, in bytes; pass 0 if unknown
inputFileGenerated original_path:string conversion:string expected_size:int53 = InputFile;


//@description Describes an image in JPEG format
//@type Image type (see https://core.telegram.org/constructor/photoSize)
//@photo Information about the image file
//@width Image width
//@height Image height
//@progressive_sizes Sizes of progressive JPEG file prefixes, which can be used to preliminarily show the image; in bytes
photoSize type:string photo:file width:int32 height:int32 progressive_sizes:vector<int32> = PhotoSize;

//@description Thumbnail image of a very poor quality and low resolution @width Thumbnail width, usually doesn't exceed 40 @height Thumbnail height, usually doesn't exceed 40 @data The thumbnail in JPEG format
minithumbnail width:int32 height:int32 data:bytes = Minithumbnail;


//@class ThumbnailFormat @description Describes format of a thumbnail

//@description The thumbnail is in JPEG format
thumbnailFormatJpeg = ThumbnailFormat;

//@description The thumbnail is in static GIF format. It will be used only for some bot inline query results
thumbnailFormatGif = ThumbnailFormat;

//@description The thumbnail is in MPEG4 format. It will be used only for some animations and videos
thumbnailFormatMpeg4 = ThumbnailFormat;

//@description The thumbnail is in PNG format. It will be used only for background patterns
thumbnailFormatPng = ThumbnailFormat;

//@description The thumbnail is in TGS format. It will be used only for sticker sets
thumbnailFormatTgs = ThumbnailFormat;

//@description The thumbnail is in WEBM format. It will be used only for sticker sets
thumbnailFormatWebm = ThumbnailFormat;

//@description The thumbnail is in WEBP format. It will be used only for some stickers and sticker sets
thumbnailFormatWebp = ThumbnailFormat;


//@description Represents a thumbnail
//@format Thumbnail format
//@width Thumbnail width
//@height Thumbnail height
//@file The thumbnail
thumbnail format:ThumbnailFormat width:int32 height:int32 file:file = Thumbnail;


//@class MaskPoint @description Part of the face, relative to which a mask is placed

//@description The mask is placed relatively to the forehead
maskPointForehead = MaskPoint;

//@description The mask is placed relatively to the eyes
maskPointEyes = MaskPoint;

//@description The mask is placed relatively to the mouth
maskPointMouth = MaskPoint;

//@description The mask is placed relatively to the chin
maskPointChin = MaskPoint;

//@description Position on a photo where a mask is placed
//@point Part of the face, relative to which the mask is placed
//@x_shift Shift by X-axis measured in widths of the mask scaled to the face size, from left to right. (For example, -1.0 will place the mask just to the left of the default mask position)
//@y_shift Shift by Y-axis measured in heights of the mask scaled to the face size, from top to bottom. (For example, 1.0 will place the mask just below the default mask position)
//@scale Mask scaling coefficient. (For example, 2.0 means a doubled size)
maskPosition point:MaskPoint x_shift:double y_shift:double scale:double = MaskPosition;


//@class StickerFormat @description Describes format of a sticker

//@description The sticker is an image in WEBP format
stickerFormatWebp = StickerFormat;

//@description The sticker is an animation in TGS format
stickerFormatTgs = StickerFormat;

//@description The sticker is a video in WEBM format
stickerFormatWebm = StickerFormat;


//@class StickerType @description Describes type of sticker

//@description The sticker is a regular sticker
stickerTypeRegular = StickerType;

//@description The sticker is a mask in WEBP format to be placed on photos or videos
stickerTypeMask = StickerType;

//@description The sticker is a custom emoji to be used inside message text and caption
stickerTypeCustomEmoji = StickerType;


//@class StickerFullType @description Contains full information about sticker type

//@description The sticker is a regular sticker @premium_animation Premium animation of the sticker; may be null. If present, only Telegram Premium users can use the sticker
stickerFullTypeRegular premium_animation:file = StickerFullType;

//@description The sticker is a mask in WEBP format to be placed on photos or videos @mask_position Position where the mask is placed; may be null
stickerFullTypeMask mask_position:maskPosition = StickerFullType;

//@description The sticker is a custom emoji to be used inside message text and caption. Currently, only Telegram Premium users can use custom emoji
//@custom_emoji_id Identifier of the custom emoji
//@needs_repainting True, if the sticker must be repainted to a text color in messages, the color of the Telegram Premium badge in emoji status, white color on chat photos, or another appropriate color in other places
stickerFullTypeCustomEmoji custom_emoji_id:int64 needs_repainting:Bool = StickerFullType;


//@description Represents a closed vector path. The path begins at the end point of the last command. The coordinate system origin is in the upper-left corner @commands List of vector path commands
closedVectorPath commands:vector<VectorPathCommand> = ClosedVectorPath;

//@description Represents outline of an image @paths The list of closed vector paths
outline paths:vector<closedVectorPath> = Outline;


//@description Describes one answer option of a poll
//@text Option text; 1-100 characters. Only custom emoji entities are allowed
//@voter_count Number of voters for this option, available only for closed or voted polls
//@vote_percentage The percentage of votes for this option; 0-100
//@is_chosen True, if the option was chosen by the user
//@is_being_chosen True, if the option is being chosen by a pending setPollAnswer request
pollOption text:formattedText voter_count:int32 vote_percentage:int32 is_chosen:Bool is_being_chosen:Bool = PollOption;


//@class PollType @description Describes the type of poll

//@description A regular poll @allow_multiple_answers True, if multiple answer options can be chosen simultaneously
pollTypeRegular allow_multiple_answers:Bool = PollType;

//@description A poll in quiz mode, which has exactly one correct answer option and can be answered only once
//@correct_option_id 0-based identifier of the correct answer option; -1 for a yet unanswered poll
//@explanation Text that is shown when the user chooses an incorrect answer or taps on the lamp icon; 0-200 characters with at most 2 line feeds; empty for a yet unanswered poll
pollTypeQuiz correct_option_id:int32 explanation:formattedText = PollType;


//@description Describes an animation file. The animation must be encoded in GIF or MPEG4 format
//@duration Duration of the animation, in seconds; as defined by the sender
//@width Width of the animation
//@height Height of the animation
//@file_name Original name of the file; as defined by the sender
//@mime_type MIME type of the file, usually "image/gif" or "video/mp4"
//@has_stickers True, if stickers were added to the animation. The list of corresponding sticker set can be received using getAttachedStickerSets
//@minithumbnail Animation minithumbnail; may be null
//@thumbnail Animation thumbnail in JPEG or MPEG4 format; may be null
//@animation File containing the animation
animation duration:int32 width:int32 height:int32 file_name:string mime_type:string has_stickers:Bool minithumbnail:minithumbnail thumbnail:thumbnail animation:file = Animation;

//@description Describes an audio file. Audio is usually in MP3 or M4A format
//@duration Duration of the audio, in seconds; as defined by the sender
//@title Title of the audio; as defined by the sender
//@performer Performer of the audio; as defined by the sender
//@file_name Original name of the file; as defined by the sender
//@mime_type The MIME type of the file; as defined by the sender
//@album_cover_minithumbnail The minithumbnail of the album cover; may be null
//@album_cover_thumbnail The thumbnail of the album cover in JPEG format; as defined by the sender. The full size thumbnail is expected to be extracted from the downloaded audio file; may be null
//@external_album_covers Album cover variants to use if the downloaded audio file contains no album cover. Provided thumbnail dimensions are approximate
//@audio File containing the audio
audio duration:int32 title:string performer:string file_name:string mime_type:string album_cover_minithumbnail:minithumbnail album_cover_thumbnail:thumbnail external_album_covers:vector<thumbnail> audio:file = Audio;

//@description Describes a document of any type
//@file_name Original name of the file; as defined by the sender
//@mime_type MIME type of the file; as defined by the sender
//@minithumbnail Document minithumbnail; may be null
//@thumbnail Document thumbnail in JPEG or PNG format (PNG will be used only for background patterns); as defined by the sender; may be null
//@document File containing the document
document file_name:string mime_type:string minithumbnail:minithumbnail thumbnail:thumbnail document:file = Document;

//@description Describes a photo
//@has_stickers True, if stickers were added to the photo. The list of corresponding sticker sets can be received using getAttachedStickerSets
//@minithumbnail Photo minithumbnail; may be null
//@sizes Available variants of the photo, in different sizes
photo has_stickers:Bool minithumbnail:minithumbnail sizes:vector<photoSize> = Photo;

//@description Describes a sticker
//@id Unique sticker identifier within the set; 0 if none
//@set_id Identifier of the sticker set to which the sticker belongs; 0 if none
//@width Sticker width; as defined by the sender
//@height Sticker height; as defined by the sender
//@emoji Emoji corresponding to the sticker
//@format Sticker format
//@full_type Sticker's full type
//@thumbnail Sticker thumbnail in WEBP or JPEG format; may be null
//@sticker File containing the sticker
sticker id:int64 set_id:int64 width:int32 height:int32 emoji:string format:StickerFormat full_type:StickerFullType thumbnail:thumbnail sticker:file = Sticker;

//@description Describes a video file
//@duration Duration of the video, in seconds; as defined by the sender
//@width Video width; as defined by the sender
//@height Video height; as defined by the sender
//@file_name Original name of the file; as defined by the sender
//@mime_type MIME type of the file; as defined by the sender
//@has_stickers True, if stickers were added to the video. The list of corresponding sticker sets can be received using getAttachedStickerSets
//@supports_streaming True, if the video is expected to be streamed
//@minithumbnail Video minithumbnail; may be null
//@thumbnail Video thumbnail in JPEG or MPEG4 format; as defined by the sender; may be null
//@video File containing the video
video duration:int32 width:int32 height:int32 file_name:string mime_type:string has_stickers:Bool supports_streaming:Bool minithumbnail:minithumbnail thumbnail:thumbnail video:file = Video;

//@description Describes a video note. The video must be equal in width and height, cropped to a circle, and stored in MPEG4 format
//@duration Duration of the video, in seconds; as defined by the sender
//@waveform A waveform representation of the video note's audio in 5-bit format; may be empty if unknown
//@length Video width and height; as defined by the sender
//@minithumbnail Video minithumbnail; may be null
//@thumbnail Video thumbnail in JPEG format; as defined by the sender; may be null
//@speech_recognition_result Result of speech recognition in the video note; may be null
//@video File containing the video
videoNote duration:int32 waveform:bytes length:int32 minithumbnail:minithumbnail thumbnail:thumbnail speech_recognition_result:SpeechRecognitionResult video:file = VideoNote;

//@description Describes a voice note
//@duration Duration of the voice note, in seconds; as defined by the sender
//@waveform A waveform representation of the voice note in 5-bit format
//@mime_type MIME type of the file; as defined by the sender. Usually, one of "audio/ogg" for Opus in an OGG container, "audio/mpeg" for an MP3 audio, or "audio/mp4" for an M4A audio
//@speech_recognition_result Result of speech recognition in the voice note; may be null
//@voice File containing the voice note
voiceNote duration:int32 waveform:bytes mime_type:string speech_recognition_result:SpeechRecognitionResult voice:file = VoiceNote;

//@description Describes an animated or custom representation of an emoji
//@sticker Sticker for the emoji; may be null if yet unknown for a custom emoji. If the sticker is a custom emoji, then it can have arbitrary format
//@sticker_width Expected width of the sticker, which can be used if the sticker is null
//@sticker_height Expected height of the sticker, which can be used if the sticker is null
//@fitzpatrick_type Emoji modifier fitzpatrick type; 0-6; 0 if none
//@sound File containing the sound to be played when the sticker is clicked; may be null. The sound is encoded with the Opus codec, and stored inside an OGG container
animatedEmoji sticker:sticker sticker_width:int32 sticker_height:int32 fitzpatrick_type:int32 sound:file = AnimatedEmoji;

//@description Describes a user contact
//@phone_number Phone number of the user
//@first_name First name of the user; 1-255 characters in length
//@last_name Last name of the user
//@vcard Additional data about the user in a form of vCard; 0-2048 bytes in length
//@user_id Identifier of the user, if known; 0 otherwise
contact phone_number:string first_name:string last_name:string vcard:string user_id:int53 = Contact;

//@description Describes a location on planet Earth
//@latitude Latitude of the location in degrees; as defined by the sender
//@longitude Longitude of the location, in degrees; as defined by the sender
//@horizontal_accuracy The estimated horizontal accuracy of the location, in meters; as defined by the sender. 0 if unknown
location latitude:double longitude:double horizontal_accuracy:double = Location;

//@description Describes a venue
//@location Venue location; as defined by the sender
//@title Venue name; as defined by the sender
//@address Venue address; as defined by the sender
//@provider Provider of the venue database; as defined by the sender. Currently, only "foursquare" and "gplaces" (Google Places) need to be supported
//@id Identifier of the venue in the provider database; as defined by the sender
//@type Type of the venue in the provider database; as defined by the sender
venue location:location title:string address:string provider:string id:string type:string = Venue;

//@description Describes a game. Use getInternalLink with internalLinkTypeGame to share the game
//@id Unique game identifier
//@short_name Game short name
//@title Game title
//@text Game text, usually containing scoreboards for a game
//@param_description Game description
//@photo Game photo
//@animation Game animation; may be null
game id:int64 short_name:string title:string text:formattedText description:string photo:photo animation:animation = Game;

//@description Describes a Web App. Use getInternalLink with internalLinkTypeWebApp to share the Web App
//@short_name Web App short name
//@title Web App title
//@param_description Web App description
//@photo Web App photo
//@animation Web App animation; may be null
webApp short_name:string title:string description:string photo:photo animation:animation = WebApp;

//@description Describes a poll
//@id Unique poll identifier
//@question Poll question; 1-300 characters. Only custom emoji entities are allowed
//@options List of poll answer options
//@total_voter_count Total number of voters, participating in the poll
//@recent_voter_ids Identifiers of recent voters, if the poll is non-anonymous
//@is_anonymous True, if the poll is anonymous
//@type Type of the poll
//@open_period Amount of time the poll will be active after creation, in seconds
//@close_date Point in time (Unix timestamp) when the poll will automatically be closed
//@is_closed True, if the poll is closed
poll id:int64 question:formattedText options:vector<pollOption> total_voter_count:int32 recent_voter_ids:vector<MessageSender> is_anonymous:Bool type:PollType open_period:int32 close_date:int32 is_closed:Bool = Poll;


//@description Describes an alternative re-encoded quality of a video file
//@id Unique identifier of the alternative video, which is used in the HLS file
//@width Video width
//@height Video height
//@codec Codec used for video file encoding, for example, "h264", "h265", or "av1"
//@hls_file HLS file describing the video
//@video File containing the video
alternativeVideo id:int64 width:int32 height:int32 codec:string hls_file:file video:file = AlternativeVideo;


//@description Describes a chat background
//@id Unique background identifier
//@is_default True, if this is one of default backgrounds
//@is_dark True, if the background is dark and is recommended to be used with dark theme
//@name Unique background name
//@document Document with the background; may be null. Null only for filled and chat theme backgrounds
//@type Type of the background
background id:int64 is_default:Bool is_dark:Bool name:string document:document type:BackgroundType = Background;

//@description Contains a list of backgrounds @backgrounds A list of backgrounds
backgrounds backgrounds:vector<background> = Backgrounds;

//@description Describes a background set for a specific chat @background The background @dark_theme_dimming Dimming of the background in dark themes, as a percentage; 0-100. Applied only to Wallpaper and Fill types of background
chatBackground background:background dark_theme_dimming:int32 = ChatBackground;


//@description Describes a user profile photo
//@id Photo identifier; 0 for an empty photo. Can be used to find a photo in a list of user profile photos
//@small A small (160x160) user profile photo. The file can be downloaded only before the photo is changed
//@big A big (640x640) user profile photo. The file can be downloaded only before the photo is changed
//@minithumbnail User profile photo minithumbnail; may be null
//@has_animation True, if the photo has animated variant
//@is_personal True, if the photo is visible only for the current user
profilePhoto id:int64 small:file big:file minithumbnail:minithumbnail has_animation:Bool is_personal:Bool = ProfilePhoto;

//@description Contains basic information about the photo of a chat
//@small A small (160x160) chat photo variant in JPEG format. The file can be downloaded only before the photo is changed
//@big A big (640x640) chat photo variant in JPEG format. The file can be downloaded only before the photo is changed
//@minithumbnail Chat photo minithumbnail; may be null
//@has_animation True, if the photo has animated variant
//@is_personal True, if the photo is visible only for the current user
chatPhotoInfo small:file big:file minithumbnail:minithumbnail has_animation:Bool is_personal:Bool = ChatPhotoInfo;


//@class UserType @description Represents the type of user. The following types are possible: regular users, deleted users and bots

//@description A regular user
userTypeRegular = UserType;

//@description A deleted user or deleted bot. No information on the user besides the user identifier is available. It is not possible to perform any active actions on this type of user
userTypeDeleted = UserType;

//@description A bot (see https://core.telegram.org/bots)
//@can_be_edited True, if the bot is owned by the current user and can be edited using the methods toggleBotUsernameIsActive, reorderBotActiveUsernames, setBotProfilePhoto, setBotName, setBotInfoDescription, and setBotInfoShortDescription
//@can_join_groups True, if the bot can be invited to basic group and supergroup chats
//@can_read_all_group_messages True, if the bot can read all messages in basic group or supergroup chats and not just those addressed to the bot. In private and channel chats a bot can always read all messages
//@has_main_web_app True, if the bot has the main Web App
//@is_inline True, if the bot supports inline queries
//@inline_query_placeholder Placeholder for inline queries (displayed on the application input field)
//@need_location True, if the location of the user is expected to be sent with every inline query to this bot
//@can_connect_to_business True, if the bot supports connection to Telegram Business accounts
//@can_be_added_to_attachment_menu True, if the bot can be added to attachment or side menu
//@active_user_count The number of recently active users of the bot
userTypeBot can_be_edited:Bool can_join_groups:Bool can_read_all_group_messages:Bool has_main_web_app:Bool is_inline:Bool inline_query_placeholder:string need_location:Bool can_connect_to_business:Bool can_be_added_to_attachment_menu:Bool active_user_count:int32 = UserType;

//@description No information on the user besides the user identifier is available, yet this user has not been deleted. This object is extremely rare and must be handled like a deleted user. It is not possible to perform any actions on users of this type
userTypeUnknown = UserType;


//@description Represents a command supported by a bot @command Text of the bot command @param_description Description of the bot command
botCommand command:string description:string = BotCommand;

//@description Contains a list of bot commands @bot_user_id Bot's user identifier @commands List of bot commands
botCommands bot_user_id:int53 commands:vector<botCommand> = BotCommands;

//@description Describes a button to be shown instead of bot commands menu button
//@text Text of the button
//@url URL of a Web App to open when the button is pressed. If the link is of the type internalLinkTypeWebApp, then it must be processed accordingly. Otherwise, the link must be passed to openWebApp
botMenuButton text:string url:string = BotMenuButton;


//@description Describes parameters of verification that is provided by a bot
//@icon_custom_emoji_id Identifier of the custom emoji that is used as the verification sign
//@organization_name Name of the organization that provides verification
//@default_custom_description Default custom description of verification reason to be used as placeholder in setMessageSenderBotVerification; may be null if none
//@can_set_custom_description True, if the bot is allowed to provide custom description for verified entities
botVerificationParameters icon_custom_emoji_id:int64 organization_name:string default_custom_description:formattedText can_set_custom_description:Bool = BotVerificationParameters;

//@description Describes verification status provided by a bot
//@bot_user_id Identifier of the bot that provided the verification
//@icon_custom_emoji_id Identifier of the custom emoji that is used as the verification sign
//@custom_description Custom description of verification reason set by the bot. Can contain only Mention, Hashtag, Cashtag, PhoneNumber, BankCardNumber, Url, and EmailAddress entities
botVerification bot_user_id:int53 icon_custom_emoji_id:int64 custom_description:formattedText = BotVerification;

//@description Contains information about verification status of a chat or a user
//@is_verified True, if the chat or the user is verified by Telegram
//@is_scam True, if the chat or the user is marked as scam by Telegram
//@is_fake True, if the chat or the user is marked as fake by Telegram
//@bot_verification_icon_custom_emoji_id Identifier of the custom emoji to be shown as verification sign provided by a bot for the user; 0 if none
verificationStatus is_verified:Bool is_scam:Bool is_fake:Bool bot_verification_icon_custom_emoji_id:int64 = VerificationStatus;


//@description Represents a location to which a chat is connected @location The location @address Location address; 1-64 characters, as defined by the chat owner
chatLocation location:location address:string = ChatLocation;


//@description Represents a birthdate of a user @day Day of the month; 1-31 @month Month of the year; 1-12 @year Birth year; 0 if unknown
birthdate day:int32 month:int32 year:int32 = Birthdate;

//@description Describes a user that had or will have a birthday soon @user_id User identifier @birthdate Birthdate of the user
closeBirthdayUser user_id:int53 birthdate:birthdate = CloseBirthdayUser;


//@class BusinessAwayMessageSchedule @description Describes conditions for sending of away messages by a Telegram Business account

//@description Send away messages always
businessAwayMessageScheduleAlways = BusinessAwayMessageSchedule;

//@description Send away messages outside of the business opening hours
businessAwayMessageScheduleOutsideOfOpeningHours = BusinessAwayMessageSchedule;

//@description Send away messages only in the specified time span
//@start_date Point in time (Unix timestamp) when the away messages will start to be sent
//@end_date Point in time (Unix timestamp) when the away messages will stop to be sent
businessAwayMessageScheduleCustom start_date:int32 end_date:int32 = BusinessAwayMessageSchedule;


//@description Represents a location of a business @location The location; may be null if not specified @address Location address; 1-96 characters
businessLocation location:location address:string = BusinessLocation;

//@description Describes private chats chosen for automatic interaction with a business
//@chat_ids Identifiers of selected private chats
//@excluded_chat_ids Identifiers of private chats that are always excluded; for businessConnectedBot only
//@select_existing_chats True, if all existing private chats are selected
//@select_new_chats True, if all new private chats are selected
//@select_contacts True, if all private chats with contacts are selected
//@select_non_contacts True, if all private chats with non-contacts are selected
//@exclude_selected If true, then all private chats except the selected are chosen. Otherwise, only the selected chats are chosen
businessRecipients chat_ids:vector<int53> excluded_chat_ids:vector<int53> select_existing_chats:Bool select_new_chats:Bool select_contacts:Bool select_non_contacts:Bool exclude_selected:Bool = BusinessRecipients;

//@description Describes settings for messages that are automatically sent by a Telegram Business account when it is away
//@shortcut_id Unique quick reply shortcut identifier for the away messages
//@recipients Chosen recipients of the away messages
//@schedule Settings used to check whether the current user is away
//@offline_only True, if the messages must not be sent if the account was online in the last 10 minutes
businessAwayMessageSettings shortcut_id:int32 recipients:businessRecipients schedule:BusinessAwayMessageSchedule offline_only:Bool = BusinessAwayMessageSettings;

//@description Describes settings for greeting messages that are automatically sent by a Telegram Business account as response to incoming messages in an inactive private chat
//@shortcut_id Unique quick reply shortcut identifier for the greeting messages
//@recipients Chosen recipients of the greeting messages
//@inactivity_days The number of days after which a chat will be considered as inactive; currently, must be on of 7, 14, 21, or 28
businessGreetingMessageSettings shortcut_id:int32 recipients:businessRecipients inactivity_days:int32 = BusinessGreetingMessageSettings;

//@description Describes a bot connected to a business account
//@bot_user_id User identifier of the bot
//@recipients Private chats that will be accessible to the bot
//@can_reply True, if the bot can send messages to the private chats; false otherwise
businessConnectedBot bot_user_id:int53 recipients:businessRecipients can_reply:Bool = BusinessConnectedBot;

//@description Describes settings for a business account start page
//@title Title text of the start page
//@message Message text of the start page
//@sticker Greeting sticker of the start page; may be null if none
businessStartPage title:string message:string sticker:sticker = BusinessStartPage;

//@description Describes settings for a business account start page to set
//@title Title text of the start page; 0-getOption("business_start_page_title_length_max") characters
//@message Message text of the start page; 0-getOption("business_start_page_message_length_max") characters
//@sticker Greeting sticker of the start page; pass null if none. The sticker must belong to a sticker set and must not be a custom emoji
inputBusinessStartPage title:string message:string sticker:InputFile = InputBusinessStartPage;

//@description Describes an interval of time when the business is open
//@start_minute The minute's sequence number in a week, starting on Monday, marking the start of the time interval during which the business is open; 0-7*24*60
//@end_minute The minute's sequence number in a week, starting on Monday, marking the end of the time interval during which the business is open; 1-8*24*60
businessOpeningHoursInterval start_minute:int32 end_minute:int32 = BusinessOpeningHoursInterval;

//@description Describes opening hours of a business @time_zone_id Unique time zone identifier @opening_hours Intervals of the time when the business is open
businessOpeningHours time_zone_id:string opening_hours:vector<businessOpeningHoursInterval> = BusinessOpeningHours;

//@description Contains information about a Telegram Business account
//@location Location of the business; may be null if none
//@opening_hours Opening hours of the business; may be null if none. The hours are guaranteed to be valid and has already been split by week days
//@local_opening_hours Opening hours of the business in the local time; may be null if none. The hours are guaranteed to be valid and has already been split by week days.
//-Local time zone identifier will be empty. An updateUserFullInfo update is not triggered when value of this field changes
//@next_open_in Time left before the business will open the next time, in seconds; 0 if unknown. An updateUserFullInfo update is not triggered when value of this field changes
//@next_close_in Time left before the business will close the next time, in seconds; 0 if unknown. An updateUserFullInfo update is not triggered when value of this field changes
//@greeting_message_settings The greeting message; may be null if none or the Business account is not of the current user
//@away_message_settings The away message; may be null if none or the Business account is not of the current user
//@start_page Information about start page of the account; may be null if none
businessInfo location:businessLocation opening_hours:businessOpeningHours local_opening_hours:businessOpeningHours next_open_in:int32 next_close_in:int32 greeting_message_settings:businessGreetingMessageSettings away_message_settings:businessAwayMessageSettings start_page:businessStartPage = BusinessInfo;


//@description Contains information about a business chat link
//@link The HTTPS link
//@text Message draft text that will be added to the input field
//@title Link title
//@view_count Number of times the link was used
businessChatLink link:string text:formattedText title:string view_count:int32 = BusinessChatLink;

//@description Contains a list of business chat links created by the user @links List of links
businessChatLinks links:vector<businessChatLink> = BusinessChatLinks;

//@description Describes a business chat link to create or edit
//@text Message draft text that will be added to the input field
//@title Link title
inputBusinessChatLink text:formattedText title:string = InputBusinessChatLink;

//@description Contains information about a business chat link
//@chat_id Identifier of the private chat that created the link
//@text Message draft text that must be added to the input field
businessChatLinkInfo chat_id:int53 text:formattedText = BusinessChatLinkInfo;


//@class ChatPhotoStickerType @description Describes type of sticker, which was used to create a chat photo

//@description Information about the sticker, which was used to create the chat photo
//@sticker_set_id Sticker set identifier
//@sticker_id Identifier of the sticker in the set
chatPhotoStickerTypeRegularOrMask sticker_set_id:int64 sticker_id:int64 = ChatPhotoStickerType;

//@description Information about the custom emoji, which was used to create the chat photo
//@custom_emoji_id Identifier of the custom emoji
chatPhotoStickerTypeCustomEmoji custom_emoji_id:int64 = ChatPhotoStickerType;


//@description Information about the sticker, which was used to create the chat photo. The sticker is shown at the center of the photo and occupies at most 67% of it
//@type Type of the sticker
//@background_fill The fill to be used as background for the sticker; rotation angle in backgroundFillGradient isn't supported
chatPhotoSticker type:ChatPhotoStickerType background_fill:BackgroundFill = ChatPhotoSticker;

//@description Animated variant of a chat photo in MPEG4 format
//@length Animation width and height
//@file Information about the animation file
//@main_frame_timestamp Timestamp of the frame, used as a static chat photo
animatedChatPhoto length:int32 file:file main_frame_timestamp:double = AnimatedChatPhoto;


//@description Describes a chat or user profile photo
//@id Unique photo identifier
//@added_date Point in time (Unix timestamp) when the photo has been added
//@minithumbnail Photo minithumbnail; may be null
//@sizes Available variants of the photo in JPEG format, in different size
//@animation A big (up to 1280x1280) animated variant of the photo in MPEG4 format; may be null
//@small_animation A small (160x160) animated variant of the photo in MPEG4 format; may be null even the big animation is available
//@sticker Sticker-based version of the chat photo; may be null
chatPhoto id:int64 added_date:int32 minithumbnail:minithumbnail sizes:vector<photoSize> animation:animatedChatPhoto small_animation:animatedChatPhoto sticker:chatPhotoSticker = ChatPhoto;

//@description Contains a list of chat or user profile photos @total_count Total number of photos @photos List of photos
chatPhotos total_count:int32 photos:vector<chatPhoto> = ChatPhotos;


//@class InputChatPhoto @description Describes a photo to be set as a user profile or chat photo

//@description A previously used profile photo of the current user @chat_photo_id Identifier of the current user's profile photo to reuse
inputChatPhotoPrevious chat_photo_id:int64 = InputChatPhoto;

//@description A static photo in JPEG format @photo Photo to be set as profile photo. Only inputFileLocal and inputFileGenerated are allowed
inputChatPhotoStatic photo:InputFile = InputChatPhoto;

//@description An animation in MPEG4 format; must be square, at most 10 seconds long, have width between 160 and 1280 and be at most 2MB in size
//@animation Animation to be set as profile photo. Only inputFileLocal and inputFileGenerated are allowed
//@main_frame_timestamp Timestamp of the frame, which will be used as static chat photo
inputChatPhotoAnimation animation:InputFile main_frame_timestamp:double = InputChatPhoto;

//@description A sticker on a custom background @sticker Information about the sticker
inputChatPhotoSticker sticker:chatPhotoSticker = InputChatPhoto;


//@description Describes actions that a user is allowed to take in a chat
//@can_send_basic_messages True, if the user can send text messages, contacts, giveaways, giveaway winners, invoices, locations, and venues
//@can_send_audios True, if the user can send music files
//@can_send_documents True, if the user can send documents
//@can_send_photos True, if the user can send photos
//@can_send_videos True, if the user can send videos
//@can_send_video_notes True, if the user can send video notes
//@can_send_voice_notes True, if the user can send voice notes
//@can_send_polls True, if the user can send polls
//@can_send_other_messages True, if the user can send animations, games, stickers, and dice and use inline bots
//@can_add_link_previews True, if the user may add a link preview to their messages
//@can_change_info True, if the user can change the chat title, photo, and other settings
//@can_invite_users True, if the user can invite new users to the chat
//@can_pin_messages True, if the user can pin messages
//@can_create_topics True, if the user can create topics
chatPermissions can_send_basic_messages:Bool can_send_audios:Bool can_send_documents:Bool can_send_photos:Bool can_send_videos:Bool can_send_video_notes:Bool can_send_voice_notes:Bool can_send_polls:Bool can_send_other_messages:Bool can_add_link_previews:Bool can_change_info:Bool can_invite_users:Bool can_pin_messages:Bool can_create_topics:Bool = ChatPermissions;

//@description Describes rights of the administrator
//@can_manage_chat True, if the administrator can access the chat event log, get boost list, see hidden supergroup and channel members, report supergroup spam messages and ignore slow mode. Implied by any other privilege; applicable to supergroups and channels only
//@can_change_info True, if the administrator can change the chat title, photo, and other settings
//@can_post_messages True, if the administrator can create channel posts or view channel statistics; applicable to channels only
//@can_edit_messages True, if the administrator can edit messages of other users and pin messages; applicable to channels only
//@can_delete_messages True, if the administrator can delete messages of other users
//@can_invite_users True, if the administrator can invite new users to the chat
//@can_restrict_members True, if the administrator can restrict, ban, or unban chat members or view supergroup statistics; always true for channels
//@can_pin_messages True, if the administrator can pin messages; applicable to basic groups and supergroups only
//@can_manage_topics True, if the administrator can create, rename, close, reopen, hide, and unhide forum topics; applicable to forum supergroups only
//@can_promote_members True, if the administrator can add new administrators with a subset of their own privileges or demote administrators that were directly or indirectly promoted by them
//@can_manage_video_chats True, if the administrator can manage video chats
//@can_post_stories True, if the administrator can create new chat stories, or edit and delete posted stories; applicable to supergroups and channels only
//@can_edit_stories True, if the administrator can edit stories posted by other users, post stories to the chat page, pin chat stories, and access story archive; applicable to supergroups and channels only
//@can_delete_stories True, if the administrator can delete stories posted by other users; applicable to supergroups and channels only
//@is_anonymous True, if the administrator isn't shown in the chat member list and sends messages anonymously; applicable to supergroups only
chatAdministratorRights can_manage_chat:Bool can_change_info:Bool can_post_messages:Bool can_edit_messages:Bool can_delete_messages:Bool can_invite_users:Bool can_restrict_members:Bool can_pin_messages:Bool can_manage_topics:Bool can_promote_members:Bool can_manage_video_chats:Bool can_post_stories:Bool can_edit_stories:Bool can_delete_stories:Bool is_anonymous:Bool = ChatAdministratorRights;


//@description Describes a possibly non-integer amount of Telegram Stars
//@star_count The integer amount of Telegram Stars rounded to 0
//@nanostar_count The number of 1/1000000000 shares of Telegram Stars; from -999999999 to 999999999
starAmount star_count:int53 nanostar_count:int32 = StarAmount;


//@class StarSubscriptionType @description Describes type of subscription paid in Telegram Stars

//@description Describes a subscription to a channel chat
//@can_reuse True, if the subscription is active and the user can use the method reuseStarSubscription to join the subscribed chat again
//@invite_link The invite link that can be used to renew the subscription if it has been expired; may be empty, if the link isn't available anymore
starSubscriptionTypeChannel can_reuse:Bool invite_link:string = StarSubscriptionType;

//@description Describes a subscription in a bot or a business account
//@is_canceled_by_bot True, if the subscription was canceled by the bot and can't be extended
//@title Subscription invoice title
//@photo Subscription invoice photo
//@invoice_link The link to the subscription invoice
starSubscriptionTypeBot is_canceled_by_bot:Bool title:string photo:photo invoice_link:string = StarSubscriptionType;


//@description Describes subscription plan paid in Telegram Stars
//@period The number of seconds between consecutive Telegram Star debiting
//@star_count The amount of Telegram Stars that must be paid for each period
starSubscriptionPricing period:int32 star_count:int53 = StarSubscriptionPricing;

//@description Contains information about subscription to a channel chat, a bot, or a business account that was paid in Telegram Stars
//@id Unique identifier of the subscription
//@chat_id Identifier of the chat that is subscribed
//@expiration_date Point in time (Unix timestamp) when the subscription will expire or expired
//@is_canceled True, if the subscription was canceled
//@is_expiring True, if the subscription expires soon and there are no enough Telegram Stars on the user's balance to extend it
//@pricing The subscription plan
//@type Type of the subscription
starSubscription id:string chat_id:int53 expiration_date:int32 is_canceled:Bool is_expiring:Bool pricing:starSubscriptionPricing type:StarSubscriptionType = StarSubscription;

//@description Represents a list of Telegram Star subscriptions
//@star_amount The amount of owned Telegram Stars
//@subscriptions List of subscriptions for Telegram Stars
//@required_star_count The number of Telegram Stars required to buy to extend subscriptions expiring soon
//@next_offset The offset for the next request. If empty, then there are no more results
starSubscriptions star_amount:starAmount subscriptions:vector<starSubscription> required_star_count:int53 next_offset:string = StarSubscriptions;


//@class AffiliateType @description Describes type of affiliate for an affiliate program

//@description The affiliate is the current user
affiliateTypeCurrentUser = AffiliateType;

//@description The affiliate is a bot owned by the current user @user_id User identifier of the bot
affiliateTypeBot user_id:int53 = AffiliateType;

//@description The affiliate is a channel chat where the current user has can_post_messages administrator right @chat_id Identifier of the channel chat
affiliateTypeChannel chat_id:int53 = AffiliateType;


//@class AffiliateProgramSortOrder @description Describes the order of the found affiliate programs

//@description The affiliate programs must be sorted by the profitability
affiliateProgramSortOrderProfitability = AffiliateProgramSortOrder;

//@description The affiliate programs must be sorted by creation date
affiliateProgramSortOrderCreationDate = AffiliateProgramSortOrder;

//@description The affiliate programs must be sorted by the expected revenue
affiliateProgramSortOrderRevenue = AffiliateProgramSortOrder;


//@description Describes parameters of an affiliate program
//@commission_per_mille The number of Telegram Stars received by the affiliate for each 1000 Telegram Stars received by the program owner;
//-getOption("affiliate_program_commission_per_mille_min")-getOption("affiliate_program_commission_per_mille_max")
//@month_count Number of months the program will be active; 0-36. If 0, then the program is eternal
affiliateProgramParameters commission_per_mille:int32 month_count:int32 = AffiliateProgramParameters;

//@description Contains information about an active affiliate program
//@parameters Parameters of the affiliate program
//@end_date Point in time (Unix timestamp) when the affiliate program will be closed; 0 if the affiliate program isn't scheduled to be closed.
//-If positive, then the program can't be connected using connectAffiliateProgram, but active connections will work until the date
//@daily_revenue_per_user_amount The amount of daily revenue per user in Telegram Stars of the bot that created the affiliate program
affiliateProgramInfo parameters:affiliateProgramParameters end_date:int32 daily_revenue_per_user_amount:starAmount = AffiliateProgramInfo;

//@description Contains information about an affiliate that received commission from a Telegram Star transaction
//@commission_per_mille The number of Telegram Stars received by the affiliate for each 1000 Telegram Stars received by the program owner
//@affiliate_chat_id Identifier of the chat which received the commission
//@star_amount The amount of Telegram Stars that were received by the affiliate; can be negative for refunds
affiliateInfo commission_per_mille:int32 affiliate_chat_id:int53 star_amount:starAmount = AffiliateInfo;

//@description Describes a found affiliate program
//@bot_user_id User identifier of the bot created the program
//@info Information about the affiliate program
foundAffiliateProgram bot_user_id:int53 info:affiliateProgramInfo = FoundAffiliateProgram;

//@description Represents a list of found affiliate programs
//@total_count The total number of found affiliate programs
//@programs The list of affiliate programs
//@next_offset The offset for the next request. If empty, then there are no more results
foundAffiliatePrograms total_count:int32 programs:vector<foundAffiliateProgram> next_offset:string = FoundAffiliatePrograms;

//@description Describes an affiliate program that was connected to an affiliate
//@url The link that can be used to refer users if the program is still active
//@bot_user_id User identifier of the bot created the program
//@parameters The parameters of the affiliate program
//@connection_date Point in time (Unix timestamp) when the affiliate program was connected
//@is_disconnected True, if the program was canceled by the bot, or disconnected by the chat owner and isn't available anymore
//@user_count The number of users that used the affiliate program
//@revenue_star_count The number of Telegram Stars that were earned by the affiliate program
connectedAffiliateProgram url:string bot_user_id:int53 parameters:affiliateProgramParameters connection_date:int32 is_disconnected:Bool user_count:int64 revenue_star_count:int64 = ConnectedAffiliateProgram;

//@description Represents a list of affiliate programs that were connected to an affiliate
//@total_count The total number of affiliate programs that were connected to the affiliate
//@programs The list of connected affiliate programs
//@next_offset The offset for the next request. If empty, then there are no more results
connectedAffiliatePrograms total_count:int32 programs:vector<connectedAffiliateProgram> next_offset:string = ConnectedAffiliatePrograms;


//@description Contains information about a product that can be paid with invoice
//@title Product title
//@param_description Product description
//@photo Product photo; may be null
productInfo title:string description:formattedText photo:photo = ProductInfo;


//@description Describes an option for buying Telegram Premium to a user
//@currency ISO 4217 currency code for Telegram Premium subscription payment
//@amount The amount to pay, in the smallest units of the currency
//@discount_percentage The discount associated with this option, as a percentage
//@month_count Number of months the Telegram Premium subscription will be active. Use getPremiumInfoSticker to get the sticker to be used as representation of the Telegram Premium subscription
//@store_product_id Identifier of the store product associated with the option
//@payment_link An internal link to be opened for buying Telegram Premium to the user if store payment isn't possible; may be null if direct payment isn't available
premiumPaymentOption currency:string amount:int53 discount_percentage:int32 month_count:int32 store_product_id:string payment_link:InternalLinkType = PremiumPaymentOption;

//@description Describes an option for buying or upgrading Telegram Premium for self
//@payment_option Information about the payment option
//@is_current True, if this is the currently used Telegram Premium subscription option
//@is_upgrade True, if the payment option can be used to upgrade the existing Telegram Premium subscription
//@last_transaction_id Identifier of the last in-store transaction for the currently used option
premiumStatePaymentOption payment_option:premiumPaymentOption is_current:Bool is_upgrade:Bool last_transaction_id:string = PremiumStatePaymentOption;

//@description Describes an option for gifting Telegram Premium to a user. Use telegramPaymentPurposePremiumGift for out-of-store payments or payments in Telegram Stars
//@currency ISO 4217 currency code for the payment
//@amount The amount to pay, in the smallest units of the currency
//@star_count The alternative amount of Telegram Stars to pay; 0 if payment in Telegram Stars is not possible
//@discount_percentage The discount associated with this option, as a percentage
//@month_count Number of months the Telegram Premium subscription will be active
//@store_product_id Identifier of the store product associated with the option
//@sticker A sticker to be shown along with the option; may be null if unknown
premiumGiftPaymentOption currency:string amount:int53 star_count:int53 discount_percentage:int32 month_count:int32 store_product_id:string sticker:sticker = PremiumGiftPaymentOption;

//@description Contains a list of options for gifting Telegram Premium to a user @options The list of options sorted by Telegram Premium subscription duration
premiumGiftPaymentOptions options:vector<premiumGiftPaymentOption> = PremiumGiftPaymentOptions;

//@description Describes an option for creating of Telegram Premium giveaway or manual distribution of Telegram Premium among chat members. Use telegramPaymentPurposePremiumGiftCodes or telegramPaymentPurposePremiumGiveaway for out-of-store payments
//@currency ISO 4217 currency code for Telegram Premium gift code payment
//@amount The amount to pay, in the smallest units of the currency
//@winner_count Number of users which will be able to activate the gift codes
//@month_count Number of months the Telegram Premium subscription will be active
//@store_product_id Identifier of the store product associated with the option; may be empty if none
//@store_product_quantity Number of times the store product must be paid
premiumGiveawayPaymentOption currency:string amount:int53 winner_count:int32 month_count:int32 store_product_id:string store_product_quantity:int32 = PremiumGiveawayPaymentOption;

//@description Contains a list of options for creating of Telegram Premium giveaway or manual distribution of Telegram Premium among chat members @options The list of options
premiumGiveawayPaymentOptions options:vector<premiumGiveawayPaymentOption> = PremiumGiveawayPaymentOptions;

//@description Contains information about a Telegram Premium gift code
//@creator_id Identifier of a chat or a user that created the gift code; may be null if unknown. If null and the code is from messagePremiumGiftCode message, then creator_id from the message can be used
//@creation_date Point in time (Unix timestamp) when the code was created
//@is_from_giveaway True, if the gift code was created for a giveaway
//@giveaway_message_id Identifier of the corresponding giveaway message in the creator_id chat; can be 0 or an identifier of a deleted message
//@month_count Number of months the Telegram Premium subscription will be active after code activation
//@user_id Identifier of a user for which the code was created; 0 if none
//@use_date Point in time (Unix timestamp) when the code was activated; 0 if none
premiumGiftCodeInfo creator_id:MessageSender creation_date:int32 is_from_giveaway:Bool giveaway_message_id:int53 month_count:int32 user_id:int53 use_date:int32 = PremiumGiftCodeInfo;

//@description Describes an option for buying Telegram Stars. Use telegramPaymentPurposeStars for out-of-store payments
//@currency ISO 4217 currency code for the payment
//@amount The amount to pay, in the smallest units of the currency
//@star_count Number of Telegram Stars that will be purchased
//@store_product_id Identifier of the store product associated with the option; may be empty if none
//@is_additional True, if the option must be shown only in the full list of payment options
starPaymentOption currency:string amount:int53 star_count:int53 store_product_id:string is_additional:Bool = StarPaymentOption;

//@description Contains a list of options for buying Telegram Stars @options The list of options
starPaymentOptions options:vector<starPaymentOption> = StarPaymentOptions;

//@description Describes an option for the number of winners of a Telegram Star giveaway
//@winner_count The number of users that will be chosen as winners
//@won_star_count The number of Telegram Stars that will be won by the winners of the giveaway
//@is_default True, if the option must be chosen by default
starGiveawayWinnerOption winner_count:int32 won_star_count:int53 is_default:Bool = StarGiveawayWinnerOption;

//@description Describes an option for creating of Telegram Star giveaway. Use telegramPaymentPurposeStarGiveaway for out-of-store payments
//@currency ISO 4217 currency code for the payment
//@amount The amount to pay, in the smallest units of the currency
//@star_count Number of Telegram Stars that will be distributed among winners
//@store_product_id Identifier of the store product associated with the option; may be empty if none
//@yearly_boost_count Number of times the chat will be boosted for one year if the option is chosen
//@winner_options Allowed options for the number of giveaway winners
//@is_default True, if the option must be chosen by default
//@is_additional True, if the option must be shown only in the full list of payment options
starGiveawayPaymentOption currency:string amount:int53 star_count:int53 store_product_id:string yearly_boost_count:int32 winner_options:vector<starGiveawayWinnerOption> is_default:Bool is_additional:Bool = StarGiveawayPaymentOption;

//@description Contains a list of options for creating of Telegram Star giveaway @options The list of options
starGiveawayPaymentOptions options:vector<starGiveawayPaymentOption> = StarGiveawayPaymentOptions;


//@description Describes a model of an upgraded gift
//@name Name of the model
//@sticker The sticker representing the upgraded gift
//@rarity_per_mille The number of upgraded gift that receive this model for each 1000 gifts upgraded
upgradedGiftModel name:string sticker:sticker rarity_per_mille:int32 = UpgradedGiftModel;

//@description Describes a symbol shown on the pattern of an upgraded gift
//@name Name of the symbol
//@sticker The sticker representing the upgraded gift
//@rarity_per_mille The number of upgraded gift that receive this symbol for each 1000 gifts upgraded
upgradedGiftSymbol name:string sticker:sticker rarity_per_mille:int32 = UpgradedGiftSymbol;

//@description Describes colors of a backdrop of an upgraded gift
//@center_color A color in the center of the backdrop in the RGB format
//@edge_color A color on the edges of the backdrop in the RGB format
//@symbol_color A color to be applied for the symbol in the RGB format
//@text_color A color for the text on the backdrop in the RGB format
upgradedGiftBackdropColors center_color:int32 edge_color:int32 symbol_color:int32 text_color:int32 = UpgradedGiftBackdropColors;

//@description Describes a backdrop of an upgraded gift
//@name Name of the backdrop
//@colors Colors of the backdrop
//@rarity_per_mille The number of upgraded gift that receive this backdrop for each 1000 gifts upgraded
upgradedGiftBackdrop name:string colors:upgradedGiftBackdropColors rarity_per_mille:int32 = UpgradedGiftBackdrop;

//@description Describes the original details about the gift
//@sender_id Identifier of the user or the chat that sent the gift; may be null if the gift was private
//@receiver_id Identifier of the user or the chat that received the gift
//@text Message added to the gift
//@date Point in time (Unix timestamp) when the gift was sent
upgradedGiftOriginalDetails sender_id:MessageSender receiver_id:MessageSender text:formattedText date:int32 = UpgradedGiftOriginalDetails;

//@description Describes a gift that can be sent to another user or channel chat
//@id Unique identifier of the gift
//@sticker The sticker representing the gift
//@star_count Number of Telegram Stars that must be paid for the gift
//@default_sell_star_count Number of Telegram Stars that can be claimed by the receiver instead of the regular gift by default. If the gift was paid with just bought Telegram Stars, then full value can be claimed
//@upgrade_star_count Number of Telegram Stars that must be paid to upgrade the gift; 0 if upgrade isn't possible
//@is_for_birthday True, if the gift is a birthday gift
//@remaining_count Number of remaining times the gift can be purchased; 0 if not limited or the gift was sold out
//@total_count Number of total times the gift can be purchased; 0 if not limited
//@first_send_date Point in time (Unix timestamp) when the gift was send for the first time; for sold out gifts only
//@last_send_date Point in time (Unix timestamp) when the gift was send for the last time; for sold out gifts only
gift id:int64 sticker:sticker star_count:int53 default_sell_star_count:int53 upgrade_star_count:int53 is_for_birthday:Bool remaining_count:int32 total_count:int32 first_send_date:int32 last_send_date:int32 = Gift;

//@description Contains a list of gifts that can be sent to another user or channel chat @gifts The list of gifts
gifts gifts:vector<gift> = Gifts;

//@description Describes an upgraded gift that can be transferred to another owner or transferred to the TON blockchain as an NFT
//@id Unique identifier of the gift
//@title The title of the upgraded gift
//@name Unique name of the upgraded gift that can be used with internalLinkTypeUpgradedGift
//@number Unique number of the upgraded gift among gifts upgraded from the same gift
//@total_upgraded_count Total number of gifts that were upgraded from the same gift
//@max_upgraded_count The maximum number of gifts that can be upgraded from the same gift
//@owner_id Identifier of the user or the chat that owns the upgraded gift; may be null if none or unknown
//@owner_address Address of the gift NFT owner in TON blockchain; may be empty if none
//@owner_name Name of the owner for the case when owner identifier and address aren't known
//@gift_address Address of the gift NFT in TON blockchain; may be empty if none
//@model Model of the upgraded gift
//@symbol Symbol of the upgraded gift
//@backdrop Backdrop of the upgraded gift
//@original_details Information about the originally sent gift; may be null if unknown
upgradedGift id:int64 title:string name:string number:int32 total_upgraded_count:int32 max_upgraded_count:int32 owner_id:MessageSender owner_address:string owner_name:string gift_address:string model:upgradedGiftModel symbol:upgradedGiftSymbol backdrop:upgradedGiftBackdrop original_details:upgradedGiftOriginalDetails = UpgradedGift;

//@description Contains result of gift upgrading
//@gift The upgraded gift
//@received_gift_id Unique identifier of the received gift for the current user
//@is_saved True, if the gift is displayed on the user's or the channel's profile page
//@can_be_transferred True, if the gift can be transferred to another owner
//@transfer_star_count Number of Telegram Stars that must be paid to transfer the upgraded gift
//@export_date Point in time (Unix timestamp) when the gift can be transferred to the TON blockchain as an NFT
upgradeGiftResult gift:upgradedGift received_gift_id:string is_saved:Bool can_be_transferred:Bool transfer_star_count:int53 export_date:int32 = UpgradeGiftResult;


//@class SentGift @description Represents content of a gift received by a user or a channel chat

//@description Regular gift @gift The gift
sentGiftRegular gift:gift = SentGift;

//@description Upgraded gift @gift The gift
sentGiftUpgraded gift:upgradedGift = SentGift;


//@description Represents a gift received by a user or a chat
//@received_gift_id Unique identifier of the received gift for the current user; only for the receiver of the gift
//@sender_id Identifier of a user or a chat that sent the gift; may be null if unknown
//@text Message added to the gift
//@is_private True, if the sender and gift text are shown only to the gift receiver; otherwise, everyone are able to see them
//@is_saved True, if the gift is displayed on the chat's profile page; only for the receiver of the gift
//@is_pinned True, if the gift is pinned to the top of the chat's profile page
//@can_be_upgraded True, if the gift is a regular gift that can be upgraded to a unique gift; only for the receiver of the gift
//@can_be_transferred True, if the gift is an upgraded gift that can be transferred to another owner; only for the receiver of the gift
//@was_refunded True, if the gift was refunded and isn't available anymore
//@date Point in time (Unix timestamp) when the gift was sent
//@gift The gift
//@sell_star_count Number of Telegram Stars that can be claimed by the receiver instead of the regular gift; 0 if the gift can't be sold by the current user
//@prepaid_upgrade_star_count Number of Telegram Stars that were paid by the sender for the ability to upgrade the gift
//@transfer_star_count Number of Telegram Stars that must be paid to transfer the upgraded gift; only for the receiver of the gift
//@export_date Point in time (Unix timestamp) when the upgraded gift can be transferred to the TON blockchain as an NFT; 0 if NFT export isn't possible; only for the receiver of the gift
receivedGift received_gift_id:string sender_id:MessageSender text:formattedText is_private:Bool is_saved:Bool is_pinned:Bool can_be_upgraded:Bool can_be_transferred:Bool was_refunded:Bool date:int32 gift:SentGift sell_star_count:int53 prepaid_upgrade_star_count:int53 transfer_star_count:int53 export_date:int32 = ReceivedGift;

//@description Represents a list of gifts received by a user or a chat
//@total_count The total number of received gifts
//@gifts The list of gifts
//@are_notifications_enabled True, if notifications about new gifts of the owner are enabled
//@next_offset The offset for the next request. If empty, then there are no more results
receivedGifts total_count:int32 gifts:vector<receivedGift> are_notifications_enabled:Bool next_offset:string = ReceivedGifts;

//@description Contains examples of possible upgraded gifts for the given regular gift
//@models Examples of possible models that can be chosen for the gift after upgrade
//@symbols Examples of possible symbols that can be chosen for the gift after upgrade
//@backdrops Examples of possible backdrops that can be chosen for the gift after upgrade
giftUpgradePreview models:vector<upgradedGiftModel> symbols:vector<upgradedGiftSymbol> backdrops:vector<upgradedGiftBackdrop> = GiftUpgradePreview;


//@class StarTransactionDirection @description Describes direction of a transaction with Telegram Stars

//@description The transaction is incoming and increases the number of owned Telegram Stars
starTransactionDirectionIncoming = StarTransactionDirection;

//@description The transaction is outgoing and decreases the number of owned Telegram Stars
starTransactionDirectionOutgoing = StarTransactionDirection;


//@class StarTransactionType @description Describes type of transaction with Telegram Stars

//@description The transaction is a deposit of Telegram Stars from the Premium bot; for regular users only
starTransactionTypePremiumBotDeposit = StarTransactionType;

//@description The transaction is a deposit of Telegram Stars from App Store; for regular users only
starTransactionTypeAppStoreDeposit = StarTransactionType;

//@description The transaction is a deposit of Telegram Stars from Google Play; for regular users only
starTransactionTypeGooglePlayDeposit = StarTransactionType;

//@description The transaction is a deposit of Telegram Stars from Fragment; for regular users and bots only
starTransactionTypeFragmentDeposit = StarTransactionType;

//@description The transaction is a deposit of Telegram Stars by another user; for regular users only
//@user_id Identifier of the user that gifted Telegram Stars; 0 if the user was anonymous
//@sticker The sticker to be shown in the transaction information; may be null if unknown
starTransactionTypeUserDeposit user_id:int53 sticker:sticker = StarTransactionType;

//@description The transaction is a deposit of Telegram Stars from a giveaway; for regular users only
//@chat_id Identifier of a supergroup or a channel chat that created the giveaway
//@giveaway_message_id Identifier of the message with the giveaway; can be 0 or an identifier of a deleted message
starTransactionTypeGiveawayDeposit chat_id:int53 giveaway_message_id:int53 = StarTransactionType;

//@description The transaction is a withdrawal of earned Telegram Stars to Fragment; for regular users, bots, supergroup and channel chats only
//@withdrawal_state State of the withdrawal; may be null for refunds from Fragment
starTransactionTypeFragmentWithdrawal withdrawal_state:RevenueWithdrawalState = StarTransactionType;

//@description The transaction is a withdrawal of earned Telegram Stars to Telegram Ad platform; for bots and channel chats only
starTransactionTypeTelegramAdsWithdrawal = StarTransactionType;

//@description The transaction is a payment for Telegram API usage; for bots only @request_count The number of billed requests
starTransactionTypeTelegramApiUsage request_count:int32 = StarTransactionType;

//@description The transaction is a purchase of paid media from a bot or a business account by the current user; for regular users only
//@user_id Identifier of the bot or the business account user that sent the paid media
//@media The bought media if the transaction wasn't refunded
starTransactionTypeBotPaidMediaPurchase user_id:int53 media:vector<PaidMedia> = StarTransactionType;

//@description The transaction is a sale of paid media by the bot or a business account managed by the bot; for bots only
//@user_id Identifier of the user that bought the media
//@media The bought media
//@payload Bot-provided payload
//@affiliate Information about the affiliate which received commission from the transaction; may be null if none
starTransactionTypeBotPaidMediaSale user_id:int53 media:vector<PaidMedia> payload:string affiliate:affiliateInfo = StarTransactionType;

//@description The transaction is a purchase of paid media from a channel by the current user; for regular users only
//@chat_id Identifier of the channel chat that sent the paid media
//@message_id Identifier of the corresponding message with paid media; can be 0 or an identifier of a deleted message
//@media The bought media if the transaction wasn't refunded
starTransactionTypeChannelPaidMediaPurchase chat_id:int53 message_id:int53 media:vector<PaidMedia> = StarTransactionType;

//@description The transaction is a sale of paid media by the channel chat; for channel chats only
//@user_id Identifier of the user that bought the media
//@message_id Identifier of the corresponding message with paid media; can be 0 or an identifier of a deleted message
//@media The bought media
starTransactionTypeChannelPaidMediaSale user_id:int53 message_id:int53 media:vector<PaidMedia> = StarTransactionType;

//@description The transaction is a purchase of a product from a bot or a business account by the current user; for regular users only
//@user_id Identifier of the bot or the business account user that created the invoice
//@product_info Information about the bought product
starTransactionTypeBotInvoicePurchase user_id:int53 product_info:productInfo = StarTransactionType;

//@description The transaction is a sale of a product by the bot; for bots only
//@user_id Identifier of the user that bought the product
//@product_info Information about the bought product
//@invoice_payload Invoice payload
//@affiliate Information about the affiliate which received commission from the transaction; may be null if none
starTransactionTypeBotInvoiceSale user_id:int53 product_info:productInfo invoice_payload:bytes affiliate:affiliateInfo = StarTransactionType;

//@description The transaction is a purchase of a subscription from a bot or a business account by the current user; for regular users only
//@user_id Identifier of the bot or the business account user that created the subscription link
//@subscription_period The number of seconds between consecutive Telegram Star debitings
//@product_info Information about the bought subscription
starTransactionTypeBotSubscriptionPurchase user_id:int53 subscription_period:int32 product_info:productInfo = StarTransactionType;

//@description The transaction is a sale of a subscription by the bot; for bots only
//@user_id Identifier of the user that bought the subscription
//@subscription_period The number of seconds between consecutive Telegram Star debitings
//@product_info Information about the bought subscription
//@invoice_payload Invoice payload
//@affiliate Information about the affiliate which received commission from the transaction; may be null if none
starTransactionTypeBotSubscriptionSale user_id:int53 subscription_period:int32 product_info:productInfo invoice_payload:bytes affiliate:affiliateInfo = StarTransactionType;

//@description The transaction is a purchase of a subscription to a channel chat by the current user; for regular users only
//@chat_id Identifier of the channel chat that created the subscription
//@subscription_period The number of seconds between consecutive Telegram Star debitings
starTransactionTypeChannelSubscriptionPurchase chat_id:int53 subscription_period:int32 = StarTransactionType;

//@description The transaction is a sale of a subscription by the channel chat; for channel chats only
//@user_id Identifier of the user that bought the subscription
//@subscription_period The number of seconds between consecutive Telegram Star debitings
starTransactionTypeChannelSubscriptionSale user_id:int53 subscription_period:int32 = StarTransactionType;

//@description The transaction is a purchase of a regular gift; for regular users and bots only @owner_id Identifier of the user or the channel that received the gift @gift The gift
starTransactionTypeGiftPurchase owner_id:MessageSender gift:gift = StarTransactionType;

//@description The transaction is a transfer of an upgraded gift; for regular users only @owner_id Identifier of the user or the channel that received the gift @gift The gift
starTransactionTypeGiftTransfer owner_id:MessageSender gift:upgradedGift = StarTransactionType;

//@description The transaction is a sale of a received gift; for regular users and channel chats only @user_id Identifier of the user that sent the gift @gift The gift
starTransactionTypeGiftSale user_id:int53 gift:gift = StarTransactionType;

//@description The transaction is an upgrade of a gift; for regular users only @user_id Identifier of the user that initially sent the gift @gift The upgraded gift
starTransactionTypeGiftUpgrade user_id:int53 gift:upgradedGift = StarTransactionType;

//@description The transaction is a sending of a paid reaction to a message in a channel chat by the current user; for regular users only
//@chat_id Identifier of the channel chat
//@message_id Identifier of the reacted message; can be 0 or an identifier of a deleted message
starTransactionTypeChannelPaidReactionSend chat_id:int53 message_id:int53 = StarTransactionType;

//@description The transaction is a receiving of a paid reaction to a message by the channel chat; for channel chats only
//@user_id Identifier of the user that added the paid reaction
//@message_id Identifier of the reacted message; can be 0 or an identifier of a deleted message
starTransactionTypeChannelPaidReactionReceive user_id:int53 message_id:int53 = StarTransactionType;

//@description The transaction is a receiving of a commission from an affiliate program; for regular users, bots and channel chats only
//@chat_id Identifier of the chat that created the affiliate program
//@commission_per_mille The number of Telegram Stars received by the affiliate for each 1000 Telegram Stars received by the program owner
starTransactionTypeAffiliateProgramCommission chat_id:int53 commission_per_mille:int32 = StarTransactionType;

//@description The transaction is a sending of a paid message; for regular users only @chat_id Identifier of the chat that received the payment @message_count Number of sent paid messages
starTransactionTypePaidMessageSend chat_id:int53 message_count:int32 = StarTransactionType;

//@description The transaction is a receiving of a paid message; for regular users and supergroup chats only
//@sender_id Identifier of the sender of the message
//@message_count Number of received paid messages
//@commission_per_mille The number of Telegram Stars received by the Telegram for each 1000 Telegram Stars paid for message sending
//@commission_star_amount The amount of Telegram Stars that were received by Telegram; can be negative for refunds
starTransactionTypePaidMessageReceive sender_id:MessageSender message_count:int32 commission_per_mille:int32 commission_star_amount:starAmount = StarTransactionType;

//@description The transaction is a purchase of Telegram Premium subscription; for regular users only
//@user_id Identifier of the user that received the Telegram Premium subscription
//@month_count Number of months the Telegram Premium subscription will be active
//@sticker A sticker to be shown in the transaction information; may be null if unknown
starTransactionTypePremiumPurchase user_id:int53 month_count:int32 sticker:sticker = StarTransactionType;

//@description The transaction is a transaction of an unsupported type
starTransactionTypeUnsupported = StarTransactionType;


//@description Represents a transaction changing the amount of owned Telegram Stars
//@id Unique identifier of the transaction
//@star_amount The amount of added owned Telegram Stars; negative for outgoing transactions
//@is_refund True, if the transaction is a refund of a previous transaction
//@date Point in time (Unix timestamp) when the transaction was completed
//@type Type of the transaction
starTransaction id:string star_amount:starAmount is_refund:Bool date:int32 type:StarTransactionType = StarTransaction;

//@description Represents a list of Telegram Star transactions
//@star_amount The amount of owned Telegram Stars
//@transactions List of transactions with Telegram Stars
//@next_offset The offset for the next request. If empty, then there are no more results
starTransactions star_amount:starAmount transactions:vector<starTransaction> next_offset:string = StarTransactions;


//@class GiveawayParticipantStatus @description Contains information about status of a user in a giveaway

//@description The user is eligible for the giveaway
giveawayParticipantStatusEligible = GiveawayParticipantStatus;

//@description The user participates in the giveaway
giveawayParticipantStatusParticipating = GiveawayParticipantStatus;

//@description The user can't participate in the giveaway, because they have already been member of the chat
//@joined_chat_date Point in time (Unix timestamp) when the user joined the chat
giveawayParticipantStatusAlreadyWasMember joined_chat_date:int32 = GiveawayParticipantStatus;

//@description The user can't participate in the giveaway, because they are an administrator in one of the chats that created the giveaway @chat_id Identifier of the chat administered by the user
giveawayParticipantStatusAdministrator chat_id:int53 = GiveawayParticipantStatus;

//@description The user can't participate in the giveaway, because they phone number is from a disallowed country @user_country_code A two-letter ISO 3166-1 alpha-2 country code of the user's country
giveawayParticipantStatusDisallowedCountry user_country_code:string = GiveawayParticipantStatus;


//@class GiveawayInfo @description Contains information about a giveaway

//@description Describes an ongoing giveaway
//@creation_date Point in time (Unix timestamp) when the giveaway was created
//@status Status of the current user in the giveaway
//@is_ended True, if the giveaway has ended and results are being prepared
giveawayInfoOngoing creation_date:int32 status:GiveawayParticipantStatus is_ended:Bool = GiveawayInfo;

//@description Describes a completed giveaway
//@creation_date Point in time (Unix timestamp) when the giveaway was created
//@actual_winners_selection_date Point in time (Unix timestamp) when the winners were selected. May be bigger than winners selection date specified in parameters of the giveaway
//@was_refunded True, if the giveaway was canceled and was fully refunded
//@is_winner True, if the current user is a winner of the giveaway
//@winner_count Number of winners in the giveaway
//@activation_count Number of winners, which activated their gift codes; for Telegram Premium giveaways only
//@gift_code Telegram Premium gift code that was received by the current user; empty if the user isn't a winner in the giveaway or the giveaway isn't a Telegram Premium giveaway
//@won_star_count The amount of Telegram Stars won by the current user; 0 if the user isn't a winner in the giveaway or the giveaway isn't a Telegram Star giveaway
giveawayInfoCompleted creation_date:int32 actual_winners_selection_date:int32 was_refunded:Bool is_winner:Bool winner_count:int32 activation_count:int32 gift_code:string won_star_count:int53 = GiveawayInfo;


//@class GiveawayPrize @description Contains information about a giveaway prize

//@description The giveaway sends Telegram Premium subscriptions to the winners @month_count Number of months the Telegram Premium subscription will be active after code activation
giveawayPrizePremium month_count:int32 = GiveawayPrize;

//@description The giveaway sends Telegram Stars to the winners @star_count Number of Telegram Stars that will be shared by all winners
giveawayPrizeStars star_count:int53 = GiveawayPrize;


//@description Contains information about supported accent color for user/chat name, background of empty chat photo, replies to messages and link previews
//@id Accent color identifier
//@built_in_accent_color_id Identifier of a built-in color to use in places, where only one color is needed; 0-6
//@light_theme_colors The list of 1-3 colors in RGB format, describing the accent color, as expected to be shown in light themes
//@dark_theme_colors The list of 1-3 colors in RGB format, describing the accent color, as expected to be shown in dark themes
//@min_channel_chat_boost_level The minimum chat boost level required to use the color in a channel chat
accentColor id:int32 built_in_accent_color_id:int32 light_theme_colors:vector<int32> dark_theme_colors:vector<int32> min_channel_chat_boost_level:int32 = AccentColor;

//@description Contains information about supported accent colors for user profile photo background in RGB format
//@palette_colors The list of 1-2 colors in RGB format, describing the colors, as expected to be shown in the color palette settings
//@background_colors The list of 1-2 colors in RGB format, describing the colors, as expected to be used for the profile photo background
//@story_colors The list of 2 colors in RGB format, describing the colors of the gradient to be used for the unread active story indicator around profile photo
profileAccentColors palette_colors:vector<int32> background_colors:vector<int32> story_colors:vector<int32> = ProfileAccentColors;

//@description Contains information about supported accent color for user profile photo background
//@id Profile accent color identifier
//@light_theme_colors Accent colors expected to be used in light themes
//@dark_theme_colors Accent colors expected to be used in dark themes
//@min_supergroup_chat_boost_level The minimum chat boost level required to use the color in a supergroup chat
//@min_channel_chat_boost_level The minimum chat boost level required to use the color in a channel chat
profileAccentColor id:int32 light_theme_colors:profileAccentColors dark_theme_colors:profileAccentColors min_supergroup_chat_boost_level:int32 min_channel_chat_boost_level:int32 = ProfileAccentColor;


//@class EmojiStatusType @description Describes type of emoji status

//@description A custom emoji set as emoji status @custom_emoji_id Identifier of the custom emoji in stickerFormatTgs format
emojiStatusTypeCustomEmoji custom_emoji_id:int64 = EmojiStatusType;

//@description An upgraded gift set as emoji status
//@upgraded_gift_id Identifier of the upgraded gift
//@gift_title The title of the upgraded gift
//@gift_name Unique name of the upgraded gift that can be used with internalLinkTypeUpgradedGift
//@model_custom_emoji_id Custom emoji identifier of the model of the upgraded gift
//@symbol_custom_emoji_id Custom emoji identifier of the symbol of the upgraded gift
//@backdrop_colors Colors of the backdrop of the upgraded gift
emojiStatusTypeUpgradedGift upgraded_gift_id:int64 gift_title:string gift_name:string model_custom_emoji_id:int64 symbol_custom_emoji_id:int64 backdrop_colors:upgradedGiftBackdropColors = EmojiStatusType;


//@description Describes an emoji to be shown instead of the Telegram Premium badge
//@type Type of the emoji status
//@expiration_date Point in time (Unix timestamp) when the status will expire; 0 if never
emojiStatus type:EmojiStatusType expiration_date:int32 = EmojiStatus;

//@description Contains a list of emoji statuses @emoji_statuses The list of emoji statuses identifiers
emojiStatuses emoji_statuses:vector<emojiStatus> = EmojiStatuses;

//@description Contains a list of custom emoji identifiers for emoji statuses @custom_emoji_ids The list of custom emoji identifiers
emojiStatusCustomEmojis custom_emoji_ids:vector<int64> = EmojiStatusCustomEmojis;


//@description Describes usernames assigned to a user, a supergroup, or a channel
//@active_usernames List of active usernames; the first one must be shown as the primary username. The order of active usernames can be changed with reorderActiveUsernames, reorderBotActiveUsernames or reorderSupergroupActiveUsernames
//@disabled_usernames List of currently disabled usernames; the username can be activated with toggleUsernameIsActive, toggleBotUsernameIsActive, or toggleSupergroupUsernameIsActive
//@editable_username The active username, which can be changed with setUsername or setSupergroupUsername. Information about other active usernames can be received using getCollectibleItemInfo
usernames active_usernames:vector<string> disabled_usernames:vector<string> editable_username:string = Usernames;


//@description Represents a user
//@id User identifier
//@first_name First name of the user
//@last_name Last name of the user
//@usernames Usernames of the user; may be null
//@phone_number Phone number of the user
//@status Current online status of the user
//@profile_photo Profile photo of the user; may be null
//@accent_color_id Identifier of the accent color for name, and backgrounds of profile photo, reply header, and link preview
//@background_custom_emoji_id Identifier of a custom emoji to be shown on the reply header and link preview background; 0 if none
//@profile_accent_color_id Identifier of the accent color for the user's profile; -1 if none
//@profile_background_custom_emoji_id Identifier of a custom emoji to be shown on the background of the user's profile; 0 if none
//@emoji_status Emoji status to be shown instead of the default Telegram Premium badge; may be null
//@is_contact The user is a contact of the current user
//@is_mutual_contact The user is a contact of the current user and the current user is a contact of the user
//@is_close_friend The user is a close friend of the current user; implies that the user is a contact
//@verification_status Information about verification status of the user; may be null if none
//@is_premium True, if the user is a Telegram Premium user
//@is_support True, if the user is Telegram support account
//@restriction_reason If non-empty, it contains a human-readable description of the reason why access to this user must be restricted
//@has_active_stories True, if the user has non-expired stories available to the current user
//@has_unread_active_stories True, if the user has unread non-expired stories available to the current user
//@restricts_new_chats True, if the user may restrict new chats with non-contacts. Use canSendMessageToUser to check whether the current user can message the user or try to create a chat with them
//@paid_message_star_count Number of Telegram Stars that must be paid by general user for each sent message to the user. If positive and userFullInfo is unknown, use canSendMessageToUser to check whether the current user must pay
//@have_access If false, the user is inaccessible, and the only information known about the user is inside this class. Identifier of the user can't be passed to any method
//@type Type of the user
//@language_code IETF language tag of the user's language; only available to bots
//@added_to_attachment_menu True, if the user added the current bot to attachment menu; only available to bots
user id:int53 first_name:string last_name:string usernames:usernames phone_number:string status:UserStatus profile_photo:profilePhoto accent_color_id:int32 background_custom_emoji_id:int64 profile_accent_color_id:int32 profile_background_custom_emoji_id:int64 emoji_status:emojiStatus is_contact:Bool is_mutual_contact:Bool is_close_friend:Bool verification_status:verificationStatus is_premium:Bool is_support:Bool restriction_reason:string has_active_stories:Bool has_unread_active_stories:Bool restricts_new_chats:Bool paid_message_star_count:int53 have_access:Bool type:UserType language_code:string added_to_attachment_menu:Bool = User;


//@description Contains information about a bot
//@short_description The text that is shown on the bot's profile page and is sent together with the link when users share the bot
//@param_description The text shown in the chat with the bot if the chat is empty
//@photo Photo shown in the chat with the bot if the chat is empty; may be null
//@animation Animation shown in the chat with the bot if the chat is empty; may be null
//@menu_button Information about a button to show instead of the bot commands menu button; may be null if ordinary bot commands menu must be shown
//@commands List of the bot commands
//@privacy_policy_url The HTTP link to the privacy policy of the bot. If empty, then /privacy command must be used if supported by the bot. If the command isn't supported, then https://telegram.org/privacy-tpa must be opened
//@default_group_administrator_rights Default administrator rights for adding the bot to basic group and supergroup chats; may be null
//@default_channel_administrator_rights Default administrator rights for adding the bot to channels; may be null
//@affiliate_program Information about the affiliate program of the bot; may be null if none
//@web_app_background_light_color Default light background color for bot Web Apps; -1 if not specified
//@web_app_background_dark_color Default dark background color for bot Web Apps; -1 if not specified
//@web_app_header_light_color Default light header color for bot Web Apps; -1 if not specified
//@web_app_header_dark_color Default dark header color for bot Web Apps; -1 if not specified
//@verification_parameters Parameters of the verification that can be provided by the bot; may be null if none or the current user isn't the owner of the bot
//@can_get_revenue_statistics True, if the bot's revenue statistics are available to the current user
//@can_manage_emoji_status True, if the bot can manage emoji status of the current user
//@has_media_previews True, if the bot has media previews
//@edit_commands_link The internal link, which can be used to edit bot commands; may be null
//@edit_description_link The internal link, which can be used to edit bot description; may be null
//@edit_description_media_link The internal link, which can be used to edit the photo or animation shown in the chat with the bot if the chat is empty; may be null
//@edit_settings_link The internal link, which can be used to edit bot settings; may be null
botInfo short_description:string description:string photo:photo animation:animation menu_button:botMenuButton commands:vector<botCommand> privacy_policy_url:string default_group_administrator_rights:chatAdministratorRights default_channel_administrator_rights:chatAdministratorRights affiliate_program:affiliateProgramInfo web_app_background_light_color:int32 web_app_background_dark_color:int32 web_app_header_light_color:int32 web_app_header_dark_color:int32 verification_parameters:botVerificationParameters can_get_revenue_statistics:Bool can_manage_emoji_status:Bool has_media_previews:Bool edit_commands_link:InternalLinkType edit_description_link:InternalLinkType edit_description_media_link:InternalLinkType edit_settings_link:InternalLinkType = BotInfo;

//@description Contains full information about a user
//@personal_photo User profile photo set by the current user for the contact; may be null. If null and user.profile_photo is null, then the photo is empty; otherwise, it is unknown.
//-If non-null, then it is the same photo as in user.profile_photo and chat.photo. This photo isn't returned in the list of user photos
//@photo User profile photo; may be null. If null and user.profile_photo is null, then the photo is empty; otherwise, it is unknown.
//-If non-null and personal_photo is null, then it is the same photo as in user.profile_photo and chat.photo
//@public_photo User profile photo visible if the main photo is hidden by privacy settings; may be null. If null and user.profile_photo is null, then the photo is empty; otherwise, it is unknown.
//-If non-null and both photo and personal_photo are null, then it is the same photo as in user.profile_photo and chat.photo. This photo isn't returned in the list of user photos
//@block_list Block list to which the user is added; may be null if none
//@can_be_called True, if the user can be called
//@supports_video_calls True, if a video call can be created with the user
//@has_private_calls True, if the user can't be called due to their privacy settings
//@has_private_forwards True, if the user can't be linked in forwarded messages due to their privacy settings
//@has_restricted_voice_and_video_note_messages True, if voice and video notes can't be sent or forwarded to the user
//@has_posted_to_profile_stories True, if the user has posted to profile stories
//@has_sponsored_messages_enabled True, if the user always enabled sponsored messages; known only for the current user
//@need_phone_number_privacy_exception True, if the current user needs to explicitly allow to share their phone number with the user when the method addContact is used
//@set_chat_background True, if the user set chat background for both chat users and it wasn't reverted yet
//@bio A short user bio; may be null for bots
//@birthdate Birthdate of the user; may be null if unknown
//@personal_chat_id Identifier of the personal chat of the user; 0 if none
//@gift_count Number of saved to profile gifts for other users or the total number of received gifts for the current user
//@group_in_common_count Number of group chats where both the other user and the current user are a member; 0 for the current user
//@incoming_paid_message_star_count Number of Telegram Stars that must be paid by the user for each sent message to the current user
//@outgoing_paid_message_star_count Number of Telegram Stars that must be paid by the current user for each sent message to the user
//@bot_verification Information about verification status of the user provided by a bot; may be null if none or unknown
//@business_info Information about business settings for Telegram Business accounts; may be null if none
//@bot_info For bots, information about the bot; may be null if the user isn't a bot
userFullInfo personal_photo:chatPhoto photo:chatPhoto public_photo:chatPhoto block_list:BlockList can_be_called:Bool supports_video_calls:Bool has_private_calls:Bool has_private_forwards:Bool has_restricted_voice_and_video_note_messages:Bool has_posted_to_profile_stories:Bool has_sponsored_messages_enabled:Bool need_phone_number_privacy_exception:Bool set_chat_background:Bool bio:formattedText birthdate:birthdate personal_chat_id:int53 gift_count:int32 group_in_common_count:int32 incoming_paid_message_star_count:int53 outgoing_paid_message_star_count:int53 bot_verification:botVerification business_info:businessInfo bot_info:botInfo = UserFullInfo;

//@description Represents a list of users @total_count Approximate total number of users found @user_ids A list of user identifiers
users total_count:int32 user_ids:vector<int53> = Users;

//@description Represents a list of found users @user_ids Identifiers of the found users @next_offset The offset for the next request. If empty, then there are no more results
foundUsers user_ids:vector<int53> next_offset:string = FoundUsers;


//@description Contains information about a chat administrator @user_id User identifier of the administrator @custom_title Custom title of the administrator @is_owner True, if the user is the owner of the chat
chatAdministrator user_id:int53 custom_title:string is_owner:Bool = ChatAdministrator;

//@description Represents a list of chat administrators @administrators A list of chat administrators
chatAdministrators administrators:vector<chatAdministrator> = ChatAdministrators;


//@class ChatMemberStatus @description Provides information about the status of a member in a chat

//@description The user is the owner of the chat and has all the administrator privileges
//@custom_title A custom title of the owner; 0-16 characters without emoji; applicable to supergroups only
//@is_anonymous True, if the creator isn't shown in the chat member list and sends messages anonymously; applicable to supergroups only
//@is_member True, if the user is a member of the chat
chatMemberStatusCreator custom_title:string is_anonymous:Bool is_member:Bool = ChatMemberStatus;

//@description The user is a member of the chat and has some additional privileges. In basic groups, administrators can edit and delete messages sent by others, add new members, ban unprivileged members, and manage video chats.
//-In supergroups and channels, there are more detailed options for administrator privileges
//@custom_title A custom title of the administrator; 0-16 characters without emoji; applicable to supergroups only
//@can_be_edited True, if the current user can edit the administrator privileges for the called user
//@rights Rights of the administrator
chatMemberStatusAdministrator custom_title:string can_be_edited:Bool rights:chatAdministratorRights = ChatMemberStatus;

//@description The user is a member of the chat, without any additional privileges or restrictions
//@member_until_date Point in time (Unix timestamp) when the user will be removed from the chat because of the expired subscription; 0 if never. Ignored in setChatMemberStatus
chatMemberStatusMember member_until_date:int32 = ChatMemberStatus;

//@description The user is under certain restrictions in the chat. Not supported in basic groups and channels
//@is_member True, if the user is a member of the chat
//@restricted_until_date Point in time (Unix timestamp) when restrictions will be lifted from the user; 0 if never. If the user is restricted for more than 366 days or for less than 30 seconds from the current time, the user is considered to be restricted forever
//@permissions User permissions in the chat
chatMemberStatusRestricted is_member:Bool restricted_until_date:int32 permissions:chatPermissions = ChatMemberStatus;

//@description The user or the chat is not a chat member
chatMemberStatusLeft = ChatMemberStatus;

//@description The user or the chat was banned (and hence is not a member of the chat). Implies the user can't return to the chat, view messages, or be used as a participant identifier to join a video chat of the chat
//@banned_until_date Point in time (Unix timestamp) when the user will be unbanned; 0 if never. If the user is banned for more than 366 days or for less than 30 seconds from the current time, the user is considered to be banned forever. Always 0 in basic groups
chatMemberStatusBanned banned_until_date:int32 = ChatMemberStatus;


//@description Describes a user or a chat as a member of another chat
//@member_id Identifier of the chat member. Currently, other chats can be only Left or Banned. Only supergroups and channels can have other chats as Left or Banned members and these chats must be supergroups or channels
//@inviter_user_id Identifier of a user that invited/promoted/banned this member in the chat; 0 if unknown
//@joined_chat_date Point in time (Unix timestamp) when the user joined/was promoted/was banned in the chat
//@status Status of the member in the chat
chatMember member_id:MessageSender inviter_user_id:int53 joined_chat_date:int32 status:ChatMemberStatus = ChatMember;

//@description Contains a list of chat members @total_count Approximate total number of chat members found @members A list of chat members
chatMembers total_count:int32 members:vector<chatMember> = ChatMembers;


//@class ChatMembersFilter @description Specifies the kind of chat members to return in searchChatMembers

//@description Returns contacts of the user
chatMembersFilterContacts = ChatMembersFilter;

//@description Returns the owner and administrators
chatMembersFilterAdministrators = ChatMembersFilter;

//@description Returns all chat members, including restricted chat members
chatMembersFilterMembers = ChatMembersFilter;

//@description Returns users which can be mentioned in the chat @message_thread_id If non-zero, the identifier of the current message thread
chatMembersFilterMention message_thread_id:int53 = ChatMembersFilter;

//@description Returns users under certain restrictions in the chat; can be used only by administrators in a supergroup
chatMembersFilterRestricted = ChatMembersFilter;

//@description Returns users banned from the chat; can be used only by administrators in a supergroup or in a channel
chatMembersFilterBanned = ChatMembersFilter;

//@description Returns bot members of the chat
chatMembersFilterBots = ChatMembersFilter;


//@class SupergroupMembersFilter @description Specifies the kind of chat members to return in getSupergroupMembers

//@description Returns recently active users in reverse chronological order
supergroupMembersFilterRecent = SupergroupMembersFilter;

//@description Returns contacts of the user, which are members of the supergroup or channel @query Query to search for
supergroupMembersFilterContacts query:string = SupergroupMembersFilter;

//@description Returns the owner and administrators
supergroupMembersFilterAdministrators = SupergroupMembersFilter;

//@description Used to search for supergroup or channel members via a (string) query @query Query to search for
supergroupMembersFilterSearch query:string = SupergroupMembersFilter;

//@description Returns restricted supergroup members; can be used only by administrators @query Query to search for
supergroupMembersFilterRestricted query:string = SupergroupMembersFilter;

//@description Returns users banned from the supergroup or channel; can be used only by administrators @query Query to search for
supergroupMembersFilterBanned query:string = SupergroupMembersFilter;

//@description Returns users which can be mentioned in the supergroup @query Query to search for @message_thread_id If non-zero, the identifier of the current message thread
supergroupMembersFilterMention query:string message_thread_id:int53 = SupergroupMembersFilter;

//@description Returns bot members of the supergroup or channel
supergroupMembersFilterBots = SupergroupMembersFilter;


//@description Contains a chat invite link
//@invite_link Chat invite link
//@name Name of the link
//@creator_user_id User identifier of an administrator created the link
//@date Point in time (Unix timestamp) when the link was created
//@edit_date Point in time (Unix timestamp) when the link was last edited; 0 if never or unknown
//@expiration_date Point in time (Unix timestamp) when the link will expire; 0 if never
//@subscription_pricing Information about subscription plan that is applied to the users joining the chat by the link; may be null if the link doesn't require subscription
//@member_limit The maximum number of members, which can join the chat using the link simultaneously; 0 if not limited. Always 0 if the link requires approval
//@member_count Number of chat members, which joined the chat using the link
//@expired_member_count Number of chat members, which joined the chat using the link, but have already left because of expired subscription; for subscription links only
//@pending_join_request_count Number of pending join requests created using this link
//@creates_join_request True, if the link only creates join request. If true, total number of joining members will be unlimited
//@is_primary True, if the link is primary. Primary invite link can't have name, expiration date, or usage limit. There is exactly one primary invite link for each administrator with can_invite_users right at a given time
//@is_revoked True, if the link was revoked
chatInviteLink invite_link:string name:string creator_user_id:int53 date:int32 edit_date:int32 expiration_date:int32 subscription_pricing:starSubscriptionPricing member_limit:int32 member_count:int32 expired_member_count:int32 pending_join_request_count:int32 creates_join_request:Bool is_primary:Bool is_revoked:Bool = ChatInviteLink;

//@description Contains a list of chat invite links @total_count Approximate total number of chat invite links found @invite_links List of invite links
chatInviteLinks total_count:int32 invite_links:vector<chatInviteLink> = ChatInviteLinks;

//@description Describes a chat administrator with a number of active and revoked chat invite links
//@user_id Administrator's user identifier
//@invite_link_count Number of active invite links
//@revoked_invite_link_count Number of revoked invite links
chatInviteLinkCount user_id:int53 invite_link_count:int32 revoked_invite_link_count:int32 = ChatInviteLinkCount;

//@description Contains a list of chat invite link counts @invite_link_counts List of invite link counts
chatInviteLinkCounts invite_link_counts:vector<chatInviteLinkCount> = ChatInviteLinkCounts;

//@description Describes a chat member joined a chat via an invite link
//@user_id User identifier
//@joined_chat_date Point in time (Unix timestamp) when the user joined the chat
//@via_chat_folder_invite_link True, if the user has joined the chat using an invite link for a chat folder
//@approver_user_id User identifier of the chat administrator, approved user join request
chatInviteLinkMember user_id:int53 joined_chat_date:int32 via_chat_folder_invite_link:Bool approver_user_id:int53 = ChatInviteLinkMember;

//@description Contains a list of chat members joined a chat via an invite link @total_count Approximate total number of chat members found @members List of chat members, joined a chat via an invite link
chatInviteLinkMembers total_count:int32 members:vector<chatInviteLinkMember> = ChatInviteLinkMembers;


//@class InviteLinkChatType @description Describes the type of chat to which points an invite link

//@description The link is an invite link for a basic group
inviteLinkChatTypeBasicGroup = InviteLinkChatType;

//@description The link is an invite link for a supergroup
inviteLinkChatTypeSupergroup = InviteLinkChatType;

//@description The link is an invite link for a channel
inviteLinkChatTypeChannel = InviteLinkChatType;


//@description Contains information about subscription plan that must be paid by the user to use a chat invite link
//@pricing Information about subscription plan that must be paid by the user to use the link
//@can_reuse True, if the user has already paid for the subscription and can use joinChatByInviteLink to join the subscribed chat again
//@form_id Identifier of the payment form to use for subscription payment; 0 if the subscription can't be paid
chatInviteLinkSubscriptionInfo pricing:starSubscriptionPricing can_reuse:Bool form_id:int64 = ChatInviteLinkSubscriptionInfo;

//@description Contains information about a chat invite link
//@chat_id Chat identifier of the invite link; 0 if the user has no access to the chat before joining
//@accessible_for If non-zero, the amount of time for which read access to the chat will remain available, in seconds
//@type Type of the chat
//@title Title of the chat
//@photo Chat photo; may be null
//@accent_color_id Identifier of the accent color for chat title and background of chat photo
//@param_description Chat description
//@member_count Number of members in the chat
//@member_user_ids User identifiers of some chat members that may be known to the current user
//@subscription_info Information about subscription plan that must be paid by the user to use the link; may be null if the link doesn't require subscription
//@creates_join_request True, if the link only creates join request
//@is_public True, if the chat is a public supergroup or channel, i.e. it has a username or it is a location-based supergroup
//@verification_status Information about verification status of the chat; may be null if none
chatInviteLinkInfo chat_id:int53 accessible_for:int32 type:InviteLinkChatType title:string photo:chatPhotoInfo accent_color_id:int32 description:string member_count:int32 member_user_ids:vector<int53> subscription_info:chatInviteLinkSubscriptionInfo creates_join_request:Bool is_public:Bool verification_status:verificationStatus = ChatInviteLinkInfo;


//@description Describes a user that sent a join request and waits for administrator approval @user_id User identifier @date Point in time (Unix timestamp) when the user sent the join request @bio A short bio of the user
chatJoinRequest user_id:int53 date:int32 bio:string = ChatJoinRequest;

//@description Contains a list of requests to join a chat @total_count Approximate total number of requests found @requests List of the requests
chatJoinRequests total_count:int32 requests:vector<chatJoinRequest> = ChatJoinRequests;

//@description Contains information about pending join requests for a chat @total_count Total number of pending join requests @user_ids Identifiers of at most 3 users sent the newest pending join requests
chatJoinRequestsInfo total_count:int32 user_ids:vector<int53> = ChatJoinRequestsInfo;


//@description Represents a basic group of 0-200 users (must be upgraded to a supergroup to accommodate more than 200 users)
//@id Group identifier
//@member_count Number of members in the group
//@status Status of the current user in the group
//@is_active True, if the group is active
//@upgraded_to_supergroup_id Identifier of the supergroup to which this group was upgraded; 0 if none
basicGroup id:int53 member_count:int32 status:ChatMemberStatus is_active:Bool upgraded_to_supergroup_id:int53 = BasicGroup;

//@description Contains full information about a basic group
//@photo Chat photo; may be null if empty or unknown. If non-null, then it is the same photo as in chat.photo
//@param_description Group description. Updated only after the basic group is opened
//@creator_user_id User identifier of the creator of the group; 0 if unknown
//@members Group members
//@can_hide_members True, if non-administrators and non-bots can be hidden in responses to getSupergroupMembers and searchChatMembers for non-administrators after upgrading the basic group to a supergroup
//@can_toggle_aggressive_anti_spam True, if aggressive anti-spam checks can be enabled or disabled in the supergroup after upgrading the basic group to a supergroup
//@invite_link Primary invite link for this group; may be null. For chat administrators with can_invite_users right only. Updated only after the basic group is opened
//@bot_commands List of commands of bots in the group
basicGroupFullInfo photo:chatPhoto description:string creator_user_id:int53 members:vector<chatMember> can_hide_members:Bool can_toggle_aggressive_anti_spam:Bool invite_link:chatInviteLink bot_commands:vector<botCommands> = BasicGroupFullInfo;


//@description Represents a supergroup or channel with zero or more members (subscribers in the case of channels). From the point of view of the system, a channel is a special kind of a supergroup:
//-only administrators can post and see the list of members, and posts from all administrators use the name and photo of the channel instead of individual names and profile photos.
//-Unlike supergroups, channels can have an unlimited number of subscribers
//@id Supergroup or channel identifier
//@usernames Usernames of the supergroup or channel; may be null
//@date Point in time (Unix timestamp) when the current user joined, or the point in time when the supergroup or channel was created, in case the user is not a member
//@status Status of the current user in the supergroup or channel; custom title will always be empty
//@member_count Number of members in the supergroup or channel; 0 if unknown. Currently, it is guaranteed to be known only if the supergroup or channel was received through
//-getChatSimilarChats, getChatsToSendStories, getCreatedPublicChats, getGroupsInCommon, getInactiveSupergroupChats, getRecommendedChats, getSuitableDiscussionChats,
//-getUserPrivacySettingRules, getVideoChatAvailableParticipants, searchPublicChats, or in chatFolderInviteLinkInfo.missing_chat_ids, or in userFullInfo.personal_chat_id,
//-or for chats with messages or stories from publicForwards and foundStories
//@boost_level Approximate boost level for the chat
//@has_linked_chat True, if the channel has a discussion group, or the supergroup is the designated discussion group for a channel
//@has_location True, if the supergroup is connected to a location, i.e. the supergroup is a location-based supergroup
//@sign_messages True, if messages sent to the channel contains name of the sender. This field is only applicable to channels
//@show_message_sender True, if messages sent to the channel have information about the sender user. This field is only applicable to channels
//@join_to_send_messages True, if users need to join the supergroup before they can send messages. Always true for channels and non-discussion supergroups
//@join_by_request True, if all users directly joining the supergroup need to be approved by supergroup administrators. Always false for channels and supergroups without username, location, or a linked chat
//@is_slow_mode_enabled True, if the slow mode is enabled in the supergroup
//@is_channel True, if the supergroup is a channel
//@is_broadcast_group True, if the supergroup is a broadcast group, i.e. only administrators can send messages and there is no limit on the number of members
//@is_forum True, if the supergroup is a forum with topics
//@verification_status Information about verification status of the supergroup or channel; may be null if none
//@has_sensitive_content True, if content of media messages in the supergroup or channel chat must be hidden with 18+ spoiler
//@restriction_reason If non-empty, contains a human-readable description of the reason why access to this supergroup or channel must be restricted
//@paid_message_star_count Number of Telegram Stars that must be paid by non-administrator users of the supergroup chat for each sent message
//@has_active_stories True, if the supergroup or channel has non-expired stories available to the current user
//@has_unread_active_stories True, if the supergroup or channel has unread non-expired stories available to the current user
supergroup id:int53 usernames:usernames date:int32 status:ChatMemberStatus member_count:int32 boost_level:int32 has_linked_chat:Bool has_location:Bool sign_messages:Bool show_message_sender:Bool join_to_send_messages:Bool join_by_request:Bool is_slow_mode_enabled:Bool is_channel:Bool is_broadcast_group:Bool is_forum:Bool verification_status:verificationStatus has_sensitive_content:Bool restriction_reason:string paid_message_star_count:int53 has_active_stories:Bool has_unread_active_stories:Bool = Supergroup;

//@description Contains full information about a supergroup or channel
//@photo Chat photo; may be null if empty or unknown. If non-null, then it is the same photo as in chat.photo
//@param_description Supergroup or channel description
//@member_count Number of members in the supergroup or channel; 0 if unknown
//@administrator_count Number of privileged users in the supergroup or channel; 0 if unknown
//@restricted_count Number of restricted users in the supergroup; 0 if unknown
//@banned_count Number of users banned from chat; 0 if unknown
//@linked_chat_id Chat identifier of a discussion group for the channel, or a channel, for which the supergroup is the designated discussion group; 0 if none or unknown
//@slow_mode_delay Delay between consecutive sent messages for non-administrator supergroup members, in seconds
//@slow_mode_delay_expires_in Time left before next message can be sent in the supergroup, in seconds. An updateSupergroupFullInfo update is not triggered when value of this field changes, but both new and old values are non-zero
//@can_enable_paid_messages True, if paid messages can be enabled in the supergroup chat; for supergroup only
//@can_enable_paid_reaction True, if paid reaction can be enabled in the channel chat; for channels only
//@can_get_members True, if members of the chat can be retrieved via getSupergroupMembers or searchChatMembers
//@has_hidden_members True, if non-administrators can receive only administrators and bots using getSupergroupMembers or searchChatMembers
//@can_hide_members True, if non-administrators and non-bots can be hidden in responses to getSupergroupMembers and searchChatMembers for non-administrators
//@can_set_sticker_set True, if the supergroup sticker set can be changed
//@can_set_location True, if the supergroup location can be changed
//@can_get_statistics True, if the supergroup or channel statistics are available
//@can_get_revenue_statistics True, if the supergroup or channel revenue statistics are available
//@can_get_star_revenue_statistics True, if the supergroup or channel Telegram Star revenue statistics are available
//@can_send_gift True, if the user can send a gift to the supergroup or channel using sendGift or transferGift
//@can_toggle_aggressive_anti_spam True, if aggressive anti-spam checks can be enabled or disabled in the supergroup
//@is_all_history_available True, if new chat members will have access to old messages. In public, discussion, of forum groups and all channels, old messages are always available,
//-so this option affects only private non-forum supergroups without a linked chat. The value of this field is only available to chat administrators
//@can_have_sponsored_messages True, if the chat can have sponsored messages. The value of this field is only available to the owner of the chat
//@has_aggressive_anti_spam_enabled True, if aggressive anti-spam checks are enabled in the supergroup. The value of this field is only available to chat administrators
//@has_paid_media_allowed True, if paid media can be sent and forwarded to the channel chat; for channels only
//@has_pinned_stories True, if the supergroup or channel has pinned stories
//@gift_count Number of saved to profile gifts for channels without can_post_messages administrator right, otherwise, the total number of received gifts
//@my_boost_count Number of times the current user boosted the supergroup or channel
//@unrestrict_boost_count Number of times the supergroup must be boosted by a user to ignore slow mode and chat permission restrictions; 0 if unspecified
//@sticker_set_id Identifier of the supergroup sticker set that must be shown before user sticker sets; 0 if none
//@custom_emoji_sticker_set_id Identifier of the custom emoji sticker set that can be used in the supergroup without Telegram Premium subscription; 0 if none
//@location Location to which the supergroup is connected; may be null if none
//@invite_link Primary invite link for the chat; may be null. For chat administrators with can_invite_users right only
//@bot_commands List of commands of bots in the group
//@bot_verification Information about verification status of the supergroup or the channel provided by a bot; may be null if none or unknown
//@upgraded_from_basic_group_id Identifier of the basic group from which supergroup was upgraded; 0 if none
//@upgraded_from_max_message_id Identifier of the last message in the basic group from which supergroup was upgraded; 0 if none
supergroupFullInfo photo:chatPhoto description:string member_count:int32 administrator_count:int32 restricted_count:int32 banned_count:int32 linked_chat_id:int53 slow_mode_delay:int32 slow_mode_delay_expires_in:double can_enable_paid_messages:Bool can_enable_paid_reaction:Bool can_get_members:Bool has_hidden_members:Bool can_hide_members:Bool can_set_sticker_set:Bool can_set_location:Bool can_get_statistics:Bool can_get_revenue_statistics:Bool can_get_star_revenue_statistics:Bool can_send_gift:Bool can_toggle_aggressive_anti_spam:Bool is_all_history_available:Bool can_have_sponsored_messages:Bool has_aggressive_anti_spam_enabled:Bool has_paid_media_allowed:Bool has_pinned_stories:Bool gift_count:int32 my_boost_count:int32 unrestrict_boost_count:int32 sticker_set_id:int64 custom_emoji_sticker_set_id:int64 location:chatLocation invite_link:chatInviteLink bot_commands:vector<botCommands> bot_verification:botVerification upgraded_from_basic_group_id:int53 upgraded_from_max_message_id:int53 = SupergroupFullInfo;


//@class SecretChatState @description Describes the current secret chat state

//@description The secret chat is not yet created; waiting for the other user to get online
secretChatStatePending = SecretChatState;

//@description The secret chat is ready to use
secretChatStateReady = SecretChatState;

//@description The secret chat is closed
secretChatStateClosed = SecretChatState;


//@description Represents a secret chat
//@id Secret chat identifier
//@user_id Identifier of the chat partner
//@state State of the secret chat
//@is_outbound True, if the chat was created by the current user; false otherwise
//@key_hash Hash of the currently used key for comparison with the hash of the chat partner's key. This is a string of 36 little-endian bytes, which must be split into groups of 2 bits, each denoting a pixel of one of 4 colors FFFFFF, D5E6F3, 2D5775, and 2F99C9.
//-The pixels must be used to make a 12x12 square image filled from left to right, top to bottom. Alternatively, the first 32 bytes of the hash can be converted to the hexadecimal format and printed as 32 2-digit hex numbers
//@layer Secret chat layer; determines features supported by the chat partner's application. Nested text entities and underline and strikethrough entities are supported if the layer >= 101,
//-files bigger than 2000MB are supported if the layer >= 143, spoiler and custom emoji text entities are supported if the layer >= 144
secretChat id:int32 user_id:int53 state:SecretChatState is_outbound:Bool key_hash:bytes layer:int32 = SecretChat;


//@class MessageSender @description Contains information about the sender of a message

//@description The message was sent by a known user @user_id Identifier of the user that sent the message
messageSenderUser user_id:int53 = MessageSender;

//@description The message was sent on behalf of a chat @chat_id Identifier of the chat that sent the message
messageSenderChat chat_id:int53 = MessageSender;


//@description Represents a list of message senders @total_count Approximate total number of messages senders found @senders List of message senders
messageSenders total_count:int32 senders:vector<MessageSender> = MessageSenders;


//@description Represents a message sender, which can be used to send messages in a chat @sender The message sender @needs_premium True, if Telegram Premium is needed to use the message sender
chatMessageSender sender:MessageSender needs_premium:Bool = ChatMessageSender;

//@description Represents a list of message senders, which can be used to send messages in a chat @senders List of available message senders
chatMessageSenders senders:vector<chatMessageSender> = ChatMessageSenders;


//@class MessageReadDate @description Describes read date of a recent outgoing message in a private chat

//@description Contains read date of the message @read_date Point in time (Unix timestamp) when the message was read by the other user
messageReadDateRead read_date:int32 = MessageReadDate;

//@description The message is unread yet
messageReadDateUnread = MessageReadDate;

//@description The message is too old to get read date
messageReadDateTooOld = MessageReadDate;

//@description The read date is unknown due to privacy settings of the other user
messageReadDateUserPrivacyRestricted = MessageReadDate;

//@description The read date is unknown due to privacy settings of the current user, but will be known if the user subscribes to Telegram Premium
messageReadDateMyPrivacyRestricted = MessageReadDate;


//@description Represents a viewer of a message @user_id User identifier of the viewer @view_date Approximate point in time (Unix timestamp) when the message was viewed
messageViewer user_id:int53 view_date:int32 = MessageViewer;

//@description Represents a list of message viewers @viewers List of message viewers
messageViewers viewers:vector<messageViewer> = MessageViewers;


//@class MessageOrigin @description Contains information about the origin of a message

//@description The message was originally sent by a known user @sender_user_id Identifier of the user that originally sent the message
messageOriginUser sender_user_id:int53 = MessageOrigin;

//@description The message was originally sent by a user, which is hidden by their privacy settings @sender_name Name of the sender
messageOriginHiddenUser sender_name:string = MessageOrigin;

//@description The message was originally sent on behalf of a chat
//@sender_chat_id Identifier of the chat that originally sent the message
//@author_signature For messages originally sent by an anonymous chat administrator, original message author signature
messageOriginChat sender_chat_id:int53 author_signature:string = MessageOrigin;

//@description The message was originally a post in a channel
//@chat_id Identifier of the channel chat to which the message was originally sent
//@message_id Message identifier of the original message
//@author_signature Original post author signature
messageOriginChannel chat_id:int53 message_id:int53 author_signature:string = MessageOrigin;


//@description Contains information about the last message from which a new message was forwarded last time
//@chat_id Identifier of the chat to which the message that was forwarded belonged; may be 0 if unknown
//@message_id Identifier of the message; may be 0 if unknown
//@sender_id Identifier of the sender of the message; may be null if unknown or the new message was forwarded not to Saved Messages
//@sender_name Name of the sender of the message if the sender is hidden by their privacy settings
//@date Point in time (Unix timestamp) when the message is sent; 0 if unknown
//@is_outgoing True, if the message that was forwarded is outgoing; always false if sender is unknown
forwardSource chat_id:int53 message_id:int53 sender_id:MessageSender sender_name:string date:int32 is_outgoing:Bool = ForwardSource;


//@class ReactionType @description Describes type of message reaction

//@description A reaction with an emoji @emoji Text representation of the reaction
reactionTypeEmoji emoji:string = ReactionType;

//@description A reaction with a custom emoji @custom_emoji_id Unique identifier of the custom emoji
reactionTypeCustomEmoji custom_emoji_id:int64 = ReactionType;

//@description The paid reaction in a channel chat
reactionTypePaid = ReactionType;


//@class PaidReactionType @description Describes type of paid message reaction

//@description A paid reaction on behalf of the current user
paidReactionTypeRegular = PaidReactionType;

//@description An anonymous paid reaction
paidReactionTypeAnonymous = PaidReactionType;

//@description A paid reaction on behalf of an owned chat @chat_id Identifier of the chat
paidReactionTypeChat chat_id:int53 = PaidReactionType;


//@description Contains information about a user that added paid reactions
//@sender_id Identifier of the user or chat that added the reactions; may be null for anonymous reactors that aren't the current user
//@star_count Number of Telegram Stars added
//@is_top True, if the reactor is one of the most active reactors; may be false if the reactor is the current user
//@is_me True, if the paid reaction was added by the current user
//@is_anonymous True, if the reactor is anonymous
paidReactor sender_id:MessageSender star_count:int32 is_top:Bool is_me:Bool is_anonymous:Bool = PaidReactor;

//@description Contains information about a forwarded message
//@origin Origin of the forwarded message
//@date Point in time (Unix timestamp) when the message was originally sent
//@source For messages forwarded to the chat with the current user (Saved Messages), to the Replies bot chat, or to the channel's discussion group, information about the source message from which the message was forwarded last time; may be null for other forwards or if unknown
//@public_service_announcement_type The type of public service announcement for the forwarded message
messageForwardInfo origin:MessageOrigin date:int32 source:forwardSource public_service_announcement_type:string = MessageForwardInfo;

//@description Contains information about a message created with importMessages
//@sender_name Name of the original sender
//@date Point in time (Unix timestamp) when the message was originally sent
messageImportInfo sender_name:string date:int32 = MessageImportInfo;

//@description Contains information about replies to a message
//@reply_count Number of times the message was directly or indirectly replied
//@recent_replier_ids Identifiers of at most 3 recent repliers to the message; available in channels with a discussion supergroup. The users and chats are expected to be inaccessible: only their photo and name will be available
//@last_read_inbox_message_id Identifier of the last read incoming reply to the message
//@last_read_outbox_message_id Identifier of the last read outgoing reply to the message
//@last_message_id Identifier of the last reply to the message
messageReplyInfo reply_count:int32 recent_replier_ids:vector<MessageSender> last_read_inbox_message_id:int53 last_read_outbox_message_id:int53 last_message_id:int53 = MessageReplyInfo;

//@description Contains information about a reaction to a message
//@type Type of the reaction
//@total_count Number of times the reaction was added
//@is_chosen True, if the reaction is chosen by the current user
//@used_sender_id Identifier of the message sender used by the current user to add the reaction; may be null if unknown or the reaction isn't chosen
//@recent_sender_ids Identifiers of at most 3 recent message senders, added the reaction; available in private, basic group and supergroup chats
messageReaction type:ReactionType total_count:int32 is_chosen:Bool used_sender_id:MessageSender recent_sender_ids:vector<MessageSender> = MessageReaction;

//@description Contains a list of reactions added to a message
//@reactions List of added reactions
//@are_tags True, if the reactions are tags and Telegram Premium users can filter messages by them
//@paid_reactors Information about top users that added the paid reaction
//@can_get_added_reactions True, if the list of added reactions is available using getMessageAddedReactions
messageReactions reactions:vector<messageReaction> are_tags:Bool paid_reactors:vector<paidReactor> can_get_added_reactions:Bool = MessageReactions;

//@description Contains information about interactions with a message
//@view_count Number of times the message was viewed
//@forward_count Number of times the message was forwarded
//@reply_info Information about direct or indirect replies to the message; may be null. Currently, available only in channels with a discussion supergroup and discussion supergroups for messages, which are not replies itself
//@reactions The list of reactions or tags added to the message; may be null
messageInteractionInfo view_count:int32 forward_count:int32 reply_info:messageReplyInfo reactions:messageReactions = MessageInteractionInfo;

//@description Contains information about an unread reaction to a message
//@type Type of the reaction
//@sender_id Identifier of the sender, added the reaction
//@is_big True, if the reaction was added with a big animation
unreadReaction type:ReactionType sender_id:MessageSender is_big:Bool = UnreadReaction;


//@class MessageEffectType @description Describes type of emoji effect

//@description An effect from an emoji reaction @select_animation Select animation for the effect in TGS format @effect_animation Effect animation for the effect in TGS format
messageEffectTypeEmojiReaction select_animation:sticker effect_animation:sticker = MessageEffectType;

//@description An effect from a premium sticker @sticker The premium sticker. The effect can be found at sticker.full_type.premium_animation
messageEffectTypePremiumSticker sticker:sticker = MessageEffectType;


//@description Contains information about an effect added to a message
//@id Unique identifier of the effect
//@static_icon Static icon for the effect in WEBP format; may be null if none
//@emoji Emoji corresponding to the effect that can be used if static icon isn't available
//@is_premium True, if Telegram Premium subscription is required to use the effect
//@type Type of the effect
messageEffect id:int64 static_icon:sticker emoji:string is_premium:Bool type:MessageEffectType = MessageEffect;


//@class MessageSendingState @description Contains information about the sending state of the message

//@description The message is being sent now, but has not yet been delivered to the server @sending_id Non-persistent message sending identifier, specified by the application
messageSendingStatePending sending_id:int32 = MessageSendingState;

//@description The message failed to be sent
//@error The cause of the message sending failure
//@can_retry True, if the message can be re-sent using resendMessages or readdQuickReplyShortcutMessages
//@need_another_sender True, if the message can be re-sent only on behalf of a different sender
//@need_another_reply_quote True, if the message can be re-sent only if another quote is chosen in the message that is replied by the given message
//@need_drop_reply True, if the message can be re-sent only if the message to be replied is removed. This will be done automatically by resendMessages
//@required_paid_message_star_count The number of Telegram Stars that must be paid to send the message; 0 if the current amount is correct
//@retry_after Time left before the message can be re-sent, in seconds. No update is sent when this field changes
messageSendingStateFailed error:error can_retry:Bool need_another_sender:Bool need_another_reply_quote:Bool need_drop_reply:Bool required_paid_message_star_count:int53 retry_after:double = MessageSendingState;


//@description Describes manually or automatically chosen quote from another message
//@text Text of the quote. Only Bold, Italic, Underline, Strikethrough, Spoiler, and CustomEmoji entities can be present in the text
//@position Approximate quote position in the original message in UTF-16 code units as specified by the message sender
//@is_manual True, if the quote was manually chosen by the message sender
textQuote text:formattedText position:int32 is_manual:Bool = TextQuote;

//@description Describes manually chosen quote from another message
//@text Text of the quote; 0-getOption("message_reply_quote_length_max") characters. Only Bold, Italic, Underline, Strikethrough, Spoiler, and CustomEmoji entities are allowed to be kept and must be kept in the quote
//@position Quote position in the original message in UTF-16 code units
inputTextQuote text:formattedText position:int32 = InputTextQuote;


//@class MessageReplyTo @description Contains information about the message or the story a message is replying to

//@description Describes a message replied by a given message
//@chat_id The identifier of the chat to which the message belongs; may be 0 if the replied message is in unknown chat
//@message_id The identifier of the message; may be 0 if the replied message is in unknown chat
//@quote Chosen quote from the replied message; may be null if none
//@origin Information about origin of the message if the message was from another chat or topic; may be null for messages from the same chat
//@origin_send_date Point in time (Unix timestamp) when the message was sent if the message was from another chat or topic; 0 for messages from the same chat
//@content Media content of the message if the message was from another chat or topic; may be null for messages from the same chat and messages without media.
//-Can be only one of the following types: messageAnimation, messageAudio, messageContact, messageDice, messageDocument, messageGame, messageGiveaway, messageGiveawayWinners,
//-messageInvoice, messageLocation, messagePaidMedia, messagePhoto, messagePoll, messageSticker, messageStory, messageText (for link preview), messageVenue, messageVideo,
//-messageVideoNote, or messageVoiceNote
messageReplyToMessage chat_id:int53 message_id:int53 quote:textQuote origin:MessageOrigin origin_send_date:int32 content:MessageContent = MessageReplyTo;

//@description Describes a story replied by a given message @story_sender_chat_id The identifier of the sender of the story @story_id The identifier of the story
messageReplyToStory story_sender_chat_id:int53 story_id:int32 = MessageReplyTo;


//@class InputMessageReplyTo @description Contains information about the message or the story to be replied

//@description Describes a message to be replied in the same chat and forum topic
//@message_id The identifier of the message to be replied in the same chat and forum topic. A message can be replied in the same chat and forum topic only if messageProperties.can_be_replied
//@quote Quote from the message to be replied; pass null if none. Must always be null for replies in secret chats
inputMessageReplyToMessage message_id:int53 quote:inputTextQuote = InputMessageReplyTo;

//@description Describes a message to be replied that is from a different chat or a forum topic; not supported in secret chats
//@chat_id The identifier of the chat to which the message to be replied belongs
//@message_id The identifier of the message to be replied in the specified chat. A message can be replied in another chat or forum topic only if messageProperties.can_be_replied_in_another_chat
//@quote Quote from the message to be replied; pass null if none
inputMessageReplyToExternalMessage chat_id:int53 message_id:int53 quote:inputTextQuote = InputMessageReplyTo;

//@description Describes a story to be replied
//@story_sender_chat_id The identifier of the sender of the story. Currently, stories can be replied only in the sender's chat and channel stories can't be replied
//@story_id The identifier of the story
inputMessageReplyToStory story_sender_chat_id:int53 story_id:int32 = InputMessageReplyTo;


//@description Describes a fact-check added to the message by an independent checker
//@text Text of the fact-check
//@country_code A two-letter ISO 3166-1 alpha-2 country code of the country for which the fact-check is shown
factCheck text:formattedText country_code:string = FactCheck;


//@description Describes a message
//@id Message identifier; unique for the chat to which the message belongs
//@sender_id Identifier of the sender of the message
//@chat_id Chat identifier
//@sending_state The sending state of the message; may be null if the message isn't being sent and didn't fail to be sent
//@scheduling_state The scheduling state of the message; may be null if the message isn't scheduled
//@is_outgoing True, if the message is outgoing
//@is_pinned True, if the message is pinned
//@is_from_offline True, if the message was sent because of a scheduled action by the message sender, for example, as away, or greeting service message
//@can_be_saved True, if content of the message can be saved locally or copied using inputMessageForwarded or forwardMessages with copy options
//@has_timestamped_media True, if media timestamp entities refers to a media in this message as opposed to a media in the replied message
//@is_channel_post True, if the message is a channel post. All messages to channels are channel posts, all other messages are not channel posts
//@is_topic_message True, if the message is a forum topic message
//@contains_unread_mention True, if the message contains an unread mention for the current user
//@date Point in time (Unix timestamp) when the message was sent; 0 for scheduled messages
//@edit_date Point in time (Unix timestamp) when the message was last edited; 0 for scheduled messages
//@forward_info Information about the initial message sender; may be null if none or unknown
//@import_info Information about the initial message for messages created with importMessages; may be null if the message isn't imported
//@interaction_info Information about interactions with the message; may be null if none
//@unread_reactions Information about unread reactions added to the message
//@fact_check Information about fact-check added to the message; may be null if none
//@reply_to Information about the message or the story this message is replying to; may be null if none
//@message_thread_id If non-zero, the identifier of the message thread the message belongs to; unique within the chat to which the message belongs
//@saved_messages_topic_id Identifier of the Saved Messages topic for the message; 0 for messages not from Saved Messages
//@self_destruct_type The message's self-destruct type; may be null if none
//@self_destruct_in Time left before the message self-destruct timer expires, in seconds; 0 if self-destruction isn't scheduled yet
//@auto_delete_in Time left before the message will be automatically deleted by message_auto_delete_time setting of the chat, in seconds; 0 if never
//@via_bot_user_id If non-zero, the user identifier of the inline bot through which this message was sent
//@sender_business_bot_user_id If non-zero, the user identifier of the business bot that sent this message
//@sender_boost_count Number of times the sender of the message boosted the supergroup at the time the message was sent; 0 if none or unknown. For messages sent by the current user, supergroupFullInfo.my_boost_count must be used instead
//@paid_message_star_count The number of Telegram Stars the sender paid to send the message
//@author_signature For channel posts and anonymous group messages, optional author signature
//@media_album_id Unique identifier of an album this message belongs to; 0 if none. Only audios, documents, photos and videos can be grouped together in albums
//@effect_id Unique identifier of the effect added to the message; 0 if none
//@has_sensitive_content True, if media content of the message must be hidden with 18+ spoiler
//@restriction_reason If non-empty, contains a human-readable description of the reason why access to this message must be restricted
//@content Content of the message
//@reply_markup Reply markup for the message; may be null if none
message id:int53 sender_id:MessageSender chat_id:int53 sending_state:MessageSendingState scheduling_state:MessageSchedulingState is_outgoing:Bool is_pinned:Bool is_from_offline:Bool can_be_saved:Bool has_timestamped_media:Bool is_channel_post:Bool is_topic_message:Bool contains_unread_mention:Bool date:int32 edit_date:int32 forward_info:messageForwardInfo import_info:messageImportInfo interaction_info:messageInteractionInfo unread_reactions:vector<unreadReaction> fact_check:factCheck reply_to:MessageReplyTo message_thread_id:int53 saved_messages_topic_id:int53 self_destruct_type:MessageSelfDestructType self_destruct_in:double auto_delete_in:double via_bot_user_id:int53 sender_business_bot_user_id:int53 sender_boost_count:int32 paid_message_star_count:int53 author_signature:string media_album_id:int64 effect_id:int64 has_sensitive_content:Bool restriction_reason:string content:MessageContent reply_markup:ReplyMarkup = Message;


//@description Contains a list of messages @total_count Approximate total number of messages found @messages List of messages; messages may be null
messages total_count:int32 messages:vector<message> = Messages;

//@description Contains a list of messages found by a search @total_count Approximate total number of messages found; -1 if unknown @messages List of messages @next_offset The offset for the next request. If empty, then there are no more results
foundMessages total_count:int32 messages:vector<message> next_offset:string = FoundMessages;

//@description Contains a list of messages found by a search in a given chat @total_count Approximate total number of messages found; -1 if unknown @messages List of messages @next_from_message_id The offset for the next request. If 0, there are no more results
foundChatMessages total_count:int32 messages:vector<message> next_from_message_id:int53 = FoundChatMessages;

//@description Contains information about a message in a specific position @position 0-based message position in the full list of suitable messages @message_id Message identifier @date Point in time (Unix timestamp) when the message was sent
messagePosition position:int32 message_id:int53 date:int32 = MessagePosition;

//@description Contains a list of message positions @total_count Total number of messages found @positions List of message positions
messagePositions total_count:int32 positions:vector<messagePosition> = MessagePositions;

//@description Contains information about found messages sent on a specific day @total_count Total number of found messages sent on the day @message First message sent on the day
messageCalendarDay total_count:int32 message:message = MessageCalendarDay;

//@description Contains information about found messages, split by days according to the option "utc_time_offset" @total_count Total number of found messages @days Information about messages sent
messageCalendar total_count:int32 days:vector<messageCalendarDay> = MessageCalendar;


//@description Describes a message from a business account as received by a bot @message The message @reply_to_message Message that is replied by the message in the same chat; may be null if none
businessMessage message:message reply_to_message:message = BusinessMessage;

//@description Contains a list of messages from a business account as received by a bot @messages List of business messages
businessMessages messages:vector<businessMessage> = BusinessMessages;


//@class MessageSource @description Describes source of a message

//@description The message is from a chat history
messageSourceChatHistory = MessageSource;

//@description The message is from a message thread history
messageSourceMessageThreadHistory = MessageSource;

//@description The message is from a forum topic history
messageSourceForumTopicHistory = MessageSource;

//@description The message is from chat, message thread or forum topic history preview
messageSourceHistoryPreview = MessageSource;

//@description The message is from a chat list or a forum topic list
messageSourceChatList = MessageSource;

//@description The message is from search results, including file downloads, local file list, outgoing document messages, calendar
messageSourceSearch = MessageSource;

//@description The message is from a chat event log
messageSourceChatEventLog = MessageSource;

//@description The message is from a notification
messageSourceNotification = MessageSource;

//@description The message was screenshotted; the source must be used only if the message content was visible during the screenshot
messageSourceScreenshot = MessageSource;

//@description The message is from some other source
messageSourceOther = MessageSource;


//@description Information about the sponsor of a message
//@url URL of the sponsor to be opened when the message is clicked
//@photo Photo of the sponsor; may be null if must not be shown
//@info Additional optional information about the sponsor to be shown along with the message
messageSponsor url:string photo:photo info:string = MessageSponsor;

//@description Describes a sponsored message
//@message_id Message identifier; unique for the chat to which the sponsored message belongs among both ordinary and sponsored messages
//@is_recommended True, if the message needs to be labeled as "recommended" instead of "sponsored"
//@can_be_reported True, if the message can be reported to Telegram moderators through reportChatSponsoredMessage
//@content Content of the message. Currently, can be only of the types messageText, messageAnimation, messagePhoto, or messageVideo. Video messages can be viewed fullscreen
//@sponsor Information about the sponsor of the message
//@title Title of the sponsored message
//@button_text Text for the message action button
//@accent_color_id Identifier of the accent color for title, button text and message background
//@background_custom_emoji_id Identifier of a custom emoji to be shown on the message background; 0 if none
//@additional_info If non-empty, additional information about the sponsored message to be shown along with the message
sponsoredMessage message_id:int53 is_recommended:Bool can_be_reported:Bool content:MessageContent sponsor:messageSponsor title:string button_text:string accent_color_id:int32 background_custom_emoji_id:int64 additional_info:string = SponsoredMessage;

//@description Contains a list of sponsored messages @messages List of sponsored messages @messages_between The minimum number of messages between shown sponsored messages, or 0 if only one sponsored message must be shown after all ordinary messages
sponsoredMessages messages:vector<sponsoredMessage> messages_between:int32 = SponsoredMessages;


//@description Describes an option to report an entity to Telegram @id Unique identifier of the option @text Text of the option
reportOption id:bytes text:string = ReportOption;


//@class ReportChatSponsoredMessageResult @description Describes result of sponsored message report

//@description The message was reported successfully
reportChatSponsoredMessageResultOk = ReportChatSponsoredMessageResult;

//@description The sponsored message is too old or not found
reportChatSponsoredMessageResultFailed = ReportChatSponsoredMessageResult;

//@description The user must choose an option to report the message and repeat request with the chosen option @title Title for the option choice @options List of available options
reportChatSponsoredMessageResultOptionRequired title:string options:vector<reportOption> = ReportChatSponsoredMessageResult;

//@description Sponsored messages were hidden for the user in all chats
reportChatSponsoredMessageResultAdsHidden = ReportChatSponsoredMessageResult;

//@description The user asked to hide sponsored messages, but Telegram Premium is required for this
reportChatSponsoredMessageResultPremiumRequired = ReportChatSponsoredMessageResult;


//@description Describes a file added to file download list
//@file_id File identifier
//@message The message with the file
//@add_date Point in time (Unix timestamp) when the file was added to the download list
//@complete_date Point in time (Unix timestamp) when the file downloading was completed; 0 if the file downloading isn't completed
//@is_paused True, if downloading of the file is paused
fileDownload file_id:int32 message:message add_date:int32 complete_date:int32 is_paused:Bool = FileDownload;

//@description Contains number of being downloaded and recently downloaded files found
//@active_count Number of active file downloads found, including paused
//@paused_count Number of paused file downloads found
//@completed_count Number of completed file downloads found
downloadedFileCounts active_count:int32 paused_count:int32 completed_count:int32 = DownloadedFileCounts;

//@description Contains a list of downloaded files, found by a search
//@total_counts Total number of suitable files, ignoring offset
//@files The list of files
//@next_offset The offset for the next request. If empty, then there are no more results
foundFileDownloads total_counts:downloadedFileCounts files:vector<fileDownload> next_offset:string = FoundFileDownloads;


//@class NotificationSettingsScope @description Describes the types of chats to which notification settings are relevant

//@description Notification settings applied to all private and secret chats when the corresponding chat setting has a default value
notificationSettingsScopePrivateChats = NotificationSettingsScope;

//@description Notification settings applied to all basic group and supergroup chats when the corresponding chat setting has a default value
notificationSettingsScopeGroupChats = NotificationSettingsScope;

//@description Notification settings applied to all channel chats when the corresponding chat setting has a default value
notificationSettingsScopeChannelChats = NotificationSettingsScope;


//@description Contains information about notification settings for a chat or a forum topic
//@use_default_mute_for If true, the value for the relevant type of chat or the forum chat is used instead of mute_for
//@mute_for Time left before notifications will be unmuted, in seconds
//@use_default_sound If true, the value for the relevant type of chat or the forum chat is used instead of sound_id
//@sound_id Identifier of the notification sound to be played for messages; 0 if sound is disabled
//@use_default_show_preview If true, the value for the relevant type of chat or the forum chat is used instead of show_preview
//@show_preview True, if message content must be displayed in notifications
//@use_default_mute_stories If true, the value for the relevant type of chat is used instead of mute_stories
//@mute_stories True, if story notifications are disabled for the chat
//@use_default_story_sound If true, the value for the relevant type of chat is used instead of story_sound_id
//@story_sound_id Identifier of the notification sound to be played for stories; 0 if sound is disabled
//@use_default_show_story_sender If true, the value for the relevant type of chat is used instead of show_story_sender
//@show_story_sender True, if the sender of stories must be displayed in notifications
//@use_default_disable_pinned_message_notifications If true, the value for the relevant type of chat or the forum chat is used instead of disable_pinned_message_notifications
//@disable_pinned_message_notifications If true, notifications for incoming pinned messages will be created as for an ordinary unread message
//@use_default_disable_mention_notifications If true, the value for the relevant type of chat or the forum chat is used instead of disable_mention_notifications
//@disable_mention_notifications If true, notifications for messages with mentions will be created as for an ordinary unread message
chatNotificationSettings use_default_mute_for:Bool mute_for:int32 use_default_sound:Bool sound_id:int64 use_default_show_preview:Bool show_preview:Bool use_default_mute_stories:Bool mute_stories:Bool use_default_story_sound:Bool story_sound_id:int64 use_default_show_story_sender:Bool show_story_sender:Bool use_default_disable_pinned_message_notifications:Bool disable_pinned_message_notifications:Bool use_default_disable_mention_notifications:Bool disable_mention_notifications:Bool = ChatNotificationSettings;

//@description Contains information about notification settings for several chats
//@mute_for Time left before notifications will be unmuted, in seconds
//@sound_id Identifier of the notification sound to be played; 0 if sound is disabled
//@show_preview True, if message content must be displayed in notifications
//@use_default_mute_stories If true, story notifications are received only for the first 5 chats from topChatCategoryUsers regardless of the value of mute_stories
//@mute_stories True, if story notifications are disabled
//@story_sound_id Identifier of the notification sound to be played for stories; 0 if sound is disabled
//@show_story_sender True, if the sender of stories must be displayed in notifications
//@disable_pinned_message_notifications True, if notifications for incoming pinned messages will be created as for an ordinary unread message
//@disable_mention_notifications True, if notifications for messages with mentions will be created as for an ordinary unread message
scopeNotificationSettings mute_for:int32 sound_id:int64 show_preview:Bool use_default_mute_stories:Bool mute_stories:Bool story_sound_id:int64 show_story_sender:Bool disable_pinned_message_notifications:Bool disable_mention_notifications:Bool = ScopeNotificationSettings;


//@class ReactionNotificationSource @description Describes sources of reactions for which notifications will be shown

//@description Notifications for reactions are disabled
reactionNotificationSourceNone = ReactionNotificationSource;

//@description Notifications for reactions are shown only for reactions from contacts
reactionNotificationSourceContacts = ReactionNotificationSource;

//@description Notifications for reactions are shown for all reactions
reactionNotificationSourceAll = ReactionNotificationSource;


//@description Contains information about notification settings for reactions
//@message_reaction_source Source of message reactions for which notifications are shown
//@story_reaction_source Source of story reactions for which notifications are shown
//@sound_id Identifier of the notification sound to be played; 0 if sound is disabled
//@show_preview True, if reaction sender and emoji must be displayed in notifications
reactionNotificationSettings message_reaction_source:ReactionNotificationSource story_reaction_source:ReactionNotificationSource sound_id:int64 show_preview:Bool = ReactionNotificationSettings;


//@description Contains information about a message draft
//@reply_to Information about the message to be replied; must be of the type inputMessageReplyToMessage; may be null if none
//@date Point in time (Unix timestamp) when the draft was created
//@input_message_text Content of the message draft; must be of the type inputMessageText, inputMessageVideoNote, or inputMessageVoiceNote
//@effect_id Identifier of the effect to apply to the message when it is sent; 0 if none
draftMessage reply_to:InputMessageReplyTo date:int32 input_message_text:InputMessageContent effect_id:int64 = DraftMessage;


//@class ChatType @description Describes the type of chat

//@description An ordinary chat with a user @user_id User identifier
chatTypePrivate user_id:int53 = ChatType;

//@description A basic group (a chat with 0-200 other users) @basic_group_id Basic group identifier
chatTypeBasicGroup basic_group_id:int53 = ChatType;

//@description A supergroup or channel (with unlimited members) @supergroup_id Supergroup or channel identifier @is_channel True, if the supergroup is a channel
chatTypeSupergroup supergroup_id:int53 is_channel:Bool = ChatType;

//@description A secret chat with a user @secret_chat_id Secret chat identifier @user_id User identifier of the other user in the secret chat
chatTypeSecret secret_chat_id:int32 user_id:int53 = ChatType;


//@description Represents an icon for a chat folder @name The chosen icon name for short folder representation; one of "All", "Unread", "Unmuted", "Bots", "Channels", "Groups", "Private", "Custom", "Setup", "Cat", "Crown",
//-"Favorite", "Flower", "Game", "Home", "Love", "Mask", "Party", "Sport", "Study", "Trade", "Travel", "Work", "Airplane", "Book", "Light", "Like", "Money", "Note", "Palette"
chatFolderIcon name:string = ChatFolderIcon;

//@description Describes name of a chat folder
//@text The text of the chat folder name; 1-12 characters without line feeds. May contain only CustomEmoji entities
//@animate_custom_emoji True, if custom emoji in the name must be animated
chatFolderName text:formattedText animate_custom_emoji:Bool = ChatFolderName;

//@description Represents a folder for user chats
//@name The name of the folder
//@icon The chosen icon for the chat folder; may be null. If null, use getChatFolderDefaultIconName to get default icon name for the folder
//@color_id The identifier of the chosen color for the chat folder icon; from -1 to 6. If -1, then color is disabled. Can't be changed if folder tags are disabled or the current user doesn't have Telegram Premium subscription
//@is_shareable True, if at least one link has been created for the folder
//@pinned_chat_ids The chat identifiers of pinned chats in the folder. There can be up to getOption("chat_folder_chosen_chat_count_max") pinned and always included non-secret chats and the same number of secret chats, but the limit can be increased with Telegram Premium
//@included_chat_ids The chat identifiers of always included chats in the folder. There can be up to getOption("chat_folder_chosen_chat_count_max") pinned and always included non-secret chats and the same number of secret chats, but the limit can be increased with Telegram Premium
//@excluded_chat_ids The chat identifiers of always excluded chats in the folder. There can be up to getOption("chat_folder_chosen_chat_count_max") always excluded non-secret chats and the same number of secret chats, but the limit can be increased with Telegram Premium
//@exclude_muted True, if muted chats need to be excluded
//@exclude_read True, if read chats need to be excluded
//@exclude_archived True, if archived chats need to be excluded
//@include_contacts True, if contacts need to be included
//@include_non_contacts True, if non-contact users need to be included
//@include_bots True, if bots need to be included
//@include_groups True, if basic groups and supergroups need to be included
//@include_channels True, if channels need to be included
chatFolder name:chatFolderName icon:chatFolderIcon color_id:int32 is_shareable:Bool pinned_chat_ids:vector<int53> included_chat_ids:vector<int53> excluded_chat_ids:vector<int53> exclude_muted:Bool exclude_read:Bool exclude_archived:Bool include_contacts:Bool include_non_contacts:Bool include_bots:Bool include_groups:Bool include_channels:Bool = ChatFolder;

//@description Contains basic information about a chat folder
//@id Unique chat folder identifier
//@name The name of the folder
//@icon The chosen or default icon for the chat folder
//@color_id The identifier of the chosen color for the chat folder icon; from -1 to 6. If -1, then color is disabled
//@is_shareable True, if at least one link has been created for the folder
//@has_my_invite_links True, if the chat folder has invite links created by the current user
chatFolderInfo id:int32 name:chatFolderName icon:chatFolderIcon color_id:int32 is_shareable:Bool has_my_invite_links:Bool = ChatFolderInfo;

//@description Contains a chat folder invite link
//@invite_link The chat folder invite link
//@name Name of the link
//@chat_ids Identifiers of chats, included in the link
chatFolderInviteLink invite_link:string name:string chat_ids:vector<int53> = ChatFolderInviteLink;

//@description Represents a list of chat folder invite links @invite_links List of the invite links
chatFolderInviteLinks invite_links:vector<chatFolderInviteLink> = ChatFolderInviteLinks;

//@description Contains information about an invite link to a chat folder
//@chat_folder_info Basic information about the chat folder; chat folder identifier will be 0 if the user didn't have the chat folder yet
//@missing_chat_ids Identifiers of the chats from the link, which aren't added to the folder yet
//@added_chat_ids Identifiers of the chats from the link, which are added to the folder already
chatFolderInviteLinkInfo chat_folder_info:chatFolderInfo missing_chat_ids:vector<int53> added_chat_ids:vector<int53> = ChatFolderInviteLinkInfo;

//@description Describes a recommended chat folder @folder The chat folder @param_description Chat folder description
recommendedChatFolder folder:chatFolder description:string = RecommendedChatFolder;

//@description Contains a list of recommended chat folders @chat_folders List of recommended chat folders
recommendedChatFolders chat_folders:vector<recommendedChatFolder> = RecommendedChatFolders;

//@description Contains settings for automatic moving of chats to and from the Archive chat lists
//@archive_and_mute_new_chats_from_unknown_users True, if new chats from non-contacts will be automatically archived and muted. Can be set to true only if the option "can_archive_and_mute_new_chats_from_unknown_users" is true
//@keep_unmuted_chats_archived True, if unmuted chats will be kept in the Archive chat list when they get a new message
//@keep_chats_from_folders_archived True, if unmuted chats, that are always included or pinned in a folder, will be kept in the Archive chat list when they get a new message. Ignored if keep_unmuted_chats_archived == true
archiveChatListSettings archive_and_mute_new_chats_from_unknown_users:Bool keep_unmuted_chats_archived:Bool keep_chats_from_folders_archived:Bool = ArchiveChatListSettings;


//@class ChatList @description Describes a list of chats

//@description A main list of chats
chatListMain = ChatList;

//@description A list of chats usually located at the top of the main chat list. Unmuted chats are automatically moved from the Archive to the Main chat list when a new message arrives
chatListArchive = ChatList;

//@description A list of chats added to a chat folder @chat_folder_id Chat folder identifier
chatListFolder chat_folder_id:int32 = ChatList;

//@description Contains a list of chat lists @chat_lists List of chat lists
chatLists chat_lists:vector<ChatList> = ChatLists;


//@class ChatSource @description Describes a reason why an external chat is shown in a chat list

//@description The chat is sponsored by the user's MTProxy server
chatSourceMtprotoProxy = ChatSource;

//@description The chat contains a public service announcement @type The type of the announcement @text The text of the announcement
chatSourcePublicServiceAnnouncement type:string text:string = ChatSource;


//@description Describes a position of a chat in a chat list
//@list The chat list
//@order A parameter used to determine order of the chat in the chat list. Chats must be sorted by the pair (order, chat.id) in descending order
//@is_pinned True, if the chat is pinned in the chat list
//@source Source of the chat in the chat list; may be null
chatPosition list:ChatList order:int64 is_pinned:Bool source:ChatSource = ChatPosition;


//@class ChatAvailableReactions @description Describes reactions available in the chat

//@description All reactions are available in the chat, excluding the paid reaction and custom reactions in channel chats
//@max_reaction_count The maximum allowed number of reactions per message; 1-11
chatAvailableReactionsAll max_reaction_count:int32 = ChatAvailableReactions;

//@description Only specific reactions are available in the chat @reactions The list of reactions @max_reaction_count The maximum allowed number of reactions per message; 1-11
chatAvailableReactionsSome reactions:vector<ReactionType> max_reaction_count:int32 = ChatAvailableReactions;


//@description Represents a tag used in Saved Messages or a Saved Messages topic
//@tag The tag
//@label Label of the tag; 0-12 characters. Always empty if the tag is returned for a Saved Messages topic
//@count Number of times the tag was used; may be 0 if the tag has non-empty label
savedMessagesTag tag:ReactionType label:string count:int32 = SavedMessagesTag;

//@description Contains a list of tags used in Saved Messages @tags List of tags
savedMessagesTags tags:vector<savedMessagesTag> = SavedMessagesTags;


//@description Contains information about a business bot that manages the chat
//@bot_user_id User identifier of the bot
//@manage_url URL to be opened to manage the bot
//@is_bot_paused True, if the bot is paused. Use toggleBusinessConnectedBotChatIsPaused to change the value of the field
//@can_bot_reply True, if the bot can reply
businessBotManageBar bot_user_id:int53 manage_url:string is_bot_paused:Bool can_bot_reply:Bool = BusinessBotManageBar;


//@description Describes a video chat
//@group_call_id Group call identifier of an active video chat; 0 if none. Full information about the video chat can be received through the method getGroupCall
//@has_participants True, if the video chat has participants
//@default_participant_id Default group call participant identifier to join the video chat; may be null
videoChat group_call_id:int32 has_participants:Bool default_participant_id:MessageSender = VideoChat;


//@description A chat. (Can be a private chat, basic group, supergroup, or secret chat)
//@id Chat unique identifier
//@type Type of the chat
//@title Chat title
//@photo Chat photo; may be null
//@accent_color_id Identifier of the accent color for message sender name, and backgrounds of chat photo, reply header, and link preview
//@background_custom_emoji_id Identifier of a custom emoji to be shown on the reply header and link preview background for messages sent by the chat; 0 if none
//@profile_accent_color_id Identifier of the profile accent color for the chat's profile; -1 if none
//@profile_background_custom_emoji_id Identifier of a custom emoji to be shown on the background of the chat's profile; 0 if none
//@permissions Actions that non-administrator chat members are allowed to take in the chat
//@last_message Last message in the chat; may be null if none or unknown
//@positions Positions of the chat in chat lists
//@chat_lists Chat lists to which the chat belongs. A chat can have a non-zero position in a chat list even it doesn't belong to the chat list and have no position in a chat list even it belongs to the chat list
//@message_sender_id Identifier of a user or chat that is selected to send messages in the chat; may be null if the user can't change message sender
//@block_list Block list to which the chat is added; may be null if none
//@has_protected_content True, if chat content can't be saved locally, forwarded, or copied
//@is_translatable True, if translation of all messages in the chat must be suggested to the user
//@is_marked_as_unread True, if the chat is marked as unread
//@view_as_topics True, if the chat is a forum supergroup that must be shown in the "View as topics" mode, or Saved Messages chat that must be shown in the "View as chats"
//@has_scheduled_messages True, if the chat has scheduled messages
//@can_be_deleted_only_for_self True, if the chat messages can be deleted only for the current user while other users will continue to see the messages
//@can_be_deleted_for_all_users True, if the chat messages can be deleted for all users
//@can_be_reported True, if the chat can be reported to Telegram moderators through reportChat or reportChatPhoto
//@default_disable_notification Default value of the disable_notification parameter, used when a message is sent to the chat
//@unread_count Number of unread messages in the chat
//@last_read_inbox_message_id Identifier of the last read incoming message
//@last_read_outbox_message_id Identifier of the last read outgoing message
//@unread_mention_count Number of unread messages with a mention/reply in the chat
//@unread_reaction_count Number of messages with unread reactions in the chat
//@notification_settings Notification settings for the chat
//@available_reactions Types of reaction, available in the chat
//@message_auto_delete_time Current message auto-delete or self-destruct timer setting for the chat, in seconds; 0 if disabled. Self-destruct timer in secret chats starts after the message or its content is viewed. Auto-delete timer in other chats starts from the send date
//@emoji_status Emoji status to be shown along with chat title; may be null
//@background Background set for the chat; may be null if none
//@theme_name If non-empty, name of a theme, set for the chat
//@action_bar Information about actions which must be possible to do through the chat action bar; may be null if none
//@business_bot_manage_bar Information about bar for managing a business bot in the chat; may be null if none
//@video_chat Information about video chat of the chat
//@pending_join_requests Information about pending join requests; may be null if none
//@reply_markup_message_id Identifier of the message from which reply markup needs to be used; 0 if there is no default custom reply markup in the chat
//@draft_message A draft of a message in the chat; may be null if none
//@client_data Application-specific data associated with the chat. (For example, the chat scroll position or local chat notification settings can be stored here.) Persistent if the message database is used
chat id:int53 type:ChatType title:string photo:chatPhotoInfo accent_color_id:int32 background_custom_emoji_id:int64 profile_accent_color_id:int32 profile_background_custom_emoji_id:int64 permissions:chatPermissions last_message:message positions:vector<chatPosition> chat_lists:vector<ChatList> message_sender_id:MessageSender block_list:BlockList has_protected_content:Bool is_translatable:Bool is_marked_as_unread:Bool view_as_topics:Bool has_scheduled_messages:Bool can_be_deleted_only_for_self:Bool can_be_deleted_for_all_users:Bool can_be_reported:Bool default_disable_notification:Bool unread_count:int32 last_read_inbox_message_id:int53 last_read_outbox_message_id:int53 unread_mention_count:int32 unread_reaction_count:int32 notification_settings:chatNotificationSettings available_reactions:ChatAvailableReactions message_auto_delete_time:int32 emoji_status:emojiStatus background:chatBackground theme_name:string action_bar:ChatActionBar business_bot_manage_bar:businessBotManageBar video_chat:videoChat pending_join_requests:chatJoinRequestsInfo reply_markup_message_id:int53 draft_message:draftMessage client_data:string = Chat;

//@description Represents a list of chats @total_count Approximate total number of chats found @chat_ids List of chat identifiers
chats total_count:int32 chat_ids:vector<int53> = Chats;


//@description Contains information about a user that has failed to be added to a chat
//@user_id User identifier
//@premium_would_allow_invite True, if subscription to Telegram Premium would have allowed to add the user to the chat
//@premium_required_to_send_messages True, if subscription to Telegram Premium is required to send the user chat invite link
failedToAddMember user_id:int53 premium_would_allow_invite:Bool premium_required_to_send_messages:Bool = FailedToAddMember;

//@description Represents a list of users that has failed to be added to a chat @failed_to_add_members Information about users that weren't added to the chat
failedToAddMembers failed_to_add_members:vector<failedToAddMember> = FailedToAddMembers;


//@description Contains information about a newly created basic group chat @chat_id Chat identifier @failed_to_add_members Information about failed to add members
createdBasicGroupChat chat_id:int53 failed_to_add_members:failedToAddMembers = CreatedBasicGroupChat;


//@class PublicChatType @description Describes type of public chat

//@description The chat is public, because it has an active username
publicChatTypeHasUsername = PublicChatType;

//@description The chat is public, because it is a location-based supergroup
publicChatTypeIsLocationBased = PublicChatType;


//@description Contains basic information about another user that started a chat with the current user
//@registration_month Month when the user was registered in Telegram; 0-12; may be 0 if unknown
//@registration_year Year when the user was registered in Telegram; 0-9999; may be 0 if unknown
//@phone_number_country_code A two-letter ISO 3166-1 alpha-2 country code based on the phone number of the user; may be empty if unknown
//@last_name_change_date Point in time (Unix timestamp) when the user changed name last time; 0 if unknown
//@last_photo_change_date Point in time (Unix timestamp) when the user changed photo last time; 0 if unknown
accountInfo registration_month:int32 registration_year:int32 phone_number_country_code:string last_name_change_date:int32 last_photo_change_date:int32 = AccountInfo;


//@class ChatActionBar @description Describes actions which must be possible to do through a chat action bar

//@description The chat can be reported as spam using the method reportChat with an empty option_id and message_ids. If the chat is a private chat with a user with an emoji status, then a notice about emoji status usage must be shown
//@can_unarchive If true, the chat was automatically archived and can be moved back to the main chat list using addChatToList simultaneously with setting chat notification settings to default using setChatNotificationSettings
chatActionBarReportSpam can_unarchive:Bool = ChatActionBar;

//@description The chat is a recently created group chat to which new members can be invited
chatActionBarInviteMembers = ChatActionBar;

//@description The chat is a private or secret chat, which can be reported using the method reportChat, or the other user can be blocked using the method setMessageSenderBlockList,
//-or the other user can be added to the contact list using the method addContact. If the chat is a private chat with a user with an emoji status, then a notice about emoji status usage must be shown
//@can_unarchive If true, the chat was automatically archived and can be moved back to the main chat list using addChatToList simultaneously with setting chat notification settings to default using setChatNotificationSettings
//@account_info Basic information about the other user in the chat; may be null if unknown
chatActionBarReportAddBlock can_unarchive:Bool account_info:accountInfo = ChatActionBar;

//@description The chat is a private or secret chat and the other user can be added to the contact list using the method addContact
chatActionBarAddContact = ChatActionBar;

//@description The chat is a private or secret chat with a mutual contact and the user's phone number can be shared with the other user using the method sharePhoneNumber
chatActionBarSharePhoneNumber = ChatActionBar;

//@description The chat is a private chat with an administrator of a chat to which the user sent join request
//@title Title of the chat to which the join request was sent
//@is_channel True, if the join request was sent to a channel chat
//@request_date Point in time (Unix timestamp) when the join request was sent
chatActionBarJoinRequest title:string is_channel:Bool request_date:int32 = ChatActionBar;


//@class KeyboardButtonType @description Describes a keyboard button type

//@description A simple button, with text that must be sent when the button is pressed
keyboardButtonTypeText = KeyboardButtonType;

//@description A button that sends the user's phone number when pressed; available only in private chats
keyboardButtonTypeRequestPhoneNumber = KeyboardButtonType;

//@description A button that sends the user's location when pressed; available only in private chats
keyboardButtonTypeRequestLocation = KeyboardButtonType;

//@description A button that allows the user to create and send a poll when pressed; available only in private chats @force_regular If true, only regular polls must be allowed to create @force_quiz If true, only polls in quiz mode must be allowed to create
keyboardButtonTypeRequestPoll force_regular:Bool force_quiz:Bool = KeyboardButtonType;

//@description A button that requests users to be shared by the current user; available only in private chats. Use the method shareUsersWithBot to complete the request
//@id Unique button identifier
//@restrict_user_is_bot True, if the shared users must or must not be bots
//@user_is_bot True, if the shared users must be bots; otherwise, the shared users must not be bots. Ignored if restrict_user_is_bot is false
//@restrict_user_is_premium True, if the shared users must or must not be Telegram Premium users
//@user_is_premium True, if the shared users must be Telegram Premium users; otherwise, the shared users must not be Telegram Premium users. Ignored if restrict_user_is_premium is false
//@max_quantity The maximum number of users to share
//@request_name Pass true to request name of the users; bots only
//@request_username Pass true to request username of the users; bots only
//@request_photo Pass true to request photo of the users; bots only
keyboardButtonTypeRequestUsers id:int32 restrict_user_is_bot:Bool user_is_bot:Bool restrict_user_is_premium:Bool user_is_premium:Bool max_quantity:int32 request_name:Bool request_username:Bool request_photo:Bool = KeyboardButtonType;

//@description A button that requests a chat to be shared by the current user; available only in private chats. Use the method shareChatWithBot to complete the request
//@id Unique button identifier
//@chat_is_channel True, if the chat must be a channel; otherwise, a basic group or a supergroup chat is shared
//@restrict_chat_is_forum True, if the chat must or must not be a forum supergroup
//@chat_is_forum True, if the chat must be a forum supergroup; otherwise, the chat must not be a forum supergroup. Ignored if restrict_chat_is_forum is false
//@restrict_chat_has_username True, if the chat must or must not have a username
//@chat_has_username True, if the chat must have a username; otherwise, the chat must not have a username. Ignored if restrict_chat_has_username is false
//@chat_is_created True, if the chat must be created by the current user
//@user_administrator_rights Expected user administrator rights in the chat; may be null if they aren't restricted
//@bot_administrator_rights Expected bot administrator rights in the chat; may be null if they aren't restricted
//@bot_is_member True, if the bot must be a member of the chat; for basic group and supergroup chats only
//@request_title Pass true to request title of the chat; bots only
//@request_username Pass true to request username of the chat; bots only
//@request_photo Pass true to request photo of the chat; bots only
keyboardButtonTypeRequestChat id:int32 chat_is_channel:Bool restrict_chat_is_forum:Bool chat_is_forum:Bool restrict_chat_has_username:Bool chat_has_username:Bool chat_is_created:Bool user_administrator_rights:chatAdministratorRights bot_administrator_rights:chatAdministratorRights bot_is_member:Bool request_title:Bool request_username:Bool request_photo:Bool = KeyboardButtonType;

//@description A button that opens a Web App by calling getWebAppUrl @url An HTTP URL to pass to getWebAppUrl
keyboardButtonTypeWebApp url:string = KeyboardButtonType;


//@description Represents a single button in a bot keyboard @text Text of the button @type Type of the button
keyboardButton text:string type:KeyboardButtonType = KeyboardButton;


//@class InlineKeyboardButtonType @description Describes the type of inline keyboard button

//@description A button that opens a specified URL @url HTTP or tg:// URL to open. If the link is of the type internalLinkTypeWebApp, then the button must be marked as a Web App button
inlineKeyboardButtonTypeUrl url:string = InlineKeyboardButtonType;

//@description A button that opens a specified URL and automatically authorize the current user by calling getLoginUrlInfo @url An HTTP URL to pass to getLoginUrlInfo @id Unique button identifier @forward_text If non-empty, new text of the button in forwarded messages
inlineKeyboardButtonTypeLoginUrl url:string id:int53 forward_text:string = InlineKeyboardButtonType;

//@description A button that opens a Web App by calling openWebApp @url An HTTP URL to pass to openWebApp
inlineKeyboardButtonTypeWebApp url:string = InlineKeyboardButtonType;

//@description A button that sends a callback query to a bot @data Data to be sent to the bot via a callback query
inlineKeyboardButtonTypeCallback data:bytes = InlineKeyboardButtonType;

//@description A button that asks for the 2-step verification password of the current user and then sends a callback query to a bot @data Data to be sent to the bot via a callback query
inlineKeyboardButtonTypeCallbackWithPassword data:bytes = InlineKeyboardButtonType;

//@description A button with a game that sends a callback query to a bot. This button must be in the first column and row of the keyboard and can be attached only to a message with content of the type messageGame
inlineKeyboardButtonTypeCallbackGame = InlineKeyboardButtonType;

//@description A button that forces an inline query to the bot to be inserted in the input field @query Inline query to be sent to the bot @target_chat Target chat from which to send the inline query
inlineKeyboardButtonTypeSwitchInline query:string target_chat:TargetChat = InlineKeyboardButtonType;

//@description A button to buy something. This button must be in the first column and row of the keyboard and can be attached only to a message with content of the type messageInvoice
inlineKeyboardButtonTypeBuy = InlineKeyboardButtonType;

//@description A button with a user reference to be handled in the same way as textEntityTypeMentionName entities @user_id User identifier
inlineKeyboardButtonTypeUser user_id:int53 = InlineKeyboardButtonType;

//@description A button that copies specified text to clipboard @text The text to copy to clipboard
inlineKeyboardButtonTypeCopyText text:string = InlineKeyboardButtonType;


//@description Represents a single button in an inline keyboard @text Text of the button @type Type of the button
inlineKeyboardButton text:string type:InlineKeyboardButtonType = InlineKeyboardButton;


//@class ReplyMarkup @description Contains a description of a custom keyboard and actions that can be done with it to quickly reply to bots

//@description Instructs application to remove the keyboard once this message has been received. This kind of keyboard can't be received in an incoming message; instead, updateChatReplyMarkup with message_id == 0 will be sent
//@is_personal True, if the keyboard is removed only for the mentioned users or the target user of a reply
replyMarkupRemoveKeyboard is_personal:Bool = ReplyMarkup;

//@description Instructs application to force a reply to this message
//@is_personal True, if a forced reply must automatically be shown to the current user. For outgoing messages, specify true to show the forced reply only for the mentioned users and for the target user of a reply
//@input_field_placeholder If non-empty, the placeholder to be shown in the input field when the reply is active; 0-64 characters
replyMarkupForceReply is_personal:Bool input_field_placeholder:string = ReplyMarkup;

//@description Contains a custom keyboard layout to quickly reply to bots
//@rows A list of rows of bot keyboard buttons
//@is_persistent True, if the keyboard is expected to always be shown when the ordinary keyboard is hidden
//@resize_keyboard True, if the application needs to resize the keyboard vertically
//@one_time True, if the application needs to hide the keyboard after use
//@is_personal True, if the keyboard must automatically be shown to the current user. For outgoing messages, specify true to show the keyboard only for the mentioned users and for the target user of a reply
//@input_field_placeholder If non-empty, the placeholder to be shown in the input field when the keyboard is active; 0-64 characters
replyMarkupShowKeyboard rows:vector<vector<keyboardButton>> is_persistent:Bool resize_keyboard:Bool one_time:Bool is_personal:Bool input_field_placeholder:string = ReplyMarkup;

//@description Contains an inline keyboard layout
//@rows A list of rows of inline keyboard buttons
replyMarkupInlineKeyboard rows:vector<vector<inlineKeyboardButton>> = ReplyMarkup;


//@class LoginUrlInfo @description Contains information about an inline button of type inlineKeyboardButtonTypeLoginUrl

//@description An HTTP URL needs to be open @url The URL to open @skip_confirmation True, if there is no need to show an ordinary open URL confirmation
loginUrlInfoOpen url:string skip_confirmation:Bool = LoginUrlInfo;

//@description An authorization confirmation dialog needs to be shown to the user
//@url An HTTP URL to be opened
//@domain A domain of the URL
//@bot_user_id User identifier of a bot linked with the website
//@request_write_access True, if the user must be asked for the permission to the bot to send them messages
loginUrlInfoRequestConfirmation url:string domain:string bot_user_id:int53 request_write_access:Bool = LoginUrlInfo;


//@description Contains parameters of the application theme
//@background_color A color of the background in the RGB format
//@secondary_background_color A secondary color for the background in the RGB format
//@header_background_color A color of the header background in the RGB format
//@bottom_bar_background_color A color of the bottom bar background in the RGB format
//@section_background_color A color of the section background in the RGB format
//@section_separator_color A color of the section separator in the RGB format
//@text_color A color of text in the RGB format
//@accent_text_color An accent color of the text in the RGB format
//@section_header_text_color A color of text on the section headers in the RGB format
//@subtitle_text_color A color of the subtitle text in the RGB format
//@destructive_text_color A color of the text for destructive actions in the RGB format
//@hint_color A color of hints in the RGB format
//@link_color A color of links in the RGB format
//@button_color A color of the buttons in the RGB format
//@button_text_color A color of text on the buttons in the RGB format
themeParameters background_color:int32 secondary_background_color:int32 header_background_color:int32 bottom_bar_background_color:int32 section_background_color:int32 section_separator_color:int32 text_color:int32 accent_text_color:int32 section_header_text_color:int32 subtitle_text_color:int32 destructive_text_color:int32 hint_color:int32 link_color:int32 button_color:int32 button_text_color:int32 = ThemeParameters;


//@class WebAppOpenMode @description Describes mode in which a Web App is opened

//@description The Web App is opened in the compact mode
webAppOpenModeCompact = WebAppOpenMode;

//@description The Web App is opened in the full-size mode
webAppOpenModeFullSize = WebAppOpenMode;

//@description The Web App is opened in the full-screen mode
webAppOpenModeFullScreen = WebAppOpenMode;


//@description Contains information about a Web App found by its short name
//@web_app The Web App
//@request_write_access True, if the user must be asked for the permission to the bot to send them messages
//@skip_confirmation True, if there is no need to show an ordinary open URL confirmation before opening the Web App. The field must be ignored and confirmation must be shown anyway if the Web App link was hidden
foundWebApp web_app:webApp request_write_access:Bool skip_confirmation:Bool = FoundWebApp;

//@description Contains information about a Web App @launch_id Unique identifier for the Web App launch @url A Web App URL to open in a web view
webAppInfo launch_id:int64 url:string = WebAppInfo;

//@description Contains information about the main Web App of a bot @url URL of the Web App to open @mode The mode in which the Web App must be opened
mainWebApp url:string mode:WebAppOpenMode = MainWebApp;

//@description Options to be used when a Web App is opened
//@theme Preferred Web App theme; pass null to use the default theme
//@application_name Short name of the current application; 0-64 English letters, digits, and underscores
//@mode The mode in which the Web App is opened; pass null to open in webAppOpenModeFullSize
webAppOpenParameters theme:themeParameters application_name:string mode:WebAppOpenMode = WebAppOpenParameters;


//@description Contains information about a message thread
//@chat_id Identifier of the chat to which the message thread belongs
//@message_thread_id Message thread identifier, unique within the chat
//@reply_info Information about the message thread; may be null for forum topic threads
//@unread_message_count Approximate number of unread messages in the message thread
//@messages The messages from which the thread starts. The messages are returned in reverse chronological order (i.e., in order of decreasing message_id)
//@draft_message A draft of a message in the message thread; may be null if none
messageThreadInfo chat_id:int53 message_thread_id:int53 reply_info:messageReplyInfo unread_message_count:int32 messages:vector<message> draft_message:draftMessage = MessageThreadInfo;


//@class SavedMessagesTopicType @description Describes type of Saved Messages topic

//@description Topic containing messages sent by the current user of forwarded from an unknown chat
savedMessagesTopicTypeMyNotes = SavedMessagesTopicType;

//@description Topic containing messages forwarded from a user with hidden privacy
savedMessagesTopicTypeAuthorHidden = SavedMessagesTopicType;

//@description Topic containing messages forwarded from a specific chat @chat_id Identifier of the chat
savedMessagesTopicTypeSavedFromChat chat_id:int53 = SavedMessagesTopicType;


//@description Contains information about a Saved Messages topic
//@id Unique topic identifier
//@type Type of the topic
//@is_pinned True, if the topic is pinned
//@order A parameter used to determine order of the topic in the topic list. Topics must be sorted by the order in descending order
//@last_message Last message in the topic; may be null if none or unknown
//@draft_message A draft of a message in the topic; may be null if none
savedMessagesTopic id:int53 type:SavedMessagesTopicType is_pinned:Bool order:int64 last_message:message draft_message:draftMessage = SavedMessagesTopic;


//@description Describes a forum topic icon @color Color of the topic icon in RGB format @custom_emoji_id Unique identifier of the custom emoji shown on the topic icon; 0 if none
forumTopicIcon color:int32 custom_emoji_id:int64 = ForumTopicIcon;

//@description Contains basic information about a forum topic
//@message_thread_id Message thread identifier of the topic
//@name Name of the topic
//@icon Icon of the topic
//@creation_date Point in time (Unix timestamp) when the topic was created
//@creator_id Identifier of the creator of the topic
//@is_general True, if the topic is the General topic list
//@is_outgoing True, if the topic was created by the current user
//@is_closed True, if the topic is closed
//@is_hidden True, if the topic is hidden above the topic list and closed; for General topic only
forumTopicInfo message_thread_id:int53 name:string icon:forumTopicIcon creation_date:int32 creator_id:MessageSender is_general:Bool is_outgoing:Bool is_closed:Bool is_hidden:Bool = ForumTopicInfo;

//@description Describes a forum topic
//@info Basic information about the topic
//@last_message Last message in the topic; may be null if unknown
//@is_pinned True, if the topic is pinned in the topic list
//@unread_count Number of unread messages in the topic
//@last_read_inbox_message_id Identifier of the last read incoming message
//@last_read_outbox_message_id Identifier of the last read outgoing message
//@unread_mention_count Number of unread messages with a mention/reply in the topic
//@unread_reaction_count Number of messages with unread reactions in the topic
//@notification_settings Notification settings for the topic
//@draft_message A draft of a message in the topic; may be null if none
forumTopic info:forumTopicInfo last_message:message is_pinned:Bool unread_count:int32 last_read_inbox_message_id:int53 last_read_outbox_message_id:int53 unread_mention_count:int32 unread_reaction_count:int32 notification_settings:chatNotificationSettings draft_message:draftMessage = ForumTopic;

//@description Describes a list of forum topics
//@total_count Approximate total number of forum topics found
//@topics List of forum topics
//@next_offset_date Offset date for the next getForumTopics request
//@next_offset_message_id Offset message identifier for the next getForumTopics request
//@next_offset_message_thread_id Offset message thread identifier for the next getForumTopics request
forumTopics total_count:int32 topics:vector<forumTopic> next_offset_date:int32 next_offset_message_id:int53 next_offset_message_thread_id:int53 = ForumTopics;


//@description Options to be used for generation of a link preview
//@is_disabled True, if link preview must be disabled
//@url URL to use for link preview. If empty, then the first URL found in the message text will be used
//@force_small_media True, if shown media preview must be small; ignored in secret chats or if the URL isn't explicitly specified
//@force_large_media True, if shown media preview must be large; ignored in secret chats or if the URL isn't explicitly specified
//@show_above_text True, if link preview must be shown above message text; otherwise, the link preview will be shown below the message text; ignored in secret chats
linkPreviewOptions is_disabled:Bool url:string force_small_media:Bool force_large_media:Bool show_above_text:Bool = LinkPreviewOptions;


//@description Contains information about a user shared with a bot
//@user_id User identifier
//@first_name First name of the user; for bots only
//@last_name Last name of the user; for bots only
//@username Username of the user; for bots only
//@photo Profile photo of the user; for bots only; may be null
sharedUser user_id:int53 first_name:string last_name:string username:string photo:photo = SharedUser;

//@description Contains information about a chat shared with a bot
//@chat_id Chat identifier
//@title Title of the chat; for bots only
//@username Username of the chat; for bots only
//@photo Photo of the chat; for bots only; may be null
sharedChat chat_id:int53 title:string username:string photo:photo = SharedChat;


//@description Describes theme settings
//@accent_color Theme accent color in ARGB format
//@background The background to be used in chats; may be null
//@outgoing_message_fill The fill to be used as a background for outgoing messages
//@animate_outgoing_message_fill If true, the freeform gradient fill needs to be animated on every sent message
//@outgoing_message_accent_color Accent color of outgoing messages in ARGB format
themeSettings accent_color:int32 background:background outgoing_message_fill:BackgroundFill animate_outgoing_message_fill:Bool outgoing_message_accent_color:int32 = ThemeSettings;


//@class RichText @description Describes a formatted text object

//@description A plain text @text Text
richTextPlain text:string = RichText;

//@description A bold rich text @text Text
richTextBold text:RichText = RichText;

//@description An italicized rich text @text Text
richTextItalic text:RichText = RichText;

//@description An underlined rich text @text Text
richTextUnderline text:RichText = RichText;

//@description A strikethrough rich text @text Text
richTextStrikethrough text:RichText = RichText;

//@description A fixed-width rich text @text Text
richTextFixed text:RichText = RichText;

//@description A rich text URL link @text Text @url URL @is_cached True, if the URL has cached instant view server-side
richTextUrl text:RichText url:string is_cached:Bool = RichText;

//@description A rich text email link @text Text @email_address Email address
richTextEmailAddress text:RichText email_address:string = RichText;

//@description A subscript rich text @text Text
richTextSubscript text:RichText = RichText;

//@description A superscript rich text @text Text
richTextSuperscript text:RichText = RichText;

//@description A marked rich text @text Text
richTextMarked text:RichText = RichText;

//@description A rich text phone number @text Text @phone_number Phone number
richTextPhoneNumber text:RichText phone_number:string = RichText;

//@description A small image inside the text
//@document The image represented as a document. The image can be in GIF, JPEG or PNG format
//@width Width of a bounding box in which the image must be shown; 0 if unknown
//@height Height of a bounding box in which the image must be shown; 0 if unknown
richTextIcon document:document width:int32 height:int32 = RichText;

//@description A reference to a richTexts object on the same page @text The text @anchor_name The name of a richTextAnchor object, which is the first element of the target richTexts object @url An HTTP URL, opening the reference
richTextReference text:RichText anchor_name:string url:string = RichText;

//@description An anchor @name Anchor name
richTextAnchor name:string = RichText;

//@description A link to an anchor on the same page @text The link text @anchor_name The anchor name. If the name is empty, the link must bring back to top @url An HTTP URL, opening the anchor
richTextAnchorLink text:RichText anchor_name:string url:string = RichText;

//@description A concatenation of rich texts @texts Texts
richTexts texts:vector<RichText> = RichText;


//@description Contains a caption of another block @text Content of the caption @credit Block credit (like HTML tag <cite>)
pageBlockCaption text:RichText credit:RichText = PageBlockCaption;

//@description Describes an item of a list page block @label Item label @page_blocks Item blocks
pageBlockListItem label:string page_blocks:vector<PageBlock> = PageBlockListItem;

//@class PageBlockHorizontalAlignment @description Describes a horizontal alignment of a table cell content

//@description The content must be left-aligned
pageBlockHorizontalAlignmentLeft = PageBlockHorizontalAlignment;

//@description The content must be center-aligned
pageBlockHorizontalAlignmentCenter = PageBlockHorizontalAlignment;

//@description The content must be right-aligned
pageBlockHorizontalAlignmentRight = PageBlockHorizontalAlignment;

//@class PageBlockVerticalAlignment @description Describes a Vertical alignment of a table cell content

//@description The content must be top-aligned
pageBlockVerticalAlignmentTop = PageBlockVerticalAlignment;

//@description The content must be middle-aligned
pageBlockVerticalAlignmentMiddle = PageBlockVerticalAlignment;

//@description The content must be bottom-aligned
pageBlockVerticalAlignmentBottom = PageBlockVerticalAlignment;

//@description Represents a cell of a table
//@text Cell text; may be null. If the text is null, then the cell must be invisible
//@is_header True, if it is a header cell
//@colspan The number of columns the cell spans
//@rowspan The number of rows the cell spans
//@align Horizontal cell content alignment
//@valign Vertical cell content alignment
pageBlockTableCell text:RichText is_header:Bool colspan:int32 rowspan:int32 align:PageBlockHorizontalAlignment valign:PageBlockVerticalAlignment = PageBlockTableCell;

//@description Contains information about a related article
//@url Related article URL
//@title Article title; may be empty
//@param_description Article description; may be empty
//@photo Article photo; may be null
//@author Article author; may be empty
//@publish_date Point in time (Unix timestamp) when the article was published; 0 if unknown
pageBlockRelatedArticle url:string title:string description:string photo:photo author:string publish_date:int32 = PageBlockRelatedArticle;


//@class PageBlock @description Describes a block of an instant view for a web page

//@description The title of a page @title Title
pageBlockTitle title:RichText = PageBlock;

//@description The subtitle of a page @subtitle Subtitle
pageBlockSubtitle subtitle:RichText = PageBlock;

//@description The author and publishing date of a page @author Author @publish_date Point in time (Unix timestamp) when the article was published; 0 if unknown
pageBlockAuthorDate author:RichText publish_date:int32 = PageBlock;

//@description A header @header Header
pageBlockHeader header:RichText = PageBlock;

//@description A subheader @subheader Subheader
pageBlockSubheader subheader:RichText = PageBlock;

//@description A kicker @kicker Kicker
pageBlockKicker kicker:RichText = PageBlock;

//@description A text paragraph @text Paragraph text
pageBlockParagraph text:RichText = PageBlock;

//@description A preformatted text paragraph @text Paragraph text @language Programming language for which the text needs to be formatted
pageBlockPreformatted text:RichText language:string = PageBlock;

//@description The footer of a page @footer Footer
pageBlockFooter footer:RichText = PageBlock;

//@description An empty block separating a page
pageBlockDivider = PageBlock;

//@description An invisible anchor on a page, which can be used in a URL to open the page from the specified anchor @name Name of the anchor
pageBlockAnchor name:string = PageBlock;

//@description A list of data blocks @items The items of the list
pageBlockList items:vector<pageBlockListItem> = PageBlock;

//@description A block quote
//@text Quote text
//@credit Quote credit
pageBlockBlockQuote text:RichText credit:RichText = PageBlock;

//@description A pull quote
//@text Quote text
//@credit Quote credit
pageBlockPullQuote text:RichText credit:RichText = PageBlock;

//@description An animation
//@animation Animation file; may be null
//@caption Animation caption
//@need_autoplay True, if the animation must be played automatically
pageBlockAnimation animation:animation caption:pageBlockCaption need_autoplay:Bool = PageBlock;

//@description An audio file
//@audio Audio file; may be null
//@caption Audio file caption
pageBlockAudio audio:audio caption:pageBlockCaption = PageBlock;

//@description A photo
//@photo Photo file; may be null
//@caption Photo caption
//@url URL that needs to be opened when the photo is clicked
pageBlockPhoto photo:photo caption:pageBlockCaption url:string = PageBlock;

//@description A video
//@video Video file; may be null
//@caption Video caption
//@need_autoplay True, if the video must be played automatically
//@is_looped True, if the video must be looped
pageBlockVideo video:video caption:pageBlockCaption need_autoplay:Bool is_looped:Bool = PageBlock;

//@description A voice note
//@voice_note Voice note; may be null
//@caption Voice note caption
pageBlockVoiceNote voice_note:voiceNote caption:pageBlockCaption = PageBlock;

//@description A page cover
//@cover Cover
pageBlockCover cover:PageBlock = PageBlock;

//@description An embedded web page
//@url URL of the embedded page, if available
//@html HTML-markup of the embedded page
//@poster_photo Poster photo, if available; may be null
//@width Block width; 0 if unknown
//@height Block height; 0 if unknown
//@caption Block caption
//@is_full_width True, if the block must be full width
//@allow_scrolling True, if scrolling needs to be allowed
pageBlockEmbedded url:string html:string poster_photo:photo width:int32 height:int32 caption:pageBlockCaption is_full_width:Bool allow_scrolling:Bool = PageBlock;

//@description An embedded post
//@url URL of the embedded post
//@author Post author
//@author_photo Post author photo; may be null
//@date Point in time (Unix timestamp) when the post was created; 0 if unknown
//@page_blocks Post content
//@caption Post caption
pageBlockEmbeddedPost url:string author:string author_photo:photo date:int32 page_blocks:vector<PageBlock> caption:pageBlockCaption = PageBlock;

//@description A collage
//@page_blocks Collage item contents
//@caption Block caption
pageBlockCollage page_blocks:vector<PageBlock> caption:pageBlockCaption = PageBlock;

//@description A slideshow
//@page_blocks Slideshow item contents
//@caption Block caption
pageBlockSlideshow page_blocks:vector<PageBlock> caption:pageBlockCaption = PageBlock;

//@description A link to a chat
//@title Chat title
//@photo Chat photo; may be null
//@accent_color_id Identifier of the accent color for chat title and background of chat photo
//@username Chat username by which all other information about the chat can be resolved
pageBlockChatLink title:string photo:chatPhotoInfo accent_color_id:int32 username:string = PageBlock;

//@description A table
//@caption Table caption
//@cells Table cells
//@is_bordered True, if the table is bordered
//@is_striped True, if the table is striped
pageBlockTable caption:RichText cells:vector<vector<pageBlockTableCell>> is_bordered:Bool is_striped:Bool = PageBlock;

//@description A collapsible block
//@header Always visible heading for the block
//@page_blocks Block contents
//@is_open True, if the block is open by default
pageBlockDetails header:RichText page_blocks:vector<PageBlock> is_open:Bool = PageBlock;

//@description Related articles
//@header Block header
//@articles List of related articles
pageBlockRelatedArticles header:RichText articles:vector<pageBlockRelatedArticle> = PageBlock;

//@description A map
//@location Location of the map center
//@zoom Map zoom level
//@width Map width
//@height Map height
//@caption Block caption
pageBlockMap location:location zoom:int32 width:int32 height:int32 caption:pageBlockCaption = PageBlock;


//@description Describes an instant view page for a web page
//@page_blocks Content of the instant view page
//@view_count Number of the instant view views; 0 if unknown
//@version Version of the instant view; currently, can be 1 or 2
//@is_rtl True, if the instant view must be shown from right to left
//@is_full True, if the instant view contains the full page. A network request might be needed to get the full instant view
//@feedback_link An internal link to be opened to leave feedback about the instant view
webPageInstantView page_blocks:vector<PageBlock> view_count:int32 version:int32 is_rtl:Bool is_full:Bool feedback_link:InternalLinkType = WebPageInstantView;


//@class LinkPreviewAlbumMedia @description Describes a media from a link preview album

//@description The media is a photo @photo Photo description
linkPreviewAlbumMediaPhoto photo:photo = LinkPreviewAlbumMedia;

//@description The media is a video @video Video description
linkPreviewAlbumMediaVideo video:video = LinkPreviewAlbumMedia;


//@class LinkPreviewType @description Describes type of link preview

//@description The link is a link to a media album consisting of photos and videos @media The list of album media @caption Album caption
linkPreviewTypeAlbum media:vector<LinkPreviewAlbumMedia> caption:string = LinkPreviewType;

//@description The link is a link to an animation @animation The animation
linkPreviewTypeAnimation animation:animation = LinkPreviewType;

//@description The link is a link to an app at App Store or Google Play @photo Photo for the app
linkPreviewTypeApp photo:photo = LinkPreviewType;

//@description The link is a link to a web site @photo Article's main photo; may be null
linkPreviewTypeArticle photo:photo = LinkPreviewType;

//@description The link is a link to an audio @audio The audio description
linkPreviewTypeAudio audio:audio = LinkPreviewType;

//@description The link is a link to a background. Link preview title and description are available only for filled backgrounds
//@document Document with the background; may be null for filled backgrounds
//@background_type Type of the background; may be null if unknown
linkPreviewTypeBackground document:document background_type:BackgroundType = LinkPreviewType;

//@description The link is a link to boost a channel chat @photo Photo of the chat; may be null
linkPreviewTypeChannelBoost photo:chatPhoto = LinkPreviewType;

//@description The link is a link to a chat
//@type Type of the chat
//@photo Photo of the chat; may be null
//@creates_join_request True, if the link only creates join request
linkPreviewTypeChat type:InviteLinkChatType photo:chatPhoto creates_join_request:Bool = LinkPreviewType;

//@description The link is a link to a general file @document The document description
linkPreviewTypeDocument document:document = LinkPreviewType;

//@description The link is a link to an animation player
//@url URL of the external animation player
//@thumbnail Thumbnail of the animation; may be null if unknown
//@duration Duration of the animation, in seconds
//@width Expected width of the embedded player
//@height Expected height of the embedded player
linkPreviewTypeEmbeddedAnimationPlayer url:string thumbnail:photo duration:int32 width:int32 height:int32 = LinkPreviewType;

//@description The link is a link to an audio player
//@url URL of the external audio player
//@thumbnail Thumbnail of the audio; may be null if unknown
//@duration Duration of the audio, in seconds
//@width Expected width of the embedded player
//@height Expected height of the embedded player
linkPreviewTypeEmbeddedAudioPlayer url:string thumbnail:photo duration:int32 width:int32 height:int32 = LinkPreviewType;

//@description The link is a link to a video player
//@url URL of the external video player
//@thumbnail Thumbnail of the video; may be null if unknown
//@duration Duration of the video, in seconds
//@width Expected width of the embedded player
//@height Expected height of the embedded player
linkPreviewTypeEmbeddedVideoPlayer url:string thumbnail:photo duration:int32 width:int32 height:int32 = LinkPreviewType;

//@description The link is a link to an audio file
//@url URL of the audio file
//@mime_type MIME type of the audio file
//@duration Duration of the audio, in seconds; 0 if unknown
linkPreviewTypeExternalAudio url:string mime_type:string duration:int32 = LinkPreviewType;

//@description The link is a link to a video file
//@url URL of the video file
//@mime_type MIME type of the video file
//@width Expected width of the video preview; 0 if unknown
//@height Expected height of the video preview; 0 if unknown
//@duration Duration of the video, in seconds; 0 if unknown
linkPreviewTypeExternalVideo url:string mime_type:string width:int32 height:int32 duration:int32 = LinkPreviewType;

//@description The link is a link to an invoice
linkPreviewTypeInvoice = LinkPreviewType;

//@description The link is a link to a text or a poll Telegram message
linkPreviewTypeMessage = LinkPreviewType;

//@description The link is a link to a photo @photo The photo
linkPreviewTypePhoto photo:photo = LinkPreviewType;

//@description The link is a link to a Telegram Premium gift code
linkPreviewTypePremiumGiftCode = LinkPreviewType;

//@description The link is a link to a shareable chat folder
linkPreviewTypeShareableChatFolder = LinkPreviewType;

//@description The link is a link to a sticker @sticker The sticker. It can be an arbitrary WEBP image and can have dimensions bigger than 512
linkPreviewTypeSticker sticker:sticker = LinkPreviewType;

//@description The link is a link to a sticker set @stickers Up to 4 stickers from the sticker set
linkPreviewTypeStickerSet stickers:vector<sticker> = LinkPreviewType;

//@description The link is a link to a story. Link preview description is unavailable @story_sender_chat_id The identifier of the chat that posted the story @story_id Story identifier
linkPreviewTypeStory story_sender_chat_id:int53 story_id:int32 = LinkPreviewType;

//@description The link is a link to boost a supergroup chat @photo Photo of the chat; may be null
linkPreviewTypeSupergroupBoost photo:chatPhoto = LinkPreviewType;

//@description The link is a link to a cloud theme. TDLib has no theme support yet @documents The list of files with theme description @settings Settings for the cloud theme; may be null if unknown
linkPreviewTypeTheme documents:vector<document> settings:themeSettings = LinkPreviewType;

//@description The link preview type is unsupported yet
linkPreviewTypeUnsupported = LinkPreviewType;

//@description The link is a link to an upgraded gift @gift The gift
linkPreviewTypeUpgradedGift gift:upgradedGift = LinkPreviewType;

//@description The link is a link to a user @photo Photo of the user; may be null if none @is_bot True, if the user is a bot
linkPreviewTypeUser photo:chatPhoto is_bot:Bool = LinkPreviewType;

//@description The link is a link to a video
//@video The video description
//@cover Cover of the video; may be null if none
//@start_timestamp Timestamp from which the video playing must start, in seconds
linkPreviewTypeVideo video:video cover:photo start_timestamp:int32 = LinkPreviewType;

//@description The link is a link to a video chat
//@photo Photo of the chat with the video chat; may be null if none
//@is_live_stream True, if the video chat is expected to be a live stream in a channel or a broadcast group
linkPreviewTypeVideoChat photo:chatPhoto is_live_stream:Bool = LinkPreviewType;

//@description The link is a link to a video note message @video_note The video note
linkPreviewTypeVideoNote video_note:videoNote = LinkPreviewType;

//@description The link is a link to a voice note message @voice_note The voice note
linkPreviewTypeVoiceNote voice_note:voiceNote = LinkPreviewType;

//@description The link is a link to a Web App @photo Web App photo; may be null if none
linkPreviewTypeWebApp photo:photo = LinkPreviewType;


//@description Describes a link preview
//@url Original URL of the link
//@display_url URL to display
//@site_name Short name of the site (e.g., Google Docs, App Store)
//@title Title of the content
//@param_description Description of the content
//@author Author of the content
//@type Type of the link preview
//@has_large_media True, if size of media in the preview can be changed
//@show_large_media True, if large media preview must be shown; otherwise, the media preview must be shown small and only the first frame must be shown for videos
//@show_media_above_description True, if media must be shown above link preview description; otherwise, the media must be shown below the description
//@skip_confirmation True, if there is no need to show an ordinary open URL confirmation, when opening the URL from the preview, because the URL is shown in the message text in clear
//@show_above_text True, if the link preview must be shown above message text; otherwise, the link preview must be shown below the message text
//@instant_view_version Version of instant view (currently, can be 1 or 2) for the web page; 0 if none
linkPreview url:string display_url:string site_name:string title:string description:formattedText author:string type:LinkPreviewType has_large_media:Bool show_large_media:Bool show_media_above_description:Bool skip_confirmation:Bool show_above_text:Bool instant_view_version:int32 = LinkPreview;


//@description Contains information about a country
//@country_code A two-letter ISO 3166-1 alpha-2 country code
//@name Native name of the country
//@english_name English name of the country
//@is_hidden True, if the country must be hidden from the list of all countries
//@calling_codes List of country calling codes
countryInfo country_code:string name:string english_name:string is_hidden:Bool calling_codes:vector<string> = CountryInfo;

//@description Contains information about countries @countries The list of countries
countries countries:vector<countryInfo> = Countries;

//@description Contains information about a phone number
//@country Information about the country to which the phone number belongs; may be null
//@country_calling_code The part of the phone number denoting country calling code or its part
//@formatted_phone_number The phone number without country calling code formatted accordingly to local rules. Expected digits are returned as '-', but even more digits might be entered by the user
//@is_anonymous True, if the phone number was bought at https://fragment.com and isn't tied to a SIM card. Information about the phone number can be received using getCollectibleItemInfo
phoneNumberInfo country:countryInfo country_calling_code:string formatted_phone_number:string is_anonymous:Bool = PhoneNumberInfo;


//@class CollectibleItemType @description Describes a collectible item that can be purchased at https://fragment.com

//@description A username @username The username
collectibleItemTypeUsername username:string = CollectibleItemType;

//@description A phone number @phone_number The phone number
collectibleItemTypePhoneNumber phone_number:string = CollectibleItemType;


//@description Contains information about a collectible item and its last purchase
//@purchase_date Point in time (Unix timestamp) when the item was purchased
//@currency Currency for the paid amount
//@amount The paid amount, in the smallest units of the currency
//@cryptocurrency Cryptocurrency used to pay for the item
//@cryptocurrency_amount The paid amount, in the smallest units of the cryptocurrency
//@url Individual URL for the item on https://fragment.com
collectibleItemInfo purchase_date:int32 currency:string amount:int53 cryptocurrency:string cryptocurrency_amount:int64 url:string = CollectibleItemInfo;


//@description Describes an action associated with a bank card number @text Action text @url The URL to be opened
bankCardActionOpenUrl text:string url:string = BankCardActionOpenUrl;

//@description Information about a bank card @title Title of the bank card description @actions Actions that can be done with the bank card number
bankCardInfo title:string actions:vector<bankCardActionOpenUrl> = BankCardInfo;


//@description Describes an address
//@country_code A two-letter ISO 3166-1 alpha-2 country code
//@state State, if applicable
//@city City
//@street_line1 First line of the address
//@street_line2 Second line of the address
//@postal_code Address postal code
address country_code:string state:string city:string street_line1:string street_line2:string postal_code:string = Address;

//@description Describes an address of a location
//@country_code A two-letter ISO 3166-1 alpha-2 country code
//@state State, if applicable; empty if unknown
//@city City; empty if unknown
//@street The address; empty if unknown
locationAddress country_code:string state:string city:string street:string = LocationAddress;


//@description Portion of the price of a product (e.g., "delivery cost", "tax amount") @label Label for this portion of the product price @amount Currency amount in the smallest units of the currency
labeledPricePart label:string amount:int53 = LabeledPricePart;

//@description Product invoice
//@currency ISO 4217 currency code
//@price_parts A list of objects used to calculate the total price of the product
//@subscription_period The number of seconds between consecutive Telegram Star debiting for subscription invoices; 0 if the invoice doesn't create subscription
//@max_tip_amount The maximum allowed amount of tip in the smallest units of the currency
//@suggested_tip_amounts Suggested amounts of tip in the smallest units of the currency
//@recurring_payment_terms_of_service_url An HTTP URL with terms of service for recurring payments. If non-empty, the invoice payment will result in recurring payments and the user must accept the terms of service before allowed to pay
//@terms_of_service_url An HTTP URL with terms of service for non-recurring payments. If non-empty, then the user must accept the terms of service before allowed to pay
//@is_test True, if the payment is a test payment
//@need_name True, if the user's name is needed for payment
//@need_phone_number True, if the user's phone number is needed for payment
//@need_email_address True, if the user's email address is needed for payment
//@need_shipping_address True, if the user's shipping address is needed for payment
//@send_phone_number_to_provider True, if the user's phone number will be sent to the provider
//@send_email_address_to_provider True, if the user's email address will be sent to the provider
//@is_flexible True, if the total price depends on the shipping method
invoice currency:string price_parts:vector<labeledPricePart> subscription_period:int32 max_tip_amount:int53 suggested_tip_amounts:vector<int53> recurring_payment_terms_of_service_url:string terms_of_service_url:string is_test:Bool need_name:Bool need_phone_number:Bool need_email_address:Bool need_shipping_address:Bool send_phone_number_to_provider:Bool send_email_address_to_provider:Bool is_flexible:Bool = Invoice;

//@description Order information
//@name Name of the user
//@phone_number Phone number of the user
//@email_address Email address of the user
//@shipping_address Shipping address for this order; may be null
orderInfo name:string phone_number:string email_address:string shipping_address:address = OrderInfo;

//@description One shipping option
//@id Shipping option identifier
//@title Option title
//@price_parts A list of objects used to calculate the total shipping costs
shippingOption id:string title:string price_parts:vector<labeledPricePart> = ShippingOption;

//@description Contains information about saved payment credentials @id Unique identifier of the saved credentials @title Title of the saved credentials
savedCredentials id:string title:string = SavedCredentials;


//@class InputCredentials @description Contains information about the payment method chosen by the user

//@description Applies if a user chooses some previously saved payment credentials. To use their previously saved credentials, the user must have a valid temporary password @saved_credentials_id Identifier of the saved credentials
inputCredentialsSaved saved_credentials_id:string = InputCredentials;

//@description Applies if a user enters new credentials on a payment provider website @data JSON-encoded data with the credential identifier from the payment provider @allow_save True, if the credential identifier can be saved on the server side
inputCredentialsNew data:string allow_save:Bool = InputCredentials;

//@description Applies if a user enters new credentials using Apple Pay @data JSON-encoded data with the credential identifier
inputCredentialsApplePay data:string = InputCredentials;

//@description Applies if a user enters new credentials using Google Pay @data JSON-encoded data with the credential identifier
inputCredentialsGooglePay data:string = InputCredentials;


//@class PaymentProvider @description Contains information about a payment provider

//@description Smart Glocal payment provider @public_token Public payment token @tokenize_url URL for sending card tokenization requests
paymentProviderSmartGlocal public_token:string tokenize_url:string = PaymentProvider;

//@description Stripe payment provider
//@publishable_key Stripe API publishable key
//@need_country True, if the user country must be provided
//@need_postal_code True, if the user ZIP/postal code must be provided
//@need_cardholder_name True, if the cardholder name must be provided
paymentProviderStripe publishable_key:string need_country:Bool need_postal_code:Bool need_cardholder_name:Bool = PaymentProvider;

//@description Some other payment provider, for which a web payment form must be shown @url Payment form URL
paymentProviderOther url:string = PaymentProvider;


//@description Describes an additional payment option @title Title for the payment option @url Payment form URL to be opened in a web view
paymentOption title:string url:string = PaymentOption;


//@class PaymentFormType @description Describes type of payment form

//@description The payment form is for a regular payment
//@invoice Full information about the invoice
//@payment_provider_user_id User identifier of the payment provider bot
//@payment_provider Information about the payment provider
//@additional_payment_options The list of additional payment options
//@saved_order_info Saved server-side order information; may be null
//@saved_credentials The list of saved payment credentials
//@can_save_credentials True, if the user can choose to save credentials
//@need_password True, if the user will be able to save credentials, if sets up a 2-step verification password
paymentFormTypeRegular invoice:invoice payment_provider_user_id:int53 payment_provider:PaymentProvider additional_payment_options:vector<paymentOption> saved_order_info:orderInfo saved_credentials:vector<savedCredentials> can_save_credentials:Bool need_password:Bool = PaymentFormType;

//@description The payment form is for a payment in Telegram Stars @star_count Number of Telegram Stars that will be paid
paymentFormTypeStars star_count:int53 = PaymentFormType;

//@description The payment form is for a payment in Telegram Stars for subscription @pricing Information about subscription plan
paymentFormTypeStarSubscription pricing:starSubscriptionPricing = PaymentFormType;


//@description Contains information about an invoice payment form
//@id The payment form identifier
//@type Type of the payment form
//@seller_bot_user_id User identifier of the seller bot
//@product_info Information about the product
paymentForm id:int64 type:PaymentFormType seller_bot_user_id:int53 product_info:productInfo = PaymentForm;

//@description Contains a temporary identifier of validated order information, which is stored for one hour, and the available shipping options @order_info_id Temporary identifier of the order information @shipping_options Available shipping options
validatedOrderInfo order_info_id:string shipping_options:vector<shippingOption> = ValidatedOrderInfo;

//@description Contains the result of a payment request @success True, if the payment request was successful; otherwise, the verification_url will be non-empty @verification_url URL for additional payment credentials verification
paymentResult success:Bool verification_url:string = PaymentResult;


//@class PaymentReceiptType @description Describes type of successful payment

//@description The payment was done using a third-party payment provider
//@payment_provider_user_id User identifier of the payment provider bot
//@invoice Information about the invoice
//@order_info Order information; may be null
//@shipping_option Chosen shipping option; may be null
//@credentials_title Title of the saved credentials chosen by the buyer
//@tip_amount The amount of tip chosen by the buyer in the smallest units of the currency
paymentReceiptTypeRegular payment_provider_user_id:int53 invoice:invoice order_info:orderInfo shipping_option:shippingOption credentials_title:string tip_amount:int53 = PaymentReceiptType;

//@description The payment was done using Telegram Stars
//@star_count Number of Telegram Stars that were paid
//@transaction_id Unique identifier of the transaction that can be used to dispute it
paymentReceiptTypeStars star_count:int53 transaction_id:string = PaymentReceiptType;


//@description Contains information about a successful payment
//@product_info Information about the product
//@date Point in time (Unix timestamp) when the payment was made
//@seller_bot_user_id User identifier of the seller bot
//@type Type of the payment receipt
paymentReceipt product_info:productInfo date:int32 seller_bot_user_id:int53 type:PaymentReceiptType = PaymentReceipt;


//@class InputInvoice @description Describes an invoice to process

//@description An invoice from a message of the type messageInvoice or paid media purchase from messagePaidMedia
//@chat_id Chat identifier of the message
//@message_id Message identifier. Use messageProperties.can_be_paid to check whether the message can be used in the method
inputInvoiceMessage chat_id:int53 message_id:int53 = InputInvoice;

//@description An invoice from a link of the type internalLinkTypeInvoice @name Name of the invoice
inputInvoiceName name:string = InputInvoice;

//@description An invoice for a payment toward Telegram; must not be used in the in-store apps @purpose Transaction purpose
inputInvoiceTelegram purpose:TelegramPaymentPurpose = InputInvoice;


//@class PaidMedia @description Describes a paid media

//@description The media is hidden until the invoice is paid
//@width Media width; 0 if unknown
//@height Media height; 0 if unknown
//@duration Media duration, in seconds; 0 if unknown
//@minithumbnail Media minithumbnail; may be null
paidMediaPreview width:int32 height:int32 duration:int32 minithumbnail:minithumbnail = PaidMedia;

//@description The media is a photo @photo The photo
paidMediaPhoto photo:photo = PaidMedia;

//@description The media is a video
//@video The video
//@cover Cover of the video; may be null if none
//@start_timestamp Timestamp from which the video playing must start, in seconds
paidMediaVideo video:video cover:photo start_timestamp:int32 = PaidMedia;

//@description The media is unsupported
paidMediaUnsupported = PaidMedia;


//@description Describes parameters of a giveaway
//@boosted_chat_id Identifier of the supergroup or channel chat, which will be automatically boosted by the winners of the giveaway for duration of the Telegram Premium subscription,
//-or for the specified time. If the chat is a channel, then can_post_messages right is required in the channel, otherwise, the user must be an administrator in the supergroup
//@additional_chat_ids Identifiers of other supergroup or channel chats that must be subscribed by the users to be eligible for the giveaway. There can be up to getOption("giveaway_additional_chat_count_max") additional chats
//@winners_selection_date Point in time (Unix timestamp) when the giveaway is expected to be performed; must be 60-getOption("giveaway_duration_max") seconds in the future in scheduled giveaways
//@only_new_members True, if only new members of the chats will be eligible for the giveaway
//@has_public_winners True, if the list of winners of the giveaway will be available to everyone
//@country_codes The list of two-letter ISO 3166-1 alpha-2 codes of countries, users from which will be eligible for the giveaway. If empty, then all users can participate in the giveaway.
//-There can be up to getOption("giveaway_country_count_max") chosen countries. Users with phone number that was bought at https://fragment.com can participate in any giveaway and the country code "FT" must not be specified in the list
//@prize_description Additional description of the giveaway prize; 0-128 characters
giveawayParameters boosted_chat_id:int53 additional_chat_ids:vector<int53> winners_selection_date:int32 only_new_members:Bool has_public_winners:Bool country_codes:vector<string> prize_description:string = GiveawayParameters;


//@description File with the date it was uploaded @file The file @date Point in time (Unix timestamp) when the file was uploaded
datedFile file:file date:int32 = DatedFile;


//@class PassportElementType @description Contains the type of Telegram Passport element

//@description A Telegram Passport element containing the user's personal details
passportElementTypePersonalDetails = PassportElementType;

//@description A Telegram Passport element containing the user's passport
passportElementTypePassport = PassportElementType;

//@description A Telegram Passport element containing the user's driver license
passportElementTypeDriverLicense = PassportElementType;

//@description A Telegram Passport element containing the user's identity card
passportElementTypeIdentityCard = PassportElementType;

//@description A Telegram Passport element containing the user's internal passport
passportElementTypeInternalPassport = PassportElementType;

//@description A Telegram Passport element containing the user's address
passportElementTypeAddress = PassportElementType;

//@description A Telegram Passport element containing the user's utility bill
passportElementTypeUtilityBill = PassportElementType;

//@description A Telegram Passport element containing the user's bank statement
passportElementTypeBankStatement = PassportElementType;

//@description A Telegram Passport element containing the user's rental agreement
passportElementTypeRentalAgreement = PassportElementType;

//@description A Telegram Passport element containing the registration page of the user's passport
passportElementTypePassportRegistration = PassportElementType;

//@description A Telegram Passport element containing the user's temporary registration
passportElementTypeTemporaryRegistration = PassportElementType;

//@description A Telegram Passport element containing the user's phone number
passportElementTypePhoneNumber = PassportElementType;

//@description A Telegram Passport element containing the user's email address
passportElementTypeEmailAddress = PassportElementType;


//@description Represents a date according to the Gregorian calendar @day Day of the month; 1-31 @month Month; 1-12 @year Year; 1-9999
date day:int32 month:int32 year:int32 = Date;

//@description Contains the user's personal details
//@first_name First name of the user written in English; 1-255 characters
//@middle_name Middle name of the user written in English; 0-255 characters
//@last_name Last name of the user written in English; 1-255 characters
//@native_first_name Native first name of the user; 1-255 characters
//@native_middle_name Native middle name of the user; 0-255 characters
//@native_last_name Native last name of the user; 1-255 characters
//@birthdate Birthdate of the user
//@gender Gender of the user, "male" or "female"
//@country_code A two-letter ISO 3166-1 alpha-2 country code of the user's country
//@residence_country_code A two-letter ISO 3166-1 alpha-2 country code of the user's residence country
personalDetails first_name:string middle_name:string last_name:string native_first_name:string native_middle_name:string native_last_name:string birthdate:date gender:string country_code:string residence_country_code:string = PersonalDetails;

//@description An identity document
//@number Document number; 1-24 characters
//@expiration_date Document expiration date; may be null if not applicable
//@front_side Front side of the document
//@reverse_side Reverse side of the document; only for driver license and identity card; may be null
//@selfie Selfie with the document; may be null
//@translation List of files containing a certified English translation of the document
identityDocument number:string expiration_date:date front_side:datedFile reverse_side:datedFile selfie:datedFile translation:vector<datedFile> = IdentityDocument;

//@description An identity document to be saved to Telegram Passport
//@number Document number; 1-24 characters
//@expiration_date Document expiration date; pass null if not applicable
//@front_side Front side of the document
//@reverse_side Reverse side of the document; only for driver license and identity card; pass null otherwise
//@selfie Selfie with the document; pass null if unavailable
//@translation List of files containing a certified English translation of the document
inputIdentityDocument number:string expiration_date:date front_side:InputFile reverse_side:InputFile selfie:InputFile translation:vector<InputFile> = InputIdentityDocument;

//@description A personal document, containing some information about a user @files List of files containing the pages of the document @translation List of files containing a certified English translation of the document
personalDocument files:vector<datedFile> translation:vector<datedFile> = PersonalDocument;

//@description A personal document to be saved to Telegram Passport @files List of files containing the pages of the document @translation List of files containing a certified English translation of the document
inputPersonalDocument files:vector<InputFile> translation:vector<InputFile> = InputPersonalDocument;


//@class PassportElement @description Contains information about a Telegram Passport element

//@description A Telegram Passport element containing the user's personal details @personal_details Personal details of the user
passportElementPersonalDetails personal_details:personalDetails = PassportElement;

//@description A Telegram Passport element containing the user's passport @passport Passport
passportElementPassport passport:identityDocument = PassportElement;

//@description A Telegram Passport element containing the user's driver license @driver_license Driver license
passportElementDriverLicense driver_license:identityDocument = PassportElement;

//@description A Telegram Passport element containing the user's identity card @identity_card Identity card
passportElementIdentityCard identity_card:identityDocument = PassportElement;

//@description A Telegram Passport element containing the user's internal passport @internal_passport Internal passport
passportElementInternalPassport internal_passport:identityDocument = PassportElement;

//@description A Telegram Passport element containing the user's address @address Address
passportElementAddress address:address = PassportElement;

//@description A Telegram Passport element containing the user's utility bill @utility_bill Utility bill
passportElementUtilityBill utility_bill:personalDocument = PassportElement;

//@description A Telegram Passport element containing the user's bank statement @bank_statement Bank statement
passportElementBankStatement bank_statement:personalDocument = PassportElement;

//@description A Telegram Passport element containing the user's rental agreement @rental_agreement Rental agreement
passportElementRentalAgreement rental_agreement:personalDocument = PassportElement;

//@description A Telegram Passport element containing the user's passport registration pages @passport_registration Passport registration pages
passportElementPassportRegistration passport_registration:personalDocument = PassportElement;

//@description A Telegram Passport element containing the user's temporary registration @temporary_registration Temporary registration
passportElementTemporaryRegistration temporary_registration:personalDocument = PassportElement;

//@description A Telegram Passport element containing the user's phone number @phone_number Phone number
passportElementPhoneNumber phone_number:string = PassportElement;

//@description A Telegram Passport element containing the user's email address @email_address Email address
passportElementEmailAddress email_address:string = PassportElement;


//@class InputPassportElement @description Contains information about a Telegram Passport element to be saved

//@description A Telegram Passport element to be saved containing the user's personal details @personal_details Personal details of the user
inputPassportElementPersonalDetails personal_details:personalDetails = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's passport @passport The passport to be saved
inputPassportElementPassport passport:inputIdentityDocument = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's driver license @driver_license The driver license to be saved
inputPassportElementDriverLicense driver_license:inputIdentityDocument = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's identity card @identity_card The identity card to be saved
inputPassportElementIdentityCard identity_card:inputIdentityDocument = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's internal passport @internal_passport The internal passport to be saved
inputPassportElementInternalPassport internal_passport:inputIdentityDocument = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's address @address The address to be saved
inputPassportElementAddress address:address = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's utility bill @utility_bill The utility bill to be saved
inputPassportElementUtilityBill utility_bill:inputPersonalDocument = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's bank statement @bank_statement The bank statement to be saved
inputPassportElementBankStatement bank_statement:inputPersonalDocument = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's rental agreement @rental_agreement The rental agreement to be saved
inputPassportElementRentalAgreement rental_agreement:inputPersonalDocument = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's passport registration @passport_registration The passport registration page to be saved
inputPassportElementPassportRegistration passport_registration:inputPersonalDocument = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's temporary registration @temporary_registration The temporary registration document to be saved
inputPassportElementTemporaryRegistration temporary_registration:inputPersonalDocument = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's phone number @phone_number The phone number to be saved
inputPassportElementPhoneNumber phone_number:string = InputPassportElement;

//@description A Telegram Passport element to be saved containing the user's email address @email_address The email address to be saved
inputPassportElementEmailAddress email_address:string = InputPassportElement;


//@description Contains information about saved Telegram Passport elements @elements Telegram Passport elements
passportElements elements:vector<PassportElement> = PassportElements;


//@class PassportElementErrorSource @description Contains the description of an error in a Telegram Passport element

//@description The element contains an error in an unspecified place. The error will be considered resolved when new data is added
passportElementErrorSourceUnspecified = PassportElementErrorSource;

//@description One of the data fields contains an error. The error will be considered resolved when the value of the field changes @field_name Field name
passportElementErrorSourceDataField field_name:string = PassportElementErrorSource;

//@description The front side of the document contains an error. The error will be considered resolved when the file with the front side changes
passportElementErrorSourceFrontSide = PassportElementErrorSource;

//@description The reverse side of the document contains an error. The error will be considered resolved when the file with the reverse side changes
passportElementErrorSourceReverseSide = PassportElementErrorSource;

//@description The selfie with the document contains an error. The error will be considered resolved when the file with the selfie changes
passportElementErrorSourceSelfie = PassportElementErrorSource;

//@description One of files with the translation of the document contains an error. The error will be considered resolved when the file changes @file_index Index of a file with the error
passportElementErrorSourceTranslationFile file_index:int32 = PassportElementErrorSource;

//@description The translation of the document contains an error. The error will be considered resolved when the list of translation files changes
passportElementErrorSourceTranslationFiles = PassportElementErrorSource;

//@description The file contains an error. The error will be considered resolved when the file changes @file_index Index of a file with the error
passportElementErrorSourceFile file_index:int32 = PassportElementErrorSource;

//@description The list of attached files contains an error. The error will be considered resolved when the list of files changes
passportElementErrorSourceFiles = PassportElementErrorSource;


//@description Contains the description of an error in a Telegram Passport element @type Type of the Telegram Passport element which has the error @message Error message @source Error source
passportElementError type:PassportElementType message:string source:PassportElementErrorSource = PassportElementError;


//@description Contains information about a Telegram Passport element that was requested by a service
//@type Type of the element
//@is_selfie_required True, if a selfie is required with the identity document
//@is_translation_required True, if a certified English translation is required with the document
//@is_native_name_required True, if personal details must include the user's name in the language of their country of residence
passportSuitableElement type:PassportElementType is_selfie_required:Bool is_translation_required:Bool is_native_name_required:Bool = PassportSuitableElement;

//@description Contains a description of the required Telegram Passport element that was requested by a service @suitable_elements List of Telegram Passport elements any of which is enough to provide
passportRequiredElement suitable_elements:vector<passportSuitableElement> = PassportRequiredElement;

//@description Contains information about a Telegram Passport authorization form that was requested
//@id Unique identifier of the authorization form
//@required_elements Telegram Passport elements that must be provided to complete the form
//@privacy_policy_url URL for the privacy policy of the service; may be empty
passportAuthorizationForm id:int32 required_elements:vector<passportRequiredElement> privacy_policy_url:string = PassportAuthorizationForm;

//@description Contains information about a Telegram Passport elements and corresponding errors @elements Telegram Passport elements @errors Errors in the elements that are already available
passportElementsWithErrors elements:vector<PassportElement> errors:vector<passportElementError> = PassportElementsWithErrors;


//@description Contains encrypted Telegram Passport data credentials @data The encrypted credentials @hash The decrypted data hash @secret Secret for data decryption, encrypted with the service's public key
encryptedCredentials data:bytes hash:bytes secret:bytes = EncryptedCredentials;


//@description Contains information about an encrypted Telegram Passport element; for bots only
//@type Type of Telegram Passport element
//@data Encrypted JSON-encoded data about the user
//@front_side The front side of an identity document
//@reverse_side The reverse side of an identity document; may be null
//@selfie Selfie with the document; may be null
//@translation List of files containing a certified English translation of the document
//@files List of attached files
//@value Unencrypted data, phone number or email address
//@hash Hash of the entire element
encryptedPassportElement type:PassportElementType data:bytes front_side:datedFile reverse_side:datedFile selfie:datedFile translation:vector<datedFile> files:vector<datedFile> value:string hash:string = EncryptedPassportElement;


//@class InputPassportElementErrorSource @description Contains the description of an error in a Telegram Passport element; for bots only

//@description The element contains an error in an unspecified place. The error will be considered resolved when new data is added @element_hash Current hash of the entire element
inputPassportElementErrorSourceUnspecified element_hash:bytes = InputPassportElementErrorSource;

//@description A data field contains an error. The error is considered resolved when the field's value changes @field_name Field name @data_hash Current data hash
inputPassportElementErrorSourceDataField field_name:string data_hash:bytes = InputPassportElementErrorSource;

//@description The front side of the document contains an error. The error is considered resolved when the file with the front side of the document changes @file_hash Current hash of the file containing the front side
inputPassportElementErrorSourceFrontSide file_hash:bytes = InputPassportElementErrorSource;

//@description The reverse side of the document contains an error. The error is considered resolved when the file with the reverse side of the document changes @file_hash Current hash of the file containing the reverse side
inputPassportElementErrorSourceReverseSide file_hash:bytes = InputPassportElementErrorSource;

//@description The selfie contains an error. The error is considered resolved when the file with the selfie changes @file_hash Current hash of the file containing the selfie
inputPassportElementErrorSourceSelfie file_hash:bytes = InputPassportElementErrorSource;

//@description One of the files containing the translation of the document contains an error. The error is considered resolved when the file with the translation changes @file_hash Current hash of the file containing the translation
inputPassportElementErrorSourceTranslationFile file_hash:bytes = InputPassportElementErrorSource;

//@description The translation of the document contains an error. The error is considered resolved when the list of files changes @file_hashes Current hashes of all files with the translation
inputPassportElementErrorSourceTranslationFiles file_hashes:vector<bytes> = InputPassportElementErrorSource;

//@description The file contains an error. The error is considered resolved when the file changes @file_hash Current hash of the file which has the error
inputPassportElementErrorSourceFile file_hash:bytes = InputPassportElementErrorSource;

//@description The list of attached files contains an error. The error is considered resolved when the file list changes @file_hashes Current hashes of all attached files
inputPassportElementErrorSourceFiles file_hashes:vector<bytes> = InputPassportElementErrorSource;


//@description Contains the description of an error in a Telegram Passport element; for bots only @type Type of Telegram Passport element that has the error @message Error message @source Error source
inputPassportElementError type:PassportElementType message:string source:InputPassportElementErrorSource = InputPassportElementError;


//@class MessageContent @description Contains the content of a message

//@description A text message
//@text Text of the message
//@link_preview A link preview attached to the message; may be null
//@link_preview_options Options which were used for generation of the link preview; may be null if default options were used
messageText text:formattedText link_preview:linkPreview link_preview_options:linkPreviewOptions = MessageContent;

//@description An animation message (GIF-style).
//@animation The animation description
//@caption Animation caption
//@show_caption_above_media True, if the caption must be shown above the animation; otherwise, the caption must be shown below the animation
//@has_spoiler True, if the animation preview must be covered by a spoiler animation
//@is_secret True, if the animation thumbnail must be blurred and the animation must be shown only while tapped
messageAnimation animation:animation caption:formattedText show_caption_above_media:Bool has_spoiler:Bool is_secret:Bool = MessageContent;

//@description An audio message @audio The audio description @caption Audio caption
messageAudio audio:audio caption:formattedText = MessageContent;

//@description A document message (general file) @document The document description @caption Document caption
messageDocument document:document caption:formattedText = MessageContent;

//@description A message with paid media
//@star_count Number of Telegram Stars needed to buy access to the media in the message
//@media Information about the media
//@caption Media caption
//@show_caption_above_media True, if the caption must be shown above the media; otherwise, the caption must be shown below the media
messagePaidMedia star_count:int53 media:vector<PaidMedia> caption:formattedText show_caption_above_media:Bool = MessageContent;

//@description A photo message
//@photo The photo
//@caption Photo caption
//@show_caption_above_media True, if the caption must be shown above the photo; otherwise, the caption must be shown below the photo
//@has_spoiler True, if the photo preview must be covered by a spoiler animation
//@is_secret True, if the photo must be blurred and must be shown only while tapped
messagePhoto photo:photo caption:formattedText show_caption_above_media:Bool has_spoiler:Bool is_secret:Bool = MessageContent;

//@description A sticker message @sticker The sticker description @is_premium True, if premium animation of the sticker must be played
messageSticker sticker:sticker is_premium:Bool = MessageContent;

//@description A video message
//@video The video description
//@alternative_videos Alternative qualities of the video
//@cover Cover of the video; may be null if none
//@start_timestamp Timestamp from which the video playing must start, in seconds
//@caption Video caption
//@show_caption_above_media True, if the caption must be shown above the video; otherwise, the caption must be shown below the video
//@has_spoiler True, if the video preview must be covered by a spoiler animation
//@is_secret True, if the video thumbnail must be blurred and the video must be shown only while tapped
messageVideo video:video alternative_videos:vector<alternativeVideo> cover:photo start_timestamp:int32 caption:formattedText show_caption_above_media:Bool has_spoiler:Bool is_secret:Bool = MessageContent;

//@description A video note message @video_note The video note description @is_viewed True, if at least one of the recipients has viewed the video note @is_secret True, if the video note thumbnail must be blurred and the video note must be shown only while tapped
messageVideoNote video_note:videoNote is_viewed:Bool is_secret:Bool = MessageContent;

//@description A voice note message @voice_note The voice note description @caption Voice note caption @is_listened True, if at least one of the recipients has listened to the voice note
messageVoiceNote voice_note:voiceNote caption:formattedText is_listened:Bool = MessageContent;

//@description A self-destructed photo message
messageExpiredPhoto = MessageContent;

//@description A self-destructed video message
messageExpiredVideo = MessageContent;

//@description A self-destructed video note message
messageExpiredVideoNote = MessageContent;

//@description A self-destructed voice note message
messageExpiredVoiceNote = MessageContent;

//@description A message with a location
//@location The location description
//@live_period Time relative to the message send date, for which the location can be updated, in seconds; if 0x7FFFFFFF, then location can be updated forever
//@expires_in Left time for which the location can be updated, in seconds. If 0, then the location can't be updated anymore. The update updateMessageContent is not sent when this field changes
//@heading For live locations, a direction in which the location moves, in degrees; 1-360. If 0 the direction is unknown
//@proximity_alert_radius For live locations, a maximum distance to another chat member for proximity alerts, in meters (0-100000). 0 if the notification is disabled. Available only to the message sender
messageLocation location:location live_period:int32 expires_in:int32 heading:int32 proximity_alert_radius:int32 = MessageContent;

//@description A message with information about a venue @venue The venue description
messageVenue venue:venue = MessageContent;

//@description A message with a user contact @contact The contact description
messageContact contact:contact = MessageContent;

//@description A message with an animated emoji @animated_emoji The animated emoji @emoji The corresponding emoji
messageAnimatedEmoji animated_emoji:animatedEmoji emoji:string = MessageContent;

//@description A dice message. The dice value is randomly generated by the server
//@initial_state The animated stickers with the initial dice animation; may be null if unknown. The update updateMessageContent will be sent when the sticker became known
//@final_state The animated stickers with the final dice animation; may be null if unknown. The update updateMessageContent will be sent when the sticker became known
//@emoji Emoji on which the dice throw animation is based
//@value The dice value. If the value is 0, the dice don't have final state yet
//@success_animation_frame_number Number of frame after which a success animation like a shower of confetti needs to be shown on updateMessageSendSucceeded
messageDice initial_state:DiceStickers final_state:DiceStickers emoji:string value:int32 success_animation_frame_number:int32 = MessageContent;

//@description A message with a game @game The game description
messageGame game:game = MessageContent;

//@description A message with a poll @poll The poll description
messagePoll poll:poll = MessageContent;

//@description A message with a forwarded story
//@story_sender_chat_id Identifier of the chat that posted the story
//@story_id Story identifier
//@via_mention True, if the story was automatically forwarded because of a mention of the user
messageStory story_sender_chat_id:int53 story_id:int32 via_mention:Bool = MessageContent;

//@description A message with an invoice from a bot. Use getInternalLink with internalLinkTypeBotStart to share the invoice
//@product_info Information about the product
//@currency Currency for the product price
//@total_amount Product total price in the smallest units of the currency
//@start_parameter Unique invoice bot start_parameter to be passed to getInternalLink
//@is_test True, if the invoice is a test invoice
//@need_shipping_address True, if the shipping address must be specified
//@receipt_message_id The identifier of the message with the receipt, after the product has been purchased
//@paid_media Extended media attached to the invoice; may be null if none
//@paid_media_caption Extended media caption; may be null if none
messageInvoice product_info:productInfo currency:string total_amount:int53 start_parameter:string is_test:Bool need_shipping_address:Bool receipt_message_id:int53 paid_media:PaidMedia paid_media_caption:formattedText = MessageContent;

//@description A message with information about an ended call @is_video True, if the call was a video call @discard_reason Reason why the call was discarded @duration Call duration, in seconds
messageCall is_video:Bool discard_reason:CallDiscardReason duration:int32 = MessageContent;

//@description A new video chat was scheduled @group_call_id Identifier of the video chat. The video chat can be received through the method getGroupCall @start_date Point in time (Unix timestamp) when the group call is expected to be started by an administrator
messageVideoChatScheduled group_call_id:int32 start_date:int32 = MessageContent;

//@description A newly created video chat @group_call_id Identifier of the video chat. The video chat can be received through the method getGroupCall
messageVideoChatStarted group_call_id:int32 = MessageContent;

//@description A message with information about an ended video chat @duration Call duration, in seconds
messageVideoChatEnded duration:int32 = MessageContent;

//@description A message with information about an invitation to a video chat @group_call_id Identifier of the video chat. The video chat can be received through the method getGroupCall @user_ids Invited user identifiers
messageInviteVideoChatParticipants group_call_id:int32 user_ids:vector<int53> = MessageContent;

//@description A newly created basic group @title Title of the basic group @member_user_ids User identifiers of members in the basic group
messageBasicGroupChatCreate title:string member_user_ids:vector<int53> = MessageContent;

//@description A newly created supergroup or channel @title Title of the supergroup or channel
messageSupergroupChatCreate title:string = MessageContent;

//@description An updated chat title @title New chat title
messageChatChangeTitle title:string = MessageContent;

//@description An updated chat photo @photo New chat photo
messageChatChangePhoto photo:chatPhoto = MessageContent;

//@description A deleted chat photo
messageChatDeletePhoto = MessageContent;

//@description New chat members were added @member_user_ids User identifiers of the new members
messageChatAddMembers member_user_ids:vector<int53> = MessageContent;

//@description A new member joined the chat via an invite link
messageChatJoinByLink = MessageContent;

//@description A new member was accepted to the chat by an administrator
messageChatJoinByRequest = MessageContent;

//@description A chat member was deleted @user_id User identifier of the deleted chat member
messageChatDeleteMember user_id:int53 = MessageContent;

//@description A basic group was upgraded to a supergroup and was deactivated as the result @supergroup_id Identifier of the supergroup to which the basic group was upgraded
messageChatUpgradeTo supergroup_id:int53 = MessageContent;

//@description A supergroup has been created from a basic group @title Title of the newly created supergroup @basic_group_id The identifier of the original basic group
messageChatUpgradeFrom title:string basic_group_id:int53 = MessageContent;

//@description A message has been pinned @message_id Identifier of the pinned message, can be an identifier of a deleted message or 0
messagePinMessage message_id:int53 = MessageContent;

//@description A screenshot of a message in the chat has been taken
messageScreenshotTaken = MessageContent;

//@description A new background was set in the chat
//@old_background_message_id Identifier of the message with a previously set same background; 0 if none. Can be an identifier of a deleted message
//@background The new background
//@only_for_self True, if the background was set only for self
messageChatSetBackground old_background_message_id:int53 background:chatBackground only_for_self:Bool = MessageContent;

//@description A theme in the chat has been changed @theme_name If non-empty, name of a new theme, set for the chat. Otherwise, chat theme was reset to the default one
messageChatSetTheme theme_name:string = MessageContent;

//@description The auto-delete or self-destruct timer for messages in the chat has been changed @message_auto_delete_time New value auto-delete or self-destruct time, in seconds; 0 if disabled @from_user_id If not 0, a user identifier, which default setting was automatically applied
messageChatSetMessageAutoDeleteTime message_auto_delete_time:int32 from_user_id:int53 = MessageContent;

//@description The chat was boosted by the sender of the message @boost_count Number of times the chat was boosted
messageChatBoost boost_count:int32 = MessageContent;

//@description A forum topic has been created @name Name of the topic @icon Icon of the topic
messageForumTopicCreated name:string icon:forumTopicIcon = MessageContent;

//@description A forum topic has been edited
//@name If non-empty, the new name of the topic
//@edit_icon_custom_emoji_id True, if icon's custom_emoji_id is changed
//@icon_custom_emoji_id New unique identifier of the custom emoji shown on the topic icon; 0 if none. Must be ignored if edit_icon_custom_emoji_id is false
messageForumTopicEdited name:string edit_icon_custom_emoji_id:Bool icon_custom_emoji_id:int64 = MessageContent;

//@description A forum topic has been closed or opened @is_closed True, if the topic was closed; otherwise, the topic was reopened
messageForumTopicIsClosedToggled is_closed:Bool = MessageContent;

//@description A General forum topic has been hidden or unhidden @is_hidden True, if the topic was hidden; otherwise, the topic was unhidden
messageForumTopicIsHiddenToggled is_hidden:Bool = MessageContent;

//@description A profile photo was suggested to a user in a private chat @photo The suggested chat photo. Use the method setProfilePhoto with inputChatPhotoPrevious to apply the photo
messageSuggestProfilePhoto photo:chatPhoto = MessageContent;

//@description A non-standard action has happened in the chat @text Message text to be shown in the chat
messageCustomServiceAction text:string = MessageContent;

//@description A new high score was achieved in a game @game_message_id Identifier of the message with the game, can be an identifier of a deleted message @game_id Identifier of the game; may be different from the games presented in the message with the game @score New score
messageGameScore game_message_id:int53 game_id:int64 score:int32 = MessageContent;

//@description A payment has been sent to a bot or a business account
//@invoice_chat_id Identifier of the chat, containing the corresponding invoice message
//@invoice_message_id Identifier of the message with the corresponding invoice; can be 0 or an identifier of a deleted message
//@currency Currency for the price of the product
//@total_amount Total price for the product, in the smallest units of the currency
//@subscription_until_date Point in time (Unix timestamp) when the subscription will expire; 0 if unknown or the payment isn't recurring
//@is_recurring True, if this is a recurring payment
//@is_first_recurring True, if this is the first recurring payment
//@invoice_name Name of the invoice; may be empty if unknown
messagePaymentSuccessful invoice_chat_id:int53 invoice_message_id:int53 currency:string total_amount:int53 subscription_until_date:int32 is_recurring:Bool is_first_recurring:Bool invoice_name:string = MessageContent;

//@description A payment has been received by the bot or the business account
//@currency Currency for price of the product
//@total_amount Total price for the product, in the smallest units of the currency
//@subscription_until_date Point in time (Unix timestamp) when the subscription will expire; 0 if unknown or the payment isn't recurring
//@is_recurring True, if this is a recurring payment
//@is_first_recurring True, if this is the first recurring payment
//@invoice_payload Invoice payload
//@shipping_option_id Identifier of the shipping option chosen by the user; may be empty if not applicable; for bots only
//@order_info Information about the order; may be null; for bots only
//@telegram_payment_charge_id Telegram payment identifier
//@provider_payment_charge_id Provider payment identifier
messagePaymentSuccessfulBot currency:string total_amount:int53 subscription_until_date:int32 is_recurring:Bool is_first_recurring:Bool invoice_payload:bytes shipping_option_id:string order_info:orderInfo telegram_payment_charge_id:string provider_payment_charge_id:string = MessageContent;

//@description A payment has been refunded
//@owner_id Identifier of the previous owner of the Telegram Stars that refunds them
//@currency Currency for the price of the product
//@total_amount Total price for the product, in the smallest units of the currency
//@invoice_payload Invoice payload; only for bots
//@telegram_payment_charge_id Telegram payment identifier
//@provider_payment_charge_id Provider payment identifier
messagePaymentRefunded owner_id:MessageSender currency:string total_amount:int53 invoice_payload:bytes telegram_payment_charge_id:string provider_payment_charge_id:string = MessageContent;

//@description Telegram Premium was gifted to a user
//@gifter_user_id The identifier of a user that gifted Telegram Premium; 0 if the gift was anonymous or is outgoing
//@receiver_user_id The identifier of a user that received Telegram Premium; 0 if the gift is incoming
//@text Message added to the gifted Telegram Premium by the sender
//@currency Currency for the paid amount
//@amount The paid amount, in the smallest units of the currency
//@cryptocurrency Cryptocurrency used to pay for the gift; may be empty if none
//@cryptocurrency_amount The paid amount, in the smallest units of the cryptocurrency; 0 if none
//@month_count Number of months the Telegram Premium subscription will be active
//@sticker A sticker to be shown in the message; may be null if unknown
messageGiftedPremium gifter_user_id:int53 receiver_user_id:int53 text:formattedText currency:string amount:int53 cryptocurrency:string cryptocurrency_amount:int64 month_count:int32 sticker:sticker = MessageContent;

//@description A Telegram Premium gift code was created for the user
//@creator_id Identifier of a chat or a user that created the gift code; may be null if unknown
//@text Message added to the gift
//@is_from_giveaway True, if the gift code was created for a giveaway
//@is_unclaimed True, if the winner for the corresponding Telegram Premium subscription wasn't chosen
//@currency Currency for the paid amount; empty if unknown
//@amount The paid amount, in the smallest units of the currency; 0 if unknown
//@cryptocurrency Cryptocurrency used to pay for the gift; may be empty if none or unknown
//@cryptocurrency_amount The paid amount, in the smallest units of the cryptocurrency; 0 if unknown
//@month_count Number of months the Telegram Premium subscription will be active after code activation
//@sticker A sticker to be shown in the message; may be null if unknown
//@code The gift code
messagePremiumGiftCode creator_id:MessageSender text:formattedText is_from_giveaway:Bool is_unclaimed:Bool currency:string amount:int53 cryptocurrency:string cryptocurrency_amount:int64 month_count:int32 sticker:sticker code:string = MessageContent;

//@description A giveaway was created for the chat. Use telegramPaymentPurposePremiumGiveaway, storePaymentPurposePremiumGiveaway, telegramPaymentPurposeStarGiveaway, or storePaymentPurposeStarGiveaway to create a giveaway
//@star_count Number of Telegram Stars that will be shared by winners of the giveaway; 0 for Telegram Premium giveaways
messageGiveawayCreated star_count:int53 = MessageContent;

//@description A giveaway
//@parameters Giveaway parameters
//@winner_count Number of users which will receive Telegram Premium subscription gift codes
//@prize Prize of the giveaway
//@sticker A sticker to be shown in the message; may be null if unknown
messageGiveaway parameters:giveawayParameters winner_count:int32 prize:GiveawayPrize sticker:sticker = MessageContent;

//@description A giveaway without public winners has been completed for the chat
//@giveaway_message_id Identifier of the message with the giveaway; can be 0 if the message was deleted
//@winner_count Number of winners in the giveaway
//@is_star_giveaway True, if the giveaway is a Telegram Star giveaway
//@unclaimed_prize_count Number of undistributed prizes; for Telegram Premium giveaways only
messageGiveawayCompleted giveaway_message_id:int53 winner_count:int32 is_star_giveaway:Bool unclaimed_prize_count:int32 = MessageContent;

//@description A giveaway with public winners has been completed for the chat
//@boosted_chat_id Identifier of the supergroup or channel chat, which was automatically boosted by the winners of the giveaway
//@giveaway_message_id Identifier of the message with the giveaway in the boosted chat
//@additional_chat_count Number of other chats that participated in the giveaway
//@actual_winners_selection_date Point in time (Unix timestamp) when the winners were selected. May be bigger than winners selection date specified in parameters of the giveaway
//@only_new_members True, if only new members of the chats were eligible for the giveaway
//@was_refunded True, if the giveaway was canceled and was fully refunded
//@prize Prize of the giveaway
//@prize_description Additional description of the giveaway prize
//@winner_count Total number of winners in the giveaway
//@winner_user_ids Up to 100 user identifiers of the winners of the giveaway
//@unclaimed_prize_count Number of undistributed prizes; for Telegram Premium giveaways only
messageGiveawayWinners boosted_chat_id:int53 giveaway_message_id:int53 additional_chat_count:int32 actual_winners_selection_date:int32 only_new_members:Bool was_refunded:Bool prize:GiveawayPrize prize_description:string winner_count:int32 winner_user_ids:vector<int53> unclaimed_prize_count:int32 = MessageContent;

//@description Telegram Stars were gifted to a user
//@gifter_user_id The identifier of a user that gifted Telegram Stars; 0 if the gift was anonymous or is outgoing
//@receiver_user_id The identifier of a user that received Telegram Stars; 0 if the gift is incoming
//@currency Currency for the paid amount
//@amount The paid amount, in the smallest units of the currency
//@cryptocurrency Cryptocurrency used to pay for the gift; may be empty if none
//@cryptocurrency_amount The paid amount, in the smallest units of the cryptocurrency; 0 if none
//@star_count Number of Telegram Stars that were gifted
//@transaction_id Identifier of the transaction for Telegram Stars purchase; for receiver only
//@sticker A sticker to be shown in the message; may be null if unknown
messageGiftedStars gifter_user_id:int53 receiver_user_id:int53 currency:string amount:int53 cryptocurrency:string cryptocurrency_amount:int64 star_count:int53 transaction_id:string sticker:sticker = MessageContent;

//@description A Telegram Stars were received by the current user from a giveaway
//@star_count Number of Telegram Stars that were received
//@transaction_id Identifier of the transaction for Telegram Stars credit
//@boosted_chat_id Identifier of the supergroup or channel chat, which was automatically boosted by the winners of the giveaway
//@giveaway_message_id Identifier of the message with the giveaway in the boosted chat; can be 0 if the message was deleted
//@is_unclaimed True, if the corresponding winner wasn't chosen and the Telegram Stars were received by the owner of the boosted chat
//@sticker A sticker to be shown in the message; may be null if unknown
messageGiveawayPrizeStars star_count:int53 transaction_id:string boosted_chat_id:int53 giveaway_message_id:int53 is_unclaimed:Bool sticker:sticker = MessageContent;

//@description A regular gift was received or sent by the current user, or the current user was notified about a channel gift
//@gift The gift
//@sender_id Sender of the gift
//@received_gift_id Unique identifier of the received gift for the current user; only for the receiver of the gift
//@text Message added to the gift
//@sell_star_count Number of Telegram Stars that can be claimed by the receiver instead of the regular gift; 0 if the gift can't be sold by the receiver
//@prepaid_upgrade_star_count Number of Telegram Stars that were paid by the sender for the ability to upgrade the gift
//@is_private True, if the sender and gift text are shown only to the gift receiver; otherwise, everyone will be able to see them
//@is_saved True, if the gift is displayed on the user's or the channel's profile page; only for the receiver of the gift
//@can_be_upgraded True, if the gift can be upgraded to a unique gift; only for the receiver of the gift
//@was_converted True, if the gift was converted to Telegram Stars; only for the receiver of the gift
//@was_upgraded True, if the gift was upgraded to a unique gift
//@was_refunded True, if the gift was refunded and isn't available anymore
//@upgraded_received_gift_id Identifier of the corresponding upgraded gift; may be empty if unknown. Use getReceivedGift to get information about the gift
messageGift gift:gift sender_id:MessageSender received_gift_id:string text:formattedText sell_star_count:int53 prepaid_upgrade_star_count:int53 is_private:Bool is_saved:Bool can_be_upgraded:Bool was_converted:Bool was_upgraded:Bool was_refunded:Bool upgraded_received_gift_id:string = MessageContent;

//@description An upgraded gift was received or sent by the current user, or the current user was notified about a channel gift
//@gift The gift
//@sender_id Sender of the gift; may be null for anonymous gifts
//@received_gift_id Unique identifier of the received gift for the current user; only for the receiver of the gift
//@is_upgrade True, if the gift was obtained by upgrading of a previously received gift; otherwise, this is a transferred gift
//@is_saved True, if the gift is displayed on the user's or the channel's profile page; only for the receiver of the gift
//@can_be_transferred True, if the gift can be transferred to another owner; only for the receiver of the gift
//@was_transferred True, if the gift was transferred to another owner; only for the receiver of the gift
//@transfer_star_count Number of Telegram Stars that must be paid to transfer the upgraded gift; only for the receiver of the gift
//@export_date Point in time (Unix timestamp) when the gift can be transferred to the TON blockchain as an NFT; 0 if NFT export isn't possible; only for the receiver of the gift
messageUpgradedGift gift:upgradedGift sender_id:MessageSender received_gift_id:string is_upgrade:Bool is_saved:Bool can_be_transferred:Bool was_transferred:Bool transfer_star_count:int53 export_date:int32 = MessageContent;

//@description A gift which purchase, upgrade or transfer were refunded
//@gift The gift
//@sender_id Sender of the gift
//@is_upgrade True, if the gift was obtained by upgrading of a previously received gift
messageRefundedUpgradedGift gift:gift sender_id:MessageSender is_upgrade:Bool = MessageContent;

//@description A contact has registered with Telegram
messageContactRegistered = MessageContent;

//@description The current user shared users, which were requested by the bot @users The shared users @button_id Identifier of the keyboard button with the request
messageUsersShared users:vector<sharedUser> button_id:int32 = MessageContent;

//@description The current user shared a chat, which was requested by the bot @chat The shared chat @button_id Identifier of the keyboard button with the request
messageChatShared chat:sharedChat button_id:int32 = MessageContent;

//@description The user allowed the bot to send messages @reason The reason why the bot was allowed to write messages
messageBotWriteAccessAllowed reason:BotWriteAccessAllowReason = MessageContent;

//@description Data from a Web App has been sent to a bot @button_text Text of the keyboardButtonTypeWebApp button, which opened the Web App
messageWebAppDataSent button_text:string = MessageContent;

//@description Data from a Web App has been received; for bots only @button_text Text of the keyboardButtonTypeWebApp button, which opened the Web App @data The data
messageWebAppDataReceived button_text:string data:string = MessageContent;

//@description Telegram Passport data has been sent to a bot @types List of Telegram Passport element types sent
messagePassportDataSent types:vector<PassportElementType> = MessageContent;

//@description Telegram Passport data has been received; for bots only @elements List of received Telegram Passport elements @credentials Encrypted data credentials
messagePassportDataReceived elements:vector<encryptedPassportElement> credentials:encryptedCredentials = MessageContent;

//@description A user in the chat came within proximity alert range @traveler_id The identifier of a user or chat that triggered the proximity alert @watcher_id The identifier of a user or chat that subscribed for the proximity alert @distance The distance between the users
messageProximityAlertTriggered traveler_id:MessageSender watcher_id:MessageSender distance:int32 = MessageContent;

//@description A message content that is not supported in the current TDLib version
messageUnsupported = MessageContent;


//@class TextEntityType @description Represents a part of the text which must be formatted differently

//@description A mention of a user, a supergroup, or a channel by their username
textEntityTypeMention = TextEntityType;

//@description A hashtag text, beginning with "#" and optionally containing a chat username at the end
textEntityTypeHashtag = TextEntityType;

//@description A cashtag text, beginning with "$", consisting of capital English letters (e.g., "$USD"), and optionally containing a chat username at the end
textEntityTypeCashtag = TextEntityType;

//@description A bot command, beginning with "/"
textEntityTypeBotCommand = TextEntityType;

//@description An HTTP URL
textEntityTypeUrl = TextEntityType;

//@description An email address
textEntityTypeEmailAddress = TextEntityType;

//@description A phone number
textEntityTypePhoneNumber = TextEntityType;

//@description A bank card number. The getBankCardInfo method can be used to get information about the bank card
textEntityTypeBankCardNumber = TextEntityType;

//@description A bold text
textEntityTypeBold = TextEntityType;

//@description An italic text
textEntityTypeItalic = TextEntityType;

//@description An underlined text
textEntityTypeUnderline = TextEntityType;

//@description A strikethrough text
textEntityTypeStrikethrough = TextEntityType;

//@description A spoiler text
textEntityTypeSpoiler = TextEntityType;

//@description Text that must be formatted as if inside a code HTML tag
textEntityTypeCode = TextEntityType;

//@description Text that must be formatted as if inside a pre HTML tag
textEntityTypePre = TextEntityType;

//@description Text that must be formatted as if inside pre, and code HTML tags @language Programming language of the code; as defined by the sender
textEntityTypePreCode language:string = TextEntityType;

//@description Text that must be formatted as if inside a blockquote HTML tag; not supported in secret chats
textEntityTypeBlockQuote = TextEntityType;

//@description Text that must be formatted as if inside a blockquote HTML tag and collapsed by default to 3 lines with the ability to show full text; not supported in secret chats
textEntityTypeExpandableBlockQuote = TextEntityType;

//@description A text description shown instead of a raw URL @url HTTP or tg:// URL to be opened when the link is clicked
textEntityTypeTextUrl url:string = TextEntityType;

//@description A text shows instead of a raw mention of the user (e.g., when the user has no username) @user_id Identifier of the mentioned user
textEntityTypeMentionName user_id:int53 = TextEntityType;

//@description A custom emoji. The text behind a custom emoji must be an emoji. Only premium users can use premium custom emoji @custom_emoji_id Unique identifier of the custom emoji
textEntityTypeCustomEmoji custom_emoji_id:int64 = TextEntityType;

//@description A media timestamp @media_timestamp Timestamp from which a video/audio/video note/voice note/story playing must start, in seconds. The media can be in the content or the link preview of the current message, or in the same places in the replied message
textEntityTypeMediaTimestamp media_timestamp:int32 = TextEntityType;


//@description A thumbnail to be sent along with a file; must be in JPEG or WEBP format for stickers, and less than 200 KB in size
//@thumbnail Thumbnail file to send. Sending thumbnails by file_id is currently not supported
//@width Thumbnail width, usually shouldn't exceed 320. Use 0 if unknown
//@height Thumbnail height, usually shouldn't exceed 320. Use 0 if unknown
inputThumbnail thumbnail:InputFile width:int32 height:int32 = InputThumbnail;


//@class InputPaidMediaType @description Describes type of paid media to sent

//@description The media is a photo. The photo must be at most 10 MB in size. The photo's width and height must not exceed 10000 in total. Width and height ratio must be at most 20
inputPaidMediaTypePhoto = InputPaidMediaType;

//@description The media is a video
//@cover Cover of the video; pass null to skip cover uploading
//@start_timestamp Timestamp from which the video playing must start, in seconds
//@duration Duration of the video, in seconds
//@supports_streaming True, if the video is expected to be streamed
inputPaidMediaTypeVideo cover:InputFile start_timestamp:int32 duration:int32 supports_streaming:Bool = InputPaidMediaType;


//@description Describes a paid media to be sent
//@type Type of the media
//@media Photo or video to be sent
//@thumbnail Media thumbnail; pass null to skip thumbnail uploading
//@added_sticker_file_ids File identifiers of the stickers added to the media, if applicable
//@width Media width
//@height Media height
inputPaidMedia type:InputPaidMediaType media:InputFile thumbnail:inputThumbnail added_sticker_file_ids:vector<int32> width:int32 height:int32 = InputPaidMedia;


//@class MessageSchedulingState @description Contains information about the time when a scheduled message will be sent

//@description The message will be sent at the specified date @send_date Point in time (Unix timestamp) when the message will be sent. The date must be within 367 days in the future
messageSchedulingStateSendAtDate send_date:int32 = MessageSchedulingState;

//@description The message will be sent when the other user is online. Applicable to private chats only and when the exact online status of the other user is known
messageSchedulingStateSendWhenOnline = MessageSchedulingState;

//@description The message will be sent when the video in the message is converted and optimized; can be used only by the server
//@send_date Approximate point in time (Unix timestamp) when the message is expected to be sent
messageSchedulingStateSendWhenVideoProcessed send_date:int32 = MessageSchedulingState;


//@class MessageSelfDestructType @description Describes when a message will be self-destructed

//@description The message will be self-destructed in the specified time after its content was opened @self_destruct_time The message's self-destruct time, in seconds; must be between 0 and 60 in private chats
messageSelfDestructTypeTimer self_destruct_time:int32 = MessageSelfDestructType;

//@description The message can be opened only once and will be self-destructed once closed
messageSelfDestructTypeImmediately = MessageSelfDestructType;


//@description Options to be used when a message is sent
//@disable_notification Pass true to disable notification for the message
//@from_background Pass true if the message is sent from the background
//@protect_content Pass true if the content of the message must be protected from forwarding and saving; for bots only
//@allow_paid_broadcast Pass true to allow the message to ignore regular broadcast limits for a small fee; for bots only
//@paid_message_star_count The number of Telegram Stars the user agreed to pay to send the messages
//@update_order_of_installed_sticker_sets Pass true if the user explicitly chosen a sticker or a custom emoji from an installed sticker set; applicable only to sendMessage and sendMessageAlbum
//@scheduling_state Message scheduling state; pass null to send message immediately. Messages sent to a secret chat, to a chat with paid messages, live location messages and self-destructing messages can't be scheduled
//@effect_id Identifier of the effect to apply to the message; pass 0 if none; applicable only to sendMessage and sendMessageAlbum in private chats
//@sending_id Non-persistent identifier, which will be returned back in messageSendingStatePending object and can be used to match sent messages and corresponding updateNewMessage updates
//@only_preview Pass true to get a fake message instead of actually sending them
messageSendOptions disable_notification:Bool from_background:Bool protect_content:Bool allow_paid_broadcast:Bool paid_message_star_count:int53 update_order_of_installed_sticker_sets:Bool scheduling_state:MessageSchedulingState effect_id:int64 sending_id:int32 only_preview:Bool = MessageSendOptions;

//@description Options to be used when a message content is copied without reference to the original sender. Service messages, messages with messageInvoice, messagePaidMedia, messageGiveaway, or messageGiveawayWinners content can't be copied
//@send_copy True, if content of the message needs to be copied without reference to the original sender. Always true if the message is forwarded to a secret chat or is local.
//-Use messageProperties.can_be_saved and messageProperties.can_be_copied_to_secret_chat to check whether the message is suitable
//@replace_caption True, if media caption of the message copy needs to be replaced. Ignored if send_copy is false
//@new_caption New message caption; pass null to copy message without caption. Ignored if replace_caption is false
//@new_show_caption_above_media True, if new caption must be shown above the media; otherwise, new caption must be shown below the media; not supported in secret chats. Ignored if replace_caption is false
messageCopyOptions send_copy:Bool replace_caption:Bool new_caption:formattedText new_show_caption_above_media:Bool = MessageCopyOptions;


//@class InputMessageContent @description The content of a message to send

//@description A text message
//@text Formatted text to be sent; 0-getOption("message_text_length_max") characters. Only Bold, Italic, Underline, Strikethrough, Spoiler, CustomEmoji, BlockQuote, ExpandableBlockQuote,
//-Code, Pre, PreCode, TextUrl and MentionName entities are allowed to be specified manually
//@link_preview_options Options to be used for generation of a link preview; may be null if none; pass null to use default link preview options
//@clear_draft True, if a chat message draft must be deleted
inputMessageText text:formattedText link_preview_options:linkPreviewOptions clear_draft:Bool = InputMessageContent;

//@description An animation message (GIF-style).
//@animation Animation file to be sent
//@thumbnail Animation thumbnail; pass null to skip thumbnail uploading
//@added_sticker_file_ids File identifiers of the stickers added to the animation, if applicable
//@duration Duration of the animation, in seconds
//@width Width of the animation; may be replaced by the server
//@height Height of the animation; may be replaced by the server
//@caption Animation caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
//@show_caption_above_media True, if the caption must be shown above the animation; otherwise, the caption must be shown below the animation; not supported in secret chats
//@has_spoiler True, if the animation preview must be covered by a spoiler animation; not supported in secret chats
inputMessageAnimation animation:InputFile thumbnail:inputThumbnail added_sticker_file_ids:vector<int32> duration:int32 width:int32 height:int32 caption:formattedText show_caption_above_media:Bool has_spoiler:Bool = InputMessageContent;

//@description An audio message
//@audio Audio file to be sent
//@album_cover_thumbnail Thumbnail of the cover for the album; pass null to skip thumbnail uploading
//@duration Duration of the audio, in seconds; may be replaced by the server
//@title Title of the audio; 0-64 characters; may be replaced by the server
//@performer Performer of the audio; 0-64 characters, may be replaced by the server
//@caption Audio caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
inputMessageAudio audio:InputFile album_cover_thumbnail:inputThumbnail duration:int32 title:string performer:string caption:formattedText = InputMessageContent;

//@description A document message (general file)
//@document Document to be sent
//@thumbnail Document thumbnail; pass null to skip thumbnail uploading
//@disable_content_type_detection Pass true to disable automatic file type detection and send the document as a file. Always true for files sent to secret chats
//@caption Document caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
inputMessageDocument document:InputFile thumbnail:inputThumbnail disable_content_type_detection:Bool caption:formattedText = InputMessageContent;

//@description A message with paid media; can be used only in channel chats with supergroupFullInfo.has_paid_media_allowed
//@star_count The number of Telegram Stars that must be paid to see the media; 1-getOption("paid_media_message_star_count_max")
//@paid_media The content of the paid media
//@caption Message caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
//@show_caption_above_media True, if the caption must be shown above the media; otherwise, the caption must be shown below the media; not supported in secret chats
//@payload Bot-provided data for the paid media; bots only
inputMessagePaidMedia star_count:int53 paid_media:vector<inputPaidMedia> caption:formattedText show_caption_above_media:Bool payload:string = InputMessageContent;

//@description A photo message
//@photo Photo to send. The photo must be at most 10 MB in size. The photo's width and height must not exceed 10000 in total. Width and height ratio must be at most 20
//@thumbnail Photo thumbnail to be sent; pass null to skip thumbnail uploading. The thumbnail is sent to the other party only in secret chats
//@added_sticker_file_ids File identifiers of the stickers added to the photo, if applicable
//@width Photo width
//@height Photo height
//@caption Photo caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
//@show_caption_above_media True, if the caption must be shown above the photo; otherwise, the caption must be shown below the photo; not supported in secret chats
//@self_destruct_type Photo self-destruct type; pass null if none; private chats only
//@has_spoiler True, if the photo preview must be covered by a spoiler animation; not supported in secret chats
inputMessagePhoto photo:InputFile thumbnail:inputThumbnail added_sticker_file_ids:vector<int32> width:int32 height:int32 caption:formattedText show_caption_above_media:Bool self_destruct_type:MessageSelfDestructType has_spoiler:Bool = InputMessageContent;

//@description A sticker message
//@sticker Sticker to be sent
//@thumbnail Sticker thumbnail; pass null to skip thumbnail uploading
//@width Sticker width
//@height Sticker height
//@emoji Emoji used to choose the sticker
inputMessageSticker sticker:InputFile thumbnail:inputThumbnail width:int32 height:int32 emoji:string = InputMessageContent;

//@description A video message
//@video Video to be sent. The video is expected to be re-encoded to MPEG4 format with H.264 codec by the sender
//@thumbnail Video thumbnail; pass null to skip thumbnail uploading
//@cover Cover of the video; pass null to skip cover uploading; not supported in secret chats and for self-destructing messages
//@start_timestamp Timestamp from which the video playing must start, in seconds
//@added_sticker_file_ids File identifiers of the stickers added to the video, if applicable
//@duration Duration of the video, in seconds
//@width Video width
//@height Video height
//@supports_streaming True, if the video is expected to be streamed
//@caption Video caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
//@show_caption_above_media True, if the caption must be shown above the video; otherwise, the caption must be shown below the video; not supported in secret chats
//@self_destruct_type Video self-destruct type; pass null if none; private chats only
//@has_spoiler True, if the video preview must be covered by a spoiler animation; not supported in secret chats
inputMessageVideo video:InputFile thumbnail:inputThumbnail cover:InputFile start_timestamp:int32 added_sticker_file_ids:vector<int32> duration:int32 width:int32 height:int32 supports_streaming:Bool caption:formattedText show_caption_above_media:Bool self_destruct_type:MessageSelfDestructType has_spoiler:Bool = InputMessageContent;

//@description A video note message
//@video_note Video note to be sent. The video is expected to be encoded to MPEG4 format with H.264 codec and have no data outside of the visible circle
//@thumbnail Video thumbnail; may be null if empty; pass null to skip thumbnail uploading
//@duration Duration of the video, in seconds; 0-60
//@length Video width and height; must be positive and not greater than 640
//@self_destruct_type Video note self-destruct type; may be null if none; pass null if none; private chats only
inputMessageVideoNote video_note:InputFile thumbnail:inputThumbnail duration:int32 length:int32 self_destruct_type:MessageSelfDestructType = InputMessageContent;

//@description A voice note message
//@voice_note Voice note to be sent. The voice note must be encoded with the Opus codec and stored inside an OGG container with a single audio channel, or be in MP3 or M4A format as regular audio
//@duration Duration of the voice note, in seconds
//@waveform Waveform representation of the voice note in 5-bit format
//@caption Voice note caption; may be null if empty; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
//@self_destruct_type Voice note self-destruct type; may be null if none; pass null if none; private chats only
inputMessageVoiceNote voice_note:InputFile duration:int32 waveform:bytes caption:formattedText self_destruct_type:MessageSelfDestructType = InputMessageContent;

//@description A message with a location
//@location Location to be sent
//@live_period Period for which the location can be updated, in seconds; must be between 60 and 86400 for a temporary live location, 0x7FFFFFFF for permanent live location, and 0 otherwise
//@heading For live locations, a direction in which the location moves, in degrees; 1-360. Pass 0 if unknown
//@proximity_alert_radius For live locations, a maximum distance to another chat member for proximity alerts, in meters (0-100000). Pass 0 if the notification is disabled. Can't be enabled in channels and Saved Messages
inputMessageLocation location:location live_period:int32 heading:int32 proximity_alert_radius:int32 = InputMessageContent;

//@description A message with information about a venue @venue Venue to send
inputMessageVenue venue:venue = InputMessageContent;

//@description A message containing a user contact @contact Contact to send
inputMessageContact contact:contact = InputMessageContent;

//@description A dice message @emoji Emoji on which the dice throw animation is based @clear_draft True, if the chat message draft must be deleted
inputMessageDice emoji:string clear_draft:Bool = InputMessageContent;

//@description A message with a game; not supported for channels or secret chats @bot_user_id User identifier of the bot that owns the game @game_short_name Short name of the game
inputMessageGame bot_user_id:int53 game_short_name:string = InputMessageContent;

//@description A message with an invoice; can be used only by bots
//@invoice Invoice
//@title Product title; 1-32 characters
//@param_description Product description; 0-255 characters
//@photo_url Product photo URL; optional
//@photo_size Product photo size
//@photo_width Product photo width
//@photo_height Product photo height
//@payload The invoice payload
//@provider_token Payment provider token; may be empty for payments in Telegram Stars
//@provider_data JSON-encoded data about the invoice, which will be shared with the payment provider
//@start_parameter Unique invoice bot deep link parameter for the generation of this invoice. If empty, it would be possible to pay directly from forwards of the invoice message
//@paid_media The content of paid media attached to the invoice; pass null if none
//@paid_media_caption Paid media caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
inputMessageInvoice invoice:invoice title:string description:string photo_url:string photo_size:int32 photo_width:int32 photo_height:int32 payload:bytes provider_token:string provider_data:string start_parameter:string paid_media:inputPaidMedia paid_media_caption:formattedText = InputMessageContent;

//@description A message with a poll. Polls can't be sent to secret chats. Polls can be sent only to a private chat with a bot
//@question Poll question; 1-255 characters (up to 300 characters for bots). Only custom emoji entities are allowed to be added and only by Premium users
//@options List of poll answer options, 2-10 strings 1-100 characters each. Only custom emoji entities are allowed to be added and only by Premium users
//@is_anonymous True, if the poll voters are anonymous. Non-anonymous polls can't be sent or forwarded to channels
//@type Type of the poll
//@open_period Amount of time the poll will be active after creation, in seconds; for bots only
//@close_date Point in time (Unix timestamp) when the poll will automatically be closed; for bots only
//@is_closed True, if the poll needs to be sent already closed; for bots only
inputMessagePoll question:formattedText options:vector<formattedText> is_anonymous:Bool type:PollType open_period:int32 close_date:int32 is_closed:Bool = InputMessageContent;

//@description A message with a forwarded story. Stories can't be sent to secret chats. A story can be forwarded only if story.can_be_forwarded
//@story_sender_chat_id Identifier of the chat that posted the story
//@story_id Story identifier
inputMessageStory story_sender_chat_id:int53 story_id:int32 = InputMessageContent;

//@description A forwarded message
//@from_chat_id Identifier for the chat this forwarded message came from
//@message_id Identifier of the message to forward. A message can be forwarded only if messageProperties.can_be_forwarded
//@in_game_share Pass true if a game message is being shared from a launched game; applies only to game messages
//@replace_video_start_timestamp Pass true to replace video start timestamp in the forwarded message
//@new_video_start_timestamp The new video start timestamp; ignored if replace_video_start_timestamp == false
//@copy_options Options to be used to copy content of the message without reference to the original sender; pass null to forward the message as usual
inputMessageForwarded from_chat_id:int53 message_id:int53 in_game_share:Bool replace_video_start_timestamp:Bool new_video_start_timestamp:int32 copy_options:messageCopyOptions = InputMessageContent;


//@description Contains properties of a message and describes actions that can be done with the message right now
//@can_be_copied_to_secret_chat True, if content of the message can be copied to a secret chat using inputMessageForwarded or forwardMessages with copy options
//@can_be_deleted_only_for_self True, if the message can be deleted only for the current user while other users will continue to see it using the method deleteMessages with revoke == false
//@can_be_deleted_for_all_users True, if the message can be deleted for all users using the method deleteMessages with revoke == true
//@can_be_edited True, if the message can be edited using the methods editMessageText, editMessageCaption, or editMessageReplyMarkup.
//-For live location and poll messages this fields shows whether editMessageLiveLocation or stopPoll can be used with this message
//@can_be_forwarded True, if the message can be forwarded using inputMessageForwarded or forwardMessages
//@can_be_paid True, if the message can be paid using inputInvoiceMessage
//@can_be_pinned True, if the message can be pinned or unpinned in the chat using pinChatMessage or unpinChatMessage
//@can_be_replied True, if the message can be replied in the same chat and forum topic using inputMessageReplyToMessage
//@can_be_replied_in_another_chat True, if the message can be replied in another chat or forum topic using inputMessageReplyToExternalMessage
//@can_be_saved True, if content of the message can be saved locally or copied using inputMessageForwarded or forwardMessages with copy options
//@can_be_shared_in_story True, if the message can be shared in a story using inputStoryAreaTypeMessage
//@can_edit_media True, if the message can be edited using the method editMessageMedia
//@can_edit_scheduling_state True, if scheduling state of the message can be edited
//@can_get_embedding_code True, if code for message embedding can be received using getMessageEmbeddingCode
//@can_get_link True, if a link can be generated for the message using getMessageLink
//@can_get_media_timestamp_links True, if media timestamp links can be generated for media timestamp entities in the message text, caption or link preview description using getMessageLink
//@can_get_message_thread True, if information about the message thread is available through getMessageThread and getMessageThreadHistory
//@can_get_read_date True, if read date of the message can be received through getMessageReadDate
//@can_get_statistics True, if message statistics are available through getMessageStatistics and message forwards can be received using getMessagePublicForwards
//@can_get_viewers True, if chat members already viewed the message can be received through getMessageViewers
//@can_recognize_speech True, if speech can be recognized for the message through recognizeSpeech
//@can_report_chat True, if the message can be reported using reportChat
//@can_report_reactions True, if reactions on the message can be reported through reportMessageReactions
//@can_report_supergroup_spam True, if the message can be reported using reportSupergroupSpam
//@can_set_fact_check True, if fact check for the message can be changed through setMessageFactCheck
//@need_show_statistics True, if message statistics must be available from context menu of the message
messageProperties can_be_copied_to_secret_chat:Bool can_be_deleted_only_for_self:Bool can_be_deleted_for_all_users:Bool can_be_edited:Bool can_be_forwarded:Bool can_be_paid:Bool can_be_pinned:Bool can_be_replied:Bool can_be_replied_in_another_chat:Bool can_be_saved:Bool can_be_shared_in_story:Bool can_edit_media:Bool can_edit_scheduling_state:Bool can_get_embedding_code:Bool can_get_link:Bool can_get_media_timestamp_links:Bool can_get_message_thread:Bool can_get_read_date:Bool can_get_statistics:Bool can_get_viewers:Bool can_recognize_speech:Bool can_report_chat:Bool can_report_reactions:Bool can_report_supergroup_spam:Bool can_set_fact_check:Bool need_show_statistics:Bool = MessageProperties;


//@class SearchMessagesFilter @description Represents a filter for message search results

//@description Returns all found messages, no filter is applied
searchMessagesFilterEmpty = SearchMessagesFilter;

//@description Returns only animation messages
searchMessagesFilterAnimation = SearchMessagesFilter;

//@description Returns only audio messages
searchMessagesFilterAudio = SearchMessagesFilter;

//@description Returns only document messages
searchMessagesFilterDocument = SearchMessagesFilter;

//@description Returns only photo messages
searchMessagesFilterPhoto = SearchMessagesFilter;

//@description Returns only video messages
searchMessagesFilterVideo = SearchMessagesFilter;

//@description Returns only voice note messages
searchMessagesFilterVoiceNote = SearchMessagesFilter;

//@description Returns only photo and video messages
searchMessagesFilterPhotoAndVideo = SearchMessagesFilter;

//@description Returns only messages containing URLs
searchMessagesFilterUrl = SearchMessagesFilter;

//@description Returns only messages containing chat photos
searchMessagesFilterChatPhoto = SearchMessagesFilter;

//@description Returns only video note messages
searchMessagesFilterVideoNote = SearchMessagesFilter;

//@description Returns only voice and video note messages
searchMessagesFilterVoiceAndVideoNote = SearchMessagesFilter;

//@description Returns only messages with mentions of the current user, or messages that are replies to their messages
searchMessagesFilterMention = SearchMessagesFilter;

//@description Returns only messages with unread mentions of the current user, or messages that are replies to their messages. When using this filter the results can't be additionally filtered by a query, a message thread or by the sending user
searchMessagesFilterUnreadMention = SearchMessagesFilter;

//@description Returns only messages with unread reactions for the current user. When using this filter the results can't be additionally filtered by a query, a message thread or by the sending user
searchMessagesFilterUnreadReaction = SearchMessagesFilter;

//@description Returns only failed to send messages. This filter can be used only if the message database is used
searchMessagesFilterFailedToSend = SearchMessagesFilter;

//@description Returns only pinned messages
searchMessagesFilterPinned = SearchMessagesFilter;


//@class SearchMessagesChatTypeFilter @description Represents a filter for type of the chats in which to search messages

//@description Returns only messages in private chats
searchMessagesChatTypeFilterPrivate = SearchMessagesChatTypeFilter;

//@description Returns only messages in basic group and supergroup chats
searchMessagesChatTypeFilterGroup = SearchMessagesChatTypeFilter;

//@description Returns only messages in channel chats
searchMessagesChatTypeFilterChannel = SearchMessagesChatTypeFilter;


//@class ChatAction @description Describes the different types of activity in a chat

//@description The user is typing a message
chatActionTyping = ChatAction;

//@description The user is recording a video
chatActionRecordingVideo = ChatAction;

//@description The user is uploading a video @progress Upload progress, as a percentage
chatActionUploadingVideo progress:int32 = ChatAction;

//@description The user is recording a voice note
chatActionRecordingVoiceNote = ChatAction;

//@description The user is uploading a voice note @progress Upload progress, as a percentage
chatActionUploadingVoiceNote progress:int32 = ChatAction;

//@description The user is uploading a photo @progress Upload progress, as a percentage
chatActionUploadingPhoto progress:int32 = ChatAction;

//@description The user is uploading a document @progress Upload progress, as a percentage
chatActionUploadingDocument progress:int32 = ChatAction;

//@description The user is picking a sticker to send
chatActionChoosingSticker = ChatAction;

//@description The user is picking a location or venue to send
chatActionChoosingLocation = ChatAction;

//@description The user is picking a contact to send
chatActionChoosingContact = ChatAction;

//@description The user has started to play a game
chatActionStartPlayingGame = ChatAction;

//@description The user is recording a video note
chatActionRecordingVideoNote = ChatAction;

//@description The user is uploading a video note @progress Upload progress, as a percentage
chatActionUploadingVideoNote progress:int32 = ChatAction;

//@description The user is watching animations sent by the other party by clicking on an animated emoji @emoji The animated emoji
chatActionWatchingAnimations emoji:string = ChatAction;

//@description The user has canceled the previous action
chatActionCancel = ChatAction;


//@class UserStatus @description Describes the last time the user was online

//@description The user's status has never been changed
userStatusEmpty = UserStatus;

//@description The user is online @expires Point in time (Unix timestamp) when the user's online status will expire
userStatusOnline expires:int32 = UserStatus;

//@description The user is offline @was_online Point in time (Unix timestamp) when the user was last online
userStatusOffline was_online:int32 = UserStatus;

//@description The user was online recently @by_my_privacy_settings Exact user's status is hidden because the current user enabled userPrivacySettingShowStatus privacy setting for the user and has no Telegram Premium
userStatusRecently by_my_privacy_settings:Bool = UserStatus;

//@description The user is offline, but was online last week @by_my_privacy_settings Exact user's status is hidden because the current user enabled userPrivacySettingShowStatus privacy setting for the user and has no Telegram Premium
userStatusLastWeek by_my_privacy_settings:Bool = UserStatus;

//@description The user is offline, but was online last month @by_my_privacy_settings Exact user's status is hidden because the current user enabled userPrivacySettingShowStatus privacy setting for the user and has no Telegram Premium
userStatusLastMonth by_my_privacy_settings:Bool = UserStatus;


//@description Represents an emoji with its keyword @emoji The emoji @keyword The keyword
emojiKeyword emoji:string keyword:string = EmojiKeyword;

//@description Represents a list of emojis with their keywords @emoji_keywords List of emojis with their keywords
emojiKeywords emoji_keywords:vector<emojiKeyword> = EmojiKeywords;

//@description Represents a list of stickers @stickers List of stickers
stickers stickers:vector<sticker> = Stickers;

//@description Represents a list of emojis @emojis List of emojis
emojis emojis:vector<string> = Emojis;

//@description Represents a sticker set
//@id Identifier of the sticker set
//@title Title of the sticker set
//@name Name of the sticker set
//@thumbnail Sticker set thumbnail in WEBP, TGS, or WEBM format with width and height 100; may be null. The file can be downloaded only before the thumbnail is changed
//@thumbnail_outline Sticker set thumbnail's outline; may be null if unknown
//@is_owned True, if the sticker set is owned by the current user
//@is_installed True, if the sticker set has been installed by the current user
//@is_archived True, if the sticker set has been archived. A sticker set can't be installed and archived simultaneously
//@is_official True, if the sticker set is official
//@sticker_type Type of the stickers in the set
//@needs_repainting True, if stickers in the sticker set are custom emoji that must be repainted; for custom emoji sticker sets only
//@is_allowed_as_chat_emoji_status True, if stickers in the sticker set are custom emoji that can be used as chat emoji status; for custom emoji sticker sets only
//@is_viewed True for already viewed trending sticker sets
//@stickers List of stickers in this set
//@emojis A list of emojis corresponding to the stickers in the same order. The list is only for informational purposes, because a sticker is always sent with a fixed emoji from the corresponding Sticker object
stickerSet id:int64 title:string name:string thumbnail:thumbnail thumbnail_outline:outline is_owned:Bool is_installed:Bool is_archived:Bool is_official:Bool sticker_type:StickerType needs_repainting:Bool is_allowed_as_chat_emoji_status:Bool is_viewed:Bool stickers:vector<sticker> emojis:vector<emojis> = StickerSet;

//@description Represents short information about a sticker set
//@id Identifier of the sticker set
//@title Title of the sticker set
//@name Name of the sticker set
//@thumbnail Sticker set thumbnail in WEBP, TGS, or WEBM format with width and height 100; may be null. The file can be downloaded only before the thumbnail is changed
//@thumbnail_outline Sticker set thumbnail's outline; may be null if unknown
//@is_owned True, if the sticker set is owned by the current user
//@is_installed True, if the sticker set has been installed by the current user
//@is_archived True, if the sticker set has been archived. A sticker set can't be installed and archived simultaneously
//@is_official True, if the sticker set is official
//@sticker_type Type of the stickers in the set
//@needs_repainting True, if stickers in the sticker set are custom emoji that must be repainted; for custom emoji sticker sets only
//@is_allowed_as_chat_emoji_status True, if stickers in the sticker set are custom emoji that can be used as chat emoji status; for custom emoji sticker sets only
//@is_viewed True for already viewed trending sticker sets
//@size Total number of stickers in the set
//@covers Up to the first 5 stickers from the set, depending on the context. If the application needs more stickers the full sticker set needs to be requested
stickerSetInfo id:int64 title:string name:string thumbnail:thumbnail thumbnail_outline:outline is_owned:Bool is_installed:Bool is_archived:Bool is_official:Bool sticker_type:StickerType needs_repainting:Bool is_allowed_as_chat_emoji_status:Bool is_viewed:Bool size:int32 covers:vector<sticker> = StickerSetInfo;

//@description Represents a list of sticker sets @total_count Approximate total number of sticker sets found @sets List of sticker sets
stickerSets total_count:int32 sets:vector<stickerSetInfo> = StickerSets;

//@description Represents a list of trending sticker sets @total_count Approximate total number of trending sticker sets @sets List of trending sticker sets @is_premium True, if the list contains sticker sets with premium stickers
trendingStickerSets total_count:int32 sets:vector<stickerSetInfo> is_premium:Bool = TrendingStickerSets;


//@class EmojiCategorySource @description Describes source of stickers for an emoji category

//@description The category contains a list of similar emoji to search for in getStickers and searchStickers for stickers,
//-or getInlineQueryResults with the bot getOption("animation_search_bot_username") for animations
//@emojis List of emojis to search for
emojiCategorySourceSearch emojis:vector<string> = EmojiCategorySource;

//@description The category contains premium stickers that must be found by getPremiumStickers
emojiCategorySourcePremium = EmojiCategorySource;


//@description Describes an emoji category
//@name Name of the category
//@icon Custom emoji sticker, which represents icon of the category
//@source Source of stickers for the emoji category
//@is_greeting True, if the category must be shown first when choosing a sticker for the start page
emojiCategory name:string icon:sticker source:EmojiCategorySource is_greeting:Bool = EmojiCategory;

//@description Represents a list of emoji categories @categories List of categories
emojiCategories categories:vector<emojiCategory> = EmojiCategories;


//@class EmojiCategoryType @description Describes type of emoji category

//@description The category must be used by default (e.g., for custom emoji or animation search)
emojiCategoryTypeDefault = EmojiCategoryType;

//@description The category must be used by default for regular sticker selection. It may contain greeting emoji category and premium stickers
emojiCategoryTypeRegularStickers = EmojiCategoryType;

//@description The category must be used for emoji status selection
emojiCategoryTypeEmojiStatus = EmojiCategoryType;

//@description The category must be used for chat photo emoji selection
emojiCategoryTypeChatPhoto = EmojiCategoryType;


//@description Describes the current weather
//@temperature Temperature, in degree Celsius
//@emoji Emoji representing the weather
currentWeather temperature:double emoji:string = CurrentWeather;


//@description Describes position of a clickable rectangle area on a story media
//@x_percentage The abscissa of the rectangle's center, as a percentage of the media width
//@y_percentage The ordinate of the rectangle's center, as a percentage of the media height
//@width_percentage The width of the rectangle, as a percentage of the media width
//@height_percentage The height of the rectangle, as a percentage of the media height
//@rotation_angle Clockwise rotation angle of the rectangle, in degrees; 0-360
//@corner_radius_percentage The radius of the rectangle corner rounding, as a percentage of the media width
storyAreaPosition x_percentage:double y_percentage:double width_percentage:double height_percentage:double rotation_angle:double corner_radius_percentage:double = StoryAreaPosition;


//@class StoryAreaType @description Describes type of clickable area on a story media

//@description An area pointing to a location @location The location @address Address of the location; may be null if unknown
storyAreaTypeLocation location:location address:locationAddress = StoryAreaType;

//@description An area pointing to a venue @venue Information about the venue
storyAreaTypeVenue venue:venue = StoryAreaType;

//@description An area pointing to a suggested reaction. App needs to show a clickable reaction on the area and call setStoryReaction when the are is clicked
//@reaction_type Type of the reaction
//@total_count Number of times the reaction was added
//@is_dark True, if reaction has a dark background
//@is_flipped True, if reaction corner is flipped
storyAreaTypeSuggestedReaction reaction_type:ReactionType total_count:int32 is_dark:Bool is_flipped:Bool = StoryAreaType;

//@description An area pointing to a message @chat_id Identifier of the chat with the message @message_id Identifier of the message
storyAreaTypeMessage chat_id:int53 message_id:int53 = StoryAreaType;

//@description An area pointing to a HTTP or tg:// link @url HTTP or tg:// URL to be opened when the area is clicked
storyAreaTypeLink url:string = StoryAreaType;

//@description An area with information about weather
//@temperature Temperature, in degree Celsius
//@emoji Emoji representing the weather
//@background_color A color of the area background in the ARGB format
storyAreaTypeWeather temperature:double emoji:string background_color:int32 = StoryAreaType;

//@description An area with an upgraded gift
//@gift_name Unique name of the upgraded gift
storyAreaTypeUpgradedGift gift_name:string = StoryAreaType;


//@description Describes a clickable rectangle area on a story media @position Position of the area @type Type of the area
storyArea position:storyAreaPosition type:StoryAreaType = StoryArea;


//@class InputStoryAreaType @description Describes type of clickable area on a story media to be added

//@description An area pointing to a location @location The location @address Address of the location; pass null if unknown
inputStoryAreaTypeLocation location:location address:locationAddress = InputStoryAreaType;

//@description An area pointing to a venue found by the bot getOption("venue_search_bot_username")
//@query_id Identifier of the inline query, used to found the venue
//@result_id Identifier of the inline query result
inputStoryAreaTypeFoundVenue query_id:int64 result_id:string = InputStoryAreaType;

//@description An area pointing to a venue already added to the story
//@venue_provider Provider of the venue
//@venue_id Identifier of the venue in the provider database
inputStoryAreaTypePreviousVenue venue_provider:string venue_id:string = InputStoryAreaType;

//@description An area pointing to a suggested reaction
//@reaction_type Type of the reaction
//@is_dark True, if reaction has a dark background
//@is_flipped True, if reaction corner is flipped
inputStoryAreaTypeSuggestedReaction reaction_type:ReactionType is_dark:Bool is_flipped:Bool = InputStoryAreaType;

//@description An area pointing to a message
//@chat_id Identifier of the chat with the message. Currently, the chat must be a supergroup or a channel chat
//@message_id Identifier of the message. Use messageProperties.can_be_shared_in_story to check whether the message is suitable
inputStoryAreaTypeMessage chat_id:int53 message_id:int53 = InputStoryAreaType;

//@description An area pointing to a HTTP or tg:// link
//@url HTTP or tg:// URL to be opened when the area is clicked
inputStoryAreaTypeLink url:string = InputStoryAreaType;

//@description An area with information about weather
//@temperature Temperature, in degree Celsius
//@emoji Emoji representing the weather
//@background_color A color of the area background in the ARGB format
inputStoryAreaTypeWeather temperature:double emoji:string background_color:int32 = InputStoryAreaType;

//@description An area with an upgraded gift @gift_name Unique name of the upgraded gift
inputStoryAreaTypeUpgradedGift gift_name:string = InputStoryAreaType;


//@description Describes a clickable rectangle area on a story media to be added @position Position of the area @type Type of the area
inputStoryArea position:storyAreaPosition type:InputStoryAreaType = InputStoryArea;

//@description Contains a list of story areas to be added @areas List of input story areas. Currently, a story can have
//-up to 10 inputStoryAreaTypeLocation, inputStoryAreaTypeFoundVenue, and inputStoryAreaTypePreviousVenue areas,
//-up to getOption("story_suggested_reaction_area_count_max") inputStoryAreaTypeSuggestedReaction areas,
//-up to 1 inputStoryAreaTypeMessage area,
//-up to getOption("story_link_area_count_max") inputStoryAreaTypeLink areas if the current user is a Telegram Premium user,
//-up to 3 inputStoryAreaTypeWeather areas, and
//-up to 1 inputStoryAreaTypeUpgradedGift area
inputStoryAreas areas:vector<inputStoryArea> = InputStoryAreas;


//@description Describes a video file sent in a story
//@duration Duration of the video, in seconds
//@width Video width
//@height Video height
//@has_stickers True, if stickers were added to the video. The list of corresponding sticker sets can be received using getAttachedStickerSets
//@is_animation True, if the video has no sound
//@minithumbnail Video minithumbnail; may be null
//@thumbnail Video thumbnail in JPEG or MPEG4 format; may be null
//@preload_prefix_size Size of file prefix, which is expected to be preloaded, in bytes
//@cover_frame_timestamp Timestamp of the frame used as video thumbnail
//@video File containing the video
storyVideo duration:double width:int32 height:int32 has_stickers:Bool is_animation:Bool minithumbnail:minithumbnail thumbnail:thumbnail preload_prefix_size:int32 cover_frame_timestamp:double video:file = StoryVideo;


//@class StoryContent @description Contains the content of a story

//@description A photo story @photo The photo
storyContentPhoto photo:photo = StoryContent;

//@description A video story @video The video in MPEG4 format @alternative_video Alternative version of the video in MPEG4 format, encoded with H.264 codec; may be null
storyContentVideo video:storyVideo alternative_video:storyVideo = StoryContent;

//@description A story content that is not supported in the current TDLib version
storyContentUnsupported = StoryContent;


//@class InputStoryContent @description The content of a story to send

//@description A photo story
//@photo Photo to send. The photo must be at most 10 MB in size. The photo size must be 1080x1920
//@added_sticker_file_ids File identifiers of the stickers added to the photo, if applicable
inputStoryContentPhoto photo:InputFile added_sticker_file_ids:vector<int32> = InputStoryContent;

//@description A video story
//@video Video to be sent. The video size must be 720x1280. The video must be streamable and stored in MPEG4 format, after encoding with H.265 codec and key frames added each second
//@added_sticker_file_ids File identifiers of the stickers added to the video, if applicable
//@duration Precise duration of the video, in seconds; 0-60
//@cover_frame_timestamp Timestamp of the frame, which will be used as video thumbnail
//@is_animation True, if the video has no sound
inputStoryContentVideo video:InputFile added_sticker_file_ids:vector<int32> duration:double cover_frame_timestamp:double is_animation:Bool = InputStoryContent;


//@class StoryList @description Describes a list of stories

//@description The list of stories, shown in the main chat list and folder chat lists
storyListMain = StoryList;

//@description The list of stories, shown in the Arvhive chat list
storyListArchive = StoryList;


//@class StoryOrigin @description Contains information about the origin of a story that was reposted

//@description The original story was a public story with known sender @chat_id Identifier of the chat that posted original story @story_id Story identifier of the original story
storyOriginPublicStory chat_id:int53 story_id:int32 = StoryOrigin;

//@description The original story was sent by an unknown user @sender_name Name of the story sender
storyOriginHiddenUser sender_name:string = StoryOrigin;


//@description Contains information about original story that was reposted
//@origin Origin of the story that was reposted
//@is_content_modified True, if story content was modified during reposting; otherwise, story wasn't modified
storyRepostInfo origin:StoryOrigin is_content_modified:Bool = StoryRepostInfo;

//@description Contains information about interactions with a story
//@view_count Number of times the story was viewed
//@forward_count Number of times the story was forwarded; 0 if none or unknown
//@reaction_count Number of reactions added to the story; 0 if none or unknown
//@recent_viewer_user_ids Identifiers of at most 3 recent viewers of the story
storyInteractionInfo view_count:int32 forward_count:int32 reaction_count:int32 recent_viewer_user_ids:vector<int53> = StoryInteractionInfo;

//@description Represents a story
//@id Unique story identifier among stories of the given sender
//@sender_chat_id Identifier of the chat that posted the story
//@sender_id Identifier of the sender of the story; may be null if the story is posted on behalf of the sender_chat_id
//@date Point in time (Unix timestamp) when the story was published
//@is_being_sent True, if the story is being sent by the current user
//@is_being_edited True, if the story is being edited by the current user
//@is_edited True, if the story was edited
//@is_posted_to_chat_page True, if the story is saved in the sender's profile and will be available there after expiration
//@is_visible_only_for_self True, if the story is visible only for the current user
//@can_be_deleted True, if the story can be deleted
//@can_be_edited True, if the story can be edited
//@can_be_forwarded True, if the story can be forwarded as a message. Otherwise, screenshots and saving of the story content must be also forbidden
//@can_be_replied True, if the story can be replied in the chat with the story sender
//@can_toggle_is_posted_to_chat_page True, if the story's is_posted_to_chat_page value can be changed
//@can_get_statistics True, if the story statistics are available through getStoryStatistics
//@can_get_interactions True, if interactions with the story can be received through getStoryInteractions
//@has_expired_viewers True, if users viewed the story can't be received, because the story has expired more than getOption("story_viewers_expiration_delay") seconds ago
//@repost_info Information about the original story; may be null if the story wasn't reposted
//@interaction_info Information about interactions with the story; may be null if the story isn't owned or there were no interactions
//@chosen_reaction_type Type of the chosen reaction; may be null if none
//@privacy_settings Privacy rules affecting story visibility; may be approximate for non-owned stories
//@content Content of the story
//@areas Clickable areas to be shown on the story content
//@caption Caption of the story
story id:int32 sender_chat_id:int53 sender_id:MessageSender date:int32 is_being_sent:Bool is_being_edited:Bool is_edited:Bool is_posted_to_chat_page:Bool is_visible_only_for_self:Bool can_be_deleted:Bool can_be_edited:Bool can_be_forwarded:Bool can_be_replied:Bool can_toggle_is_posted_to_chat_page:Bool can_get_statistics:Bool can_get_interactions:Bool has_expired_viewers:Bool repost_info:storyRepostInfo interaction_info:storyInteractionInfo chosen_reaction_type:ReactionType privacy_settings:StoryPrivacySettings content:StoryContent areas:vector<storyArea> caption:formattedText = Story;

//@description Represents a list of stories
//@total_count Approximate total number of stories found
//@stories The list of stories
//@pinned_story_ids Identifiers of the pinned stories; returned only in getChatPostedToChatPageStories with from_story_id == 0
stories total_count:int32 stories:vector<story> pinned_story_ids:vector<int32> = Stories;

//@description Contains a list of stories found by a search @total_count Approximate total number of stories found @stories List of stories @next_offset The offset for the next request. If empty, then there are no more results
foundStories total_count:int32 stories:vector<story> next_offset:string = FoundStories;

//@description Contains identifier of a story along with identifier of its sender
//@sender_chat_id Identifier of the chat that posted the story
//@story_id Unique story identifier among stories of the given sender
storyFullId sender_chat_id:int53 story_id:int32 = StoryFullId;

//@description Contains basic information about a story
//@story_id Unique story identifier among stories of the given sender
//@date Point in time (Unix timestamp) when the story was published
//@is_for_close_friends True, if the story is available only to close friends
storyInfo story_id:int32 date:int32 is_for_close_friends:Bool = StoryInfo;

//@description Describes active stories posted by a chat
//@chat_id Identifier of the chat that posted the stories
//@list Identifier of the story list in which the stories are shown; may be null if the stories aren't shown in a story list
//@order A parameter used to determine order of the stories in the story list; 0 if the stories doesn't need to be shown in the story list. Stories must be sorted by the pair (order, story_sender_chat_id) in descending order
//@max_read_story_id Identifier of the last read active story
//@stories Basic information about the stories; use getStory to get full information about the stories. The stories are in chronological order (i.e., in order of increasing story identifiers)
chatActiveStories chat_id:int53 list:StoryList order:int53 max_read_story_id:int32 stories:vector<storyInfo> = ChatActiveStories;


//@class StoryInteractionType @description Describes type of interaction with a story

//@description A view of the story @chosen_reaction_type Type of the reaction that was chosen by the viewer; may be null if none
storyInteractionTypeView chosen_reaction_type:ReactionType = StoryInteractionType;

//@description A forward of the story as a message @message The message with story forward
storyInteractionTypeForward message:message = StoryInteractionType;

//@description A repost of the story as a story @story The reposted story
storyInteractionTypeRepost story:story = StoryInteractionType;


//@description Represents interaction with a story
//@actor_id Identifier of the user or chat that made the interaction
//@interaction_date Approximate point in time (Unix timestamp) when the interaction happened
//@block_list Block list to which the actor is added; may be null if none or for chat stories
//@type Type of the interaction
storyInteraction actor_id:MessageSender interaction_date:int32 block_list:BlockList type:StoryInteractionType = StoryInteraction;

//@description Represents a list of interactions with a story
//@total_count Approximate total number of interactions found
//@total_forward_count Approximate total number of found forwards and reposts; always 0 for chat stories
//@total_reaction_count Approximate total number of found reactions; always 0 for chat stories
//@interactions List of story interactions
//@next_offset The offset for the next request. If empty, then there are no more results
storyInteractions total_count:int32 total_forward_count:int32 total_reaction_count:int32 interactions:vector<storyInteraction> next_offset:string = StoryInteractions;


//@description Describes a message that can be used for quick reply
//@id Unique message identifier among all quick replies
//@sending_state The sending state of the message; may be null if the message isn't being sent and didn't fail to be sent
//@can_be_edited True, if the message can be edited
//@reply_to_message_id The identifier of the quick reply message to which the message replies; 0 if none
//@via_bot_user_id If non-zero, the user identifier of the bot through which this message was sent
//@media_album_id Unique identifier of an album this message belongs to; 0 if none. Only audios, documents, photos and videos can be grouped together in albums
//@content Content of the message
//@reply_markup Inline keyboard reply markup for the message; may be null if none
quickReplyMessage id:int53 sending_state:MessageSendingState can_be_edited:Bool reply_to_message_id:int53 via_bot_user_id:int53 media_album_id:int64 content:MessageContent reply_markup:ReplyMarkup = QuickReplyMessage;

//@description Contains a list of quick reply messages @messages List of quick reply messages; messages may be null
quickReplyMessages messages:vector<quickReplyMessage> = QuickReplyMessages;

//@description Describes a shortcut that can be used for a quick reply
//@id Unique shortcut identifier
//@name The name of the shortcut that can be used to use the shortcut
//@first_message The first shortcut message
//@message_count The total number of messages in the shortcut
quickReplyShortcut id:int32 name:string first_message:quickReplyMessage message_count:int32 = QuickReplyShortcut;


//@class PublicForward @description Describes a public forward or repost of a story

//@description Contains a public forward as a message @message Information about the message
publicForwardMessage message:message = PublicForward;

//@description Contains a public repost to a story @story Information about the story
publicForwardStory story:story = PublicForward;


//@description Represents a list of public forwards and reposts as a story of a message or a story
//@total_count Approximate total number of messages and stories found
//@forwards List of found public forwards and reposts
//@next_offset The offset for the next request. If empty, then there are no more results
publicForwards total_count:int32 forwards:vector<PublicForward> next_offset:string = PublicForwards;


//@description Describes media previews of a bot
//@date Point in time (Unix timestamp) when the preview was added or changed last time
//@content Content of the preview
botMediaPreview date:int32 content:StoryContent = BotMediaPreview;

//@description Contains a list of media previews of a bot @previews List of media previews
botMediaPreviews previews:vector<botMediaPreview> = BotMediaPreviews;

//@description Contains a list of media previews of a bot for the given language and the list of languages for which the bot has dedicated previews
//@previews List of media previews
//@language_codes List of language codes for which the bot has dedicated previews
botMediaPreviewInfo previews:vector<botMediaPreview> language_codes:vector<string> = BotMediaPreviewInfo;


//@description Contains a list of features available on a specific chat boost level
//@level Target chat boost level
//@story_per_day_count Number of stories that the chat can publish daily
//@custom_emoji_reaction_count Number of custom emoji reactions that can be added to the list of available reactions
//@title_color_count Number of custom colors for chat title
//@profile_accent_color_count Number of custom colors for profile photo background
//@can_set_profile_background_custom_emoji True, if custom emoji for profile background can be set
//@accent_color_count Number of custom colors for background of empty chat photo, replies to messages and link previews
//@can_set_background_custom_emoji True, if custom emoji for reply header and link preview background can be set
//@can_set_emoji_status True, if emoji status can be set
//@chat_theme_background_count Number of chat theme backgrounds that can be set as chat background
//@can_set_custom_background True, if custom background can be set in the chat for all users
//@can_set_custom_emoji_sticker_set True, if custom emoji sticker set can be set for the chat
//@can_recognize_speech True, if speech recognition can be used for video note and voice note messages by all users
//@can_disable_sponsored_messages True, if sponsored messages can be disabled in the chat
chatBoostLevelFeatures level:int32 story_per_day_count:int32 custom_emoji_reaction_count:int32 title_color_count:int32 profile_accent_color_count:int32 can_set_profile_background_custom_emoji:Bool accent_color_count:int32 can_set_background_custom_emoji:Bool can_set_emoji_status:Bool chat_theme_background_count:int32 can_set_custom_background:Bool can_set_custom_emoji_sticker_set:Bool can_recognize_speech:Bool can_disable_sponsored_messages:Bool = ChatBoostLevelFeatures;

//@description Contains a list of features available on the first chat boost levels
//@features The list of features
//@min_profile_background_custom_emoji_boost_level The minimum boost level required to set custom emoji for profile background
//@min_background_custom_emoji_boost_level The minimum boost level required to set custom emoji for reply header and link preview background; for channel chats only
//@min_emoji_status_boost_level The minimum boost level required to set emoji status
//@min_chat_theme_background_boost_level The minimum boost level required to set a chat theme background as chat background
//@min_custom_background_boost_level The minimum boost level required to set custom chat background
//@min_custom_emoji_sticker_set_boost_level The minimum boost level required to set custom emoji sticker set for the chat; for supergroup chats only
//@min_speech_recognition_boost_level The minimum boost level allowing to recognize speech in video note and voice note messages for non-Premium users; for supergroup chats only
//@min_sponsored_message_disable_boost_level The minimum boost level allowing to disable sponsored messages in the chat; for channel chats only
chatBoostFeatures features:vector<chatBoostLevelFeatures> min_profile_background_custom_emoji_boost_level:int32 min_background_custom_emoji_boost_level:int32 min_emoji_status_boost_level:int32 min_chat_theme_background_boost_level:int32 min_custom_background_boost_level:int32 min_custom_emoji_sticker_set_boost_level:int32 min_speech_recognition_boost_level:int32 min_sponsored_message_disable_boost_level:int32 = ChatBoostFeatures;


//@class ChatBoostSource @description Describes source of a chat boost

//@description The chat created a Telegram Premium gift code for a user
//@user_id Identifier of a user, for which the gift code was created
//@gift_code The created Telegram Premium gift code, which is known only if this is a gift code for the current user, or it has already been claimed
chatBoostSourceGiftCode user_id:int53 gift_code:string = ChatBoostSource;

//@description The chat created a giveaway
//@user_id Identifier of a user that won in the giveaway; 0 if none
//@gift_code The created Telegram Premium gift code if it was used by the user or can be claimed by the current user; an empty string otherwise; for Telegram Premium giveways only
//@star_count Number of Telegram Stars distributed among winners of the giveaway
//@giveaway_message_id Identifier of the corresponding giveaway message; can be an identifier of a deleted message
//@is_unclaimed True, if the winner for the corresponding giveaway prize wasn't chosen, because there were not enough participants
chatBoostSourceGiveaway user_id:int53 gift_code:string star_count:int53 giveaway_message_id:int53 is_unclaimed:Bool = ChatBoostSource;

//@description A user with Telegram Premium subscription or gifted Telegram Premium boosted the chat
//@user_id Identifier of the user
chatBoostSourcePremium user_id:int53 = ChatBoostSource;


//@description Describes a prepaid giveaway
//@id Unique identifier of the prepaid giveaway
//@winner_count Number of users which will receive giveaway prize
//@prize Prize of the giveaway
//@boost_count The number of boosts received by the chat from the giveaway; for Telegram Star giveaways only
//@payment_date Point in time (Unix timestamp) when the giveaway was paid
prepaidGiveaway id:int64 winner_count:int32 prize:GiveawayPrize boost_count:int32 payment_date:int32 = PrepaidGiveaway;

//@description Describes current boost status of a chat
//@boost_url An HTTP URL, which can be used to boost the chat
//@applied_slot_ids Identifiers of boost slots of the current user applied to the chat
//@level Current boost level of the chat
//@gift_code_boost_count The number of boosts received by the chat from created Telegram Premium gift codes and giveaways; always 0 if the current user isn't an administrator in the chat
//@boost_count The number of boosts received by the chat
//@current_level_boost_count The number of boosts added to reach the current level
//@next_level_boost_count The number of boosts needed to reach the next level; 0 if the next level isn't available
//@premium_member_count Approximate number of Telegram Premium subscribers joined the chat; always 0 if the current user isn't an administrator in the chat
//@premium_member_percentage A percentage of Telegram Premium subscribers joined the chat; always 0 if the current user isn't an administrator in the chat
//@prepaid_giveaways The list of prepaid giveaways available for the chat; only for chat administrators
chatBoostStatus boost_url:string applied_slot_ids:vector<int32> level:int32 gift_code_boost_count:int32 boost_count:int32 current_level_boost_count:int32 next_level_boost_count:int32 premium_member_count:int32 premium_member_percentage:double prepaid_giveaways:vector<prepaidGiveaway> = ChatBoostStatus;

//@description Describes a boost applied to a chat
//@id Unique identifier of the boost
//@count The number of identical boosts applied
//@source Source of the boost
//@start_date Point in time (Unix timestamp) when the chat was boosted
//@expiration_date Point in time (Unix timestamp) when the boost will expire
chatBoost id:string count:int32 source:ChatBoostSource start_date:int32 expiration_date:int32 = ChatBoost;

//@description Contains a list of boosts applied to a chat
//@total_count Total number of boosts applied to the chat
//@boosts List of boosts
//@next_offset The offset for the next request. If empty, then there are no more results
foundChatBoosts total_count:int32 boosts:vector<chatBoost> next_offset:string = FoundChatBoosts;

//@description Describes a slot for chat boost
//@slot_id Unique identifier of the slot
//@currently_boosted_chat_id Identifier of the currently boosted chat; 0 if none
//@start_date Point in time (Unix timestamp) when the chat was boosted; 0 if none
//@expiration_date Point in time (Unix timestamp) when the boost will expire
//@cooldown_until_date Point in time (Unix timestamp) after which the boost can be used for another chat
chatBoostSlot slot_id:int32 currently_boosted_chat_id:int53 start_date:int32 expiration_date:int32 cooldown_until_date:int32 = ChatBoostSlot;

//@description Contains a list of chat boost slots @slots List of boost slots
chatBoostSlots slots:vector<chatBoostSlot> = ChatBoostSlots;


//@class ResendCodeReason @description Describes the reason why a code needs to be re-sent

//@description The user requested to resend the code
resendCodeReasonUserRequest = ResendCodeReason;

//@description The code is re-sent, because device verification has failed
//@error_message Cause of the verification failure, for example, PLAY_SERVICES_NOT_AVAILABLE, APNS_RECEIVE_TIMEOUT, or APNS_INIT_FAILED
resendCodeReasonVerificationFailed error_message:string = ResendCodeReason;


//@class CallDiscardReason @description Describes the reason why a call was discarded

//@description The call wasn't discarded, or the reason is unknown
callDiscardReasonEmpty = CallDiscardReason;

//@description The call was ended before the conversation started. It was canceled by the caller or missed by the other party
callDiscardReasonMissed = CallDiscardReason;

//@description The call was ended before the conversation started. It was declined by the other party
callDiscardReasonDeclined = CallDiscardReason;

//@description The call was ended during the conversation because the users were disconnected
callDiscardReasonDisconnected = CallDiscardReason;

//@description The call was ended because one of the parties hung up
callDiscardReasonHungUp = CallDiscardReason;

//@description The call was ended because it has been used successfully to transfer private encryption key for the associated group call
//@encrypted_group_call_key Encrypted using the call private key encryption key for the associated group call
callDiscardReasonAllowGroupCall encrypted_group_call_key:bytes = CallDiscardReason;


//@description Specifies the supported call protocols
//@udp_p2p True, if UDP peer-to-peer connections are supported
//@udp_reflector True, if connection through UDP reflectors is supported
//@min_layer The minimum supported API layer; use 65
//@max_layer The maximum supported API layer; use 92
//@library_versions List of supported tgcalls versions
callProtocol udp_p2p:Bool udp_reflector:Bool min_layer:int32 max_layer:int32 library_versions:vector<string> = CallProtocol;


//@class CallServerType @description Describes the type of call server

//@description A Telegram call reflector @peer_tag A peer tag to be used with the reflector @is_tcp True, if the server uses TCP instead of UDP
callServerTypeTelegramReflector peer_tag:bytes is_tcp:Bool = CallServerType;

//@description A WebRTC server
//@username Username to be used for authentication
//@password Authentication password
//@supports_turn True, if the server supports TURN
//@supports_stun True, if the server supports STUN
callServerTypeWebrtc username:string password:string supports_turn:Bool supports_stun:Bool = CallServerType;


//@description Describes a server for relaying call data
//@id Server identifier
//@ip_address Server IPv4 address
//@ipv6_address Server IPv6 address
//@port Server port number
//@type Server type
callServer id:int64 ip_address:string ipv6_address:string port:int32 type:CallServerType = CallServer;


//@description Contains the call identifier @id Call identifier
callId id:int32 = CallId;

//@description Contains the group call identifier @id Group call identifier
groupCallId id:int32 = GroupCallId;


//@class CallState @description Describes the current call state

//@description The call is pending, waiting to be accepted by a user @is_created True, if the call has already been created by the server @is_received True, if the call has already been received by the other party
callStatePending is_created:Bool is_received:Bool = CallState;

//@description The call has been answered and encryption keys are being exchanged
callStateExchangingKeys = CallState;

//@description The call is ready to use
//@protocol Call protocols supported by the other call participant
//@servers List of available call servers
//@config A JSON-encoded call config
//@encryption_key Call encryption key
//@emojis Encryption key fingerprint represented as 4 emoji
//@allow_p2p True, if peer-to-peer connection is allowed by users privacy settings
//@custom_parameters Custom JSON-encoded call parameters to be passed to tgcalls
callStateReady protocol:callProtocol servers:vector<callServer> config:string encryption_key:bytes emojis:vector<string> allow_p2p:Bool custom_parameters:string = CallState;

//@description The call is hanging up after discardCall has been called
callStateHangingUp = CallState;

//@description The call has ended successfully
//@reason The reason why the call has ended
//@need_rating True, if the call rating must be sent to the server
//@need_debug_information True, if the call debug information must be sent to the server
//@need_log True, if the call log must be sent to the server
callStateDiscarded reason:CallDiscardReason need_rating:Bool need_debug_information:Bool need_log:Bool = CallState;

//@description The call has ended with an error @error Error. An error with the code 4005000 will be returned if an outgoing call is missed because of an expired timeout
callStateError error:error = CallState;


//@class GroupCallVideoQuality @description Describes the quality of a group call video

//@description The worst available video quality
groupCallVideoQualityThumbnail = GroupCallVideoQuality;

//@description The medium video quality
groupCallVideoQualityMedium = GroupCallVideoQuality;

//@description The best available video quality
groupCallVideoQualityFull = GroupCallVideoQuality;


//@description Describes an available stream in a group call
//@channel_id Identifier of an audio/video channel
//@scale Scale of segment durations in the stream. The duration is 1000/(2**scale) milliseconds
//@time_offset Point in time when the stream currently ends; Unix timestamp in milliseconds
groupCallStream channel_id:int32 scale:int32 time_offset:int53 = GroupCallStream;

//@description Represents a list of group call streams @streams A list of group call streams
groupCallStreams streams:vector<groupCallStream> = GroupCallStreams;

//@description Represents an RTMP URL @url The URL @stream_key Stream key
rtmpUrl url:string stream_key:string = RtmpUrl;


//@description Describes a recently speaking participant in a group call @participant_id Group call participant identifier @is_speaking True, is the user has spoken recently
groupCallRecentSpeaker participant_id:MessageSender is_speaking:Bool = GroupCallRecentSpeaker;

//@description Describes a group call
//@id Group call identifier
//@from_call_id Identifier of one-to-one call from which the group call was created; 0 if unknown
//@title Group call title
//@scheduled_start_date Point in time (Unix timestamp) when the group call is expected to be started by an administrator; 0 if it is already active or was ended
//@enabled_start_notification True, if the group call is scheduled and the current user will receive a notification when the group call starts
//@is_active True, if the call is active
//@is_rtmp_stream True, if the chat is an RTMP stream instead of an ordinary video chat
//@is_joined True, if the call is joined
//@need_rejoin True, if user was kicked from the call because of network loss and the call needs to be rejoined
//@can_be_managed True, if the current user can manage the group call
//@participant_count Number of participants in the group call
//@has_hidden_listeners True, if group call participants, which are muted, aren't returned in participant list
//@loaded_all_participants True, if all group call participants are loaded
//@recent_speakers At most 3 recently speaking users in the group call
//@is_my_video_enabled True, if the current user's video is enabled
//@is_my_video_paused True, if the current user's video is paused
//@can_enable_video True, if the current user can broadcast video or share screen
//@mute_new_participants True, if only group call administrators can unmute new participants
//@can_toggle_mute_new_participants True, if the current user can enable or disable mute_new_participants setting
//@record_duration Duration of the ongoing group call recording, in seconds; 0 if none. An updateGroupCall update is not triggered when value of this field changes, but the same recording goes on
//@is_video_recorded True, if a video file is being recorded for the call
//@duration Call duration, in seconds; for ended calls only
groupCall id:int32 from_call_id:int32 title:string scheduled_start_date:int32 enabled_start_notification:Bool is_active:Bool is_rtmp_stream:Bool is_joined:Bool need_rejoin:Bool can_be_managed:Bool participant_count:int32 has_hidden_listeners:Bool loaded_all_participants:Bool recent_speakers:vector<groupCallRecentSpeaker> is_my_video_enabled:Bool is_my_video_paused:Bool can_enable_video:Bool mute_new_participants:Bool can_toggle_mute_new_participants:Bool record_duration:int32 is_video_recorded:Bool duration:int32 = GroupCall;

//@description Describes a group of video synchronization source identifiers @semantics The semantics of sources, one of "SIM" or "FID" @source_ids The list of synchronization source identifiers
groupCallVideoSourceGroup semantics:string source_ids:vector<int32> = GroupCallVideoSourceGroup;

//@description Contains information about a group call participant's video channel
//@source_groups List of synchronization source groups of the video
//@endpoint_id Video channel endpoint identifier
//@is_paused True, if the video is paused. This flag needs to be ignored, if new video frames are received
groupCallParticipantVideoInfo source_groups:vector<groupCallVideoSourceGroup> endpoint_id:string is_paused:Bool = GroupCallParticipantVideoInfo;

//@description Represents a group call participant
//@participant_id Identifier of the group call participant
//@audio_source_id User's audio channel synchronization source identifier
//@screen_sharing_audio_source_id User's screen sharing audio channel synchronization source identifier
//@video_info Information about user's video channel; may be null if there is no active video
//@screen_sharing_video_info Information about user's screen sharing video channel; may be null if there is no active screen sharing video
//@bio The participant user's bio or the participant chat's description
//@is_current_user True, if the participant is the current user
//@is_speaking True, if the participant is speaking as set by setGroupCallParticipantIsSpeaking
//@is_hand_raised True, if the participant hand is raised
//@can_be_muted_for_all_users True, if the current user can mute the participant for all other group call participants
//@can_be_unmuted_for_all_users True, if the current user can allow the participant to unmute themselves or unmute the participant (if the participant is the current user)
//@can_be_muted_for_current_user True, if the current user can mute the participant only for self
//@can_be_unmuted_for_current_user True, if the current user can unmute the participant for self
//@is_muted_for_all_users True, if the participant is muted for all users
//@is_muted_for_current_user True, if the participant is muted for the current user
//@can_unmute_self True, if the participant is muted for all users, but can unmute themselves
//@volume_level Participant's volume level; 1-20000 in hundreds of percents
//@order User's order in the group call participant list. Orders must be compared lexicographically. The bigger is order, the higher is user in the list. If order is empty, the user must be removed from the participant list
groupCallParticipant participant_id:MessageSender audio_source_id:int32 screen_sharing_audio_source_id:int32 video_info:groupCallParticipantVideoInfo screen_sharing_video_info:groupCallParticipantVideoInfo bio:string is_current_user:Bool is_speaking:Bool is_hand_raised:Bool can_be_muted_for_all_users:Bool can_be_unmuted_for_all_users:Bool can_be_muted_for_current_user:Bool can_be_unmuted_for_current_user:Bool is_muted_for_all_users:Bool is_muted_for_current_user:Bool can_unmute_self:Bool volume_level:int32 order:string = GroupCallParticipant;


//@class CallProblem @description Describes the exact type of problem with a call

//@description The user heard their own voice
callProblemEcho = CallProblem;

//@description The user heard background noise
callProblemNoise = CallProblem;

//@description The other side kept disappearing
callProblemInterruptions = CallProblem;

//@description The speech was distorted
callProblemDistortedSpeech = CallProblem;

//@description The user couldn't hear the other side
callProblemSilentLocal = CallProblem;

//@description The other side couldn't hear the user
callProblemSilentRemote = CallProblem;

//@description The call ended unexpectedly
callProblemDropped = CallProblem;

//@description The video was distorted
callProblemDistortedVideo = CallProblem;

//@description The video was pixelated
callProblemPixelatedVideo = CallProblem;


//@description Describes a call
//@id Call identifier, not persistent
//@user_id User identifier of the other call participant
//@is_outgoing True, if the call is outgoing
//@is_video True, if the call is a video call
//@state Call state
//@group_call_id Identifier of the group call associated with the call; 0 if the group call isn't created yet. The group call can be received through the method getGroupCall
call id:int32 user_id:int53 is_outgoing:Bool is_video:Bool state:CallState group_call_id:int32 = Call;


//@class FirebaseAuthenticationSettings @description Contains settings for Firebase Authentication in the official applications

//@description Settings for Firebase Authentication in the official Android application
firebaseAuthenticationSettingsAndroid = FirebaseAuthenticationSettings;

//@description Settings for Firebase Authentication in the official iOS application @device_token Device token from Apple Push Notification service @is_app_sandbox True, if App Sandbox is enabled
firebaseAuthenticationSettingsIos device_token:string is_app_sandbox:Bool = FirebaseAuthenticationSettings;


//@description Contains settings for the authentication of the user's phone number
//@allow_flash_call Pass true if the authentication code may be sent via a flash call to the specified phone number
//@allow_missed_call Pass true if the authentication code may be sent via a missed call to the specified phone number
//@is_current_phone_number Pass true if the authenticated phone number is used on the current device
//@has_unknown_phone_number Pass true if there is a SIM card in the current device, but it is not possible to check whether phone number matches
//@allow_sms_retriever_api For official applications only. True, if the application can use Android SMS Retriever API (requires Google Play Services >= 10.2) to automatically receive the authentication code from the SMS. See https://developers.google.com/identity/sms-retriever/ for more details
//@firebase_authentication_settings For official Android and iOS applications only; pass null otherwise. Settings for Firebase Authentication
//@authentication_tokens List of up to 20 authentication tokens, recently received in updateOption("authentication_token") in previously logged out sessions
phoneNumberAuthenticationSettings allow_flash_call:Bool allow_missed_call:Bool is_current_phone_number:Bool has_unknown_phone_number:Bool allow_sms_retriever_api:Bool firebase_authentication_settings:FirebaseAuthenticationSettings authentication_tokens:vector<string> = PhoneNumberAuthenticationSettings;


//@description Represents a reaction applied to a message
//@type Type of the reaction
//@sender_id Identifier of the chat member, applied the reaction
//@is_outgoing True, if the reaction was added by the current user
//@date Point in time (Unix timestamp) when the reaction was added
addedReaction type:ReactionType sender_id:MessageSender is_outgoing:Bool date:int32 = AddedReaction;

//@description Represents a list of reactions added to a message @total_count The total number of found reactions @reactions The list of added reactions @next_offset The offset for the next request. If empty, then there are no more results
addedReactions total_count:int32 reactions:vector<addedReaction> next_offset:string = AddedReactions;

//@description Represents an available reaction @type Type of the reaction @needs_premium True, if Telegram Premium is needed to send the reaction
availableReaction type:ReactionType needs_premium:Bool = AvailableReaction;

//@description Represents a list of reactions that can be added to a message
//@top_reactions List of reactions to be shown at the top
//@recent_reactions List of recently used reactions
//@popular_reactions List of popular reactions
//@allow_custom_emoji True, if any custom emoji reaction can be added by Telegram Premium subscribers
//@are_tags True, if the reactions will be tags and the message can be found by them
//@unavailability_reason The reason why the current user can't add reactions to the message, despite some other users can; may be null if none
availableReactions top_reactions:vector<availableReaction> recent_reactions:vector<availableReaction> popular_reactions:vector<availableReaction> allow_custom_emoji:Bool are_tags:Bool unavailability_reason:ReactionUnavailabilityReason = AvailableReactions;

//@description Contains information about an emoji reaction
//@emoji Text representation of the reaction
//@title Reaction title
//@is_active True, if the reaction can be added to new messages and enabled in chats
//@static_icon Static icon for the reaction
//@appear_animation Appear animation for the reaction
//@select_animation Select animation for the reaction
//@activate_animation Activate animation for the reaction
//@effect_animation Effect animation for the reaction
//@around_animation Around animation for the reaction; may be null
//@center_animation Center animation for the reaction; may be null
emojiReaction emoji:string title:string is_active:Bool static_icon:sticker appear_animation:sticker select_animation:sticker activate_animation:sticker effect_animation:sticker around_animation:sticker center_animation:sticker = EmojiReaction;


//@class ReactionUnavailabilityReason @description Describes why the current user can't add reactions to the message, despite some other users can

//@description The user is an anonymous administrator in the supergroup, but isn't a creator of it, so they can't vote on behalf of the supergroup
reactionUnavailabilityReasonAnonymousAdministrator = ReactionUnavailabilityReason;

//@description The user isn't a member of the supergroup and can't send messages and reactions there without joining
reactionUnavailabilityReasonGuest = ReactionUnavailabilityReason;


//@description Represents a list of animations @animations List of animations
animations animations:vector<animation> = Animations;


//@class DiceStickers @description Contains animated stickers which must be used for dice animation rendering

//@description A regular animated sticker @sticker The animated sticker with the dice animation
diceStickersRegular sticker:sticker = DiceStickers;

//@description Animated stickers to be combined into a slot machine
//@background The animated sticker with the slot machine background. The background animation must start playing after all reel animations finish
//@lever The animated sticker with the lever animation. The lever animation must play once in the initial dice state
//@left_reel The animated sticker with the left reel
//@center_reel The animated sticker with the center reel
//@right_reel The animated sticker with the right reel
diceStickersSlotMachine background:sticker lever:sticker left_reel:sticker center_reel:sticker right_reel:sticker = DiceStickers;


//@description Represents the result of an importContacts request
//@user_ids User identifiers of the imported contacts in the same order as they were specified in the request; 0 if the contact is not yet a registered user
//@importer_count The number of users that imported the corresponding contact; 0 for already registered users or if unavailable
importedContacts user_ids:vector<int53> importer_count:vector<int32> = ImportedContacts;


//@class SpeechRecognitionResult @description Describes result of speech recognition in a voice note

//@description The speech recognition is ongoing @partial_text Partially recognized text
speechRecognitionResultPending partial_text:string = SpeechRecognitionResult;

//@description The speech recognition successfully finished @text Recognized text
speechRecognitionResultText text:string = SpeechRecognitionResult;

//@description The speech recognition failed @error Recognition error. An error with a message "MSG_VOICE_TOO_LONG" is returned when media duration is too big to be recognized
speechRecognitionResultError error:error = SpeechRecognitionResult;


//@description Describes a connection of the bot with a business account
//@id Unique identifier of the connection
//@user_id Identifier of the business user that created the connection
//@user_chat_id Chat identifier of the private chat with the user
//@date Point in time (Unix timestamp) when the connection was established
//@can_reply True, if the bot can send messages to the connected user; false otherwise
//@is_enabled True, if the connection is enabled; false otherwise
businessConnection id:string user_id:int53 user_chat_id:int53 date:int32 can_reply:Bool is_enabled:Bool = BusinessConnection;


//@description Describes a color to highlight a bot added to attachment menu @light_color Color in the RGB format for light themes @dark_color Color in the RGB format for dark themes
attachmentMenuBotColor light_color:int32 dark_color:int32 = AttachmentMenuBotColor;

//@description Represents a bot, which can be added to attachment or side menu
//@bot_user_id User identifier of the bot
//@supports_self_chat True, if the bot supports opening from attachment menu in the chat with the bot
//@supports_user_chats True, if the bot supports opening from attachment menu in private chats with ordinary users
//@supports_bot_chats True, if the bot supports opening from attachment menu in private chats with other bots
//@supports_group_chats True, if the bot supports opening from attachment menu in basic group and supergroup chats
//@supports_channel_chats True, if the bot supports opening from attachment menu in channel chats
//@request_write_access True, if the user must be asked for the permission to send messages to the bot
//@is_added True, if the bot was explicitly added by the user. If the bot isn't added, then on the first bot launch toggleBotIsAddedToAttachmentMenu must be called and the bot must be added or removed
//@show_in_attachment_menu True, if the bot must be shown in the attachment menu
//@show_in_side_menu True, if the bot must be shown in the side menu
//@show_disclaimer_in_side_menu True, if a disclaimer, why the bot is shown in the side menu, is needed
//@name Name for the bot in attachment menu
//@name_color Color to highlight selected name of the bot if appropriate; may be null
//@default_icon Default icon for the bot in SVG format; may be null
//@ios_static_icon Icon for the bot in SVG format for the official iOS app; may be null
//@ios_animated_icon Icon for the bot in TGS format for the official iOS app; may be null
//@ios_side_menu_icon Icon for the bot in PNG format for the official iOS app side menu; may be null
//@android_icon Icon for the bot in TGS format for the official Android app; may be null
//@android_side_menu_icon Icon for the bot in SVG format for the official Android app side menu; may be null
//@macos_icon Icon for the bot in TGS format for the official native macOS app; may be null
//@macos_side_menu_icon Icon for the bot in PNG format for the official macOS app side menu; may be null
//@icon_color Color to highlight selected icon of the bot if appropriate; may be null
//@web_app_placeholder Default placeholder for opened Web Apps in SVG format; may be null
attachmentMenuBot bot_user_id:int53 supports_self_chat:Bool supports_user_chats:Bool supports_bot_chats:Bool supports_group_chats:Bool supports_channel_chats:Bool request_write_access:Bool is_added:Bool show_in_attachment_menu:Bool show_in_side_menu:Bool show_disclaimer_in_side_menu:Bool name:string name_color:attachmentMenuBotColor default_icon:file ios_static_icon:file ios_animated_icon:file ios_side_menu_icon:file android_icon:file android_side_menu_icon:file macos_icon:file macos_side_menu_icon:file icon_color:attachmentMenuBotColor web_app_placeholder:file = AttachmentMenuBot;

//@description Information about the message sent by answerWebAppQuery @inline_message_id Identifier of the sent inline message, if known
sentWebAppMessage inline_message_id:string = SentWebAppMessage;


//@class BotWriteAccessAllowReason @description Describes a reason why a bot was allowed to write messages to the current user

//@description The user connected a website by logging in using Telegram Login Widget on it @domain_name Domain name of the connected website
botWriteAccessAllowReasonConnectedWebsite domain_name:string = BotWriteAccessAllowReason;

//@description The user added the bot to attachment or side menu using toggleBotIsAddedToAttachmentMenu
botWriteAccessAllowReasonAddedToAttachmentMenu = BotWriteAccessAllowReason;

//@description The user launched a Web App using getWebAppLinkUrl @web_app Information about the Web App
botWriteAccessAllowReasonLaunchedWebApp web_app:webApp = BotWriteAccessAllowReason;

//@description The user accepted bot's request to send messages with allowBotToSendMessages
botWriteAccessAllowReasonAcceptedRequest = BotWriteAccessAllowReason;


//@description Contains an HTTP URL @url The URL
httpUrl url:string = HttpUrl;


//@description Contains an HTTPS URL, which can be used to get information about a user @url The URL @expires_in Left time for which the link is valid, in seconds; 0 if the link is a public username link
userLink url:string expires_in:int32 = UserLink;


//@description Describes allowed types for the target chat
//@allow_user_chats True, if private chats with ordinary users are allowed
//@allow_bot_chats True, if private chats with other bots are allowed
//@allow_group_chats True, if basic group and supergroup chats are allowed
//@allow_channel_chats True, if channel chats are allowed
targetChatTypes allow_user_chats:Bool allow_bot_chats:Bool allow_group_chats:Bool allow_channel_chats:Bool = TargetChatTypes;


//@class TargetChat @description Describes the target chat to be opened

//@description The currently opened chat and forum topic must be kept
targetChatCurrent = TargetChat;

//@description The chat needs to be chosen by the user among chats of the specified types @types Allowed types for the chat
targetChatChosen types:targetChatTypes = TargetChat;

//@description The chat needs to be open with the provided internal link @link An internal link pointing to the chat
targetChatInternalLink link:InternalLinkType = TargetChat;


//@class InputInlineQueryResult @description Represents a single result of an inline query; for bots only

//@description Represents a link to an animated GIF or an animated (i.e., without sound) H.264/MPEG-4 AVC video
//@id Unique identifier of the query result
//@title Title of the query result
//@thumbnail_url URL of the result thumbnail (JPEG, GIF, or MPEG4), if it exists
//@thumbnail_mime_type MIME type of the video thumbnail. If non-empty, must be one of "image/jpeg", "image/gif" and "video/mp4"
//@video_url The URL of the video file (file size must not exceed 1MB)
//@video_mime_type MIME type of the video file. Must be one of "image/gif" and "video/mp4"
//@video_duration Duration of the video, in seconds
//@video_width Width of the video
//@video_height Height of the video
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageAnimation, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultAnimation id:string title:string thumbnail_url:string thumbnail_mime_type:string video_url:string video_mime_type:string video_duration:int32 video_width:int32 video_height:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents a link to an article or web page
//@id Unique identifier of the query result
//@url URL of the result, if it exists
//@title Title of the result
//@param_description A short description of the result
//@thumbnail_url URL of the result thumbnail, if it exists
//@thumbnail_width Thumbnail width, if known
//@thumbnail_height Thumbnail height, if known
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultArticle id:string url:string title:string description:string thumbnail_url:string thumbnail_width:int32 thumbnail_height:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents a link to an MP3 audio file
//@id Unique identifier of the query result
//@title Title of the audio file
//@performer Performer of the audio file
//@audio_url The URL of the audio file
//@audio_duration Audio file duration, in seconds
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageAudio, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultAudio id:string title:string performer:string audio_url:string audio_duration:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents a user contact
//@id Unique identifier of the query result
//@contact User contact
//@thumbnail_url URL of the result thumbnail, if it exists
//@thumbnail_width Thumbnail width, if known
//@thumbnail_height Thumbnail height, if known
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultContact id:string contact:contact thumbnail_url:string thumbnail_width:int32 thumbnail_height:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents a link to a file
//@id Unique identifier of the query result
//@title Title of the resulting file
//@param_description Short description of the result, if known
//@document_url URL of the file
//@mime_type MIME type of the file content; only "application/pdf" and "application/zip" are currently allowed
//@thumbnail_url The URL of the file thumbnail, if it exists
//@thumbnail_width Width of the thumbnail
//@thumbnail_height Height of the thumbnail
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageDocument, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultDocument id:string title:string description:string document_url:string mime_type:string thumbnail_url:string thumbnail_width:int32 thumbnail_height:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents a game
//@id Unique identifier of the query result
//@game_short_name Short name of the game
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
inputInlineQueryResultGame id:string game_short_name:string reply_markup:ReplyMarkup = InputInlineQueryResult;

//@description Represents a point on the map
//@id Unique identifier of the query result
//@location Location result
//@live_period Amount of time relative to the message sent time until the location can be updated, in seconds
//@title Title of the result
//@thumbnail_url URL of the result thumbnail, if it exists
//@thumbnail_width Thumbnail width, if known
//@thumbnail_height Thumbnail height, if known
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultLocation id:string location:location live_period:int32 title:string thumbnail_url:string thumbnail_width:int32 thumbnail_height:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents link to a JPEG image
//@id Unique identifier of the query result
//@title Title of the result, if known
//@param_description A short description of the result, if known
//@thumbnail_url URL of the photo thumbnail, if it exists
//@photo_url The URL of the JPEG photo (photo size must not exceed 5MB)
//@photo_width Width of the photo
//@photo_height Height of the photo
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessagePhoto, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultPhoto id:string title:string description:string thumbnail_url:string photo_url:string photo_width:int32 photo_height:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents a link to a WEBP, TGS, or WEBM sticker
//@id Unique identifier of the query result
//@thumbnail_url URL of the sticker thumbnail, if it exists
//@sticker_url The URL of the WEBP, TGS, or WEBM sticker (sticker file size must not exceed 5MB)
//@sticker_width Width of the sticker
//@sticker_height Height of the sticker
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageSticker, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultSticker id:string thumbnail_url:string sticker_url:string sticker_width:int32 sticker_height:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents information about a venue
//@id Unique identifier of the query result
//@venue Venue result
//@thumbnail_url URL of the result thumbnail, if it exists
//@thumbnail_width Thumbnail width, if known
//@thumbnail_height Thumbnail height, if known
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultVenue id:string venue:venue thumbnail_url:string thumbnail_width:int32 thumbnail_height:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents a link to a page containing an embedded video player or a video file
//@id Unique identifier of the query result
//@title Title of the result
//@param_description A short description of the result, if known
//@thumbnail_url The URL of the video thumbnail (JPEG), if it exists
//@video_url URL of the embedded video player or video file
//@mime_type MIME type of the content of the video URL, only "text/html" or "video/mp4" are currently supported
//@video_width Width of the video
//@video_height Height of the video
//@video_duration Video duration, in seconds
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageVideo, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultVideo id:string title:string description:string thumbnail_url:string video_url:string mime_type:string video_width:int32 video_height:int32 video_duration:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;

//@description Represents a link to an opus-encoded audio file within an OGG container, single channel audio
//@id Unique identifier of the query result
//@title Title of the voice note
//@voice_note_url The URL of the voice note file
//@voice_note_duration Duration of the voice note, in seconds
//@reply_markup The message reply markup; pass null if none. Must be of type replyMarkupInlineKeyboard or null
//@input_message_content The content of the message to be sent. Must be one of the following types: inputMessageText, inputMessageVoiceNote, inputMessageInvoice, inputMessageLocation, inputMessageVenue or inputMessageContact
inputInlineQueryResultVoiceNote id:string title:string voice_note_url:string voice_note_duration:int32 reply_markup:ReplyMarkup input_message_content:InputMessageContent = InputInlineQueryResult;


//@class InlineQueryResult @description Represents a single result of an inline query

//@description Represents a link to an article or web page
//@id Unique identifier of the query result
//@url URL of the result, if it exists
//@title Title of the result
//@param_description A short description of the result
//@thumbnail Result thumbnail in JPEG format; may be null
inlineQueryResultArticle id:string url:string title:string description:string thumbnail:thumbnail = InlineQueryResult;

//@description Represents a user contact
//@id Unique identifier of the query result
//@contact A user contact
//@thumbnail Result thumbnail in JPEG format; may be null
inlineQueryResultContact id:string contact:contact thumbnail:thumbnail = InlineQueryResult;

//@description Represents a point on the map
//@id Unique identifier of the query result
//@location Location result
//@title Title of the result
//@thumbnail Result thumbnail in JPEG format; may be null
inlineQueryResultLocation id:string location:location title:string thumbnail:thumbnail = InlineQueryResult;

//@description Represents information about a venue
//@id Unique identifier of the query result
//@venue Venue result
//@thumbnail Result thumbnail in JPEG format; may be null
inlineQueryResultVenue id:string venue:venue thumbnail:thumbnail = InlineQueryResult;

//@description Represents information about a game
//@id Unique identifier of the query result
//@game Game result
inlineQueryResultGame id:string game:game = InlineQueryResult;

//@description Represents an animation file
//@id Unique identifier of the query result
//@animation Animation file
//@title Animation title
inlineQueryResultAnimation id:string animation:animation title:string = InlineQueryResult;

//@description Represents an audio file
//@id Unique identifier of the query result
//@audio Audio file
inlineQueryResultAudio id:string audio:audio = InlineQueryResult;

//@description Represents a document
//@id Unique identifier of the query result
//@document Document
//@title Document title
//@param_description Document description
inlineQueryResultDocument id:string document:document title:string description:string = InlineQueryResult;

//@description Represents a photo
//@id Unique identifier of the query result
//@photo Photo
//@title Title of the result, if known
//@param_description A short description of the result, if known
inlineQueryResultPhoto id:string photo:photo title:string description:string = InlineQueryResult;

//@description Represents a sticker
//@id Unique identifier of the query result
//@sticker Sticker
inlineQueryResultSticker id:string sticker:sticker = InlineQueryResult;

//@description Represents a video
//@id Unique identifier of the query result
//@video Video
//@title Title of the video
//@param_description Description of the video
inlineQueryResultVideo id:string video:video title:string description:string = InlineQueryResult;

//@description Represents a voice note
//@id Unique identifier of the query result
//@voice_note Voice note
//@title Title of the voice note
inlineQueryResultVoiceNote id:string voice_note:voiceNote title:string = InlineQueryResult;


//@class InlineQueryResultsButtonType @description Represents type of button in results of inline query

//@description Describes the button that opens a private chat with the bot and sends a start message to the bot with the given parameter @parameter The parameter for the bot start message
inlineQueryResultsButtonTypeStartBot parameter:string = InlineQueryResultsButtonType;

//@description Describes the button that opens a Web App by calling getWebAppUrl @url An HTTP URL to pass to getWebAppUrl
inlineQueryResultsButtonTypeWebApp url:string = InlineQueryResultsButtonType;


//@description Represents a button to be shown above inline query results @text The text of the button @type Type of the button
inlineQueryResultsButton text:string type:InlineQueryResultsButtonType = InlineQueryResultsButton;


//@description Represents the results of the inline query. Use sendInlineQueryResultMessage to send the result of the query
//@inline_query_id Unique identifier of the inline query
//@button Button to be shown above inline query results; may be null
//@results Results of the query
//@next_offset The offset for the next request. If empty, then there are no more results
inlineQueryResults inline_query_id:int64 button:inlineQueryResultsButton results:vector<InlineQueryResult> next_offset:string = InlineQueryResults;


//@description Represents an inline message that can be sent via the bot
//@id Unique identifier for the message
//@expiration_date Point in time (Unix timestamp) when the message can't be used anymore
preparedInlineMessageId id:string expiration_date:int32 = PreparedInlineMessageId;

//@description Represents a ready to send inline message. Use sendInlineQueryResultMessage to send the message
//@inline_query_id Unique identifier of the inline query to pass to sendInlineQueryResultMessage
//@result Resulted inline message of the query
//@chat_types Types of the chats to which the message can be sent
preparedInlineMessage inline_query_id:int64 result:InlineQueryResult chat_types:targetChatTypes = PreparedInlineMessage;


//@class CallbackQueryPayload @description Represents a payload of a callback query

//@description The payload for a general callback button @data Data that was attached to the callback button
callbackQueryPayloadData data:bytes = CallbackQueryPayload;

//@description The payload for a callback button requiring password @password The 2-step verification password for the current user @data Data that was attached to the callback button
callbackQueryPayloadDataWithPassword password:string data:bytes = CallbackQueryPayload;

//@description The payload for a game callback button @game_short_name A short name of the game that was attached to the callback button
callbackQueryPayloadGame game_short_name:string = CallbackQueryPayload;


//@description Contains a bot's answer to a callback query @text Text of the answer @show_alert True, if an alert must be shown to the user instead of a toast notification @url URL to be opened
callbackQueryAnswer text:string show_alert:Bool url:string = CallbackQueryAnswer;


//@description Contains the result of a custom request @result A JSON-serialized result
customRequestResult result:string = CustomRequestResult;


//@description Contains one row of the game high score table @position Position in the high score table @user_id User identifier @score User score
gameHighScore position:int32 user_id:int53 score:int32 = GameHighScore;

//@description Contains a list of game high scores @scores A list of game high scores
gameHighScores scores:vector<gameHighScore> = GameHighScores;


//@class ChatEventAction @description Represents a chat event

//@description A message was edited @old_message The original message before the edit @new_message The message after it was edited
chatEventMessageEdited old_message:message new_message:message = ChatEventAction;

//@description A message was deleted @message Deleted message @can_report_anti_spam_false_positive True, if the message deletion can be reported via reportSupergroupAntiSpamFalsePositive
chatEventMessageDeleted message:message can_report_anti_spam_false_positive:Bool = ChatEventAction;

//@description A message was pinned @message Pinned message
chatEventMessagePinned message:message = ChatEventAction;

//@description A message was unpinned @message Unpinned message
chatEventMessageUnpinned message:message = ChatEventAction;

//@description A poll in a message was stopped @message The message with the poll
chatEventPollStopped message:message = ChatEventAction;

//@description A new member joined the chat
chatEventMemberJoined = ChatEventAction;

//@description A new member joined the chat via an invite link @invite_link Invite link used to join the chat @via_chat_folder_invite_link True, if the user has joined the chat using an invite link for a chat folder
chatEventMemberJoinedByInviteLink invite_link:chatInviteLink via_chat_folder_invite_link:Bool = ChatEventAction;

//@description A new member was accepted to the chat by an administrator @approver_user_id User identifier of the chat administrator, approved user join request @invite_link Invite link used to join the chat; may be null
chatEventMemberJoinedByRequest approver_user_id:int53 invite_link:chatInviteLink = ChatEventAction;

//@description A new chat member was invited @user_id New member user identifier @status New member status
chatEventMemberInvited user_id:int53 status:ChatMemberStatus = ChatEventAction;

//@description A member left the chat
chatEventMemberLeft = ChatEventAction;

//@description A chat member has gained/lost administrator status, or the list of their administrator privileges has changed @user_id Affected chat member user identifier @old_status Previous status of the chat member @new_status New status of the chat member
chatEventMemberPromoted user_id:int53 old_status:ChatMemberStatus new_status:ChatMemberStatus = ChatEventAction;

//@description A chat member was restricted/unrestricted or banned/unbanned, or the list of their restrictions has changed @member_id Affected chat member identifier @old_status Previous status of the chat member @new_status New status of the chat member
chatEventMemberRestricted member_id:MessageSender old_status:ChatMemberStatus new_status:ChatMemberStatus = ChatEventAction;

//@description A chat member extended their subscription to the chat @user_id Affected chat member user identifier @old_status Previous status of the chat member @new_status New status of the chat member
chatEventMemberSubscriptionExtended user_id:int53 old_status:ChatMemberStatus new_status:ChatMemberStatus = ChatEventAction;

//@description The chat available reactions were changed @old_available_reactions Previous chat available reactions @new_available_reactions New chat available reactions
chatEventAvailableReactionsChanged old_available_reactions:ChatAvailableReactions new_available_reactions:ChatAvailableReactions = ChatEventAction;

//@description The chat background was changed @old_background Previous background; may be null if none @new_background New background; may be null if none
chatEventBackgroundChanged old_background:chatBackground new_background:chatBackground = ChatEventAction;

//@description The chat description was changed @old_description Previous chat description @new_description New chat description
chatEventDescriptionChanged old_description:string new_description:string = ChatEventAction;

//@description The chat emoji status was changed @old_emoji_status Previous emoji status; may be null if none @new_emoji_status New emoji status; may be null if none
chatEventEmojiStatusChanged old_emoji_status:emojiStatus new_emoji_status:emojiStatus = ChatEventAction;

//@description The linked chat of a supergroup was changed @old_linked_chat_id Previous supergroup linked chat identifier @new_linked_chat_id New supergroup linked chat identifier
chatEventLinkedChatChanged old_linked_chat_id:int53 new_linked_chat_id:int53 = ChatEventAction;

//@description The supergroup location was changed @old_location Previous location; may be null @new_location New location; may be null
chatEventLocationChanged old_location:chatLocation new_location:chatLocation = ChatEventAction;

//@description The message auto-delete timer was changed @old_message_auto_delete_time Previous value of message_auto_delete_time @new_message_auto_delete_time New value of message_auto_delete_time
chatEventMessageAutoDeleteTimeChanged old_message_auto_delete_time:int32 new_message_auto_delete_time:int32 = ChatEventAction;

//@description The chat permissions were changed @old_permissions Previous chat permissions @new_permissions New chat permissions
chatEventPermissionsChanged old_permissions:chatPermissions new_permissions:chatPermissions = ChatEventAction;

//@description The chat photo was changed @old_photo Previous chat photo value; may be null @new_photo New chat photo value; may be null
chatEventPhotoChanged old_photo:chatPhoto new_photo:chatPhoto = ChatEventAction;

//@description The slow_mode_delay setting of a supergroup was changed @old_slow_mode_delay Previous value of slow_mode_delay, in seconds @new_slow_mode_delay New value of slow_mode_delay, in seconds
chatEventSlowModeDelayChanged old_slow_mode_delay:int32 new_slow_mode_delay:int32 = ChatEventAction;

//@description The supergroup sticker set was changed @old_sticker_set_id Previous identifier of the chat sticker set; 0 if none @new_sticker_set_id New identifier of the chat sticker set; 0 if none
chatEventStickerSetChanged old_sticker_set_id:int64 new_sticker_set_id:int64 = ChatEventAction;

//@description The supergroup sticker set with allowed custom emoji was changed @old_sticker_set_id Previous identifier of the chat sticker set; 0 if none @new_sticker_set_id New identifier of the chat sticker set; 0 if none
chatEventCustomEmojiStickerSetChanged old_sticker_set_id:int64 new_sticker_set_id:int64 = ChatEventAction;

//@description The chat title was changed @old_title Previous chat title @new_title New chat title
chatEventTitleChanged old_title:string new_title:string = ChatEventAction;

//@description The chat editable username was changed @old_username Previous chat username @new_username New chat username
chatEventUsernameChanged old_username:string new_username:string = ChatEventAction;

//@description The chat active usernames were changed @old_usernames Previous list of active usernames @new_usernames New list of active usernames
chatEventActiveUsernamesChanged old_usernames:vector<string> new_usernames:vector<string> = ChatEventAction;

//@description The chat accent color or background custom emoji were changed
//@old_accent_color_id Previous identifier of chat accent color
//@old_background_custom_emoji_id Previous identifier of the custom emoji; 0 if none
//@new_accent_color_id New identifier of chat accent color
//@new_background_custom_emoji_id New identifier of the custom emoji; 0 if none
chatEventAccentColorChanged old_accent_color_id:int32 old_background_custom_emoji_id:int64 new_accent_color_id:int32 new_background_custom_emoji_id:int64 = ChatEventAction;

//@description The chat's profile accent color or profile background custom emoji were changed
//@old_profile_accent_color_id Previous identifier of chat's profile accent color; -1 if none
//@old_profile_background_custom_emoji_id Previous identifier of the custom emoji; 0 if none
//@new_profile_accent_color_id New identifier of chat's profile accent color; -1 if none
//@new_profile_background_custom_emoji_id New identifier of the custom emoji; 0 if none
chatEventProfileAccentColorChanged old_profile_accent_color_id:int32 old_profile_background_custom_emoji_id:int64 new_profile_accent_color_id:int32 new_profile_background_custom_emoji_id:int64 = ChatEventAction;

//@description The has_protected_content setting of a channel was toggled @has_protected_content New value of has_protected_content
chatEventHasProtectedContentToggled has_protected_content:Bool = ChatEventAction;

//@description The can_invite_users permission of a supergroup chat was toggled @can_invite_users New value of can_invite_users permission
chatEventInvitesToggled can_invite_users:Bool = ChatEventAction;

//@description The is_all_history_available setting of a supergroup was toggled @is_all_history_available New value of is_all_history_available
chatEventIsAllHistoryAvailableToggled is_all_history_available:Bool = ChatEventAction;

//@description The has_aggressive_anti_spam_enabled setting of a supergroup was toggled @has_aggressive_anti_spam_enabled New value of has_aggressive_anti_spam_enabled
chatEventHasAggressiveAntiSpamEnabledToggled has_aggressive_anti_spam_enabled:Bool = ChatEventAction;

//@description The sign_messages setting of a channel was toggled @sign_messages New value of sign_messages
chatEventSignMessagesToggled sign_messages:Bool = ChatEventAction;

//@description The show_message_sender setting of a channel was toggled @show_message_sender New value of show_message_sender
chatEventShowMessageSenderToggled show_message_sender:Bool = ChatEventAction;

//@description A chat invite link was edited @old_invite_link Previous information about the invite link @new_invite_link New information about the invite link
chatEventInviteLinkEdited old_invite_link:chatInviteLink new_invite_link:chatInviteLink = ChatEventAction;

//@description A chat invite link was revoked @invite_link The invite link
chatEventInviteLinkRevoked invite_link:chatInviteLink = ChatEventAction;

//@description A revoked chat invite link was deleted @invite_link The invite link
chatEventInviteLinkDeleted invite_link:chatInviteLink = ChatEventAction;

//@description A video chat was created @group_call_id Identifier of the video chat. The video chat can be received through the method getGroupCall
chatEventVideoChatCreated group_call_id:int32 = ChatEventAction;

//@description A video chat was ended @group_call_id Identifier of the video chat. The video chat can be received through the method getGroupCall
chatEventVideoChatEnded group_call_id:int32 = ChatEventAction;

//@description The mute_new_participants setting of a video chat was toggled @mute_new_participants New value of the mute_new_participants setting
chatEventVideoChatMuteNewParticipantsToggled mute_new_participants:Bool = ChatEventAction;

//@description A video chat participant was muted or unmuted @participant_id Identifier of the affected group call participant @is_muted New value of is_muted
chatEventVideoChatParticipantIsMutedToggled participant_id:MessageSender is_muted:Bool = ChatEventAction;

//@description A video chat participant volume level was changed @participant_id Identifier of the affected group call participant @volume_level New value of volume_level; 1-20000 in hundreds of percents
chatEventVideoChatParticipantVolumeLevelChanged participant_id:MessageSender volume_level:int32 = ChatEventAction;

//@description The is_forum setting of a channel was toggled @is_forum New value of is_forum
chatEventIsForumToggled is_forum:Bool = ChatEventAction;

//@description A new forum topic was created @topic_info Information about the topic
chatEventForumTopicCreated topic_info:forumTopicInfo = ChatEventAction;

//@description A forum topic was edited @old_topic_info Old information about the topic @new_topic_info New information about the topic
chatEventForumTopicEdited old_topic_info:forumTopicInfo new_topic_info:forumTopicInfo = ChatEventAction;

//@description A forum topic was closed or reopened @topic_info New information about the topic
chatEventForumTopicToggleIsClosed topic_info:forumTopicInfo = ChatEventAction;

//@description The General forum topic was hidden or unhidden @topic_info New information about the topic
chatEventForumTopicToggleIsHidden topic_info:forumTopicInfo = ChatEventAction;

//@description A forum topic was deleted @topic_info Information about the topic
chatEventForumTopicDeleted topic_info:forumTopicInfo = ChatEventAction;

//@description A pinned forum topic was changed @old_topic_info Information about the old pinned topic; may be null @new_topic_info Information about the new pinned topic; may be null
chatEventForumTopicPinned old_topic_info:forumTopicInfo new_topic_info:forumTopicInfo = ChatEventAction;

//@description Represents a chat event
//@id Chat event identifier
//@date Point in time (Unix timestamp) when the event happened
//@member_id Identifier of the user or chat who performed the action
//@action The action
chatEvent id:int64 date:int32 member_id:MessageSender action:ChatEventAction = ChatEvent;

//@description Contains a list of chat events @events List of events
chatEvents events:vector<chatEvent> = ChatEvents;

//@description Represents a set of filters used to obtain a chat event log
//@message_edits True, if message edits need to be returned
//@message_deletions True, if message deletions need to be returned
//@message_pins True, if pin/unpin events need to be returned
//@member_joins True, if members joining events need to be returned
//@member_leaves True, if members leaving events need to be returned
//@member_invites True, if invited member events need to be returned
//@member_promotions True, if member promotion/demotion events need to be returned
//@member_restrictions True, if member restricted/unrestricted/banned/unbanned events need to be returned
//@info_changes True, if changes in chat information need to be returned
//@setting_changes True, if changes in chat settings need to be returned
//@invite_link_changes True, if changes to invite links need to be returned
//@video_chat_changes True, if video chat actions need to be returned
//@forum_changes True, if forum-related actions need to be returned
//@subscription_extensions True, if subscription extensions need to be returned
chatEventLogFilters message_edits:Bool message_deletions:Bool message_pins:Bool member_joins:Bool member_leaves:Bool member_invites:Bool member_promotions:Bool member_restrictions:Bool info_changes:Bool setting_changes:Bool invite_link_changes:Bool video_chat_changes:Bool forum_changes:Bool subscription_extensions:Bool = ChatEventLogFilters;


//@class LanguagePackStringValue @description Represents the value of a string in a language pack

//@description An ordinary language pack string @value String value
languagePackStringValueOrdinary value:string = LanguagePackStringValue;

//@description A language pack string which has different forms based on the number of some object it mentions. See https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html for more information
//@zero_value Value for zero objects
//@one_value Value for one object
//@two_value Value for two objects
//@few_value Value for few objects
//@many_value Value for many objects
//@other_value Default value
languagePackStringValuePluralized zero_value:string one_value:string two_value:string few_value:string many_value:string other_value:string = LanguagePackStringValue;

//@description A deleted language pack string, the value must be taken from the built-in English language pack
languagePackStringValueDeleted = LanguagePackStringValue;


//@description Represents one language pack string @key String key @value String value; pass null if the string needs to be taken from the built-in English language pack
languagePackString key:string value:LanguagePackStringValue = LanguagePackString;

//@description Contains a list of language pack strings @strings A list of language pack strings
languagePackStrings strings:vector<languagePackString> = LanguagePackStrings;

//@description Contains information about a language pack
//@id Unique language pack identifier
//@base_language_pack_id Identifier of a base language pack; may be empty. If a string is missed in the language pack, then it must be fetched from base language pack. Unsupported in custom language packs
//@name Language name
//@native_name Name of the language in that language
//@plural_code A language code to be used to apply plural forms. See https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html for more information
//@is_official True, if the language pack is official
//@is_rtl True, if the language pack strings are RTL
//@is_beta True, if the language pack is a beta language pack
//@is_installed True, if the language pack is installed by the current user
//@total_string_count Total number of non-deleted strings from the language pack
//@translated_string_count Total number of translated strings from the language pack
//@local_string_count Total number of non-deleted strings from the language pack available locally
//@translation_url Link to language translation interface; empty for custom local language packs
languagePackInfo id:string base_language_pack_id:string name:string native_name:string plural_code:string is_official:Bool is_rtl:Bool is_beta:Bool is_installed:Bool total_string_count:int32 translated_string_count:int32 local_string_count:int32 translation_url:string = LanguagePackInfo;

//@description Contains information about the current localization target @language_packs List of available language packs for this application
localizationTargetInfo language_packs:vector<languagePackInfo> = LocalizationTargetInfo;


//@class PremiumLimitType @description Describes type of limit, increased for Premium users

//@description The maximum number of joined supergroups and channels
premiumLimitTypeSupergroupCount = PremiumLimitType;

//@description The maximum number of pinned chats in the main chat list
premiumLimitTypePinnedChatCount = PremiumLimitType;

//@description The maximum number of created public chats
premiumLimitTypeCreatedPublicChatCount = PremiumLimitType;

//@description The maximum number of saved animations
premiumLimitTypeSavedAnimationCount = PremiumLimitType;

//@description The maximum number of favorite stickers
premiumLimitTypeFavoriteStickerCount = PremiumLimitType;

//@description The maximum number of chat folders
premiumLimitTypeChatFolderCount = PremiumLimitType;

//@description The maximum number of pinned and always included, or always excluded chats in a chat folder
premiumLimitTypeChatFolderChosenChatCount = PremiumLimitType;

//@description The maximum number of pinned chats in the archive chat list
premiumLimitTypePinnedArchivedChatCount = PremiumLimitType;

//@description The maximum number of pinned Saved Messages topics
premiumLimitTypePinnedSavedMessagesTopicCount = PremiumLimitType;

//@description The maximum length of sent media caption
premiumLimitTypeCaptionLength = PremiumLimitType;

//@description The maximum length of the user's bio
premiumLimitTypeBioLength = PremiumLimitType;

//@description The maximum number of invite links for a chat folder
premiumLimitTypeChatFolderInviteLinkCount = PremiumLimitType;

//@description The maximum number of added shareable chat folders
premiumLimitTypeShareableChatFolderCount = PremiumLimitType;

//@description The maximum number of active stories
premiumLimitTypeActiveStoryCount = PremiumLimitType;

//@description The maximum number of stories sent per week
premiumLimitTypeWeeklySentStoryCount = PremiumLimitType;

//@description The maximum number of stories sent per month
premiumLimitTypeMonthlySentStoryCount = PremiumLimitType;

//@description The maximum length of captions of sent stories
premiumLimitTypeStoryCaptionLength = PremiumLimitType;

//@description The maximum number of suggested reaction areas on a story
premiumLimitTypeStorySuggestedReactionAreaCount = PremiumLimitType;

//@description The maximum number of received similar chats
premiumLimitTypeSimilarChatCount = PremiumLimitType;


//@class PremiumFeature @description Describes a feature available to Premium users

//@description Increased limits
premiumFeatureIncreasedLimits = PremiumFeature;

//@description Increased maximum upload file size
premiumFeatureIncreasedUploadFileSize = PremiumFeature;

//@description Improved download speed
premiumFeatureImprovedDownloadSpeed = PremiumFeature;

//@description The ability to convert voice notes to text
premiumFeatureVoiceRecognition = PremiumFeature;

//@description Disabled ads
premiumFeatureDisabledAds = PremiumFeature;

//@description Allowed to use more reactions
premiumFeatureUniqueReactions = PremiumFeature;

//@description Allowed to use premium stickers with unique effects
premiumFeatureUniqueStickers = PremiumFeature;

//@description Allowed to use custom emoji stickers in message texts and captions
premiumFeatureCustomEmoji = PremiumFeature;

//@description Ability to change position of the main chat list, archive and mute all new chats from non-contacts, and completely disable notifications about the user's contacts joined Telegram
premiumFeatureAdvancedChatManagement = PremiumFeature;

//@description A badge in the user's profile
premiumFeatureProfileBadge = PremiumFeature;

//@description The ability to show an emoji status along with the user's name
premiumFeatureEmojiStatus = PremiumFeature;

//@description Profile photo animation on message and chat screens
premiumFeatureAnimatedProfilePhoto = PremiumFeature;

//@description The ability to set a custom emoji as a forum topic icon
premiumFeatureForumTopicIcon = PremiumFeature;

//@description Allowed to set a premium application icons
premiumFeatureAppIcons = PremiumFeature;

//@description Allowed to translate chat messages real-time
premiumFeatureRealTimeChatTranslation = PremiumFeature;

//@description Allowed to use many additional features for stories
premiumFeatureUpgradedStories = PremiumFeature;

//@description The ability to boost chats
premiumFeatureChatBoost = PremiumFeature;

//@description The ability to choose accent color for replies and user profile
premiumFeatureAccentColor = PremiumFeature;

//@description The ability to set private chat background for both users
premiumFeatureBackgroundForBoth = PremiumFeature;

//@description The ability to use tags in Saved Messages
premiumFeatureSavedMessagesTags = PremiumFeature;

//@description The ability to disallow incoming voice and video note messages in private chats using setUserPrivacySettingRules with userPrivacySettingAllowPrivateVoiceAndVideoNoteMessages
//-and to restrict incoming messages from non-contacts using setNewChatPrivacySettings
premiumFeatureMessagePrivacy = PremiumFeature;

//@description The ability to view last seen and read times of other users even they can't view last seen or read time for the current user
premiumFeatureLastSeenTimes = PremiumFeature;

//@description The ability to use Business features
premiumFeatureBusiness = PremiumFeature;

//@description The ability to use all available message effects
premiumFeatureMessageEffects = PremiumFeature;


//@class BusinessFeature @description Describes a feature available to Business user accounts

//@description The ability to set location
businessFeatureLocation = BusinessFeature;

//@description The ability to set opening hours
businessFeatureOpeningHours = BusinessFeature;

//@description The ability to use quick replies
businessFeatureQuickReplies = BusinessFeature;

//@description The ability to set up a greeting message
businessFeatureGreetingMessage = BusinessFeature;

//@description The ability to set up an away message
businessFeatureAwayMessage = BusinessFeature;

//@description The ability to create links to the business account with predefined message text
businessFeatureAccountLinks = BusinessFeature;

//@description The ability to customize start page
businessFeatureStartPage = BusinessFeature;

//@description The ability to connect a bot to the account
businessFeatureBots = BusinessFeature;

//@description The ability to show an emoji status along with the business name
businessFeatureEmojiStatus = BusinessFeature;

//@description The ability to display folder names for each chat in the chat list
businessFeatureChatFolderTags = BusinessFeature;

//@description Allowed to use many additional features for stories
businessFeatureUpgradedStories = BusinessFeature;


//@class PremiumStoryFeature @description Describes a story feature available to Premium users

//@description Stories of the current user are displayed before stories of non-Premium contacts, supergroups, and channels
premiumStoryFeaturePriorityOrder = PremiumStoryFeature;

//@description The ability to hide the fact that the user viewed other's stories
premiumStoryFeatureStealthMode = PremiumStoryFeature;

//@description The ability to check who opened the current user's stories after they expire
premiumStoryFeaturePermanentViewsHistory = PremiumStoryFeature;

//@description The ability to set custom expiration duration for stories
premiumStoryFeatureCustomExpirationDuration = PremiumStoryFeature;

//@description The ability to save other's unprotected stories
premiumStoryFeatureSaveStories = PremiumStoryFeature;

//@description The ability to use links and formatting in story caption, and use inputStoryAreaTypeLink areas
premiumStoryFeatureLinksAndFormatting = PremiumStoryFeature;

//@description The ability to choose better quality for viewed stories
premiumStoryFeatureVideoQuality = PremiumStoryFeature;


//@description Contains information about a limit, increased for Premium users @type The type of the limit @default_value Default value of the limit @premium_value Value of the limit for Premium users
premiumLimit type:PremiumLimitType default_value:int32 premium_value:int32 = PremiumLimit;

//@description Contains information about features, available to Premium users
//@features The list of available features
//@limits The list of limits, increased for Premium users
//@payment_link An internal link to be opened to pay for Telegram Premium if store payment isn't possible; may be null if direct payment isn't available
premiumFeatures features:vector<PremiumFeature> limits:vector<premiumLimit> payment_link:InternalLinkType = PremiumFeatures;

//@description Contains information about features, available to Business user accounts @features The list of available business features
businessFeatures features:vector<BusinessFeature> = BusinessFeatures;


//@class PremiumSource @description Describes a source from which the Premium features screen is opened

//@description A limit was exceeded @limit_type Type of the exceeded limit
premiumSourceLimitExceeded limit_type:PremiumLimitType = PremiumSource;

//@description A user tried to use a Premium feature @feature The used feature
premiumSourceFeature feature:PremiumFeature = PremiumSource;

//@description A user tried to use a Business feature @feature The used feature; pass null if none specific feature was used
premiumSourceBusinessFeature feature:BusinessFeature = PremiumSource;

//@description A user tried to use a Premium story feature @feature The used feature
premiumSourceStoryFeature feature:PremiumStoryFeature = PremiumSource;

//@description A user opened an internal link of the type internalLinkTypePremiumFeatures @referrer The referrer from the link
premiumSourceLink referrer:string = PremiumSource;

//@description A user opened the Premium features screen from settings
premiumSourceSettings = PremiumSource;


//@description Describes a promotion animation for a Premium feature @feature Premium feature @animation Promotion animation for the feature
premiumFeaturePromotionAnimation feature:PremiumFeature animation:animation = PremiumFeaturePromotionAnimation;

//@description Describes a promotion animation for a Business feature @feature Business feature @animation Promotion animation for the feature
businessFeaturePromotionAnimation feature:BusinessFeature animation:animation = BusinessFeaturePromotionAnimation;

//@description Contains state of Telegram Premium subscription and promotion videos for Premium features
//@state Text description of the state of the current Premium subscription; may be empty if the current user has no Telegram Premium subscription
//@payment_options The list of available options for buying Telegram Premium
//@animations The list of available promotion animations for Premium features
//@business_animations The list of available promotion animations for Business features
premiumState state:formattedText payment_options:vector<premiumStatePaymentOption> animations:vector<premiumFeaturePromotionAnimation> business_animations:vector<businessFeaturePromotionAnimation> = PremiumState;


//@class StorePaymentPurpose @description Describes a purpose of an in-store payment

//@description The user subscribing to Telegram Premium @is_restore Pass true if this is a restore of a Telegram Premium purchase; only for App Store @is_upgrade Pass true if this is an upgrade from a monthly subscription to early subscription; only for App Store
storePaymentPurposePremiumSubscription is_restore:Bool is_upgrade:Bool = StorePaymentPurpose;

//@description The user gifting Telegram Premium to another user
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@user_id Identifiers of the user which will receive Telegram Premium
//@text Text to show along with the gift codes; 0-getOption("gift_text_length_max") characters. Only Bold, Italic, Underline, Strikethrough, Spoiler, and CustomEmoji entities are allowed
storePaymentPurposePremiumGift currency:string amount:int53 user_id:int53 text:formattedText = StorePaymentPurpose;

//@description The user boosting a chat by creating Telegram Premium gift codes for other users
//@boosted_chat_id Identifier of the supergroup or channel chat, which will be automatically boosted by the users for duration of the Premium subscription and which is administered by the user
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@user_ids Identifiers of the users which can activate the gift codes
//@text Text to show along with the gift codes; 0-getOption("gift_text_length_max") characters. Only Bold, Italic, Underline, Strikethrough, Spoiler, and CustomEmoji entities are allowed
storePaymentPurposePremiumGiftCodes boosted_chat_id:int53 currency:string amount:int53 user_ids:vector<int53> text:formattedText = StorePaymentPurpose;

//@description The user creating a Telegram Premium giveaway
//@parameters Giveaway parameters
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
storePaymentPurposePremiumGiveaway parameters:giveawayParameters currency:string amount:int53 = StorePaymentPurpose;

//@description The user creating a Telegram Star giveaway
//@parameters Giveaway parameters
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@winner_count The number of users to receive Telegram Stars
//@star_count The number of Telegram Stars to be distributed through the giveaway
storePaymentPurposeStarGiveaway parameters:giveawayParameters currency:string amount:int53 winner_count:int32 star_count:int53 = StorePaymentPurpose;

//@description The user buying Telegram Stars
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@star_count Number of bought Telegram Stars
storePaymentPurposeStars currency:string amount:int53 star_count:int53 = StorePaymentPurpose;

//@description The user buying Telegram Stars for other users
//@user_id Identifier of the user to which Telegram Stars are gifted
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@star_count Number of bought Telegram Stars
storePaymentPurposeGiftedStars user_id:int53 currency:string amount:int53 star_count:int53 = StorePaymentPurpose;


//@class TelegramPaymentPurpose @description Describes a purpose of a payment toward Telegram

//@description The user gifting Telegram Premium to another user
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@user_id Identifier of the user which will receive Telegram Premium
//@month_count Number of months the Telegram Premium subscription will be active for the user
//@text Text to show to the user receiving Telegram Premium; 0-getOption("gift_text_length_max") characters. Only Bold, Italic, Underline, Strikethrough, Spoiler, and CustomEmoji entities are allowed
telegramPaymentPurposePremiumGift currency:string amount:int53 user_id:int53 month_count:int32 text:formattedText = TelegramPaymentPurpose;

//@description The user boosting a chat by creating Telegram Premium gift codes for other users
//@boosted_chat_id Identifier of the supergroup or channel chat, which will be automatically boosted by the users for duration of the Premium subscription and which is administered by the user
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@user_ids Identifiers of the users which can activate the gift codes
//@month_count Number of months the Telegram Premium subscription will be active for the users
//@text Text to show along with the gift codes; 0-getOption("gift_text_length_max") characters. Only Bold, Italic, Underline, Strikethrough, Spoiler, and CustomEmoji entities are allowed
telegramPaymentPurposePremiumGiftCodes boosted_chat_id:int53 currency:string amount:int53 user_ids:vector<int53> month_count:int32 text:formattedText = TelegramPaymentPurpose;

//@description The user creating a Telegram Premium giveaway
//@parameters Giveaway parameters
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@winner_count Number of users which will be able to activate the gift codes
//@month_count Number of months the Telegram Premium subscription will be active for the users
telegramPaymentPurposePremiumGiveaway parameters:giveawayParameters currency:string amount:int53 winner_count:int32 month_count:int32 = TelegramPaymentPurpose;

//@description The user buying Telegram Stars
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@star_count Number of bought Telegram Stars
telegramPaymentPurposeStars currency:string amount:int53 star_count:int53 = TelegramPaymentPurpose;

//@description The user buying Telegram Stars for other users
//@user_id Identifier of the user to which Telegram Stars are gifted
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@star_count Number of bought Telegram Stars
telegramPaymentPurposeGiftedStars user_id:int53 currency:string amount:int53 star_count:int53 = TelegramPaymentPurpose;

//@description The user creating a Telegram Star giveaway
//@parameters Giveaway parameters
//@currency ISO 4217 currency code of the payment currency
//@amount Paid amount, in the smallest units of the currency
//@winner_count The number of users to receive Telegram Stars
//@star_count The number of Telegram Stars to be distributed through the giveaway
telegramPaymentPurposeStarGiveaway parameters:giveawayParameters currency:string amount:int53 winner_count:int32 star_count:int53 = TelegramPaymentPurpose;

//@description The user joins a chat and subscribes to regular payments in Telegram Stars @invite_link Invite link to use
telegramPaymentPurposeJoinChat invite_link:string = TelegramPaymentPurpose;


//@class DeviceToken @description Represents a data needed to subscribe for push notifications through registerDevice method.
//-To use specific push notification service, the correct application platform must be specified and a valid server authentication data must be uploaded at https://my.telegram.org

//@description A token for Firebase Cloud Messaging @token Device registration token; may be empty to deregister a device @encrypt True, if push notifications must be additionally encrypted
deviceTokenFirebaseCloudMessaging token:string encrypt:Bool = DeviceToken;

//@description A token for Apple Push Notification service @device_token Device token; may be empty to deregister a device @is_app_sandbox True, if App Sandbox is enabled
deviceTokenApplePush device_token:string is_app_sandbox:Bool = DeviceToken;

//@description A token for Apple Push Notification service VoIP notifications @device_token Device token; may be empty to deregister a device @is_app_sandbox True, if App Sandbox is enabled @encrypt True, if push notifications must be additionally encrypted
deviceTokenApplePushVoIP device_token:string is_app_sandbox:Bool encrypt:Bool = DeviceToken;

//@description A token for Windows Push Notification Services @access_token The access token that will be used to send notifications; may be empty to deregister a device
deviceTokenWindowsPush access_token:string = DeviceToken;

//@description A token for Microsoft Push Notification Service @channel_uri Push notification channel URI; may be empty to deregister a device
deviceTokenMicrosoftPush channel_uri:string = DeviceToken;

//@description A token for Microsoft Push Notification Service VoIP channel @channel_uri Push notification channel URI; may be empty to deregister a device
deviceTokenMicrosoftPushVoIP channel_uri:string = DeviceToken;

//@description A token for web Push API
//@endpoint Absolute URL exposed by the push service where the application server can send push messages; may be empty to deregister a device
//@p256dh_base64url Base64url-encoded P-256 elliptic curve Diffie-Hellman public key
//@auth_base64url Base64url-encoded authentication secret
deviceTokenWebPush endpoint:string p256dh_base64url:string auth_base64url:string = DeviceToken;

//@description A token for Simple Push API for Firefox OS @endpoint Absolute URL exposed by the push service where the application server can send push messages; may be empty to deregister a device
deviceTokenSimplePush endpoint:string = DeviceToken;

//@description A token for Ubuntu Push Client service @token Token; may be empty to deregister a device
deviceTokenUbuntuPush token:string = DeviceToken;

//@description A token for BlackBerry Push Service @token Token; may be empty to deregister a device
deviceTokenBlackBerryPush token:string = DeviceToken;

//@description A token for Tizen Push Service @reg_id Push service registration identifier; may be empty to deregister a device
deviceTokenTizenPush reg_id:string = DeviceToken;

//@description A token for HUAWEI Push Service @token Device registration token; may be empty to deregister a device @encrypt True, if push notifications must be additionally encrypted
deviceTokenHuaweiPush token:string encrypt:Bool = DeviceToken;


//@description Contains a globally unique push receiver identifier, which can be used to identify which account has received a push notification @id The globally unique identifier of push notification subscription
pushReceiverId id:int64 = PushReceiverId;


//@class BackgroundFill @description Describes a fill of a background

//@description Describes a solid fill of a background @color A color of the background in the RGB format
backgroundFillSolid color:int32 = BackgroundFill;

//@description Describes a gradient fill of a background
//@top_color A top color of the background in the RGB format
//@bottom_color A bottom color of the background in the RGB format
//@rotation_angle Clockwise rotation angle of the gradient, in degrees; 0-359. Must always be divisible by 45
backgroundFillGradient top_color:int32 bottom_color:int32 rotation_angle:int32 = BackgroundFill;

//@description Describes a freeform gradient fill of a background @colors A list of 3 or 4 colors of the freeform gradient in the RGB format
backgroundFillFreeformGradient colors:vector<int32> = BackgroundFill;


//@class BackgroundType @description Describes the type of background

//@description A wallpaper in JPEG format
//@is_blurred True, if the wallpaper must be downscaled to fit in 450x450 square and then box-blurred with radius 12
//@is_moving True, if the background needs to be slightly moved when device is tilted
backgroundTypeWallpaper is_blurred:Bool is_moving:Bool = BackgroundType;

//@description A PNG or TGV (gzipped subset of SVG with MIME type "application/x-tgwallpattern") pattern to be combined with the background fill chosen by the user
//@fill Fill of the background
//@intensity Intensity of the pattern when it is shown above the filled background; 0-100
//@is_inverted True, if the background fill must be applied only to the pattern itself. All other pixels are black in this case. For dark themes only
//@is_moving True, if the background needs to be slightly moved when device is tilted
backgroundTypePattern fill:BackgroundFill intensity:int32 is_inverted:Bool is_moving:Bool = BackgroundType;

//@description A filled background @fill The background fill
backgroundTypeFill fill:BackgroundFill = BackgroundType;

//@description A background from a chat theme; can be used only as a chat background in channels @theme_name Name of the chat theme
backgroundTypeChatTheme theme_name:string = BackgroundType;


//@class InputBackground @description Contains information about background to set

//@description A background from a local file
//@background Background file to use. Only inputFileLocal and inputFileGenerated are supported. The file must be in JPEG format for wallpapers and in PNG format for patterns
inputBackgroundLocal background:InputFile = InputBackground;

//@description A background from the server @background_id The background identifier
inputBackgroundRemote background_id:int64 = InputBackground;

//@description A background previously set in the chat; for chat backgrounds only @message_id Identifier of the message with the background
inputBackgroundPrevious message_id:int53 = InputBackground;


//@description Describes a chat theme
//@name Theme name
//@light_settings Theme settings for a light chat theme
//@dark_settings Theme settings for a dark chat theme
chatTheme name:string light_settings:themeSettings dark_settings:themeSettings = ChatTheme;


//@description Describes a time zone
//@id Unique time zone identifier
//@name Time zone name
//@utc_time_offset Current UTC time offset for the time zone
timeZone id:string name:string utc_time_offset:int32 = TimeZone;

//@description Contains a list of time zones @time_zones A list of time zones
timeZones time_zones:vector<timeZone> = TimeZones;


//@description Contains a list of hashtags @hashtags A list of hashtags
hashtags hashtags:vector<string> = Hashtags;


//@class CanSendStoryResult @description Represents result of checking whether the current user can send a story in the specific chat

//@description A story can be sent
canSendStoryResultOk = CanSendStoryResult;

//@description The user must subscribe to Telegram Premium to be able to post stories
canSendStoryResultPremiumNeeded = CanSendStoryResult;

//@description The chat must be boosted first by Telegram Premium subscribers to post more stories. Call getChatBoostStatus to get current boost status of the chat
canSendStoryResultBoostNeeded = CanSendStoryResult;

//@description The limit for the number of active stories exceeded. The user can buy Telegram Premium, delete an active story, or wait for the oldest story to expire
canSendStoryResultActiveStoryLimitExceeded = CanSendStoryResult;

//@description The weekly limit for the number of posted stories exceeded. The user needs to buy Telegram Premium or wait specified time @retry_after Time left before the user can send the next story
canSendStoryResultWeeklyLimitExceeded retry_after:int32 = CanSendStoryResult;

//@description The monthly limit for the number of posted stories exceeded. The user needs to buy Telegram Premium or wait specified time @retry_after Time left before the user can send the next story
canSendStoryResultMonthlyLimitExceeded retry_after:int32 = CanSendStoryResult;


//@class CanTransferOwnershipResult @description Represents result of checking whether the current session can be used to transfer a chat ownership to another user

//@description The session can be used
canTransferOwnershipResultOk = CanTransferOwnershipResult;

//@description The 2-step verification needs to be enabled first
canTransferOwnershipResultPasswordNeeded = CanTransferOwnershipResult;

//@description The 2-step verification was enabled recently, user needs to wait @retry_after Time left before the session can be used to transfer ownership of a chat, in seconds
canTransferOwnershipResultPasswordTooFresh retry_after:int32 = CanTransferOwnershipResult;

//@description The session was created recently, user needs to wait @retry_after Time left before the session can be used to transfer ownership of a chat, in seconds
canTransferOwnershipResultSessionTooFresh retry_after:int32 = CanTransferOwnershipResult;


//@class CheckChatUsernameResult @description Represents result of checking whether a username can be set for a chat

//@description The username can be set
checkChatUsernameResultOk = CheckChatUsernameResult;

//@description The username is invalid
checkChatUsernameResultUsernameInvalid = CheckChatUsernameResult;

//@description The username is occupied
checkChatUsernameResultUsernameOccupied = CheckChatUsernameResult;

//@description The username can be purchased at https://fragment.com. Information about the username can be received using getCollectibleItemInfo
checkChatUsernameResultUsernamePurchasable = CheckChatUsernameResult;

//@description The user has too many chats with username, one of them must be made private first
checkChatUsernameResultPublicChatsTooMany = CheckChatUsernameResult;

//@description The user can't be a member of a public supergroup
checkChatUsernameResultPublicGroupsUnavailable = CheckChatUsernameResult;


//@class CheckStickerSetNameResult @description Represents result of checking whether a name can be used for a new sticker set

//@description The name can be set
checkStickerSetNameResultOk = CheckStickerSetNameResult;

//@description The name is invalid
checkStickerSetNameResultNameInvalid = CheckStickerSetNameResult;

//@description The name is occupied
checkStickerSetNameResultNameOccupied = CheckStickerSetNameResult;


//@class ResetPasswordResult @description Represents result of 2-step verification password reset

//@description The password was reset
resetPasswordResultOk = ResetPasswordResult;

//@description The password reset request is pending @pending_reset_date Point in time (Unix timestamp) after which the password can be reset immediately using resetPassword
resetPasswordResultPending pending_reset_date:int32 = ResetPasswordResult;

//@description The password reset request was declined @retry_date Point in time (Unix timestamp) when the password reset can be retried
resetPasswordResultDeclined retry_date:int32 = ResetPasswordResult;


//@class MessageFileType @description Contains information about a file with messages exported from another app

//@description The messages were exported from a private chat @name Name of the other party; may be empty if unrecognized
messageFileTypePrivate name:string = MessageFileType;

//@description The messages were exported from a group chat @title Title of the group chat; may be empty if unrecognized
messageFileTypeGroup title:string = MessageFileType;

//@description The messages were exported from a chat of unknown type
messageFileTypeUnknown = MessageFileType;


//@class PushMessageContent @description Contains content of a push message notification

//@description A general message with hidden content @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentHidden is_pinned:Bool = PushMessageContent;

//@description An animation message (GIF-style). @animation Message content; may be null @caption Animation caption @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentAnimation animation:animation caption:string is_pinned:Bool = PushMessageContent;

//@description An audio message @audio Message content; may be null @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentAudio audio:audio is_pinned:Bool = PushMessageContent;

//@description A message with a user contact @name Contact's name @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentContact name:string is_pinned:Bool = PushMessageContent;

//@description A contact has registered with Telegram
pushMessageContentContactRegistered = PushMessageContent;

//@description A document message (a general file) @document Message content; may be null @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentDocument document:document is_pinned:Bool = PushMessageContent;

//@description A message with a game @title Game title, empty for pinned game message @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentGame title:string is_pinned:Bool = PushMessageContent;

//@description A new high score was achieved in a game @title Game title, empty for pinned message @score New score, 0 for pinned message @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentGameScore title:string score:int32 is_pinned:Bool = PushMessageContent;

//@description A message with an invoice from a bot @price Product price @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentInvoice price:string is_pinned:Bool = PushMessageContent;

//@description A message with a location @is_live True, if the location is live @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentLocation is_live:Bool is_pinned:Bool = PushMessageContent;

//@description A message with paid media
//@star_count Number of Telegram Stars needed to buy access to the media in the message; 0 for pinned message
//@is_pinned True, if the message is a pinned message with the specified content
pushMessageContentPaidMedia star_count:int53 is_pinned:Bool = PushMessageContent;

//@description A photo message
//@photo Message content; may be null
//@caption Photo caption
//@is_secret True, if the photo is secret
//@is_pinned True, if the message is a pinned message with the specified content
pushMessageContentPhoto photo:photo caption:string is_secret:Bool is_pinned:Bool = PushMessageContent;

//@description A message with a poll
//@question Poll question
//@is_regular True, if the poll is regular and not in quiz mode
//@is_pinned True, if the message is a pinned message with the specified content
pushMessageContentPoll question:string is_regular:Bool is_pinned:Bool = PushMessageContent;

//@description A message with a Telegram Premium gift code created for the user @month_count Number of months the Telegram Premium subscription will be active after code activation
pushMessageContentPremiumGiftCode month_count:int32 = PushMessageContent;

//@description A message with a giveaway
//@winner_count Number of users which will receive giveaway prizes; 0 for pinned message
//@prize Prize of the giveaway; may be null for pinned message
//@is_pinned True, if the message is a pinned message with the specified content
pushMessageContentGiveaway winner_count:int32 prize:GiveawayPrize is_pinned:Bool = PushMessageContent;

//@description A message with a gift @star_count Number of Telegram Stars that sender paid for the gift
pushMessageContentGift star_count:int53 = PushMessageContent;

//@description A message with an upgraded gift
//@is_upgrade True, if the gift was obtained by upgrading of a previously received gift; otherwise, this is a transferred gift
pushMessageContentUpgradedGift is_upgrade:Bool = PushMessageContent;

//@description A screenshot of a message in the chat has been taken
pushMessageContentScreenshotTaken = PushMessageContent;

//@description A message with a sticker
//@sticker Message content; may be null
//@emoji Emoji corresponding to the sticker; may be empty
//@is_pinned True, if the message is a pinned message with the specified content
pushMessageContentSticker sticker:sticker emoji:string is_pinned:Bool = PushMessageContent;

//@description A message with a story @is_mention True, if the user was mentioned in the story @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentStory is_mention:Bool is_pinned:Bool = PushMessageContent;

//@description A text message @text Message text @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentText text:string is_pinned:Bool = PushMessageContent;

//@description A video message
//@video Message content; may be null
//@caption Video caption
//@is_secret True, if the video is secret
//@is_pinned True, if the message is a pinned message with the specified content
pushMessageContentVideo video:video caption:string is_secret:Bool is_pinned:Bool = PushMessageContent;

//@description A video note message @video_note Message content; may be null @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentVideoNote video_note:videoNote is_pinned:Bool = PushMessageContent;

//@description A voice note message @voice_note Message content; may be null @is_pinned True, if the message is a pinned message with the specified content
pushMessageContentVoiceNote voice_note:voiceNote is_pinned:Bool = PushMessageContent;

//@description A newly created basic group
pushMessageContentBasicGroupChatCreate = PushMessageContent;

//@description A video chat or live stream was started
pushMessageContentVideoChatStarted = PushMessageContent;

//@description A video chat or live stream has ended
pushMessageContentVideoChatEnded = PushMessageContent;

//@description An invitation of participants to a video chat or live stream
//@is_current_user True, if the current user was invited to the video chat or the live stream
pushMessageContentInviteVideoChatParticipants is_current_user:Bool = PushMessageContent;

//@description New chat members were invited to a group
//@member_name Name of the added member
//@is_current_user True, if the current user was added to the group
//@is_returned True, if the user has returned to the group themselves
pushMessageContentChatAddMembers member_name:string is_current_user:Bool is_returned:Bool = PushMessageContent;

//@description A chat photo was edited
pushMessageContentChatChangePhoto = PushMessageContent;

//@description A chat title was edited @title New chat title
pushMessageContentChatChangeTitle title:string = PushMessageContent;

//@description A chat background was edited @is_same True, if the set background is the same as the background of the current user
pushMessageContentChatSetBackground is_same:Bool = PushMessageContent;

//@description A chat theme was edited @theme_name If non-empty, name of a new theme, set for the chat. Otherwise, the chat theme was reset to the default one
pushMessageContentChatSetTheme theme_name:string = PushMessageContent;

//@description A chat member was deleted
//@member_name Name of the deleted member
//@is_current_user True, if the current user was deleted from the group
//@is_left True, if the user has left the group themselves
pushMessageContentChatDeleteMember member_name:string is_current_user:Bool is_left:Bool = PushMessageContent;

//@description A new member joined the chat via an invite link
pushMessageContentChatJoinByLink = PushMessageContent;

//@description A new member was accepted to the chat by an administrator
pushMessageContentChatJoinByRequest = PushMessageContent;

//@description A new recurring payment was made by the current user @amount The paid amount
pushMessageContentRecurringPayment amount:string = PushMessageContent;

//@description A profile photo was suggested to the user
pushMessageContentSuggestProfilePhoto = PushMessageContent;

//@description A user in the chat came within proximity alert range from the current user @distance The distance to the user
pushMessageContentProximityAlertTriggered distance:int32 = PushMessageContent;

//@description A forwarded messages @total_count Number of forwarded messages
pushMessageContentMessageForwards total_count:int32 = PushMessageContent;

//@description A media album
//@total_count Number of messages in the album
//@has_photos True, if the album has at least one photo
//@has_videos True, if the album has at least one video file
//@has_audios True, if the album has at least one audio file
//@has_documents True, if the album has at least one document
pushMessageContentMediaAlbum total_count:int32 has_photos:Bool has_videos:Bool has_audios:Bool has_documents:Bool = PushMessageContent;


//@class NotificationType @description Contains detailed information about a notification

//@description New message was received @message The message @show_preview True, if message content must be displayed in notifications
notificationTypeNewMessage message:message show_preview:Bool = NotificationType;

//@description New secret chat was created
notificationTypeNewSecretChat = NotificationType;

//@description New call was received @call_id Call identifier
notificationTypeNewCall call_id:int32 = NotificationType;

//@description New message was received through a push notification
//@message_id The message identifier. The message will not be available in the chat history, but the identifier can be used in viewMessages, or as a message to be replied in the same chat
//@sender_id Identifier of the sender of the message. Corresponding user or chat may be inaccessible
//@sender_name Name of the sender
//@is_outgoing True, if the message is outgoing
//@content Push message content
notificationTypeNewPushMessage message_id:int53 sender_id:MessageSender sender_name:string is_outgoing:Bool content:PushMessageContent = NotificationType;


//@class NotificationGroupType @description Describes the type of notifications in a notification group

//@description A group containing notifications of type notificationTypeNewMessage and notificationTypeNewPushMessage with ordinary unread messages
notificationGroupTypeMessages = NotificationGroupType;

//@description A group containing notifications of type notificationTypeNewMessage and notificationTypeNewPushMessage with unread mentions of the current user, replies to their messages, or a pinned message
notificationGroupTypeMentions = NotificationGroupType;

//@description A group containing a notification of type notificationTypeNewSecretChat
notificationGroupTypeSecretChat = NotificationGroupType;

//@description A group containing notifications of type notificationTypeNewCall
notificationGroupTypeCalls = NotificationGroupType;


//@description Describes a notification sound in MP3 format
//@id Unique identifier of the notification sound
//@duration Duration of the sound, in seconds
//@date Point in time (Unix timestamp) when the sound was created
//@title Title of the notification sound
//@data Arbitrary data, defined while the sound was uploaded
//@sound File containing the sound
notificationSound id:int64 duration:int32 date:int32 title:string data:string sound:file = NotificationSound;

//@description Contains a list of notification sounds @notification_sounds A list of notification sounds
notificationSounds notification_sounds:vector<notificationSound> = NotificationSounds;


//@description Contains information about a notification
//@id Unique persistent identifier of this notification
//@date Notification date
//@is_silent True, if the notification was explicitly sent without sound
//@type Notification type
notification id:int32 date:int32 is_silent:Bool type:NotificationType = Notification;

//@description Describes a group of notifications
//@id Unique persistent auto-incremented from 1 identifier of the notification group
//@type Type of the group
//@chat_id Identifier of a chat to which all notifications in the group belong
//@total_count Total number of active notifications in the group
//@notifications The list of active notifications
notificationGroup id:int32 type:NotificationGroupType chat_id:int53 total_count:int32 notifications:vector<notification> = NotificationGroup;


//@class OptionValue @description Represents the value of an option

//@description Represents a boolean option @value The value of the option
optionValueBoolean value:Bool = OptionValue;

//@description Represents an unknown option or an option which has a default value
optionValueEmpty = OptionValue;

//@description Represents an integer option @value The value of the option
optionValueInteger value:int64 = OptionValue;

//@description Represents a string option @value The value of the option
optionValueString value:string = OptionValue;


//@description Represents one member of a JSON object @key Member's key @value Member's value
jsonObjectMember key:string value:JsonValue = JsonObjectMember;

//@class JsonValue @description Represents a JSON value

//@description Represents a null JSON value
jsonValueNull = JsonValue;

//@description Represents a boolean JSON value @value The value
jsonValueBoolean value:Bool = JsonValue;

//@description Represents a numeric JSON value @value The value
jsonValueNumber value:double = JsonValue;

//@description Represents a string JSON value @value The value
jsonValueString value:string = JsonValue;

//@description Represents a JSON array @values The list of array elements
jsonValueArray values:vector<JsonValue> = JsonValue;

//@description Represents a JSON object @members The list of object members
jsonValueObject members:vector<jsonObjectMember> = JsonValue;


//@class StoryPrivacySettings @description Describes privacy settings of a story

//@description The story can be viewed by everyone @except_user_ids Identifiers of the users that can't see the story; always unknown and empty for non-owned stories
storyPrivacySettingsEveryone except_user_ids:vector<int53> = StoryPrivacySettings;

//@description The story can be viewed by all contacts except chosen users @except_user_ids User identifiers of the contacts that can't see the story; always unknown and empty for non-owned stories
storyPrivacySettingsContacts except_user_ids:vector<int53> = StoryPrivacySettings;

//@description The story can be viewed by all close friends
storyPrivacySettingsCloseFriends = StoryPrivacySettings;

//@description The story can be viewed by certain specified users @user_ids Identifiers of the users; always unknown and empty for non-owned stories
storyPrivacySettingsSelectedUsers user_ids:vector<int53> = StoryPrivacySettings;


//@class UserPrivacySettingRule @description Represents a single rule for managing user privacy settings

//@description A rule to allow all users to do something
userPrivacySettingRuleAllowAll = UserPrivacySettingRule;

//@description A rule to allow all contacts of the user to do something
userPrivacySettingRuleAllowContacts = UserPrivacySettingRule;

//@description A rule to allow all bots to do something
userPrivacySettingRuleAllowBots = UserPrivacySettingRule;

//@description A rule to allow all Premium Users to do something; currently, allowed only for userPrivacySettingAllowChatInvites
userPrivacySettingRuleAllowPremiumUsers = UserPrivacySettingRule;

//@description A rule to allow certain specified users to do something @user_ids The user identifiers, total number of users in all rules must not exceed 1000
userPrivacySettingRuleAllowUsers user_ids:vector<int53> = UserPrivacySettingRule;

//@description A rule to allow all members of certain specified basic groups and supergroups to doing something @chat_ids The chat identifiers, total number of chats in all rules must not exceed 20
userPrivacySettingRuleAllowChatMembers chat_ids:vector<int53> = UserPrivacySettingRule;

//@description A rule to restrict all users from doing something
userPrivacySettingRuleRestrictAll = UserPrivacySettingRule;

//@description A rule to restrict all contacts of the user from doing something
userPrivacySettingRuleRestrictContacts = UserPrivacySettingRule;

//@description A rule to restrict all bots from doing something
userPrivacySettingRuleRestrictBots = UserPrivacySettingRule;

//@description A rule to restrict all specified users from doing something @user_ids The user identifiers, total number of users in all rules must not exceed 1000
userPrivacySettingRuleRestrictUsers user_ids:vector<int53> = UserPrivacySettingRule;

//@description A rule to restrict all members of specified basic groups and supergroups from doing something @chat_ids The chat identifiers, total number of chats in all rules must not exceed 20
userPrivacySettingRuleRestrictChatMembers chat_ids:vector<int53> = UserPrivacySettingRule;

//@description A list of privacy rules. Rules are matched in the specified order. The first matched rule defines the privacy setting for a given user. If no rule matches, the action is not allowed @rules A list of rules
userPrivacySettingRules rules:vector<UserPrivacySettingRule> = UserPrivacySettingRules;


//@class UserPrivacySetting @description Describes available user privacy settings

//@description A privacy setting for managing whether the user's online status is visible
userPrivacySettingShowStatus = UserPrivacySetting;

//@description A privacy setting for managing whether the user's profile photo is visible
userPrivacySettingShowProfilePhoto = UserPrivacySetting;

//@description A privacy setting for managing whether a link to the user's account is included in forwarded messages
userPrivacySettingShowLinkInForwardedMessages = UserPrivacySetting;

//@description A privacy setting for managing whether the user's phone number is visible
userPrivacySettingShowPhoneNumber = UserPrivacySetting;

//@description A privacy setting for managing whether the user's bio is visible
userPrivacySettingShowBio = UserPrivacySetting;

//@description A privacy setting for managing whether the user's birthdate is visible
userPrivacySettingShowBirthdate = UserPrivacySetting;

//@description A privacy setting for managing whether the user can be invited to chats
userPrivacySettingAllowChatInvites = UserPrivacySetting;

//@description A privacy setting for managing whether the user can be called
userPrivacySettingAllowCalls = UserPrivacySetting;

//@description A privacy setting for managing whether peer-to-peer connections can be used for calls
userPrivacySettingAllowPeerToPeerCalls = UserPrivacySetting;

//@description A privacy setting for managing whether the user can be found by their phone number. Checked only if the phone number is not known to the other user. Can be set only to "Allow contacts" or "Allow all"
userPrivacySettingAllowFindingByPhoneNumber = UserPrivacySetting;

//@description A privacy setting for managing whether the user can receive voice and video messages in private chats; for Telegram Premium users only
userPrivacySettingAllowPrivateVoiceAndVideoNoteMessages = UserPrivacySetting;

//@description A privacy setting for managing whether received gifts are automatically shown on the user's profile page
userPrivacySettingAutosaveGifts = UserPrivacySetting;

//@description A privacy setting for managing whether the user can receive messages without additional payment
userPrivacySettingAllowUnpaidMessages = UserPrivacySetting;


//@description Contains privacy settings for message read date in private chats. Read dates are always shown to the users that can see online status of the current user regardless of this setting
//@show_read_date True, if message read date is shown to other users in private chats. If false and the current user isn't a Telegram Premium user, then they will not be able to see other's message read date
readDatePrivacySettings show_read_date:Bool = ReadDatePrivacySettings;

//@description Contains privacy settings for chats with non-contacts
//@allow_new_chats_from_unknown_users True, if non-contacts users are able to write first to the current user. Telegram Premium subscribers are able to write first regardless of this setting
//@incoming_paid_message_star_count Number of Telegram Stars that must be paid for every incoming private message by non-contacts; 0-getOption("paid_message_star_count_max").
//-If positive, then allow_new_chats_from_unknown_users must be true. The current user will receive getOption("paid_message_earnings_per_mille") Telegram Stars for each 1000 Telegram Stars paid for message sending
newChatPrivacySettings allow_new_chats_from_unknown_users:Bool incoming_paid_message_star_count:int53 = NewChatPrivacySettings;


//@class CanSendMessageToUserResult @description Describes result of canSendMessageToUser

//@description The user can be messaged
canSendMessageToUserResultOk = CanSendMessageToUserResult;

//@description The user can be messaged, but the messages are paid
//@outgoing_paid_message_star_count Number of Telegram Stars that must be paid by the current user for each sent message to the user
canSendMessageToUserResultUserHasPaidMessages outgoing_paid_message_star_count:int53 = CanSendMessageToUserResult;

//@description The user can't be messaged, because they are deleted or unknown
canSendMessageToUserResultUserIsDeleted = CanSendMessageToUserResult;

//@description The user can't be messaged, because they restrict new chats with non-contacts
canSendMessageToUserResultUserRestrictsNewChats = CanSendMessageToUserResult;


//@description Contains information about the period of inactivity after which the current user's account will automatically be deleted @days Number of days of inactivity before the account will be flagged for deletion; 30-730 days
accountTtl days:int32 = AccountTtl;


//@description Contains default auto-delete timer setting for new chats @time Message auto-delete time, in seconds. If 0, then messages aren't deleted automatically
messageAutoDeleteTime time:int32 = MessageAutoDeleteTime;


//@class SessionType @description Represents the type of session

//@description The session is running on an Android device
sessionTypeAndroid = SessionType;

//@description The session is running on a generic Apple device
sessionTypeApple = SessionType;

//@description The session is running on the Brave browser
sessionTypeBrave = SessionType;

//@description The session is running on the Chrome browser
sessionTypeChrome = SessionType;

//@description The session is running on the Edge browser
sessionTypeEdge = SessionType;

//@description The session is running on the Firefox browser
sessionTypeFirefox = SessionType;

//@description The session is running on an iPad device
sessionTypeIpad = SessionType;

//@description The session is running on an iPhone device
sessionTypeIphone = SessionType;

//@description The session is running on a Linux device
sessionTypeLinux = SessionType;

//@description The session is running on a Mac device
sessionTypeMac = SessionType;

//@description The session is running on the Opera browser
sessionTypeOpera = SessionType;

//@description The session is running on the Safari browser
sessionTypeSafari = SessionType;

//@description The session is running on an Ubuntu device
sessionTypeUbuntu = SessionType;

//@description The session is running on an unknown type of device
sessionTypeUnknown = SessionType;

//@description The session is running on the Vivaldi browser
sessionTypeVivaldi = SessionType;

//@description The session is running on a Windows device
sessionTypeWindows = SessionType;

//@description The session is running on an Xbox console
sessionTypeXbox = SessionType;


//@description Contains information about one session in a Telegram application used by the current user. Sessions must be shown to the user in the returned order
//@id Session identifier
//@is_current True, if this session is the current session
//@is_password_pending True, if a 2-step verification password is needed to complete authorization of the session
//@is_unconfirmed True, if the session wasn't confirmed from another session
//@can_accept_secret_chats True, if incoming secret chats can be accepted by the session
//@can_accept_calls True, if incoming calls can be accepted by the session
//@type Session type based on the system and application version, which can be used to display a corresponding icon
//@api_id Telegram API identifier, as provided by the application
//@application_name Name of the application, as provided by the application
//@application_version The version of the application, as provided by the application
//@is_official_application True, if the application is an official application or uses the api_id of an official application
//@device_model Model of the device the application has been run or is running on, as provided by the application
//@platform Operating system the application has been run or is running on, as provided by the application
//@system_version Version of the operating system the application has been run or is running on, as provided by the application
//@log_in_date Point in time (Unix timestamp) when the user has logged in
//@last_active_date Point in time (Unix timestamp) when the session was last used
//@ip_address IP address from which the session was created, in human-readable format
//@location A human-readable description of the location from which the session was created, based on the IP address
session id:int64 is_current:Bool is_password_pending:Bool is_unconfirmed:Bool can_accept_secret_chats:Bool can_accept_calls:Bool type:SessionType api_id:int32 application_name:string application_version:string is_official_application:Bool device_model:string platform:string system_version:string log_in_date:int32 last_active_date:int32 ip_address:string location:string = Session;

//@description Contains a list of sessions @sessions List of sessions @inactive_session_ttl_days Number of days of inactivity before sessions will automatically be terminated; 1-366 days
sessions sessions:vector<session> inactive_session_ttl_days:int32 = Sessions;

//@description Contains information about an unconfirmed session
//@id Session identifier
//@log_in_date Point in time (Unix timestamp) when the user has logged in
//@device_model Model of the device that was used for the session creation, as provided by the application
//@location A human-readable description of the location from which the session was created, based on the IP address
unconfirmedSession id:int64 log_in_date:int32 device_model:string location:string = UnconfirmedSession;


//@description Contains information about one website the current user is logged in with Telegram
//@id Website identifier
//@domain_name The domain name of the website
//@bot_user_id User identifier of a bot linked with the website
//@browser The version of a browser used to log in
//@platform Operating system the browser is running on
//@log_in_date Point in time (Unix timestamp) when the user was logged in
//@last_active_date Point in time (Unix timestamp) when obtained authorization was last used
//@ip_address IP address from which the user was logged in, in human-readable format
//@location Human-readable description of a country and a region from which the user was logged in, based on the IP address
connectedWebsite id:int64 domain_name:string bot_user_id:int53 browser:string platform:string log_in_date:int32 last_active_date:int32 ip_address:string location:string = ConnectedWebsite;

//@description Contains a list of websites the current user is logged in with Telegram @websites List of connected websites
connectedWebsites websites:vector<connectedWebsite> = ConnectedWebsites;


//@class ReportReason @description Describes the reason why a chat is reported

//@description The chat contains spam messages
reportReasonSpam = ReportReason;

//@description The chat promotes violence
reportReasonViolence = ReportReason;

//@description The chat contains pornographic messages
reportReasonPornography = ReportReason;

//@description The chat has child abuse related content
reportReasonChildAbuse = ReportReason;

//@description The chat contains copyrighted content
reportReasonCopyright = ReportReason;

//@description The location-based chat is unrelated to its stated location
reportReasonUnrelatedLocation = ReportReason;

//@description The chat represents a fake account
reportReasonFake = ReportReason;

//@description The chat has illegal drugs related content
reportReasonIllegalDrugs = ReportReason;

//@description The chat contains messages with personal details
reportReasonPersonalDetails = ReportReason;

//@description A custom reason provided by the user
reportReasonCustom = ReportReason;


//@class ReportChatResult @description Describes result of chat report

//@description The chat was reported successfully
reportChatResultOk = ReportChatResult;

//@description The user must choose an option to report the chat and repeat request with the chosen option @title Title for the option choice @options List of available options
reportChatResultOptionRequired title:string options:vector<reportOption> = ReportChatResult;

//@description The user must add additional text details to the report @option_id Option identifier for the next reportChat request @is_optional True, if the user can skip text adding
reportChatResultTextRequired option_id:bytes is_optional:Bool = ReportChatResult;

//@description The user must choose messages to report and repeat the reportChat request with the chosen messages
reportChatResultMessagesRequired = ReportChatResult;


//@class ReportStoryResult @description Describes result of story report

//@description The story was reported successfully
reportStoryResultOk = ReportStoryResult;

//@description The user must choose an option to report the story and repeat request with the chosen option @title Title for the option choice @options List of available options
reportStoryResultOptionRequired title:string options:vector<reportOption> = ReportStoryResult;

//@description The user must add additional text details to the report @option_id Option identifier for the next reportStory request @is_optional True, if the user can skip text adding
reportStoryResultTextRequired option_id:bytes is_optional:Bool = ReportStoryResult;


//@class InternalLinkType @description Describes an internal https://t.me or tg: link, which must be processed by the application in a special way

//@description The link is a link to the Devices section of the application. Use getActiveSessions to get the list of active sessions and show them to the user
internalLinkTypeActiveSessions = InternalLinkType;

//@description The link is a link to an attachment menu bot to be opened in the specified or a chosen chat. Process given target_chat to open the chat.
//-Then, call searchPublicChat with the given bot username, check that the user is a bot and can be added to attachment menu. Then, use getAttachmentMenuBot to receive information about the bot.
//-If the bot isn't added to attachment menu, then show a disclaimer about Mini Apps being third-party applications, ask the user to accept their Terms of service and confirm adding the bot to side and attachment menu.
//-If the user accept the terms and confirms adding, then use toggleBotIsAddedToAttachmentMenu to add the bot.
//-If the attachment menu bot can't be used in the opened chat, show an error to the user. If the bot is added to attachment menu and can be used in the chat, then use openWebApp with the given URL
//@target_chat Target chat to be opened
//@bot_username Username of the bot
//@url URL to be passed to openWebApp
internalLinkTypeAttachmentMenuBot target_chat:TargetChat bot_username:string url:string = InternalLinkType;

//@description The link contains an authentication code. Call checkAuthenticationCode with the code if the current authorization state is authorizationStateWaitCode @code The authentication code
internalLinkTypeAuthenticationCode code:string = InternalLinkType;

//@description The link is a link to a background. Call searchBackground with the given background name to process the link.
//-If background is found and the user wants to apply it, then call setDefaultBackground
//@background_name Name of the background
internalLinkTypeBackground background_name:string = InternalLinkType;

//@description The link is a link to a Telegram bot, which is expected to be added to a channel chat as an administrator. Call searchPublicChat with the given bot username and check that the user is a bot,
//-ask the current user to select a channel chat to add the bot to as an administrator. Then, call getChatMember to receive the current bot rights in the chat and if the bot already is an administrator,
//-check that the current user can edit its administrator rights and combine received rights with the requested administrator rights. Then, show confirmation box to the user, and call setChatMemberStatus with the chosen chat and confirmed rights
//@bot_username Username of the bot
//@administrator_rights Expected administrator rights for the bot
internalLinkTypeBotAddToChannel bot_username:string administrator_rights:chatAdministratorRights = InternalLinkType;

//@description The link is a link to a chat with a Telegram bot. Call searchPublicChat with the given bot username, check that the user is a bot, show START button in the chat with the bot,
//-and then call sendBotStartMessage with the given start parameter after the button is pressed
//@bot_username Username of the bot
//@start_parameter The parameter to be passed to sendBotStartMessage
//@autostart True, if sendBotStartMessage must be called automatically without showing the START button
internalLinkTypeBotStart bot_username:string start_parameter:string autostart:Bool = InternalLinkType;

//@description The link is a link to a Telegram bot, which is expected to be added to a group chat. Call searchPublicChat with the given bot username, check that the user is a bot and can be added to groups,
//-ask the current user to select a basic group or a supergroup chat to add the bot to, taking into account that bots can be added to a public supergroup only by administrators of the supergroup.
//-If administrator rights are provided by the link, call getChatMember to receive the current bot rights in the chat and if the bot already is an administrator,
//-check that the current user can edit its administrator rights, combine received rights with the requested administrator rights, show confirmation box to the user,
//-and call setChatMemberStatus with the chosen chat and confirmed administrator rights. Before call to setChatMemberStatus it may be required to upgrade the chosen basic group chat to a supergroup chat.
//-Then, if start_parameter isn't empty, call sendBotStartMessage with the given start parameter and the chosen chat; otherwise, just send /start message with bot's username added to the chat
//@bot_username Username of the bot
//@start_parameter The parameter to be passed to sendBotStartMessage
//@administrator_rights Expected administrator rights for the bot; may be null
internalLinkTypeBotStartInGroup bot_username:string start_parameter:string administrator_rights:chatAdministratorRights = InternalLinkType;

//@description The link is a link to a business chat. Use getBusinessChatLinkInfo with the provided link name to get information about the link,
//-then open received private chat and replace chat draft with the provided text
//@link_name Name of the link
internalLinkTypeBusinessChat link_name:string = InternalLinkType;

//@description The link is a link to the Telegram Star purchase section of the application
//@star_count The number of Telegram Stars that must be owned by the user
//@purpose Purpose of Telegram Star purchase. Arbitrary string specified by the server, for example, "subs" if the Telegram Stars are required to extend channel subscriptions
internalLinkTypeBuyStars star_count:int53 purpose:string = InternalLinkType;

//@description The link is a link to the change phone number section of the application
internalLinkTypeChangePhoneNumber = InternalLinkType;

//@description The link is an affiliate program link. Call searchChatAffiliateProgram with the given username and referrer to process the link
//@username Username to be passed to searchChatAffiliateProgram
//@referrer Referrer to be passed to searchChatAffiliateProgram
internalLinkTypeChatAffiliateProgram username:string referrer:string = InternalLinkType;

//@description The link is a link to boost a Telegram chat. Call getChatBoostLinkInfo with the given URL to process the link.
//-If the chat is found, then call getChatBoostStatus and getAvailableChatBoostSlots to get the current boost status and check whether the chat can be boosted.
//-If the user wants to boost the chat and the chat can be boosted, then call boostChat
//@url URL to be passed to getChatBoostLinkInfo
internalLinkTypeChatBoost url:string = InternalLinkType;

//@description The link is an invite link to a chat folder. Call checkChatFolderInviteLink with the given invite link to process the link.
//-If the link is valid and the user wants to join the chat folder, then call addChatFolderByInviteLink
//@invite_link Internal representation of the invite link
internalLinkTypeChatFolderInvite invite_link:string = InternalLinkType;

//@description The link is a link to the folder section of the application settings
internalLinkTypeChatFolderSettings = InternalLinkType;

//@description The link is a chat invite link. Call checkChatInviteLink with the given invite link to process the link.
//-If the link is valid and the user wants to join the chat, then call joinChatByInviteLink
//@invite_link Internal representation of the invite link
internalLinkTypeChatInvite invite_link:string = InternalLinkType;

//@description The link is a link to the default message auto-delete timer settings section of the application settings
internalLinkTypeDefaultMessageAutoDeleteTimerSettings = InternalLinkType;

//@description The link is a link to the edit profile section of the application settings
internalLinkTypeEditProfileSettings = InternalLinkType;

//@description The link is a link to a game. Call searchPublicChat with the given bot username, check that the user is a bot,
//-ask the current user to select a chat to send the game, and then call sendMessage with inputMessageGame
//@bot_username Username of the bot that owns the game
//@game_short_name Short name of the game
internalLinkTypeGame bot_username:string game_short_name:string = InternalLinkType;

//@description The link must be opened in an Instant View. Call getWebPageInstantView with the given URL to process the link.
//-If Instant View is found, then show it, otherwise, open the fallback URL in an external browser
//@url URL to be passed to getWebPageInstantView
//@fallback_url An URL to open if getWebPageInstantView fails
internalLinkTypeInstantView url:string fallback_url:string = InternalLinkType;

//@description The link is a link to an invoice. Call getPaymentForm with the given invoice name to process the link @invoice_name Name of the invoice
internalLinkTypeInvoice invoice_name:string = InternalLinkType;

//@description The link is a link to a language pack. Call getLanguagePackInfo with the given language pack identifier to process the link.
//-If the language pack is found and the user wants to apply it, then call setOption for the option "language_pack_id"
//@language_pack_id Language pack identifier
internalLinkTypeLanguagePack language_pack_id:string = InternalLinkType;

//@description The link is a link to the language section of the application settings
internalLinkTypeLanguageSettings = InternalLinkType;

//@description The link is a link to the main Web App of a bot. Call searchPublicChat with the given bot username, check that the user is a bot and has the main Web App.
//-If the bot can be added to attachment menu, then use getAttachmentMenuBot to receive information about the bot, then if the bot isn't added to side menu,
//-show a disclaimer about Mini Apps being third-party applications, ask the user to accept their Terms of service and confirm adding the bot to side and attachment menu,
//-then if the user accepts the terms and confirms adding, use toggleBotIsAddedToAttachmentMenu to add the bot.
//-Then, use getMainWebApp with the given start parameter and mode and open the returned URL as a Web App
//@bot_username Username of the bot
//@start_parameter Start parameter to be passed to getMainWebApp
//@mode The mode to be passed to getMainWebApp
internalLinkTypeMainWebApp bot_username:string start_parameter:string mode:WebAppOpenMode = InternalLinkType;

//@description The link is a link to a Telegram message or a forum topic. Call getMessageLinkInfo with the given URL to process the link,
//-and then open received forum topic or chat and show the message there
//@url URL to be passed to getMessageLinkInfo
internalLinkTypeMessage url:string = InternalLinkType;

//@description The link contains a message draft text. A share screen needs to be shown to the user, then the chosen chat must be opened and the text is added to the input field
//@text Message draft text
//@contains_link True, if the first line of the text contains a link. If true, the input field needs to be focused and the text after the link must be selected
internalLinkTypeMessageDraft text:formattedText contains_link:Bool = InternalLinkType;

//@description The link contains a request of Telegram passport data. Call getPassportAuthorizationForm with the given parameters to process the link if the link was received from outside of the application; otherwise, ignore it
//@bot_user_id User identifier of the service's bot; the corresponding user may be unknown yet
//@scope Telegram Passport element types requested by the service
//@public_key Service's public key
//@nonce Unique request identifier provided by the service
//@callback_url An HTTP URL to open once the request is finished, canceled, or failed with the parameters tg_passport=success, tg_passport=cancel, or tg_passport=error&error=... respectively.
//-If empty, then onActivityResult method must be used to return response on Android, or the link tgbot{bot_user_id}://passport/success or tgbot{bot_user_id}://passport/cancel must be opened otherwise
internalLinkTypePassportDataRequest bot_user_id:int53 scope:string public_key:string nonce:string callback_url:string = InternalLinkType;

//@description The link can be used to confirm ownership of a phone number to prevent account deletion. Call sendPhoneNumberCode with the given phone number and with phoneNumberCodeTypeConfirmOwnership with the given hash to process the link.
//-If succeeded, call checkPhoneNumberCode to check entered by the user code, or resendPhoneNumberCode to resend it
//@hash Hash value from the link
//@phone_number Phone number value from the link
internalLinkTypePhoneNumberConfirmation hash:string phone_number:string = InternalLinkType;

//@description The link is a link to the Premium features screen of the application from which the user can subscribe to Telegram Premium. Call getPremiumFeatures with the given referrer to process the link
//@referrer Referrer specified in the link
internalLinkTypePremiumFeatures referrer:string = InternalLinkType;

//@description The link is a link to the screen for gifting Telegram Premium subscriptions to friends via inputInvoiceTelegram with telegramPaymentPurposePremiumGift payments or in-store purchases
//@referrer Referrer specified in the link
internalLinkTypePremiumGift referrer:string = InternalLinkType;

//@description The link is a link with a Telegram Premium gift code. Call checkPremiumGiftCode with the given code to process the link.
//-If the code is valid and the user wants to apply it, then call applyPremiumGiftCode
//@code The Telegram Premium gift code
internalLinkTypePremiumGiftCode code:string = InternalLinkType;

//@description The link is a link to the privacy and security section of the application settings
internalLinkTypePrivacyAndSecuritySettings = InternalLinkType;

//@description The link is a link to a proxy. Call addProxy with the given parameters to process the link and add the proxy
//@server Proxy server domain or IP address
//@port Proxy server port
//@type Type of the proxy
internalLinkTypeProxy server:string port:int32 type:ProxyType = InternalLinkType;

//@description The link is a link to a chat by its username. Call searchPublicChat with the given chat username to process the link.
//-If the chat is found, open its profile information screen or the chat itself.
//-If draft text isn't empty and the chat is a private chat with a regular user, then put the draft text in the input field
//@chat_username Username of the chat
//@draft_text Draft text for message to send in the chat
//@open_profile True, if chat profile information screen must be opened; otherwise, the chat itself must be opened
internalLinkTypePublicChat chat_username:string draft_text:string open_profile:Bool = InternalLinkType;

//@description The link can be used to login the current user on another device, but it must be scanned from QR-code using in-app camera. An alert similar to
//-"This code can be used to allow someone to log in to your Telegram account. To confirm Telegram login, please go to Settings > Devices > Scan QR and scan the code" needs to be shown
internalLinkTypeQrCodeAuthentication = InternalLinkType;

//@description The link forces restore of App Store purchases when opened. For official iOS application only
internalLinkTypeRestorePurchases = InternalLinkType;

//@description The link is a link to application settings
internalLinkTypeSettings = InternalLinkType;

//@description The link is a link to a sticker set. Call searchStickerSet with the given sticker set name to process the link and show the sticker set.
//-If the sticker set is found and the user wants to add it, then call changeStickerSet
//@sticker_set_name Name of the sticker set
//@expect_custom_emoji True, if the sticker set is expected to contain custom emoji
internalLinkTypeStickerSet sticker_set_name:string expect_custom_emoji:Bool = InternalLinkType;

//@description The link is a link to a story. Call searchPublicChat with the given sender username, then call getStory with the received chat identifier and the given story identifier, then show the story if received
//@story_sender_username Username of the sender of the story
//@story_id Story identifier
internalLinkTypeStory story_sender_username:string story_id:int32 = InternalLinkType;

//@description The link is a link to a cloud theme. TDLib has no theme support yet @theme_name Name of the theme
internalLinkTypeTheme theme_name:string = InternalLinkType;

//@description The link is a link to the theme section of the application settings
internalLinkTypeThemeSettings = InternalLinkType;

//@description The link is an unknown tg: link. Call getDeepLinkInfo to process the link @link Link to be passed to getDeepLinkInfo
internalLinkTypeUnknownDeepLink link:string = InternalLinkType;

//@description The link is a link to an unsupported proxy. An alert can be shown to the user
internalLinkTypeUnsupportedProxy = InternalLinkType;

//@description The link is a link to an upgraded gift. Call getUpgradedGift with the given name to process the link @name Name of the unique gift
internalLinkTypeUpgradedGift name:string = InternalLinkType;

//@description The link is a link to a user by its phone number. Call searchUserByPhoneNumber with the given phone number to process the link.
//-If the user is found, then call createPrivateChat and open user's profile information screen or the chat itself. If draft text isn't empty, then put the draft text in the input field
//@phone_number Phone number of the user
//@draft_text Draft text for message to send in the chat
//@open_profile True, if user's profile information screen must be opened; otherwise, the chat itself must be opened
internalLinkTypeUserPhoneNumber phone_number:string draft_text:string open_profile:Bool = InternalLinkType;

//@description The link is a link to a user by a temporary token. Call searchUserByToken with the given token to process the link.
//-If the user is found, then call createPrivateChat and open the chat
//@token The token
internalLinkTypeUserToken token:string = InternalLinkType;

//@description The link is a link to a video chat. Call searchPublicChat with the given chat username, and then joinGroupCall with the given invite hash to process the link
//@chat_username Username of the chat with the video chat
//@invite_hash If non-empty, invite hash to be used to join the video chat without being muted by administrators
//@is_live_stream True, if the video chat is expected to be a live stream in a channel or a broadcast group
internalLinkTypeVideoChat chat_username:string invite_hash:string is_live_stream:Bool = InternalLinkType;

//@description The link is a link to a Web App. Call searchPublicChat with the given bot username, check that the user is a bot. If the bot is restricted for the current user, then show an error message.
//-Otherwise, call searchWebApp with the received bot and the given web_app_short_name. Process received foundWebApp by showing a confirmation dialog if needed.
//-If the bot can be added to attachment or side menu, but isn't added yet, then show a disclaimer about Mini Apps being third-party applications instead of the dialog
//-and ask the user to accept their Terms of service. If the user accept the terms and confirms adding, then use toggleBotIsAddedToAttachmentMenu to add the bot.
//-Then, call getWebAppLinkUrl and open the returned URL as a Web App
//@bot_username Username of the bot that owns the Web App
//@web_app_short_name Short name of the Web App
//@start_parameter Start parameter to be passed to getWebAppLinkUrl
//@mode The mode in which the Web App must be opened
internalLinkTypeWebApp bot_username:string web_app_short_name:string start_parameter:string mode:WebAppOpenMode = InternalLinkType;


//@description Contains an HTTPS link to a message in a supergroup or channel, or a forum topic @link The link @is_public True, if the link will work for non-members of the chat
messageLink link:string is_public:Bool = MessageLink;

//@description Contains information about a link to a message or a forum topic in a chat
//@is_public True, if the link is a public link for a message or a forum topic in a chat
//@chat_id If found, identifier of the chat to which the link points, 0 otherwise
//@message_thread_id If found, identifier of the message thread in which to open the message, or a forum topic to open if the message is missing
//@message If found, the linked message; may be null
//@media_timestamp Timestamp from which the video/audio/video note/voice note/story playing must start, in seconds; 0 if not specified. The media can be in the message content or in its link preview
//@for_album True, if the whole media album to which the message belongs is linked
messageLinkInfo is_public:Bool chat_id:int53 message_thread_id:int53 message:message media_timestamp:int32 for_album:Bool = MessageLinkInfo;


//@description Contains an HTTPS link to boost a chat @link The link @is_public True, if the link will work for non-members of the chat
chatBoostLink link:string is_public:Bool = ChatBoostLink;

//@description Contains information about a link to boost a chat
//@is_public True, if the link will work for non-members of the chat
//@chat_id Identifier of the chat to which the link points; 0 if the chat isn't found
chatBoostLinkInfo is_public:Bool chat_id:int53 = ChatBoostLinkInfo;


//@class BlockList @description Describes type of block list

//@description The main block list that disallows writing messages to the current user, receiving their status and photo, viewing of stories, and some other actions
blockListMain = BlockList;

//@description The block list that disallows viewing of stories of the current user
blockListStories = BlockList;


//@description Contains a part of a file @data File bytes
filePart data:bytes = FilePart;


//@class FileType @description Represents the type of file

//@description The data is not a file
fileTypeNone = FileType;

//@description The file is an animation
fileTypeAnimation = FileType;

//@description The file is an audio file
fileTypeAudio = FileType;

//@description The file is a document
fileTypeDocument = FileType;

//@description The file is a notification sound
fileTypeNotificationSound = FileType;

//@description The file is a photo
fileTypePhoto = FileType;

//@description The file is a photo published as a story
fileTypePhotoStory = FileType;

//@description The file is a profile photo
fileTypeProfilePhoto = FileType;

//@description The file was sent to a secret chat (the file type is not known to the server)
fileTypeSecret = FileType;

//@description The file is a thumbnail of a file from a secret chat
fileTypeSecretThumbnail = FileType;

//@description The file is a file from Secure storage used for storing Telegram Passport files
fileTypeSecure = FileType;

//@description The file is a self-destructing photo in a private chat
fileTypeSelfDestructingPhoto = FileType;

//@description The file is a self-destructing video in a private chat
fileTypeSelfDestructingVideo = FileType;

//@description The file is a self-destructing video note in a private chat
fileTypeSelfDestructingVideoNote = FileType;

//@description The file is a self-destructing voice note in a private chat
fileTypeSelfDestructingVoiceNote = FileType;

//@description The file is a sticker
fileTypeSticker = FileType;

//@description The file is a thumbnail of another file
fileTypeThumbnail = FileType;

//@description The file type is not yet known
fileTypeUnknown = FileType;

//@description The file is a video
fileTypeVideo = FileType;

//@description The file is a video note
fileTypeVideoNote = FileType;

//@description The file is a video published as a story
fileTypeVideoStory = FileType;

//@description The file is a voice note
fileTypeVoiceNote = FileType;

//@description The file is a wallpaper or a background pattern
fileTypeWallpaper = FileType;


//@description Contains the storage usage statistics for a specific file type
//@file_type File type
//@size Total size of the files, in bytes
//@count Total number of files
storageStatisticsByFileType file_type:FileType size:int53 count:int32 = StorageStatisticsByFileType;

//@description Contains the storage usage statistics for a specific chat
//@chat_id Chat identifier; 0 if none
//@size Total size of the files in the chat, in bytes
//@count Total number of files in the chat
//@by_file_type Statistics split by file types
storageStatisticsByChat chat_id:int53 size:int53 count:int32 by_file_type:vector<storageStatisticsByFileType> = StorageStatisticsByChat;

//@description Contains the exact storage usage statistics split by chats and file type
//@size Total size of files, in bytes
//@count Total number of files
//@by_chat Statistics split by chats
storageStatistics size:int53 count:int32 by_chat:vector<storageStatisticsByChat> = StorageStatistics;

//@description Contains approximate storage usage statistics, excluding files of unknown file type
//@files_size Approximate total size of files, in bytes
//@file_count Approximate number of files
//@database_size Size of the database
//@language_pack_database_size Size of the language pack database
//@log_size Size of the TDLib internal log
storageStatisticsFast files_size:int53 file_count:int32 database_size:int53 language_pack_database_size:int53 log_size:int53 = StorageStatisticsFast;

//@description Contains database statistics
//@statistics Database statistics in an unspecified human-readable format
databaseStatistics statistics:string = DatabaseStatistics;


//@class NetworkType @description Represents the type of network

//@description The network is not available
networkTypeNone = NetworkType;

//@description A mobile network
networkTypeMobile = NetworkType;

//@description A mobile roaming network
networkTypeMobileRoaming = NetworkType;

//@description A Wi-Fi network
networkTypeWiFi = NetworkType;

//@description A different network type (e.g., Ethernet network)
networkTypeOther = NetworkType;


//@class NetworkStatisticsEntry @description Contains statistics about network usage

//@description Contains information about the total amount of data that was used to send and receive files
//@file_type Type of the file the data is part of; pass null if the data isn't related to files
//@network_type Type of the network the data was sent through. Call setNetworkType to maintain the actual network type
//@sent_bytes Total number of bytes sent
//@received_bytes Total number of bytes received
networkStatisticsEntryFile file_type:FileType network_type:NetworkType sent_bytes:int53 received_bytes:int53 = NetworkStatisticsEntry;

//@description Contains information about the total amount of data that was used for calls
//@network_type Type of the network the data was sent through. Call setNetworkType to maintain the actual network type
//@sent_bytes Total number of bytes sent
//@received_bytes Total number of bytes received
//@duration Total call duration, in seconds
networkStatisticsEntryCall network_type:NetworkType sent_bytes:int53 received_bytes:int53 duration:double = NetworkStatisticsEntry;

//@description A full list of available network statistic entries @since_date Point in time (Unix timestamp) from which the statistics are collected @entries Network statistics entries
networkStatistics since_date:int32 entries:vector<NetworkStatisticsEntry> = NetworkStatistics;


//@description Contains auto-download settings
//@is_auto_download_enabled True, if the auto-download is enabled
//@max_photo_file_size The maximum size of a photo file to be auto-downloaded, in bytes
//@max_video_file_size The maximum size of a video file to be auto-downloaded, in bytes
//@max_other_file_size The maximum size of other file types to be auto-downloaded, in bytes
//@video_upload_bitrate The maximum suggested bitrate for uploaded videos, in kbit/s
//@preload_large_videos True, if the beginning of video files needs to be preloaded for instant playback
//@preload_next_audio True, if the next audio track needs to be preloaded while the user is listening to an audio file
//@preload_stories True, if stories needs to be preloaded
//@use_less_data_for_calls True, if "use less data for calls" option needs to be enabled
autoDownloadSettings is_auto_download_enabled:Bool max_photo_file_size:int32 max_video_file_size:int53 max_other_file_size:int53 video_upload_bitrate:int32 preload_large_videos:Bool preload_next_audio:Bool preload_stories:Bool use_less_data_for_calls:Bool = AutoDownloadSettings;

//@description Contains auto-download settings presets for the current user
//@low Preset with lowest settings; expected to be used by default when roaming
//@medium Preset with medium settings; expected to be used by default when using mobile data
//@high Preset with highest settings; expected to be used by default when connected on Wi-Fi
autoDownloadSettingsPresets low:autoDownloadSettings medium:autoDownloadSettings high:autoDownloadSettings = AutoDownloadSettingsPresets;


//@class AutosaveSettingsScope @description Describes scope of autosave settings

//@description Autosave settings applied to all private chats without chat-specific settings
autosaveSettingsScopePrivateChats = AutosaveSettingsScope;

//@description Autosave settings applied to all basic group and supergroup chats without chat-specific settings
autosaveSettingsScopeGroupChats = AutosaveSettingsScope;

//@description Autosave settings applied to all channel chats without chat-specific settings
autosaveSettingsScopeChannelChats = AutosaveSettingsScope;

//@description Autosave settings applied to a chat @chat_id Chat identifier
autosaveSettingsScopeChat chat_id:int53 = AutosaveSettingsScope;


//@description Contains autosave settings for an autosave settings scope
//@autosave_photos True, if photo autosave is enabled
//@autosave_videos True, if video autosave is enabled
//@max_video_file_size The maximum size of a video file to be autosaved, in bytes; 512 KB - 4000 MB
scopeAutosaveSettings autosave_photos:Bool autosave_videos:Bool max_video_file_size:int53 = ScopeAutosaveSettings;

//@description Contains autosave settings for a chat, which overrides default settings for the corresponding scope
//@chat_id Chat identifier
//@settings Autosave settings for the chat
autosaveSettingsException chat_id:int53 settings:scopeAutosaveSettings = AutosaveSettingsException;

//@description Describes autosave settings
//@private_chat_settings Default autosave settings for private chats
//@group_settings Default autosave settings for basic group and supergroup chats
//@channel_settings Default autosave settings for channel chats
//@exceptions Autosave settings for specific chats
autosaveSettings private_chat_settings:scopeAutosaveSettings group_settings:scopeAutosaveSettings channel_settings:scopeAutosaveSettings exceptions:vector<autosaveSettingsException> = AutosaveSettings;


//@class ConnectionState @description Describes the current state of the connection to Telegram servers

//@description Waiting for the network to become available. Use setNetworkType to change the available network type
connectionStateWaitingForNetwork = ConnectionState;

//@description Establishing a connection with a proxy server
connectionStateConnectingToProxy = ConnectionState;

//@description Establishing a connection to the Telegram servers
connectionStateConnecting = ConnectionState;

//@description Downloading data expected to be received while the application was offline
connectionStateUpdating = ConnectionState;

//@description There is a working connection to the Telegram servers
connectionStateReady = ConnectionState;


//@class TopChatCategory @description Represents the categories of chats for which a list of frequently used chats can be retrieved

//@description A category containing frequently used private chats with non-bot users
topChatCategoryUsers = TopChatCategory;

//@description A category containing frequently used private chats with bot users
topChatCategoryBots = TopChatCategory;

//@description A category containing frequently used basic groups and supergroups
topChatCategoryGroups = TopChatCategory;

//@description A category containing frequently used channels
topChatCategoryChannels = TopChatCategory;

//@description A category containing frequently used chats with inline bots sorted by their usage in inline mode
topChatCategoryInlineBots = TopChatCategory;

//@description A category containing frequently used chats with bots, which Web Apps were opened
topChatCategoryWebAppBots = TopChatCategory;

//@description A category containing frequently used chats used for calls
topChatCategoryCalls = TopChatCategory;

//@description A category containing frequently used chats used to forward messages
topChatCategoryForwardChats = TopChatCategory;


//@description Contains 0-based match position @position The position of the match
foundPosition position:int32 = FoundPosition;

//@description Contains 0-based positions of matched objects @total_count Total number of matched objects @positions The positions of the matched objects
foundPositions total_count:int32 positions:vector<int32> = FoundPositions;


//@class TMeUrlType @description Describes the type of URL linking to an internal Telegram entity

//@description A URL linking to a user @user_id Identifier of the user
tMeUrlTypeUser user_id:int53 = TMeUrlType;

//@description A URL linking to a public supergroup or channel @supergroup_id Identifier of the supergroup or channel
tMeUrlTypeSupergroup supergroup_id:int53 = TMeUrlType;

//@description A chat invite link @info Information about the chat invite link
tMeUrlTypeChatInvite info:chatInviteLinkInfo = TMeUrlType;

//@description A URL linking to a sticker set @sticker_set_id Identifier of the sticker set
tMeUrlTypeStickerSet sticker_set_id:int64 = TMeUrlType;

//@description Represents a URL linking to an internal Telegram entity @url URL @type Type of the URL
tMeUrl url:string type:TMeUrlType = TMeUrl;

//@description Contains a list of t.me URLs @urls List of URLs
tMeUrls urls:vector<tMeUrl> = TMeUrls;


//@class SuggestedAction @description Describes an action suggested to the current user

//@description Suggests the user to enable archive_and_mute_new_chats_from_unknown_users setting in archiveChatListSettings
suggestedActionEnableArchiveAndMuteNewChats = SuggestedAction;

//@description Suggests the user to check whether they still remember their 2-step verification password
suggestedActionCheckPassword = SuggestedAction;

//@description Suggests the user to check whether authorization phone number is correct and change the phone number if it is inaccessible
suggestedActionCheckPhoneNumber = SuggestedAction;

//@description Suggests the user to view a hint about the meaning of one and two check marks on sent messages
suggestedActionViewChecksHint = SuggestedAction;

//@description Suggests the user to convert specified supergroup to a broadcast group @supergroup_id Supergroup identifier
suggestedActionConvertToBroadcastGroup supergroup_id:int53 = SuggestedAction;

//@description Suggests the user to set a 2-step verification password to be able to log in again
//@authorization_delay The number of days to pass between consecutive authorizations if the user declines to set password; if 0, then the user is advised to set the password for security reasons
suggestedActionSetPassword authorization_delay:int32 = SuggestedAction;

//@description Suggests the user to upgrade the Premium subscription from monthly payments to annual payments
suggestedActionUpgradePremium = SuggestedAction;

//@description Suggests the user to restore a recently expired Premium subscription
suggestedActionRestorePremium = SuggestedAction;

//@description Suggests the user to subscribe to the Premium subscription with annual payments
suggestedActionSubscribeToAnnualPremium = SuggestedAction;

//@description Suggests the user to gift Telegram Premium to friends for Christmas
suggestedActionGiftPremiumForChristmas = SuggestedAction;

//@description Suggests the user to set birthdate
suggestedActionSetBirthdate = SuggestedAction;

//@description Suggests the user to set profile photo
suggestedActionSetProfilePhoto = SuggestedAction;

//@description Suggests the user to extend their expiring Telegram Premium subscription @manage_premium_subscription_url A URL for managing Telegram Premium subscription
suggestedActionExtendPremium manage_premium_subscription_url:string = SuggestedAction;

//@description Suggests the user to extend their expiring Telegram Star subscriptions. Call getStarSubscriptions with only_expiring == true
//-to get the number of expiring subscriptions and the number of required to buy Telegram Stars
suggestedActionExtendStarSubscriptions = SuggestedAction;


//@description Contains a counter @count Count
count count:int32 = Count;

//@description Contains some text @text Text
text text:string = Text;

//@description Contains a value representing a number of seconds @seconds Number of seconds
seconds seconds:double = Seconds;

//@description Contains size of downloaded prefix of a file @size The prefix size, in bytes
fileDownloadedPrefixSize size:int53 = FileDownloadedPrefixSize;

//@description Contains a number of Telegram Stars @star_count Number of Telegram Stars
starCount star_count:int53 = StarCount;


//@description Contains information about a tg: deep link @text Text to be shown to the user @need_update_application True, if the user must be asked to update the application
deepLinkInfo text:formattedText need_update_application:Bool = DeepLinkInfo;


//@class TextParseMode @description Describes the way the text needs to be parsed for text entities

//@description The text uses Markdown-style formatting
//@version Version of the parser: 0 or 1 - Telegram Bot API "Markdown" parse mode, 2 - Telegram Bot API "MarkdownV2" parse mode
textParseModeMarkdown version:int32 = TextParseMode;

//@description The text uses HTML-style formatting. The same as Telegram Bot API "HTML" parse mode
textParseModeHTML = TextParseMode;


//@class ProxyType @description Describes the type of proxy server

//@description A SOCKS5 proxy server @username Username for logging in; may be empty @password Password for logging in; may be empty
proxyTypeSocks5 username:string password:string = ProxyType;

//@description A HTTP transparent proxy server @username Username for logging in; may be empty @password Password for logging in; may be empty @http_only Pass true if the proxy supports only HTTP requests and doesn't support transparent TCP connections via HTTP CONNECT method
proxyTypeHttp username:string password:string http_only:Bool = ProxyType;

//@description An MTProto proxy server @secret The proxy's secret in hexadecimal encoding
proxyTypeMtproto secret:string = ProxyType;


//@description Contains information about a proxy server
//@id Unique identifier of the proxy
//@server Proxy server domain or IP address
//@port Proxy server port
//@last_used_date Point in time (Unix timestamp) when the proxy was last used; 0 if never
//@is_enabled True, if the proxy is enabled now
//@type Type of the proxy
proxy id:int32 server:string port:int32 last_used_date:int32 is_enabled:Bool type:ProxyType = Proxy;

//@description Represents a list of proxy servers @proxies List of proxy servers
proxies proxies:vector<proxy> = Proxies;


//@description A sticker to be added to a sticker set
//@sticker File with the sticker; must fit in a 512x512 square. For WEBP stickers the file must be in WEBP or PNG format, which will be converted to WEBP server-side.
//-See https://core.telegram.org/animated_stickers#technical-requirements for technical requirements
//@format Format of the sticker
//@emojis String with 1-20 emoji corresponding to the sticker
//@mask_position Position where the mask is placed; pass null if not specified
//@keywords List of up to 20 keywords with total length up to 64 characters, which can be used to find the sticker
inputSticker sticker:InputFile format:StickerFormat emojis:string mask_position:maskPosition keywords:vector<string> = InputSticker;


//@description Represents a date range @start_date Point in time (Unix timestamp) at which the date range begins @end_date Point in time (Unix timestamp) at which the date range ends
dateRange start_date:int32 end_date:int32 = DateRange;


//@description A value with information about its recent changes @value The current value @previous_value The value for the previous day @growth_rate_percentage The growth rate of the value, as a percentage
statisticalValue value:double previous_value:double growth_rate_percentage:double = StatisticalValue;


//@class StatisticalGraph @description Describes a statistical graph

//@description A graph data @json_data Graph data in JSON format @zoom_token If non-empty, a token which can be used to receive a zoomed in graph
statisticalGraphData json_data:string zoom_token:string = StatisticalGraph;

//@description The graph data to be asynchronously loaded through getStatisticalGraph @token The token to use for data loading
statisticalGraphAsync token:string = StatisticalGraph;

//@description An error message to be shown to the user instead of the graph @error_message The error message
statisticalGraphError error_message:string = StatisticalGraph;


//@class ChatStatisticsObjectType @description Describes type of object, for which statistics are provided

//@description Describes a message sent in the chat @message_id Message identifier
chatStatisticsObjectTypeMessage message_id:int53 = ChatStatisticsObjectType;

//@description Describes a story sent by the chat @story_id Story identifier
chatStatisticsObjectTypeStory story_id:int32 = ChatStatisticsObjectType;


//@description Contains statistics about interactions with a message sent in the chat or a story sent by the chat
//@object_type Type of the object
//@view_count Number of times the object was viewed
//@forward_count Number of times the object was forwarded
//@reaction_count Number of times reactions were added to the object
chatStatisticsInteractionInfo object_type:ChatStatisticsObjectType view_count:int32 forward_count:int32 reaction_count:int32 = ChatStatisticsInteractionInfo;

//@description Contains statistics about messages sent by a user
//@user_id User identifier
//@sent_message_count Number of sent messages
//@average_character_count Average number of characters in sent messages; 0 if unknown
chatStatisticsMessageSenderInfo user_id:int53 sent_message_count:int32 average_character_count:int32 = ChatStatisticsMessageSenderInfo;

//@description Contains statistics about administrator actions done by a user
//@user_id Administrator user identifier
//@deleted_message_count Number of messages deleted by the administrator
//@banned_user_count Number of users banned by the administrator
//@restricted_user_count Number of users restricted by the administrator
chatStatisticsAdministratorActionsInfo user_id:int53 deleted_message_count:int32 banned_user_count:int32 restricted_user_count:int32 = ChatStatisticsAdministratorActionsInfo;

//@description Contains statistics about number of new members invited by a user
//@user_id User identifier
//@added_member_count Number of new members invited by the user
chatStatisticsInviterInfo user_id:int53 added_member_count:int32 = ChatStatisticsInviterInfo;


//@class ChatStatistics @description Contains a detailed statistics about a chat

//@description A detailed statistics about a supergroup chat
//@period A period to which the statistics applies
//@member_count Number of members in the chat
//@message_count Number of messages sent to the chat
//@viewer_count Number of users who viewed messages in the chat
//@sender_count Number of users who sent messages to the chat
//@member_count_graph A graph containing number of members in the chat
//@join_graph A graph containing number of members joined and left the chat
//@join_by_source_graph A graph containing number of new member joins per source
//@language_graph A graph containing distribution of active users per language
//@message_content_graph A graph containing distribution of sent messages by content type
//@action_graph A graph containing number of different actions in the chat
//@day_graph A graph containing distribution of message views per hour
//@week_graph A graph containing distribution of message views per day of week
//@top_senders List of users sent most messages in the last week
//@top_administrators List of most active administrators in the last week
//@top_inviters List of most active inviters of new members in the last week
chatStatisticsSupergroup period:dateRange member_count:statisticalValue message_count:statisticalValue viewer_count:statisticalValue sender_count:statisticalValue member_count_graph:StatisticalGraph join_graph:StatisticalGraph join_by_source_graph:StatisticalGraph language_graph:StatisticalGraph message_content_graph:StatisticalGraph action_graph:StatisticalGraph day_graph:StatisticalGraph week_graph:StatisticalGraph top_senders:vector<chatStatisticsMessageSenderInfo> top_administrators:vector<chatStatisticsAdministratorActionsInfo> top_inviters:vector<chatStatisticsInviterInfo> = ChatStatistics;

//@description A detailed statistics about a channel chat
//@period A period to which the statistics applies
//@member_count Number of members in the chat
//@mean_message_view_count Mean number of times the recently sent messages were viewed
//@mean_message_share_count Mean number of times the recently sent messages were shared
//@mean_message_reaction_count Mean number of times reactions were added to the recently sent messages
//@mean_story_view_count Mean number of times the recently sent stories were viewed
//@mean_story_share_count Mean number of times the recently sent stories were shared
//@mean_story_reaction_count Mean number of times reactions were added to the recently sent stories
//@enabled_notifications_percentage A percentage of users with enabled notifications for the chat; 0-100
//@member_count_graph A graph containing number of members in the chat
//@join_graph A graph containing number of members joined and left the chat
//@mute_graph A graph containing number of members muted and unmuted the chat
//@view_count_by_hour_graph A graph containing number of message views in a given hour in the last two weeks
//@view_count_by_source_graph A graph containing number of message views per source
//@join_by_source_graph A graph containing number of new member joins per source
//@language_graph A graph containing number of users viewed chat messages per language
//@message_interaction_graph A graph containing number of chat message views and shares
//@message_reaction_graph A graph containing number of reactions on messages
//@story_interaction_graph A graph containing number of story views and shares
//@story_reaction_graph A graph containing number of reactions on stories
//@instant_view_interaction_graph A graph containing number of views of associated with the chat instant views
//@recent_interactions Detailed statistics about number of views and shares of recently sent messages and stories
chatStatisticsChannel period:dateRange member_count:statisticalValue mean_message_view_count:statisticalValue mean_message_share_count:statisticalValue mean_message_reaction_count:statisticalValue mean_story_view_count:statisticalValue mean_story_share_count:statisticalValue mean_story_reaction_count:statisticalValue enabled_notifications_percentage:double member_count_graph:StatisticalGraph join_graph:StatisticalGraph mute_graph:StatisticalGraph view_count_by_hour_graph:StatisticalGraph view_count_by_source_graph:StatisticalGraph join_by_source_graph:StatisticalGraph language_graph:StatisticalGraph message_interaction_graph:StatisticalGraph message_reaction_graph:StatisticalGraph story_interaction_graph:StatisticalGraph story_reaction_graph:StatisticalGraph instant_view_interaction_graph:StatisticalGraph recent_interactions:vector<chatStatisticsInteractionInfo> = ChatStatistics;


//@description Contains information about revenue earned from sponsored messages in a chat
//@cryptocurrency Cryptocurrency in which revenue is calculated
//@total_amount Total amount of the cryptocurrency earned, in the smallest units of the cryptocurrency
//@balance_amount Amount of the cryptocurrency that isn't withdrawn yet, in the smallest units of the cryptocurrency
//@available_amount Amount of the cryptocurrency available for withdrawal, in the smallest units of the cryptocurrency
//@withdrawal_enabled True, if Telegram Stars can be withdrawn now or later
chatRevenueAmount cryptocurrency:string total_amount:int64 balance_amount:int64 available_amount:int64 withdrawal_enabled:Bool = ChatRevenueAmount;

//@description A detailed statistics about revenue earned from sponsored messages in a chat
//@revenue_by_hour_graph A graph containing amount of revenue in a given hour
//@revenue_graph A graph containing amount of revenue
//@revenue_amount Amount of earned revenue
//@usd_rate Current conversion rate of the cryptocurrency in which revenue is calculated to USD
chatRevenueStatistics revenue_by_hour_graph:StatisticalGraph revenue_graph:StatisticalGraph revenue_amount:chatRevenueAmount usd_rate:double = ChatRevenueStatistics;

//@description A detailed statistics about a message
//@message_interaction_graph A graph containing number of message views and shares
//@message_reaction_graph A graph containing number of message reactions
messageStatistics message_interaction_graph:StatisticalGraph message_reaction_graph:StatisticalGraph = MessageStatistics;

//@description A detailed statistics about a story
//@story_interaction_graph A graph containing number of story views and shares
//@story_reaction_graph A graph containing number of story reactions
storyStatistics story_interaction_graph:StatisticalGraph story_reaction_graph:StatisticalGraph = StoryStatistics;


//@class RevenueWithdrawalState @description Describes state of a revenue withdrawal

//@description Withdrawal is pending
revenueWithdrawalStatePending = RevenueWithdrawalState;

//@description Withdrawal succeeded
//@date Point in time (Unix timestamp) when the withdrawal was completed
//@url The URL where the withdrawal transaction can be viewed
revenueWithdrawalStateSucceeded date:int32 url:string = RevenueWithdrawalState;

//@description Withdrawal failed
revenueWithdrawalStateFailed = RevenueWithdrawalState;


//@class ChatRevenueTransactionType @description Describes type of transaction for revenue earned from sponsored messages in a chat

//@description Describes earnings from sponsored messages in a chat in some time frame
//@start_date Point in time (Unix timestamp) when the earnings started
//@end_date Point in time (Unix timestamp) when the earnings ended
chatRevenueTransactionTypeEarnings start_date:int32 end_date:int32 = ChatRevenueTransactionType;

//@description Describes a withdrawal of earnings
//@withdrawal_date Point in time (Unix timestamp) when the earnings withdrawal started
//@provider Name of the payment provider
//@state State of the withdrawal
chatRevenueTransactionTypeWithdrawal withdrawal_date:int32 provider:string state:RevenueWithdrawalState = ChatRevenueTransactionType;

//@description Describes a refund for failed withdrawal of earnings
//@refund_date Point in time (Unix timestamp) when the transaction was refunded
//@provider Name of the payment provider
chatRevenueTransactionTypeRefund refund_date:int32 provider:string = ChatRevenueTransactionType;

//@description Contains a chat revenue transactions
//@cryptocurrency Cryptocurrency in which revenue is calculated
//@cryptocurrency_amount The withdrawn amount, in the smallest units of the cryptocurrency
//@type Type of the transaction
chatRevenueTransaction cryptocurrency:string cryptocurrency_amount:int64 type:ChatRevenueTransactionType = ChatRevenueTransaction;

//@description Contains a list of chat revenue transactions @total_count Total number of transactions @transactions List of transactions
chatRevenueTransactions total_count:int32 transactions:vector<chatRevenueTransaction> = ChatRevenueTransactions;


//@description Contains information about Telegram Stars earned by a bot or a chat
//@total_amount Total amount of Telegram Stars earned
//@current_amount The amount of Telegram Stars that aren't withdrawn yet
//@available_amount The amount of Telegram Stars that are available for withdrawal
//@withdrawal_enabled True, if Telegram Stars can be withdrawn now or later
//@next_withdrawal_in Time left before the next withdrawal can be started, in seconds; 0 if withdrawal can be started now
starRevenueStatus total_amount:starAmount current_amount:starAmount available_amount:starAmount withdrawal_enabled:Bool next_withdrawal_in:int32 = StarRevenueStatus;

//@description A detailed statistics about Telegram Stars earned by a bot or a chat
//@revenue_by_day_graph A graph containing amount of revenue in a given day
//@status Telegram Star revenue status
//@usd_rate Current conversion rate of a Telegram Star to USD
starRevenueStatistics revenue_by_day_graph:StatisticalGraph status:starRevenueStatus usd_rate:double = StarRevenueStatistics;


//@description A point on a Cartesian plane @x The point's first coordinate @y The point's second coordinate
point x:double y:double = Point;


//@class VectorPathCommand @description Represents a vector path command

//@description A straight line to a given point @end_point The end point of the straight line
vectorPathCommandLine end_point:point = VectorPathCommand;

//@description A cubic Bézier curve to a given point @start_control_point The start control point of the curve @end_control_point The end control point of the curve @end_point The end point of the curve
vectorPathCommandCubicBezierCurve start_control_point:point end_control_point:point end_point:point = VectorPathCommand;


//@class BotCommandScope @description Represents the scope to which bot commands are relevant

//@description A scope covering all users
botCommandScopeDefault = BotCommandScope;

//@description A scope covering all private chats
botCommandScopeAllPrivateChats = BotCommandScope;

//@description A scope covering all group and supergroup chats
botCommandScopeAllGroupChats = BotCommandScope;

//@description A scope covering all group and supergroup chat administrators
botCommandScopeAllChatAdministrators = BotCommandScope;

//@description A scope covering all members of a chat @chat_id Chat identifier
botCommandScopeChat chat_id:int53 = BotCommandScope;

//@description A scope covering all administrators of a chat @chat_id Chat identifier
botCommandScopeChatAdministrators chat_id:int53 = BotCommandScope;

//@description A scope covering a member of a chat @chat_id Chat identifier @user_id User identifier
botCommandScopeChatMember chat_id:int53 user_id:int53 = BotCommandScope;


//@class PhoneNumberCodeType @description Describes type of the request for which a code is sent to a phone number

//@description Checks ownership of a new phone number to change the user's authentication phone number; for official Android and iOS applications only
phoneNumberCodeTypeChange = PhoneNumberCodeType;

//@description Verifies ownership of a phone number to be added to the user's Telegram Passport
phoneNumberCodeTypeVerify = PhoneNumberCodeType;

//@description Confirms ownership of a phone number to prevent account deletion while handling links of the type internalLinkTypePhoneNumberConfirmation
//@hash Hash value from the link
phoneNumberCodeTypeConfirmOwnership hash:string = PhoneNumberCodeType;


//@class Update @description Contains notifications about data changes

//@description The user authorization state has changed @authorization_state New authorization state
updateAuthorizationState authorization_state:AuthorizationState = Update;

//@description A new message was received; can also be an outgoing message @message The new message
updateNewMessage message:message = Update;

//@description A request to send a message has reached the Telegram server. This doesn't mean that the message will be sent successfully.
//-This update is sent only if the option "use_quick_ack" is set to true. This update may be sent multiple times for the same message
//@chat_id The chat identifier of the sent message
//@message_id A temporary message identifier
updateMessageSendAcknowledged chat_id:int53 message_id:int53 = Update;

//@description A message has been successfully sent
//@message The sent message. Almost any field of the new message can be different from the corresponding field of the original message.
//-For example, the field scheduling_state may change, making the message scheduled, or non-scheduled
//@old_message_id The previous temporary message identifier
updateMessageSendSucceeded message:message old_message_id:int53 = Update;

//@description A message failed to send. Be aware that some messages being sent can be irrecoverably deleted, in which case updateDeleteMessages will be received instead of this update
//@message The failed to send message
//@old_message_id The previous temporary message identifier
//@error The cause of the message sending failure
updateMessageSendFailed message:message old_message_id:int53 error:error = Update;

//@description The message content has changed @chat_id Chat identifier @message_id Message identifier @new_content New message content
updateMessageContent chat_id:int53 message_id:int53 new_content:MessageContent = Update;

//@description A message was edited. Changes in the message content will come in a separate updateMessageContent
//@chat_id Chat identifier
//@message_id Message identifier
//@edit_date Point in time (Unix timestamp) when the message was edited
//@reply_markup New message reply markup; may be null
updateMessageEdited chat_id:int53 message_id:int53 edit_date:int32 reply_markup:ReplyMarkup = Update;

//@description The message pinned state was changed @chat_id Chat identifier @message_id The message identifier @is_pinned True, if the message is pinned
updateMessageIsPinned chat_id:int53 message_id:int53 is_pinned:Bool = Update;

//@description The information about interactions with a message has changed @chat_id Chat identifier @message_id Message identifier @interaction_info New information about interactions with the message; may be null
updateMessageInteractionInfo chat_id:int53 message_id:int53 interaction_info:messageInteractionInfo = Update;

//@description The message content was opened. Updates voice note messages to "listened", video note messages to "viewed" and starts the self-destruct timer @chat_id Chat identifier @message_id Message identifier
updateMessageContentOpened chat_id:int53 message_id:int53 = Update;

//@description A message with an unread mention was read @chat_id Chat identifier @message_id Message identifier @unread_mention_count The new number of unread mention messages left in the chat
updateMessageMentionRead chat_id:int53 message_id:int53 unread_mention_count:int32 = Update;

//@description The list of unread reactions added to a message was changed
//@chat_id Chat identifier
//@message_id Message identifier
//@unread_reactions The new list of unread reactions
//@unread_reaction_count The new number of messages with unread reactions left in the chat
updateMessageUnreadReactions chat_id:int53 message_id:int53 unread_reactions:vector<unreadReaction> unread_reaction_count:int32 = Update;

//@description A fact-check added to a message was changed
//@chat_id Chat identifier
//@message_id Message identifier
//@fact_check The new fact-check
updateMessageFactCheck chat_id:int53 message_id:int53 fact_check:factCheck = Update;

//@description A message with a live location was viewed. When the update is received, the application is expected to update the live location
//@chat_id Identifier of the chat with the live location message
//@message_id Identifier of the message with live location
updateMessageLiveLocationViewed chat_id:int53 message_id:int53 = Update;

//@description An automatically scheduled message with video has been successfully sent after conversion
//@chat_id Identifier of the chat with the message
//@message_id Identifier of the sent message
updateVideoPublished chat_id:int53 message_id:int53 = Update;

//@description A new chat has been loaded/created. This update is guaranteed to come before the chat identifier is returned to the application. The chat field changes will be reported through separate updates @chat The chat
updateNewChat chat:chat = Update;

//@description The title of a chat was changed @chat_id Chat identifier @title The new chat title
updateChatTitle chat_id:int53 title:string = Update;

//@description A chat photo was changed @chat_id Chat identifier @photo The new chat photo; may be null
updateChatPhoto chat_id:int53 photo:chatPhotoInfo = Update;

//@description Chat accent colors have changed
//@chat_id Chat identifier
//@accent_color_id The new chat accent color identifier
//@background_custom_emoji_id The new identifier of a custom emoji to be shown on the reply header and link preview background; 0 if none
//@profile_accent_color_id The new chat profile accent color identifier; -1 if none
//@profile_background_custom_emoji_id The new identifier of a custom emoji to be shown on the profile background; 0 if none
updateChatAccentColors chat_id:int53 accent_color_id:int32 background_custom_emoji_id:int64 profile_accent_color_id:int32 profile_background_custom_emoji_id:int64 = Update;

//@description Chat permissions were changed @chat_id Chat identifier @permissions The new chat permissions
updateChatPermissions chat_id:int53 permissions:chatPermissions = Update;

//@description The last message of a chat was changed
//@chat_id Chat identifier
//@last_message The new last message in the chat; may be null if the last message became unknown. While the last message is unknown, new messages can be added to the chat without corresponding updateNewMessage update
//@positions The new chat positions in the chat lists
updateChatLastMessage chat_id:int53 last_message:message positions:vector<chatPosition> = Update;

//@description The position of a chat in a chat list has changed. An updateChatLastMessage or updateChatDraftMessage update might be sent instead of the update
//@chat_id Chat identifier
//@position New chat position. If new order is 0, then the chat needs to be removed from the list
updateChatPosition chat_id:int53 position:chatPosition = Update;

//@description A chat was added to a chat list @chat_id Chat identifier @chat_list The chat list to which the chat was added
updateChatAddedToList chat_id:int53 chat_list:ChatList = Update;

//@description A chat was removed from a chat list @chat_id Chat identifier @chat_list The chat list from which the chat was removed
updateChatRemovedFromList chat_id:int53 chat_list:ChatList = Update;

//@description Incoming messages were read or the number of unread messages has been changed @chat_id Chat identifier @last_read_inbox_message_id Identifier of the last read incoming message @unread_count The number of unread messages left in the chat
updateChatReadInbox chat_id:int53 last_read_inbox_message_id:int53 unread_count:int32 = Update;

//@description Outgoing messages were read @chat_id Chat identifier @last_read_outbox_message_id Identifier of last read outgoing message
updateChatReadOutbox chat_id:int53 last_read_outbox_message_id:int53 = Update;

//@description The chat action bar was changed @chat_id Chat identifier @action_bar The new value of the action bar; may be null
updateChatActionBar chat_id:int53 action_bar:ChatActionBar = Update;

//@description The bar for managing business bot was changed in a chat @chat_id Chat identifier @business_bot_manage_bar The new value of the business bot manage bar; may be null
updateChatBusinessBotManageBar chat_id:int53 business_bot_manage_bar:businessBotManageBar = Update;

//@description The chat available reactions were changed @chat_id Chat identifier @available_reactions The new reactions, available in the chat
updateChatAvailableReactions chat_id:int53 available_reactions:ChatAvailableReactions = Update;

//@description A chat draft has changed. Be aware that the update may come in the currently opened chat but with old content of the draft. If the user has changed the content of the draft, this update mustn't be applied
//@chat_id Chat identifier
//@draft_message The new draft message; may be null if none
//@positions The new chat positions in the chat lists
updateChatDraftMessage chat_id:int53 draft_message:draftMessage positions:vector<chatPosition> = Update;

//@description Chat emoji status has changed
//@chat_id Chat identifier
//@emoji_status The new chat emoji status; may be null
updateChatEmojiStatus chat_id:int53 emoji_status:emojiStatus = Update;

//@description The message sender that is selected to send messages in a chat has changed @chat_id Chat identifier @message_sender_id New value of message_sender_id; may be null if the user can't change message sender
updateChatMessageSender chat_id:int53 message_sender_id:MessageSender = Update;

//@description The message auto-delete or self-destruct timer setting for a chat was changed @chat_id Chat identifier @message_auto_delete_time New value of message_auto_delete_time
updateChatMessageAutoDeleteTime chat_id:int53 message_auto_delete_time:int32 = Update;

//@description Notification settings for a chat were changed @chat_id Chat identifier @notification_settings The new notification settings
updateChatNotificationSettings chat_id:int53 notification_settings:chatNotificationSettings = Update;

//@description The chat pending join requests were changed @chat_id Chat identifier @pending_join_requests The new data about pending join requests; may be null
updateChatPendingJoinRequests chat_id:int53 pending_join_requests:chatJoinRequestsInfo = Update;

//@description The default chat reply markup was changed. Can occur because new messages with reply markup were received or because an old reply markup was hidden by the user
//@chat_id Chat identifier
//@reply_markup_message_id Identifier of the message from which reply markup needs to be used; 0 if there is no default custom reply markup in the chat
updateChatReplyMarkup chat_id:int53 reply_markup_message_id:int53 = Update;

//@description The chat background was changed @chat_id Chat identifier @background The new chat background; may be null if background was reset to default
updateChatBackground chat_id:int53 background:chatBackground = Update;

//@description The chat theme was changed @chat_id Chat identifier @theme_name The new name of the chat theme; may be empty if theme was reset to default
updateChatTheme chat_id:int53 theme_name:string = Update;

//@description The chat unread_mention_count has changed @chat_id Chat identifier @unread_mention_count The number of unread mention messages left in the chat
updateChatUnreadMentionCount chat_id:int53 unread_mention_count:int32 = Update;

//@description The chat unread_reaction_count has changed @chat_id Chat identifier @unread_reaction_count The number of messages with unread reactions left in the chat
updateChatUnreadReactionCount chat_id:int53 unread_reaction_count:int32 = Update;

//@description A chat video chat state has changed @chat_id Chat identifier @video_chat New value of video_chat
updateChatVideoChat chat_id:int53 video_chat:videoChat = Update;

//@description The value of the default disable_notification parameter, used when a message is sent to the chat, was changed @chat_id Chat identifier @default_disable_notification The new default_disable_notification value
updateChatDefaultDisableNotification chat_id:int53 default_disable_notification:Bool = Update;

//@description A chat content was allowed or restricted for saving @chat_id Chat identifier @has_protected_content New value of has_protected_content
updateChatHasProtectedContent chat_id:int53 has_protected_content:Bool = Update;

//@description Translation of chat messages was enabled or disabled @chat_id Chat identifier @is_translatable New value of is_translatable
updateChatIsTranslatable chat_id:int53 is_translatable:Bool = Update;

//@description A chat was marked as unread or was read @chat_id Chat identifier @is_marked_as_unread New value of is_marked_as_unread
updateChatIsMarkedAsUnread chat_id:int53 is_marked_as_unread:Bool = Update;

//@description A chat default appearance has changed @chat_id Chat identifier @view_as_topics New value of view_as_topics
updateChatViewAsTopics chat_id:int53 view_as_topics:Bool = Update;

//@description A chat was blocked or unblocked @chat_id Chat identifier @block_list Block list to which the chat is added; may be null if none
updateChatBlockList chat_id:int53 block_list:BlockList = Update;

//@description A chat's has_scheduled_messages field has changed @chat_id Chat identifier @has_scheduled_messages New value of has_scheduled_messages
updateChatHasScheduledMessages chat_id:int53 has_scheduled_messages:Bool = Update;

//@description The list of chat folders or a chat folder has changed
//@chat_folders The new list of chat folders
//@main_chat_list_position Position of the main chat list among chat folders, 0-based
//@are_tags_enabled True, if folder tags are enabled
updateChatFolders chat_folders:vector<chatFolderInfo> main_chat_list_position:int32 are_tags_enabled:Bool = Update;

//@description The number of online group members has changed. This update with non-zero number of online group members is sent only for currently opened chats.
//-There is no guarantee that it is sent just after the number of online users has changed
//@chat_id Identifier of the chat
//@online_member_count New number of online members in the chat, or 0 if unknown
updateChatOnlineMemberCount chat_id:int53 online_member_count:int32 = Update;

//@description Basic information about a Saved Messages topic has changed. This update is guaranteed to come before the topic identifier is returned to the application
//@topic New data about the topic
updateSavedMessagesTopic topic:savedMessagesTopic = Update;

//@description Number of Saved Messages topics has changed @topic_count Approximate total number of Saved Messages topics
updateSavedMessagesTopicCount topic_count:int32 = Update;

//@description Basic information about a quick reply shortcut has changed. This update is guaranteed to come before the quick shortcut name is returned to the application
//@shortcut New data about the shortcut
updateQuickReplyShortcut shortcut:quickReplyShortcut = Update;

//@description A quick reply shortcut and all its messages were deleted @shortcut_id The identifier of the deleted shortcut
updateQuickReplyShortcutDeleted shortcut_id:int32 = Update;

//@description The list of quick reply shortcuts has changed @shortcut_ids The new list of identifiers of quick reply shortcuts
updateQuickReplyShortcuts shortcut_ids:vector<int32> = Update;

//@description The list of quick reply shortcut messages has changed
//@shortcut_id The identifier of the shortcut
//@messages The new list of quick reply messages for the shortcut in order from the first to the last sent
updateQuickReplyShortcutMessages shortcut_id:int32 messages:vector<quickReplyMessage> = Update;

//@description Basic information about a topic in a forum chat was changed @chat_id Chat identifier @info New information about the topic
updateForumTopicInfo chat_id:int53 info:forumTopicInfo = Update;

//@description Notification settings for some type of chats were updated @scope Types of chats for which notification settings were updated @notification_settings The new notification settings
updateScopeNotificationSettings scope:NotificationSettingsScope notification_settings:scopeNotificationSettings = Update;

//@description Notification settings for reactions were updated @notification_settings The new notification settings
updateReactionNotificationSettings notification_settings:reactionNotificationSettings = Update;

//@description A notification was changed @notification_group_id Unique notification group identifier @notification Changed notification
updateNotification notification_group_id:int32 notification:notification = Update;

//@description A list of active notifications in a notification group has changed
//@notification_group_id Unique notification group identifier
//@type New type of the notification group
//@chat_id Identifier of a chat to which all notifications in the group belong
//@notification_settings_chat_id Chat identifier, which notification settings must be applied to the added notifications
//@notification_sound_id Identifier of the notification sound to be played; 0 if sound is disabled
//@total_count Total number of unread notifications in the group, can be bigger than number of active notifications
//@added_notifications List of added group notifications, sorted by notification identifier
//@removed_notification_ids Identifiers of removed group notifications, sorted by notification identifier
updateNotificationGroup notification_group_id:int32 type:NotificationGroupType chat_id:int53 notification_settings_chat_id:int53 notification_sound_id:int64 total_count:int32 added_notifications:vector<notification> removed_notification_ids:vector<int32> = Update;

//@description Contains active notifications that were shown on previous application launches. This update is sent only if the message database is used. In that case it comes once before any updateNotification and updateNotificationGroup update @groups Lists of active notification groups
updateActiveNotifications groups:vector<notificationGroup> = Update;

//@description Describes whether there are some pending notification updates. Can be used to prevent application from killing, while there are some pending notifications
//@have_delayed_notifications True, if there are some delayed notification updates, which will be sent soon
//@have_unreceived_notifications True, if there can be some yet unreceived notifications, which are being fetched from the server
updateHavePendingNotifications have_delayed_notifications:Bool have_unreceived_notifications:Bool = Update;

//@description Some messages were deleted
//@chat_id Chat identifier
//@message_ids Identifiers of the deleted messages
//@is_permanent True, if the messages are permanently deleted by a user (as opposed to just becoming inaccessible)
//@from_cache True, if the messages are deleted only from the cache and can possibly be retrieved again in the future
updateDeleteMessages chat_id:int53 message_ids:vector<int53> is_permanent:Bool from_cache:Bool = Update;

//@description A message sender activity in the chat has changed
//@chat_id Chat identifier
//@message_thread_id If not 0, the message thread identifier in which the action was performed
//@sender_id Identifier of a message sender performing the action
//@action The action
updateChatAction chat_id:int53 message_thread_id:int53 sender_id:MessageSender action:ChatAction = Update;

//@description The user went online or offline @user_id User identifier @status New status of the user
updateUserStatus user_id:int53 status:UserStatus = Update;

//@description Some data of a user has changed. This update is guaranteed to come before the user identifier is returned to the application @user New data about the user
updateUser user:user = Update;

//@description Some data of a basic group has changed. This update is guaranteed to come before the basic group identifier is returned to the application @basic_group New data about the group
updateBasicGroup basic_group:basicGroup = Update;

//@description Some data of a supergroup or a channel has changed. This update is guaranteed to come before the supergroup identifier is returned to the application @supergroup New data about the supergroup
updateSupergroup supergroup:supergroup = Update;

//@description Some data of a secret chat has changed. This update is guaranteed to come before the secret chat identifier is returned to the application @secret_chat New data about the secret chat
updateSecretChat secret_chat:secretChat = Update;

//@description Some data in userFullInfo has been changed @user_id User identifier @user_full_info New full information about the user
updateUserFullInfo user_id:int53 user_full_info:userFullInfo = Update;

//@description Some data in basicGroupFullInfo has been changed @basic_group_id Identifier of a basic group @basic_group_full_info New full information about the group
updateBasicGroupFullInfo basic_group_id:int53 basic_group_full_info:basicGroupFullInfo = Update;

//@description Some data in supergroupFullInfo has been changed @supergroup_id Identifier of the supergroup or channel @supergroup_full_info New full information about the supergroup
updateSupergroupFullInfo supergroup_id:int53 supergroup_full_info:supergroupFullInfo = Update;

//@description A service notification from the server was received. Upon receiving this the application must show a popup with the content of the notification
//@type Notification type. If type begins with "AUTH_KEY_DROP_", then two buttons "Cancel" and "Log out" must be shown under notification; if user presses the second, all local data must be destroyed using Destroy method
//@content Notification content
updateServiceNotification type:string content:MessageContent = Update;

//@description Information about a file was updated @file New data about the file
updateFile file:file = Update;

//@description The file generation process needs to be started by the application. Use setFileGenerationProgress and finishFileGeneration to generate the file
//@generation_id Unique identifier for the generation process
//@original_path The original path specified by the application in inputFileGenerated
//@destination_path The path to a file that must be created and where the new file must be generated by the application.
//-If the application has no access to the path, it can use writeGeneratedFilePart to generate the file
//@conversion If the conversion is "#url#" than original_path contains an HTTP/HTTPS URL of a file that must be downloaded by the application.
//-Otherwise, this is the conversion specified by the application in inputFileGenerated
updateFileGenerationStart generation_id:int64 original_path:string destination_path:string conversion:string = Update;

//@description File generation is no longer needed @generation_id Unique identifier for the generation process
updateFileGenerationStop generation_id:int64 = Update;

//@description The state of the file download list has changed
//@total_size Total size of files in the file download list, in bytes
//@total_count Total number of files in the file download list
//@downloaded_size Total downloaded size of files in the file download list, in bytes
updateFileDownloads total_size:int53 total_count:int32 downloaded_size:int53 = Update;

//@description A file was added to the file download list. This update is sent only after file download list is loaded for the first time @file_download The added file download @counts New number of being downloaded and recently downloaded files found
updateFileAddedToDownloads file_download:fileDownload counts:downloadedFileCounts = Update;

//@description A file download was changed. This update is sent only after file download list is loaded for the first time
//@file_id File identifier
//@complete_date Point in time (Unix timestamp) when the file downloading was completed; 0 if the file downloading isn't completed
//@is_paused True, if downloading of the file is paused
//@counts New number of being downloaded and recently downloaded files found
updateFileDownload file_id:int32 complete_date:int32 is_paused:Bool counts:downloadedFileCounts = Update;

//@description A file was removed from the file download list. This update is sent only after file download list is loaded for the first time @file_id File identifier @counts New number of being downloaded and recently downloaded files found
updateFileRemovedFromDownloads file_id:int32 counts:downloadedFileCounts = Update;

//@description A request can't be completed unless application verification is performed; for official mobile applications only.
//-The method setApplicationVerificationToken must be called once the verification is completed or failed
//@verification_id Unique identifier for the verification process
//@nonce Unique base64url-encoded nonce for the classic Play Integrity verification (https://developer.android.com/google/play/integrity/classic) for Android,
//-or a unique string to compare with verify_nonce field from a push notification for iOS
//@cloud_project_number Cloud project number to pass to the Play Integrity API on Android
updateApplicationVerificationRequired verification_id:int53 nonce:string cloud_project_number:int64 = Update;

//@description A request can't be completed unless reCAPTCHA verification is performed; for official mobile applications only.
//-The method setApplicationVerificationToken must be called once the verification is completed or failed
//@verification_id Unique identifier for the verification process
//@action The action for the check
//@recaptcha_key_id Identifier of the reCAPTCHA key
updateApplicationRecaptchaVerificationRequired verification_id:int53 action:string recaptcha_key_id:string = Update;

//@description New call was created or information about a call was updated @call New data about a call
updateCall call:call = Update;

//@description Information about a group call was updated @group_call New data about a group call
updateGroupCall group_call:groupCall = Update;

//@description Information about a group call participant was changed. The updates are sent only after the group call is received through getGroupCall and only if the call is joined or being joined
//@group_call_id Identifier of group call
//@participant New data about a participant
updateGroupCallParticipant group_call_id:int32 participant:groupCallParticipant = Update;

//@description New call signaling data arrived @call_id The call identifier @data The data
updateNewCallSignalingData call_id:int32 data:bytes = Update;

//@description Some privacy setting rules have been changed @setting The privacy setting @rules New privacy rules
updateUserPrivacySettingRules setting:UserPrivacySetting rules:userPrivacySettingRules = Update;

//@description Number of unread messages in a chat list has changed. This update is sent only if the message database is used
//@chat_list The chat list with changed number of unread messages
//@unread_count Total number of unread messages
//@unread_unmuted_count Total number of unread messages in unmuted chats
updateUnreadMessageCount chat_list:ChatList unread_count:int32 unread_unmuted_count:int32 = Update;

//@description Number of unread chats, i.e. with unread messages or marked as unread, has changed. This update is sent only if the message database is used
//@chat_list The chat list with changed number of unread messages
//@total_count Approximate total number of chats in the chat list
//@unread_count Total number of unread chats
//@unread_unmuted_count Total number of unread unmuted chats
//@marked_as_unread_count Total number of chats marked as unread
//@marked_as_unread_unmuted_count Total number of unmuted chats marked as unread
updateUnreadChatCount chat_list:ChatList total_count:int32 unread_count:int32 unread_unmuted_count:int32 marked_as_unread_count:int32 marked_as_unread_unmuted_count:int32 = Update;

//@description A story was changed @story The new information about the story
updateStory story:story = Update;

//@description A story became inaccessible @story_sender_chat_id Identifier of the chat that posted the story @story_id Story identifier
updateStoryDeleted story_sender_chat_id:int53 story_id:int32 = Update;

//@description A story has been successfully sent @story The sent story @old_story_id The previous temporary story identifier
updateStorySendSucceeded story:story old_story_id:int32 = Update;

//@description A story failed to send. If the story sending is canceled, then updateStoryDeleted will be received instead of this update
//@story The failed to send story
//@error The cause of the story sending failure
//@error_type Type of the error; may be null if unknown
updateStorySendFailed story:story error:error error_type:CanSendStoryResult = Update;

//@description The list of active stories posted by a specific chat has changed
//@active_stories The new list of active stories
updateChatActiveStories active_stories:chatActiveStories = Update;

//@description Number of chats in a story list has changed @story_list The story list @chat_count Approximate total number of chats with active stories in the list
updateStoryListChatCount story_list:StoryList chat_count:int32 = Update;

//@description Story stealth mode settings have changed
//@active_until_date Point in time (Unix timestamp) until stealth mode is active; 0 if it is disabled
//@cooldown_until_date Point in time (Unix timestamp) when stealth mode can be enabled again; 0 if there is no active cooldown
updateStoryStealthMode active_until_date:int32 cooldown_until_date:int32 = Update;

//@description An option changed its value @name The option name @value The new option value
updateOption name:string value:OptionValue = Update;

//@description A sticker set has changed @sticker_set The sticker set
updateStickerSet sticker_set:stickerSet = Update;

//@description The list of installed sticker sets was updated @sticker_type Type of the affected stickers @sticker_set_ids The new list of installed ordinary sticker sets
updateInstalledStickerSets sticker_type:StickerType sticker_set_ids:vector<int64> = Update;

//@description The list of trending sticker sets was updated or some of them were viewed @sticker_type Type of the affected stickers @sticker_sets The prefix of the list of trending sticker sets with the newest trending sticker sets
updateTrendingStickerSets sticker_type:StickerType sticker_sets:trendingStickerSets = Update;

//@description The list of recently used stickers was updated @is_attached True, if the list of stickers attached to photo or video files was updated; otherwise, the list of sent stickers is updated @sticker_ids The new list of file identifiers of recently used stickers
updateRecentStickers is_attached:Bool sticker_ids:vector<int32> = Update;

//@description The list of favorite stickers was updated @sticker_ids The new list of file identifiers of favorite stickers
updateFavoriteStickers sticker_ids:vector<int32> = Update;

//@description The list of saved animations was updated @animation_ids The new list of file identifiers of saved animations
updateSavedAnimations animation_ids:vector<int32> = Update;

//@description The list of saved notification sounds was updated. This update may not be sent until information about a notification sound was requested for the first time @notification_sound_ids The new list of identifiers of saved notification sounds
updateSavedNotificationSounds notification_sound_ids:vector<int64> = Update;

//@description The default background has changed @for_dark_theme True, if default background for dark theme has changed @background The new default background; may be null
updateDefaultBackground for_dark_theme:Bool background:background = Update;

//@description The list of available chat themes has changed @chat_themes The new list of chat themes
updateChatThemes chat_themes:vector<chatTheme> = Update;

//@description The list of supported accent colors has changed
//@colors Information about supported colors; colors with identifiers 0 (red), 1 (orange), 2 (purple/violet), 3 (green), 4 (cyan), 5 (blue), 6 (pink) must always be supported
//-and aren't included in the list. The exact colors for the accent colors with identifiers 0-6 must be taken from the app theme
//@available_accent_color_ids The list of accent color identifiers, which can be set through setAccentColor and setChatAccentColor. The colors must be shown in the specified order
updateAccentColors colors:vector<accentColor> available_accent_color_ids:vector<int32> = Update;

//@description The list of supported accent colors for user profiles has changed
//@colors Information about supported colors
//@available_accent_color_ids The list of accent color identifiers, which can be set through setProfileAccentColor and setChatProfileAccentColor. The colors must be shown in the specified order
updateProfileAccentColors colors:vector<profileAccentColor> available_accent_color_ids:vector<int32> = Update;

//@description Some language pack strings have been updated @localization_target Localization target to which the language pack belongs @language_pack_id Identifier of the updated language pack @strings List of changed language pack strings; empty if all strings have changed
updateLanguagePackStrings localization_target:string language_pack_id:string strings:vector<languagePackString> = Update;

//@description The connection state has changed. This update must be used only to show a human-readable description of the connection state @state The new connection state
updateConnectionState state:ConnectionState = Update;

//@description New terms of service must be accepted by the user. If the terms of service are declined, then the deleteAccount method must be called with the reason "Decline ToS update" @terms_of_service_id Identifier of the terms of service @terms_of_service The new terms of service
updateTermsOfService terms_of_service_id:string terms_of_service:termsOfService = Update;

//@description The first unconfirmed session has changed @session The unconfirmed session; may be null if none
updateUnconfirmedSession session:unconfirmedSession = Update;

//@description The list of bots added to attachment or side menu has changed @bots The new list of bots. The bots must not be shown on scheduled messages screen
updateAttachmentMenuBots bots:vector<attachmentMenuBot> = Update;

//@description A message was sent by an opened Web App, so the Web App needs to be closed @web_app_launch_id Identifier of Web App launch
updateWebAppMessageSent web_app_launch_id:int64 = Update;

//@description The list of active emoji reactions has changed @emojis The new list of active emoji reactions
updateActiveEmojiReactions emojis:vector<string> = Update;

//@description The list of available message effects has changed
//@reaction_effect_ids The new list of available message effects from emoji reactions
//@sticker_effect_ids The new list of available message effects from Premium stickers
updateAvailableMessageEffects reaction_effect_ids:vector<int64> sticker_effect_ids:vector<int64> = Update;

//@description The type of default reaction has changed @reaction_type The new type of the default reaction
updateDefaultReactionType reaction_type:ReactionType = Update;

//@description The type of default paid reaction has changed @type The new type of the default paid reaction
updateDefaultPaidReactionType type:PaidReactionType = Update;

//@description Tags used in Saved Messages or a Saved Messages topic have changed
//@saved_messages_topic_id Identifier of Saved Messages topic which tags were changed; 0 if tags for the whole chat has changed
//@tags The new tags
updateSavedMessagesTags saved_messages_topic_id:int53 tags:savedMessagesTags = Update;

//@description The list of messages with active live location that need to be updated by the application has changed. The list is persistent across application restarts only if the message database is used
//@messages The list of messages with active live locations
updateActiveLiveLocationMessages messages:vector<message> = Update;

//@description The number of Telegram Stars owned by the current user has changed @star_amount The new amount of owned Telegram Stars
updateOwnedStarCount star_amount:starAmount = Update;

//@description The revenue earned from sponsored messages in a chat has changed. If chat revenue screen is opened, then getChatRevenueTransactions may be called to fetch new transactions
//@chat_id Identifier of the chat
//@revenue_amount New amount of earned revenue
updateChatRevenueAmount chat_id:int53 revenue_amount:chatRevenueAmount = Update;

//@description The Telegram Star revenue earned by a bot or a chat has changed. If Telegram Star transaction screen of the chat is opened, then getStarTransactions may be called to fetch new transactions
//@owner_id Identifier of the owner of the Telegram Stars
//@status New Telegram Star revenue status
updateStarRevenueStatus owner_id:MessageSender status:starRevenueStatus = Update;

//@description The parameters of speech recognition without Telegram Premium subscription has changed
//@max_media_duration The maximum allowed duration of media for speech recognition without Telegram Premium subscription, in seconds
//@weekly_count The total number of allowed speech recognitions per week; 0 if none
//@left_count Number of left speech recognition attempts this week
//@next_reset_date Point in time (Unix timestamp) when the weekly number of tries will reset; 0 if unknown
updateSpeechRecognitionTrial max_media_duration:int32 weekly_count:int32 left_count:int32 next_reset_date:int32 = Update;

//@description The list of supported dice emojis has changed @emojis The new list of supported dice emojis
updateDiceEmojis emojis:vector<string> = Update;

//@description Some animated emoji message was clicked and a big animated sticker must be played if the message is visible on the screen. chatActionWatchingAnimations with the text of the message needs to be sent if the sticker is played
//@chat_id Chat identifier
//@message_id Message identifier
//@sticker The animated sticker to be played
updateAnimatedEmojiMessageClicked chat_id:int53 message_id:int53 sticker:sticker = Update;

//@description The parameters of animation search through getOption("animation_search_bot_username") bot has changed @provider Name of the animation search provider @emojis The new list of emojis suggested for searching
updateAnimationSearchParameters provider:string emojis:vector<string> = Update;

//@description The list of suggested to the user actions has changed @added_actions Added suggested actions @removed_actions Removed suggested actions
updateSuggestedActions added_actions:vector<SuggestedAction> removed_actions:vector<SuggestedAction> = Update;

//@description Download or upload file speed for the user was limited, but it can be restored by subscription to Telegram Premium. The notification can be postponed until a being downloaded or uploaded file is visible to the user.
//-Use getOption("premium_download_speedup") or getOption("premium_upload_speedup") to get expected speedup after subscription to Telegram Premium
//@is_upload True, if upload speed was limited; false, if download speed was limited
updateSpeedLimitNotification is_upload:Bool = Update;

//@description The list of contacts that had birthdays recently or will have birthday soon has changed @close_birthday_users List of contact users with close birthday
updateContactCloseBirthdays close_birthday_users:vector<closeBirthdayUser> = Update;

//@description Autosave settings for some type of chats were updated @scope Type of chats for which autosave settings were updated @settings The new autosave settings; may be null if the settings are reset to default
updateAutosaveSettings scope:AutosaveSettingsScope settings:scopeAutosaveSettings = Update;

//@description A business connection has changed; for bots only @connection New data about the connection
updateBusinessConnection connection:businessConnection = Update;

//@description A new message was added to a business account; for bots only @connection_id Unique identifier of the business connection @message The new message
updateNewBusinessMessage connection_id:string message:businessMessage = Update;

//@description A message in a business account was edited; for bots only @connection_id Unique identifier of the business connection @message The edited message
updateBusinessMessageEdited connection_id:string message:businessMessage = Update;

//@description Messages in a business account were deleted; for bots only
//@connection_id Unique identifier of the business connection
//@chat_id Identifier of a chat in the business account in which messages were deleted
//@message_ids Unique message identifiers of the deleted messages
updateBusinessMessagesDeleted connection_id:string chat_id:int53 message_ids:vector<int53> = Update;

//@description A new incoming inline query; for bots only
//@id Unique query identifier
//@sender_user_id Identifier of the user who sent the query
//@user_location User location; may be null
//@chat_type The type of the chat from which the query originated; may be null if unknown
//@query Text of the query
//@offset Offset of the first entry to return
updateNewInlineQuery id:int64 sender_user_id:int53 user_location:location chat_type:ChatType query:string offset:string = Update;

//@description The user has chosen a result of an inline query; for bots only
//@sender_user_id Identifier of the user who sent the query
//@user_location User location; may be null
//@query Text of the query
//@result_id Identifier of the chosen result
//@inline_message_id Identifier of the sent inline message, if known
updateNewChosenInlineResult sender_user_id:int53 user_location:location query:string result_id:string inline_message_id:string = Update;

//@description A new incoming callback query; for bots only
//@id Unique query identifier
//@sender_user_id Identifier of the user who sent the query
//@chat_id Identifier of the chat where the query was sent
//@message_id Identifier of the message from which the query originated
//@chat_instance Identifier that uniquely corresponds to the chat to which the message was sent
//@payload Query payload
updateNewCallbackQuery id:int64 sender_user_id:int53 chat_id:int53 message_id:int53 chat_instance:int64 payload:CallbackQueryPayload = Update;

//@description A new incoming callback query from a message sent via a bot; for bots only
//@id Unique query identifier
//@sender_user_id Identifier of the user who sent the query
//@inline_message_id Identifier of the inline message from which the query originated
//@chat_instance An identifier uniquely corresponding to the chat a message was sent to
//@payload Query payload
updateNewInlineCallbackQuery id:int64 sender_user_id:int53 inline_message_id:string chat_instance:int64 payload:CallbackQueryPayload = Update;

//@description A new incoming callback query from a business message; for bots only
//@id Unique query identifier
//@sender_user_id Identifier of the user who sent the query
//@connection_id Unique identifier of the business connection
//@message The message from the business account from which the query originated
//@chat_instance An identifier uniquely corresponding to the chat a message was sent to
//@payload Query payload
updateNewBusinessCallbackQuery id:int64 sender_user_id:int53 connection_id:string message:businessMessage chat_instance:int64 payload:CallbackQueryPayload = Update;

//@description A new incoming shipping query; for bots only. Only for invoices with flexible price
//@id Unique query identifier
//@sender_user_id Identifier of the user who sent the query
//@invoice_payload Invoice payload
//@shipping_address User shipping address
updateNewShippingQuery id:int64 sender_user_id:int53 invoice_payload:string shipping_address:address = Update;

//@description A new incoming pre-checkout query; for bots only. Contains full information about a checkout
//@id Unique query identifier
//@sender_user_id Identifier of the user who sent the query
//@currency Currency for the product price
//@total_amount Total price for the product, in the smallest units of the currency
//@invoice_payload Invoice payload
//@shipping_option_id Identifier of a shipping option chosen by the user; may be empty if not applicable
//@order_info Information about the order; may be null
updateNewPreCheckoutQuery id:int64 sender_user_id:int53 currency:string total_amount:int53 invoice_payload:bytes shipping_option_id:string order_info:orderInfo = Update;

//@description A new incoming event; for bots only @event A JSON-serialized event
updateNewCustomEvent event:string = Update;

//@description A new incoming query; for bots only @id The query identifier @data JSON-serialized query data @timeout Query timeout
updateNewCustomQuery id:int64 data:string timeout:int32 = Update;

//@description A poll was updated; for bots only @poll New data about the poll
updatePoll poll:poll = Update;

//@description A user changed the answer to a poll; for bots only
//@poll_id Unique poll identifier
//@voter_id Identifier of the message sender that changed the answer to the poll
//@option_ids 0-based identifiers of answer options, chosen by the user
updatePollAnswer poll_id:int64 voter_id:MessageSender option_ids:vector<int32> = Update;

//@description User rights changed in a chat; for bots only
//@chat_id Chat identifier
//@actor_user_id Identifier of the user, changing the rights
//@date Point in time (Unix timestamp) when the user rights were changed
//@invite_link If user has joined the chat using an invite link, the invite link; may be null
//@via_join_request True, if the user has joined the chat after sending a join request and being approved by an administrator
//@via_chat_folder_invite_link True, if the user has joined the chat using an invite link for a chat folder
//@old_chat_member Previous chat member
//@new_chat_member New chat member
updateChatMember chat_id:int53 actor_user_id:int53 date:int32 invite_link:chatInviteLink via_join_request:Bool via_chat_folder_invite_link:Bool old_chat_member:chatMember new_chat_member:chatMember = Update;

//@description A user sent a join request to a chat; for bots only
//@chat_id Chat identifier
//@request Join request
//@user_chat_id Chat identifier of the private chat with the user
//@invite_link The invite link, which was used to send join request; may be null
updateNewChatJoinRequest chat_id:int53 request:chatJoinRequest user_chat_id:int53 invite_link:chatInviteLink = Update;

//@description A chat boost has changed; for bots only
//@chat_id Chat identifier
//@boost New information about the boost
updateChatBoost chat_id:int53 boost:chatBoost = Update;

//@description User changed its reactions on a message with public reactions; for bots only
//@chat_id Chat identifier
//@message_id Message identifier
//@actor_id Identifier of the user or chat that changed reactions
//@date Point in time (Unix timestamp) when the reactions were changed
//@old_reaction_types Old list of chosen reactions
//@new_reaction_types New list of chosen reactions
updateMessageReaction chat_id:int53 message_id:int53 actor_id:MessageSender date:int32 old_reaction_types:vector<ReactionType> new_reaction_types:vector<ReactionType> = Update;

//@description Reactions added to a message with anonymous reactions have changed; for bots only
//@chat_id Chat identifier
//@message_id Message identifier
//@date Point in time (Unix timestamp) when the reactions were changed
//@reactions The list of reactions added to the message
updateMessageReactions chat_id:int53 message_id:int53 date:int32 reactions:vector<messageReaction> = Update;

//@description Paid media were purchased by a user; for bots only
//@user_id User identifier
//@payload Bot-specified payload for the paid media
updatePaidMediaPurchased user_id:int53 payload:string = Update;


//@description Contains a list of updates @updates List of updates
updates updates:vector<Update> = Updates;


//@class LogStream @description Describes a stream to which TDLib internal log is written

//@description The log is written to stderr or an OS specific log
logStreamDefault = LogStream;

//@description The log is written to a file
//@path Path to the file to where the internal TDLib log will be written
//@max_file_size The maximum size of the file to where the internal TDLib log is written before the file will automatically be rotated, in bytes
//@redirect_stderr Pass true to additionally redirect stderr to the log file. Ignored on Windows
logStreamFile path:string max_file_size:int53 redirect_stderr:Bool = LogStream;

//@description The log is written nowhere
logStreamEmpty = LogStream;


//@description Contains a TDLib internal log verbosity level @verbosity_level Log verbosity level
logVerbosityLevel verbosity_level:int32 = LogVerbosityLevel;

//@description Contains a list of available TDLib internal log tags @tags List of log tags
logTags tags:vector<string> = LogTags;


//@description Contains custom information about the user @message Information message @author Information author @date Information change date
userSupportInfo message:formattedText author:string date:int32 = UserSupportInfo;


//@description A simple object containing a number; for testing only @value Number
testInt value:int32 = TestInt;
//@description A simple object containing a string; for testing only @value String
testString value:string = TestString;
//@description A simple object containing a sequence of bytes; for testing only @value Bytes
testBytes value:bytes = TestBytes;
//@description A simple object containing a vector of numbers; for testing only @value Vector of numbers
testVectorInt value:vector<int32> = TestVectorInt;
//@description A simple object containing a vector of objects that hold a number; for testing only @value Vector of objects
testVectorIntObject value:vector<testInt> = TestVectorIntObject;
//@description A simple object containing a vector of strings; for testing only @value Vector of strings
testVectorString value:vector<string> = TestVectorString;
//@description A simple object containing a vector of objects that hold a string; for testing only @value Vector of objects
testVectorStringObject value:vector<testString> = TestVectorStringObject;

---functions---

//@description Returns the current authorization state. This is an offline method. For informational purposes only. Use updateAuthorizationState instead to maintain the current authorization state. Can be called before initialization
getAuthorizationState = AuthorizationState;


//@description Sets the parameters for TDLib initialization. Works only when the current authorization state is authorizationStateWaitTdlibParameters
//@use_test_dc Pass true to use Telegram test environment instead of the production environment
//@database_directory The path to the directory for the persistent database; if empty, the current working directory will be used
//@files_directory The path to the directory for storing files; if empty, database_directory will be used
//@database_encryption_key Encryption key for the database. If the encryption key is invalid, then an error with code 401 will be returned
//@use_file_database Pass true to keep information about downloaded and uploaded files between application restarts
//@use_chat_info_database Pass true to keep cache of users, basic groups, supergroups, channels and secret chats between restarts. Implies use_file_database
//@use_message_database Pass true to keep cache of chats and messages between restarts. Implies use_chat_info_database
//@use_secret_chats Pass true to enable support for secret chats
//@api_id Application identifier for Telegram API access, which can be obtained at https://my.telegram.org
//@api_hash Application identifier hash for Telegram API access, which can be obtained at https://my.telegram.org
//@system_language_code IETF language tag of the user's operating system language; must be non-empty
//@device_model Model of the device the application is being run on; must be non-empty
//@system_version Version of the operating system the application is being run on. If empty, the version is automatically detected by TDLib
//@application_version Application version; must be non-empty
setTdlibParameters use_test_dc:Bool database_directory:string files_directory:string database_encryption_key:bytes use_file_database:Bool use_chat_info_database:Bool use_message_database:Bool use_secret_chats:Bool api_id:int32 api_hash:string system_language_code:string device_model:string system_version:string application_version:string = Ok;

//@description Sets the phone number of the user and sends an authentication code to the user. Works only when the current authorization state is authorizationStateWaitPhoneNumber,
//-or if there is no pending authentication query and the current authorization state is authorizationStateWaitEmailAddress, authorizationStateWaitEmailCode, authorizationStateWaitCode, authorizationStateWaitRegistration, or authorizationStateWaitPassword
//@phone_number The phone number of the user, in international format
//@settings Settings for the authentication of the user's phone number; pass null to use default settings
setAuthenticationPhoneNumber phone_number:string settings:phoneNumberAuthenticationSettings = Ok;

//@description Sets the email address of the user and sends an authentication code to the email address. Works only when the current authorization state is authorizationStateWaitEmailAddress @email_address The email address of the user
setAuthenticationEmailAddress email_address:string = Ok;

//@description Resends an authentication code to the user. Works only when the current authorization state is authorizationStateWaitCode, the next_code_type of the result is not null
//-and the server-specified timeout has passed, or when the current authorization state is authorizationStateWaitEmailCode
//@reason Reason of code resending; pass null if unknown
resendAuthenticationCode reason:ResendCodeReason = Ok;

//@description Checks the authentication of an email address. Works only when the current authorization state is authorizationStateWaitEmailCode @code Email address authentication to check
checkAuthenticationEmailCode code:EmailAddressAuthentication = Ok;

//@description Checks the authentication code. Works only when the current authorization state is authorizationStateWaitCode @code Authentication code to check
checkAuthenticationCode code:string = Ok;

//@description Requests QR code authentication by scanning a QR code on another logged in device. Works only when the current authorization state is authorizationStateWaitPhoneNumber,
//-or if there is no pending authentication query and the current authorization state is authorizationStateWaitEmailAddress, authorizationStateWaitEmailCode, authorizationStateWaitCode, authorizationStateWaitRegistration, or authorizationStateWaitPassword
//@other_user_ids List of user identifiers of other users currently using the application
requestQrCodeAuthentication other_user_ids:vector<int53> = Ok;

//@description Finishes user registration. Works only when the current authorization state is authorizationStateWaitRegistration
//@first_name The first name of the user; 1-64 characters
//@last_name The last name of the user; 0-64 characters
//@disable_notification Pass true to disable notification about the current user joining Telegram for other users that added them to contact list
registerUser first_name:string last_name:string disable_notification:Bool = Ok;

//@description Resets the login email address. May return an error with a message "TASK_ALREADY_EXISTS" if reset is still pending.
//-Works only when the current authorization state is authorizationStateWaitEmailCode and authorization_state.can_reset_email_address == true
resetAuthenticationEmailAddress = Ok;

//@description Checks the 2-step verification password for correctness. Works only when the current authorization state is authorizationStateWaitPassword @password The 2-step verification password to check
checkAuthenticationPassword password:string = Ok;

//@description Requests to send a 2-step verification password recovery code to an email address that was previously set up. Works only when the current authorization state is authorizationStateWaitPassword
requestAuthenticationPasswordRecovery = Ok;

//@description Checks whether a 2-step verification password recovery code sent to an email address is valid. Works only when the current authorization state is authorizationStateWaitPassword @recovery_code Recovery code to check
checkAuthenticationPasswordRecoveryCode recovery_code:string = Ok;

//@description Recovers the 2-step verification password with a password recovery code sent to an email address that was previously set up. Works only when the current authorization state is authorizationStateWaitPassword
//@recovery_code Recovery code to check
//@new_password New 2-step verification password of the user; may be empty to remove the password
//@new_hint New password hint; may be empty
recoverAuthenticationPassword recovery_code:string new_password:string new_hint:string = Ok;

//@description Sends Firebase Authentication SMS to the phone number of the user. Works only when the current authorization state is authorizationStateWaitCode and the server returned code of the type authenticationCodeTypeFirebaseAndroid or authenticationCodeTypeFirebaseIos
//@token Play Integrity API or SafetyNet Attestation API token for the Android application, or secret from push notification for the iOS application
sendAuthenticationFirebaseSms token:string = Ok;

//@description Reports that authentication code wasn't delivered via SMS; for official mobile applications only. Works only when the current authorization state is authorizationStateWaitCode @mobile_network_code Current mobile network code
reportAuthenticationCodeMissing mobile_network_code:string = Ok;

//@description Checks the authentication token of a bot; to log in as a bot. Works only when the current authorization state is authorizationStateWaitPhoneNumber. Can be used instead of setAuthenticationPhoneNumber and checkAuthenticationCode to log in @token The bot token
checkAuthenticationBotToken token:string = Ok;

//@description Closes the TDLib instance after a proper logout. Requires an available network connection. All local data will be destroyed. After the logout completes, updateAuthorizationState with authorizationStateClosed will be sent
logOut = Ok;

//@description Closes the TDLib instance. All databases will be flushed to disk and properly closed. After the close completes, updateAuthorizationState with authorizationStateClosed will be sent. Can be called before initialization
close = Ok;

//@description Closes the TDLib instance, destroying all local data without a proper logout. The current user session will remain in the list of all active sessions. All local data will be destroyed.
//-After the destruction completes updateAuthorizationState with authorizationStateClosed will be sent. Can be called before authorization
destroy = Ok;


//@description Confirms QR code authentication on another device. Returns created session on success @link A link from a QR code. The link must be scanned by the in-app camera
confirmQrCodeAuthentication link:string = Session;


//@description Returns all updates needed to restore current TDLib state, i.e. all actual updateAuthorizationState/updateUser/updateNewChat and others. This is especially useful if TDLib is run in a separate process. Can be called before initialization
getCurrentState = Updates;


//@description Changes the database encryption key. Usually the encryption key is never changed and is stored in some OS keychain @new_encryption_key New encryption key
setDatabaseEncryptionKey new_encryption_key:bytes = Ok;


//@description Returns the current state of 2-step verification
getPasswordState = PasswordState;

//@description Changes the 2-step verification password for the current user. If a new recovery email address is specified, then the change will not be applied until the new recovery email address is confirmed
//@old_password Previous 2-step verification password of the user
//@new_password New 2-step verification password of the user; may be empty to remove the password
//@new_hint New password hint; may be empty
//@set_recovery_email_address Pass true to change also the recovery email address
//@new_recovery_email_address New recovery email address; may be empty
setPassword old_password:string new_password:string new_hint:string set_recovery_email_address:Bool new_recovery_email_address:string = PasswordState;

//@description Changes the login email address of the user. The email address can be changed only if the current user already has login email and passwordState.login_email_address_pattern is non-empty.
//-The change will not be applied until the new login email address is confirmed with checkLoginEmailAddressCode. To use Apple ID/Google ID instead of an email address, call checkLoginEmailAddressCode directly
//@new_login_email_address New login email address
setLoginEmailAddress new_login_email_address:string = EmailAddressAuthenticationCodeInfo;

//@description Resends the login email address verification code
resendLoginEmailAddressCode = EmailAddressAuthenticationCodeInfo;

//@description Checks the login email address authentication @code Email address authentication to check
checkLoginEmailAddressCode code:EmailAddressAuthentication = Ok;

//@description Returns a 2-step verification recovery email address that was previously set up. This method can be used to verify a password provided by the user @password The 2-step verification password for the current user
getRecoveryEmailAddress password:string = RecoveryEmailAddress;

//@description Changes the 2-step verification recovery email address of the user. If a new recovery email address is specified, then the change will not be applied until the new recovery email address is confirmed.
//-If new_recovery_email_address is the same as the email address that is currently set up, this call succeeds immediately and aborts all other requests waiting for an email confirmation
//@password The 2-step verification password of the current user
//@new_recovery_email_address New recovery email address
setRecoveryEmailAddress password:string new_recovery_email_address:string = PasswordState;

//@description Checks the 2-step verification recovery email address verification code @code Verification code to check
checkRecoveryEmailAddressCode code:string = PasswordState;

//@description Resends the 2-step verification recovery email address verification code
resendRecoveryEmailAddressCode = PasswordState;

//@description Cancels verification of the 2-step verification recovery email address
cancelRecoveryEmailAddressVerification = PasswordState;

//@description Requests to send a 2-step verification password recovery code to an email address that was previously set up
requestPasswordRecovery = EmailAddressAuthenticationCodeInfo;

//@description Checks whether a 2-step verification password recovery code sent to an email address is valid @recovery_code Recovery code to check
checkPasswordRecoveryCode recovery_code:string = Ok;

//@description Recovers the 2-step verification password using a recovery code sent to an email address that was previously set up
//@recovery_code Recovery code to check
//@new_password New 2-step verification password of the user; may be empty to remove the password
//@new_hint New password hint; may be empty
recoverPassword recovery_code:string new_password:string new_hint:string = PasswordState;

//@description Removes 2-step verification password without previous password and access to recovery email address. The password can't be reset immediately and the request needs to be repeated after the specified time
resetPassword = ResetPasswordResult;

//@description Cancels reset of 2-step verification password. The method can be called if passwordState.pending_reset_date > 0
cancelPasswordReset = Ok;

//@description Creates a new temporary password for processing payments @password The 2-step verification password of the current user @valid_for Time during which the temporary password will be valid, in seconds; must be between 60 and 86400
createTemporaryPassword password:string valid_for:int32 = TemporaryPasswordState;

//@description Returns information about the current temporary password
getTemporaryPasswordState = TemporaryPasswordState;


//@description Returns the current user
getMe = User;

//@description Returns information about a user by their identifier. This is an offline method if the current user is not a bot @user_id User identifier
getUser user_id:int53 = User;

//@description Returns full information about a user by their identifier @user_id User identifier
getUserFullInfo user_id:int53 = UserFullInfo;

//@description Returns information about a basic group by its identifier. This is an offline method if the current user is not a bot @basic_group_id Basic group identifier
getBasicGroup basic_group_id:int53 = BasicGroup;

//@description Returns full information about a basic group by its identifier @basic_group_id Basic group identifier
getBasicGroupFullInfo basic_group_id:int53 = BasicGroupFullInfo;

//@description Returns information about a supergroup or a channel by its identifier. This is an offline method if the current user is not a bot @supergroup_id Supergroup or channel identifier
getSupergroup supergroup_id:int53 = Supergroup;

//@description Returns full information about a supergroup or a channel by its identifier, cached for up to 1 minute @supergroup_id Supergroup or channel identifier
getSupergroupFullInfo supergroup_id:int53 = SupergroupFullInfo;

//@description Returns information about a secret chat by its identifier. This is an offline method @secret_chat_id Secret chat identifier
getSecretChat secret_chat_id:int32 = SecretChat;

//@description Returns information about a chat by its identifier. This is an offline method if the current user is not a bot @chat_id Chat identifier
getChat chat_id:int53 = Chat;

//@description Returns information about a message. Returns a 404 error if the message doesn't exist
//@chat_id Identifier of the chat the message belongs to
//@message_id Identifier of the message to get
getMessage chat_id:int53 message_id:int53 = Message;

//@description Returns information about a message, if it is available without sending network request. Returns a 404 error if message isn't available locally. This is an offline method
//@chat_id Identifier of the chat the message belongs to
//@message_id Identifier of the message to get
getMessageLocally chat_id:int53 message_id:int53 = Message;

//@description Returns information about a non-bundled message that is replied by a given message. Also, returns the pinned message, the game message, the invoice message,
//-the message with a previously set same background, the giveaway message, and the topic creation message for messages of the types
//-messagePinMessage, messageGameScore, messagePaymentSuccessful, messageChatSetBackground, messageGiveawayCompleted and topic messages without non-bundled replied message respectively.
//-Returns a 404 error if the message doesn't exist
//@chat_id Identifier of the chat the message belongs to
//@message_id Identifier of the reply message
getRepliedMessage chat_id:int53 message_id:int53 = Message;

//@description Returns information about a newest pinned message in the chat. Returns a 404 error if the message doesn't exist @chat_id Identifier of the chat the message belongs to
getChatPinnedMessage chat_id:int53 = Message;

//@description Returns information about a message with the callback button that originated a callback query; for bots only @chat_id Identifier of the chat the message belongs to @message_id Message identifier @callback_query_id Identifier of the callback query
getCallbackQueryMessage chat_id:int53 message_id:int53 callback_query_id:int64 = Message;

//@description Returns information about messages. If a message is not found, returns null on the corresponding position of the result @chat_id Identifier of the chat the messages belong to @message_ids Identifiers of the messages to get
getMessages chat_id:int53 message_ids:vector<int53> = Messages;

//@description Returns properties of a message. This is an offline method @chat_id Chat identifier @message_id Identifier of the message
getMessageProperties chat_id:int53 message_id:int53 = MessageProperties;

//@description Returns information about a message thread. Can be used only if messageProperties.can_get_message_thread == true @chat_id Chat identifier @message_id Identifier of the message
getMessageThread chat_id:int53 message_id:int53 = MessageThreadInfo;

//@description Returns read date of a recent outgoing message in a private chat. The method can be called if messageProperties.can_get_read_date == true
//@chat_id Chat identifier
//@message_id Identifier of the message
getMessageReadDate chat_id:int53 message_id:int53 = MessageReadDate;

//@description Returns viewers of a recent outgoing message in a basic group or a supergroup chat. For video notes and voice notes only users, opened content of the message, are returned. The method can be called if messageProperties.can_get_viewers == true
//@chat_id Chat identifier
//@message_id Identifier of the message
getMessageViewers chat_id:int53 message_id:int53 = MessageViewers;

//@description Returns information about a file. This is an offline method @file_id Identifier of the file to get
getFile file_id:int32 = File;

//@description Returns information about a file by its remote identifier. This is an offline method. Can be used to register a URL as a file for further uploading, or sending as a message. Even the request succeeds, the file can be used only if it is still accessible to the user.
//-For example, if the file is from a message, then the message must be not deleted and accessible to the user. If the file database is disabled, then the corresponding object with the file must be preloaded by the application
//@remote_file_id Remote identifier of the file to get
//@file_type File type; pass null if unknown
getRemoteFile remote_file_id:string file_type:FileType = File;

//@description Loads more chats from a chat list. The loaded chats and their positions in the chat list will be sent through updates. Chats are sorted by the pair (chat.position.order, chat.id) in descending order. Returns a 404 error if all chats have been loaded
//@chat_list The chat list in which to load chats; pass null to load chats from the main chat list
//@limit The maximum number of chats to be loaded. For optimal performance, the number of loaded chats is chosen by TDLib and can be smaller than the specified limit, even if the end of the list is not reached
loadChats chat_list:ChatList limit:int32 = Ok;

//@description Returns an ordered list of chats from the beginning of a chat list. For informational purposes only. Use loadChats and updates processing instead to maintain chat lists in a consistent state
//@chat_list The chat list in which to return chats; pass null to get chats from the main chat list
//@limit The maximum number of chats to be returned
getChats chat_list:ChatList limit:int32 = Chats;

//@description Searches a public chat by its username. Currently, only private chats, supergroups and channels can be public. Returns the chat if found; otherwise, an error is returned @username Username to be resolved
searchPublicChat username:string = Chat;

//@description Searches public chats by looking for specified query in their username and title. Currently, only private chats, supergroups and channels can be public. Returns a meaningful number of results.
//-Excludes private chats with contacts and chats from the chat list from the results
//@query Query to search for
searchPublicChats query:string = Chats;

//@description Searches for the specified query in the title and username of already known chats. This is an offline method. Returns chats in the order seen in the main chat list
//@query Query to search for. If the query is empty, returns up to 50 recently found chats
//@limit The maximum number of chats to be returned
searchChats query:string limit:int32 = Chats;

//@description Searches for the specified query in the title and username of already known chats via request to the server. Returns chats in the order seen in the main chat list @query Query to search for @limit The maximum number of chats to be returned
searchChatsOnServer query:string limit:int32 = Chats;

//@description Returns a list of channel chats recommended to the current user
getRecommendedChats = Chats;

//@description Returns a list of chats similar to the given chat @chat_id Identifier of the target chat; must be an identifier of a channel chat
getChatSimilarChats chat_id:int53 = Chats;

//@description Returns approximate number of chats similar to the given chat
//@chat_id Identifier of the target chat; must be an identifier of a channel chat
//@return_local Pass true to get the number of chats without sending network requests, or -1 if the number of chats is unknown locally
getChatSimilarChatCount chat_id:int53 return_local:Bool = Count;

//@description Informs TDLib that a chat was opened from the list of similar chats. The method is independent of openChat and closeChat methods
//@chat_id Identifier of the original chat, which similar chats were requested
//@opened_chat_id Identifier of the opened chat
openChatSimilarChat chat_id:int53 opened_chat_id:int53 = Ok;

//@description Returns a list of bots similar to the given bot @bot_user_id User identifier of the target bot
getBotSimilarBots bot_user_id:int53 = Users;

//@description Returns approximate number of bots similar to the given bot
//@bot_user_id User identifier of the target bot
//@return_local Pass true to get the number of bots without sending network requests, or -1 if the number of bots is unknown locally
getBotSimilarBotCount bot_user_id:int53 return_local:Bool = Count;

//@description Informs TDLib that a bot was opened from the list of similar bots
//@bot_user_id Identifier of the original bot, which similar bots were requested
//@opened_bot_user_id Identifier of the opened bot
openBotSimilarBot bot_user_id:int53 opened_bot_user_id:int53 = Ok;

//@description Returns a list of frequently used chats @category Category of chats to be returned @limit The maximum number of chats to be returned; up to 30
getTopChats category:TopChatCategory limit:int32 = Chats;

//@description Removes a chat from the list of frequently used chats. Supported only if the chat info database is enabled @category Category of frequently used chats @chat_id Chat identifier
removeTopChat category:TopChatCategory chat_id:int53 = Ok;

//@description Searches for the specified query in the title and username of up to 50 recently found chats. This is an offline method
//@query Query to search for
//@limit The maximum number of chats to be returned
searchRecentlyFoundChats query:string limit:int32 = Chats;

//@description Adds a chat to the list of recently found chats. The chat is added to the beginning of the list. If the chat is already in the list, it will be removed from the list first @chat_id Identifier of the chat to add
addRecentlyFoundChat chat_id:int53 = Ok;

//@description Removes a chat from the list of recently found chats @chat_id Identifier of the chat to be removed
removeRecentlyFoundChat chat_id:int53 = Ok;

//@description Clears the list of recently found chats
clearRecentlyFoundChats = Ok;

//@description Returns recently opened chats. This is an offline method. Returns chats in the order of last opening @limit The maximum number of chats to be returned
getRecentlyOpenedChats limit:int32 = Chats;

//@description Checks whether a username can be set for a chat @chat_id Chat identifier; must be identifier of a supergroup chat, or a channel chat, or a private chat with self, or 0 if the chat is being created @username Username to be checked
checkChatUsername chat_id:int53 username:string = CheckChatUsernameResult;

//@description Returns a list of public chats of the specified type, owned by the user @type Type of the public chats to return
getCreatedPublicChats type:PublicChatType = Chats;

//@description Checks whether the maximum number of owned public chats has been reached. Returns corresponding error if the limit was reached. The limit can be increased with Telegram Premium @type Type of the public chats, for which to check the limit
checkCreatedPublicChatsLimit type:PublicChatType = Ok;

//@description Returns a list of basic group and supergroup chats, which can be used as a discussion group for a channel. Returned basic group chats must be first upgraded to supergroups before they can be set as a discussion group.
//-To set a returned supergroup as a discussion group, access to its old messages must be enabled using toggleSupergroupIsAllHistoryAvailable first
getSuitableDiscussionChats = Chats;

//@description Returns a list of recently inactive supergroups and channels. Can be used when user reaches limit on the number of joined supergroups and channels and receives CHANNELS_TOO_MUCH error. Also, the limit can be increased with Telegram Premium
getInactiveSupergroupChats = Chats;

//@description Returns a list of channel chats, which can be used as a personal chat
getSuitablePersonalChats = Chats;


//@description Loads more Saved Messages topics. The loaded topics will be sent through updateSavedMessagesTopic. Topics are sorted by their topic.order in descending order. Returns a 404 error if all topics have been loaded
//@limit The maximum number of topics to be loaded. For optimal performance, the number of loaded topics is chosen by TDLib and can be smaller than the specified limit, even if the end of the list is not reached
loadSavedMessagesTopics limit:int32 = Ok;

//@description Returns messages in a Saved Messages topic. The messages are returned in reverse chronological order (i.e., in order of decreasing message_id)
//@saved_messages_topic_id Identifier of Saved Messages topic which messages will be fetched
//@from_message_id Identifier of the message starting from which messages must be fetched; use 0 to get results from the last message
//@offset Specify 0 to get results from exactly the message from_message_id or a negative offset up to 99 to get additionally some newer messages
//@limit The maximum number of messages to be returned; must be positive and can't be greater than 100. If the offset is negative, the limit must be greater than or equal to -offset.
//-For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
getSavedMessagesTopicHistory saved_messages_topic_id:int53 from_message_id:int53 offset:int32 limit:int32 = Messages;

//@description Returns the last message sent in a Saved Messages topic no later than the specified date
//@saved_messages_topic_id Identifier of Saved Messages topic which message will be returned
//@date Point in time (Unix timestamp) relative to which to search for messages
getSavedMessagesTopicMessageByDate saved_messages_topic_id:int53 date:int32 = Message;

//@description Deletes all messages in a Saved Messages topic @saved_messages_topic_id Identifier of Saved Messages topic which messages will be deleted
deleteSavedMessagesTopicHistory saved_messages_topic_id:int53 = Ok;

//@description Deletes all messages between the specified dates in a Saved Messages topic. Messages sent in the last 30 seconds will not be deleted
//@saved_messages_topic_id Identifier of Saved Messages topic which messages will be deleted
//@min_date The minimum date of the messages to delete
//@max_date The maximum date of the messages to delete
deleteSavedMessagesTopicMessagesByDate saved_messages_topic_id:int53 min_date:int32 max_date:int32 = Ok;

//@description Changes the pinned state of a Saved Messages topic. There can be up to getOption("pinned_saved_messages_topic_count_max") pinned topics. The limit can be increased with Telegram Premium
//@saved_messages_topic_id Identifier of Saved Messages topic to pin or unpin
//@is_pinned Pass true to pin the topic; pass false to unpin it
toggleSavedMessagesTopicIsPinned saved_messages_topic_id:int53 is_pinned:Bool = Ok;

//@description Changes the order of pinned Saved Messages topics @saved_messages_topic_ids Identifiers of the new pinned Saved Messages topics
setPinnedSavedMessagesTopics saved_messages_topic_ids:vector<int53> = Ok;


//@description Returns a list of common group chats with a given user. Chats are sorted by their type and creation date
//@user_id User identifier
//@offset_chat_id Chat identifier starting from which to return chats; use 0 for the first request
//@limit The maximum number of chats to be returned; up to 100
getGroupsInCommon user_id:int53 offset_chat_id:int53 limit:int32 = Chats;


//@description Returns messages in a chat. The messages are returned in reverse chronological order (i.e., in order of decreasing message_id).
//-For optimal performance, the number of returned messages is chosen by TDLib. This is an offline method if only_local is true
//@chat_id Chat identifier
//@from_message_id Identifier of the message starting from which history must be fetched; use 0 to get results from the last message
//@offset Specify 0 to get results from exactly the message from_message_id or a negative offset up to 99 to get additionally some newer messages
//@limit The maximum number of messages to be returned; must be positive and can't be greater than 100. If the offset is negative, the limit must be greater than or equal to -offset.
//-For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
//@only_local Pass true to get only messages that are available without sending network requests
getChatHistory chat_id:int53 from_message_id:int53 offset:int32 limit:int32 only_local:Bool = Messages;

//@description Returns messages in a message thread of a message. Can be used only if messageProperties.can_get_message_thread == true. Message thread of a channel message is in the channel's linked supergroup.
//-The messages are returned in reverse chronological order (i.e., in order of decreasing message_id). For optimal performance, the number of returned messages is chosen by TDLib
//@chat_id Chat identifier
//@message_id Message identifier, which thread history needs to be returned
//@from_message_id Identifier of the message starting from which history must be fetched; use 0 to get results from the last message
//@offset Specify 0 to get results from exactly the message from_message_id or a negative offset up to 99 to get additionally some newer messages
//@limit The maximum number of messages to be returned; must be positive and can't be greater than 100. If the offset is negative, the limit must be greater than or equal to -offset.
//-For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
getMessageThreadHistory chat_id:int53 message_id:int53 from_message_id:int53 offset:int32 limit:int32 = Messages;

//@description Deletes all messages in the chat. Use chat.can_be_deleted_only_for_self and chat.can_be_deleted_for_all_users fields to find whether and how the method can be applied to the chat
//@chat_id Chat identifier
//@remove_from_chat_list Pass true to remove the chat from all chat lists
//@revoke Pass true to delete chat history for all users
deleteChatHistory chat_id:int53 remove_from_chat_list:Bool revoke:Bool = Ok;

//@description Deletes a chat along with all messages in the corresponding chat for all chat members. For group chats this will release the usernames and remove all members.
//-Use the field chat.can_be_deleted_for_all_users to find whether the method can be applied to the chat
//@chat_id Chat identifier
deleteChat chat_id:int53 = Ok;

//@description Searches for messages with given words in the chat. Returns the results in reverse chronological order, i.e. in order of decreasing message_id. Cannot be used in secret chats with a non-empty query
//-(searchSecretMessages must be used instead), or without an enabled message database. For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit.
//-A combination of query, sender_id, filter and message_thread_id search criteria is expected to be supported, only if it is required for Telegram official application implementation
//@chat_id Identifier of the chat in which to search messages
//@query Query to search for
//@sender_id Identifier of the sender of messages to search for; pass null to search for messages from any sender. Not supported in secret chats
//@from_message_id Identifier of the message starting from which history must be fetched; use 0 to get results from the last message
//@offset Specify 0 to get results from exactly the message from_message_id or a negative offset to get the specified message and some newer messages
//@limit The maximum number of messages to be returned; must be positive and can't be greater than 100. If the offset is negative, the limit must be greater than -offset.
//-For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
//@filter Additional filter for messages to search; pass null to search for all messages
//@message_thread_id If not 0, only messages in the specified thread will be returned; supergroups only
//@saved_messages_topic_id If not 0, only messages in the specified Saved Messages topic will be returned; pass 0 to return all messages, or for chats other than Saved Messages
searchChatMessages chat_id:int53 query:string sender_id:MessageSender from_message_id:int53 offset:int32 limit:int32 filter:SearchMessagesFilter message_thread_id:int53 saved_messages_topic_id:int53 = FoundChatMessages;

//@description Searches for messages in all chats except secret chats. Returns the results in reverse chronological order (i.e., in order of decreasing (date, chat_id, message_id)).
//-For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
//@chat_list Chat list in which to search messages; pass null to search in all chats regardless of their chat list. Only Main and Archive chat lists are supported
//@query Query to search for
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of messages to be returned; up to 100. For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
//@filter Additional filter for messages to search; pass null to search for all messages. Filters searchMessagesFilterMention, searchMessagesFilterUnreadMention, searchMessagesFilterUnreadReaction, searchMessagesFilterFailedToSend, and searchMessagesFilterPinned are unsupported in this function
//@chat_type_filter Additional filter for type of the chat of the searched messages; pass null to search for messages in all chats
//@min_date If not 0, the minimum date of the messages to return
//@max_date If not 0, the maximum date of the messages to return
searchMessages chat_list:ChatList query:string offset:string limit:int32 filter:SearchMessagesFilter chat_type_filter:SearchMessagesChatTypeFilter min_date:int32 max_date:int32 = FoundMessages;

//@description Searches for messages in secret chats. Returns the results in reverse chronological order. For optimal performance, the number of returned messages is chosen by TDLib
//@chat_id Identifier of the chat in which to search. Specify 0 to search in all secret chats
//@query Query to search for. If empty, searchChatMessages must be used instead
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of messages to be returned; up to 100. For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
//@filter Additional filter for messages to search; pass null to search for all messages
searchSecretMessages chat_id:int53 query:string offset:string limit:int32 filter:SearchMessagesFilter = FoundMessages;

//@description Searches for messages tagged by the given reaction and with the given words in the Saved Messages chat; for Telegram Premium users only.
//-Returns the results in reverse chronological order, i.e. in order of decreasing message_id.
//-For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
//@saved_messages_topic_id If not 0, only messages in the specified Saved Messages topic will be considered; pass 0 to consider all messages
//@tag Tag to search for; pass null to return all suitable messages
//@query Query to search for
//@from_message_id Identifier of the message starting from which messages must be fetched; use 0 to get results from the last message
//@offset Specify 0 to get results from exactly the message from_message_id or a negative offset to get the specified message and some newer messages
//@limit The maximum number of messages to be returned; must be positive and can't be greater than 100. If the offset is negative, the limit must be greater than -offset.
//-For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
searchSavedMessages saved_messages_topic_id:int53 tag:ReactionType query:string from_message_id:int53 offset:int32 limit:int32 = FoundChatMessages;

//@description Searches for call messages. Returns the results in reverse chronological order (i.e., in order of decreasing message_id). For optimal performance, the number of returned messages is chosen by TDLib
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of messages to be returned; up to 100. For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
//@only_missed Pass true to search only for messages with missed/declined calls
searchCallMessages offset:string limit:int32 only_missed:Bool = FoundMessages;

//@description Searches for outgoing messages with content of the type messageDocument in all chats except secret chats. Returns the results in reverse chronological order
//@query Query to search for in document file name and message caption
//@limit The maximum number of messages to be returned; up to 100
searchOutgoingDocumentMessages query:string limit:int32 = FoundMessages;

//@description Searches for public channel posts containing the given hashtag or cashtag. For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
//@tag Hashtag or cashtag to search for
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of messages to be returned; up to 100. For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
searchPublicMessagesByTag tag:string offset:string limit:int32 = FoundMessages;

//@description Searches for public stories containing the given hashtag or cashtag. For optimal performance, the number of returned stories is chosen by TDLib and can be smaller than the specified limit
//@story_sender_chat_id Identifier of the chat that posted the stories to search for; pass 0 to search stories in all chats
//@tag Hashtag or cashtag to search for
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of stories to be returned; up to 100. For optimal performance, the number of returned stories is chosen by TDLib and can be smaller than the specified limit
searchPublicStoriesByTag story_sender_chat_id:int53 tag:string offset:string limit:int32 = FoundStories;

//@description Searches for public stories by the given address location. For optimal performance, the number of returned stories is chosen by TDLib and can be smaller than the specified limit
//@address Address of the location
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of stories to be returned; up to 100. For optimal performance, the number of returned stories is chosen by TDLib and can be smaller than the specified limit
searchPublicStoriesByLocation address:locationAddress offset:string limit:int32 = FoundStories;

//@description Searches for public stories from the given venue. For optimal performance, the number of returned stories is chosen by TDLib and can be smaller than the specified limit
//@venue_provider Provider of the venue
//@venue_id Identifier of the venue in the provider database
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of stories to be returned; up to 100. For optimal performance, the number of returned stories is chosen by TDLib and can be smaller than the specified limit
searchPublicStoriesByVenue venue_provider:string venue_id:string offset:string limit:int32 = FoundStories;

//@description Returns recently searched for hashtags or cashtags by their prefix @tag_prefix Prefix of hashtags or cashtags to return @limit The maximum number of items to be returned
getSearchedForTags tag_prefix:string limit:int32 = Hashtags;

//@description Removes a hashtag or a cashtag from the list of recently searched for hashtags or cashtags @tag Hashtag or cashtag to delete
removeSearchedForTag tag:string = Ok;

//@description Clears the list of recently searched for hashtags or cashtags @clear_cashtags Pass true to clear the list of recently searched for cashtags; otherwise, the list of recently searched for hashtags will be cleared
clearSearchedForTags clear_cashtags:Bool = Ok;

//@description Deletes all call messages @revoke Pass true to delete the messages for all users
deleteAllCallMessages revoke:Bool = Ok;

//@description Returns information about the recent locations of chat members that were sent to the chat. Returns up to 1 location message per user @chat_id Chat identifier @limit The maximum number of messages to be returned
searchChatRecentLocationMessages chat_id:int53 limit:int32 = Messages;

//@description Returns the last message sent in a chat no later than the specified date. Returns a 404 error if such message doesn't exist
//@chat_id Chat identifier
//@date Point in time (Unix timestamp) relative to which to search for messages
getChatMessageByDate chat_id:int53 date:int32 = Message;

//@description Returns sparse positions of messages of the specified type in the chat to be used for shared media scroll implementation. Returns the results in reverse chronological order (i.e., in order of decreasing message_id).
//-Cannot be used in secret chats or with searchMessagesFilterFailedToSend filter without an enabled message database
//@chat_id Identifier of the chat in which to return information about message positions
//@filter Filter for message content. Filters searchMessagesFilterEmpty, searchMessagesFilterMention, searchMessagesFilterUnreadMention, and searchMessagesFilterUnreadReaction are unsupported in this function
//@from_message_id The message identifier from which to return information about message positions
//@limit The expected number of message positions to be returned; 50-2000. A smaller number of positions can be returned, if there are not enough appropriate messages
//@saved_messages_topic_id If not 0, only messages in the specified Saved Messages topic will be considered; pass 0 to consider all messages, or for chats other than Saved Messages
getChatSparseMessagePositions chat_id:int53 filter:SearchMessagesFilter from_message_id:int53 limit:int32 saved_messages_topic_id:int53 = MessagePositions;

//@description Returns information about the next messages of the specified type in the chat split by days. Returns the results in reverse chronological order. Can return partial result for the last returned day. Behavior of this method depends on the value of the option "utc_time_offset"
//@chat_id Identifier of the chat in which to return information about messages
//@filter Filter for message content. Filters searchMessagesFilterEmpty, searchMessagesFilterMention, searchMessagesFilterUnreadMention, and searchMessagesFilterUnreadReaction are unsupported in this function
//@from_message_id The message identifier from which to return information about messages; use 0 to get results from the last message
//@saved_messages_topic_id If not0, only messages in the specified Saved Messages topic will be considered; pass 0 to consider all messages, or for chats other than Saved Messages
getChatMessageCalendar chat_id:int53 filter:SearchMessagesFilter from_message_id:int53 saved_messages_topic_id:int53 = MessageCalendar;

//@description Returns approximate number of messages of the specified type in the chat
//@chat_id Identifier of the chat in which to count messages
//@filter Filter for message content; searchMessagesFilterEmpty is unsupported in this function
//@saved_messages_topic_id If not 0, only messages in the specified Saved Messages topic will be counted; pass 0 to count all messages, or for chats other than Saved Messages
//@return_local Pass true to get the number of messages without sending network requests, or -1 if the number of messages is unknown locally
getChatMessageCount chat_id:int53 filter:SearchMessagesFilter saved_messages_topic_id:int53 return_local:Bool = Count;

//@description Returns approximate 1-based position of a message among messages, which can be found by the specified filter in the chat. Cannot be used in secret chats
//@chat_id Identifier of the chat in which to find message position
//@message_id Message identifier
//@filter Filter for message content; searchMessagesFilterEmpty, searchMessagesFilterUnreadMention, searchMessagesFilterUnreadReaction, and searchMessagesFilterFailedToSend are unsupported in this function
//@message_thread_id If not 0, only messages in the specified thread will be considered; supergroups only
//@saved_messages_topic_id If not 0, only messages in the specified Saved Messages topic will be considered; pass 0 to consider all relevant messages, or for chats other than Saved Messages
getChatMessagePosition chat_id:int53 message_id:int53 filter:SearchMessagesFilter message_thread_id:int53 saved_messages_topic_id:int53 = Count;

//@description Returns all scheduled messages in a chat. The messages are returned in reverse chronological order (i.e., in order of decreasing message_id) @chat_id Chat identifier
getChatScheduledMessages chat_id:int53 = Messages;

//@description Returns sponsored messages to be shown in a chat; for channel chats and chats with bots only @chat_id Identifier of the chat
getChatSponsoredMessages chat_id:int53 = SponsoredMessages;

//@description Informs TDLib that the user opened the sponsored chat via the button, the name, the chat photo, a mention in the sponsored message text, or the media in the sponsored message
//@chat_id Chat identifier of the sponsored message
//@message_id Identifier of the sponsored message
//@is_media_click Pass true if the media was clicked in the sponsored message
//@from_fullscreen Pass true if the user expanded the video from the sponsored message fullscreen before the click
clickChatSponsoredMessage chat_id:int53 message_id:int53 is_media_click:Bool from_fullscreen:Bool = Ok;

//@description Reports a sponsored message to Telegram moderators
//@chat_id Chat identifier of the sponsored message
//@message_id Identifier of the sponsored message
//@option_id Option identifier chosen by the user; leave empty for the initial request
reportChatSponsoredMessage chat_id:int53 message_id:int53 option_id:bytes = ReportChatSponsoredMessageResult;


//@description Removes an active notification from notification list. Needs to be called only if the notification is removed by the current user @notification_group_id Identifier of notification group to which the notification belongs @notification_id Identifier of removed notification
removeNotification notification_group_id:int32 notification_id:int32 = Ok;

//@description Removes a group of active notifications. Needs to be called only if the notification group is removed by the current user @notification_group_id Notification group identifier @max_notification_id The maximum identifier of removed notifications
removeNotificationGroup notification_group_id:int32 max_notification_id:int32 = Ok;


//@description Returns an HTTPS link to a message in a chat. Available only if messageProperties.can_get_link, or if messageProperties.can_get_media_timestamp_links and a media timestamp link is generated. This is an offline method
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message
//@media_timestamp If not 0, timestamp from which the video/audio/video note/voice note/story playing must start, in seconds. The media can be in the message content or in its link preview
//@for_album Pass true to create a link for the whole media album
//@in_message_thread Pass true to create a link to the message as a channel post comment, in a message thread, or a forum topic
getMessageLink chat_id:int53 message_id:int53 media_timestamp:int32 for_album:Bool in_message_thread:Bool = MessageLink;

//@description Returns an HTML code for embedding the message. Available only if messageProperties.can_get_embedding_code
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message
//@for_album Pass true to return an HTML code for embedding of the whole media album
getMessageEmbeddingCode chat_id:int53 message_id:int53 for_album:Bool = Text;

//@description Returns information about a public or private message link. Can be called for any internal link of the type internalLinkTypeMessage @url The message link
getMessageLinkInfo url:string = MessageLinkInfo;


//@description Translates a text to the given language. If the current user is a Telegram Premium user, then text formatting is preserved
//@text Text to translate
//@to_language_code Language code of the language to which the message is translated. Must be one of
//-"af", "sq", "am", "ar", "hy", "az", "eu", "be", "bn", "bs", "bg", "ca", "ceb", "zh-CN", "zh", "zh-Hans", "zh-TW", "zh-Hant", "co", "hr", "cs", "da", "nl", "en", "eo", "et",
//-"fi", "fr", "fy", "gl", "ka", "de", "el", "gu", "ht", "ha", "haw", "he", "iw", "hi", "hmn", "hu", "is", "ig", "id", "in", "ga", "it", "ja", "jv", "kn", "kk", "km", "rw", "ko",
//-"ku", "ky", "lo", "la", "lv", "lt", "lb", "mk", "mg", "ms", "ml", "mt", "mi", "mr", "mn", "my", "ne", "no", "ny", "or", "ps", "fa", "pl", "pt", "pa", "ro", "ru", "sm", "gd", "sr",
//-"st", "sn", "sd", "si", "sk", "sl", "so", "es", "su", "sw", "sv", "tl", "tg", "ta", "tt", "te", "th", "tr", "tk", "uk", "ur", "ug", "uz", "vi", "cy", "xh", "yi", "ji", "yo", "zu"
translateText text:formattedText to_language_code:string = FormattedText;

//@description Extracts text or caption of the given message and translates it to the given language. If the current user is a Telegram Premium user, then text formatting is preserved
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message
//@to_language_code Language code of the language to which the message is translated. Must be one of
//-"af", "sq", "am", "ar", "hy", "az", "eu", "be", "bn", "bs", "bg", "ca", "ceb", "zh-CN", "zh", "zh-Hans", "zh-TW", "zh-Hant", "co", "hr", "cs", "da", "nl", "en", "eo", "et",
//-"fi", "fr", "fy", "gl", "ka", "de", "el", "gu", "ht", "ha", "haw", "he", "iw", "hi", "hmn", "hu", "is", "ig", "id", "in", "ga", "it", "ja", "jv", "kn", "kk", "km", "rw", "ko",
//-"ku", "ky", "lo", "la", "lv", "lt", "lb", "mk", "mg", "ms", "ml", "mt", "mi", "mr", "mn", "my", "ne", "no", "ny", "or", "ps", "fa", "pl", "pt", "pa", "ro", "ru", "sm", "gd", "sr",
//-"st", "sn", "sd", "si", "sk", "sl", "so", "es", "su", "sw", "sv", "tl", "tg", "ta", "tt", "te", "th", "tr", "tk", "uk", "ur", "ug", "uz", "vi", "cy", "xh", "yi", "ji", "yo", "zu"
translateMessageText chat_id:int53 message_id:int53 to_language_code:string = FormattedText;

//@description Recognizes speech in a video note or a voice note message
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message. Use messageProperties.can_recognize_speech to check whether the message is suitable
recognizeSpeech chat_id:int53 message_id:int53 = Ok;

//@description Rates recognized speech in a video note or a voice note message @chat_id Identifier of the chat to which the message belongs @message_id Identifier of the message @is_good Pass true if the speech recognition is good
rateSpeechRecognition chat_id:int53 message_id:int53 is_good:Bool = Ok;


//@description Returns the list of message sender identifiers, which can be used to send messages in a chat @chat_id Chat identifier
getChatAvailableMessageSenders chat_id:int53 = ChatMessageSenders;

//@description Selects a message sender to send messages in a chat @chat_id Chat identifier @message_sender_id New message sender for the chat
setChatMessageSender chat_id:int53 message_sender_id:MessageSender = Ok;

//@description Sends a message. Returns the sent message
//@chat_id Target chat
//@message_thread_id If not 0, the message thread identifier in which the message will be sent
//@reply_to Information about the message or story to be replied; pass null if none
//@options Options to be used to send the message; pass null to use default options
//@reply_markup Markup for replying to the message; pass null if none; for bots only
//@input_message_content The content of the message to be sent
sendMessage chat_id:int53 message_thread_id:int53 reply_to:InputMessageReplyTo options:messageSendOptions reply_markup:ReplyMarkup input_message_content:InputMessageContent = Message;

//@description Sends 2-10 messages grouped together into an album. Currently, only audio, document, photo and video messages can be grouped into an album.
//-Documents and audio files can be only grouped in an album with messages of the same type. Returns sent messages
//@chat_id Target chat
//@message_thread_id If not 0, the message thread identifier in which the messages will be sent
//@reply_to Information about the message or story to be replied; pass null if none
//@options Options to be used to send the messages; pass null to use default options
//@input_message_contents Contents of messages to be sent. At most 10 messages can be added to an album. All messages must have the same value of show_caption_above_media
sendMessageAlbum chat_id:int53 message_thread_id:int53 reply_to:InputMessageReplyTo options:messageSendOptions input_message_contents:vector<InputMessageContent> = Messages;

//@description Invites a bot to a chat (if it is not yet a member) and sends it the /start command; requires can_invite_users member right. Bots can't be invited to a private chat other than the chat with the bot.
//-Bots can't be invited to channels (although they can be added as admins) and secret chats. Returns the sent message
//@bot_user_id Identifier of the bot
//@chat_id Identifier of the target chat
//@parameter A hidden parameter sent to the bot for deep linking purposes (https://core.telegram.org/bots#deep-linking)
sendBotStartMessage bot_user_id:int53 chat_id:int53 parameter:string = Message;

//@description Sends the result of an inline query as a message. Returns the sent message. Always clears a chat draft message
//@chat_id Target chat
//@message_thread_id If not 0, the message thread identifier in which the message will be sent
//@reply_to Information about the message or story to be replied; pass null if none
//@options Options to be used to send the message; pass null to use default options
//@query_id Identifier of the inline query
//@result_id Identifier of the inline query result
//@hide_via_bot Pass true to hide the bot, via which the message is sent. Can be used only for bots getOption("animation_search_bot_username"), getOption("photo_search_bot_username"), and getOption("venue_search_bot_username")
sendInlineQueryResultMessage chat_id:int53 message_thread_id:int53 reply_to:InputMessageReplyTo options:messageSendOptions query_id:int64 result_id:string hide_via_bot:Bool = Message;

//@description Forwards previously sent messages. Returns the forwarded messages in the same order as the message identifiers passed in message_ids. If a message can't be forwarded, null will be returned instead of the message
//@chat_id Identifier of the chat to which to forward messages
//@message_thread_id If not 0, the message thread identifier in which the message will be sent; for forum threads only
//@from_chat_id Identifier of the chat from which to forward messages
//@message_ids Identifiers of the messages to forward. Message identifiers must be in a strictly increasing order. At most 100 messages can be forwarded simultaneously. A message can be forwarded only if messageProperties.can_be_forwarded
//@options Options to be used to send the messages; pass null to use default options
//@send_copy Pass true to copy content of the messages without reference to the original sender. Always true if the messages are forwarded to a secret chat or are local.
//-Use messageProperties.can_be_saved and messageProperties.can_be_copied_to_secret_chat to check whether the message is suitable
//@remove_caption Pass true to remove media captions of message copies. Ignored if send_copy is false
forwardMessages chat_id:int53 message_thread_id:int53 from_chat_id:int53 message_ids:vector<int53> options:messageSendOptions send_copy:Bool remove_caption:Bool = Messages;

//@description Sends messages from a quick reply shortcut. Requires Telegram Business subscription. Can't be used to send paid messages
//@chat_id Identifier of the chat to which to send messages. The chat must be a private chat with a regular user
//@shortcut_id Unique identifier of the quick reply shortcut
//@sending_id Non-persistent identifier, which will be returned back in messageSendingStatePending object and can be used to match sent messages and corresponding updateNewMessage updates
sendQuickReplyShortcutMessages chat_id:int53 shortcut_id:int32 sending_id:int32 = Messages;

//@description Resends messages which failed to send. Can be called only for messages for which messageSendingStateFailed.can_retry is true and after specified in messageSendingStateFailed.retry_after time passed.
//-If a message is re-sent, the corresponding failed to send message is deleted. Returns the sent messages in the same order as the message identifiers passed in message_ids. If a message can't be re-sent, null will be returned instead of the message
//@chat_id Identifier of the chat to send messages
//@message_ids Identifiers of the messages to resend. Message identifiers must be in a strictly increasing order
//@quote New manually chosen quote from the message to be replied; pass null if none. Ignored if more than one message is re-sent, or if messageSendingStateFailed.need_another_reply_quote == false
//@paid_message_star_count The number of Telegram Stars the user agreed to pay to send the messages. Ignored if messageSendingStateFailed.required_paid_message_star_count == 0
resendMessages chat_id:int53 message_ids:vector<int53> quote:inputTextQuote paid_message_star_count:int53 = Messages;

//@description Adds a local message to a chat. The message is persistent across application restarts only if the message database is used. Returns the added message
//@chat_id Target chat
//@sender_id Identifier of the sender of the message
//@reply_to Information about the message or story to be replied; pass null if none
//@disable_notification Pass true to disable notification for the message
//@input_message_content The content of the message to be added
addLocalMessage chat_id:int53 sender_id:MessageSender reply_to:InputMessageReplyTo disable_notification:Bool input_message_content:InputMessageContent = Message;

//@description Deletes messages
//@chat_id Chat identifier
//@message_ids Identifiers of the messages to be deleted. Use messageProperties.can_be_deleted_only_for_self and messageProperties.can_be_deleted_for_all_users to get suitable messages
//@revoke Pass true to delete messages for all chat members. Always true for supergroups, channels and secret chats
deleteMessages chat_id:int53 message_ids:vector<int53> revoke:Bool = Ok;

//@description Deletes all messages sent by the specified message sender in a chat. Supported only for supergroups; requires can_delete_messages administrator right @chat_id Chat identifier @sender_id Identifier of the sender of messages to delete
deleteChatMessagesBySender chat_id:int53 sender_id:MessageSender = Ok;

//@description Deletes all messages between the specified dates in a chat. Supported only for private chats and basic groups. Messages sent in the last 30 seconds will not be deleted
//@chat_id Chat identifier
//@min_date The minimum date of the messages to delete
//@max_date The maximum date of the messages to delete
//@revoke Pass true to delete chat messages for all users; private chats only
deleteChatMessagesByDate chat_id:int53 min_date:int32 max_date:int32 revoke:Bool = Ok;


//@description Edits the text of a message (or a text of a game message). Returns the edited message after the edit is completed on the server side
//@chat_id The chat the message belongs to
//@message_id Identifier of the message. Use messageProperties.can_be_edited to check whether the message can be edited
//@reply_markup The new message reply markup; pass null if none; for bots only
//@input_message_content New text content of the message. Must be of type inputMessageText
editMessageText chat_id:int53 message_id:int53 reply_markup:ReplyMarkup input_message_content:InputMessageContent = Message;

//@description Edits the message content of a live location. Messages can be edited for a limited period of time specified in the live location.
//-Returns the edited message after the edit is completed on the server side
//@chat_id The chat the message belongs to
//@message_id Identifier of the message. Use messageProperties.can_be_edited to check whether the message can be edited
//@reply_markup The new message reply markup; pass null if none; for bots only
//@location New location content of the message; pass null to stop sharing the live location
//@live_period New time relative to the message send date, for which the location can be updated, in seconds. If 0x7FFFFFFF specified, then the location can be updated forever.
//-Otherwise, must not exceed the current live_period by more than a day, and the live location expiration date must remain in the next 90 days. Pass 0 to keep the current live_period
//@heading The new direction in which the location moves, in degrees; 1-360. Pass 0 if unknown
//@proximity_alert_radius The new maximum distance for proximity alerts, in meters (0-100000). Pass 0 if the notification is disabled
editMessageLiveLocation chat_id:int53 message_id:int53 reply_markup:ReplyMarkup location:location live_period:int32 heading:int32 proximity_alert_radius:int32 = Message;

//@description Edits the media content of a message, including message caption. If only the caption needs to be edited, use editMessageCaption instead.
//-The type of message content in an album can't be changed with exception of replacing a photo with a video or vice versa. Returns the edited message after the edit is completed on the server side
//@chat_id The chat the message belongs to
//@message_id Identifier of the message. Use messageProperties.can_edit_media to check whether the message can be edited
//@reply_markup The new message reply markup; pass null if none; for bots only
//@input_message_content New content of the message. Must be one of the following types: inputMessageAnimation, inputMessageAudio, inputMessageDocument, inputMessagePhoto or inputMessageVideo
editMessageMedia chat_id:int53 message_id:int53 reply_markup:ReplyMarkup input_message_content:InputMessageContent = Message;

//@description Edits the message content caption. Returns the edited message after the edit is completed on the server side
//@chat_id The chat the message belongs to
//@message_id Identifier of the message. Use messageProperties.can_be_edited to check whether the message can be edited
//@reply_markup The new message reply markup; pass null if none; for bots only
//@caption New message content caption; 0-getOption("message_caption_length_max") characters; pass null to remove caption
//@show_caption_above_media Pass true to show the caption above the media; otherwise, the caption will be shown below the media. May be true only for animation, photo, and video messages
editMessageCaption chat_id:int53 message_id:int53 reply_markup:ReplyMarkup caption:formattedText show_caption_above_media:Bool = Message;

//@description Edits the message reply markup; for bots only. Returns the edited message after the edit is completed on the server side
//@chat_id The chat the message belongs to
//@message_id Identifier of the message. Use messageProperties.can_be_edited to check whether the message can be edited
//@reply_markup The new message reply markup; pass null if none
editMessageReplyMarkup chat_id:int53 message_id:int53 reply_markup:ReplyMarkup = Message;

//@description Edits the text of an inline text or game message sent via a bot; for bots only
//@inline_message_id Inline message identifier
//@reply_markup The new message reply markup; pass null if none
//@input_message_content New text content of the message. Must be of type inputMessageText
editInlineMessageText inline_message_id:string reply_markup:ReplyMarkup input_message_content:InputMessageContent = Ok;

//@description Edits the content of a live location in an inline message sent via a bot; for bots only
//@inline_message_id Inline message identifier
//@reply_markup The new message reply markup; pass null if none
//@location New location content of the message; pass null to stop sharing the live location
//@live_period New time relative to the message send date, for which the location can be updated, in seconds. If 0x7FFFFFFF specified, then the location can be updated forever.
//-Otherwise, must not exceed the current live_period by more than a day, and the live location expiration date must remain in the next 90 days. Pass 0 to keep the current live_period
//@heading The new direction in which the location moves, in degrees; 1-360. Pass 0 if unknown
//@proximity_alert_radius The new maximum distance for proximity alerts, in meters (0-100000). Pass 0 if the notification is disabled
editInlineMessageLiveLocation inline_message_id:string reply_markup:ReplyMarkup location:location live_period:int32 heading:int32 proximity_alert_radius:int32 = Ok;

//@description Edits the media content of a message with a text, an animation, an audio, a document, a photo or a video in an inline message sent via a bot; for bots only
//@inline_message_id Inline message identifier
//@reply_markup The new message reply markup; pass null if none; for bots only
//@input_message_content New content of the message. Must be one of the following types: inputMessageAnimation, inputMessageAudio, inputMessageDocument, inputMessagePhoto or inputMessageVideo
editInlineMessageMedia inline_message_id:string reply_markup:ReplyMarkup input_message_content:InputMessageContent = Ok;

//@description Edits the caption of an inline message sent via a bot; for bots only
//@inline_message_id Inline message identifier
//@reply_markup The new message reply markup; pass null if none
//@caption New message content caption; pass null to remove caption; 0-getOption("message_caption_length_max") characters
//@show_caption_above_media Pass true to show the caption above the media; otherwise, the caption will be shown below the media. May be true only for animation, photo, and video messages
editInlineMessageCaption inline_message_id:string reply_markup:ReplyMarkup caption:formattedText show_caption_above_media:Bool = Ok;

//@description Edits the reply markup of an inline message sent via a bot; for bots only
//@inline_message_id Inline message identifier
//@reply_markup The new message reply markup; pass null if none
editInlineMessageReplyMarkup inline_message_id:string reply_markup:ReplyMarkup = Ok;

//@description Edits the time when a scheduled message will be sent. Scheduling state of all messages in the same album or forwarded together with the message will be also changed
//@chat_id The chat the message belongs to
//@message_id Identifier of the message. Use messageProperties.can_edit_scheduling_state to check whether the message is suitable
//@scheduling_state The new message scheduling state; pass null to send the message immediately. Must be null for messages in the state messageSchedulingStateSendWhenVideoProcessed
editMessageSchedulingState chat_id:int53 message_id:int53 scheduling_state:MessageSchedulingState = Ok;


//@description Changes the fact-check of a message. Can be only used if messageProperties.can_set_fact_check == true
//@chat_id The channel chat the message belongs to
//@message_id Identifier of the message
//@text New text of the fact-check; 0-getOption("fact_check_length_max") characters; pass null to remove it. Only Bold, Italic, and TextUrl entities with https://t.me/ links are supported
setMessageFactCheck chat_id:int53 message_id:int53 text:formattedText = Ok;


//@description Sends a message on behalf of a business account; for bots only. Returns the message after it was sent
//@business_connection_id Unique identifier of business connection on behalf of which to send the request
//@chat_id Target chat
//@reply_to Information about the message to be replied; pass null if none
//@disable_notification Pass true to disable notification for the message
//@protect_content Pass true if the content of the message must be protected from forwarding and saving
//@effect_id Identifier of the effect to apply to the message
//@reply_markup Markup for replying to the message; pass null if none
//@input_message_content The content of the message to be sent
sendBusinessMessage business_connection_id:string chat_id:int53 reply_to:InputMessageReplyTo disable_notification:Bool protect_content:Bool effect_id:int64 reply_markup:ReplyMarkup input_message_content:InputMessageContent = BusinessMessage;

//@description Sends 2-10 messages grouped together into an album on behalf of a business account; for bots only. Currently, only audio, document, photo and video messages can be grouped into an album.
//-Documents and audio files can be only grouped in an album with messages of the same type. Returns sent messages
//@business_connection_id Unique identifier of business connection on behalf of which to send the request
//@chat_id Target chat
//@reply_to Information about the message to be replied; pass null if none
//@disable_notification Pass true to disable notification for the message
//@protect_content Pass true if the content of the message must be protected from forwarding and saving
//@effect_id Identifier of the effect to apply to the message
//@input_message_contents Contents of messages to be sent. At most 10 messages can be added to an album. All messages must have the same value of show_caption_above_media
sendBusinessMessageAlbum business_connection_id:string chat_id:int53 reply_to:InputMessageReplyTo disable_notification:Bool protect_content:Bool effect_id:int64 input_message_contents:vector<InputMessageContent> = BusinessMessages;

//@description Edits the text of a text or game message sent on behalf of a business account; for bots only
//@business_connection_id Unique identifier of business connection on behalf of which the message was sent
//@chat_id The chat the message belongs to
//@message_id Identifier of the message
//@reply_markup The new message reply markup; pass null if none
//@input_message_content New text content of the message. Must be of type inputMessageText
editBusinessMessageText business_connection_id:string chat_id:int53 message_id:int53 reply_markup:ReplyMarkup input_message_content:InputMessageContent = BusinessMessage;

//@description Edits the content of a live location in a message sent on behalf of a business account; for bots only
//@business_connection_id Unique identifier of business connection on behalf of which the message was sent
//@chat_id The chat the message belongs to
//@message_id Identifier of the message
//@reply_markup The new message reply markup; pass null if none
//@location New location content of the message; pass null to stop sharing the live location
//@live_period New time relative to the message send date, for which the location can be updated, in seconds. If 0x7FFFFFFF specified, then the location can be updated forever.
//-Otherwise, must not exceed the current live_period by more than a day, and the live location expiration date must remain in the next 90 days. Pass 0 to keep the current live_period
//@heading The new direction in which the location moves, in degrees; 1-360. Pass 0 if unknown
//@proximity_alert_radius The new maximum distance for proximity alerts, in meters (0-100000). Pass 0 if the notification is disabled
editBusinessMessageLiveLocation business_connection_id:string chat_id:int53 message_id:int53 reply_markup:ReplyMarkup location:location live_period:int32 heading:int32 proximity_alert_radius:int32 = BusinessMessage;

//@description Edits the media content of a message with a text, an animation, an audio, a document, a photo or a video in a message sent on behalf of a business account; for bots only
//@business_connection_id Unique identifier of business connection on behalf of which the message was sent
//@chat_id The chat the message belongs to
//@message_id Identifier of the message
//@reply_markup The new message reply markup; pass null if none; for bots only
//@input_message_content New content of the message. Must be one of the following types: inputMessageAnimation, inputMessageAudio, inputMessageDocument, inputMessagePhoto or inputMessageVideo
editBusinessMessageMedia business_connection_id:string chat_id:int53 message_id:int53 reply_markup:ReplyMarkup input_message_content:InputMessageContent = BusinessMessage;

//@description Edits the caption of a message sent on behalf of a business account; for bots only
//@business_connection_id Unique identifier of business connection on behalf of which the message was sent
//@chat_id The chat the message belongs to
//@message_id Identifier of the message
//@reply_markup The new message reply markup; pass null if none
//@caption New message content caption; pass null to remove caption; 0-getOption("message_caption_length_max") characters
//@show_caption_above_media Pass true to show the caption above the media; otherwise, the caption will be shown below the media. May be true only for animation, photo, and video messages
editBusinessMessageCaption business_connection_id:string chat_id:int53 message_id:int53 reply_markup:ReplyMarkup caption:formattedText show_caption_above_media:Bool = BusinessMessage;

//@description Edits the reply markup of a message sent on behalf of a business account; for bots only
//@business_connection_id Unique identifier of business connection on behalf of which the message was sent
//@chat_id The chat the message belongs to
//@message_id Identifier of the message
//@reply_markup The new message reply markup; pass null if none
editBusinessMessageReplyMarkup business_connection_id:string chat_id:int53 message_id:int53 reply_markup:ReplyMarkup = BusinessMessage;

//@description Stops a poll sent on behalf of a business account; for bots only
//@business_connection_id Unique identifier of business connection on behalf of which the message with the poll was sent
//@chat_id The chat the message belongs to
//@message_id Identifier of the message containing the poll
//@reply_markup The new message reply markup; pass null if none
stopBusinessPoll business_connection_id:string chat_id:int53 message_id:int53 reply_markup:ReplyMarkup = BusinessMessage;

//@description Pins or unpins a message sent on behalf of a business account; for bots only
//@business_connection_id Unique identifier of business connection on behalf of which the message was sent
//@chat_id The chat the message belongs to
//@message_id Identifier of the message
//@is_pinned Pass true to pin the message, pass false to unpin it
setBusinessMessageIsPinned business_connection_id:string chat_id:int53 message_id:int53 is_pinned:Bool = Ok;


//@description Checks validness of a name for a quick reply shortcut. Can be called synchronously @name The name of the shortcut; 1-32 characters
checkQuickReplyShortcutName name:string = Ok;

//@description Loads quick reply shortcuts created by the current user. The loaded data will be sent through updateQuickReplyShortcut and updateQuickReplyShortcuts
loadQuickReplyShortcuts = Ok;

//@description Changes name of a quick reply shortcut @shortcut_id Unique identifier of the quick reply shortcut @name New name for the shortcut. Use checkQuickReplyShortcutName to check its validness
setQuickReplyShortcutName shortcut_id:int32 name:string = Ok;

//@description Deletes a quick reply shortcut @shortcut_id Unique identifier of the quick reply shortcut
deleteQuickReplyShortcut shortcut_id:int32 = Ok;

//@description Changes the order of quick reply shortcuts @shortcut_ids The new order of quick reply shortcuts
reorderQuickReplyShortcuts shortcut_ids:vector<int32> = Ok;

//@description Loads quick reply messages that can be sent by a given quick reply shortcut. The loaded messages will be sent through updateQuickReplyShortcutMessages
//@shortcut_id Unique identifier of the quick reply shortcut
loadQuickReplyShortcutMessages shortcut_id:int32 = Ok;

//@description Deletes specified quick reply messages
//@shortcut_id Unique identifier of the quick reply shortcut to which the messages belong
//@message_ids Unique identifiers of the messages
deleteQuickReplyShortcutMessages shortcut_id:int32 message_ids:vector<int53> = Ok;

//@description Adds a message to a quick reply shortcut. If shortcut doesn't exist and there are less than getOption("quick_reply_shortcut_count_max") shortcuts, then a new shortcut is created.
//-The shortcut must not contain more than getOption("quick_reply_shortcut_message_count_max") messages after adding the new message. Returns the added message
//@shortcut_name Name of the target shortcut
//@reply_to_message_id Identifier of a quick reply message in the same shortcut to be replied; pass 0 if none
//@input_message_content The content of the message to be added; inputMessagePoll, inputMessageForwarded and inputMessageLocation with live_period aren't supported
addQuickReplyShortcutMessage shortcut_name:string reply_to_message_id:int53 input_message_content:InputMessageContent = QuickReplyMessage;

//@description Adds a message to a quick reply shortcut via inline bot. If shortcut doesn't exist and there are less than getOption("quick_reply_shortcut_count_max") shortcuts, then a new shortcut is created.
//-The shortcut must not contain more than getOption("quick_reply_shortcut_message_count_max") messages after adding the new message. Returns the added message
//@shortcut_name Name of the target shortcut
//@reply_to_message_id Identifier of a quick reply message in the same shortcut to be replied; pass 0 if none
//@query_id Identifier of the inline query
//@result_id Identifier of the inline query result
//@hide_via_bot Pass true to hide the bot, via which the message is sent. Can be used only for bots getOption("animation_search_bot_username"), getOption("photo_search_bot_username"), and getOption("venue_search_bot_username")
addQuickReplyShortcutInlineQueryResultMessage shortcut_name:string reply_to_message_id:int53 query_id:int64 result_id:string hide_via_bot:Bool = QuickReplyMessage;

//@description Adds 2-10 messages grouped together into an album to a quick reply shortcut. Currently, only audio, document, photo and video messages can be grouped into an album.
//-Documents and audio files can be only grouped in an album with messages of the same type. Returns sent messages
//@shortcut_name Name of the target shortcut
//@reply_to_message_id Identifier of a quick reply message in the same shortcut to be replied; pass 0 if none
//@input_message_contents Contents of messages to be sent. At most 10 messages can be added to an album. All messages must have the same value of show_caption_above_media
addQuickReplyShortcutMessageAlbum shortcut_name:string reply_to_message_id:int53 input_message_contents:vector<InputMessageContent> = QuickReplyMessages;

//@description Readds quick reply messages which failed to add. Can be called only for messages for which messageSendingStateFailed.can_retry is true and after specified in messageSendingStateFailed.retry_after time passed.
//-If a message is readded, the corresponding failed to send message is deleted. Returns the sent messages in the same order as the message identifiers passed in message_ids. If a message can't be readded, null will be returned instead of the message
//@shortcut_name Name of the target shortcut
//@message_ids Identifiers of the quick reply messages to readd. Message identifiers must be in a strictly increasing order
readdQuickReplyShortcutMessages shortcut_name:string message_ids:vector<int53> = QuickReplyMessages;

//@description Asynchronously edits the text, media or caption of a quick reply message. Use quickReplyMessage.can_be_edited to check whether a message can be edited.
//-Media message can be edited only to a media message. The type of message content in an album can't be changed with exception of replacing a photo with a video or vice versa
//@shortcut_id Unique identifier of the quick reply shortcut with the message
//@message_id Identifier of the message
//@input_message_content New content of the message. Must be one of the following types: inputMessageText, inputMessageAnimation, inputMessageAudio, inputMessageDocument, inputMessagePhoto or inputMessageVideo
editQuickReplyMessage shortcut_id:int32 message_id:int53 input_message_content:InputMessageContent = Ok;


//@description Returns the list of custom emoji, which can be used as forum topic icon by all users
getForumTopicDefaultIcons = Stickers;

//@description Creates a topic in a forum supergroup chat; requires can_manage_topics administrator or can_create_topics member right in the supergroup
//@chat_id Identifier of the chat
//@name Name of the topic; 1-128 characters
//@icon Icon of the topic. Icon color must be one of 0x6FB9F0, 0xFFD67E, 0xCB86DB, 0x8EEE98, 0xFF93B2, or 0xFB6F5F. Telegram Premium users can use any custom emoji as topic icon, other users can use only a custom emoji returned by getForumTopicDefaultIcons
createForumTopic chat_id:int53 name:string icon:forumTopicIcon = ForumTopicInfo;

//@description Edits title and icon of a topic in a forum supergroup chat; requires can_manage_topics right in the supergroup unless the user is creator of the topic
//@chat_id Identifier of the chat
//@message_thread_id Message thread identifier of the forum topic
//@name New name of the topic; 0-128 characters. If empty, the previous topic name is kept
//@edit_icon_custom_emoji Pass true to edit the icon of the topic. Icon of the General topic can't be edited
//@icon_custom_emoji_id Identifier of the new custom emoji for topic icon; pass 0 to remove the custom emoji. Ignored if edit_icon_custom_emoji is false. Telegram Premium users can use any custom emoji, other users can use only a custom emoji returned by getForumTopicDefaultIcons
editForumTopic chat_id:int53 message_thread_id:int53 name:string edit_icon_custom_emoji:Bool icon_custom_emoji_id:int64 = Ok;

//@description Returns information about a forum topic @chat_id Identifier of the chat @message_thread_id Message thread identifier of the forum topic
getForumTopic chat_id:int53 message_thread_id:int53 = ForumTopic;

//@description Returns an HTTPS link to a topic in a forum chat. This is an offline method @chat_id Identifier of the chat @message_thread_id Message thread identifier of the forum topic
getForumTopicLink chat_id:int53 message_thread_id:int53 = MessageLink;

//@description Returns found forum topics in a forum chat. This is a temporary method for getting information about topic list from the server
//@chat_id Identifier of the forum chat
//@query Query to search for in the forum topic's name
//@offset_date The date starting from which the results need to be fetched. Use 0 or any date in the future to get results from the last topic
//@offset_message_id The message identifier of the last message in the last found topic, or 0 for the first request
//@offset_message_thread_id The message thread identifier of the last found topic, or 0 for the first request
//@limit The maximum number of forum topics to be returned; up to 100. For optimal performance, the number of returned forum topics is chosen by TDLib and can be smaller than the specified limit
getForumTopics chat_id:int53 query:string offset_date:int32 offset_message_id:int53 offset_message_thread_id:int53 limit:int32 = ForumTopics;

//@description Changes the notification settings of a forum topic
//@chat_id Chat identifier
//@message_thread_id Message thread identifier of the forum topic
//@notification_settings New notification settings for the forum topic. If the topic is muted for more than 366 days, it is considered to be muted forever
setForumTopicNotificationSettings chat_id:int53 message_thread_id:int53 notification_settings:chatNotificationSettings = Ok;

//@description Toggles whether a topic is closed in a forum supergroup chat; requires can_manage_topics right in the supergroup unless the user is creator of the topic
//@chat_id Identifier of the chat
//@message_thread_id Message thread identifier of the forum topic
//@is_closed Pass true to close the topic; pass false to reopen it
toggleForumTopicIsClosed chat_id:int53 message_thread_id:int53 is_closed:Bool = Ok;

//@description Toggles whether a General topic is hidden in a forum supergroup chat; requires can_manage_topics right in the supergroup
//@chat_id Identifier of the chat
//@is_hidden Pass true to hide and close the General topic; pass false to unhide it
toggleGeneralForumTopicIsHidden chat_id:int53 is_hidden:Bool = Ok;

//@description Changes the pinned state of a forum topic; requires can_manage_topics right in the supergroup. There can be up to getOption("pinned_forum_topic_count_max") pinned forum topics
//@chat_id Chat identifier
//@message_thread_id Message thread identifier of the forum topic
//@is_pinned Pass true to pin the topic; pass false to unpin it
toggleForumTopicIsPinned chat_id:int53 message_thread_id:int53 is_pinned:Bool = Ok;

//@description Changes the order of pinned forum topics; requires can_manage_topics right in the supergroup @chat_id Chat identifier @message_thread_ids The new list of pinned forum topics
setPinnedForumTopics chat_id:int53 message_thread_ids:vector<int53> = Ok;

//@description Deletes all messages in a forum topic; requires can_delete_messages administrator right in the supergroup unless the user is creator of the topic, the topic has no messages from other users and has at most 11 messages
//@chat_id Identifier of the chat
//@message_thread_id Message thread identifier of the forum topic
deleteForumTopic chat_id:int53 message_thread_id:int53 = Ok;


//@description Returns information about an emoji reaction. Returns a 404 error if the reaction is not found @emoji Text representation of the reaction
getEmojiReaction emoji:string = EmojiReaction;

//@description Returns TGS stickers with generic animations for custom emoji reactions
getCustomEmojiReactionAnimations = Stickers;

//@description Returns reactions, which can be added to a message. The list can change after updateActiveEmojiReactions, updateChatAvailableReactions for the chat, or updateMessageInteractionInfo for the message
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message
//@row_size Number of reaction per row, 5-25
getMessageAvailableReactions chat_id:int53 message_id:int53 row_size:int32 = AvailableReactions;

//@description Clears the list of recently used reactions
clearRecentReactions = Ok;

//@description Adds a reaction or a tag to a message. Use getMessageAvailableReactions to receive the list of available reactions for the message
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message
//@reaction_type Type of the reaction to add. Use addPendingPaidMessageReaction instead to add the paid reaction
//@is_big Pass true if the reaction is added with a big animation
//@update_recent_reactions Pass true if the reaction needs to be added to recent reactions; tags are never added to the list of recent reactions
addMessageReaction chat_id:int53 message_id:int53 reaction_type:ReactionType is_big:Bool update_recent_reactions:Bool = Ok;

//@description Removes a reaction from a message. A chosen reaction can always be removed
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message
//@reaction_type Type of the reaction to remove. The paid reaction can't be removed
removeMessageReaction chat_id:int53 message_id:int53 reaction_type:ReactionType = Ok;

//@description Returns the list of message sender identifiers, which can be used to send a paid reaction in a chat @chat_id Chat identifier
getChatAvailablePaidMessageReactionSenders chat_id:int53 = MessageSenders;

//@description Adds the paid message reaction to a message. Use getMessageAvailableReactions to check whether the reaction is available for the message
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message
//@star_count Number of Telegram Stars to be used for the reaction. The total number of pending paid reactions must not exceed getOption("paid_reaction_star_count_max")
//@type Type of the paid reaction; pass null if the user didn't choose reaction type explicitly, for example, the reaction is set from the message bubble
addPendingPaidMessageReaction chat_id:int53 message_id:int53 star_count:int53 type:PaidReactionType = Ok;

//@description Applies all pending paid reactions on a message @chat_id Identifier of the chat to which the message belongs @message_id Identifier of the message
commitPendingPaidMessageReactions chat_id:int53 message_id:int53 = Ok;

//@description Removes all pending paid reactions on a message @chat_id Identifier of the chat to which the message belongs @message_id Identifier of the message
removePendingPaidMessageReactions chat_id:int53 message_id:int53 = Ok;

//@description Changes type of paid message reaction of the current user on a message. The message must have paid reaction added by the current user
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message
//@type New type of the paid reaction
setPaidMessageReactionType chat_id:int53 message_id:int53 type:PaidReactionType = Ok;

//@description Sets reactions on a message; for bots only
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message
//@reaction_types Types of the reaction to set; pass an empty list to remove the reactions
//@is_big Pass true if the reactions are added with a big animation
setMessageReactions chat_id:int53 message_id:int53 reaction_types:vector<ReactionType> is_big:Bool = Ok;

//@description Returns reactions added for a message, along with their sender
//@chat_id Identifier of the chat to which the message belongs
//@message_id Identifier of the message. Use message.interaction_info.reactions.can_get_added_reactions to check whether added reactions can be received for the message
//@reaction_type Type of the reactions to return; pass null to return all added reactions; reactionTypePaid isn't supported
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of reactions to be returned; must be positive and can't be greater than 100
getMessageAddedReactions chat_id:int53 message_id:int53 reaction_type:ReactionType offset:string limit:int32 = AddedReactions;

//@description Changes type of default reaction for the current user @reaction_type New type of the default reaction. The paid reaction can't be set as default
setDefaultReactionType reaction_type:ReactionType = Ok;

//@description Returns tags used in Saved Messages or a Saved Messages topic
//@saved_messages_topic_id Identifier of Saved Messages topic which tags will be returned; pass 0 to get all Saved Messages tags
getSavedMessagesTags saved_messages_topic_id:int53 = SavedMessagesTags;

//@description Changes label of a Saved Messages tag; for Telegram Premium users only @tag The tag which label will be changed @label New label for the tag; 0-12 characters
setSavedMessagesTagLabel tag:ReactionType label:string = Ok;

//@description Returns information about a message effect. Returns a 404 error if the effect is not found @effect_id Unique identifier of the effect
getMessageEffect effect_id:int64 = MessageEffect;


//@description Searches for a given quote in a text. Returns found quote start position in UTF-16 code units. Returns a 404 error if the quote is not found. Can be called synchronously
//@text Text in which to search for the quote
//@quote Quote to search for
//@quote_position Approximate quote position in UTF-16 code units
searchQuote text:formattedText quote:formattedText quote_position:int32 = FoundPosition;

//@description Returns all entities (mentions, hashtags, cashtags, bot commands, bank card numbers, URLs, and email addresses) found in the text. Can be called synchronously @text The text in which to look for entities
getTextEntities text:string = TextEntities;

//@description Parses Bold, Italic, Underline, Strikethrough, Spoiler, CustomEmoji, BlockQuote, ExpandableBlockQuote, Code, Pre, PreCode, TextUrl
//-and MentionName entities from a marked-up text. Can be called synchronously
//@text The text to parse
//@parse_mode Text parse mode
parseTextEntities text:string parse_mode:TextParseMode = FormattedText;

//@description Parses Markdown entities in a human-friendly format, ignoring markup errors. Can be called synchronously
//@text The text to parse. For example, "__italic__ ~~strikethrough~~ ||spoiler|| **bold** `code` ```pre``` __[italic__ text_url](telegram.org) __italic**bold italic__bold**"
parseMarkdown text:formattedText = FormattedText;

//@description Replaces text entities with Markdown formatting in a human-friendly format. Entities that can't be represented in Markdown unambiguously are kept as is. Can be called synchronously @text The text
getMarkdownText text:formattedText = FormattedText;

//@description Returns an emoji for the given country. Returns an empty string on failure. Can be called synchronously @country_code A two-letter ISO 3166-1 alpha-2 country code as received from getCountries
getCountryFlagEmoji country_code:string = Text;

//@description Returns the MIME type of a file, guessed by its extension. Returns an empty string on failure. Can be called synchronously @file_name The name of the file or path to the file
getFileMimeType file_name:string = Text;

//@description Returns the extension of a file, guessed by its MIME type. Returns an empty string on failure. Can be called synchronously @mime_type The MIME type of the file
getFileExtension mime_type:string = Text;

//@description Removes potentially dangerous characters from the name of a file. Returns an empty string on failure. Can be called synchronously @file_name File name or path to the file
cleanFileName file_name:string = Text;

//@description Returns a string stored in the local database from the specified localization target and language pack by its key. Returns a 404 error if the string is not found. Can be called synchronously
//@language_pack_database_path Path to the language pack database in which strings are stored
//@localization_target Localization target to which the language pack belongs
//@language_pack_id Language pack identifier
//@key Language pack key of the string to be returned
getLanguagePackString language_pack_database_path:string localization_target:string language_pack_id:string key:string = LanguagePackStringValue;

//@description Converts a JSON-serialized string to corresponding JsonValue object. Can be called synchronously @json The JSON-serialized string
getJsonValue json:string = JsonValue;

//@description Converts a JsonValue object to corresponding JSON-serialized string. Can be called synchronously @json_value The JsonValue object
getJsonString json_value:JsonValue = Text;

//@description Converts a themeParameters object to corresponding JSON-serialized string. Can be called synchronously @theme Theme parameters to convert to JSON
getThemeParametersJsonString theme:themeParameters = Text;


//@description Changes the user answer to a poll. A poll in quiz mode can be answered only once
//@chat_id Identifier of the chat to which the poll belongs
//@message_id Identifier of the message containing the poll
//@option_ids 0-based identifiers of answer options, chosen by the user. User can choose more than 1 answer option only is the poll allows multiple answers
setPollAnswer chat_id:int53 message_id:int53 option_ids:vector<int32> = Ok;

//@description Returns message senders voted for the specified option in a non-anonymous polls. For optimal performance, the number of returned users is chosen by TDLib
//@chat_id Identifier of the chat to which the poll belongs
//@message_id Identifier of the message containing the poll
//@option_id 0-based identifier of the answer option
//@offset Number of voters to skip in the result; must be non-negative
//@limit The maximum number of voters to be returned; must be positive and can't be greater than 50. For optimal performance, the number of returned voters is chosen by TDLib and can be smaller than the specified limit, even if the end of the voter list has not been reached
getPollVoters chat_id:int53 message_id:int53 option_id:int32 offset:int32 limit:int32 = MessageSenders;

//@description Stops a poll
//@chat_id Identifier of the chat to which the poll belongs
//@message_id Identifier of the message containing the poll. Use messageProperties.can_be_edited to check whether the poll can be stopped
//@reply_markup The new message reply markup; pass null if none; for bots only
stopPoll chat_id:int53 message_id:int53 reply_markup:ReplyMarkup = Ok;


//@description Hides a suggested action @action Suggested action to hide
hideSuggestedAction action:SuggestedAction = Ok;

//@description Hides the list of contacts that have close birthdays for 24 hours
hideContactCloseBirthdays = Ok;


//@description Returns information about a business connection by its identifier; for bots only @connection_id Identifier of the business connection to return
getBusinessConnection connection_id:string = BusinessConnection;


//@description Returns information about a button of type inlineKeyboardButtonTypeLoginUrl. The method needs to be called when the user presses the button
//@chat_id Chat identifier of the message with the button
//@message_id Message identifier of the message with the button. The message must not be scheduled
//@button_id Button identifier
getLoginUrlInfo chat_id:int53 message_id:int53 button_id:int53 = LoginUrlInfo;

//@description Returns an HTTP URL which can be used to automatically authorize the user on a website after clicking an inline button of type inlineKeyboardButtonTypeLoginUrl.
//-Use the method getLoginUrlInfo to find whether a prior user confirmation is needed. If an error is returned, then the button must be handled as an ordinary URL button
//@chat_id Chat identifier of the message with the button
//@message_id Message identifier of the message with the button
//@button_id Button identifier
//@allow_write_access Pass true to allow the bot to send messages to the current user
getLoginUrl chat_id:int53 message_id:int53 button_id:int53 allow_write_access:Bool = HttpUrl;


//@description Shares users after pressing a keyboardButtonTypeRequestUsers button with the bot
//@chat_id Identifier of the chat with the bot
//@message_id Identifier of the message with the button
//@button_id Identifier of the button
//@shared_user_ids Identifiers of the shared users
//@only_check Pass true to check that the users can be shared by the button instead of actually sharing them
shareUsersWithBot chat_id:int53 message_id:int53 button_id:int32 shared_user_ids:vector<int53> only_check:Bool = Ok;

//@description Shares a chat after pressing a keyboardButtonTypeRequestChat button with the bot
//@chat_id Identifier of the chat with the bot
//@message_id Identifier of the message with the button
//@button_id Identifier of the button
//@shared_chat_id Identifier of the shared chat
//@only_check Pass true to check that the chat can be shared by the button instead of actually sharing it. Doesn't check bot_is_member and bot_administrator_rights restrictions.
//-If the bot must be a member, then all chats from getGroupsInCommon and all chats, where the user can add the bot, are suitable. In the latter case the bot will be automatically added to the chat.
//-If the bot must be an administrator, then all chats, where the bot already has requested rights or can be added to administrators by the user, are suitable. In the latter case the bot will be automatically granted requested rights
shareChatWithBot chat_id:int53 message_id:int53 button_id:int32 shared_chat_id:int53 only_check:Bool = Ok;


//@description Sends an inline query to a bot and returns its results. Returns an error with code 502 if the bot fails to answer the query before the query timeout expires
//@bot_user_id Identifier of the target bot
//@chat_id Identifier of the chat where the query was sent
//@user_location Location of the user; pass null if unknown or the bot doesn't need user's location
//@query Text of the query
//@offset Offset of the first entry to return; use empty string to get the first chunk of results
getInlineQueryResults bot_user_id:int53 chat_id:int53 user_location:location query:string offset:string = InlineQueryResults;

//@description Sets the result of an inline query; for bots only
//@inline_query_id Identifier of the inline query
//@is_personal Pass true if results may be cached and returned only for the user that sent the query. By default, results may be returned to any user who sends the same query
//@button Button to be shown above inline query results; pass null if none
//@results The results of the query
//@cache_time Allowed time to cache the results of the query, in seconds
//@next_offset Offset for the next inline query; pass an empty string if there are no more results
answerInlineQuery inline_query_id:int64 is_personal:Bool button:inlineQueryResultsButton results:vector<InputInlineQueryResult> cache_time:int32 next_offset:string = Ok;

//@description Saves an inline message to be sent by the given user; for bots only
//@user_id Identifier of the user
//@result The description of the message
//@chat_types Types of the chats to which the message can be sent
savePreparedInlineMessage user_id:int53 result:InputInlineQueryResult chat_types:targetChatTypes = PreparedInlineMessageId;

//@description Saves an inline message to be sent by the given user
//@bot_user_id Identifier of the bot that created the message
//@prepared_message_id Identifier of the prepared message
getPreparedInlineMessage bot_user_id:int53 prepared_message_id:string = PreparedInlineMessage;


//@description Returns the most grossing Web App bots
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of bots to be returned; up to 100
getGrossingWebAppBots offset:string limit:int32 = FoundUsers;

//@description Returns information about a Web App by its short name. Returns a 404 error if the Web App is not found
//@bot_user_id Identifier of the target bot
//@web_app_short_name Short name of the Web App
searchWebApp bot_user_id:int53 web_app_short_name:string = FoundWebApp;

//@description Returns a default placeholder for Web Apps of a bot. This is an offline method. Returns a 404 error if the placeholder isn't known @bot_user_id Identifier of the target bot
getWebAppPlaceholder bot_user_id:int53 = Outline;

//@description Returns an HTTPS URL of a Web App to open after a link of the type internalLinkTypeWebApp is clicked
//@chat_id Identifier of the chat in which the link was clicked; pass 0 if none
//@bot_user_id Identifier of the target bot
//@web_app_short_name Short name of the Web App
//@start_parameter Start parameter from internalLinkTypeWebApp
//@allow_write_access Pass true if the current user allowed the bot to send them messages
//@parameters Parameters to use to open the Web App
getWebAppLinkUrl chat_id:int53 bot_user_id:int53 web_app_short_name:string start_parameter:string allow_write_access:Bool parameters:webAppOpenParameters = HttpUrl;

//@description Returns information needed to open the main Web App of a bot
//@chat_id Identifier of the chat in which the Web App is opened; pass 0 if none
//@bot_user_id Identifier of the target bot. If the bot is restricted for the current user, then show an error instead of calling the method
//@start_parameter Start parameter from internalLinkTypeMainWebApp
//@parameters Parameters to use to open the Web App
getMainWebApp chat_id:int53 bot_user_id:int53 start_parameter:string parameters:webAppOpenParameters = MainWebApp;

//@description Returns an HTTPS URL of a Web App to open from the side menu, a keyboardButtonTypeWebApp button, or an inlineQueryResultsButtonTypeWebApp button
//@bot_user_id Identifier of the target bot. If the bot is restricted for the current user, then show an error instead of calling the method
//@url The URL from a keyboardButtonTypeWebApp button, inlineQueryResultsButtonTypeWebApp button, or an empty string when the bot is opened from the side menu
//@parameters Parameters to use to open the Web App
getWebAppUrl bot_user_id:int53 url:string parameters:webAppOpenParameters = HttpUrl;

//@description Sends data received from a keyboardButtonTypeWebApp Web App to a bot
//@bot_user_id Identifier of the target bot
//@button_text Text of the keyboardButtonTypeWebApp button, which opened the Web App
//@data The data
sendWebAppData bot_user_id:int53 button_text:string data:string = Ok;

//@description Informs TDLib that a Web App is being opened from the attachment menu, a botMenuButton button, an internalLinkTypeAttachmentMenuBot link, or an inlineKeyboardButtonTypeWebApp button.
//-For each bot, a confirmation alert about data sent to the bot must be shown once
//@chat_id Identifier of the chat in which the Web App is opened. The Web App can't be opened in secret chats
//@bot_user_id Identifier of the bot, providing the Web App. If the bot is restricted for the current user, then show an error instead of calling the method
//@url The URL from an inlineKeyboardButtonTypeWebApp button, a botMenuButton button, an internalLinkTypeAttachmentMenuBot link, or an empty string otherwise
//@message_thread_id If not 0, the message thread identifier in which the message will be sent
//@reply_to Information about the message or story to be replied in the message sent by the Web App; pass null if none
//@parameters Parameters to use to open the Web App
openWebApp chat_id:int53 bot_user_id:int53 url:string message_thread_id:int53 reply_to:InputMessageReplyTo parameters:webAppOpenParameters = WebAppInfo;

//@description Informs TDLib that a previously opened Web App was closed @web_app_launch_id Identifier of Web App launch, received from openWebApp
closeWebApp web_app_launch_id:int64 = Ok;

//@description Sets the result of interaction with a Web App and sends corresponding message on behalf of the user to the chat from which the query originated; for bots only
//@web_app_query_id Identifier of the Web App query
//@result The result of the query
answerWebAppQuery web_app_query_id:string result:InputInlineQueryResult = SentWebAppMessage;

//@description Checks whether a file can be downloaded and saved locally by Web App request
//@bot_user_id Identifier of the bot, providing the Web App
//@file_name Name of the file
//@url URL of the file
checkWebAppFileDownload bot_user_id:int53 file_name:string url:string = Ok;


//@description Sends a callback query to a bot and returns an answer. Returns an error with code 502 if the bot fails to answer the query before the query timeout expires
//@chat_id Identifier of the chat with the message
//@message_id Identifier of the message from which the query originated. The message must not be scheduled
//@payload Query payload
getCallbackQueryAnswer chat_id:int53 message_id:int53 payload:CallbackQueryPayload = CallbackQueryAnswer;

//@description Sets the result of a callback query; for bots only
//@callback_query_id Identifier of the callback query
//@text Text of the answer
//@show_alert Pass true to show an alert to the user instead of a toast notification
//@url URL to be opened
//@cache_time Time during which the result of the query can be cached, in seconds
answerCallbackQuery callback_query_id:int64 text:string show_alert:Bool url:string cache_time:int32 = Ok;


//@description Sets the result of a shipping query; for bots only @shipping_query_id Identifier of the shipping query @shipping_options Available shipping options @error_message An error message, empty on success
answerShippingQuery shipping_query_id:int64 shipping_options:vector<shippingOption> error_message:string = Ok;

//@description Sets the result of a pre-checkout query; for bots only @pre_checkout_query_id Identifier of the pre-checkout query @error_message An error message, empty on success
answerPreCheckoutQuery pre_checkout_query_id:int64 error_message:string = Ok;


//@description Updates the game score of the specified user in the game; for bots only
//@chat_id The chat to which the message with the game belongs
//@message_id Identifier of the message
//@edit_message Pass true to edit the game message to include the current scoreboard
//@user_id User identifier
//@score The new score
//@force Pass true to update the score even if it decreases. If the score is 0, the user will be deleted from the high score table
setGameScore chat_id:int53 message_id:int53 edit_message:Bool user_id:int53 score:int32 force:Bool = Message;

//@description Updates the game score of the specified user in a game; for bots only
//@inline_message_id Inline message identifier
//@edit_message Pass true to edit the game message to include the current scoreboard
//@user_id User identifier
//@score The new score
//@force Pass true to update the score even if it decreases. If the score is 0, the user will be deleted from the high score table
setInlineGameScore inline_message_id:string edit_message:Bool user_id:int53 score:int32 force:Bool = Ok;

//@description Returns the high scores for a game and some part of the high score table in the range of the specified user; for bots only @chat_id The chat that contains the message with the game @message_id Identifier of the message @user_id User identifier
getGameHighScores chat_id:int53 message_id:int53 user_id:int53 = GameHighScores;

//@description Returns game high scores and some part of the high score table in the range of the specified user; for bots only @inline_message_id Inline message identifier @user_id User identifier
getInlineGameHighScores inline_message_id:string user_id:int53 = GameHighScores;


//@description Deletes the default reply markup from a chat. Must be called after a one-time keyboard or a replyMarkupForceReply reply markup has been used. An updateChatReplyMarkup update will be sent if the reply markup is changed
//@chat_id Chat identifier
//@message_id The message identifier of the used keyboard
deleteChatReplyMarkup chat_id:int53 message_id:int53 = Ok;


//@description Sends a notification about user activity in a chat
//@chat_id Chat identifier
//@message_thread_id If not 0, the message thread identifier in which the action was performed
//@business_connection_id Unique identifier of business connection on behalf of which to send the request; for bots only
//@action The action description; pass null to cancel the currently active action
sendChatAction chat_id:int53 message_thread_id:int53 business_connection_id:string action:ChatAction = Ok;


//@description Informs TDLib that the chat is opened by the user. Many useful activities depend on the chat being opened or closed (e.g., in supergroups and channels all updates are received only for opened chats) @chat_id Chat identifier
openChat chat_id:int53 = Ok;

//@description Informs TDLib that the chat is closed by the user. Many useful activities depend on the chat being opened or closed @chat_id Chat identifier
closeChat chat_id:int53 = Ok;

//@description Informs TDLib that messages are being viewed by the user. Sponsored messages must be marked as viewed only when the entire text of the message is shown on the screen (excluding the button).
//-Many useful activities depend on whether the messages are currently being viewed or not (e.g., marking messages as read, incrementing a view counter, updating a view counter, removing deleted messages in supergroups and channels)
//@chat_id Chat identifier
//@message_ids The identifiers of the messages being viewed
//@source Source of the message view; pass null to guess the source based on chat open state
//@force_read Pass true to mark as read the specified messages even the chat is closed
viewMessages chat_id:int53 message_ids:vector<int53> source:MessageSource force_read:Bool = Ok;

//@description Informs TDLib that the message content has been opened (e.g., the user has opened a photo, video, document, location or venue, or has listened to an audio file or voice note message).
//-An updateMessageContentOpened update will be generated if something has changed
//@chat_id Chat identifier of the message
//@message_id Identifier of the message with the opened content
openMessageContent chat_id:int53 message_id:int53 = Ok;

//@description Informs TDLib that a message with an animated emoji was clicked by the user. Returns a big animated sticker to be played or a 404 error if usual animation needs to be played @chat_id Chat identifier of the message @message_id Identifier of the clicked message
clickAnimatedEmojiMessage chat_id:int53 message_id:int53 = Sticker;

//@description Returns an HTTPS or a tg: link with the given type. Can be called before authorization @type Expected type of the link @is_http Pass true to create an HTTPS link (only available for some link types); pass false to create a tg: link
getInternalLink type:InternalLinkType is_http:Bool = HttpUrl;

//@description Returns information about the type of internal link. Returns a 404 error if the link is not internal. Can be called before authorization @link The link
getInternalLinkType link:string = InternalLinkType;

//@description Returns information about an action to be done when the current user clicks an external link. Don't use this method for links from secret chats if link preview is disabled in secret chats @link The link
getExternalLinkInfo link:string = LoginUrlInfo;

//@description Returns an HTTP URL which can be used to automatically authorize the current user on a website after clicking an HTTP link. Use the method getExternalLinkInfo to find whether a prior user confirmation is needed
//@link The HTTP link
//@allow_write_access Pass true if the current user allowed the bot, returned in getExternalLinkInfo, to send them messages
getExternalLink link:string allow_write_access:Bool = HttpUrl;


//@description Marks all mentions in a chat as read @chat_id Chat identifier
readAllChatMentions chat_id:int53 = Ok;

//@description Marks all mentions in a forum topic as read @chat_id Chat identifier @message_thread_id Message thread identifier in which mentions are marked as read
readAllMessageThreadMentions chat_id:int53 message_thread_id:int53 = Ok;

//@description Marks all reactions in a chat or a forum topic as read @chat_id Chat identifier
readAllChatReactions chat_id:int53 = Ok;

//@description Marks all reactions in a forum topic as read @chat_id Chat identifier @message_thread_id Message thread identifier in which reactions are marked as read
readAllMessageThreadReactions chat_id:int53 message_thread_id:int53 = Ok;


//@description Returns an existing chat corresponding to a given user @user_id User identifier @force Pass true to create the chat without a network request. In this case all information about the chat except its type, title and photo can be incorrect
createPrivateChat user_id:int53 force:Bool = Chat;

//@description Returns an existing chat corresponding to a known basic group @basic_group_id Basic group identifier @force Pass true to create the chat without a network request. In this case all information about the chat except its type, title and photo can be incorrect
createBasicGroupChat basic_group_id:int53 force:Bool = Chat;

//@description Returns an existing chat corresponding to a known supergroup or channel @supergroup_id Supergroup or channel identifier @force Pass true to create the chat without a network request. In this case all information about the chat except its type, title and photo can be incorrect
createSupergroupChat supergroup_id:int53 force:Bool = Chat;

//@description Returns an existing chat corresponding to a known secret chat @secret_chat_id Secret chat identifier
createSecretChat secret_chat_id:int32 = Chat;

//@description Creates a new basic group and sends a corresponding messageBasicGroupChatCreate. Returns information about the newly created chat
//@user_ids Identifiers of users to be added to the basic group; may be empty to create a basic group without other members
//@title Title of the new basic group; 1-128 characters
//@message_auto_delete_time Message auto-delete time value, in seconds; must be from 0 up to 365 * 86400 and be divisible by 86400. If 0, then messages aren't deleted automatically
createNewBasicGroupChat user_ids:vector<int53> title:string message_auto_delete_time:int32 = CreatedBasicGroupChat;

//@description Creates a new supergroup or channel and sends a corresponding messageSupergroupChatCreate. Returns the newly created chat
//@title Title of the new chat; 1-128 characters
//@is_forum Pass true to create a forum supergroup chat
//@is_channel Pass true to create a channel chat; ignored if a forum is created
//@param_description Chat description; 0-255 characters
//@location Chat location if a location-based supergroup is being created; pass null to create an ordinary supergroup chat
//@message_auto_delete_time Message auto-delete time value, in seconds; must be from 0 up to 365 * 86400 and be divisible by 86400. If 0, then messages aren't deleted automatically
//@for_import Pass true to create a supergroup for importing messages using importMessages
createNewSupergroupChat title:string is_forum:Bool is_channel:Bool description:string location:chatLocation message_auto_delete_time:int32 for_import:Bool = Chat;

//@description Creates a new secret chat. Returns the newly created chat @user_id Identifier of the target user
createNewSecretChat user_id:int53 = Chat;

//@description Creates a new supergroup from an existing basic group and sends a corresponding messageChatUpgradeTo and messageChatUpgradeFrom; requires owner privileges. Deactivates the original basic group @chat_id Identifier of the chat to upgrade
upgradeBasicGroupChatToSupergroupChat chat_id:int53 = Chat;


//@description Returns chat lists to which the chat can be added. This is an offline method @chat_id Chat identifier
getChatListsToAddChat chat_id:int53 = ChatLists;

//@description Adds a chat to a chat list. A chat can't be simultaneously in Main and Archive chat lists, so it is automatically removed from another one if needed
//@chat_id Chat identifier
//@chat_list The chat list. Use getChatListsToAddChat to get suitable chat lists
addChatToList chat_id:int53 chat_list:ChatList = Ok;

//@description Returns information about a chat folder by its identifier @chat_folder_id Chat folder identifier
getChatFolder chat_folder_id:int32 = ChatFolder;

//@description Creates new chat folder. Returns information about the created chat folder. There can be up to getOption("chat_folder_count_max") chat folders, but the limit can be increased with Telegram Premium @folder The new chat folder
createChatFolder folder:chatFolder = ChatFolderInfo;

//@description Edits existing chat folder. Returns information about the edited chat folder @chat_folder_id Chat folder identifier @folder The edited chat folder
editChatFolder chat_folder_id:int32 folder:chatFolder = ChatFolderInfo;

//@description Deletes existing chat folder @chat_folder_id Chat folder identifier @leave_chat_ids Identifiers of the chats to leave. The chats must be pinned or always included in the folder
deleteChatFolder chat_folder_id:int32 leave_chat_ids:vector<int53> = Ok;

//@description Returns identifiers of pinned or always included chats from a chat folder, which are suggested to be left when the chat folder is deleted @chat_folder_id Chat folder identifier
getChatFolderChatsToLeave chat_folder_id:int32 = Chats;

//@description Returns approximate number of chats in a being created chat folder. Main and archive chat lists must be fully preloaded for this function to work correctly @folder The new chat folder
getChatFolderChatCount folder:chatFolder = Count;

//@description Changes the order of chat folders @chat_folder_ids Identifiers of chat folders in the new correct order @main_chat_list_position Position of the main chat list among chat folders, 0-based. Can be non-zero only for Premium users
reorderChatFolders chat_folder_ids:vector<int32> main_chat_list_position:int32 = Ok;

//@description Toggles whether chat folder tags are enabled @are_tags_enabled Pass true to enable folder tags; pass false to disable them
toggleChatFolderTags are_tags_enabled:Bool = Ok;

//@description Returns recommended chat folders for the current user
getRecommendedChatFolders = RecommendedChatFolders;

//@description Returns default icon name for a folder. Can be called synchronously @folder Chat folder
getChatFolderDefaultIconName folder:chatFolder = ChatFolderIcon;

//@description Returns identifiers of chats from a chat folder, suitable for adding to a chat folder invite link @chat_folder_id Chat folder identifier
getChatsForChatFolderInviteLink chat_folder_id:int32 = Chats;

//@description Creates a new invite link for a chat folder. A link can be created for a chat folder if it has only pinned and included chats
//@chat_folder_id Chat folder identifier
//@name Name of the link; 0-32 characters
//@chat_ids Identifiers of chats to be accessible by the invite link. Use getChatsForChatFolderInviteLink to get suitable chats. Basic groups will be automatically converted to supergroups before link creation
createChatFolderInviteLink chat_folder_id:int32 name:string chat_ids:vector<int53> = ChatFolderInviteLink;

//@description Returns invite links created by the current user for a shareable chat folder @chat_folder_id Chat folder identifier
getChatFolderInviteLinks chat_folder_id:int32 = ChatFolderInviteLinks;

//@description Edits an invite link for a chat folder
//@chat_folder_id Chat folder identifier
//@invite_link Invite link to be edited
//@name New name of the link; 0-32 characters
//@chat_ids New identifiers of chats to be accessible by the invite link. Use getChatsForChatFolderInviteLink to get suitable chats. Basic groups will be automatically converted to supergroups before link editing
editChatFolderInviteLink chat_folder_id:int32 invite_link:string name:string chat_ids:vector<int53> = ChatFolderInviteLink;

//@description Deletes an invite link for a chat folder
//@chat_folder_id Chat folder identifier
//@invite_link Invite link to be deleted
deleteChatFolderInviteLink chat_folder_id:int32 invite_link:string = Ok;

//@description Checks the validity of an invite link for a chat folder and returns information about the corresponding chat folder @invite_link Invite link to be checked
checkChatFolderInviteLink invite_link:string = ChatFolderInviteLinkInfo;

//@description Adds a chat folder by an invite link @invite_link Invite link for the chat folder @chat_ids Identifiers of the chats added to the chat folder. The chats are automatically joined if they aren't joined yet
addChatFolderByInviteLink invite_link:string chat_ids:vector<int53> = Ok;

//@description Returns new chats added to a shareable chat folder by its owner. The method must be called at most once in getOption("chat_folder_new_chats_update_period") for the given chat folder @chat_folder_id Chat folder identifier
getChatFolderNewChats chat_folder_id:int32 = Chats;

//@description Process new chats added to a shareable chat folder by its owner @chat_folder_id Chat folder identifier @added_chat_ids Identifiers of the new chats, which are added to the chat folder. The chats are automatically joined if they aren't joined yet
processChatFolderNewChats chat_folder_id:int32 added_chat_ids:vector<int53> = Ok;

//@description Returns settings for automatic moving of chats to and from the Archive chat lists
getArchiveChatListSettings = ArchiveChatListSettings;

//@description Changes settings for automatic moving of chats to and from the Archive chat lists @settings New settings
setArchiveChatListSettings settings:archiveChatListSettings = Ok;


//@description Changes the chat title. Supported only for basic groups, supergroups and channels. Requires can_change_info member right
//@chat_id Chat identifier
//@title New title of the chat; 1-128 characters
setChatTitle chat_id:int53 title:string = Ok;

//@description Changes the photo of a chat. Supported only for basic groups, supergroups and channels. Requires can_change_info member right
//@chat_id Chat identifier
//@photo New chat photo; pass null to delete the chat photo
setChatPhoto chat_id:int53 photo:InputChatPhoto = Ok;

//@description Changes accent color and background custom emoji of a channel chat. Requires can_change_info administrator right
//@chat_id Chat identifier
//@accent_color_id Identifier of the accent color to use. The chat must have at least accentColor.min_channel_chat_boost_level boost level to pass the corresponding color
//@background_custom_emoji_id Identifier of a custom emoji to be shown on the reply header and link preview background; 0 if none. Use chatBoostLevelFeatures.can_set_background_custom_emoji to check whether a custom emoji can be set
setChatAccentColor chat_id:int53 accent_color_id:int32 background_custom_emoji_id:int64 = Ok;

//@description Changes accent color and background custom emoji for profile of a supergroup or channel chat. Requires can_change_info administrator right
//@chat_id Chat identifier
//@profile_accent_color_id Identifier of the accent color to use for profile; pass -1 if none. The chat must have at least profileAccentColor.min_supergroup_chat_boost_level for supergroups
//-or profileAccentColor.min_channel_chat_boost_level for channels boost level to pass the corresponding color
//@profile_background_custom_emoji_id Identifier of a custom emoji to be shown on the chat's profile photo background; 0 if none. Use chatBoostLevelFeatures.can_set_profile_background_custom_emoji to check whether a custom emoji can be set
setChatProfileAccentColor chat_id:int53 profile_accent_color_id:int32 profile_background_custom_emoji_id:int64 = Ok;

//@description Changes the message auto-delete or self-destruct (for secret chats) time in a chat. Requires change_info administrator right in basic groups, supergroups and channels.
//-Message auto-delete time can't be changed in a chat with the current user (Saved Messages) and the chat 777000 (Telegram).
//@chat_id Chat identifier
//@message_auto_delete_time New time value, in seconds; unless the chat is secret, it must be from 0 up to 365 * 86400 and be divisible by 86400. If 0, then messages aren't deleted automatically
setChatMessageAutoDeleteTime chat_id:int53 message_auto_delete_time:int32 = Ok;

//@description Changes the emoji status of a chat. Use chatBoostLevelFeatures.can_set_emoji_status to check whether an emoji status can be set. Requires can_change_info administrator right
//@chat_id Chat identifier
//@emoji_status New emoji status; pass null to remove emoji status
setChatEmojiStatus chat_id:int53 emoji_status:emojiStatus = Ok;

//@description Changes the chat members permissions. Supported only for basic groups and supergroups. Requires can_restrict_members administrator right
//@chat_id Chat identifier
//@permissions New non-administrator members permissions in the chat
setChatPermissions chat_id:int53 permissions:chatPermissions = Ok;

//@description Sets the background in a specific chat. Supported only in private and secret chats with non-deleted users, and in chats with sufficient boost level and can_change_info administrator right
//@chat_id Chat identifier
//@background The input background to use; pass null to create a new filled or chat theme background
//@type Background type; pass null to use default background type for the chosen background; backgroundTypeChatTheme isn't supported for private and secret chats.
//-Use chatBoostLevelFeatures.chat_theme_background_count and chatBoostLevelFeatures.can_set_custom_background to check whether the background type can be set in the boosted chat
//@dark_theme_dimming Dimming of the background in dark themes, as a percentage; 0-100. Applied only to Wallpaper and Fill types of background
//@only_for_self Pass true to set background only for self; pass false to set background for all chat users. Always false for backgrounds set in boosted chats. Background can be set for both users only by Telegram Premium users and if set background isn't of the type inputBackgroundPrevious
setChatBackground chat_id:int53 background:InputBackground type:BackgroundType dark_theme_dimming:int32 only_for_self:Bool = Ok;

//@description Deletes background in a specific chat
//@chat_id Chat identifier
//@restore_previous Pass true to restore previously set background. Can be used only in private and secret chats with non-deleted users if userFullInfo.set_chat_background == true.
//-Supposed to be used from messageChatSetBackground messages with the currently set background that was set for both sides by the other user
deleteChatBackground chat_id:int53 restore_previous:Bool = Ok;

//@description Changes the chat theme. Supported only in private and secret chats @chat_id Chat identifier @theme_name Name of the new chat theme; pass an empty string to return the default theme
setChatTheme chat_id:int53 theme_name:string = Ok;

//@description Changes the draft message in a chat
//@chat_id Chat identifier
//@message_thread_id If not 0, the message thread identifier in which the draft was changed
//@draft_message New draft message; pass null to remove the draft. All files in draft message content must be of the type inputFileLocal. Media thumbnails and captions are ignored
setChatDraftMessage chat_id:int53 message_thread_id:int53 draft_message:draftMessage = Ok;

//@description Changes the notification settings of a chat. Notification settings of a chat with the current user (Saved Messages) can't be changed
//@chat_id Chat identifier
//@notification_settings New notification settings for the chat. If the chat is muted for more than 366 days, it is considered to be muted forever
setChatNotificationSettings chat_id:int53 notification_settings:chatNotificationSettings = Ok;

//@description Changes the ability of users to save, forward, or copy chat content. Supported only for basic groups, supergroups and channels. Requires owner privileges
//@chat_id Chat identifier
//@has_protected_content New value of has_protected_content
toggleChatHasProtectedContent chat_id:int53 has_protected_content:Bool = Ok;

//@description Changes the view_as_topics setting of a forum chat or Saved Messages @chat_id Chat identifier @view_as_topics New value of view_as_topics
toggleChatViewAsTopics chat_id:int53 view_as_topics:Bool = Ok;

//@description Changes the translatable state of a chat @chat_id Chat identifier @is_translatable New value of is_translatable
toggleChatIsTranslatable chat_id:int53 is_translatable:Bool = Ok;

//@description Changes the marked as unread state of a chat @chat_id Chat identifier @is_marked_as_unread New value of is_marked_as_unread
toggleChatIsMarkedAsUnread chat_id:int53 is_marked_as_unread:Bool = Ok;

//@description Changes the value of the default disable_notification parameter, used when a message is sent to a chat @chat_id Chat identifier @default_disable_notification New value of default_disable_notification
toggleChatDefaultDisableNotification chat_id:int53 default_disable_notification:Bool = Ok;

//@description Changes reactions, available in a chat. Available for basic groups, supergroups, and channels. Requires can_change_info member right
//@chat_id Identifier of the chat
//@available_reactions Reactions available in the chat. All explicitly specified emoji reactions must be active. In channel chats up to the chat's boost level custom emoji reactions can be explicitly specified
setChatAvailableReactions chat_id:int53 available_reactions:ChatAvailableReactions = Ok;

//@description Changes application-specific data associated with a chat @chat_id Chat identifier @client_data New value of client_data
setChatClientData chat_id:int53 client_data:string = Ok;

//@description Changes information about a chat. Available for basic groups, supergroups, and channels. Requires can_change_info member right @chat_id Identifier of the chat @param_description New chat description; 0-255 characters
setChatDescription chat_id:int53 description:string = Ok;

//@description Changes the discussion group of a channel chat; requires can_change_info administrator right in the channel if it is specified
//@chat_id Identifier of the channel chat. Pass 0 to remove a link from the supergroup passed in the second argument to a linked channel chat (requires can_pin_messages member right in the supergroup)
//@discussion_chat_id Identifier of a new channel's discussion group. Use 0 to remove the discussion group. Use the method getSuitableDiscussionChats to find all suitable groups.
//-Basic group chats must be first upgraded to supergroup chats. If new chat members don't have access to old messages in the supergroup, then toggleSupergroupIsAllHistoryAvailable must be used first to change that
setChatDiscussionGroup chat_id:int53 discussion_chat_id:int53 = Ok;

//@description Changes the location of a chat. Available only for some location-based supergroups, use supergroupFullInfo.can_set_location to check whether the method is allowed to use @chat_id Chat identifier @location New location for the chat; must be valid and not null
setChatLocation chat_id:int53 location:chatLocation = Ok;

//@description Changes the slow mode delay of a chat. Available only for supergroups; requires can_restrict_members right @chat_id Chat identifier @slow_mode_delay New slow mode delay for the chat, in seconds; must be one of 0, 10, 30, 60, 300, 900, 3600
setChatSlowModeDelay chat_id:int53 slow_mode_delay:int32 = Ok;

//@description Pins a message in a chat. A message can be pinned only if messageProperties.can_be_pinned
//@chat_id Identifier of the chat
//@message_id Identifier of the new pinned message
//@disable_notification Pass true to disable notification about the pinned message. Notifications are always disabled in channels and private chats
//@only_for_self Pass true to pin the message only for self; private chats only
pinChatMessage chat_id:int53 message_id:int53 disable_notification:Bool only_for_self:Bool = Ok;

//@description Removes a pinned message from a chat; requires can_pin_messages member right if the chat is a basic group or supergroup, or can_edit_messages administrator right if the chat is a channel @chat_id Identifier of the chat @message_id Identifier of the removed pinned message
unpinChatMessage chat_id:int53 message_id:int53 = Ok;

//@description Removes all pinned messages from a chat; requires can_pin_messages member right if the chat is a basic group or supergroup, or can_edit_messages administrator right if the chat is a channel @chat_id Identifier of the chat
unpinAllChatMessages chat_id:int53 = Ok;

//@description Removes all pinned messages from a forum topic; requires can_pin_messages member right in the supergroup
//@chat_id Identifier of the chat
//@message_thread_id Message thread identifier in which messages will be unpinned
unpinAllMessageThreadMessages chat_id:int53 message_thread_id:int53 = Ok;


//@description Adds the current user as a new member to a chat. Private and secret chats can't be joined using this method. May return an error with a message "INVITE_REQUEST_SENT" if only a join request was created @chat_id Chat identifier
joinChat chat_id:int53 = Ok;

//@description Removes the current user from chat members. Private and secret chats can't be left using this method @chat_id Chat identifier
leaveChat chat_id:int53 = Ok;

//@description Adds a new member to a chat; requires can_invite_users member right. Members can't be added to private or secret chats. Returns information about members that weren't added
//@chat_id Chat identifier
//@user_id Identifier of the user
//@forward_limit The number of earlier messages from the chat to be forwarded to the new member; up to 100. Ignored for supergroups and channels, or if the added user is a bot
addChatMember chat_id:int53 user_id:int53 forward_limit:int32 = FailedToAddMembers;

//@description Adds multiple new members to a chat; requires can_invite_users member right. Currently, this method is only available for supergroups and channels.
//-This method can't be used to join a chat. Members can't be added to a channel if it has more than 200 members. Returns information about members that weren't added
//@chat_id Chat identifier
//@user_ids Identifiers of the users to be added to the chat. The maximum number of added users is 20 for supergroups and 100 for channels
addChatMembers chat_id:int53 user_ids:vector<int53> = FailedToAddMembers;

//@description Changes the status of a chat member; requires can_invite_users member right to add a chat member, can_promote_members administrator right to change administrator rights of the member,
//-and can_restrict_members administrator right to change restrictions of a user. This function is currently not suitable for transferring chat ownership; use transferChatOwnership instead.
//-Use addChatMember or banChatMember if some additional parameters needs to be passed
//@chat_id Chat identifier
//@member_id Member identifier. Chats can be only banned and unbanned in supergroups and channels
//@status The new status of the member in the chat
setChatMemberStatus chat_id:int53 member_id:MessageSender status:ChatMemberStatus = Ok;

//@description Bans a member in a chat; requires can_restrict_members administrator right. Members can't be banned in private or secret chats. In supergroups and channels, the user will not be able to return to the group on their own using invite links, etc., unless unbanned first
//@chat_id Chat identifier
//@member_id Member identifier
//@banned_until_date Point in time (Unix timestamp) when the user will be unbanned; 0 if never. If the user is banned for more than 366 days or for less than 30 seconds from the current time, the user is considered to be banned forever. Ignored in basic groups and if a chat is banned
//@revoke_messages Pass true to delete all messages in the chat for the user that is being removed. Always true for supergroups and channels
banChatMember chat_id:int53 member_id:MessageSender banned_until_date:int32 revoke_messages:Bool = Ok;

//@description Checks whether the current session can be used to transfer a chat ownership to another user
canTransferOwnership = CanTransferOwnershipResult;

//@description Changes the owner of a chat; requires owner privileges in the chat. Use the method canTransferOwnership to check whether the ownership can be transferred from the current session. Available only for supergroups and channel chats
//@chat_id Chat identifier
//@user_id Identifier of the user to which transfer the ownership. The ownership can't be transferred to a bot or to a deleted user
//@password The 2-step verification password of the current user
transferChatOwnership chat_id:int53 user_id:int53 password:string = Ok;

//@description Returns information about a single member of a chat @chat_id Chat identifier @member_id Member identifier
getChatMember chat_id:int53 member_id:MessageSender = ChatMember;

//@description Searches for a specified query in the first name, last name and usernames of the members of a specified chat. Requires administrator rights if the chat is a channel
//@chat_id Chat identifier
//@query Query to search for
//@limit The maximum number of users to be returned; up to 200
//@filter The type of users to search for; pass null to search among all chat members
searchChatMembers chat_id:int53 query:string limit:int32 filter:ChatMembersFilter = ChatMembers;

//@description Returns a list of administrators of the chat with their custom titles @chat_id Chat identifier
getChatAdministrators chat_id:int53 = ChatAdministrators;


//@description Clears message drafts in all chats @exclude_secret_chats Pass true to keep local message drafts in secret chats
clearAllDraftMessages exclude_secret_chats:Bool = Ok;


//@description Returns saved notification sound by its identifier. Returns a 404 error if there is no saved notification sound with the specified identifier @notification_sound_id Identifier of the notification sound
getSavedNotificationSound notification_sound_id:int64 = NotificationSounds;

//@description Returns the list of saved notification sounds. If a sound isn't in the list, then default sound needs to be used
getSavedNotificationSounds = NotificationSounds;

//@description Adds a new notification sound to the list of saved notification sounds. The new notification sound is added to the top of the list. If it is already in the list, its position isn't changed @sound Notification sound file to add
addSavedNotificationSound sound:InputFile = NotificationSound;

//@description Removes a notification sound from the list of saved notification sounds @notification_sound_id Identifier of the notification sound
removeSavedNotificationSound notification_sound_id:int64 = Ok;


//@description Returns the list of chats with non-default notification settings for new messages
//@scope If specified, only chats from the scope will be returned; pass null to return chats from all scopes
//@compare_sound Pass true to include in the response chats with only non-default sound
getChatNotificationSettingsExceptions scope:NotificationSettingsScope compare_sound:Bool = Chats;

//@description Returns the notification settings for chats of a given type @scope Types of chats for which to return the notification settings information
getScopeNotificationSettings scope:NotificationSettingsScope = ScopeNotificationSettings;

//@description Changes notification settings for chats of a given type @scope Types of chats for which to change the notification settings @notification_settings The new notification settings for the given scope
setScopeNotificationSettings scope:NotificationSettingsScope notification_settings:scopeNotificationSettings = Ok;

//@description Changes notification settings for reactions @notification_settings The new notification settings for reactions
setReactionNotificationSettings notification_settings:reactionNotificationSettings = Ok;

//@description Resets all chat and scope notification settings to their default values. By default, all chats are unmuted and message previews are shown
resetAllNotificationSettings = Ok;


//@description Changes the pinned state of a chat. There can be up to getOption("pinned_chat_count_max")/getOption("pinned_archived_chat_count_max") pinned non-secret chats and the same number of secret chats in the main/archive chat list. The limit can be increased with Telegram Premium
//@chat_list Chat list in which to change the pinned state of the chat
//@chat_id Chat identifier
//@is_pinned Pass true to pin the chat; pass false to unpin it
toggleChatIsPinned chat_list:ChatList chat_id:int53 is_pinned:Bool = Ok;

//@description Changes the order of pinned chats @chat_list Chat list in which to change the order of pinned chats @chat_ids The new list of pinned chats
setPinnedChats chat_list:ChatList chat_ids:vector<int53> = Ok;

//@description Traverse all chats in a chat list and marks all messages in the chats as read @chat_list Chat list in which to mark all chats as read
readChatList chat_list:ChatList = Ok;


//@description Returns the current weather in the given location @location The location
getCurrentWeather location:location = CurrentWeather;


//@description Returns a story
//@story_sender_chat_id Identifier of the chat that posted the story
//@story_id Story identifier
//@only_local Pass true to get only locally available information without sending network requests
getStory story_sender_chat_id:int53 story_id:int32 only_local:Bool = Story;

//@description Returns supergroup and channel chats in which the current user has the right to post stories. The chats must be rechecked with canSendStory before actually trying to post a story there
getChatsToSendStories = Chats;

//@description Checks whether the current user can send a story on behalf of a chat; requires can_post_stories right for supergroup and channel chats
//@chat_id Chat identifier. Pass Saved Messages chat identifier when posting a story on behalf of the current user
canSendStory chat_id:int53 = CanSendStoryResult;

//@description Sends a new story to a chat; requires can_post_stories right for supergroup and channel chats. Returns a temporary story
//@chat_id Identifier of the chat that will post the story. Pass Saved Messages chat identifier when posting a story on behalf of the current user
//@content Content of the story
//@areas Clickable rectangle areas to be shown on the story media; pass null if none
//@caption Story caption; pass null to use an empty caption; 0-getOption("story_caption_length_max") characters; can have entities only if getOption("can_use_text_entities_in_story_caption")
//@privacy_settings The privacy settings for the story; ignored for stories sent to supergroup and channel chats
//@active_period Period after which the story is moved to archive, in seconds; must be one of 6 * 3600, 12 * 3600, 86400, or 2 * 86400 for Telegram Premium users, and 86400 otherwise
//@from_story_full_id Full identifier of the original story, which content was used to create the story; pass null if the story isn't repost of another story
//@is_posted_to_chat_page Pass true to keep the story accessible after expiration
//@protect_content Pass true if the content of the story must be protected from forwarding and screenshotting
sendStory chat_id:int53 content:InputStoryContent areas:inputStoryAreas caption:formattedText privacy_settings:StoryPrivacySettings active_period:int32 from_story_full_id:storyFullId is_posted_to_chat_page:Bool protect_content:Bool = Story;

//@description Changes content and caption of a story. Can be called only if story.can_be_edited == true
//@story_sender_chat_id Identifier of the chat that posted the story
//@story_id Identifier of the story to edit
//@content New content of the story; pass null to keep the current content
//@areas New clickable rectangle areas to be shown on the story media; pass null to keep the current areas. Areas can't be edited if story content isn't changed
//@caption New story caption; pass null to keep the current caption
editStory story_sender_chat_id:int53 story_id:int32 content:InputStoryContent areas:inputStoryAreas caption:formattedText = Ok;

//@description Changes cover of a video story. Can be called only if story.can_be_edited == true and the story isn't being edited now
//@story_sender_chat_id Identifier of the chat that posted the story
//@story_id Identifier of the story to edit
//@cover_frame_timestamp New timestamp of the frame, which will be used as video thumbnail
editStoryCover story_sender_chat_id:int53 story_id:int32 cover_frame_timestamp:double = Ok;

//@description Changes privacy settings of a story. The method can be called only for stories posted on behalf of the current user and if story.can_be_edited == true
//@story_id Identifier of the story
//@privacy_settings The new privacy settings for the story
setStoryPrivacySettings story_id:int32 privacy_settings:StoryPrivacySettings = Ok;

//@description Toggles whether a story is accessible after expiration. Can be called only if story.can_toggle_is_posted_to_chat_page == true
//@story_sender_chat_id Identifier of the chat that posted the story
//@story_id Identifier of the story
//@is_posted_to_chat_page Pass true to make the story accessible after expiration; pass false to make it private
toggleStoryIsPostedToChatPage story_sender_chat_id:int53 story_id:int32 is_posted_to_chat_page:Bool = Ok;

//@description Deletes a previously sent story. Can be called only if story.can_be_deleted == true
//@story_sender_chat_id Identifier of the chat that posted the story
//@story_id Identifier of the story to delete
deleteStory story_sender_chat_id:int53 story_id:int32 = Ok;

//@description Returns the list of chats with non-default notification settings for stories
getStoryNotificationSettingsExceptions = Chats;

//@description Loads more active stories from a story list. The loaded stories will be sent through updates. Active stories are sorted by
//-the pair (active_stories.order, active_stories.story_sender_chat_id) in descending order. Returns a 404 error if all active stories have been loaded
//@story_list The story list in which to load active stories
loadActiveStories story_list:StoryList = Ok;

//@description Changes story list in which stories from the chat are shown @chat_id Identifier of the chat that posted stories @story_list New list for active stories posted by the chat
setChatActiveStoriesList chat_id:int53 story_list:StoryList = Ok;

//@description Returns the list of active stories posted by the given chat @chat_id Chat identifier
getChatActiveStories chat_id:int53 = ChatActiveStories;

//@description Returns the list of stories that posted by the given chat to its chat page. If from_story_id == 0, then pinned stories are returned first.
//-Then, stories are returned in reverse chronological order (i.e., in order of decreasing story_id). For optimal performance, the number of returned stories is chosen by TDLib
//@chat_id Chat identifier
//@from_story_id Identifier of the story starting from which stories must be returned; use 0 to get results from pinned and the newest story
//@limit The maximum number of stories to be returned.
//-For optimal performance, the number of returned stories is chosen by TDLib and can be smaller than the specified limit
getChatPostedToChatPageStories chat_id:int53 from_story_id:int32 limit:int32 = Stories;

//@description Returns the list of all stories posted by the given chat; requires can_edit_stories right in the chat.
//-The stories are returned in reverse chronological order (i.e., in order of decreasing story_id). For optimal performance, the number of returned stories is chosen by TDLib
//@chat_id Chat identifier
//@from_story_id Identifier of the story starting from which stories must be returned; use 0 to get results from the last story
//@limit The maximum number of stories to be returned.
//-For optimal performance, the number of returned stories is chosen by TDLib and can be smaller than the specified limit
getChatArchivedStories chat_id:int53 from_story_id:int32 limit:int32 = Stories;

//@description Changes the list of pinned stories on a chat page; requires can_edit_stories right in the chat
//@chat_id Identifier of the chat that posted the stories
//@story_ids New list of pinned stories. All stories must be posted to the chat page first. There can be up to getOption("pinned_story_count_max") pinned stories on a chat page
setChatPinnedStories chat_id:int53 story_ids:vector<int32> = Ok;

//@description Informs TDLib that a story is opened and is being viewed by the user
//@story_sender_chat_id The identifier of the sender of the opened story
//@story_id The identifier of the story
openStory story_sender_chat_id:int53 story_id:int32 = Ok;

//@description Informs TDLib that a story is closed by the user
//@story_sender_chat_id The identifier of the sender of the story to close
//@story_id The identifier of the story
closeStory story_sender_chat_id:int53 story_id:int32 = Ok;

//@description Returns reactions, which can be chosen for a story @row_size Number of reaction per row, 5-25
getStoryAvailableReactions row_size:int32 = AvailableReactions;

//@description Changes chosen reaction on a story that has already been sent
//@story_sender_chat_id The identifier of the sender of the story
//@story_id The identifier of the story
//@reaction_type Type of the reaction to set; pass null to remove the reaction. Custom emoji reactions can be used only by Telegram Premium users. Paid reactions can't be set
//@update_recent_reactions Pass true if the reaction needs to be added to recent reactions
setStoryReaction story_sender_chat_id:int53 story_id:int32 reaction_type:ReactionType update_recent_reactions:Bool = Ok;

//@description Returns interactions with a story. The method can be called only for stories posted on behalf of the current user
//@story_id Story identifier
//@query Query to search for in names, usernames and titles; may be empty to get all relevant interactions
//@only_contacts Pass true to get only interactions by contacts; pass false to get all relevant interactions
//@prefer_forwards Pass true to get forwards and reposts first, then reactions, then other views; pass false to get interactions sorted just by interaction date
//@prefer_with_reaction Pass true to get interactions with reaction first; pass false to get interactions sorted just by interaction date. Ignored if prefer_forwards == true
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of story interactions to return
getStoryInteractions story_id:int32 query:string only_contacts:Bool prefer_forwards:Bool prefer_with_reaction:Bool offset:string limit:int32 = StoryInteractions;

//@description Returns interactions with a story posted in a chat. Can be used only if story is posted on behalf of a chat and the user is an administrator in the chat
//@story_sender_chat_id The identifier of the sender of the story
//@story_id Story identifier
//@reaction_type Pass the default heart reaction or a suggested reaction type to receive only interactions with the specified reaction type; pass null to receive all interactions; reactionTypePaid isn't supported
//@prefer_forwards Pass true to get forwards and reposts first, then reactions, then other views; pass false to get interactions sorted just by interaction date
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of story interactions to return
getChatStoryInteractions story_sender_chat_id:int53 story_id:int32 reaction_type:ReactionType prefer_forwards:Bool offset:string limit:int32 = StoryInteractions;

//@description Reports a story to the Telegram moderators
//@story_sender_chat_id The identifier of the sender of the story to report
//@story_id The identifier of the story to report
//@option_id Option identifier chosen by the user; leave empty for the initial request
//@text Additional report details; 0-1024 characters; leave empty for the initial request
reportStory story_sender_chat_id:int53 story_id:int32 option_id:bytes text:string = ReportStoryResult;

//@description Activates stealth mode for stories, which hides all views of stories from the current user in the last "story_stealth_mode_past_period" seconds
//-and for the next "story_stealth_mode_future_period" seconds; for Telegram Premium users only
activateStoryStealthMode = Ok;

//@description Returns forwards of a story as a message to public chats and reposts by public channels. Can be used only if the story is posted on behalf of the current user or story.can_get_statistics == true.
//-For optimal performance, the number of returned messages and stories is chosen by TDLib
//@story_sender_chat_id The identifier of the sender of the story
//@story_id The identifier of the story
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of messages and stories to be returned; must be positive and can't be greater than 100. For optimal performance, the number of returned objects is chosen by TDLib and can be smaller than the specified limit
getStoryPublicForwards story_sender_chat_id:int53 story_id:int32 offset:string limit:int32 = PublicForwards;


//@description Returns the list of features available on the specific chat boost level. This is an offline method
//@is_channel Pass true to get the list of features for channels; pass false to get the list of features for supergroups
//@level Chat boost level
getChatBoostLevelFeatures is_channel:Bool level:int32 = ChatBoostLevelFeatures;

//@description Returns the list of features available for different chat boost levels. This is an offline method
//@is_channel Pass true to get the list of features for channels; pass false to get the list of features for supergroups
getChatBoostFeatures is_channel:Bool = ChatBoostFeatures;

//@description Returns the list of available chat boost slots for the current user
getAvailableChatBoostSlots = ChatBoostSlots;

//@description Returns the current boost status for a supergroup or a channel chat @chat_id Identifier of the chat
getChatBoostStatus chat_id:int53 = ChatBoostStatus;

//@description Boosts a chat and returns the list of available chat boost slots for the current user after the boost
//@chat_id Identifier of the chat
//@slot_ids Identifiers of boost slots of the current user from which to apply boosts to the chat
boostChat chat_id:int53 slot_ids:vector<int32> = ChatBoostSlots;

//@description Returns an HTTPS link to boost the specified supergroup or channel chat @chat_id Identifier of the chat
getChatBoostLink chat_id:int53 = ChatBoostLink;

//@description Returns information about a link to boost a chat. Can be called for any internal link of the type internalLinkTypeChatBoost @url The link to boost a chat
getChatBoostLinkInfo url:string = ChatBoostLinkInfo;

//@description Returns the list of boosts applied to a chat; requires administrator rights in the chat
//@chat_id Identifier of the chat
//@only_gift_codes Pass true to receive only boosts received from gift codes and giveaways created by the chat
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of boosts to be returned; up to 100. For optimal performance, the number of returned boosts can be smaller than the specified limit
getChatBoosts chat_id:int53 only_gift_codes:Bool offset:string limit:int32 = FoundChatBoosts;

//@description Returns the list of boosts applied to a chat by a given user; requires administrator rights in the chat; for bots only
//@chat_id Identifier of the chat
//@user_id Identifier of the user
getUserChatBoosts chat_id:int53 user_id:int53 = FoundChatBoosts;


//@description Returns information about a bot that can be added to attachment or side menu @bot_user_id Bot's user identifier
getAttachmentMenuBot bot_user_id:int53 = AttachmentMenuBot;

//@description Adds or removes a bot to attachment and side menu. Bot can be added to the menu, only if userTypeBot.can_be_added_to_attachment_menu == true
//@bot_user_id Bot's user identifier
//@is_added Pass true to add the bot to attachment menu; pass false to remove the bot from attachment menu
//@allow_write_access Pass true if the current user allowed the bot to send them messages. Ignored if is_added is false
toggleBotIsAddedToAttachmentMenu bot_user_id:int53 is_added:Bool allow_write_access:Bool = Ok;


//@description Returns up to 8 emoji statuses, which must be shown right after the default Premium Badge in the emoji status list for self status
getThemedEmojiStatuses = EmojiStatusCustomEmojis;

//@description Returns recent emoji statuses for self status
getRecentEmojiStatuses = EmojiStatuses;

//@description Returns available upgraded gift emoji statuses for self status
getUpgradedGiftEmojiStatuses = EmojiStatuses;

//@description Returns default emoji statuses for self status
getDefaultEmojiStatuses = EmojiStatusCustomEmojis;

//@description Clears the list of recently used emoji statuses for self status
clearRecentEmojiStatuses = Ok;


//@description Returns up to 8 emoji statuses, which must be shown in the emoji status list for chats
getThemedChatEmojiStatuses = EmojiStatusCustomEmojis;

//@description Returns default emoji statuses for chats
getDefaultChatEmojiStatuses = EmojiStatusCustomEmojis;

//@description Returns the list of emoji statuses, which can't be used as chat emoji status, even they are from a sticker set with is_allowed_as_chat_emoji_status == true
getDisallowedChatEmojiStatuses = EmojiStatusCustomEmojis;


//@description Downloads a file from the cloud. Download progress and completion of the download will be notified through updateFile updates
//@file_id Identifier of the file to download
//@priority Priority of the download (1-32). The higher the priority, the earlier the file will be downloaded. If the priorities of two files are equal, then the last one for which downloadFile/addFileToDownloads was called will be downloaded first
//@offset The starting position from which the file needs to be downloaded
//@limit Number of bytes which need to be downloaded starting from the "offset" position before the download will automatically be canceled; use 0 to download without a limit
//@synchronous Pass true to return response only after the file download has succeeded, has failed, has been canceled, or a new downloadFile request with different offset/limit parameters was sent; pass false to return file state immediately, just after the download has been started
downloadFile file_id:int32 priority:int32 offset:int53 limit:int53 synchronous:Bool = File;

//@description Returns file downloaded prefix size from a given offset, in bytes @file_id Identifier of the file @offset Offset from which downloaded prefix size needs to be calculated
getFileDownloadedPrefixSize file_id:int32 offset:int53 = FileDownloadedPrefixSize;

//@description Stops the downloading of a file. If a file has already been downloaded, does nothing @file_id Identifier of a file to stop downloading @only_if_pending Pass true to stop downloading only if it hasn't been started, i.e. request hasn't been sent to server
cancelDownloadFile file_id:int32 only_if_pending:Bool = Ok;

//@description Returns suggested name for saving a file in a given directory @file_id Identifier of the file @directory Directory in which the file is expected to be saved
getSuggestedFileName file_id:int32 directory:string = Text;

//@description Preliminary uploads a file to the cloud before sending it in a message, which can be useful for uploading of being recorded voice and video notes.
//-In all other cases there is no need to preliminary upload a file. Updates updateFile will be used to notify about upload progress.
//-The upload will not be completed until the file is sent in a message
//@file File to upload
//@file_type File type; pass null if unknown
//@priority Priority of the upload (1-32). The higher the priority, the earlier the file will be uploaded. If the priorities of two files are equal, then the first one for which preliminaryUploadFile was called will be uploaded first
preliminaryUploadFile file:InputFile file_type:FileType priority:int32 = File;

//@description Stops the preliminary uploading of a file. Supported only for files uploaded by using preliminaryUploadFile @file_id Identifier of the file to stop uploading
cancelPreliminaryUploadFile file_id:int32 = Ok;

//@description Writes a part of a generated file. This method is intended to be used only if the application has no direct access to TDLib's file system, because it is usually slower than a direct write to the destination file
//@generation_id The identifier of the generation process
//@offset The offset from which to write the data to the file
//@data The data to write
writeGeneratedFilePart generation_id:int64 offset:int53 data:bytes = Ok;

//@description Informs TDLib on a file generation progress
//@generation_id The identifier of the generation process
//@expected_size Expected size of the generated file, in bytes; 0 if unknown
//@local_prefix_size The number of bytes already generated
setFileGenerationProgress generation_id:int64 expected_size:int53 local_prefix_size:int53 = Ok;

//@description Finishes the file generation
//@generation_id The identifier of the generation process
//@error If passed, the file generation has failed and must be terminated; pass null if the file generation succeeded
finishFileGeneration generation_id:int64 error:error = Ok;

//@description Reads a part of a file from the TDLib file cache and returns read bytes. This method is intended to be used only if the application has no direct access to TDLib's file system, because it is usually slower than a direct read from the file
//@file_id Identifier of the file. The file must be located in the TDLib file cache
//@offset The offset from which to read the file
//@count Number of bytes to read. An error will be returned if there are not enough bytes available in the file from the specified position. Pass 0 to read all available data from the specified position
readFilePart file_id:int32 offset:int53 count:int53 = FilePart;

//@description Deletes a file from the TDLib file cache @file_id Identifier of the file to delete
deleteFile file_id:int32 = Ok;

//@description Adds a file from a message to the list of file downloads. Download progress and completion of the download will be notified through updateFile updates.
//-If message database is used, the list of file downloads is persistent across application restarts. The downloading is independent of download using downloadFile, i.e. it continues if downloadFile is canceled or is used to download a part of the file
//@file_id Identifier of the file to download
//@chat_id Chat identifier of the message with the file
//@message_id Message identifier
//@priority Priority of the download (1-32). The higher the priority, the earlier the file will be downloaded. If the priorities of two files are equal, then the last one for which downloadFile/addFileToDownloads was called will be downloaded first
addFileToDownloads file_id:int32 chat_id:int53 message_id:int53 priority:int32 = File;

//@description Changes pause state of a file in the file download list
//@file_id Identifier of the downloaded file
//@is_paused Pass true if the download is paused
toggleDownloadIsPaused file_id:int32 is_paused:Bool = Ok;

//@description Changes pause state of all files in the file download list @are_paused Pass true to pause all downloads; pass false to unpause them
toggleAllDownloadsArePaused are_paused:Bool = Ok;

//@description Removes a file from the file download list @file_id Identifier of the downloaded file @delete_from_cache Pass true to delete the file from the TDLib file cache
removeFileFromDownloads file_id:int32 delete_from_cache:Bool = Ok;

//@description Removes all files from the file download list
//@only_active Pass true to remove only active downloads, including paused
//@only_completed Pass true to remove only completed downloads
//@delete_from_cache Pass true to delete the file from the TDLib file cache
removeAllFilesFromDownloads only_active:Bool only_completed:Bool delete_from_cache:Bool = Ok;

//@description Searches for files in the file download list or recently downloaded files from the list
//@query Query to search for; may be empty to return all downloaded files
//@only_active Pass true to search only for active downloads, including paused
//@only_completed Pass true to search only for completed downloads
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of files to be returned
searchFileDownloads query:string only_active:Bool only_completed:Bool offset:string limit:int32 = FoundFileDownloads;


//@description Application or reCAPTCHA verification has been completed. Can be called before authorization
//@verification_id Unique identifier for the verification process as received from updateApplicationVerificationRequired or updateApplicationRecaptchaVerificationRequired
//@token Play Integrity API token for the Android application, or secret from push notification for the iOS application for application verification, or reCAPTCHA token for reCAPTCHA verifications;
//-pass an empty string to abort verification and receive error VERIFICATION_FAILED for the request
setApplicationVerificationToken verification_id:int53 token:string = Ok;


//@description Returns information about a file with messages exported from another application @message_file_head Beginning of the message file; up to 100 first lines
getMessageFileType message_file_head:string = MessageFileType;

//@description Returns a confirmation text to be shown to the user before starting message import
//@chat_id Identifier of a chat to which the messages will be imported. It must be an identifier of a private chat with a mutual contact or an identifier of a supergroup chat with can_change_info member right
getMessageImportConfirmationText chat_id:int53 = Text;

//@description Imports messages exported from another app
//@chat_id Identifier of a chat to which the messages will be imported. It must be an identifier of a private chat with a mutual contact or an identifier of a supergroup chat with can_change_info member right
//@message_file File with messages to import. Only inputFileLocal and inputFileGenerated are supported. The file must not be previously uploaded
//@attached_files Files used in the imported messages. Only inputFileLocal and inputFileGenerated are supported. The files must not be previously uploaded
importMessages chat_id:int53 message_file:InputFile attached_files:vector<InputFile> = Ok;


//@description Replaces current primary invite link for a chat with a new primary invite link. Available for basic groups, supergroups, and channels. Requires administrator privileges and can_invite_users right @chat_id Chat identifier
replacePrimaryChatInviteLink chat_id:int53 = ChatInviteLink;

//@description Creates a new invite link for a chat. Available for basic groups, supergroups, and channels. Requires administrator privileges and can_invite_users right in the chat
//@chat_id Chat identifier
//@name Invite link name; 0-32 characters
//@expiration_date Point in time (Unix timestamp) when the link will expire; pass 0 if never
//@member_limit The maximum number of chat members that can join the chat via the link simultaneously; 0-99999; pass 0 if not limited
//@creates_join_request Pass true if users joining the chat via the link need to be approved by chat administrators. In this case, member_limit must be 0
createChatInviteLink chat_id:int53 name:string expiration_date:int32 member_limit:int32 creates_join_request:Bool = ChatInviteLink;

//@description Creates a new subscription invite link for a channel chat. Requires can_invite_users right in the chat
//@chat_id Chat identifier
//@name Invite link name; 0-32 characters
//@subscription_pricing Information about subscription plan that will be applied to the users joining the chat via the link.
//-Subscription period must be 2592000 in production environment, and 60 or 300 if Telegram test environment is used
createChatSubscriptionInviteLink chat_id:int53 name:string subscription_pricing:starSubscriptionPricing = ChatInviteLink;

//@description Edits a non-primary invite link for a chat. Available for basic groups, supergroups, and channels.
//-If the link creates a subscription, then expiration_date, member_limit and creates_join_request must not be used.
//-Requires administrator privileges and can_invite_users right in the chat for own links and owner privileges for other links
//@chat_id Chat identifier
//@invite_link Invite link to be edited
//@name Invite link name; 0-32 characters
//@expiration_date Point in time (Unix timestamp) when the link will expire; pass 0 if never
//@member_limit The maximum number of chat members that can join the chat via the link simultaneously; 0-99999; pass 0 if not limited
//@creates_join_request Pass true if users joining the chat via the link need to be approved by chat administrators. In this case, member_limit must be 0
editChatInviteLink chat_id:int53 invite_link:string name:string expiration_date:int32 member_limit:int32 creates_join_request:Bool = ChatInviteLink;

//@description Edits a subscription invite link for a channel chat. Requires can_invite_users right in the chat for own links and owner privileges for other links
//@chat_id Chat identifier
//@invite_link Invite link to be edited
//@name Invite link name; 0-32 characters
editChatSubscriptionInviteLink chat_id:int53 invite_link:string name:string = ChatInviteLink;

//@description Returns information about an invite link. Requires administrator privileges and can_invite_users right in the chat to get own links and owner privileges to get other links
//@chat_id Chat identifier
//@invite_link Invite link to get
getChatInviteLink chat_id:int53 invite_link:string = ChatInviteLink;

//@description Returns the list of chat administrators with number of their invite links. Requires owner privileges in the chat @chat_id Chat identifier
getChatInviteLinkCounts chat_id:int53 = ChatInviteLinkCounts;

//@description Returns invite links for a chat created by specified administrator. Requires administrator privileges and can_invite_users right in the chat to get own links and owner privileges to get other links
//@chat_id Chat identifier
//@creator_user_id User identifier of a chat administrator. Must be an identifier of the current user for non-owner
//@is_revoked Pass true if revoked links needs to be returned instead of active or expired
//@offset_date Creation date of an invite link starting after which to return invite links; use 0 to get results from the beginning
//@offset_invite_link Invite link starting after which to return invite links; use empty string to get results from the beginning
//@limit The maximum number of invite links to return; up to 100
getChatInviteLinks chat_id:int53 creator_user_id:int53 is_revoked:Bool offset_date:int32 offset_invite_link:string limit:int32 = ChatInviteLinks;

//@description Returns chat members joined a chat via an invite link. Requires administrator privileges and can_invite_users right in the chat for own links and owner privileges for other links
//@chat_id Chat identifier
//@invite_link Invite link for which to return chat members
//@only_with_expired_subscription Pass true if the link is a subscription link and only members with expired subscription must be returned
//@offset_member A chat member from which to return next chat members; pass null to get results from the beginning
//@limit The maximum number of chat members to return; up to 100
getChatInviteLinkMembers chat_id:int53 invite_link:string only_with_expired_subscription:Bool offset_member:chatInviteLinkMember limit:int32 = ChatInviteLinkMembers;

//@description Revokes invite link for a chat. Available for basic groups, supergroups, and channels. Requires administrator privileges and can_invite_users right in the chat for own links and owner privileges for other links.
//-If a primary link is revoked, then additionally to the revoked link returns new primary link
//@chat_id Chat identifier
//@invite_link Invite link to be revoked
revokeChatInviteLink chat_id:int53 invite_link:string = ChatInviteLinks;

//@description Deletes revoked chat invite links. Requires administrator privileges and can_invite_users right in the chat for own links and owner privileges for other links @chat_id Chat identifier @invite_link Invite link to revoke
deleteRevokedChatInviteLink chat_id:int53 invite_link:string = Ok;

//@description Deletes all revoked chat invite links created by a given chat administrator. Requires administrator privileges and can_invite_users right in the chat for own links and owner privileges for other links
//@chat_id Chat identifier
//@creator_user_id User identifier of a chat administrator, which links will be deleted. Must be an identifier of the current user for non-owner
deleteAllRevokedChatInviteLinks chat_id:int53 creator_user_id:int53 = Ok;

//@description Checks the validity of an invite link for a chat and returns information about the corresponding chat @invite_link Invite link to be checked
checkChatInviteLink invite_link:string = ChatInviteLinkInfo;

//@description Uses an invite link to add the current user to the chat if possible. May return an error with a message "INVITE_REQUEST_SENT" if only a join request was created @invite_link Invite link to use
joinChatByInviteLink invite_link:string = Chat;

//@description Returns pending join requests in a chat
//@chat_id Chat identifier
//@invite_link Invite link for which to return join requests. If empty, all join requests will be returned. Requires administrator privileges and can_invite_users right in the chat for own links and owner privileges for other links
//@query A query to search for in the first names, last names and usernames of the users to return
//@offset_request A chat join request from which to return next requests; pass null to get results from the beginning
//@limit The maximum number of requests to join the chat to return
getChatJoinRequests chat_id:int53 invite_link:string query:string offset_request:chatJoinRequest limit:int32 = ChatJoinRequests;

//@description Handles a pending join request in a chat @chat_id Chat identifier @user_id Identifier of the user that sent the request @approve Pass true to approve the request; pass false to decline it
processChatJoinRequest chat_id:int53 user_id:int53 approve:Bool = Ok;

//@description Handles all pending join requests for a given link in a chat
//@chat_id Chat identifier
//@invite_link Invite link for which to process join requests. If empty, all join requests will be processed. Requires administrator privileges and can_invite_users right in the chat for own links and owner privileges for other links
//@approve Pass true to approve all requests; pass false to decline them
processChatJoinRequests chat_id:int53 invite_link:string approve:Bool = Ok;


//@description Creates a new call
//@user_id Identifier of the user to be called
//@protocol The call protocols supported by the application
//@is_video Pass true to create a video call
//@group_call_id Identifier of the group call to which the user will be added after exchanging private key via the call; pass 0 if none
createCall user_id:int53 protocol:callProtocol is_video:Bool group_call_id:int32 = CallId;

//@description Accepts an incoming call @call_id Call identifier @protocol The call protocols supported by the application
acceptCall call_id:int32 protocol:callProtocol = Ok;

//@description Sends call signaling data @call_id Call identifier @data The data
sendCallSignalingData call_id:int32 data:bytes = Ok;

//@description Discards a call
//@call_id Call identifier
//@is_disconnected Pass true if the user was disconnected
//@duration The call duration, in seconds
//@is_video Pass true if the call was a video call
//@connection_id Identifier of the connection used during the call
discardCall call_id:int32 is_disconnected:Bool duration:int32 is_video:Bool connection_id:int64 = Ok;

//@description Sends a call rating
//@call_id Call identifier
//@rating Call rating; 1-5
//@comment An optional user comment if the rating is less than 5
//@problems List of the exact types of problems with the call, specified by the user
sendCallRating call_id:int32 rating:int32 comment:string problems:vector<CallProblem> = Ok;

//@description Sends debug information for a call to Telegram servers @call_id Call identifier @debug_information Debug information in application-specific format
sendCallDebugInformation call_id:int32 debug_information:string = Ok;

//@description Sends log file for a call to Telegram servers @call_id Call identifier @log_file Call log file. Only inputFileLocal and inputFileGenerated are supported
sendCallLog call_id:int32 log_file:InputFile = Ok;


//@description Returns the list of participant identifiers, on whose behalf a video chat in the chat can be joined @chat_id Chat identifier
getVideoChatAvailableParticipants chat_id:int53 = MessageSenders;

//@description Changes default participant identifier, on whose behalf a video chat in the chat will be joined @chat_id Chat identifier @default_participant_id Default group call participant identifier to join the video chats
setVideoChatDefaultParticipant chat_id:int53 default_participant_id:MessageSender = Ok;

//@description Creates a video chat (a group call bound to a chat). Available only for basic groups, supergroups and channels; requires can_manage_video_chats administrator right
//@chat_id Identifier of a chat in which the video chat will be created
//@title Group call title; if empty, chat title will be used
//@start_date Point in time (Unix timestamp) when the group call is expected to be started by an administrator; 0 to start the video chat immediately. The date must be at least 10 seconds and at most 8 days in the future
//@is_rtmp_stream Pass true to create an RTMP stream instead of an ordinary video chat
createVideoChat chat_id:int53 title:string start_date:int32 is_rtmp_stream:Bool = GroupCallId;

//@description Creates a group call from a one-to-one call @call_id Call identifier
createGroupCall call_id:int32 = Ok;

//@description Returns RTMP URL for streaming to the chat; requires can_manage_video_chats administrator right @chat_id Chat identifier
getVideoChatRtmpUrl chat_id:int53 = RtmpUrl;

//@description Replaces the current RTMP URL for streaming to the chat; requires owner privileges @chat_id Chat identifier
replaceVideoChatRtmpUrl chat_id:int53 = RtmpUrl;

//@description Returns information about a group call @group_call_id Group call identifier
getGroupCall group_call_id:int32 = GroupCall;

//@description Starts a scheduled group call @group_call_id Group call identifier
startScheduledGroupCall group_call_id:int32 = Ok;

//@description Toggles whether the current user will receive a notification when the group call starts; scheduled group calls only
//@group_call_id Group call identifier
//@enabled_start_notification New value of the enabled_start_notification setting
toggleGroupCallEnabledStartNotification group_call_id:int32 enabled_start_notification:Bool = Ok;

//@description Joins an active group call. Returns join response payload for tgcalls
//@group_call_id Group call identifier
//@participant_id Identifier of a group call participant, which will be used to join the call; pass null to join as self; video chats only
//@audio_source_id Caller audio channel synchronization source identifier; received from tgcalls
//@payload Group call join payload; received from tgcalls
//@is_muted Pass true to join the call with muted microphone
//@is_my_video_enabled Pass true if the user's video is enabled
//@invite_hash If non-empty, invite hash to be used to join the group call without being muted by administrators
//@key_fingerprint Fingerprint of the encryption key for E2E group calls not bound to a chat; pass 0 for voice chats
joinGroupCall group_call_id:int32 participant_id:MessageSender audio_source_id:int32 payload:string is_muted:Bool is_my_video_enabled:Bool invite_hash:string key_fingerprint:int64 = Text;

//@description Starts screen sharing in a joined group call. Returns join response payload for tgcalls
//@group_call_id Group call identifier
//@audio_source_id Screen sharing audio channel synchronization source identifier; received from tgcalls
//@payload Group call join payload; received from tgcalls
startGroupCallScreenSharing group_call_id:int32 audio_source_id:int32 payload:string = Text;

//@description Pauses or unpauses screen sharing in a joined group call @group_call_id Group call identifier @is_paused Pass true to pause screen sharing; pass false to unpause it
toggleGroupCallScreenSharingIsPaused group_call_id:int32 is_paused:Bool = Ok;

//@description Ends screen sharing in a joined group call @group_call_id Group call identifier
endGroupCallScreenSharing group_call_id:int32 = Ok;

//@description Sets group call title. Requires groupCall.can_be_managed group call flag @group_call_id Group call identifier @title New group call title; 1-64 characters
setGroupCallTitle group_call_id:int32 title:string = Ok;

//@description Toggles whether new participants of a group call can be unmuted only by administrators of the group call. Requires groupCall.can_toggle_mute_new_participants group call flag
//@group_call_id Group call identifier
//@mute_new_participants New value of the mute_new_participants setting
toggleGroupCallMuteNewParticipants group_call_id:int32 mute_new_participants:Bool = Ok;

//@description Invites users to an active group call. Sends a service message of type messageInviteVideoChatParticipants for video chats
//@group_call_id Group call identifier
//@user_ids User identifiers. At most 10 users can be invited simultaneously
inviteGroupCallParticipants group_call_id:int32 user_ids:vector<int53> = Ok;

//@description Returns invite link to a video chat in a public chat
//@group_call_id Group call identifier
//@can_self_unmute Pass true if the invite link needs to contain an invite hash, passing which to joinGroupCall would allow the invited user to unmute themselves. Requires groupCall.can_be_managed group call flag
getGroupCallInviteLink group_call_id:int32 can_self_unmute:Bool = HttpUrl;

//@description Revokes invite link for a group call. Requires groupCall.can_be_managed group call flag @group_call_id Group call identifier
revokeGroupCallInviteLink group_call_id:int32 = Ok;

//@description Starts recording of an active group call. Requires groupCall.can_be_managed group call flag
//@group_call_id Group call identifier
//@title Group call recording title; 0-64 characters
//@record_video Pass true to record a video file instead of an audio file
//@use_portrait_orientation Pass true to use portrait orientation for video instead of landscape one
startGroupCallRecording group_call_id:int32 title:string record_video:Bool use_portrait_orientation:Bool = Ok;

//@description Ends recording of an active group call. Requires groupCall.can_be_managed group call flag @group_call_id Group call identifier
endGroupCallRecording group_call_id:int32 = Ok;

//@description Toggles whether current user's video is paused @group_call_id Group call identifier @is_my_video_paused Pass true if the current user's video is paused
toggleGroupCallIsMyVideoPaused group_call_id:int32 is_my_video_paused:Bool = Ok;

//@description Toggles whether current user's video is enabled @group_call_id Group call identifier @is_my_video_enabled Pass true if the current user's video is enabled
toggleGroupCallIsMyVideoEnabled group_call_id:int32 is_my_video_enabled:Bool = Ok;

//@description Informs TDLib that speaking state of a participant of an active group has changed
//@group_call_id Group call identifier
//@audio_source Group call participant's synchronization audio source identifier, or 0 for the current user
//@is_speaking Pass true if the user is speaking
setGroupCallParticipantIsSpeaking group_call_id:int32 audio_source:int32 is_speaking:Bool = Ok;

//@description Toggles whether a participant of an active group call is muted, unmuted, or allowed to unmute themselves
//@group_call_id Group call identifier
//@participant_id Participant identifier
//@is_muted Pass true to mute the user; pass false to unmute them
toggleGroupCallParticipantIsMuted group_call_id:int32 participant_id:MessageSender is_muted:Bool = Ok;

//@description Changes volume level of a participant of an active group call. If the current user can manage the group call, then the participant's volume level will be changed for all users with the default volume level
//@group_call_id Group call identifier
//@participant_id Participant identifier
//@volume_level New participant's volume level; 1-20000 in hundreds of percents
setGroupCallParticipantVolumeLevel group_call_id:int32 participant_id:MessageSender volume_level:int32 = Ok;

//@description Toggles whether a group call participant hand is rased
//@group_call_id Group call identifier
//@participant_id Participant identifier
//@is_hand_raised Pass true if the user's hand needs to be raised. Only self hand can be raised. Requires groupCall.can_be_managed group call flag to lower other's hand
toggleGroupCallParticipantIsHandRaised group_call_id:int32 participant_id:MessageSender is_hand_raised:Bool = Ok;

//@description Loads more participants of a group call. The loaded participants will be received through updates. Use the field groupCall.loaded_all_participants to check whether all participants have already been loaded
//@group_call_id Group call identifier. The group call must be previously received through getGroupCall and must be joined or being joined
//@limit The maximum number of participants to load; up to 100
loadGroupCallParticipants group_call_id:int32 limit:int32 = Ok;

//@description Leaves a group call @group_call_id Group call identifier
leaveGroupCall group_call_id:int32 = Ok;

//@description Ends a group call. Requires groupCall.can_be_managed @group_call_id Group call identifier
endGroupCall group_call_id:int32 = Ok;

//@description Returns information about available group call streams @group_call_id Group call identifier
getGroupCallStreams group_call_id:int32 = GroupCallStreams;

//@description Returns a file with a segment of a group call stream in a modified OGG format for audio or MPEG-4 format for video
//@group_call_id Group call identifier
//@time_offset Point in time when the stream segment begins; Unix timestamp in milliseconds
//@scale Segment duration scale; 0-1. Segment's duration is 1000/(2**scale) milliseconds
//@channel_id Identifier of an audio/video channel to get as received from tgcalls
//@video_quality Video quality as received from tgcalls; pass null to get the worst available quality
getGroupCallStreamSegment group_call_id:int32 time_offset:int53 scale:int32 channel_id:int32 video_quality:GroupCallVideoQuality = FilePart;


//@description Changes the block list of a message sender. Currently, only users and supergroup chats can be blocked
//@sender_id Identifier of a message sender to block/unblock
//@block_list New block list for the message sender; pass null to unblock the message sender
setMessageSenderBlockList sender_id:MessageSender block_list:BlockList = Ok;

//@description Blocks an original sender of a message in the Replies chat
//@message_id The identifier of an incoming message in the Replies chat
//@delete_message Pass true to delete the message
//@delete_all_messages Pass true to delete all messages from the same sender
//@report_spam Pass true to report the sender to the Telegram moderators
blockMessageSenderFromReplies message_id:int53 delete_message:Bool delete_all_messages:Bool report_spam:Bool = Ok;

//@description Returns users and chats that were blocked by the current user
//@block_list Block list from which to return users
//@offset Number of users and chats to skip in the result; must be non-negative
//@limit The maximum number of users and chats to return; up to 100
getBlockedMessageSenders block_list:BlockList offset:int32 limit:int32 = MessageSenders;


//@description Adds a user to the contact list or edits an existing contact by their user identifier
//@contact The contact to add or edit; phone number may be empty and needs to be specified only if known, vCard is ignored
//@share_phone_number Pass true to share the current user's phone number with the new contact. A corresponding rule to userPrivacySettingShowPhoneNumber will be added if needed.
//-Use the field userFullInfo.need_phone_number_privacy_exception to check whether the current user needs to be asked to share their phone number
addContact contact:contact share_phone_number:Bool = Ok;

//@description Adds new contacts or edits existing contacts by their phone numbers; contacts' user identifiers are ignored @contacts The list of contacts to import or edit; contacts' vCard are ignored and are not imported
importContacts contacts:vector<contact> = ImportedContacts;

//@description Returns all contacts of the user
getContacts = Users;

//@description Searches for the specified query in the first names, last names and usernames of the known user contacts
//@query Query to search for; may be empty to return all contacts
//@limit The maximum number of users to be returned
searchContacts query:string limit:int32 = Users;

//@description Removes users from the contact list @user_ids Identifiers of users to be deleted
removeContacts user_ids:vector<int53> = Ok;

//@description Returns the total number of imported contacts
getImportedContactCount = Count;

//@description Changes imported contacts using the list of contacts saved on the device. Imports newly added contacts and, if at least the file database is enabled, deletes recently deleted contacts.
//-Query result depends on the result of the previous query, so only one query is possible at the same time
//@contacts The new list of contacts, contact's vCard are ignored and are not imported
changeImportedContacts contacts:vector<contact> = ImportedContacts;

//@description Clears all imported contacts, contact list remains unchanged
clearImportedContacts = Ok;

//@description Changes the list of close friends of the current user @user_ids User identifiers of close friends; the users must be contacts of the current user
setCloseFriends user_ids:vector<int53> = Ok;

//@description Returns all close friends of the current user
getCloseFriends = Users;

//@description Changes a personal profile photo of a contact user @user_id User identifier @photo Profile photo to set; pass null to delete the photo; inputChatPhotoPrevious isn't supported in this function
setUserPersonalProfilePhoto user_id:int53 photo:InputChatPhoto = Ok;

//@description Suggests a profile photo to another regular user with common messages and allowing non-paid messages
//@user_id User identifier
//@photo Profile photo to suggest; inputChatPhotoPrevious isn't supported in this function
suggestUserProfilePhoto user_id:int53 photo:InputChatPhoto = Ok;

//@description Toggles whether the bot can manage emoji status of the current user @bot_user_id User identifier of the bot @can_manage_emoji_status Pass true if the bot is allowed to change emoji status of the user; pass false otherwise
toggleBotCanManageEmojiStatus bot_user_id:int53 can_manage_emoji_status:Bool = Ok;

//@description Changes the emoji status of a user; for bots only @user_id Identifier of the user @emoji_status New emoji status; pass null to switch to the default badge
setUserEmojiStatus user_id:int53 emoji_status:emojiStatus = Ok;


//@description Searches a user by their phone number. Returns a 404 error if the user can't be found
//@phone_number Phone number to search for
//@only_local Pass true to get only locally available information without sending network requests
searchUserByPhoneNumber phone_number:string only_local:Bool = User;

//@description Shares the phone number of the current user with a mutual contact. Supposed to be called when the user clicks on chatActionBarSharePhoneNumber @user_id Identifier of the user with whom to share the phone number. The user must be a mutual contact
sharePhoneNumber user_id:int53 = Ok;


//@description Returns the profile photos of a user. Personal and public photo aren't returned @user_id User identifier @offset The number of photos to skip; must be non-negative @limit The maximum number of photos to be returned; up to 100
getUserProfilePhotos user_id:int53 offset:int32 limit:int32 = ChatPhotos;


//@description Returns outline of a sticker. This is an offline method. Returns a 404 error if the outline isn't known
//@sticker_file_id File identifier of the sticker
//@for_animated_emoji Pass true to get the outline scaled for animated emoji
//@for_clicked_animated_emoji_message Pass true to get the outline scaled for clicked animated emoji message
getStickerOutline sticker_file_id:int32 for_animated_emoji:Bool for_clicked_animated_emoji_message:Bool = Outline;

//@description Returns stickers from the installed sticker sets that correspond to any of the given emoji or can be found by sticker-specific keywords. If the query is non-empty, then favorite, recently used or trending stickers may also be returned
//@sticker_type Type of the stickers to return
//@query Search query; a space-separated list of emojis or a keyword prefix. If empty, returns all known installed stickers
//@limit The maximum number of stickers to be returned
//@chat_id Chat identifier for which to return stickers. Available custom emoji stickers may be different for different chats
getStickers sticker_type:StickerType query:string limit:int32 chat_id:int53 = Stickers;

//@description Returns unique emoji that correspond to stickers to be found by the getStickers(sticker_type, query, 1000000, chat_id)
//@sticker_type Type of the stickers to search for
//@query Search query
//@chat_id Chat identifier for which to find stickers
//@return_only_main_emoji Pass true if only main emoji for each found sticker must be included in the result
getAllStickerEmojis sticker_type:StickerType query:string chat_id:int53 return_only_main_emoji:Bool = Emojis;

//@description Searches for stickers from public sticker sets that correspond to any of the given emoji
//@sticker_type Type of the stickers to return
//@emojis Space-separated list of emojis to search for
//@query Query to search for; may be empty to search for emoji only
//@input_language_codes List of possible IETF language tags of the user's input language; may be empty if unknown
//@offset The offset from which to return the stickers; must be non-negative
//@limit The maximum number of stickers to be returned; 0-100
searchStickers sticker_type:StickerType emojis:string query:string input_language_codes:vector<string> offset:int32 limit:int32 = Stickers;

//@description Returns greeting stickers from regular sticker sets that can be used for the start page of other users
getGreetingStickers = Stickers;

//@description Returns premium stickers from regular sticker sets @limit The maximum number of stickers to be returned; 0-100
getPremiumStickers limit:int32 = Stickers;

//@description Returns a list of installed sticker sets @sticker_type Type of the sticker sets to return
getInstalledStickerSets sticker_type:StickerType = StickerSets;

//@description Returns a list of archived sticker sets
//@sticker_type Type of the sticker sets to return
//@offset_sticker_set_id Identifier of the sticker set from which to return the result; use 0 to get results from the beginning
//@limit The maximum number of sticker sets to return; up to 100
getArchivedStickerSets sticker_type:StickerType offset_sticker_set_id:int64 limit:int32 = StickerSets;

//@description Returns a list of trending sticker sets. For optimal performance, the number of returned sticker sets is chosen by TDLib
//@sticker_type Type of the sticker sets to return
//@offset The offset from which to return the sticker sets; must be non-negative
//@limit The maximum number of sticker sets to be returned; up to 100. For optimal performance, the number of returned sticker sets is chosen by TDLib and can be smaller than the specified limit, even if the end of the list has not been reached
getTrendingStickerSets sticker_type:StickerType offset:int32 limit:int32 = TrendingStickerSets;

//@description Returns a list of sticker sets attached to a file, including regular, mask, and emoji sticker sets. Currently, only animations, photos, and videos can have attached sticker sets @file_id File identifier
getAttachedStickerSets file_id:int32 = StickerSets;

//@description Returns information about a sticker set by its identifier @set_id Identifier of the sticker set
getStickerSet set_id:int64 = StickerSet;

//@description Returns name of a sticker set by its identifier @set_id Identifier of the sticker set
getStickerSetName set_id:int64 = Text;

//@description Searches for a sticker set by its name @name Name of the sticker set @ignore_cache Pass true to ignore local cache of sticker sets and always send a network request
searchStickerSet name:string ignore_cache:Bool = StickerSet;

//@description Searches for installed sticker sets by looking for specified query in their title and name @sticker_type Type of the sticker sets to search for @query Query to search for @limit The maximum number of sticker sets to return
searchInstalledStickerSets sticker_type:StickerType query:string limit:int32 = StickerSets;

//@description Searches for sticker sets by looking for specified query in their title and name. Excludes installed sticker sets from the results
//@sticker_type Type of the sticker sets to return
//@query Query to search for
searchStickerSets sticker_type:StickerType query:string = StickerSets;

//@description Installs/uninstalls or activates/archives a sticker set @set_id Identifier of the sticker set @is_installed The new value of is_installed @is_archived The new value of is_archived. A sticker set can't be installed and archived simultaneously
changeStickerSet set_id:int64 is_installed:Bool is_archived:Bool = Ok;

//@description Informs the server that some trending sticker sets have been viewed by the user @sticker_set_ids Identifiers of viewed trending sticker sets
viewTrendingStickerSets sticker_set_ids:vector<int64> = Ok;

//@description Changes the order of installed sticker sets @sticker_type Type of the sticker sets to reorder @sticker_set_ids Identifiers of installed sticker sets in the new correct order
reorderInstalledStickerSets sticker_type:StickerType sticker_set_ids:vector<int64> = Ok;

//@description Returns a list of recently used stickers @is_attached Pass true to return stickers and masks that were recently attached to photos or video files; pass false to return recently sent stickers
getRecentStickers is_attached:Bool = Stickers;

//@description Manually adds a new sticker to the list of recently used stickers. The new sticker is added to the top of the list. If the sticker was already in the list, it is removed from the list first.
//-Only stickers belonging to a sticker set or in WEBP or WEBM format can be added to this list. Emoji stickers can't be added to recent stickers
//@is_attached Pass true to add the sticker to the list of stickers recently attached to photo or video files; pass false to add the sticker to the list of recently sent stickers
//@sticker Sticker file to add
addRecentSticker is_attached:Bool sticker:InputFile = Stickers;

//@description Removes a sticker from the list of recently used stickers @is_attached Pass true to remove the sticker from the list of stickers recently attached to photo or video files; pass false to remove the sticker from the list of recently sent stickers @sticker Sticker file to delete
removeRecentSticker is_attached:Bool sticker:InputFile = Ok;

//@description Clears the list of recently used stickers @is_attached Pass true to clear the list of stickers recently attached to photo or video files; pass false to clear the list of recently sent stickers
clearRecentStickers is_attached:Bool = Ok;

//@description Returns favorite stickers
getFavoriteStickers = Stickers;

//@description Adds a new sticker to the list of favorite stickers. The new sticker is added to the top of the list. If the sticker was already in the list, it is removed from the list first.
//-Only stickers belonging to a sticker set or in WEBP or WEBM format can be added to this list. Emoji stickers can't be added to favorite stickers
//@sticker Sticker file to add
addFavoriteSticker sticker:InputFile = Ok;

//@description Removes a sticker from the list of favorite stickers @sticker Sticker file to delete from the list
removeFavoriteSticker sticker:InputFile = Ok;

//@description Returns emoji corresponding to a sticker. The list is only for informational purposes, because a sticker is always sent with a fixed emoji from the corresponding Sticker object @sticker Sticker file identifier
getStickerEmojis sticker:InputFile = Emojis;

//@description Searches for emojis by keywords. Supported only if the file database is enabled. Order of results is unspecified
//@text Text to search for
//@input_language_codes List of possible IETF language tags of the user's input language; may be empty if unknown
searchEmojis text:string input_language_codes:vector<string> = EmojiKeywords;

//@description Return emojis matching the keyword. Supported only if the file database is enabled. Order of results is unspecified
//@text Text to search for
//@input_language_codes List of possible IETF language tags of the user's input language; may be empty if unknown
getKeywordEmojis text:string input_language_codes:vector<string> = Emojis;

//@description Returns available emoji categories @type Type of emoji categories to return; pass null to get default emoji categories
getEmojiCategories type:EmojiCategoryType = EmojiCategories;

//@description Returns an animated emoji corresponding to a given emoji. Returns a 404 error if the emoji has no animated emoji @emoji The emoji
getAnimatedEmoji emoji:string = AnimatedEmoji;

//@description Returns an HTTP URL which can be used to automatically log in to the translation platform and suggest new emoji replacements. The URL will be valid for 30 seconds after generation
//@language_code Language code for which the emoji replacements will be suggested
getEmojiSuggestionsUrl language_code:string = HttpUrl;

//@description Returns the list of custom emoji stickers by their identifiers. Stickers are returned in arbitrary order. Only found stickers are returned
//@custom_emoji_ids Identifiers of custom emoji stickers. At most 200 custom emoji stickers can be received simultaneously
getCustomEmojiStickers custom_emoji_ids:vector<int64> = Stickers;

//@description Returns default list of custom emoji stickers for placing on a chat photo
getDefaultChatPhotoCustomEmojiStickers = Stickers;

//@description Returns default list of custom emoji stickers for placing on a profile photo
getDefaultProfilePhotoCustomEmojiStickers = Stickers;

//@description Returns default list of custom emoji stickers for reply background
getDefaultBackgroundCustomEmojiStickers = Stickers;


//@description Returns saved animations
getSavedAnimations = Animations;

//@description Manually adds a new animation to the list of saved animations. The new animation is added to the beginning of the list. If the animation was already in the list, it is removed first.
//-Only non-secret video animations with MIME type "video/mp4" can be added to the list
//@animation The animation file to be added. Only animations known to the server (i.e., successfully sent via a message) can be added to the list
addSavedAnimation animation:InputFile = Ok;

//@description Removes an animation from the list of saved animations @animation Animation file to be removed
removeSavedAnimation animation:InputFile = Ok;


//@description Returns up to 20 recently used inline bots in the order of their last usage
getRecentInlineBots = Users;

//@description Returns the list of bots owned by the current user
getOwnedBots = Users;


//@description Searches for recently used hashtags by their prefix @prefix Hashtag prefix to search for @limit The maximum number of hashtags to be returned
searchHashtags prefix:string limit:int32 = Hashtags;

//@description Removes a hashtag from the list of recently used hashtags @hashtag Hashtag to delete
removeRecentHashtag hashtag:string = Ok;


//@description Returns a link preview by the text of a message. Do not call this function too often. Returns a 404 error if the text has no link preview
//@text Message text with formatting
//@link_preview_options Options to be used for generation of the link preview; pass null to use default link preview options
getLinkPreview text:formattedText link_preview_options:linkPreviewOptions = LinkPreview;

//@description Returns an instant view version of a web page if available. This is an offline method if only_local is true. Returns a 404 error if the web page has no instant view page
//@url The web page URL
//@only_local Pass true to get only locally available information without sending network requests
getWebPageInstantView url:string only_local:Bool = WebPageInstantView;


//@description Changes a profile photo for the current user
//@photo Profile photo to set
//@is_public Pass true to set a public photo, which will be visible even the main photo is hidden by privacy settings
setProfilePhoto photo:InputChatPhoto is_public:Bool = Ok;

//@description Deletes a profile photo @profile_photo_id Identifier of the profile photo to delete
deleteProfilePhoto profile_photo_id:int64 = Ok;

//@description Changes accent color and background custom emoji for the current user; for Telegram Premium users only
//@accent_color_id Identifier of the accent color to use
//@background_custom_emoji_id Identifier of a custom emoji to be shown on the reply header and link preview background; 0 if none
setAccentColor accent_color_id:int32 background_custom_emoji_id:int64 = Ok;

//@description Changes accent color and background custom emoji for profile of the current user; for Telegram Premium users only
//@profile_accent_color_id Identifier of the accent color to use for profile; pass -1 if none
//@profile_background_custom_emoji_id Identifier of a custom emoji to be shown on the user's profile photo background; 0 if none
setProfileAccentColor profile_accent_color_id:int32 profile_background_custom_emoji_id:int64 = Ok;

//@description Changes the first and last name of the current user @first_name The new value of the first name for the current user; 1-64 characters @last_name The new value of the optional last name for the current user; 0-64 characters
setName first_name:string last_name:string = Ok;

//@description Changes the bio of the current user @bio The new value of the user bio; 0-getOption("bio_length_max") characters without line feeds
setBio bio:string = Ok;

//@description Changes the editable username of the current user
//@username The new value of the username. Use an empty string to remove the username. The username can't be completely removed if there is another active or disabled username
setUsername username:string = Ok;

//@description Changes active state for a username of the current user. The editable username can't be disabled. May return an error with a message "USERNAMES_ACTIVE_TOO_MUCH" if the maximum number of active usernames has been reached
//@username The username to change
//@is_active Pass true to activate the username; pass false to disable it
toggleUsernameIsActive username:string is_active:Bool = Ok;

//@description Changes order of active usernames of the current user @usernames The new order of active usernames. All currently active usernames must be specified
reorderActiveUsernames usernames:vector<string> = Ok;

//@description Changes the birthdate of the current user @birthdate The new value of the current user's birthdate; pass null to remove the birthdate
setBirthdate birthdate:birthdate = Ok;

//@description Changes the personal chat of the current user @chat_id Identifier of the new personal chat; pass 0 to remove the chat. Use getSuitablePersonalChats to get suitable chats
setPersonalChat chat_id:int53 = Ok;

//@description Changes the emoji status of the current user; for Telegram Premium users only @emoji_status New emoji status; pass null to switch to the default badge
setEmojiStatus emoji_status:emojiStatus = Ok;

//@description Toggles whether the current user has sponsored messages enabled. The setting has no effect for users without Telegram Premium for which sponsored messages are always enabled
//@has_sponsored_messages_enabled Pass true to enable sponsored messages for the current user; false to disable them
toggleHasSponsoredMessagesEnabled has_sponsored_messages_enabled:Bool = Ok;

//@description Changes the business location of the current user. Requires Telegram Business subscription @location The new location of the business; pass null to remove the location
setBusinessLocation location:businessLocation = Ok;

//@description Changes the business opening hours of the current user. Requires Telegram Business subscription
//@opening_hours The new opening hours of the business; pass null to remove the opening hours; up to 28 time intervals can be specified
setBusinessOpeningHours opening_hours:businessOpeningHours = Ok;

//@description Changes the business greeting message settings of the current user. Requires Telegram Business subscription @greeting_message_settings The new settings for the greeting message of the business; pass null to disable the greeting message
setBusinessGreetingMessageSettings greeting_message_settings:businessGreetingMessageSettings = Ok;

//@description Changes the business away message settings of the current user. Requires Telegram Business subscription @away_message_settings The new settings for the away message of the business; pass null to disable the away message
setBusinessAwayMessageSettings away_message_settings:businessAwayMessageSettings = Ok;

//@description Changes the business start page of the current user. Requires Telegram Business subscription @start_page The new start page of the business; pass null to remove custom start page
setBusinessStartPage start_page:inputBusinessStartPage = Ok;


//@description Sends a code to the specified phone number. Aborts previous phone number verification if there was one. On success, returns information about the sent code
//@phone_number The phone number, in international format
//@settings Settings for the authentication of the user's phone number; pass null to use default settings
//@type Type of the request for which the code is sent
sendPhoneNumberCode phone_number:string settings:phoneNumberAuthenticationSettings type:PhoneNumberCodeType = AuthenticationCodeInfo;

//@description Sends Firebase Authentication SMS to the specified phone number. Works only when received a code of the type authenticationCodeTypeFirebaseAndroid or authenticationCodeTypeFirebaseIos
//@token Play Integrity API or SafetyNet Attestation API token for the Android application, or secret from push notification for the iOS application
sendPhoneNumberFirebaseSms token:string = Ok;

//@description Reports that authentication code wasn't delivered via SMS to the specified phone number; for official mobile applications only @mobile_network_code Current mobile network code
reportPhoneNumberCodeMissing mobile_network_code:string = Ok;

//@description Resends the authentication code sent to a phone number. Works only if the previously received authenticationCodeInfo next_code_type was not null and the server-specified timeout has passed
//@reason Reason of code resending; pass null if unknown
resendPhoneNumberCode reason:ResendCodeReason = AuthenticationCodeInfo;

//@description Check the authentication code and completes the request for which the code was sent if appropriate @code Authentication code to check
checkPhoneNumberCode code:string = Ok;


//@description Returns the business bot that is connected to the current user account. Returns a 404 error if there is no connected bot
getBusinessConnectedBot = BusinessConnectedBot;

//@description Adds or changes business bot that is connected to the current user account @bot Connection settings for the bot
setBusinessConnectedBot bot:businessConnectedBot = Ok;

//@description Deletes the business bot that is connected to the current user account @bot_user_id Unique user identifier for the bot
deleteBusinessConnectedBot bot_user_id:int53 = Ok;

//@description Pauses or resumes the connected business bot in a specific chat @chat_id Chat identifier @is_paused Pass true to pause the connected bot in the chat; pass false to resume the bot
toggleBusinessConnectedBotChatIsPaused chat_id:int53 is_paused:Bool = Ok;

//@description Removes the connected business bot from a specific chat by adding the chat to businessRecipients.excluded_chat_ids @chat_id Chat identifier
removeBusinessConnectedBotFromChat chat_id:int53 = Ok;


//@description Returns business chat links created for the current account
getBusinessChatLinks = BusinessChatLinks;

//@description Creates a business chat link for the current account. Requires Telegram Business subscription. There can be up to getOption("business_chat_link_count_max") links created. Returns the created link
//@link_info Information about the link to create
createBusinessChatLink link_info:inputBusinessChatLink = BusinessChatLink;

//@description Edits a business chat link of the current account. Requires Telegram Business subscription. Returns the edited link
//@link The link to edit
//@link_info New description of the link
editBusinessChatLink link:string link_info:inputBusinessChatLink = BusinessChatLink;

//@description Deletes a business chat link of the current account @link The link to delete
deleteBusinessChatLink link:string = Ok;

//@description Returns information about a business chat link @link_name Name of the link
getBusinessChatLinkInfo link_name:string = BusinessChatLinkInfo;


//@description Returns an HTTPS link, which can be used to get information about the current user
getUserLink = UserLink;

//@description Searches a user by a token from the user's link @token Token to search for
searchUserByToken token:string = User;


//@description Sets the list of commands supported by the bot for the given user scope and language; for bots only
//@scope The scope to which the commands are relevant; pass null to change commands in the default bot command scope
//@language_code A two-letter ISO 639-1 language code. If empty, the commands will be applied to all users from the given scope, for which language there are no dedicated commands
//@commands List of the bot's commands
setCommands scope:BotCommandScope language_code:string commands:vector<botCommand> = Ok;

//@description Deletes commands supported by the bot for the given user scope and language; for bots only
//@scope The scope to which the commands are relevant; pass null to delete commands in the default bot command scope
//@language_code A two-letter ISO 639-1 language code or an empty string
deleteCommands scope:BotCommandScope language_code:string = Ok;

//@description Returns the list of commands supported by the bot for the given user scope and language; for bots only
//@scope The scope to which the commands are relevant; pass null to get commands in the default bot command scope
//@language_code A two-letter ISO 639-1 language code or an empty string
getCommands scope:BotCommandScope language_code:string = BotCommands;

//@description Sets menu button for the given user or for all users; for bots only
//@user_id Identifier of the user or 0 to set menu button for all users
//@menu_button New menu button
setMenuButton user_id:int53 menu_button:botMenuButton = Ok;

//@description Returns menu button set by the bot for the given user; for bots only @user_id Identifier of the user or 0 to get the default menu button
getMenuButton user_id:int53 = BotMenuButton;

//@description Sets default administrator rights for adding the bot to basic group and supergroup chats; for bots only @default_group_administrator_rights Default administrator rights for adding the bot to basic group and supergroup chats; pass null to remove default rights
setDefaultGroupAdministratorRights default_group_administrator_rights:chatAdministratorRights = Ok;

//@description Sets default administrator rights for adding the bot to channel chats; for bots only @default_channel_administrator_rights Default administrator rights for adding the bot to channels; pass null to remove default rights
setDefaultChannelAdministratorRights default_channel_administrator_rights:chatAdministratorRights = Ok;


//@description Checks whether the specified bot can send messages to the user. Returns a 404 error if can't and the access can be granted by call to allowBotToSendMessages @bot_user_id Identifier of the target bot
canBotSendMessages bot_user_id:int53 = Ok;

//@description Allows the specified bot to send messages to the user @bot_user_id Identifier of the target bot
allowBotToSendMessages bot_user_id:int53 = Ok;

//@description Sends a custom request from a Web App
//@bot_user_id Identifier of the bot
//@method The method name
//@parameters JSON-serialized method parameters
sendWebAppCustomRequest bot_user_id:int53 method:string parameters:string = CustomRequestResult;


//@description Returns the list of media previews of a bot @bot_user_id Identifier of the target bot. The bot must have the main Web App
getBotMediaPreviews bot_user_id:int53 = BotMediaPreviews;

//@description Returns the list of media previews for the given language and the list of languages for which the bot has dedicated previews
//@bot_user_id Identifier of the target bot. The bot must be owned and must have the main Web App
//@language_code A two-letter ISO 639-1 language code for which to get previews. If empty, then default previews are returned
getBotMediaPreviewInfo bot_user_id:int53 language_code:string = BotMediaPreviewInfo;

//@description Adds a new media preview to the beginning of the list of media previews of a bot. Returns the added preview after addition is completed server-side. The total number of previews must not exceed getOption("bot_media_preview_count_max") for the given language
//@bot_user_id Identifier of the target bot. The bot must be owned and must have the main Web App
//@language_code A two-letter ISO 639-1 language code for which preview is added. If empty, then the preview will be shown to all users for whose languages there are no dedicated previews.
//-If non-empty, then there must be an official language pack of the same name, which is returned by getLocalizationTargetInfo
//@content Content of the added preview
addBotMediaPreview bot_user_id:int53 language_code:string content:InputStoryContent = BotMediaPreview;

//@description Replaces media preview in the list of media previews of a bot. Returns the new preview after edit is completed server-side
//@bot_user_id Identifier of the target bot. The bot must be owned and must have the main Web App
//@language_code Language code of the media preview to edit
//@file_id File identifier of the media to replace
//@content Content of the new preview
editBotMediaPreview bot_user_id:int53 language_code:string file_id:int32 content:InputStoryContent = BotMediaPreview;

//@description Changes order of media previews in the list of media previews of a bot
//@bot_user_id Identifier of the target bot. The bot must be owned and must have the main Web App
//@language_code Language code of the media previews to reorder
//@file_ids File identifiers of the media in the new order
reorderBotMediaPreviews bot_user_id:int53 language_code:string file_ids:vector<int32> = Ok;

//@description Delete media previews from the list of media previews of a bot
//@bot_user_id Identifier of the target bot. The bot must be owned and must have the main Web App
//@language_code Language code of the media previews to delete
//@file_ids File identifiers of the media to delete
deleteBotMediaPreviews bot_user_id:int53 language_code:string file_ids:vector<int32> = Ok;


//@description Sets the name of a bot. Can be called only if userTypeBot.can_be_edited == true
//@bot_user_id Identifier of the target bot
//@language_code A two-letter ISO 639-1 language code. If empty, the name will be shown to all users for whose languages there is no dedicated name
//@name New bot's name on the specified language; 0-64 characters; must be non-empty if language code is empty
setBotName bot_user_id:int53 language_code:string name:string = Ok;

//@description Returns the name of a bot in the given language. Can be called only if userTypeBot.can_be_edited == true
//@bot_user_id Identifier of the target bot
//@language_code A two-letter ISO 639-1 language code or an empty string
getBotName bot_user_id:int53 language_code:string = Text;

//@description Changes a profile photo for a bot @bot_user_id Identifier of the target bot @photo Profile photo to set; pass null to delete the chat photo
setBotProfilePhoto bot_user_id:int53 photo:InputChatPhoto = Ok;

//@description Changes active state for a username of a bot. The editable username can't be disabled. May return an error with a message "USERNAMES_ACTIVE_TOO_MUCH" if the maximum number of active usernames has been reached. Can be called only if userTypeBot.can_be_edited == true
//@bot_user_id Identifier of the target bot
//@username The username to change
//@is_active Pass true to activate the username; pass false to disable it
toggleBotUsernameIsActive bot_user_id:int53 username:string is_active:Bool = Ok;

//@description Changes order of active usernames of a bot. Can be called only if userTypeBot.can_be_edited == true @bot_user_id Identifier of the target bot @usernames The new order of active usernames. All currently active usernames must be specified
reorderBotActiveUsernames bot_user_id:int53 usernames:vector<string> = Ok;

//@description Sets the text shown in the chat with a bot if the chat is empty. Can be called only if userTypeBot.can_be_edited == true
//@bot_user_id Identifier of the target bot
//@language_code A two-letter ISO 639-1 language code. If empty, the description will be shown to all users for whose languages there is no dedicated description
//@param_description New bot's description on the specified language
setBotInfoDescription bot_user_id:int53 language_code:string description:string = Ok;

//@description Returns the text shown in the chat with a bot if the chat is empty in the given language. Can be called only if userTypeBot.can_be_edited == true
//@bot_user_id Identifier of the target bot
//@language_code A two-letter ISO 639-1 language code or an empty string
getBotInfoDescription bot_user_id:int53 language_code:string = Text;

//@description Sets the text shown on a bot's profile page and sent together with the link when users share the bot. Can be called only if userTypeBot.can_be_edited == true
//@bot_user_id Identifier of the target bot
//@language_code A two-letter ISO 639-1 language code. If empty, the short description will be shown to all users for whose languages there is no dedicated description
//@short_description New bot's short description on the specified language
setBotInfoShortDescription bot_user_id:int53 language_code:string short_description:string = Ok;

//@description Returns the text shown on a bot's profile page and sent together with the link when users share the bot in the given language. Can be called only if userTypeBot.can_be_edited == true
//@bot_user_id Identifier of the target bot
//@language_code A two-letter ISO 639-1 language code or an empty string
getBotInfoShortDescription bot_user_id:int53 language_code:string = Text;


//@description Changes the verification status of a user or a chat by an owned bot
//@bot_user_id Identifier of the owned bot, which will verify the user or the chat
//@verified_id Identifier of the user or the supergroup or channel chat, which will be verified by the bot
//@custom_description Custom description of verification reason; 0-getOption("bot_verification_custom_description_length_max").
//-If empty, then "was verified by organization "organization_name"" will be used as description. Can be specified only if the bot is allowed to provide custom description
setMessageSenderBotVerification bot_user_id:int53 verified_id:MessageSender custom_description:string = Ok;

//@description Removes the verification status of a user or a chat by an owned bot
//@bot_user_id Identifier of the owned bot, which verified the user or the chat
//@verified_id Identifier of the user or the supergroup or channel chat, which verification is removed
removeMessageSenderBotVerification bot_user_id:int53 verified_id:MessageSender = Ok;


//@description Returns all active sessions of the current user
getActiveSessions = Sessions;

//@description Terminates a session of the current user @session_id Session identifier
terminateSession session_id:int64 = Ok;

//@description Terminates all other sessions of the current user
terminateAllOtherSessions = Ok;

//@description Confirms an unconfirmed session of the current user from another device @session_id Session identifier
confirmSession session_id:int64 = Ok;

//@description Toggles whether a session can accept incoming calls @session_id Session identifier @can_accept_calls Pass true to allow accepting incoming calls by the session; pass false otherwise
toggleSessionCanAcceptCalls session_id:int64 can_accept_calls:Bool = Ok;

//@description Toggles whether a session can accept incoming secret chats @session_id Session identifier @can_accept_secret_chats Pass true to allow accepting secret chats by the session; pass false otherwise
toggleSessionCanAcceptSecretChats session_id:int64 can_accept_secret_chats:Bool = Ok;

//@description Changes the period of inactivity after which sessions will automatically be terminated @inactive_session_ttl_days New number of days of inactivity before sessions will be automatically terminated; 1-366 days
setInactiveSessionTtl inactive_session_ttl_days:int32 = Ok;


//@description Returns all website where the current user used Telegram to log in
getConnectedWebsites = ConnectedWebsites;

//@description Disconnects website from the current user's Telegram account @website_id Website identifier
disconnectWebsite website_id:int64 = Ok;

//@description Disconnects all websites from the current user's Telegram account
disconnectAllWebsites = Ok;


//@description Changes the editable username of a supergroup or channel, requires owner privileges in the supergroup or channel
//@supergroup_id Identifier of the supergroup or channel
//@username New value of the username. Use an empty string to remove the username. The username can't be completely removed if there is another active or disabled username
setSupergroupUsername supergroup_id:int53 username:string = Ok;

//@description Changes active state for a username of a supergroup or channel, requires owner privileges in the supergroup or channel. The editable username can't be disabled.
//-May return an error with a message "USERNAMES_ACTIVE_TOO_MUCH" if the maximum number of active usernames has been reached
//@supergroup_id Identifier of the supergroup or channel
//@username The username to change
//@is_active Pass true to activate the username; pass false to disable it
toggleSupergroupUsernameIsActive supergroup_id:int53 username:string is_active:Bool = Ok;

//@description Disables all active non-editable usernames of a supergroup or channel, requires owner privileges in the supergroup or channel @supergroup_id Identifier of the supergroup or channel
disableAllSupergroupUsernames supergroup_id:int53 = Ok;

//@description Changes order of active usernames of a supergroup or channel, requires owner privileges in the supergroup or channel
//@supergroup_id Identifier of the supergroup or channel
//@usernames The new order of active usernames. All currently active usernames must be specified
reorderSupergroupActiveUsernames supergroup_id:int53 usernames:vector<string> = Ok;

//@description Changes the sticker set of a supergroup; requires can_change_info administrator right @supergroup_id Identifier of the supergroup @sticker_set_id New value of the supergroup sticker set identifier. Use 0 to remove the supergroup sticker set
setSupergroupStickerSet supergroup_id:int53 sticker_set_id:int64 = Ok;

//@description Changes the custom emoji sticker set of a supergroup; requires can_change_info administrator right. The chat must have at least chatBoostFeatures.min_custom_emoji_sticker_set_boost_level boost level to pass the corresponding color
//@supergroup_id Identifier of the supergroup
//@custom_emoji_sticker_set_id New value of the custom emoji sticker set identifier for the supergroup. Use 0 to remove the custom emoji sticker set in the supergroup
setSupergroupCustomEmojiStickerSet supergroup_id:int53 custom_emoji_sticker_set_id:int64 = Ok;

//@description Changes the number of times the supergroup must be boosted by a user to ignore slow mode and chat permission restrictions; requires can_restrict_members administrator right
//@supergroup_id Identifier of the supergroup
//@unrestrict_boost_count New value of the unrestrict_boost_count supergroup setting; 0-8. Use 0 to remove the setting
setSupergroupUnrestrictBoostCount supergroup_id:int53 unrestrict_boost_count:int32 = Ok;

//@description Toggles whether sender signature or link to the account is added to sent messages in a channel; requires can_change_info member right
//@supergroup_id Identifier of the channel
//@sign_messages New value of sign_messages
//@show_message_sender New value of show_message_sender
toggleSupergroupSignMessages supergroup_id:int53 sign_messages:Bool show_message_sender:Bool = Ok;

//@description Toggles whether joining is mandatory to send messages to a discussion supergroup; requires can_restrict_members administrator right
//@supergroup_id Identifier of the supergroup that isn't a broadcast group
//@join_to_send_messages New value of join_to_send_messages
toggleSupergroupJoinToSendMessages supergroup_id:int53 join_to_send_messages:Bool = Ok;

//@description Toggles whether all users directly joining the supergroup need to be approved by supergroup administrators; requires can_restrict_members administrator right
//@supergroup_id Identifier of the supergroup that isn't a broadcast group
//@join_by_request New value of join_by_request
toggleSupergroupJoinByRequest supergroup_id:int53 join_by_request:Bool = Ok;

//@description Toggles whether the message history of a supergroup is available to new members; requires can_change_info member right @supergroup_id The identifier of the supergroup @is_all_history_available The new value of is_all_history_available
toggleSupergroupIsAllHistoryAvailable supergroup_id:int53 is_all_history_available:Bool = Ok;

//@description Toggles whether sponsored messages are shown in the channel chat; requires owner privileges in the channel. The chat must have at least chatBoostFeatures.min_sponsored_message_disable_boost_level boost level to disable sponsored messages
//@supergroup_id The identifier of the channel
//@can_have_sponsored_messages The new value of can_have_sponsored_messages
toggleSupergroupCanHaveSponsoredMessages supergroup_id:int53 can_have_sponsored_messages:Bool = Ok;

//@description Toggles whether non-administrators can receive only administrators and bots using getSupergroupMembers or searchChatMembers. Can be called only if supergroupFullInfo.can_hide_members == true
//@supergroup_id Identifier of the supergroup
//@has_hidden_members New value of has_hidden_members
toggleSupergroupHasHiddenMembers supergroup_id:int53 has_hidden_members:Bool = Ok;

//@description Toggles whether aggressive anti-spam checks are enabled in the supergroup. Can be called only if supergroupFullInfo.can_toggle_aggressive_anti_spam == true
//@supergroup_id The identifier of the supergroup, which isn't a broadcast group
//@has_aggressive_anti_spam_enabled The new value of has_aggressive_anti_spam_enabled
toggleSupergroupHasAggressiveAntiSpamEnabled supergroup_id:int53 has_aggressive_anti_spam_enabled:Bool = Ok;

//@description Toggles whether the supergroup is a forum; requires owner privileges in the supergroup. Discussion supergroups can't be converted to forums @supergroup_id Identifier of the supergroup @is_forum New value of is_forum
toggleSupergroupIsForum supergroup_id:int53 is_forum:Bool = Ok;

//@description Upgrades supergroup to a broadcast group; requires owner privileges in the supergroup @supergroup_id Identifier of the supergroup
toggleSupergroupIsBroadcastGroup supergroup_id:int53 = Ok;

//@description Reports messages in a supergroup as spam; requires administrator rights in the supergroup
//@supergroup_id Supergroup identifier
//@message_ids Identifiers of messages to report. Use messageProperties.can_report_supergroup_spam to check whether the message can be reported
reportSupergroupSpam supergroup_id:int53 message_ids:vector<int53> = Ok;

//@description Reports a false deletion of a message by aggressive anti-spam checks; requires administrator rights in the supergroup. Can be called only for messages from chatEventMessageDeleted with can_report_anti_spam_false_positive == true
//@supergroup_id Supergroup identifier
//@message_id Identifier of the erroneously deleted message from chatEventMessageDeleted
reportSupergroupAntiSpamFalsePositive supergroup_id:int53 message_id:int53 = Ok;

//@description Returns information about members or banned users in a supergroup or channel. Can be used only if supergroupFullInfo.can_get_members == true; additionally, administrator privileges may be required for some filters
//@supergroup_id Identifier of the supergroup or channel
//@filter The type of users to return; pass null to use supergroupMembersFilterRecent
//@offset Number of users to skip
//@limit The maximum number of users to be returned; up to 200
getSupergroupMembers supergroup_id:int53 filter:SupergroupMembersFilter offset:int32 limit:int32 = ChatMembers;


//@description Closes a secret chat, effectively transferring its state to secretChatStateClosed @secret_chat_id Secret chat identifier
closeSecretChat secret_chat_id:int32 = Ok;


//@description Returns a list of service actions taken by chat members and administrators in the last 48 hours. Available only for supergroups and channels. Requires administrator rights. Returns results in reverse chronological order (i.e., in order of decreasing event_id)
//@chat_id Chat identifier
//@query Search query by which to filter events
//@from_event_id Identifier of an event from which to return results. Use 0 to get results from the latest events
//@limit The maximum number of events to return; up to 100
//@filters The types of events to return; pass null to get chat events of all types
//@user_ids User identifiers by which to filter events. By default, events relating to all users will be returned
getChatEventLog chat_id:int53 query:string from_event_id:int64 limit:int32 filters:chatEventLogFilters user_ids:vector<int53> = ChatEvents;


//@description Returns the list of supported time zones
getTimeZones = TimeZones;


//@description Returns an invoice payment form. This method must be called when the user presses inline button of the type inlineKeyboardButtonTypeBuy, or wants to buy access to media in a messagePaidMedia message
//@input_invoice The invoice
//@theme Preferred payment form theme; pass null to use the default theme
getPaymentForm input_invoice:InputInvoice theme:themeParameters = PaymentForm;

//@description Validates the order information provided by a user and returns the available shipping options for a flexible invoice
//@input_invoice The invoice
//@order_info The order information, provided by the user; pass null if empty
//@allow_save Pass true to save the order information
validateOrderInfo input_invoice:InputInvoice order_info:orderInfo allow_save:Bool = ValidatedOrderInfo;

//@description Sends a filled-out payment form to the bot for final verification
//@input_invoice The invoice
//@payment_form_id Payment form identifier returned by getPaymentForm
//@order_info_id Identifier returned by validateOrderInfo, or an empty string
//@shipping_option_id Identifier of a chosen shipping option, if applicable
//@credentials The credentials chosen by user for payment; pass null for a payment in Telegram Stars
//@tip_amount Chosen by the user amount of tip in the smallest units of the currency
sendPaymentForm input_invoice:InputInvoice payment_form_id:int64 order_info_id:string shipping_option_id:string credentials:InputCredentials tip_amount:int53 = PaymentResult;

//@description Returns information about a successful payment @chat_id Chat identifier of the messagePaymentSuccessful message @message_id Message identifier
getPaymentReceipt chat_id:int53 message_id:int53 = PaymentReceipt;

//@description Returns saved order information. Returns a 404 error if there is no saved order information
getSavedOrderInfo = OrderInfo;

//@description Deletes saved order information
deleteSavedOrderInfo = Ok;

//@description Deletes saved credentials for all payment provider bots
deleteSavedCredentials = Ok;


//@description Returns gifts that can be sent to other users and channel chats
getAvailableGifts = Gifts;

//@description Sends a gift to another user or channel chat. May return an error with a message "STARGIFT_USAGE_LIMITED" if the gift was sold out
//@gift_id Identifier of the gift to send
//@owner_id Identifier of the user or the channel chat that will receive the gift
//@text Text to show along with the gift; 0-getOption("gift_text_length_max") characters. Only Bold, Italic, Underline, Strikethrough, Spoiler, and CustomEmoji entities are allowed.
//-Must be empty if the receiver enabled paid messages
//@is_private Pass true to show gift text and sender only to the gift receiver; otherwise, everyone will be able to see them
//@pay_for_upgrade Pass true to additionally pay for the gift upgrade and allow the receiver to upgrade it for free
sendGift gift_id:int64 owner_id:MessageSender text:formattedText is_private:Bool pay_for_upgrade:Bool = Ok;

//@description Sells a gift for Telegram Stars @received_gift_id Identifier of the gift
sellGift received_gift_id:string = Ok;

//@description Toggles whether a gift is shown on the current user's or the channel's profile page; requires can_post_messages administrator right in the channel chat
//@received_gift_id Identifier of the gift
//@is_saved Pass true to display the gift on the user's or the channel's profile page; pass false to remove it from the profile page
toggleGiftIsSaved received_gift_id:string is_saved:Bool = Ok;

//@description Changes the list of pinned gifts on the current user's or the channel's profile page; requires can_post_messages administrator right in the channel chat
//@owner_id Identifier of the user or the channel chat that received the gifts
//@received_gift_ids New list of pinned gifts. All gifts must be upgraded and saved on the profile page first. There can be up to getOption("pinned_gift_count_max") pinned gifts
setPinnedGifts owner_id:MessageSender received_gift_ids:vector<string> = Ok;

//@description Toggles whether notifications for new gifts received by a channel chat are sent to the current user; requires can_post_messages administrator right in the chat
//@chat_id Identifier of the channel chat
//@are_enabled Pass true to enable notifications about new gifts owned by the channel chat; pass false to disable the notifications
toggleChatGiftNotifications chat_id:int53 are_enabled:Bool = Ok;

//@description Returns examples of possible upgraded gifts for a regular gift @gift_id Identifier of the gift
getGiftUpgradePreview gift_id:int64 = GiftUpgradePreview;

//@description Upgrades a regular gift
//@received_gift_id Identifier of the gift
//@keep_original_details Pass true to keep the original gift text, sender and receiver in the upgraded gift
//@star_count The amount of Telegram Stars required to pay for the upgrade. It the gift has prepaid_upgrade_star_count > 0, then pass 0, otherwise, pass gift.upgrade_star_count
upgradeGift received_gift_id:string keep_original_details:Bool star_count:int53 = UpgradeGiftResult;

//@description Sends an upgraded gift to another user or a channel chat
//@received_gift_id Identifier of the gift
//@new_owner_id Identifier of the user or the channel chat that will receive the gift
//@star_count The amount of Telegram Stars required to pay for the transfer
transferGift received_gift_id:string new_owner_id:MessageSender star_count:int53 = Ok;

//@description Returns gifts received by the given user or chat
//@owner_id Identifier of the gift receiver
//@exclude_unsaved Pass true to exclude gifts that aren't saved to the chat's profile page. Always true for gifts received by other users and channel chats without can_post_messages administrator right
//@exclude_saved Pass true to exclude gifts that are saved to the chat's profile page. Always false for gifts received by other users and channel chats without can_post_messages administrator right
//@exclude_unlimited Pass true to exclude gifts that can be purchased unlimited number of times
//@exclude_limited Pass true to exclude gifts that can be purchased limited number of times
//@exclude_upgraded Pass true to exclude upgraded gifts
//@sort_by_price Pass true to sort results by gift price instead of send date
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of gifts to be returned; must be positive and can't be greater than 100. For optimal performance, the number of returned objects is chosen by TDLib and can be smaller than the specified limit
getReceivedGifts owner_id:MessageSender exclude_unsaved:Bool exclude_saved:Bool exclude_unlimited:Bool exclude_limited:Bool exclude_upgraded:Bool sort_by_price:Bool offset:string limit:int32 = ReceivedGifts;

//@description Returns information about a received gift @received_gift_id Identifier of the gift
getReceivedGift received_gift_id:string = ReceivedGift;

//@description Returns information about an upgraded gift by its name @name Unique name of the upgraded gift
getUpgradedGift name:string = UpgradedGift;

//@description Returns a URL for upgraded gift withdrawal in the TON blockchain as an NFT; requires owner privileges for gifts owned by a chat
//@received_gift_id Identifier of the gift
//@password The 2-step verification password of the current user
getUpgradedGiftWithdrawalUrl received_gift_id:string password:string = HttpUrl;


//@description Creates a link for the given invoice; for bots only
//@business_connection_id Unique identifier of business connection on behalf of which to send the request
//@invoice Information about the invoice of the type inputMessageInvoice
createInvoiceLink business_connection_id:string invoice:InputMessageContent = HttpUrl;

//@description Refunds a previously done payment in Telegram Stars; for bots only
//@user_id Identifier of the user that did the payment
//@telegram_payment_charge_id Telegram payment identifier
refundStarPayment user_id:int53 telegram_payment_charge_id:string = Ok;


//@description Returns a user that can be contacted to get support
getSupportUser = User;


//@description Constructs a persistent HTTP URL for a background @name Background name @type Background type; backgroundTypeChatTheme isn't supported
getBackgroundUrl name:string type:BackgroundType = HttpUrl;

//@description Searches for a background by its name @name The name of the background
searchBackground name:string = Background;

//@description Sets default background for chats; adds the background to the list of installed backgrounds
//@background The input background to use; pass null to create a new filled background
//@type Background type; pass null to use the default type of the remote background; backgroundTypeChatTheme isn't supported
//@for_dark_theme Pass true if the background is set for a dark theme
setDefaultBackground background:InputBackground type:BackgroundType for_dark_theme:Bool = Background;

//@description Deletes default background for chats @for_dark_theme Pass true if the background is deleted for a dark theme
deleteDefaultBackground for_dark_theme:Bool = Ok;

//@description Returns backgrounds installed by the user @for_dark_theme Pass true to order returned backgrounds for a dark theme
getInstalledBackgrounds for_dark_theme:Bool = Backgrounds;

//@description Removes background from the list of installed backgrounds @background_id The background identifier
removeInstalledBackground background_id:int64 = Ok;

//@description Resets list of installed backgrounds to its default value
resetInstalledBackgrounds = Ok;


//@description Returns information about the current localization target. This is an offline method if only_local is true. Can be called before authorization @only_local Pass true to get only locally available information without sending network requests
getLocalizationTargetInfo only_local:Bool = LocalizationTargetInfo;

//@description Returns information about a language pack. Returned language pack identifier may be different from a provided one. Can be called before authorization @language_pack_id Language pack identifier
getLanguagePackInfo language_pack_id:string = LanguagePackInfo;

//@description Returns strings from a language pack in the current localization target by their keys. Can be called before authorization
//@language_pack_id Language pack identifier of the strings to be returned
//@keys Language pack keys of the strings to be returned; leave empty to request all available strings
getLanguagePackStrings language_pack_id:string keys:vector<string> = LanguagePackStrings;

//@description Fetches the latest versions of all strings from a language pack in the current localization target from the server.
//-This method doesn't need to be called explicitly for the current used/base language packs. Can be called before authorization
//@language_pack_id Language pack identifier
synchronizeLanguagePack language_pack_id:string = Ok;

//@description Adds a custom server language pack to the list of installed language packs in current localization target. Can be called before authorization @language_pack_id Identifier of a language pack to be added
addCustomServerLanguagePack language_pack_id:string = Ok;

//@description Adds or changes a custom local language pack to the current localization target
//@info Information about the language pack. Language pack identifier must start with 'X', consist only of English letters, digits and hyphens, and must not exceed 64 characters. Can be called before authorization
//@strings Strings of the new language pack
setCustomLanguagePack info:languagePackInfo strings:vector<languagePackString> = Ok;

//@description Edits information about a custom local language pack in the current localization target. Can be called before authorization @info New information about the custom local language pack
editCustomLanguagePackInfo info:languagePackInfo = Ok;

//@description Adds, edits or deletes a string in a custom local language pack. Can be called before authorization @language_pack_id Identifier of a previously added custom local language pack in the current localization target @new_string New language pack string
setCustomLanguagePackString language_pack_id:string new_string:languagePackString = Ok;

//@description Deletes all information about a language pack in the current localization target. The language pack which is currently in use (including base language pack) or is being synchronized can't be deleted.
//-Can be called before authorization
//@language_pack_id Identifier of the language pack to delete
deleteLanguagePack language_pack_id:string = Ok;


//@description Registers the currently used device for receiving push notifications. Returns a globally unique identifier of the push notification subscription @device_token Device token @other_user_ids List of user identifiers of other users currently using the application
registerDevice device_token:DeviceToken other_user_ids:vector<int53> = PushReceiverId;

//@description Handles a push notification. Returns error with code 406 if the push notification is not supported and connection to the server is required to fetch new data. Can be called before authorization
//@payload JSON-encoded push notification payload with all fields sent by the server, and "google.sent_time" and "google.notification.sound" fields added
processPushNotification payload:string = Ok;

//@description Returns a globally unique push notification subscription identifier for identification of an account, which has received a push notification. Can be called synchronously @payload JSON-encoded push notification payload
getPushReceiverId payload:string = PushReceiverId;


//@description Returns t.me URLs recently visited by a newly registered user @referrer Google Play referrer to identify the user
getRecentlyVisitedTMeUrls referrer:string = TMeUrls;


//@description Changes user privacy settings @setting The privacy setting @rules The new privacy rules
setUserPrivacySettingRules setting:UserPrivacySetting rules:userPrivacySettingRules = Ok;

//@description Returns the current privacy settings @setting The privacy setting
getUserPrivacySettingRules setting:UserPrivacySetting = UserPrivacySettingRules;

//@description Changes privacy settings for message read date @settings New settings
setReadDatePrivacySettings settings:readDatePrivacySettings = Ok;

//@description Returns privacy settings for message read date
getReadDatePrivacySettings = ReadDatePrivacySettings;

//@description Changes privacy settings for new chat creation; can be used only if getOption("can_set_new_chat_privacy_settings") @settings New settings
setNewChatPrivacySettings settings:newChatPrivacySettings = Ok;

//@description Returns privacy settings for new chat creation
getNewChatPrivacySettings = NewChatPrivacySettings;

//@description Returns the total number of Telegram Stars received by the current user for paid messages from the given user @user_id Identifier of the user
getPaidMessageRevenue user_id:int53 = StarCount;

//@description Allows the specified user to send unpaid private messages to the current user by adding a rule to userPrivacySettingAllowUnpaidMessages
//@user_id Identifier of the user
//@refund_payments Pass true to refund the user previously paid messages
allowUnpaidMessagesFromUser user_id:int53 refund_payments:Bool = Ok;

//@description Changes the amount of Telegram Stars that must be paid to send a message to a supergroup chat; requires can_restrict_members administrator right and supergroupFullInfo.can_enable_paid_messages
//@chat_id Identifier of the supergroup chat
//@paid_message_star_count The new number of Telegram Stars that must be paid for each message that is sent to the supergroup chat unless the sender is an administrator of the chat; 0-getOption("paid_message_star_count_max").
//-The supergroup will receive getOption("paid_message_earnings_per_mille") Telegram Stars for each 1000 Telegram Stars paid for message sending
setChatPaidMessageStarCount chat_id:int53 paid_message_star_count:int53 = Ok;


//@description Check whether the current user can message another user or try to create a chat with them
//@user_id Identifier of the other user
//@only_local Pass true to get only locally available information without sending network requests
canSendMessageToUser user_id:int53 only_local:Bool = CanSendMessageToUserResult;


//@description Returns the value of an option by its name. (Check the list of available options on https://core.telegram.org/tdlib/options.) Can be called before authorization. Can be called synchronously for options "version" and "commit_hash"
//@name The name of the option
getOption name:string = OptionValue;

//@description Sets the value of an option. (Check the list of available options on https://core.telegram.org/tdlib/options.) Only writable options can be set. Can be called before authorization
//@name The name of the option
//@value The new value of the option; pass null to reset option value to a default value
setOption name:string value:OptionValue = Ok;


//@description Changes the period of inactivity after which the account of the current user will automatically be deleted @ttl New account TTL
setAccountTtl ttl:accountTtl = Ok;

//@description Returns the period of inactivity after which the account of the current user will automatically be deleted
getAccountTtl = AccountTtl;

//@description Deletes the account of the current user, deleting all information associated with the user from the server. The phone number of the account can be used to create a new account.
//-Can be called before authorization when the current authorization state is authorizationStateWaitPassword
//@reason The reason why the account was deleted; optional
//@password The 2-step verification password of the current user. If the current user isn't authorized, then an empty string can be passed and account deletion can be canceled within one week
deleteAccount reason:string password:string = Ok;


//@description Changes the default message auto-delete time for new chats @message_auto_delete_time New default message auto-delete time; must be from 0 up to 365 * 86400 and be divisible by 86400. If 0, then messages aren't deleted automatically
setDefaultMessageAutoDeleteTime message_auto_delete_time:messageAutoDeleteTime = Ok;

//@description Returns default message auto-delete time setting for new chats
getDefaultMessageAutoDeleteTime = MessageAutoDeleteTime;


//@description Removes a chat action bar without any other action @chat_id Chat identifier
removeChatActionBar chat_id:int53 = Ok;

//@description Reports a chat to the Telegram moderators. A chat can be reported only from the chat action bar, or if chat.can_be_reported
//@chat_id Chat identifier
//@option_id Option identifier chosen by the user; leave empty for the initial request
//@message_ids Identifiers of reported messages. Use messageProperties.can_report_chat to check whether the message can be reported
//@text Additional report details if asked by the server; 0-1024 characters; leave empty for the initial request
reportChat chat_id:int53 option_id:bytes message_ids:vector<int53> text:string = ReportChatResult;

//@description Reports a chat photo to the Telegram moderators. A chat photo can be reported only if chat.can_be_reported
//@chat_id Chat identifier
//@file_id Identifier of the photo to report. Only full photos from chatPhoto can be reported
//@reason The reason for reporting the chat photo
//@text Additional report details; 0-1024 characters
reportChatPhoto chat_id:int53 file_id:int32 reason:ReportReason text:string = Ok;

//@description Reports reactions set on a message to the Telegram moderators. Reactions on a message can be reported only if messageProperties.can_report_reactions
//@chat_id Chat identifier
//@message_id Message identifier
//@sender_id Identifier of the sender, which added the reaction
reportMessageReactions chat_id:int53 message_id:int53 sender_id:MessageSender = Ok;


//@description Returns detailed revenue statistics about a chat. Currently, this method can be used only
//-for channels if supergroupFullInfo.can_get_revenue_statistics == true or bots if userFullInfo.bot_info.can_get_revenue_statistics == true
//@chat_id Chat identifier
//@is_dark Pass true if a dark theme is used by the application
getChatRevenueStatistics chat_id:int53 is_dark:Bool = ChatRevenueStatistics;

//@description Returns a URL for chat revenue withdrawal; requires owner privileges in the channel chat or the bot. Currently, this method can be used only
//-if getOption("can_withdraw_chat_revenue") for channels with supergroupFullInfo.can_get_revenue_statistics == true or bots with userFullInfo.bot_info.can_get_revenue_statistics == true
//@chat_id Chat identifier
//@password The 2-step verification password of the current user
getChatRevenueWithdrawalUrl chat_id:int53 password:string = HttpUrl;

//@description Returns the list of revenue transactions for a chat. Currently, this method can be used only
//-for channels if supergroupFullInfo.can_get_revenue_statistics == true or bots if userFullInfo.bot_info.can_get_revenue_statistics == true
//@chat_id Chat identifier
//@offset Number of transactions to skip
//@limit The maximum number of transactions to be returned; up to 200
getChatRevenueTransactions chat_id:int53 offset:int32 limit:int32 = ChatRevenueTransactions;


//@description Returns detailed Telegram Star revenue statistics
//@owner_id Identifier of the owner of the Telegram Stars; can be identifier of the current user, an owned bot, or a supergroup or a channel chat with supergroupFullInfo.can_get_star_revenue_statistics == true
//@is_dark Pass true if a dark theme is used by the application
getStarRevenueStatistics owner_id:MessageSender is_dark:Bool = StarRevenueStatistics;

//@description Returns a URL for Telegram Star withdrawal
//@owner_id Identifier of the owner of the Telegram Stars; can be identifier of the current user, an owned bot, or an owned supergroup or channel chat
//@star_count The number of Telegram Stars to withdraw. Must be at least getOption("star_withdrawal_count_min")
//@password The 2-step verification password of the current user
getStarWithdrawalUrl owner_id:MessageSender star_count:int53 password:string = HttpUrl;

//@description Returns a URL for a Telegram Ad platform account that can be used to set up advertisements for the chat paid in the owned Telegram Stars
//@owner_id Identifier of the owner of the Telegram Stars; can be identifier of an owned bot, or identifier of an owned channel chat
getStarAdAccountUrl owner_id:MessageSender = HttpUrl;


//@description Returns detailed statistics about a chat. Currently, this method can be used only for supergroups and channels. Can be used only if supergroupFullInfo.can_get_statistics == true @chat_id Chat identifier @is_dark Pass true if a dark theme is used by the application
getChatStatistics chat_id:int53 is_dark:Bool = ChatStatistics;

//@description Returns detailed statistics about a message. Can be used only if messageProperties.can_get_statistics == true @chat_id Chat identifier @message_id Message identifier @is_dark Pass true if a dark theme is used by the application
getMessageStatistics chat_id:int53 message_id:int53 is_dark:Bool = MessageStatistics;

//@description Returns forwarded copies of a channel message to different public channels and public reposts as a story. Can be used only if messageProperties.can_get_statistics == true. For optimal performance, the number of returned messages and stories is chosen by TDLib
//@chat_id Chat identifier of the message
//@message_id Message identifier
//@offset Offset of the first entry to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of messages and stories to be returned; must be positive and can't be greater than 100. For optimal performance, the number of returned objects is chosen by TDLib and can be smaller than the specified limit
getMessagePublicForwards chat_id:int53 message_id:int53 offset:string limit:int32 = PublicForwards;

//@description Returns detailed statistics about a story. Can be used only if story.can_get_statistics == true @chat_id Chat identifier @story_id Story identifier @is_dark Pass true if a dark theme is used by the application
getStoryStatistics chat_id:int53 story_id:int32 is_dark:Bool = StoryStatistics;

//@description Loads an asynchronous or a zoomed in statistical graph @chat_id Chat identifier @token The token for graph loading @x X-value for zoomed in graph or 0 otherwise
getStatisticalGraph chat_id:int53 token:string x:int53 = StatisticalGraph;


//@description Returns storage usage statistics. Can be called before authorization
//@chat_limit The maximum number of chats with the largest storage usage for which separate statistics need to be returned. All other chats will be grouped in entries with chat_id == 0. If the chat info database is not used, the chat_limit is ignored and is always set to 0
getStorageStatistics chat_limit:int32 = StorageStatistics;

//@description Quickly returns approximate storage usage statistics. Can be called before authorization
getStorageStatisticsFast = StorageStatisticsFast;

//@description Returns database statistics
getDatabaseStatistics = DatabaseStatistics;

//@description Optimizes storage usage, i.e. deletes some files and returns new storage usage statistics. Secret thumbnails can't be deleted
//@size Limit on the total size of files after deletion, in bytes. Pass -1 to use the default limit
//@ttl Limit on the time that has passed since the last time a file was accessed (or creation time for some filesystems). Pass -1 to use the default limit
//@count Limit on the total number of files after deletion. Pass -1 to use the default limit
//@immunity_delay The amount of time after the creation of a file during which it can't be deleted, in seconds. Pass -1 to use the default value
//@file_types If non-empty, only files with the given types are considered. By default, all types except thumbnails, profile photos, stickers and wallpapers are deleted
//@chat_ids If non-empty, only files from the given chats are considered. Use 0 as chat identifier to delete files not belonging to any chat (e.g., profile photos)
//@exclude_chat_ids If non-empty, files from the given chats are excluded. Use 0 as chat identifier to exclude all files not belonging to any chat (e.g., profile photos)
//@return_deleted_file_statistics Pass true if statistics about the files that were deleted must be returned instead of the whole storage usage statistics. Affects only returned statistics
//@chat_limit Same as in getStorageStatistics. Affects only returned statistics
optimizeStorage size:int53 ttl:int32 count:int32 immunity_delay:int32 file_types:vector<FileType> chat_ids:vector<int53> exclude_chat_ids:vector<int53> return_deleted_file_statistics:Bool chat_limit:int32 = StorageStatistics;


//@description Sets the current network type. Can be called before authorization. Calling this method forces all network connections to reopen, mitigating the delay in switching between different networks,
//-so it must be called whenever the network is changed, even if the network type remains the same. Network type is used to check whether the library can use the network at all and also for collecting detailed network data usage statistics
//@type The new network type; pass null to set network type to networkTypeOther
setNetworkType type:NetworkType = Ok;

//@description Returns network data usage statistics. Can be called before authorization @only_current Pass true to get statistics only for the current library launch
getNetworkStatistics only_current:Bool = NetworkStatistics;

//@description Adds the specified data to data usage statistics. Can be called before authorization @entry The network statistics entry with the data to be added to statistics
addNetworkStatistics entry:NetworkStatisticsEntry = Ok;

//@description Resets all network data usage statistics to zero. Can be called before authorization
resetNetworkStatistics = Ok;

//@description Returns auto-download settings presets for the current user
getAutoDownloadSettingsPresets = AutoDownloadSettingsPresets;

//@description Sets auto-download settings @settings New user auto-download settings @type Type of the network for which the new settings are relevant
setAutoDownloadSettings settings:autoDownloadSettings type:NetworkType = Ok;

//@description Returns autosave settings for the current user
getAutosaveSettings = AutosaveSettings;

//@description Sets autosave settings for the given scope. The method is guaranteed to work only after at least one call to getAutosaveSettings @scope Autosave settings scope @settings New autosave settings for the scope; pass null to set autosave settings to default
setAutosaveSettings scope:AutosaveSettingsScope settings:scopeAutosaveSettings = Ok;

//@description Clears the list of all autosave settings exceptions. The method is guaranteed to work only after at least one call to getAutosaveSettings
clearAutosaveSettingsExceptions = Ok;


//@description Returns information about a bank card @bank_card_number The bank card number
getBankCardInfo bank_card_number:string = BankCardInfo;


//@description Returns one of the available Telegram Passport elements @type Telegram Passport element type @password The 2-step verification password of the current user
getPassportElement type:PassportElementType password:string = PassportElement;

//@description Returns all available Telegram Passport elements @password The 2-step verification password of the current user
getAllPassportElements password:string = PassportElements;

//@description Adds an element to the user's Telegram Passport. May return an error with a message "PHONE_VERIFICATION_NEEDED" or "EMAIL_VERIFICATION_NEEDED" if the chosen phone number or the chosen email address must be verified first
//@element Input Telegram Passport element
//@password The 2-step verification password of the current user
setPassportElement element:InputPassportElement password:string = PassportElement;

//@description Deletes a Telegram Passport element @type Element type
deletePassportElement type:PassportElementType = Ok;

//@description Informs the user that some of the elements in their Telegram Passport contain errors; for bots only. The user will not be able to resend the elements, until the errors are fixed @user_id User identifier @errors The errors
setPassportElementErrors user_id:int53 errors:vector<inputPassportElementError> = Ok;


//@description Returns an IETF language tag of the language preferred in the country, which must be used to fill native fields in Telegram Passport personal details. Returns a 404 error if unknown @country_code A two-letter ISO 3166-1 alpha-2 country code
getPreferredCountryLanguage country_code:string = Text;


//@description Sends a code to verify an email address to be added to a user's Telegram Passport @email_address Email address
sendEmailAddressVerificationCode email_address:string = EmailAddressAuthenticationCodeInfo;

//@description Resends the code to verify an email address to be added to a user's Telegram Passport
resendEmailAddressVerificationCode = EmailAddressAuthenticationCodeInfo;

//@description Checks the email address verification code for Telegram Passport @code Verification code to check
checkEmailAddressVerificationCode code:string = Ok;


//@description Returns a Telegram Passport authorization form for sharing data with a service
//@bot_user_id User identifier of the service's bot
//@scope Telegram Passport element types requested by the service
//@public_key Service's public key
//@nonce Unique request identifier provided by the service
getPassportAuthorizationForm bot_user_id:int53 scope:string public_key:string nonce:string = PassportAuthorizationForm;

//@description Returns already available Telegram Passport elements suitable for completing a Telegram Passport authorization form. Result can be received only once for each authorization form
//@authorization_form_id Authorization form identifier
//@password The 2-step verification password of the current user
getPassportAuthorizationFormAvailableElements authorization_form_id:int32 password:string = PassportElementsWithErrors;

//@description Sends a Telegram Passport authorization form, effectively sharing data with the service. This method must be called after getPassportAuthorizationFormAvailableElements if some previously available elements are going to be reused
//@authorization_form_id Authorization form identifier
//@types Types of Telegram Passport elements chosen by user to complete the authorization form
sendPassportAuthorizationForm authorization_form_id:int32 types:vector<PassportElementType> = Ok;


//@description Informs the server about the number of pending bot updates if they haven't been processed for a long time; for bots only @pending_update_count The number of pending updates @error_message The last error message
setBotUpdatesStatus pending_update_count:int32 error_message:string = Ok;


//@description Uploads a file with a sticker; returns the uploaded file
//@user_id Sticker file owner; ignored for regular users
//@sticker_format Sticker format
//@sticker File file to upload; must fit in a 512x512 square. For WEBP stickers the file must be in WEBP or PNG format, which will be converted to WEBP server-side.
//-See https://core.telegram.org/animated_stickers#technical-requirements for technical requirements
uploadStickerFile user_id:int53 sticker_format:StickerFormat sticker:InputFile = File;

//@description Returns a suggested name for a new sticker set with a given title @title Sticker set title; 1-64 characters
getSuggestedStickerSetName title:string = Text;

//@description Checks whether a name can be used for a new sticker set @name Name to be checked
checkStickerSetName name:string = CheckStickerSetNameResult;

//@description Creates a new sticker set. Returns the newly created sticker set
//@user_id Sticker set owner; ignored for regular users
//@title Sticker set title; 1-64 characters
//@name Sticker set name. Can contain only English letters, digits and underscores. Must end with *"_by_<bot username>"* (*<bot_username>* is case insensitive) for bots; 0-64 characters.
//-If empty, then the name returned by getSuggestedStickerSetName will be used automatically
//@sticker_type Type of the stickers in the set
//@needs_repainting Pass true if stickers in the sticker set must be repainted; for custom emoji sticker sets only
//@stickers List of stickers to be added to the set; 1-200 stickers for custom emoji sticker sets, and 1-120 stickers otherwise. For TGS stickers, uploadStickerFile must be used before the sticker is shown
//@source Source of the sticker set; may be empty if unknown
createNewStickerSet user_id:int53 title:string name:string sticker_type:StickerType needs_repainting:Bool stickers:vector<inputSticker> source:string = StickerSet;

//@description Adds a new sticker to a set
//@user_id Sticker set owner; ignored for regular users
//@name Sticker set name. The sticker set must be owned by the current user, and contain less than 200 stickers for custom emoji sticker sets and less than 120 otherwise
//@sticker Sticker to add to the set
addStickerToSet user_id:int53 name:string sticker:inputSticker = Ok;

//@description Replaces existing sticker in a set. The function is equivalent to removeStickerFromSet, then addStickerToSet, then setStickerPositionInSet
//@user_id Sticker set owner; ignored for regular users
//@name Sticker set name. The sticker set must be owned by the current user
//@old_sticker Sticker to remove from the set
//@new_sticker Sticker to add to the set
replaceStickerInSet user_id:int53 name:string old_sticker:InputFile new_sticker:inputSticker = Ok;

//@description Sets a sticker set thumbnail
//@user_id Sticker set owner; ignored for regular users
//@name Sticker set name. The sticker set must be owned by the current user
//@thumbnail Thumbnail to set; pass null to remove the sticker set thumbnail
//@format Format of the thumbnail; pass null if thumbnail is removed
setStickerSetThumbnail user_id:int53 name:string thumbnail:InputFile format:StickerFormat = Ok;

//@description Sets a custom emoji sticker set thumbnail
//@name Sticker set name. The sticker set must be owned by the current user
//@custom_emoji_id Identifier of the custom emoji from the sticker set, which will be set as sticker set thumbnail; pass 0 to remove the sticker set thumbnail
setCustomEmojiStickerSetThumbnail name:string custom_emoji_id:int64 = Ok;

//@description Sets a sticker set title @name Sticker set name. The sticker set must be owned by the current user @title New sticker set title
setStickerSetTitle name:string title:string = Ok;

//@description Completely deletes a sticker set @name Sticker set name. The sticker set must be owned by the current user
deleteStickerSet name:string = Ok;

//@description Changes the position of a sticker in the set to which it belongs. The sticker set must be owned by the current user
//@sticker Sticker
//@position New position of the sticker in the set, 0-based
setStickerPositionInSet sticker:InputFile position:int32 = Ok;

//@description Removes a sticker from the set to which it belongs. The sticker set must be owned by the current user @sticker Sticker to remove from the set
removeStickerFromSet sticker:InputFile = Ok;

//@description Changes the list of emojis corresponding to a sticker. The sticker must belong to a regular or custom emoji sticker set that is owned by the current user
//@sticker Sticker
//@emojis New string with 1-20 emoji corresponding to the sticker
setStickerEmojis sticker:InputFile emojis:string = Ok;

//@description Changes the list of keywords of a sticker. The sticker must belong to a regular or custom emoji sticker set that is owned by the current user
//@sticker Sticker
//@keywords List of up to 20 keywords with total length up to 64 characters, which can be used to find the sticker
setStickerKeywords sticker:InputFile keywords:vector<string> = Ok;

//@description Changes the mask position of a mask sticker. The sticker must belong to a mask sticker set that is owned by the current user
//@sticker Sticker
//@mask_position Position where the mask is placed; pass null to remove mask position
setStickerMaskPosition sticker:InputFile mask_position:maskPosition = Ok;

//@description Returns sticker sets owned by the current user
//@offset_sticker_set_id Identifier of the sticker set from which to return owned sticker sets; use 0 to get results from the beginning
//@limit The maximum number of sticker sets to be returned; must be positive and can't be greater than 100. For optimal performance, the number of returned objects is chosen by TDLib and can be smaller than the specified limit
getOwnedStickerSets offset_sticker_set_id:int64 limit:int32 = StickerSets;


//@description Returns information about a file with a map thumbnail in PNG format. Only map thumbnail files with size less than 1MB can be downloaded
//@location Location of the map center
//@zoom Map zoom level; 13-20
//@width Map width in pixels before applying scale; 16-1024
//@height Map height in pixels before applying scale; 16-1024
//@scale Map scale; 1-3
//@chat_id Identifier of a chat in which the thumbnail will be shown. Use 0 if unknown
getMapThumbnailFile location:location zoom:int32 width:int32 height:int32 scale:int32 chat_id:int53 = File;


//@description Returns information about a limit, increased for Premium users. Returns a 404 error if the limit is unknown @limit_type Type of the limit
getPremiumLimit limit_type:PremiumLimitType = PremiumLimit;

//@description Returns information about features, available to Premium users @source Source of the request; pass null if the method is called from some non-standard source
getPremiumFeatures source:PremiumSource = PremiumFeatures;

//@description Returns examples of premium stickers for demonstration purposes
getPremiumStickerExamples = Stickers;

//@description Returns the sticker to be used as representation of the Telegram Premium subscription @month_count Number of months the Telegram Premium subscription will be active
getPremiumInfoSticker month_count:int32 = Sticker;

//@description Informs TDLib that the user viewed detailed information about a Premium feature on the Premium features screen @feature The viewed premium feature
viewPremiumFeature feature:PremiumFeature = Ok;

//@description Informs TDLib that the user clicked Premium subscription button on the Premium features screen
clickPremiumSubscriptionButton = Ok;

//@description Returns state of Telegram Premium subscription and promotion videos for Premium features
getPremiumState = PremiumState;

//@description Returns available options for gifting Telegram Premium to a user
getPremiumGiftPaymentOptions = PremiumGiftPaymentOptions;

//@description Returns available options for creating of Telegram Premium giveaway or manual distribution of Telegram Premium among chat members
//@boosted_chat_id Identifier of the supergroup or channel chat, which will be automatically boosted by receivers of the gift codes and which is administered by the user
getPremiumGiveawayPaymentOptions boosted_chat_id:int53 = PremiumGiveawayPaymentOptions;

//@description Return information about a Telegram Premium gift code @code The code to check
checkPremiumGiftCode code:string = PremiumGiftCodeInfo;

//@description Applies a Telegram Premium gift code @code The code to apply
applyPremiumGiftCode code:string = Ok;

//@description Launches a prepaid giveaway
//@giveaway_id Unique identifier of the prepaid giveaway
//@parameters Giveaway parameters
//@winner_count The number of users to receive giveaway prize
//@star_count The number of Telegram Stars to be distributed through the giveaway; pass 0 for Telegram Premium giveaways
launchPrepaidGiveaway giveaway_id:int64 parameters:giveawayParameters winner_count:int32 star_count:int53 = Ok;

//@description Returns information about a giveaway
//@chat_id Identifier of the channel chat which started the giveaway
//@message_id Identifier of the giveaway or a giveaway winners message in the chat
getGiveawayInfo chat_id:int53 message_id:int53 = GiveawayInfo;

//@description Returns available options for Telegram Stars purchase
getStarPaymentOptions = StarPaymentOptions;

//@description Returns available options for Telegram Stars gifting @user_id Identifier of the user that will receive Telegram Stars; pass 0 to get options for an unspecified user
getStarGiftPaymentOptions user_id:int53 = StarPaymentOptions;

//@description Returns available options for Telegram Star giveaway creation
getStarGiveawayPaymentOptions = StarGiveawayPaymentOptions;

//@description Returns the list of Telegram Star transactions for the specified owner
//@owner_id Identifier of the owner of the Telegram Stars; can be the identifier of the current user, identifier of an owned bot,
//-or identifier of a supergroup or a channel chat with supergroupFullInfo.can_get_star_revenue_statistics == true
//@subscription_id If non-empty, only transactions related to the Star Subscription will be returned
//@direction Direction of the transactions to receive; pass null to get all transactions
//@offset Offset of the first transaction to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of transactions to return
getStarTransactions owner_id:MessageSender subscription_id:string direction:StarTransactionDirection offset:string limit:int32 = StarTransactions;

//@description Returns the list of Telegram Star subscriptions for the current user
//@only_expiring Pass true to receive only expiring subscriptions for which there are no enough Telegram Stars to extend
//@offset Offset of the first subscription to return as received from the previous request; use empty string to get the first chunk of results
getStarSubscriptions only_expiring:Bool offset:string = StarSubscriptions;

//@description Checks whether an in-store purchase is possible. Must be called before any in-store purchase @purpose Transaction purpose
canPurchaseFromStore purpose:StorePaymentPurpose = Ok;

//@description Informs server about a purchase through App Store. For official applications only @receipt App Store receipt @purpose Transaction purpose
assignAppStoreTransaction receipt:bytes purpose:StorePaymentPurpose = Ok;

//@description Informs server about a purchase through Google Play. For official applications only
//@package_name Application package name
//@store_product_id Identifier of the purchased store product
//@purchase_token Google Play purchase token
//@purpose Transaction purpose
assignGooglePlayTransaction package_name:string store_product_id:string purchase_token:string purpose:StorePaymentPurpose = Ok;

//@description Cancels or re-enables Telegram Star subscription
//@subscription_id Identifier of the subscription to change
//@is_canceled New value of is_canceled
editStarSubscription subscription_id:string is_canceled:Bool = Ok;

//@description Cancels or re-enables Telegram Star subscription for a user; for bots only
//@user_id User identifier
//@telegram_payment_charge_id Telegram payment identifier of the subscription
//@is_canceled Pass true to cancel the subscription; pass false to allow the user to enable it
editUserStarSubscription user_id:int53 telegram_payment_charge_id:string is_canceled:Bool = Ok;

//@description Reuses an active Telegram Star subscription to a channel chat and joins the chat again @subscription_id Identifier of the subscription
reuseStarSubscription subscription_id:string = Ok;


//@description Changes affiliate program for a bot
//@chat_id Identifier of the chat with an owned bot for which affiliate program is changed
//@parameters Parameters of the affiliate program; pass null to close the currently active program. If there is an active program, then commission and program duration can only be increased.
//-If the active program is scheduled to be closed, then it can't be changed anymore
setChatAffiliateProgram chat_id:int53 parameters:affiliateProgramParameters = Ok;

//@description Searches a chat with an affiliate program. Returns the chat if found and the program is active
//@username Username of the chat
//@referrer The referrer from an internalLinkTypeChatAffiliateProgram link
searchChatAffiliateProgram username:string referrer:string = Chat;

//@description Searches affiliate programs that can be connected to the given affiliate
//@affiliate The affiliate for which affiliate programs are searched for
//@sort_order Sort order for the results
//@offset Offset of the first affiliate program to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of affiliate programs to return
searchAffiliatePrograms affiliate:AffiliateType sort_order:AffiliateProgramSortOrder offset:string limit:int32 = FoundAffiliatePrograms;

//@description Connects an affiliate program to the given affiliate. Returns information about the connected affiliate program
//@affiliate The affiliate to which the affiliate program will be connected
//@bot_user_id Identifier of the bot, which affiliate program is connected
connectAffiliateProgram affiliate:AffiliateType bot_user_id:int53 = ConnectedAffiliateProgram;

//@description Disconnects an affiliate program from the given affiliate and immediately deactivates its referral link. Returns updated information about the disconnected affiliate program
//@affiliate The affiliate to which the affiliate program is connected
//@url The referral link of the affiliate program
disconnectAffiliateProgram affiliate:AffiliateType url:string = ConnectedAffiliateProgram;

//@description Returns an affiliate program that were connected to the given affiliate by identifier of the bot that created the program
//@affiliate The affiliate to which the affiliate program will be connected
//@bot_user_id Identifier of the bot that created the program
getConnectedAffiliateProgram affiliate:AffiliateType bot_user_id:int53 = ConnectedAffiliateProgram;

//@description Returns affiliate programs that were connected to the given affiliate
//@affiliate The affiliate to which the affiliate program were connected
//@offset Offset of the first affiliate program to return as received from the previous request; use empty string to get the first chunk of results
//@limit The maximum number of affiliate programs to return
getConnectedAffiliatePrograms affiliate:AffiliateType offset:string limit:int32 = ConnectedAffiliatePrograms;


//@description Returns information about features, available to Business users @source Source of the request; pass null if the method is called from settings or some non-standard source
getBusinessFeatures source:BusinessFeature = BusinessFeatures;


//@description Accepts Telegram terms of services @terms_of_service_id Terms of service identifier
acceptTermsOfService terms_of_service_id:string = Ok;


//@description Searches specified query by word prefixes in the provided strings. Returns 0-based positions of strings that matched. Can be called synchronously
//@strings The strings to search in for the query
//@query Query to search for
//@limit The maximum number of objects to return
//@return_none_for_empty_query Pass true to receive no results for an empty query
searchStringsByPrefix strings:vector<string> query:string limit:int32 return_none_for_empty_query:Bool = FoundPositions;


//@description Sends a custom request; for bots only @method The method name @parameters JSON-serialized method parameters
sendCustomRequest method:string parameters:string = CustomRequestResult;

//@description Answers a custom query; for bots only @custom_query_id Identifier of a custom query @data JSON-serialized answer to the query
answerCustomQuery custom_query_id:int64 data:string = Ok;


//@description Succeeds after a specified amount of time has passed. Can be called before initialization @seconds Number of seconds before the function returns
setAlarm seconds:double = Ok;


//@description Returns information about existing countries. Can be called before authorization
getCountries = Countries;

//@description Uses the current IP address to find the current country. Returns two-letter ISO 3166-1 alpha-2 country code. Can be called before authorization
getCountryCode = Text;

//@description Returns information about a phone number by its prefix. Can be called before authorization @phone_number_prefix The phone number prefix
getPhoneNumberInfo phone_number_prefix:string = PhoneNumberInfo;

//@description Returns information about a phone number by its prefix synchronously. getCountries must be called at least once after changing localization to the specified language if properly localized country information is expected. Can be called synchronously
//@language_code A two-letter ISO 639-1 language code for country information localization
//@phone_number_prefix The phone number prefix
getPhoneNumberInfoSync language_code:string phone_number_prefix:string = PhoneNumberInfo;


//@description Returns information about a given collectible item that was purchased at https://fragment.com
//@type Type of the collectible item. The item must be used by a user and must be visible to the current user
getCollectibleItemInfo type:CollectibleItemType = CollectibleItemInfo;


//@description Returns information about a tg:// deep link. Use "tg://need_update_for_some_feature" or "tg:some_unsupported_feature" for testing. Returns a 404 error for unknown links. Can be called before authorization @link The link
getDeepLinkInfo link:string = DeepLinkInfo;


//@description Returns application config, provided by the server. Can be called before authorization
getApplicationConfig = JsonValue;

//@description Saves application log event on the server. Can be called before authorization @type Event type @chat_id Optional chat identifier, associated with the event @data The log event data
saveApplicationLogEvent type:string chat_id:int53 data:JsonValue = Ok;

//@description Returns the link for downloading official Telegram application to be used when the current user invites friends to Telegram
getApplicationDownloadLink = HttpUrl;


//@description Adds a proxy server for network requests. Can be called before authorization
//@server Proxy server domain or IP address
//@port Proxy server port
//@enable Pass true to immediately enable the proxy
//@type Proxy type
addProxy server:string port:int32 enable:Bool type:ProxyType = Proxy;

//@description Edits an existing proxy server for network requests. Can be called before authorization
//@proxy_id Proxy identifier
//@server Proxy server domain or IP address
//@port Proxy server port
//@enable Pass true to immediately enable the proxy
//@type Proxy type
editProxy proxy_id:int32 server:string port:int32 enable:Bool type:ProxyType = Proxy;

//@description Enables a proxy. Only one proxy can be enabled at a time. Can be called before authorization @proxy_id Proxy identifier
enableProxy proxy_id:int32 = Ok;

//@description Disables the currently enabled proxy. Can be called before authorization
disableProxy = Ok;

//@description Removes a proxy server. Can be called before authorization @proxy_id Proxy identifier
removeProxy proxy_id:int32 = Ok;

//@description Returns the list of proxies that are currently set up. Can be called before authorization
getProxies = Proxies;

//@description Returns an HTTPS link, which can be used to add a proxy. Available only for SOCKS5 and MTProto proxies. Can be called before authorization @proxy_id Proxy identifier
getProxyLink proxy_id:int32 = HttpUrl;

//@description Computes time needed to receive a response from a Telegram server through a proxy. Can be called before authorization @proxy_id Proxy identifier. Use 0 to ping a Telegram server without a proxy
pingProxy proxy_id:int32 = Seconds;


//@description Sets new log stream for internal logging of TDLib. Can be called synchronously @log_stream New log stream
setLogStream log_stream:LogStream = Ok;

//@description Returns information about currently used log stream for internal logging of TDLib. Can be called synchronously
getLogStream = LogStream;

//@description Sets the verbosity level of the internal logging of TDLib. Can be called synchronously
//@new_verbosity_level New value of the verbosity level for logging. Value 0 corresponds to fatal errors, value 1 corresponds to errors, value 2 corresponds to warnings and debug warnings,
//-value 3 corresponds to informational, value 4 corresponds to debug, value 5 corresponds to verbose debug, value greater than 5 and up to 1023 can be used to enable even more logging
setLogVerbosityLevel new_verbosity_level:int32 = Ok;

//@description Returns current verbosity level of the internal logging of TDLib. Can be called synchronously
getLogVerbosityLevel = LogVerbosityLevel;

//@description Returns the list of available TDLib internal log tags, for example, ["actor", "binlog", "connections", "notifications", "proxy"]. Can be called synchronously
getLogTags = LogTags;

//@description Sets the verbosity level for a specified TDLib internal log tag. Can be called synchronously
//@tag Logging tag to change verbosity level
//@new_verbosity_level New verbosity level; 1-1024
setLogTagVerbosityLevel tag:string new_verbosity_level:int32 = Ok;

//@description Returns current verbosity level for a specified TDLib internal log tag. Can be called synchronously @tag Logging tag to change verbosity level
getLogTagVerbosityLevel tag:string = LogVerbosityLevel;

//@description Adds a message to TDLib internal log. Can be called synchronously
//@verbosity_level The minimum verbosity level needed for the message to be logged; 0-1023
//@text Text of a message to log
addLogMessage verbosity_level:int32 text:string = Ok;


//@description Returns support information for the given user; for Telegram support only @user_id User identifier
getUserSupportInfo user_id:int53 = UserSupportInfo;

//@description Sets support information for the given user; for Telegram support only @user_id User identifier @message New information message
setUserSupportInfo user_id:int53 message:formattedText = UserSupportInfo;

//@description Returns localized name of the Telegram support user; for Telegram support only
getSupportName = Text;


//@description Does nothing; for testing only. This is an offline method. Can be called before authorization
testCallEmpty = Ok;

//@description Returns the received string; for testing only. This is an offline method. Can be called before authorization @x String to return
testCallString x:string = TestString;

//@description Returns the received bytes; for testing only. This is an offline method. Can be called before authorization @x Bytes to return
testCallBytes x:bytes = TestBytes;

//@description Returns the received vector of numbers; for testing only. This is an offline method. Can be called before authorization @x Vector of numbers to return
testCallVectorInt x:vector<int32> = TestVectorInt;

//@description Returns the received vector of objects containing a number; for testing only. This is an offline method. Can be called before authorization @x Vector of objects to return
testCallVectorIntObject x:vector<testInt> = TestVectorIntObject;

//@description Returns the received vector of strings; for testing only. This is an offline method. Can be called before authorization @x Vector of strings to return
testCallVectorString x:vector<string> = TestVectorString;

//@description Returns the received vector of objects containing a string; for testing only. This is an offline method. Can be called before authorization @x Vector of objects to return
testCallVectorStringObject x:vector<testString> = TestVectorStringObject;

//@description Returns the squared received number; for testing only. This is an offline method. Can be called before authorization @x Number to square
testSquareInt x:int32 = TestInt;

//@description Sends a simple network request to the Telegram servers; for testing only. Can be called before authorization
testNetwork = Ok;

//@description Sends a simple network request to the Telegram servers via proxy; for testing only. Can be called before authorization
//@server Proxy server domain or IP address
//@port Proxy server port
//@type Proxy type
//@dc_id Identifier of a datacenter with which to test connection
//@timeout The maximum overall timeout for the request
testProxy server:string port:int32 type:ProxyType dc_id:int32 timeout:double = Ok;

//@description Forces an updates.getDifference call to the Telegram servers; for testing only
testGetDifference = Ok;

//@description Does nothing and ensures that the Update object is used; for testing only. This is an offline method. Can be called before authorization
testUseUpdate = Update;

//@description Returns the specified error and ensures that the Error object is used; for testing only. Can be called synchronously @error The error to be returned
testReturnError error:error = Error;
