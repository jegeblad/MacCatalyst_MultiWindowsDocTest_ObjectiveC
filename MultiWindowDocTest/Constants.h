#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* Some shared constants */
@interface Constants : NSObject

+(NSString*) userActivityTypeDocumentView;
+(NSString*) userActivityTypeOpenRecentDocument;
+(NSString*) userActivityTypeDocumentBrowser;
+(NSString*) userActivityTypeNewDocument;

+(NSString*) keyURLData;

@end

NS_ASSUME_NONNULL_END
