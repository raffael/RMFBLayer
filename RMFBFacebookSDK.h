//
//  RMFBOSX.h
//
//  Created by Raffael Hannemann on 01.02.13.
//  Copyright (c) 2013 raffael.me. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accounts/Accounts.h>
#if TARGET_OS_IPHONE
#import <FacebookSDK/FacebookSDK.h>
#endif
#import "RMFBLayer.h"

@interface RMFBFacebookSDK : NSObject <RMFBAbstraction> {
	int _authAttempts;
}

@property (strong) NSString *facebookAppId;
@property (strong,nonatomic) NSString *accessToken;
@property (weak,nonatomic) NSObject<RMFBLayerDelegate> *delegate;
@property (weak) id<RMFBAbstractionFailDelegate> failDelegate;
@property (strong) NSArray *permissions;
@property (assign,readonly) BOOL authenticated;

@end
