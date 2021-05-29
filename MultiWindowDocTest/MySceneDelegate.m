#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/UTType.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "DocumentBrowserViewController.h"
#import "MySceneDelegate.h"
#import "Document.h"
#import "RecentDocumentHandler.h"
#import "Constants.h"


@implementation MySceneDelegate


-(void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
	scene.activationConditions.canActivateForTargetContentIdentifierPredicate = [NSPredicate predicateWithValue:NO];
	scene.activationConditions.prefersToActivateForTargetContentIdentifierPredicate = [NSPredicate predicateWithValue:NO];

	/* Get associated User activity
	  1) when using requestSceneSessionActivation:userActivity:options:errorHandler: the user activity is in the userActivities set of connectionOptions.
	  2) when user reactivates an instance of UI, UIKit creates a scene object and populates it with saved state,
	   provided by stateRestorationActivityForScene: The user activity is presented in session.stateRestorationActivity.
	*/
	NSUserActivity * userActivityConnectionOptions = [connectionOptions.userActivities anyObject];
	NSUserActivity * sessionUserActivity = session.stateRestorationActivity;
	NSUserActivity * userActivity = userActivityConnectionOptions?userActivityConnectionOptions:sessionUserActivity;

	// Replace the document browser controller here, if you want
	// The default one just uses the Info.plist (Sigh, really!?!)
	UIWindow * window = [((UIWindowScene*)scene).windows objectAtIndex:0];
	DocumentBrowserViewController * docBrowser = [[DocumentBrowserViewController alloc] initForOpeningContentTypes:@[ [UTType typeWithIdentifier:@"public.plain-text"] ] ];
	window.rootViewController = docBrowser;

	// When trying to open a document from the recent menu -- I need to know if this is
	// a recent item to immediately reveal the document in the document browser, and then access it
	if ([userActivity.activityType isEqual:[Constants userActivityTypeOpenRecentDocument]])
	{
		NSURL * url = [RecentDocumentHandler dataToURL:userActivity.userInfo[[Constants keyURLData]]];
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
	UIOpenURLContext * urlContext = [URLContexts anyObject];
	UIWindow * window = [((UIWindowScene*)scene).windows objectAtIndex:0];
	DocumentBrowserViewController * docBrowser = (DocumentBrowserViewController*)window.rootViewController;
	[docBrowser tryToRevealAndOpenDocumentAtURL:urlContext.URL];
}


- (NSUserActivity *)stateRestorationActivityForScene:(UIScene *)scene
{
	return scene.userActivity;
}


- (void)sceneDidDisconnect:(UIScene *)scene
{
	UIWindow * window = [((UIWindowScene*)scene).windows objectAtIndex:0];
	DocumentBrowserViewController * docBrowser = (DocumentBrowserViewController*)window.rootViewController;
	if (docBrowser)
	{
		[docBrowser cleanUp]; // pop the doc VC if visible to free resources
	}
}


@end
