//
//  RMFBOSX.h
//
//  Created by Raffael Hannemann on 01.02.13.
//  Copyright (c) 2013 raffael.me. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "RMFBLayer.h"

typedef NS_ENUM(NSUInteger, RMFBOSXErrorCode) {
	RMFBOSXNotSupported,
	RMFBOSXObtainingAccountIdentifierTimedOut,
	RMFBOSXAppNotAllowed,
	RMFBOSXUnkownAccountAccessError,
	RMFBOSXTooManyAttempts,
	RMFBOSXAccountCredentialRenewalFailed,
	RMFBOSXAccountIsNil,
};

@interface RMFBOSX : NSObject <RMFBAbstraction> {
	BOOL _isObtainingAccountType;
	NSThread *_obtainingAccountTypeThread;
	int _authAttempts;
}

@property (strong) NSString *facebookAppId;
@property (strong,nonatomic) NSString *accessToken;
@property (weak,nonatomic) NSObject<RMFBLayerDelegate> *delegate;
@property (weak) id<RMFBAbstractionFailDelegate> failDelegate;

@property (strong) ACAccountStore *osxAccountStore;
@property (strong) ACAccount *osxFbAccount;
@property (strong) NSString *osxSlService;
@property (strong) NSArray *permissions;

@property (assign,readonly) BOOL authenticated;

@end
