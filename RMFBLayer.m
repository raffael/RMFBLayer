//
//  RMFBLayer.m
//
//  Created by Raffael Hannemann on 31.01.13.
//  Copyright (c) 2013 raffael.me. All rights reserved.
//

#import "RMFBLayer.h"

@implementation RMFBLayer

static RMFBLayer *instance;
+(RMFBLayer *) sharedInstance {
	if (instance==nil) instance = [[self alloc] init];
	return instance;
}

+ (id) layerWithFacebookAppId:(NSString *)appId {
	return [[RMFBLayer alloc] initWithFacebookAppId:appId];
}

- (id)init
{
    self = [super init];
    if (self) {
        abstractions = [NSMutableArray array];
		self.preferredFramework = RMFBDefaultPreferredFramework;
		self.autofetchUserInformation = RMFBDefaultAutofetchUserInformation;
    }
    return self;
}

- (id) initWithFacebookAppId:(NSString *) appId {
    self = [self init];
    if (self) {
    	self.facebookAppId = appId;
		self.preferredFramework = RMFBDefaultPreferredFramework;
    }
    return self;
}

- (void) addAbstraction: (id<RMFBAbstraction>) newAbstraction {
	[abstractions addObject: newAbstraction];
	if (self.facebookAppId) [newAbstraction setFacebookAppId:self.facebookAppId];
	if (self.delegate) [newAbstraction setDelegate:_delegate];
	[newAbstraction setFailDelegate:self];
	if (abstractions.count==1) _abstraction = newAbstraction;
	else {
		for(id<RMFBAbstraction> abstraction in abstractions) {
			if (self.preferredFramework==[abstraction abstractionIdentifier]) {
				_abstraction = abstraction;
			}
		}
		if (!_abstraction) _abstraction = [abstractions lastObject];
	}
}

- (RMFBFrameworkIdentifier) abstractionIdentifier {
	return [_abstraction abstractionIdentifier];
}

- (void) setDelegate:(id<RMFBLayerDelegate>)delegate {
	_delegate = delegate;
	for(id<RMFBAbstraction> abstraction in abstractions)
		[abstraction setDelegate:delegate];
}

- (void) performRequest:(NSString *)urlString usingRequestMethod:(RMFBRequestMethod)method usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {
	[_abstraction performRequest:urlString usingRequestMethod:method usingParameters:parameters andCompletionHandler:completionHandler];
}

- (void) performGETRequest:(NSString *)urlString usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {
	[_abstraction performGETRequest:urlString usingParameters:parameters andCompletionHandler:completionHandler];
}

- (void) performPOSTRequest:(NSString *)urlString usingParameters:(NSDictionary *)parameters andCompletionHandler:(RMFBLayerCompletionBlock)completionHandler {
	[_abstraction performPOSTRequest:urlString usingParameters:parameters andCompletionHandler:completionHandler];
}

- (void) authForPermissions:(NSArray *)permissions {
	self.permissions = [permissions copy];
	[(NSObject *)_abstraction performSelectorOnMainThread:@selector(authForPermissions:) withObject:permissions waitUntilDone:YES];
}

- (void) setPreferredFramework:(RMFBFrameworkIdentifier)preferredFramework {
	if (_preferredFramework != preferredFramework) {
		for(id<RMFBAbstraction> abstraction in abstractions) {
			if (preferredFramework==[abstraction abstractionIdentifier]) {
				_abstraction = abstraction;
			}
		}
	}
	_preferredFramework = preferredFramework;
}

/** Switching abstractions only happend during authenticating. */
- (void) abstraction:(id<RMFBAbstraction>)sender failedWithError:(NSError *)error {
	
	// If all abstractions have been tried out, fail finally
	_failedAbstractions++;
	if (_failedAbstractions>=abstractions.count) {
		[self.delegate performSelectorOnMainThread:@selector(facebookAuthenticationFailedFinallyWithError:) withObject:error waitUntilDone:NO];
		return;
	}
	
	// ... else, switch to the next abstraction
	int currentIndex = (int)[abstractions indexOfObject:self.abstraction];
	
	// Notify the delegate about the switching
	if ([self.delegate respondsToSelector:@selector(facebookAbstractionSwitchedAfterFail:)])
		[self.delegate facebookAbstractionSwitchedAfterFail:currentIndex];

	currentIndex = (currentIndex +1) % (int)abstractions.count;
	_abstraction = [abstractions objectAtIndex:currentIndex];
	NSLog(@"RMFBLayer: Switched abstraction after previous abstraction failed.");
	
	[_abstraction authForPermissions:self.permissions];
}

- (NSString *) accessToken {
	return [self.abstraction accessToken];
}

- (void) invalidateSession {
	[self.abstraction invalidateSession];
}

- (void) setFacebookAppId:(NSString *)facebookAppId {
	_facebookAppId = facebookAppId;
	for(id<RMFBAbstraction> abstraction in abstractions)
		[abstraction setFacebookAppId:facebookAppId];
}

@end
