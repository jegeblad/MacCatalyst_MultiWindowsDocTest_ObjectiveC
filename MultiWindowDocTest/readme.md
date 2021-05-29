### Mac catalyst experiments with multiple windows and UIDocumentBrowserController

## Introduction 

I had a lot of issues porting an Objective-C app to macOS with Mac Catalyst. Especially, when dealing with mutiple windows.

Feel free to look and reuse this code as you please. 

### Code
Objective C.

I tried to build on the sample application that Xcode generates for a "Document app", and then enabled MultipleWindows and Mac Catalyst support.



### Issues I have found

##### • Empty Windows
Apple insists that UIDocumentBrowserController should be the rootViewController of a new window. However, this seems to often 
create an extra empty window while the document browser is shown. The window disappears once the browser controller presents
a "proper" UIViewController. 

This can be fixed (hacked!) by setting the scene's maximum/minimum size restrictions to (10,10) while the doc browser is visible (thus 
the window is forced to be too small to be visible). 

Visible doc browser 

	((UIWindowScene*)self.view.window.windowScene).sizeRestrictions.maximumSize = CGSizeMake(10, 10);
	((UIWindowScene*)self.view.window.windowScene).sizeRestrictions.minimumSize = CGSizeMake(10, 10);

And before presenting the UIViewController on top of the doc browser, e.g:

	((UIWindowScene*)self.view.window.windowScene).sizeRestrictions.maximumSize = CGSizeMake(100000, 100000);
	((UIWindowScene*)self.view.window.windowScene).sizeRestrictions.minimumSize = CGSizeMake(640, 480);

##### • Presenting the first view controller

The example code from Apple presents the view controller on top of UIDocumentBrowserController, and then
opens an associated UIDocument. This doesn't seem to work on recent versions of Big Sur. The window simply flashes
as if the view controller is shown for a brief moment, and then hidden again. However, it seems to work if you
present the view controller after the document has been successfully openend. 

So instead of (this flashes):

    DocumentViewController *documentViewController = [storyBoard instantiateViewControllerWithIdentifier:@"DocumentViewController"];
	documentViewController.document = [[Document alloc] initWithFileURL:documentURL];
	documentViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:documentViewController animated:YES completion:nil];
    

And having the DocumentViewController open the document, and then present (this presents the view controller):

	DocumentViewController *documentViewController = [storyBoard instantiateViewControllerWithIdentifier:@"DocumentViewController"];
	documentViewController.document = [[Document alloc] initWithFileURL:documentURL];
	documentViewController.modalPresentationStyle = UIModalPresentationFullScreen;
	[documentViewController.document openWithCompletionHandler:^(BOOL success)
	{
		if (success)
		{
			[self presentViewController:documentViewController animated:YES completion:nil];
		}
		else
		{
			NSLog(@"I couldn't open doc url %@", documentURL);
		}
	}];


##### • Recent Menu

UIKit seems to fill out the recent menu with whatever is opened with a UIDocument. However, when you try
open a recent document from the automatic menu, it will call **scene:(UIScene *)scene openURLContexts:**.
This is great, and we can handle it like:

    - (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
    {
    	UIOpenURLContext * urlContext = [URLContexts anyObject];
    	UIWindow * window = [((UIWindowScene*)scene).windows objectAtIndex:0];
    	DocumentBrowserViewController * docBrowser = (DocumentBrowserViewController*)window.rootViewController;
    	[docBrowser tryToRevealAndOpenDocumentAtURL:urlContext.URL];
    }

However, sand-boxing will not allow us to open that URL. To handle that, you need to save/restore security scoped URL bookmarks.
You need to enable these by adding: 
    
    com.apple.security.files.bookmarks.app-scope      Boolean    1
    
to your .entitlments file.

If **documentUrl** is a bookmarked URL you can now need to call **[documentURL startAccessingSecurityScopedResource]** and 
**[documentURL stopAccessingSecurityScopedResource]** around access (including document browser reveal). So the 
**tryToRevealAndOpenDocumentAtURL** method looks like this:

    - (void)tryToRevealAndOpenDocumentAtURL:(NSURL *)documentURL
    {
    	[documentURL startAccessingSecurityScopedResource]; // <- START HERE
    	[self revealDocumentAtURL:documentURL importIfNeeded:NO completion:^(NSURL * _Nullable revealedDocumentURL, NSError * _Nullable error) {
    		[documentURL stopAccessingSecurityScopedResource]; // <- STOP HERE AGAIN
    		if (error) {
    			// Handle the error appropriately
    			NSLog(@"Failed to reveal the document at URL %@ with error: '%@'", documentURL, error);
    			return;
    		}
		
    		// Present the Document View Controller for the revealed URL
        	UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        	DocumentViewController *documentViewController = [storyBoard instantiateViewControllerWithIdentifier:@"DocumentViewController"];
        	
            [documentURL startAccessingSecurityScopedResource]; // <- START HERE AGAIN
        	documentViewController.document = [[Document alloc] initWithFileURL:documentURL];
        	documentViewController.modalPresentationStyle = UIModalPresentationFullScreen;
            
            // We have to present af document opened successfully
            [documentViewController.document openWithCompletionHandler:^(BOOL success)
        	{
        		[documentURL stopAccessingSecurityScopedResource]; // <- STOP HERE AGAIN
        		if (success)
        		{
        			[self presentViewController:documentViewController animated:YES completion:nil];
        		}
        		else
        		{
        			NSLog(@"I couldn't open doc url %@", documentURL);
        		}
        	}];
    	}];
    }

To handle this, you can store a bookmarked URL in **NSUserDefaults** e.g. whenever you open a document, and the restore later.

I implemented a "cache" of bookmarked URLs in **RecentDocumentHandler** that uses **NSUserDefaults**.

##### • Recent Menu - Part 2
The recent menu is filled up with anything being opened by a UIDocument. This isn't ideal, because we may use UIDocument to 
access items that are not supposed to be visible in the recent menu (as UIDocument handles file coordination).

##### • Reactivating the Document Browser
When the user clicks on "Open ...", it would be ideal if the document browser pops to the top of the visible windows. Reactivating the scene 
like this: 

    -(void) popDocumentBrowserToTop
    {
    	[[UIApplication sharedApplication] requestSceneSessionActivation:activeDocBrowserScene.session
    														userActivity:nil options:nil errorHandler:^(NSError * _Nonnull error)
    	{}];
    }
    
Doesn't work. 

However, If we place a view controller on top of the doc browser momentarily, reactivating the scene does make
it pop to the front of the visible windows: 

    -(void) popDocumentBrowserToTop
    {
		UIViewController * vc = [[UIViewController alloc] init];
        // present dummy VC
		[[currentActive.windows objectAtIndex:0].rootViewController presentViewController:vc animated:NO completion:^()
        {
             // activate the scene now will move it to the top of windows
			[[UIApplication sharedApplication] requestSceneSessionActivation:activeDocBrowserScene.session userActivity:nil options:nil errorHandler:nil];
             // remove the dummy VC again -- We no longer need it.
			[vc dismissViewControllerAnimated:NO completion:nil];
		}];
    }

In generally, lots of things break surrounding document browser. In general, dstoying a session where the document browser is visible seem to break the document browser the next time it is presented.
