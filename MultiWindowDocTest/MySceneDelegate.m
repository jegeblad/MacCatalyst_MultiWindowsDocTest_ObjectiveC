#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/UTType.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "Constants.h"
#import "DocumentBrowserViewController.h"
#import "DocumentViewController.h"
#import "Document.h"
#import "RecentDocumentHandler.h"
#import "MySceneDelegate.h"



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

	UIWindow * window = [((UIWindowScene*)scene).windows objectAtIndex:0];

	// When trying to open a document from the recent menu -- We can actually just open the document view controller directly
	// To do that, we replace window.rootViewController in presentRecentURL:onWindow:inScene
	if ([userActivity.activityType isEqual:[Constants userActivityTypeOpenRecentDocument]])
	{
		NSURL * url = [RecentDocumentHandler dataToURL:userActivity.userInfo[[Constants keyURLData]]];
		[self presentDocumentURLDirectly:url onWindow:window inScene:scene];
		return;
	}
	if ([userActivity.activityType isEqual:[Constants userActivityTypeNewDocument]])
	{
		DocumentBrowserViewController * docBrowser = [[DocumentBrowserViewController alloc] initForOpeningContentTypes:@[ [UTType typeWithIdentifier:@"public.plain-text"] ] ];
		window.rootViewController = docBrowser;
		scene.userActivity = userActivity;
		docBrowser.createNewDocumentOnAppear = YES;
		return;
	}

	// Replace the document browser controller here, if you want
	// The default one just uses the Info.plist to determine the UTTypes, so here we can customize it a bit
	DocumentBrowserViewController * docBrowser = [[DocumentBrowserViewController alloc] initForOpeningContentTypes:@[ [UTType typeWithIdentifier:@"public.plain-text"] ] ];
	window.rootViewController = docBrowser;
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
	UIViewController * rootViewController = window.rootViewController;
	DocumentBrowserViewController * docBrowser = [rootViewController isKindOfClass:[DocumentBrowserViewController class]] ? (DocumentBrowserViewController*)rootViewController : nil;
	if (docBrowser)
	{
		[docBrowser cleanUp]; // pop the doc VC if visible to free resources
	}
}


-(void) presentDocumentURLDirectly:(NSURL*) documentURL onWindow:(UIWindow*) window inScene:(UIScene*)scene
{
	UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	DocumentViewController *documentViewController = [storyBoard instantiateViewControllerWithIdentifier:@"DocumentViewController"];
	[documentURL startAccessingSecurityScopedResource];
	documentViewController.document = [[Document alloc] initWithFileURL:documentURL];
	documentViewController.modalPresentationStyle = UIModalPresentationFullScreen;
	window.rootViewController = documentViewController;

	[documentViewController.document openWithCompletionHandler:^(BOOL success)
	{
		if (success)
		{
			[[RecentDocumentHandler sharedHandler] addURLForRecent:documentURL];
			[[UIMenuSystem mainSystem] setNeedsRebuild]; // Make sure this item will be part of recents next time we show the menu
		}
		else
		{
			NSLog(@"I couldn't open doc url %@. Destroying scene.", documentURL);

			// We don't know what the error is here so just display something generic and unhelpful as "try again later....".
			UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"Unable to open document"
												message:[NSString stringWithFormat:@"Unable to open document at %@. Please try again later.", [documentURL path]]
										 preferredStyle:UIAlertControllerStyleAlert];
			[alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
			{
				// When the user clicks OK -> Destroy this scene session to close the window.
				[[UIApplication sharedApplication] requestSceneSessionDestruction:scene.session options:nil errorHandler:nil];
			}]];
			[documentViewController presentViewController:alertController animated:YES completion:nil];
		}
		[documentURL stopAccessingSecurityScopedResource];
	}];
}



@end
