//
//  DocumentViewController.m
//  MultiWindowDocTest
//
//  Created by Jens Egeblad on 27/05/2021.
//

#import "DocumentViewController.h"
#import "Constants.h"

@interface NSWeakWrapper : NSObject
@property (weak) NSObject * wrappedObject;
@end

@implementation NSWeakWrapper
@end


@interface DocumentViewControllerManager()
{
	NSMutableArray<NSWeakWrapper*> * activeViewControllers; // list of weak references to the active view controllers
}

@end

@implementation DocumentViewControllerManager

+(DocumentViewControllerManager*) sharedManager
{
	static DocumentViewControllerManager * singletonManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{ singletonManager = [[self alloc] init]; });

	return singletonManager;
}


+(UIScene*) sceneForURL:(NSURL*) url
{
	// Go throught
	DocumentViewController * docVC = [[[self class] sharedManager] getVCForURL:url];
	if (docVC)
	{
		return docVC.view.window.windowScene;
	}
	
	return nil;
}


+ (BOOL)activateExistingSceneWithURLIfOpen:(NSURL*)url
{
	UIScene * scene = [[self class] sceneForURL:url];
	if (scene)
	{
		[[UIApplication sharedApplication] requestSceneSessionActivation:scene.session
															userActivity:scene.userActivity options:nil errorHandler:^(NSError * _Nonnull error)
		{
		}];
		return YES;
	}
	
	return NO;
}



-(id) init
{
	self = [super init];
	if (self)
	{
		activeViewControllers = [NSMutableArray arrayWithCapacity:5];
	}
	
	return self;
}


-(void) addDocumentVC:(DocumentViewController*) docVC
{
	NSWeakWrapper * wrapper = [[NSWeakWrapper alloc] init];
	wrapper.wrappedObject = docVC;
	[activeViewControllers addObject:wrapper];
}


-(DocumentViewController*) getVCForURL:(NSURL*) url
{
	// Go through list and clean up dead while we are at it
	NSMutableArray * cleanedUpArray = [NSMutableArray arrayWithCapacity:[activeViewControllers count]];
	
	NSString * urlPath = [url path];
	DocumentViewController * result = nil;
	
	for (NSWeakWrapper * wrapper in activeViewControllers)
	{
		if (wrapper.wrappedObject!=nil)
		{
			[cleanedUpArray addObject:wrapper];
			DocumentViewController * vc = ((DocumentViewController*)wrapper.wrappedObject);
			if ([[vc.document.fileURL path] isEqual:urlPath])
			{
				result = vc;
			}
		}
	}
	
	return result;
}



@end



@interface DocumentViewController()
@property IBOutlet UILabel *documentNameLabel;
@end

@implementation DocumentViewController


    
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}


-(void) viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}


- (IBAction)dismissDocumentViewController {
    [self dismissViewControllerAnimated:YES completion:^ {
        [self.document closeWithCompletionHandler:nil];
    }];
}


-(void) viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	self.documentNameLabel.text = self.document.fileURL.lastPathComponent;
	self.view.window.windowScene.title = self.documentNameLabel.text;
	self.view.window.windowScene.titlebar.representedURL = self.document.fileURL;

	[[DocumentViewControllerManager sharedManager] addDocumentVC:self];

	// Set the user activity
	NSUserActivity * userActivity = [[NSUserActivity alloc] initWithActivityType:[Constants userActivityTypeDocumentView]];
	userActivity.title =   self.document.fileURL.lastPathComponent;
	userActivity.userInfo = @{@"url":self.document.fileURL};
	userActivity.targetContentIdentifier = [NSString stringWithFormat:@"unique:%@", [self.document.fileURL path]];
	self.view.window.windowScene.userActivity = userActivity;
	NSLog(@"Viewer Setting activity: %@", self.view.window.windowScene.userActivity.activityType);
}



@end
