//
//  Document.m
//  MultiWindowDocTest
//
//  Created by Jens Egeblad on 27/05/2021.
//

#import "Document.h"

@implementation Document
    
- (id)contentsForType:(NSString*)typeName error:(NSError **)errorPtr {
    // Encode your document with an instance of NSData or NSFileWrapper
	*errorPtr = nil;
    return [[NSData alloc] init];
}
    
- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)errorPtr {
    // Load your document from contents
	*errorPtr = nil;
    return YES;
}

@end
