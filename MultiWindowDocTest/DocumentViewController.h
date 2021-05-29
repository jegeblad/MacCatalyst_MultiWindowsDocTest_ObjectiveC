//
//  DocumentViewController.h
//  MultiWindowDocTest
//
//  Created by Jens Egeblad on 27/05/2021.
//

#import <UIKit/UIKit.h>

// Manage the visibile doc view controllers
@interface DocumentViewControllerManager : NSObject

// Returns the scene that displays this url
+(UIScene*) sceneForURL:(NSURL*) url;

// Attempt to activate the scene displaying this URL (returns true if we have a scene with the URL)
+(BOOL)activateExistingSceneWithURLIfOpen:(NSURL*)url;

@end


// The actual view controller for displaying a document
@interface DocumentViewController : UIViewController

@property (strong) UIDocument *document;

@end
