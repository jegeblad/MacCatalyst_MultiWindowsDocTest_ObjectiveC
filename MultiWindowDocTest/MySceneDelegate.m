#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/UTType.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "DocumentBrowserViewController.h"
#import "MySceneDelegate.h"
#import "Document.h"
#import "RecentDocumentHandler.h"

@implementation MySceneDelegate

-(void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
	scene.activationConditions.canActivateForTargetContentIdentifierPredicate = [NSPredicate predicateWithValue:NO];
	scene.activationConditions.prefersToActivateForTargetContentIdentifierPredicate = [NSPredicate predicateWithValue:NO];
	
	/*
	  1) when using requestSceneSessionActivation:userActivity:options:errorHandler: the user activity is in the userActivities set of connectionOptions.
	  2) when user reactivates an instance of UI, UIKit creates a scene object and populates it with saved state,
	   provided by stateRestorationActivityForScene: The user activity is presented in session.stateRestorationActivity.
	*/

	NSUserActivity * userActivityConnectionOptions = [connectionOptions.userActivities anyObject];
	NSUserActivity * sessionUserActivity = session.stateRestorationActivity;
	NSUserActivity * userActivity = userActivityConnectionOptions?userActivityConnectionOptions:sessionUserActivity;

	NSLog(@"willConnectToSession: %@ %@ %@ %@", scene,  userActivity, session.stateRestorationActivity, connectionOptions);
	NSLog(@"\t : URL %@\n", [connectionOptions.URLContexts.allObjects count]>0?connectionOptions.URLContexts.allObjects.firstObject:nil);
	UIWindow * window = [((UIWindowScene*)scene).windows objectAtIndex:0];
	NSLog(@"\t : Activity %@\n", userActivity.activityType );
	
	DocumentBrowserViewController * docBrowser = [[DocumentBrowserViewController alloc] initForOpeningContentTypes:@[
		[UTType typeWithIdentifier:@"public.plain-text"]
	]];
	window.rootViewController = docBrowser;

	// When trying to open a recent document
	if ([userActivity.activityType isEqual:@"com.mexircus.openrecentdoc"])
	{
		[scene setUserActivity:nil];
		NSURL * url = [RecentDocumentHandler dataToURL:userActivity.userInfo[@"urldata"]];
		[docBrowser tryToRevealAndOpenDocumentAtURL:url];
		return;
	}

	scene.userActivity = userActivity;
	if ([connectionOptions.URLContexts count]>0)
	{
		[self scene:scene openURLContexts:connectionOptions.URLContexts];
	}
}



- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
//	DocumentBrowserViewController * docBrowser = (DocumentBrowserViewController*)self.window.rootViewController;
	UIOpenURLContext * urlContext = [URLContexts anyObject];
	NSLog(@"openURLContexts Context: %@", urlContext);
	UIWindow * window = [((UIWindowScene*)scene).windows objectAtIndex:0];
	DocumentBrowserViewController * docBrowser = (DocumentBrowserViewController*)window.rootViewController;
	[docBrowser tryToRevealAndOpenDocumentAtURL:urlContext.URL];
}

- (NSUserActivity *)stateRestorationActivityForScene:(UIScene *)scene
{
	NSLog(@"stateRestorationActivityForScene: %@ -> %@ | %@", scene, scene.userActivity, scene.userActivity.activityType);
	return scene.userActivity;
}

- (void)sceneDidDisconnect:(UIScene *)scene
{
	UIWindow * window = [((UIWindowScene*)scene).windows objectAtIndex:0];
	DocumentBrowserViewController * docBrowser = (DocumentBrowserViewController*)window.rootViewController;
	if (docBrowser)
	{
		[docBrowser cleanUp]; // pop the doc VC if visible
	}
}

#if 0


- (void)sceneWillEnterForeground:(UIScene *)scene
{
	NSLog(@"sceneWillEnterForeground: %@", scene);
/*
	for (UIWindow * window in ((UIWindowScene*)scene).windows)
	{
		NSLog(@"  Window root view controller: %@", window.rootViewController);
	}
 */
}


- (void)sceneDidBecomeActive:(UIScene *)scene
{
	NSLog(@"sceneDidBecomeActive: %@", scene);
/*	for (UIWindow * window in ((UIWindowScene*)scene).windows)
	{
		NSLog(@"  Window root view controller: %@", window.rootViewController);
	}*/
}


- (void)sceneWillResignActive:(UIScene *)scene
{
	NSLog(@"sceneWillResignActive: %@", scene);
}


- (void)sceneDidEnterBackground:(UIScene *)scene
{
	NSLog(@"sceneDidEnterBackground: %@", scene);
}



- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity
{
	NSLog(@"continueUserActivity: %@", scene);
}


- (void)scene:(UIScene *)scene didFailToContinueUserActivityWithType:(NSString *)userActivityType error:(NSError *)error
{
	NSLog(@"didFailToContinueUserActivityWithType: %@", scene);
}



- (void)scene:(UIScene *)scene didUpdateUserActivity:(NSUserActivity *)userActivity
{
	NSLog(@"didUpdateUserActivity: %@", scene);
}

// ----------------------------------------------------------------
//
// UIWindowSceneDelegate
//


- (void)windowScene:(UIWindowScene *)windowScene didUpdateCoordinateSpace:(id<UICoordinateSpace>)previousCoordinateSpace
	interfaceOrientation:(UIInterfaceOrientation)previousInterfaceOrientation
	traitCollection:(UITraitCollection *)previousTraitCollection
{
	NSLog(@"didUpdateCoordinateSpace: %@", windowScene);

}


- (void)windowScene:(UIWindowScene *)windowScene
	performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem
	completionHandler:(void (^)(BOOL succeeded))completionHandler
{
	NSLog(@"performActionForShortcutItem: %@", windowScene);

}


- (void)windowScene:(UIWindowScene *)windowScene
	userDidAcceptCloudKitShareWithMetadata:(CKShareMetadata *)cloudKitShareMetadata
{
	NSLog(@"userDidAcceptCloudKitShareWithMetadata: %@", windowScene);

}

#endif

@end
