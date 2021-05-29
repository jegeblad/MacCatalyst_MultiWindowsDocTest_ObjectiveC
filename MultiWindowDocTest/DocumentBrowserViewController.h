//
//  DocumentBrowserViewController.h
//  MultiWindowDocTest
//
//  Created by Jens Egeblad on 27/05/2021.
//

#import <UIKit/UIKit.h>

@interface DocumentBrowserViewController : UIDocumentBrowserViewController

- (void)presentDocumentAtURL:(NSURL *)documentURL;
- (void)tryToRevealAndOpenDocumentAtURL:(NSURL *)documentURL;

+(UIWindowScene*) activeScene;
+(void) setActiveScene:(UIWindowScene*) scene;

-(void) cleanUp;

@end
