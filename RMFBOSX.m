//
//  RMFBOSX.m
//
//  Created by Raffael Hannemann on 01.02.13.
//  Copyright (c) 2013 raffael.me. All rights reserved.
//


#import "RMFBOSX.h"
@implementation RMFBOSX 

- (id)init {
    self = [super init];
    if (self) {
		
		_authAttempts = 0;
		
		if ([self supportsFB]) {
			//	self.osxAccountStore = [[ACAccountStore alloc] init];
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(accountChanged:)
														 name:ACAccountStoreDidChangeNotification
													   object:nil];
		}
		
    }
    return self;
}

- (BOOL) supportsFB {
	Class accountStoreClass = NSClassFromString(@"ACAccountStore");
	
	SInt32 major, minor, bugfix;
	Gestalt(gestaltSystemVersionMajor, &major);
	Gestalt(gestaltSystemVersionMinor, &minor);
	Gestalt(gestaltSystemVersionBugFix, &bugfix);	
	return (((major>=10 && minor >= 8 && bugfix >= 2) || (major>=10 && minor >= 9)) && accountStoreClass!=nil);
}

- (void) accountChanged:(NSNotification *) notification {
	[self authForPermissions:self.permissions];
}

- (id) initWithFacebookAppId:(NSString *)appId {
	self = [self init];
	if (self) {
		self.facebookAppId = appId;
	}
	return self;
}


+ (NSError *) notSupportedError {
	SInt32 major, minor, bugfix;
	Gestalt(gestaltSystemVersionMajor, &major);
	Gestalt(gestaltSystemVersionMinor, &minor);
	Gestalt(gestaltSystemVersionBugFix, &bugfix);
	NSString *OS = [NSString stringWithFormat:@"%d.%d.%d",major,minor,bugfix];
	return [NSError errorWithDomain:@"me.raffael.RMFBLayer" code:RMFBOSXNotSupported userInfo:@{@"OS":OS}];
}

+ (NSError *) appAccessNotAllowedErrorWithError: (NSError *) error {
	return [NSError errorWithDomain:@"me.raffael.RMFBLayer" code:RMFBOSXAppNotAllowed userInfo:@{@"error":error}];
}

+ (NSError *) unknownAccountAccessErrorWithError: (NSError *) error {
	return [NSError errorWithDomain:@"me.raffael.RMFBLayer" code:RMFBOSXUnkownAccountAccessError userInfo:@{@"error":error}];
}

+ (NSError *) tooManyAttempsError {
	return [NSError errorWithDomain:@"me.raffael.RMFBLayer" code:RMFBOSXTooManyAttempts userInfo:nil];
}

+ (NSError *) obtainingAccountIdentifierTimedOutError {
	return [NSError errorWithDomain:@"me.raffael.RMFBLayer" code:RMFBOSXObtainingAccountIdentifierTimedOut userInfo:nil];
}

- (void) authForPermissions:(NSArray *)permissions {
	_authAttempts++;
	
	if (![self supportsFB]) {
		[self.failDelegate abstraction:self failedWithError:[RMFBOSX notSupportedError]];
		return;
	}
	
	if (_authAttempts>10) {
		[self.failDelegate abstraction:self failedWithError:[RMFBOSX tooManyAttempsError]];
		return;
	}
	
	[self performSelectorInBackground:@selector(authInBackgroundWithPermissions:) withObject:permissions];
}

- (void) willObtainAccountType {
	_isObtainingAccountType = YES;
	[self performSelectorInBackground:@selector(obtainingAccountTypeTimeout) withObject:nil];
}

- (void) didObtainAccountType {
	_isObtainingAccountType = NO;
}

- (void) obtainingAccountTypeTimeout {
	[NSThread sleepForTimeInterval:5];
	NSLog(@"RMFBOSX: Timeout for obtaining AccountType. Is still obtaining ACAccountType: %@",(_isObtainingAccountType)?@"YES":@"NO");
	if (_isObtainingAccountType) {
		NSLog(@"RMFBOSX: Failed to authenticate, AccountType could not be obtained.");
		[_obtainingAccountTypeThread cancel];
		[self.failDelegate abstraction:self failedWithError:[RMFBOSX obtainingAccountIdentifierTimedOutError]];
	}
}

