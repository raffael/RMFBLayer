# RMFBLayer

RMFBLayer is a class to access the Facebook API within OS X applications by sending requests either using the **OS X Facebook integration** (if available) or **PhFacebook.framework** as fallback.

OS X Facebook integration (Social.framework) might not be available due to the fact that the user has not updated yet to OS X 10.8.2 or that the user has not set up the Facebook account in his System Preferences. The RMFBLayer automatically recognizes these circumstances and uses then PhFacebook.framework instead.

RMFBLayer provides a streamlined interface to the two Facebook API abstractions to facilitate the data retrieval. All requests are based on the completion block paradigm.

**WARNING:** Since PhFacebook.framework originally does not support completion blocks, a modified version is available [as fork](https://github.com/raffael-me/PhFacebook), separately.

## Requirements:

- You have added Social.framework to your app
- You have added the [PhFacebook.framework](https://github.com/raffael-me/PhFacebook) with completion block support

## Details:

RMFBLayer provides an interface to quickly send requests and process their result. It does that by delegating the requests to abstractions. Currently, two abstraction intances are available: 
* RMFBOSX: The OS X Facebook integration,
* RMFBPhFacebook: The PhFacebook framework
Both abstractions, and the layer itself, share the same interface to access the Facebook API.

To make FQL requests, wrap them into a normal GET request.

## Usage:

1. Set the prefered abstraction and add the two abstractions:

```smalltalk
	[[RMFBLayer sharedInstance] setPreferedFramework:RMFBFrameworkOSX];
	[[RMFBLayer sharedInstance] addAbstraction:[[RMFBOSX alloc] initWithFacebookAppId:kFacebookAppId]];
	[[RMFBLayer sharedInstance] addAbstraction:[[RMFBPhFacebook alloc] initWithFacebookAppId:kFacebookAppId]];
```

2. Set the delegate in order to be notified once the auth has finished:

```smalltalk
	[[RMFBLayer sharedInstance] setDelegate:self];
```

3. Start the authentication:

```smalltalk
	[[RMFBLayer sharedInstance] authForPermissions:@[@"read_mailbox"]];
```

4. Make a new request:

```smalltalk
	[[RMFBLayer sharedInstance] performGETRequest:@"/me" usingParameters:@{
		@"fields": @"id"
	} andCompletionHandler:^(NSObject *resultObject, NSError *error) {
		NSLog(@"Get request result: %@", resultObject);
		NSLog(@"Get request error: %@", error);
		NSString *identifier = [((NSDictionary *)resultObject) objectForKey:@"id"];
	}];
```

# Status
Currently marked as BETA. PhFacebook usage has not been tested heavily.