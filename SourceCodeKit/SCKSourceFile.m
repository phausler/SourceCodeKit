#import "SCKSourceFile.h"
#import <Cocoa/Cocoa.h>
#import "SCKTextTypes.h"


@implementation SCKSourceFile

@synthesize fileName, source, collection;

- (void)subclassResponsibility:(SEL)aSelector
{
    NSLog(@"%@ must implement %s", [self class], sel_getName(aSelector));
}

- (id)initUsingIndex:(SCKIndex *)anIndex
{
    [self subclassResponsibility:_cmd];
    self = nil;
	return nil;
}

+ (SCKSourceFile*)fileUsingIndex:(SCKIndex *)anIndex
{
	return [[self alloc] initUsingIndex: (SCKIndex*)anIndex];
}

- (void)reparse
{
    [self subclassResponsibility:_cmd];
}

- (void)lexicalHighlightFile
{
    [self subclassResponsibility:_cmd];
}

- (void)syntaxHighlightFile
{
    [self subclassResponsibility:_cmd];
}

- (void)syntaxHighlightRange:(NSRange)r
{
    [self subclassResponsibility:_cmd];
}

- (void)addIncludePath:(NSString *)includePath
{
    [self subclassResponsibility:_cmd];
}

- (void)collectDiagnostics
{
    [self subclassResponsibility:_cmd];
}

- (SCKCodeCompletionResult*)completeAtLocation:(NSUInteger)location
{
    [self subclassResponsibility:_cmd];
    return nil;
}

@end

