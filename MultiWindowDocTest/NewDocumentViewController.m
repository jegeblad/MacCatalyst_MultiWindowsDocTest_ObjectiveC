//
//  NewDocumentViewController.m
//  MultiWindowDocTest
//
//  Created by Jens Egeblad on 29/05/2021.
//

#import "NewDocumentViewController.h"

@interface NewDocumentViewController ()

@end

@implementation NewDocumentViewController


-(void) viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	self.view.window.windowScene.title = @"New Document";
#if TARGET_OS_MACCATALYST
	self.view.window.windowScene.titlebar.representedURL = nil;
#endif
}


-(IBAction) onGo
{
	NSURL * tempURL = [self createNewFile];
	[self dismissViewControllerAnimated:YES completion:^()
	{
		self.completionBlock(tempURL, YES);
	}];
}


-(IBAction) onCancel
{
	[self dismissViewControllerAnimated:YES completion:^()
	{
		self.completionBlock(nil, NO);
	}];
}


-(NSURL *) createNewFile
{
	return [[self class] createNewTempFile];
}


+(NSURL*) createNewTempFile
{
	// Create some temp file and return an URL to it
	NSFileManager * fMan = [NSFileManager defaultManager];
	NSString * tempFold = NSTemporaryDirectory();
	NSString * result = 0;
	int counter = 0;
	
	do {
		result = [tempFold stringByAppendingPathComponent:@"Untitled.txt"];
		if (counter>0)
		{
			result = [tempFold stringByAppendingPathComponent:[NSString stringWithFormat:@"Untitled - %d.txt", counter]];
		}
		counter ++;
	} while ([fMan fileExistsAtPath:result]);
	
	NSString * hello = @"Hello world...";
	[hello writeToFile:result atomically:YES encoding:NSUTF8StringEncoding error:nil];
	
	return [NSURL fileURLWithPath:result];
}


@end
