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
		self.preferedFramework = RMFBDefaultPreferedFramework;
		self.autofetchUserInformation = RMFBDefaultAutofetchUserInformation;
    }
    return self;
}

- (id) initWithFacebookAppId:(NSString *) appId {
    self = [self init];
    if (self) {
    	self.facebookAppId = appId;
		self.preferedFramework = RMFBFrameworkOSX;
    }
    return self;
}

- (void) addAbstraction: (id<RMFBAbstraction>) newAbstraction {
	[abstractions addObject: newAbstraction];
	if (self.facebookAppId) [newAbstraction setFacebookAppId:self.facebookAppId];
	if (self.delegate) [newAbstraction setDelegate:_delegate];
	[newAbstraction setFailDelegate:self];
	if (!_abstraction) _abstraction = newAbstraction;
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
	[_abstraction authForPermissions:self.permissions];
}

- (void) abstractionFailed:(id<RMFBAbstraction>)sender {
	int currentIndex = (int)[abstractions indexOfObject:self.abstraction];
	currentIndex = (currentIndex +1) % (int)abstractions.count;
	_abstraction = [abstractions objectAtIndex:currentIndex];
	NSLog(@"RMFBLayer: Switched abstraction after previous abstraction failed.");
	[_abstraction authForPermissions:self.permissions];
}

- (NSString *) accessToken {
	return [self.abstraction accessToken];
}

@end
