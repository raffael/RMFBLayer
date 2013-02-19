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

@interface RMFBOSX : NSObject <RMFBAbstraction>

@property (retain) NSString *facebookAppId;
@property (retain,nonatomic) NSString *accessToken;
@property (retain,nonatomic) NSObject<RMFBLayerDelegate> *delegate;
@property (retain) id<RMFBAbstractionFailDelegate> failDelegate;

@property (retain) ACAccountStore *osxAccountStore;
@property (retain) ACAccount *osxFbAccount;
@property (retain) NSString *osxSlService;
@property (retain) NSArray *permissions;

@end
