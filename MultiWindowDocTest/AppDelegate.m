//
//  AppDelegate.m
//  MultiWindowDocTest
//
//  Created by Jens Egeblad on 27/05/2021.
//

#import "AppDelegate.h"
#import "DocumentBrowserViewController.h"
#import "DocumentViewController.h"
#import "Document.h"
#import "MySceneDelegate.h"
#import "RecentDocumentHandler.h"

@interface AppDelegate ()
{
}

@end

@implementation AppDelegate



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	return YES;
}


-(UISceneConfiguration*)application:(UIApplication*) application configurationForConnectingSceneSession:(nonnull UISceneSession *)connectingSceneSession options:(nonnull UISceneConnectionOptions *)options
{
	return [UISceneConfiguration configurationWithName:@"MySceneConfig" sessionRole:connectingSceneSession.role];
}


- (BOOL)application:(UIApplication *)app openURL:(NSURL *)inputURL options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
	if (!inputURL.isFileURL) {
	    return NO;
	}

	// Reveal / import the document at the URL
	DocumentBrowserViewController *documentBrowserViewController = (DocumentBrowserViewController *)self.window.rootViewController;
	[documentBrowserViewController revealDocumentAtURL:inputURL importIfNeeded:YES completion:^(NSURL * _Nullable revealedDocumentURL, NSError * _Nullable error)
	{
	    if (error) {
	        // Handle the error appropriately
	        NSLog(@"Failed to reveal the document at URL %@ with error: '%@'", inputURL, error);
	        return;
	    }
	    [documentBrowserViewController presentDocumentAtURL:revealedDocumentURL];
	}];

	return YES;
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions
{
	NSLog(@"Did discard sessions");
}

// ------------------------------------------------------------------------
// Menu stuff
//


-(IBAction) onOpenRecentDocument:(UICommand*) sender
{
	NSData * urldata = sender.propertyList[@"urldata"];
	if (urldata)
	{
		// Check if document already open
		NSURL * documentURL = [RecentDocumentHandler dataToURL:urldata];
		if (documentURL && [DocumentViewControllerManager activateExistingSceneWithURLIfOpen:documentURL])
		{
			return;
		}
		
		NSUserActivity * userActivity = [[NSUserActivity alloc] initWithActivityType:@"com.mexircus.openrecentdoc"];
		userActivity.userInfo = @{@"urldata":urldata};
		[[UIApplication sharedApplication] requestSceneSessionActivation:nil
															userActivity:userActivity options:nil errorHandler:^(NSError * _Nonnull error)
		{
		}];
	}
}


-(IBAction) onClearRecentList:(id) sender
{
	[[RecentDocumentHandler sharedHandler] clearRecentURLs];
	[[UIMenuSystem mainSystem] setNeedsRebuild]; // Make sure menu is really clear now
}


- (UIMenu*)buildRecentsMenu
{
	NSArray * recentURLsData = [[RecentDocumentHandler sharedHandler] recentURLs];
	NSMutableArray * children = [NSMutableArray arrayWithCapacity:[recentURLsData count]+2];

	if (recentURLsData)
	{
		// add reverse
		for (NSInteger idx = [recentURLsData count]-1; idx>=0; --idx)
		{
			NSData * data = [recentURLsData objectAtIndex:idx];
			NSURL * url = [RecentDocumentHandler dataToURL:data];
			if (url)
			{
				NSString * title = [[url path] lastPathComponent];
				UICommand * newCommand = [UICommand commandWithTitle:title image:nil action:@selector(onOpenRecentDocument:) propertyList:@{@"urldata":data}];
				[children addObject:newCommand];
			}
		}
	}
	// Note: If we have no recentURLs just add clear menu dimmed (disabled)
	// I know Apple calls this "Clear Menu", but I suspect "Clear list" is more user friendly.
	UICommand * clearMenuCommand = [UICommand commandWithTitle:@"Clear List" image:nil action:@selector(onClearRecentList:) propertyList:nil];
	UIMenu * clearMenuMenu = [UIMenu menuWithTitle:@"Clear list..." image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[clearMenuCommand]];
	[children addObject:clearMenuMenu];

	UIMenu * openRecentDocument = [UIMenu menuWithTitle:@"Open Recent..." image:nil identifier:nil options:0 children:children];
	return openRecentDocument;
}


- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder
{
	[super buildMenuWithBuilder:builder];
	// File menu
	[builder removeMenuForIdentifier:UIMenuNewScene];
	[builder removeMenuForIdentifier:UIMenuOpenRecent]; // <- remove Apple's recent menu
	
	UIKeyCommand * newDocumentMenuItem = [UIKeyCommand commandWithTitle:@"New Document" image:nil action:@selector(onNewDocument) input:@"n" modifierFlags:UIKeyModifierCommand propertyList:nil];
	UIMenu * newItem = [UIMenu menuWithTitle:@"New Document" image:nil identifier:UIMenuNewScene options:UIMenuOptionsDisplayInline children:@[
		newDocumentMenuItem
	]];
	
	UIMenu * openRecentDocument = [self buildRecentsMenu];
	UIKeyCommand * openDocumentItem = [UIKeyCommand commandWithTitle:@"Open..." image:nil action:@selector(onOpenDocument) input:@"O" modifierFlags:UIKeyModifierCommand propertyList:nil];
	UIMenu * openMenu = [UIMenu menuWithTitle:@"Open..." image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[
		openDocumentItem,
		openRecentDocument
	]];
	[builder insertChildMenu:newItem atStartOfMenuForIdentifier:UIMenuFile];
	[builder insertSiblingMenu:openMenu afterMenuForIdentifier:UIMenuNewScene];
}


-(IBAction) onNewDocument
{
	
}


-(void) requestNewDocBrowserScene
{
	static int counter = 0;
	NSUserActivity * userActivity = [[NSUserActivity alloc] initWithActivityType:[NSString stringWithFormat:@"com.mexircus.test%d", counter++]];
	[[UIApplication sharedApplication] requestSceneSessionActivation:nil
														userActivity:userActivity options:nil errorHandler:^(NSError * _Nonnull error)
	{

	}];
}


-(IBAction) onOpenDocument
{
	if (false)
	{
		// Create new a scene -- This doesn't pop the Browser controller to the top
		[self requestNewDocBrowserScene];
		return;
	}
	
	// Ideally we would just activate the sccene, but that doesn't seem to  pop the doc-browser to the front
	// So instead I tried to kill it and open a new one once killed, however
	// that seems to break it
	UIWindowScene * currentActive = [DocumentBrowserViewController activeScene];
	if (currentActive && currentActive.session)
	{
		UIViewController * vc = [[UIViewController alloc] init];
		[[currentActive.windows objectAtIndex:0].rootViewController presentViewController:vc animated:NO completion:
		 ^(){
			[[UIApplication sharedApplication] requestSceneSessionActivation:currentActive.session userActivity:nil options:nil errorHandler:nil];
			[vc dismissViewControllerAnimated:NO completion:nil];
		}];
	}
	else
	{
		[self requestNewDocBrowserScene];
	}
}


-(BOOL) respondsToSelector:(SEL)aSelector
{
	if (aSelector==@selector(onNewDocument))
	{
		return YES;
	}
	if (aSelector==@selector(onOpenDocument))
	{
		return YES;
	}
	if (aSelector==@selector(onClearRecentList:))
	{
		return [[RecentDocumentHandler sharedHandler] recentURLs]!=nil; // will return nil if count == 0
	}
	
	return [super respondsToSelector:aSelector];
}


// ------------------------------------------------------------------------
// Scene stuff
//


@end
