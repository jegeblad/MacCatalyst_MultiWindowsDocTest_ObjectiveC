//
//  NewDocumentViewController.h
//  MultiWindowDocTest
//
//  Created by Jens Egeblad on 29/05/2021.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^CompletionBlock)(NSURL * _Nullable dummyURL, BOOL success);


@interface NewDocumentViewController : UIViewController

@property CompletionBlock completionBlock; // When user presses Go or Cancel we call this block
 
+(NSURL*) createNewTempFile;

-(IBAction) onGo;
-(IBAction) onCancel;

@end

NS_ASSUME_NONNULL_END
