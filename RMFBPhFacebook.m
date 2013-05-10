//
//  RMFBPhFacebook.m
//
//  Created by Raffael Hannemann on 01.02.13.
//  Copyright (c) 2013 raffael.me. All rights reserved.
//

#import "RMFBPhFacebook.h"

@implementation RMFBPhFacebook

- (id) initWithFacebookAppId:(NSString *)appId {
    self = [self init];
    if (self) {
    	fb = [[PhFacebook alloc] initWithApplicationID:appId delegate: self];
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self) {
		fb = nil;
    }
    return self;
}

- (void) authForPermissions:(NSArray *)permissions {
	requestedPermissions = [permissions copy];
	//TODO: does this work: ?
	[fb performSelectorOnMainThread:@selector(getAccessTokenForPermissions:cached:) withObject:permissions waitUntilDone:YES];
}

- (void) renewAccessTokenWithCompletionHandler:(RMFBLayerRenewalBlock)completionHandler {
	[fb invalidateCachedToken];
	[fb getAccessTokenForPermissions:requestedPermissions cached:YES];
}

- (void) setLoginRedirectURL:(NSString *)loginRedirectURL {
	[fb setLoginSuccessURL:loginRedirectURL];
}

#pragma mark -
#pragma mark PhFacebook delegate methods
- (void) tokenResult:(NSDictionary *)result {
	if ([[result valueForKey: @"valid"] boolValue]==YES) {
		self.accessToken = [fb accessToken];
		[self.delegate performSelectorOnMainThread:@selector(facebookAuthSucceeded) withObject:nil waitUntilDone:NO ];

	} else {
		[self.delegate performSelectorOnMainThread:@selector(facebookAuthFailed) withObject:nil waitUntilDone:NO ];
	}
}

- (void) performRequest:(NSString *)urlString usingRequestMethod:(RMFBRequestMethod)method usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {

	NSMutableDictionary *encodedParameters = [NSMutableDictionary dictionaryWithCapacity:parameters.count];
	for(NSString *key in parameters) {
		NSString *originalValue = [parameters objectForKey:key];
		NSString *encodedValue = CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)originalValue,
																					 NULL,
																					 (CFStringRef)@"!*'();:@&=+$,/?%#[]",
																					 kCFStringEncodingUTF8 ));

		[encodedParameters setObject:encodedValue forKey:key];
	}

	[fb sendRequest:urlString params:encodedParameters usePostRequest:(method==RMFBPOSTRequest) withCompletionBlock:^(NSDictionary *result) {

		NSString *jsonString = [result objectForKey:@"result"];

		NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
		NSError *jsonError;
	//TODO: critical assumption: result is always dictionary, never array?
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves|NSJSONReadingAllowFragments error:&jsonError];

		if (jsonError) {
			completionHandler(nil, [NSError errorWithDomain:@"RMPhFacebook" code:RMFBAbstractionErrorJSONError userInfo:@{@"json-error":jsonError}]);
		} else if (json[@"error"]!=nil) {
			completionHandler(json, [NSError errorWithDomain:@"RMPhFacebook" code:RMFBAbstractionErrorAPIError userInfo:@{@"api-error":json[@"error"]}]);
		} else {
			completionHandler(json,nil);
		}
	}];
}

- (void) performGETRequest:(NSString *)urlString usingParameters: (NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {
	[self performRequest:urlString usingRequestMethod:RMFBGETRequest usingParameters:parameters andCompletionHandler:completionHandler];
}

- (void) performPOSTRequest:(NSString *)urlString usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {
	[self performRequest:urlString usingRequestMethod:RMFBPOSTRequest usingParameters:parameters andCompletionHandler:completionHandler];
}

@end