- (void) authInBackgroundWithPermissions: (NSArray *) permissions {
	
	// Reference required to cancel the thread, if obtaining the AccountType fails
	_obtainingAccountTypeThread = [NSThread currentThread];
		
	self.permissions = [permissions copy];
	
	// Set the dictionary that will be passed on to request account access
	NSDictionary *fbInfo = @{
		ACFacebookAppIdKey: self.facebookAppId,
		ACFacebookPermissionsKey: self.permissions,
		ACFacebookAudienceKey: ACFacebookAudienceOnlyMe,
		};
	
	self.osxAccountStore = [[ACAccountStore alloc] init];

	// Get the Facebook account type for the access request

	/** The following procedure of obtaining the AccountType may fail, that is, will never terminate,
	 Therefore, set a timeout for this procedure in a secondary thread, and notify the delegate that the procedure failed, if the timeout happened. */
	[self willObtainAccountType];
	ACAccountType *fbAccountType = [self.osxAccountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
	[self didObtainAccountType];
	
	// Request access to the Facebook account with the access info
	[self.osxAccountStore requestAccessToAccountsWithType:fbAccountType
												  options:fbInfo
											   completion:^(BOOL granted, NSError *error) {
												   if (error) {
													   if ([error code]==6) {
														   NSLog(@"RMFBOSX: Failed to authenticate, will notify failDelegate. Error: %@",error);
														   [self.failDelegate abstraction:self failedWithError:[RMFBOSX appAccessNotAllowedErrorWithError:error]];
														   return;
													   } else {
														   [self.failDelegate abstraction:self failedWithError:[RMFBOSX unknownAccountAccessErrorWithError:error]];
														   return;
													   }
														
												   }
												   if (granted) {
													   // If access granted, then get the Facebook account info
													   NSArray *accounts = [self.osxAccountStore accountsWithAccountType:fbAccountType];
													   self.osxFbAccount = [accounts lastObject];
													   													   
													   /** Setting service type, so that ShareKit is able to configure its UI. */
													   self.osxSlService = SLServiceTypeFacebook;
													   
													   /** Instead of notifying the delegate that authentication has been successful, make a test request to check if the current access_token is still valid. If not, renew it. Notify the delegate afterwards. */
													   if (self.osxFbAccount.credential.oauthToken==nil) {
														   [self renewAccessTokenWithCompletionHandler:^{
															   [self testAccessToken];
														   }];
													   } else {
														   [self testAccessToken];
													   }
												   } else {
													   NSLog(@"RMFBOSX: Access not granted, error: %@", error);
													   [self.delegate performSelectorOnMainThread:@selector(facebookAuthenticationCanceled) withObject:nil waitUntilDone:NO];
												   }
											   }];
}

- (void) testAccessToken {
	/** Trigger a test request, for which a valid access_token is required, with the current credentials / access_token. */
	[self performGETRequest:@"/me/"
			usingParameters:nil
	   andCompletionHandler:^(NSObject *resultObject, NSError *error) {
		   /** If this handler has been called, it means that the access_token is either valid or not present. */
		   if (error || !self.osxFbAccount.credential.oauthToken) {
			   [self.osxAccountStore renewCredentialsForAccount:self.osxFbAccount completion:^(ACAccountCredentialRenewResult renewResult, NSError *error){
				   switch(renewResult) {
					   case ACAccountCredentialRenewResultRenewed: {
						   [self testAccessToken];
						   break;
					   }
					   case ACAccountCredentialRenewResultFailed:
					   case ACAccountCredentialRenewResultRejected:
					   default:{
						   NSError *error = [NSError errorWithDomain:@"RMFBOSX" code:RMFBAbstractionErrorJSONError userInfo:@{@"ACAccountCredentialRenewResult":[NSNumber numberWithInteger:renewResult]}];
						   [self.delegate facebookAuthenticationFailedFinallyWithError:error];
					   }
				   }
				   
			   }];
			   return;
		   }
		   
		   self.accessToken = self.osxFbAccount.credential.oauthToken;

		   /** Thus, notify the delegate that authentication has been successful. */
		   [self.delegate performSelectorOnMainThread: @selector(facebookAuthenticationSucceeded) withObject:nil waitUntilDone:NO];
	}];
}

- (NSString *) finalAPIURLStringFor:(NSString *) suffix {
	NSString *string = [RMFBBaseUri stringByAppendingString:suffix];
	return [string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (void) performRequest:(NSString *)urlString usingRequestMethod:(RMFBRequestMethod)method usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {

	NSURL __block *requestURL = [NSURL URLWithString:[self finalAPIURLStringFor:urlString]];
	SLRequest *fbShareRequest = [SLRequest requestForServiceType:SLServiceTypeFacebook
												   requestMethod:SLRequestMethodGET
															 URL:requestURL
													  parameters:parameters];
	fbShareRequest.account = self.osxFbAccount;

	// Perform the request
	[fbShareRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {

		_authAttempts = 0;
		
		NSString *jsonString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
		NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
		NSError *jsonParsingError = nil;
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData
															 options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves|NSJSONReadingAllowFragments
															   error:&jsonParsingError];

		if (jsonParsingError) {
			NSLog(@"RMFBOSX: Error while parsing JSON string '%@' for request '%@'",jsonString,requestURL);
			completionHandler(nil, [NSError errorWithDomain:@"RMFBOSX" code:RMFBAbstractionErrorJSONError userInfo:@{@"json-error":jsonParsingError}]);
		} else if ([json isKindOfClass:[NSDictionary class]] && [json objectForKey:@"error"]!=nil) {
			/** If an error is present, check if the access_token has to be renewed. */
			NSDictionary *apiError = [json objectForKey:@"error"];
			NSNumber *fbErrorCode = [apiError objectForKey:@"code"];
			if (fbErrorCode && ([fbErrorCode isEqualToNumber:@190] || [fbErrorCode isEqualToNumber:@2500])) {
				/** Renew the access_token and trigger the same request again. */
				[self renewAccessTokenWithCompletionHandler:^{
					[self performRequest:urlString usingRequestMethod:method usingParameters:parameters andCompletionHandler:completionHandler];
				}];
			} else {
				completionHandler(nil, [NSError errorWithDomain:@"RMFBOSX" code:RMFBAbstractionErrorUnknownError userInfo:@{@"api-error":apiError}]);
			}
		} else {
			completionHandler(json, error);
		}
	}];

}

- (void) performGETRequest:(NSString *)urlString usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {
	[self performRequest:urlString usingRequestMethod:SLRequestMethodGET usingParameters:parameters andCompletionHandler:completionHandler];
}

- (void) performPOSTRequest:(NSString *)urlString usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {
	[self performRequest:urlString usingRequestMethod:SLRequestMethodPOST usingParameters:parameters andCompletionHandler:completionHandler];
}

- (void) renewAccessTokenWithCompletionHandler:(RMFBLayerRenewalBlock)completionHandler {
	NSLog(@"RMFBOSX: Will renew access_token ...");
	[self.osxAccountStore renewCredentialsForAccount:self.osxFbAccount completion:^(ACAccountCredentialRenewResult renewResult, NSError *error) {
		if (renewResult == ACAccountCredentialRenewResultRenewed) {
			NSLog(@"RMFBOSX: access_token renewed.");
			completionHandler();
		}
		if (renewResult == ACAccountCredentialRenewResultFailed || renewResult == ACAccountCredentialRenewResultRejected) {
			NSLog(@"RMFBOSX: Renewal failed, will notify failDelegate.");
			[self.failDelegate abstraction:self failedWithError:error];
		}
	}];
}

- (RMFBFrameworkIdentifier) abstractionIdentifier {
	return RMFBFrameworkOSX;
}

- (void) invalidateSession {
	self.osxAccountStore = nil;
	self.accessToken = nil;
}

@end
