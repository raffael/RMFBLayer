//
//  RMFBFacebookSDK.m
//
//  Created by Raffael Hannemann on 19.07.14.
//  Copyright (c) 2013 raffael.me. All rights reserved.
//


#import "RMFBFacebookSDK.h"

@interface RMFBFacebookSDK ()
@property (assign,readwrite) BOOL authenticated;
@end

@implementation RMFBFacebookSDK {
	FBSession *_session;
	FBSessionStateHandler _stateHandler;
}

- (id)init {
    self = [super init];
    if (self) {
		_authAttempts = 0;
		__weak typeof(self)weakSelf = self;
		_stateHandler = ^(FBSession *session, FBSessionState state, NSError *error) {
			// if login fails for any reason, we alert
			NSLog(@"%@", session);
			
			if (error) {
				[weakSelf setAuthenticated:NO];
				[weakSelf.failDelegate abstraction:weakSelf failedWithError:error];
			} else if (FB_ISSESSIONOPENWITHSTATE(state)) {
				[weakSelf setAuthenticated:YES];
				[weakSelf setAccessToken:session.accessTokenData.accessToken];
				[weakSelf.delegate facebookAuthenticationSucceeded];
			}
		};
    }
    return self;
}

- (void) setAccessToken:(NSString *)accessToken {
	_accessToken = accessToken;
}

- (id) initWithFacebookAppId:(NSString *)appId {
	self = [self init];
	if (self) {
		self.facebookAppId = appId;
	}
	return self;
}

+ (NSError *) OSXFBAccountIsNilError {
	return [NSError errorWithDomain:@"me.raffael.RMFBLayer" code:0 userInfo:nil];
}

- (void) authForPermissions:(NSArray *)permissions {
	_authAttempts++;
	
	self.permissions = permissions.copy;
	
	if (_authAttempts>10) {
		_authenticated = NO;
		[self.failDelegate abstraction:self failedWithError:nil];
		return;
	}
	
	if (!self.permissions) {
		_authenticated = NO;
		[self.failDelegate abstraction:self failedWithError:nil];
	}
	
	if ([FBSession activeSession].isOpen) {
		_session = [FBSession activeSession];
		self.accessToken = _session.accessTokenData.accessToken;
		_authenticated = YES;
		[self.delegate facebookAuthenticationSucceeded];
	} else {
		_session = [[FBSession alloc] initWithPermissions:self.permissions];
		
		[_session setStateChangeHandler:^(FBSession *session, FBSessionState status, NSError *error) {
			// State changed! (Never called after switching back from Safari)
		}];
		
		[_session openWithBehavior:FBSessionLoginBehaviorUseSystemAccountIfPresent
				 completionHandler:^(FBSession *newSession, FBSessionState status, NSError *error) {
					 
					 [FBSession setActiveSession:newSession];
					 
					 _session = newSession;
					 
					 [FBSession openActiveSessionWithReadPermissions:self.permissions
														allowLoginUI:YES
												   completionHandler:_stateHandler];
				 }];
	}
	
}

- (NSString *) finalAPIURLStringFor:(NSString *) suffix {
	NSString *string = [RMFBBaseUri stringByAppendingString:suffix];
	return [string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (void) performRequest:(NSString *)urlString usingRequestMethod:(RMFBRequestMethod)method usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {

	// create the connection object
	FBRequestConnection *newConnection = [[FBRequestConnection alloc] init];
	
	// create a handler block to handle the results of the request for fbid's profile
	FBRequestHandler handler = ^(FBRequestConnection *connection, id result, NSError *error) {
		// output the results of the request
		completionHandler(result,error);
	};
	
	NSString *httpMethod = (method==RMFBPOSTRequest) ? @"POST" : @"GET";
	// create the request object, using the fbid as the graph path
	// as an alternative the request* static methods of the FBRequest class could
	// be used to fetch common requests, such as /me and /me/friends
	FBRequest *request = [[FBRequest alloc] initWithSession:FBSession.activeSession
												  graphPath:urlString
												 parameters:parameters
												 HTTPMethod:httpMethod];
	
	// add the request to the connection object, if more than one request is added
	// the connection object will compose the requests as a batch request; whether or
	// not the request is a batch or a singleton, the handler behavior is the same,
	// allowing the application to be dynamic in regards to whether a single or multiple
	// requests are occuring
	[newConnection addRequest:request completionHandler:handler];
	
	/*// if there's an outstanding connection, just cancel
	[self.requestConnection cancel];
	
	// keep track of our connection, and start it
	self.requestConnection = newConnection;
	 */
	[newConnection start];

}

- (void) performGETRequest:(NSString *)urlString usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {
	[self performRequest:urlString usingRequestMethod:RMFBGETRequest usingParameters:parameters andCompletionHandler:completionHandler];
}

- (void) performPOSTRequest:(NSString *)urlString usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {
	[self performRequest:urlString usingRequestMethod:RMFBPOSTRequest usingParameters:parameters andCompletionHandler:completionHandler];
}

- (void) renewAccessTokenWithCompletionHandler:(RMFBLayerRenewalBlock)completionHandler {
	//TODO!
}

- (RMFBFrameworkIdentifier) abstractionIdentifier {
	return RMFBFrameworkFacebookSDK;
}

- (void) invalidateSession {
	self.accessToken = nil;
	_authenticated = NO;
	//TODO: invalidate session
}

- (void) handleOpenURL:(NSURL *) URL sourceApplication: (NSString *) sourceApplication {
	[self performSelector:@selector(checkAuthentication:) withObject:@5 afterDelay:1];
	[FBAppCall handleOpenURL:URL sourceApplication:sourceApplication];
}

- (void) checkAuthentication: (NSNumber *) ttl {
	if ([FBSession activeSession].isOpen) {
		_stateHandler([FBSession activeSession], [FBSession activeSession].state, nil);
	} else {
		if (ttl.intValue > 0)
			[self performSelector:@selector(checkAuthentication:) withObject:@(ttl.intValue-1) afterDelay:1];
	}
}
@end
