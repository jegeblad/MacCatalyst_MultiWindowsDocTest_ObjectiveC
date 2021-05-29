/*
	Copyright Jens Egeblad, 2021
	Feel free to reuse and modify as you please!
*/

#import "RecentDocumentHandler.h"


// Maximum number of items in the recent list
static NSInteger kRecentMaxCount = 12;
static NSString * kRecentKey = @"recents";
static NSString * bookmarkedURLSKey = @"bookmarkedurls";

@implementation RecentDocumentHandler


+(RecentDocumentHandler*) sharedHandler
{
	static RecentDocumentHandler * singletonHandler = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		singletonHandler = [[self alloc] init];
	});
	return singletonHandler;
}


-(id) init
{
	self = [super init];
	if (self)
	{
		
	}
	
	return self;
}


+(NSData*) urlToData:(NSURL*) url
{
	if (!url) { return nil; }
	
	NSError * error = nil;
	NSURLBookmarkCreationOptions options = NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess;

	return [url bookmarkDataWithOptions:options includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
}


+(NSURL*) dataToURL:(NSData*) bookmarkData
{
	if (!bookmarkData) { return nil; }

	NSError * error = nil;
	NSURL * url = [NSURL URLByResolvingBookmarkData:bookmarkData options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:&error];

	return url;
}


-(NSURL*) bookmarkedURLForURL:(NSURL*) url
{
	NSDictionary * dictionary = [[NSUserDefaults standardUserDefaults] objectForKey:bookmarkedURLSKey];
	NSURL * bookmarkURL = [[self class] dataToURL:[dictionary objectForKey:[url path]]];
	if (bookmarkURL)
	{
		return bookmarkURL;
	}
	
	return url;
}


-(void) addBookmarkedURLForURL:(NSURL*) url
{
	NSDictionary * oldDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:bookmarkedURLSKey];
	NSMutableDictionary * newDictionary = [[NSMutableDictionary alloc] initWithDictionary:oldDictionary];
	NSData * data = [[self class] urlToData:url];
	if (data)
	{
		[newDictionary setObject:data forKey:[url path]];
		[[NSUserDefaults standardUserDefaults] setObject:newDictionary forKey:bookmarkedURLSKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}


-(void) addURLForRecent:(NSURL *)urlToAdd
{
	NSMutableArray * newRecents = [NSMutableArray arrayWithCapacity:kRecentMaxCount];
	NSArray * oldRecents = [[NSUserDefaults standardUserDefaults] objectForKey:kRecentKey];

	NSURLBookmarkCreationOptions options = NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess;
	NSData * newData = [urlToAdd bookmarkDataWithOptions:options includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
	if (!newData)
	{
		return; // Not sure if this can happen
	}

	// Copy from old list if any
	if (oldRecents)
	{
		// Filter out old URL
		BOOL containsURL = [oldRecents containsObject:urlToAdd];
		NSString * urlToAddPath = [urlToAdd path];
		
		NSInteger startIdx = [oldRecents count]-kRecentMaxCount+1;// we copy over kRecentMaxCount-1 URLs
		if (containsURL)
		{
			startIdx-=1; // move back to allow for skip
		}
		for (NSInteger idx=MAX(0,startIdx); idx < [oldRecents count]; ++idx)
		{
			NSData * bookmarkData = [oldRecents objectAtIndex:idx];
			NSURL * url = [[self class] dataToURL:bookmarkData];
			if (url && ![[url path] isEqual:urlToAddPath]) { [newRecents addObject:bookmarkData]; }
		}
	}
	
	[newRecents addObject:newData];
	[[NSUserDefaults standardUserDefaults] setObject:newRecents forKey:kRecentKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


-(NSArray*) recentURLs
{
	NSArray * oldRecentsURLDatas = [[NSUserDefaults standardUserDefaults] objectForKey:kRecentKey];
	return [oldRecentsURLDatas count]>0?oldRecentsURLDatas:nil;
}


-(void) clearRecentURLs
{
	[[NSUserDefaults standardUserDefaults] setObject:@[] forKey:kRecentKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
