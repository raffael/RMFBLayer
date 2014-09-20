//
//  RMFBLayer.h
//
//  Created by Raffael Hannemann on 31.01.13.
//  Copyright (c) 2013 raffael.me. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accounts/Accounts.h>
#import <Social/Social.h>

/** Identifiers for the available FB API Abstractions. Extend the enum when adding new abstractions. */
typedef enum {
	RMFBFrameworkOSX,
	RMFBFrameworkPhFacebook,
	RMFBFrameworkFacebookSDK
} RMFBFrameworkIdentifier;

/** Identifiers for the four HTTP request methods. */
typedef enum {
	RMFBGETRequest,
	RMFBPOSTRequest,
	RMFBPUTRequest,
	RMFBDELETERequest
} RMFBRequestMethod;

/** Codes for the error types. */
typedef enum {
	RMFBAbstractionErrorUnknownError,
	RMFBAbstractionErrorJSONError,
	RMFBAbstractionErrorAPIError,
	RMFBAbstractionErrorAuthenticationError,
} RMFBAbstractionErrors;

/** The default abstraction that will be used, if not set explicitely. */
#define RMFBDefaultPreferredFramework RMFBFrameworkOSX

/** The default flag for whether the user's information shall be fetched as soon as the access_token is valid. */
#define RMFBDefaultAutofetchUserInformation YES

/** The Graph base URI. */
#define RMFBBaseUri @"https://graph.facebook.com"

typedef void (^RMFBLayerCompletionBlock)(NSObject *resultObject, NSError *error);
typedef void (^RMFBLayerRenewalBlock)();

/** Layer Delegates will be notified once the user has been authenticated successfully or authentication failed. */
@protocol RMFBLayerDelegate <NSObject>
- (void) facebookAuthenticationCanceled;
- (void) facebookAuthenticationSucceeded;
- (void) facebookAuthenticationFailedFinallyWithError: (NSError *) error;
- (void) facebookAbstractionSwitchedAfterFail: (RMFBFrameworkIdentifier) failedFrameworkIdentifier;
- (void) facebookRequestCanceledRequireNewLogin: (BOOL) loginRequired;
@end

@protocol RMFBAbstractionFailDelegate;

/** Any objects that implement the RMFBAbstraction protocol are able to handle a Facebook API request, that is they delegate the request to the FB API framework, that they are wrapping. Implementations should be placed in the FMRBAbstractions group. */
@protocol RMFBAbstraction <NSObject>

/** Init the instance using a Facebook application identifier. */
- (id) initWithFacebookAppId:(NSString *) appId;

/** Try to authenticate the user, that is, invoke any required UI dialogues. */
- (void) authForPermissions: (NSArray *) permissions;

/** Perform a GET request with a set of parameters and a completion handler. This is basically a wrapper for -performRequest:usingRequestMethod:usingParameters:andCompletionHandler:;. */
- (void) performGETRequest:(NSString *) urlString usingParameters:(NSDictionary *) parameters andCompletionHandler: (RMFBLayerCompletionBlock) completionHandler;

/** Perform a POST request with a set of parameters and a completion handler. This is basically a wrapper for -performRequest:usingRequestMethod:usingParameters:andCompletionHandler:;. */
- (void) performPOSTRequest:(NSString *) urlString usingParameters:(NSDictionary *) parameters andCompletionHandler: (RMFBLayerCompletionBlock) completionHandler;

//TODO: DELETE, PUT required?

/** Perform a request with a given HTTP request method type, a set of parameters and a completion handler. */
- (void) performRequest:(NSString *) urlString usingRequestMethod:(RMFBRequestMethod) method usingParameters:(NSDictionary *) parameters andCompletionHandler: (RMFBLayerCompletionBlock) completionHandler;

- (void) renewAccessTokenWithCompletionHandler:(RMFBLayerRenewalBlock) completionHandler;

- (void) invalidateSession;

- (BOOL) handleFacebookSDKCallbackURL: (NSURL *) URL sourceApplication: (NSString *) sourceApplication;

- (RMFBFrameworkIdentifier) abstractionIdentifier;

@property (weak,nonatomic) NSObject<RMFBLayerDelegate> *delegate;
@property (strong) NSString *facebookAppId;
@property (strong,nonatomic) NSString *accessToken;
@property (assign,readonly) BOOL authenticated;
@property (weak) id<RMFBAbstractionFailDelegate> failDelegate;
@end

/** The delegate will be called, once one abstraction instance failed, e.g. if the user is running on OS X < 10.8.1, or the user did not activate Facebook integration. You should not implement this delegate, instead the RMFBLayer will implement it to handle failure automatically to select another abstraction instance and try the last request with it once again. */
@protocol RMFBAbstractionFailDelegate <NSObject>
- (void) abstraction: (id<RMFBAbstraction>) sender failedWithError: (NSError *) error;
@end

@interface RMFBLayer : NSObject <RMFBAbstraction, RMFBLayerDelegate, RMFBAbstractionFailDelegate> {
	NSMutableArray *abstractions;
	int _failedAbstractions;
}

+(RMFBLayer *) sharedInstance;
-(RMFBLayer *) layerWithFacebookAppId:(NSString *) appId;
@property (assign,nonatomic) RMFBFrameworkIdentifier preferredFramework;
@property (assign, readonly) id<RMFBAbstraction> abstraction;
@property (assign, readonly) BOOL authenticated;
@property (retain) NSString *facebookAppId;
@property (retain,nonatomic) NSString *accessToken;
@property (retain,nonatomic) NSObject<RMFBLayerDelegate> *delegate;
@property (retain) NSArray *permissions;
@property (retain) NSDictionary *userInformation;
//TODO: implement logic behind:
@property (assign) BOOL autofetchUserInformation;

- (void) addOSXAbstraction;
- (void) addPhFacebookAbstraction;
- (void) addAbstraction:(id<RMFBAbstraction>) abstraction;

@end
