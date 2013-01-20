#import "SCKProject.h"
#import "SCKSourceFile.h"
#import "SCKSourceCollection.h"

@implementation SCKProject
{
	NSURL *directoryURL;
	SCKSourceCollection *sourceCollection;
	NSMutableArray *fileURLs;
	id <SCKProjectContent> projectContent;
}

@synthesize directoryURL, fileURLs;
@synthesize sourceCollection;

- (id)init
{
    self = [super init];
    if (self)
    {
        directoryURL = nil;
        sourceCollection = [[SCKSourceCollection alloc] init];
        fileURLs = [[NSMutableArray alloc] init];
        projectContent = [[SCKFileBrowsingProjectContent alloc] init];
    }
    return self;
}

- (id) initWithDirectoryURL:(NSURL *)aURL
           sourceCollection:(SCKSourceCollection *)aSourceCollection;
{
	NSAssert(aSourceCollection != nil, @"Collection must not be nil");
	self = [super init];
    if (self)
    {
        directoryURL = aURL;
        sourceCollection = aSourceCollection;
        fileURLs = [NSMutableArray new];
        projectContent = [SCKFileBrowsingProjectContent new];
    }
	return self;
}

- (void)addFileURL:(NSURL *)aURL
{
    if (aURL == nil)
    {
        return;
    }
    
	if ([fileURLs containsObject:aURL])
		return;

	[fileURLs addObject: aURL];
}

- (void)removeFileURL:(NSURL *)aURL
{
    if (aURL == nil)
    {
        return;
    }
    
	[fileURLs removeObject:aURL];
}

- (NSArray *)files
{
	NSMutableArray *files = [NSMutableArray new];

	for (NSURL *url in fileURLs)
	{
		NSString *resolvedFilePath = (directoryURL == nil ? [url path] : [[directoryURL path] stringByAppendingPathComponent:[url relativePath]]);
		SCKSourceFile *file = [sourceCollection sourceFileForPath:[resolvedFilePath stringByStandardizingPath]];

		[files addObject: file];
	}
	return files;
}

- (NSArray *)programComponentsForKey:(NSString *)key
{
	// NOTE: We could write...
	//NSDictionary *componentsByName = [[[self files] mappedCollection] valueForKey: key];
	//return [[[componentsByName mappedCollection] allValues] flattenedCollection];

	NSMutableArray *components = [NSMutableArray new];
	for (SCKSourceFile *file in [self files])
	{
		[components addObjectsFromArray:[[file valueForKey:key] allValues]];
	}
	return components;
}

- (NSArray *)classes
{
	return [self programComponentsForKey:@"classes"];
}

- (NSArray *)functions
{
	return [self programComponentsForKey:@"functions"];
}

- (NSArray *)globals
{
	return [self programComponentsForKey:@"globals"];
}

- (void)setContentClass: (Class)aClass
{
	NSAssert([aClass conformsToProtocol:@protocol(SCKProjectContent)], @"Content class must conform to SCKProjectContent protocol");
	projectContent = [aClass new];
}

- (Class)contentClass
{
	return [projectContent class];
}

- (id)content
{
	return [projectContent content];
}

@end

@implementation SCKFileBrowsingProjectContent

- (id)content
{
    return nil;
}

@end