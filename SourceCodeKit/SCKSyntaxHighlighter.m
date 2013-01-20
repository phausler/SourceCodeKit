#import "SCKSyntaxHighlighter.h"
#import <Cocoa/Cocoa.h>
#import "SCKTextTypes.h"
#include <time.h>

static NSDictionary *noAttributes;

@implementation SCKSyntaxHighlighter

@synthesize tokenAttributes, semanticAttributes;

+ (void)initialize
{
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        noAttributes = [NSDictionary dictionary];
    });
}

- (id)init
{
	self = [super init];
	NSDictionary *comment = @{NSForegroundColorAttributeName: [NSColor grayColor]};
	NSDictionary *keyword = @{NSForegroundColorAttributeName: [NSColor redColor]};
	NSDictionary *literal = @{NSForegroundColorAttributeName: [NSColor redColor]};
	tokenAttributes = [@{
                       SCKTextTokenTypeComment: comment,
                       SCKTextTokenTypePunctuation: noAttributes,
                       SCKTextTokenTypeKeyword: keyword,
                       SCKTextTokenTypeLiteral: literal}
                       mutableCopy];

	semanticAttributes = [@{
                          SCKTextTypeDeclRef: @{NSForegroundColorAttributeName: [NSColor blueColor]},
                          SCKTextTypeMessageSend: @{NSForegroundColorAttributeName: [NSColor brownColor]},
                          SCKTextTypeDeclaration: @{NSForegroundColorAttributeName: [NSColor greenColor]},
                          SCKTextTypeMacroInstantiation: @{NSForegroundColorAttributeName: [NSColor magentaColor]},
                          SCKTextTypeMacroDefinition: @{NSForegroundColorAttributeName: [NSColor magentaColor]},
                          SCKTextTypePreprocessorDirective: @{NSForegroundColorAttributeName: [NSColor orangeColor]},
                          SCKTextTypeReference: @{NSForegroundColorAttributeName: [NSColor purpleColor]}}
                          mutableCopy];
	return self;
}

- (void)transformString:(NSMutableAttributedString *)source;
{
	NSUInteger end = [source length];
	NSUInteger i = 0;
	NSRange r;
	do
	{
		NSDictionary *attrs = [source attributesAtIndex:i
		                          longestEffectiveRange:&r
		                                        inRange:NSMakeRange(i, end-i)];
		i = r.location + r.length;
        
		NSString *token = [attrs objectForKey:kSCKTextTokenType];
		NSString *semantic = [attrs objectForKey:kSCKTextSemanticType];
		NSDictionary *diagnostic = [attrs objectForKey:kSCKDiagnostic];
        
		// Skip ranges that have attributes other than semantic markup
		if ((nil == semantic) && (nil == token)) continue;
		if (semantic == SCKTextTypePreprocessorDirective)
		{
			attrs = [semanticAttributes objectForKey: semantic];
		}
		else if (token == nil || token != SCKTextTokenTypeIdentifier)
		{
			attrs = [tokenAttributes objectForKey: token];
		}
		else
		{
			NSString *semantic = [attrs objectForKey:kSCKTextSemanticType];
			attrs = [semanticAttributes objectForKey:semantic];
		}
        
		if (nil == attrs)
		{
			attrs = noAttributes;
		}
        
		[source setAttributes:attrs range:r];
        
		// Re-apply the diagnostic
		if (nil != diagnostic)
		{
			[source addAttribute:NSToolTipAttributeName
			               value:[diagnostic objectForKey: kSCKDiagnosticText]
			               range:r];
			[source addAttribute:NSUnderlineStyleAttributeName
                           value:[NSNumber numberWithInt: NSSingleUnderlineStyle]
                           range:r];
			[source addAttribute:NSUnderlineColorAttributeName
			               value:[NSColor redColor]
			               range:r];
		}
	} while (i < end);
}

@end

