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
		self.osxAccountStore = [[ACAccountStore alloc] init];
    }
    return self;
}

- (id) initWithFacebookAppId:(NSString *)appId {
	self = [self init];
	if (self) {
		self.facebookAppId = appId;
	}
	return self;
}

- (void) authForPermissions:(NSArray *)permissions {

	self.permissions = [permissions copy];

	// Set the dictionary that will be passed on to request account access
	NSDictionary *fbInfo = @{
		ACFacebookAppIdKey: self.facebookAppId,
		ACFacebookPermissionsKey: self.permissions,
		ACFacebookAudienceKey: ACFacebookAudienceOnlyMe,
	};

	// Get the Facebook account type for the access request
	ACAccountType *fbAccountType = [self.osxAccountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];

	// Request access to the Facebook account with the access info
	[self.osxAccountStore requestAccessToAccountsWithType:fbAccountType options:fbInfo completion:^(BOOL granted, NSError *error) {
		if (error) {
			if ([error code]==6) {
				NSLog(@"RMFBOSX: Failed to authenticate, will notify failDelegate.");
				[self.failDelegate abstractionFailed:self];
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
			[self testAccessToken];
		} else {
			NSLog(@"RMFBOSX: Access not granted");
			[self.delegate performSelectorOnMainThread:@selector(facebookAuthFailed) withObject:nil waitUntilDone:NO];
		}
	}];
}

- (void) testAccessToken {
	/** Trigger a test request, for which a valid access_token is required, with the current credentials / access_token. */
	[self performGETRequest:@"/me/"
			usingParameters:nil
	   andCompletionHandler:^(NSObject *resultObject, NSError *error) {
		   /** If this handler has been called, it means that the access_token now is valid. However it might have been renewed automatically during the request operation. */
		   self.accessToken = self.osxFbAccount.credential.oauthToken;
		   /** Thus, notify the delegate that authentication has been successful. */
		   [self.delegate performSelectorOnMainThread: @selector(facebookAuthSucceeded) withObject:nil waitUntilDone:NO];
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

		NSString *jsonString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
		NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
		NSError *jsonError = nil;
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves|NSJSONReadingAllowFragments error:&jsonError];

		if (jsonError) {
			NSLog(@"RMFBOSX: Error while parsing JSON string '%@' for request '%@'",jsonString,requestURL);
			completionHandler(nil, [NSError errorWithDomain:@"RMFBOSX" code:RMFBAbstractionErrorJSONError userInfo:@{@"json-error":jsonError}]);
		} else if ([json isKindOfClass:[NSDictionary class]] && [json objectForKey:@"error"]!=nil) {
			/** If an error is present, check if the access_token has to be renewed. */
			NSDictionary *apiError = [json objectForKey:@"error"];
			if ([[apiError objectForKey:@"code"] isEqualToNumber:@190]) {
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
			[self.failDelegate abstractionFailed:self];
		}
	}];
}

- (RMFBFrameworkIdentifier) abstractionIdentifier {
	return RMFBFrameworkOSX;
}

@end
