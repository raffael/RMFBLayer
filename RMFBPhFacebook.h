//
//  RMFBPhFacebook.h
//
//  Created by Raffael Hannemann on 01.02.13.
//  Copyright (c) 2013 raffael.me. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PhFacebook/PhFacebook.h>
#import "RMFBLayer.h"

@interface RMFBPhFacebook : NSObject <RMFBAbstraction, PhFacebookDelegate> {
	PhFacebook *fb;
	NSMutableDictionary *request2BlockMap;
	NSArray *requestedPermissions;
}

@property (retain) NSString *facebookAppId;
@property (retain,nonatomic) NSString *accessToken;
@property (retain,nonatomic) NSObject<RMFBLayerDelegate> *delegate;
@property (retain) id<RMFBAbstractionFailDelegate> failDelegate;

- (void) setLoginRedirectURL: (NSString *) loginRedirectURL; // URL where to redirect once user submits login form, MUST be set.

@end
