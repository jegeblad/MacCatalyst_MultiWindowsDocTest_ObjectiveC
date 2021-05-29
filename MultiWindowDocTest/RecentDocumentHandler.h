/*
	Copyright Jens Egeblad, 2021
    Feel free to reuse and modify as you please!
*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RecentDocumentHandler : NSObject

+(RecentDocumentHandler*) sharedHandler;

-(id) init;

// Convert URL to bookmark NSData
+(NSData*) urlToData:(NSURL*) url;

// Convert bookmark NSData to URL
+(NSURL*) dataToURL:(NSData*) bookmarkData;

// Looks for a URL in the bookmarked URLs and returns the bookmarked version if possible (or the URL itself if no bookmarked version)
-(NSURL*) bookmarkedURLForURL:(NSURL*) url;

// Adds a bookmarkedURL to separate list of URLs (not recents)
-(void) addBookmarkedURLForURL:(NSURL*) url;

// Save a recent URL as bookmarked data in user defaults
-(void) addURLForRecent:(NSURL*) url;

// Returns array of recent URLs as bookmarkeddatas from user defaults
-(NSArray*) recentURLs;

// Clear list of recent URLS
-(void) clearRecentURLs;

@end

NS_ASSUME_NONNULL_END
