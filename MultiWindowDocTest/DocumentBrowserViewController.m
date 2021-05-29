//
//  DocumentBrowserViewController.m
//  MultiWindowDocTest
//
//  Created by Jens Egeblad on 27/05/2021.
//

#import "DocumentBrowserViewController.h"
#import "Document.h"
#import "DocumentViewController.h"
#import "RecentDocumentHandler.h"
#import "Constants.h"

static __weak UIWindowScene* activeOnScene = nil; // Keep track of which scene holds a visible DocumentBrowserController. That way, we can reactivate this scene when the user clicks "Open ..."


@interface DocumentBrowserViewController () <UIDocumentBrowserViewControllerDelegate>
{
	__weak DocumentViewController * visibleDocVC; // <- Keep track of the visible document VC, so that we can drop it on clean up
}

@end


@implementation DocumentBrowserViewController


+(UIWindowScene*) activeScene
{
	return activeOnScene;
}


+(void) setActiveScene:(UIWindowScene*) scene
{
	activeOnScene = scene;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	visibleDocVC = nil; // <- No visible (presented) document view controller
    self.delegate = self;
    self.allowsDocumentCreation = YES;
    self.allowsPickingMultipleItems = NO;
}


-(void) viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self addArtificialSizeRestrictions];

	activeOnScene = self.view.window.windowScene;
	
	NSUserActivity * userActivity = [[NSUserActivity alloc] initWithActivityType:[Constants userActivityTypeDocumentBrowser]];
	userActivity.userInfo = @{@"browser" : @"browser"}; // <- This isn't really needed or used for anything
	
	self.view.window.windowScene.userActivity = userActivity;
}


-(void) viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	activeOnScene = nil;
}


-(void) addArtificialSizeRestrictions
{
	// Some weird empty windows that just show up with the browser
	// I don't know what they are, but if we restrict size of the scene they do not appear
	// Here we restrict the size of the scene until we transition to a proper view controller
	((UIWindowScene*)self.view.window.windowScene).sizeRestrictions.maximumSize = CGSizeMake(10, 10);
	((UIWindowScene*)self.view.window.windowScene).sizeRestrictions.minimumSize = CGSizeMake(10, 10);
}


-(void) removeArtificialSizeRestrictions
{
	// Some weird empty windows that just show up with the browser
	// I don't know what they are, but if we restrict size of the scene they do not appear
	// Here we allow free sizes again
	((UIWindowScene*)self.view.window.windowScene).sizeRestrictions.maximumSize = CGSizeMake(100000, 100000);
	((UIWindowScene*)self.view.window.windowScene).sizeRestrictions.minimumSize = CGSizeMake(640, 480);
}


- (void)presentDocumentAtURL:(NSURL *)documentURL
{
	// Access the document
	UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	DocumentViewController *documentViewController = [storyBoard instantiateViewControllerWithIdentifier:@"DocumentViewController"];
	[documentURL startAccessingSecurityScopedResource];
	documentViewController.document = [[Document alloc] initWithFileURL:documentURL];
	
	// If we don't try to open the document within openWithCompletionHandler
	// the view controller will appear and and disappear immediately in BigSur 11.2 - 11.4 (WTH?!)
	[self removeArtificialSizeRestrictions];
	documentViewController.modalPresentationStyle = UIModalPresentationFullScreen;
	[documentViewController.document openWithCompletionHandler:^(BOOL success)
	{
		if (success)
		{
			//[[RecentDocumentHandler sharedHandler] addBookmarkedURLForURL:documentURL]; // <- If using Apple's recent menu, it seems I need to cache the scoped bookmark document URL myself
			[[RecentDocumentHandler sharedHandler] addURLForRecent:documentURL];
			[[UIMenuSystem mainSystem] setNeedsRebuild]; // Make sure this item will be part of recents
		}
		[documentURL stopAccessingSecurityScopedResource];
		if (success)
		{
			[self removeArtificialSizeRestrictions];
			[self presentViewController:documentViewController animated:YES completion:nil];
			self->visibleDocVC = documentViewController;
			activeOnScene = nil;
		}
		else
		{
			NSLog(@"I couldn't open doc url %@", documentURL);
		}
	}];
}



- (void)tryToRevealAndOpenDocumentAtURL:(NSURL *)documentURL
{
	 // If using Apple's recent menu, it seems we need to replace the document URL with the scoped one from the cache
	/*
	NSURL * bookmarkURL = [[RecentDocumentHandler sharedHandler] bookmarkedURLForURL:documentURL];
	if (bookmarkURL)
	{
		documentURL = bookmarkURL;
	}
	 */
	if ([DocumentViewControllerManager activateExistingSceneWithURLIfOpen:documentURL])
	{
		return;
	}
	
	[documentURL startAccessingSecurityScopedResource];
	[self revealDocumentAtURL:documentURL importIfNeeded:NO completion:^(NSURL * _Nullable revealedDocumentURL, NSError * _Nullable error) {
		[documentURL stopAccessingSecurityScopedResource];
		if (error) {
			// Handle the error appropriately
			NSLog(@"Failed to reveal the document at URL %@ with error: '%@'", documentURL, error);
			return;
		}
		// Present the Document View Controller for the revealed URL
		[self presentDocumentAtURL:documentURL];
	}];
}


-(void) cleanUp
{
	if (visibleDocVC)
	{
		[visibleDocVC dismissViewControllerAnimated:NO completion:nil];
		self.view.window.windowScene.userActivity = nil;
	}
	
	// This is really another stupid hack -- but it seems only one scene is allowed to have the
	// the Doc Browser on top at any time.
	// Reusing this scene will not work for some weird reason, so to avoid
	// problems put another dumb VC on top of this one
	[self presentViewController:[[UIViewController alloc] init] animated:NO completion:nil];
}


// ----------------------------------------------------------------------------------------
//
#pragma mark UIDocumentBrowserViewControllerDelegate
//

- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didRequestDocumentCreationWithHandler:(void (^)(NSURL * _Nullable, UIDocumentBrowserImportMode))importHandler
{
    NSURL *newDocumentURL = nil;
    // Set the URL for the new document here. Optionally, you can present a template chooser before calling the importHandler.
    // Make sure the importHandler is always called, even if the user cancels the creation request.
    if (newDocumentURL != nil) {
        importHandler(newDocumentURL, UIDocumentBrowserImportModeMove);
    } else {
        importHandler(newDocumentURL, UIDocumentBrowserImportModeNone);
    }
}


-(void)documentBrowser:(UIDocumentBrowserViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)documentURLs
{
    NSURL *sourceURL = documentURLs.firstObject;
    if (!sourceURL) {
        return;
    }
    
    // Present the Document View Controller for the first document that was picked.
    // If you support picking multiple items, make sure you handle them all.
	if (![DocumentViewControllerManager activateExistingSceneWithURLIfOpen:sourceURL])
	{
		[self presentDocumentAtURL:sourceURL];
	}
}


- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didImportDocumentAtURL:(NSURL *)sourceURL toDestinationURL:(NSURL *)destinationURL
{
    [self presentDocumentAtURL:destinationURL];
}


- (void)documentBrowser:(UIDocumentBrowserViewController *)controller failedToImportDocumentAtURL:(NSURL *)documentURL error:(NSError * _Nullable)error
{
	NSLog(@"Failed to import document: %@", [error description]);
}



@end
