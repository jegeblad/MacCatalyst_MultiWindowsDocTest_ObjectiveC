//
//  DocumentBrowserViewController.m
//  MultiWindowDocTest
//
//  Created by Jens Egeblad on 27/05/2021.
//

#import "DocumentBrowserViewController.h"
#import "Document.h"
#import "DocumentViewController.h"
#import "NewDocumentViewController.h"
#import "RecentDocumentHandler.h"
#import "Constants.h"

static __weak UIWindowScene* activeOnScene = nil; // Keep track of which scene holds a visible DocumentBrowserController. That way, we can reactivate this scene when the user clicks "Open ..."


@interface DocumentBrowserViewController () <UIDocumentBrowserViewControllerDelegate>
{
	__weak DocumentViewController * visibleDocVC; // <- Keep track of the visible document VC, so that we can drop it on clean up
	BOOL ignoreImportError;
}

@end


@implementation DocumentBrowserViewController

-(id) initForOpeningContentTypes:(nullable NSArray<UTType*> *) contentTypes
{
	self = [super initForOpeningContentTypes:contentTypes];
	if (self)
	{
		self.createNewDocumentOnAppear = NO;
		ignoreImportError = NO;
	}
	
	return self;
}


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
	if (self.createNewDocumentOnAppear)
	{
		[self createNewDocumentDirect];
		self.createNewDocumentOnAppear = NO;
	}
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


-(void)revealAndImport:(NSURL*) dummyURL
{
	// These seems to force a enter filename dialog
	ignoreImportError = YES; // Don't show multiple alerts
	[self revealDocumentAtURL:dummyURL importIfNeeded:YES completion:^(NSURL * _Nullable revealedDocumentURL, NSError * _Nullable error) {
		self->ignoreImportError = NO;
		if (error) {
			// Handle the error appropriately
			[self revealAndImport:dummyURL];
			UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"Unable to use that filename"
												message:[NSString stringWithFormat:@"Please enter a different filename"]
										 preferredStyle:UIAlertControllerStyleAlert];
			[alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
			{
				// When the user clicks OK -> Destroy this scene session to close the window.
		//		[[UIApplication sharedApplication] requestSceneSessionDestruction:scene.session options:nil errorHandler:nil];
			}]];
			[self presentViewController:alertController animated:YES completion:nil];
			return;
		}
		[self presentDocumentAtURL:revealedDocumentURL];
	}];
}


- (void)createNewDocumentDirect
{
	UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	NewDocumentViewController * newDocVC = [storyBoard instantiateViewControllerWithIdentifier:@"NewDocumentViewController"];
	newDocVC.modalPresentationStyle = UIModalPresentationFormSheet;
	newDocVC.completionBlock = ^(NSURL * dummyURL, BOOL success)
	{
		if (success)
		{
			[self revealAndImport:dummyURL];
		}
		else
		{
			// cancelled
		}
	};

	[self removeArtificialSizeRestrictions];
	[self presentViewController:newDocVC animated:YES completion:nil];
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
	UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	NewDocumentViewController * newDocVC = [storyBoard instantiateViewControllerWithIdentifier:@"NewDocumentViewController"];
	newDocVC.modalPresentationStyle = UIModalPresentationFormSheet;
	newDocVC.completionBlock = ^(NSURL * dummyURL, BOOL success)
	{
		if (success)
		{
			importHandler(dummyURL, UIDocumentBrowserImportModeMove);
		}
		else
		{
			// cancelled
			importHandler(dummyURL, UIDocumentBrowserImportModeNone);
		}
	};

	[self removeArtificialSizeRestrictions];
	[self presentViewController:newDocVC animated:YES completion:nil];
	
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
	if (ignoreImportError)
	{
		return;
	}
	// We don't know what the error is here so just display something generic and unhelpful as "try again later....".
	UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"Unable to open document"
										message:[NSString stringWithFormat:@"Unable to open document at %@:\n\n%@", [documentURL path], [error description]]
								 preferredStyle:UIAlertControllerStyleAlert];
	[alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
	{
		// When the user clicks OK -> Destroy this scene session to close the window.
//		[[UIApplication sharedApplication] requestSceneSessionDestruction:scene.session options:nil errorHandler:nil];
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}



@end
