//
//  BITAuthenticator_Private.h
//  HockeySDK
//
//  Created by Stephan Diederich on 08.08.13.
//
//

#import "BITAuthenticator.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITAuthenticationViewController.h"
#import "BITHTTPOperation.h" //needed for typedef

@interface BITAuthenticator ()<BITAuthenticationViewControllerDelegate>

//can be set for testing
@property (nonatomic) UIDevice *currentDevice;

/**
 *	if set, this serves as the installationIdentifier. 
 *  This is retrieved from the hockeyApp backend
 *  @see installationIdentifier
 */
@property (nonatomic, copy) NSString *authenticationToken;

/**
 *  holds the identifier of the last version that was authenticated
 *  only used if validation is set BITAuthenticatorValidationTypeOnFirstLaunch
 */
@property (nonatomic, copy) NSString *lastAuthenticatedVersion;

@property (nonatomic, copy) tAuthenticationCompletion authenticationCompletionBlock;
@property (nonatomic, copy) tValidationCompletion validationCompletion;

/**
 *	removes all previously stored authentication tokens, UDIDs, etc
 */
- (void) cleanupInternalStorage;


/**
 * method registered as observer for applicationsDidBecomeActive events
 */
- (void) applicationDidBecomeActive:(NSNotification*) note;

#pragma mark - Validation callbacks
- (void) validationSucceeded;
- (void) validationFailedWithError:(NSError *) validationError;


#pragma mark - Networking helpers (TODO: move to base-class / networking component)
@property (nonatomic, strong) NSOperationQueue *operationQueue;

/**
 *	creates an NRURLRequest for the given method and path by using
 *  the internally stored baseURL.
 *
 *	@param	method	the HTTPMethod to check, must not be nil
 *	@param	path	path to append to baseURL. can be nil in which case "/" is appended
 *
 *	@return	an NSMutableURLRequest for further configuration
 */
- (NSMutableURLRequest *) requestWithMethod:(NSString*) method
                                       path:(NSString *) path;
/**
 *	Creates an operation for the given NSURLRequest
 *
 *	@param	request	the request that should be handled
 *	@param	completion	completionBlock that is called once the operation finished
 *
 *	@return	operation, which can be queued via enqueueHTTPOperation:
 */
- (BITHTTPOperation*) operationWithURLRequest:(NSURLRequest*) request
                                   completion:(BITNetworkCompletionBlock) completion;

/**
 *	Creates an operation for the given path, and enqueues it
 *
 *	@param	path	the request path to check
 *	@param	completion	completionBlock that is called once the operation finished
 *
 */
- (void) getPath:(NSString*) path
      completion:(BITNetworkCompletionBlock) completion;

/**
 *	adds the given operation to the internal queue
 *
 *	@param	operation	operation to add
 */
- (void) enqeueHTTPOperation:(BITHTTPOperation *) operation;

/**
 *	cancels the specified operations
 *
 *	@param	path	the path which operation should be cancelled. Can be nil to match all
 *	@param	method	the method which operations to cancel. Can be nil to match all
 *  @return number of operations cancelled
 */
- (NSUInteger) cancelOperationsWithPath:(NSString*) path
                                 method:(NSString*) method;

@end
