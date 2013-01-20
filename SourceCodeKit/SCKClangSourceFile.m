#import "SCKClangSourceFile.h"
#import "SourceCodeKit.h"
#import <Cocoa/Cocoa.h>
#include <time.h>

//#define NSLog(...)

/**
 * Converts a clang source range into an NSRange within its enclosing file.
 */
NSRange NSRangeFromCXSourceRange(CXSourceRange sr)
{
	unsigned start, end;
	CXSourceLocation s = clang_getRangeStart(sr);
	CXSourceLocation e = clang_getRangeEnd(sr);
	clang_getInstantiationLocation(s, 0, 0, 0, &start);
	clang_getInstantiationLocation(e, 0, 0, 0, &end);
	if (end < start)
	{
		return NSMakeRange(end, start-end);
	}
	return NSMakeRange(start, end - start);
}

static void freestring(CXString *str)
{
	clang_disposeString(*str);
}

#define SCOPED_STR(name, value)\
	__attribute__((unused))\
	__attribute__((cleanup(freestring))) CXString name ## str = value;\
	const char *name = clang_getCString(name ## str);

@implementation SCKSourceLocation

@synthesize file;
@synthesize offset;

- (id)initWithClangSourceLocation:(CXSourceLocation)l
{
	self = [super init];
    if (self)
    {
        CXFile f;
        unsigned o;
        clang_getInstantiationLocation(l, &f, 0, 0, &o);
        offset = o;
        SCOPED_STR(fileName, clang_getFileName(f));
        file = [[NSString alloc] initWithUTF8String:fileName];
    }
	return self;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@:%d", file, (int)offset];
}

- (NSUInteger)hash
{
    return [file hash] ^ offset;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
    {
        return YES;
    }
    
    if (![object isKindOfClass:[SCKSourceLocation class]])
    {
        return NO;
    }
    
    if ([file isEqualToString:[(SCKSourceLocation *)object file]] && offset == [(SCKSourceLocation *)object offset])
    {
        return YES;
    }
    
    return NO;
}

@end


@interface SCKClangIndex : NSObject
@property (readonly) CXIndex clangIndex;
//FIXME: We should have different default arguments for C, C++ and ObjC.
@property ( nonatomic) NSMutableArray *defaultArguments;
@end

@implementation SCKClangIndex

@synthesize clangIndex, defaultArguments;

- (id)init
{
	self = [super init];
    if (self)
    {
        clang_toggleCrashRecovery(0);
        clangIndex = clang_createIndex(1, 1);
        
        /*
         * NOTE: If BuildKit becomes usable, it might be sensible to store these
         * defaults in the BuildKit configuration and let BuildKit generate the
         * command line switches for us.
         */
        NSString *plistPath = [[NSBundle bundleForClass:[SCKClangIndex class]] pathForResource:@"DefaultArguments" ofType:@"plist"];
        
        NSData *plistData = [NSData dataWithContentsOfFile:plistPath];
        
        // Load the options required to compile GNUstep apps
        defaultArguments = [(NSArray*)[NSPropertyListSerialization propertyListFromData:plistData
                                                                       mutabilityOption:NSPropertyListImmutable
                                                                                 format:NULL
                                                                       errorDescription:NULL] mutableCopy];
    }
	

	return self;
}

- (void)dealloc
{
	clang_disposeIndex(clangIndex);
}

@end

@interface SCKClangSourceFile ()
- (void)highlightRange:(CXSourceRange)r syntax:(BOOL)highightSyntax;
@end

@implementation SCKClangSourceFile {
	/** Compiler arguments */
	NSMutableArray *args;
	/** Index shared between code files */
	SCKClangIndex *idx;
	/** libclang translation unit handle. */
	CXTranslationUnit translationUnit;
	CXFile file;
}

@synthesize classes, functions, globals, enumerations, enumerationValues;

static NSString *classNameFromCategory(CXCursor category)
{
	__block NSString *className = nil;
	clang_visitChildrenWithBlock(category, ^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent) {
        if (CXCursor_ObjCClassRef == cursor.kind)
        {
            SCOPED_STR(name, clang_getCursorSpelling(cursor));
            className = [NSString stringWithUTF8String:name];
            return CXChildVisit_Break;
        }
        return CXChildVisit_Continue;
    });
	return className;
}

- (void)setLocation:(SCKSourceLocation *)aLocation
          forMethod:(NSString *)methodName
            inClass:(NSString *)className
           category:(NSString *)categoryName
       isDefinition:(BOOL)isDefinition
{
	SCKClass *cls = [classes objectForKey:className];
	if (nil == cls)
	{
		cls = [SCKClass new];
		cls.name = className;
		[classes setObject:cls forKey:className];
	}
    
	NSMutableDictionary *methods = cls.methods;
	if (nil != categoryName)
	{
		SCKCategory *cat = [cls.categories objectForKey:categoryName];
		if (nil == cat)
		{
			cat = [SCKCategory new];
			cat.name = categoryName;
			cat.parent = cls;
			[cls.categories setObject:cat forKey:categoryName];
		}
		methods = cat.methods;
	}
    
	SCKMethod *m = [methods objectForKey:methodName];
	if (isDefinition)
	{
		m.definition = aLocation;
	}
	else
	{
		m.declaration = aLocation;
	}
}
- (void)setLocation:(SCKSourceLocation *)l
          forGlobal:(const char *)name
           withType:(const char *)type
         isFunction:(BOOL)isFunction
       isDefinition:(BOOL)isDefinition
{
	NSMutableDictionary *dict = isFunction ? functions : globals;
	NSString *symbol = [NSString stringWithUTF8String:name];

	SCKTypedProgramComponent *global = [dict objectForKey:symbol];
	SCKTypedProgramComponent *g = nil;
	if (nil == global)
	{
		g = isFunction ? [SCKFunction new] : [SCKGlobal new];
		global = g;
		global.name = symbol;
		[global setTypeEncoding:[NSString stringWithUTF8String:type]];
	}
    
	if (isDefinition)
	{
		global.definition = l;
	}
	else
	{
		global.declaration = l;
	}

	[dict setObject:global forKey:symbol];
}

- (void)rebuildIndex
{
	if (0 == translationUnit)
    {
        return;
    }
    
	clang_visitChildrenWithBlock(clang_getTranslationUnitCursor(translationUnit), ^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent) {
        switch(cursor.kind)
        {
            default:
                break;
            case CXCursor_ObjCImplementationDecl: {
                clang_visitChildrenWithBlock(clang_getTranslationUnitCursor(translationUnit), ^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent) {
                    if (CXCursor_ObjCInstanceMethodDecl == cursor.kind)
                    {
                        SCOPED_STR(methodName, clang_getCursorSpelling(cursor));
                        SCOPED_STR(className, clang_getCursorSpelling(parent));
                        //clang_visitChildren((parent), findClass, NULL);
                        SCKSourceLocation *l = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(cursor)];
                        [self setLocation:l
                                forMethod:[NSString stringWithUTF8String:methodName]
                                  inClass:[NSString stringWithUTF8String:className]
                                 category:nil
                             isDefinition:clang_isCursorDefinition(cursor)];
                    }
                    return CXChildVisit_Continue;
                });
                break;
            }
            case CXCursor_ObjCCategoryImplDecl: {
                clang_visitChildrenWithBlock(clang_getTranslationUnitCursor(translationUnit), ^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent) {
                    if (CXCursor_ObjCInstanceMethodDecl == cursor.kind)
                    {
                        SCOPED_STR(methodName, clang_getCursorSpelling(cursor));
                        SCOPED_STR(categoryName, clang_getCursorSpelling(parent));
                        NSString *className = classNameFromCategory(parent);
                        SCKSourceLocation *l = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(cursor)];
                        [self setLocation:l
                                forMethod:[NSString stringWithUTF8String:methodName]
                                  inClass:className
                                 category:[NSString stringWithUTF8String:categoryName]
                             isDefinition:clang_isCursorDefinition(cursor)];
                    }
                    return CXChildVisit_Continue;
                });
                break;
            }
            case CXCursor_FunctionDecl:
            case CXCursor_VarDecl: {
                if (clang_getCursorLinkage(cursor) == CXLinkage_External)
                {
                    SCOPED_STR(name, clang_getCursorSpelling(cursor));
                    SCOPED_STR(type, clang_getDeclObjCTypeEncoding(cursor));
                    SCKSourceLocation *l = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(cursor)];
                    [self setLocation:l
                            forGlobal:name
                             withType:type
                           isFunction:(cursor.kind == CXCursor_FunctionDecl)
                         isDefinition:clang_isCursorDefinition(cursor)];
                }
                break;
            }
            case CXCursor_EnumDecl: {
                SCOPED_STR(enumName, clang_getCursorSpelling(cursor));
                SCOPED_STR(type, clang_getDeclObjCTypeEncoding(cursor));
                NSString *name = [NSString stringWithUTF8String:enumName];
                SCKEnumeration *e = [enumerations objectForKey:name];
                
                __block BOOL foundType;
                if (e == nil)
                {
                    e = [SCKEnumeration new];
                    foundType = NO;
                    e.name = name;
                    e.declaration = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(cursor)];
                }
                else
                {
                    foundType = e.typeEncoding != nil;
                }
                
                clang_visitChildrenWithBlock(cursor, ^ enum CXChildVisitResult (CXCursor enumCursor, CXCursor parent) {
                    if (enumCursor.kind == CXCursor_EnumConstantDecl)
                    {
                        if (!foundType)
                        {
                            SCOPED_STR(type, clang_getDeclObjCTypeEncoding(enumCursor));
                            foundType = YES;
                            e.typeEncoding = [NSString stringWithUTF8String:type];
                        }
                        SCOPED_STR(valName, clang_getCursorSpelling(enumCursor));
                        NSString *vName = [NSString stringWithUTF8String:valName];
                        
                        SCKEnumerationValue *v = [e.values objectForKey:vName];
                        if (nil == v)
                        {
                            v = [SCKEnumerationValue new];
                            v.name = vName;
                            v.declaration = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(enumCursor)];
                            v.longLongValue = clang_getEnumConstantDeclValue(enumCursor);
                            [e.values setObject:v forKey:vName];
                        }
                        
                        SCKEnumerationValue *ev = [enumerationValues objectForKey:vName];
                        if (ev)
                        {
                            if (ev.longLongValue != v.longLongValue)
                            {
                                [enumerationValues setObject:[NSMutableArray arrayWithObjects:v, ev, nil] forKey:vName];
                            }
                        }
                        else
                        {
                            [enumerationValues setObject:v forKey:vName];
                        }
                    }
                    return CXChildVisit_Continue;
                });
                break;
            }
        }
        return CXChildVisit_Continue;
    });
}

- (id)initUsingIndex:(SCKIndex *)anIndex
{
    self = [super init];
    if (self)
    {
        idx = (SCKClangIndex*)anIndex;
        NSAssert([idx isKindOfClass:[SCKClangIndex class]], @"Initializing SCKClangSourceFile with incorrect kind of index");
        args = [idx.defaultArguments mutableCopy];
        classes = [NSMutableDictionary new];
        functions = [NSMutableDictionary new];
        globals = [NSMutableDictionary new];
        enumerations = [NSMutableDictionary new];
        enumerationValues = [NSMutableDictionary new];
    }
	return self;
}

- (void)addIncludePath:(NSString *)includePath
{
	[args addObject:[NSString stringWithFormat:@"-I%@", includePath]];
	// After we've added an include path, we may change how the file is parsed,
	// so parse it again, if required
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
		translationUnit = NULL;
		[self reparse];
	}
}

- (void)dealloc
{
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
	}
}

- (void)reparse
{
	const char *fn = [fileName UTF8String];
	struct CXUnsavedFile unsaved[] = {
		{fn, [[source string] UTF8String], [source length]},
		{NULL, NULL, 0}
    };
    
	int unsavedCount = (source == nil) ? 0 : 1;
    
	const char *mainFile = fn;
	if ([@"h" isEqualToString:[fileName pathExtension]])
	{
		unsaved[unsavedCount].Filename = "/tmp/foo.m";
		unsaved[unsavedCount].Contents = [[NSString stringWithFormat:@"#import \"%@\"\n", fileName] UTF8String];
		unsaved[unsavedCount].Length = strlen(unsaved[unsavedCount].Contents);
		mainFile = unsaved[unsavedCount].Filename;
		unsavedCount++;
	}
    
	file = NULL;
	if (NULL == translationUnit)
	{
		int argc = (int)[args count];
		const char *argv[argc];
		int i=0;
		for (NSString *arg in args)
		{
			argv[i++] = [arg UTF8String];
		}
		translationUnit =clang_parseTranslationUnit(idx.clangIndex,
                                                    mainFile, argv, argc, unsaved,
                                                    unsavedCount,
                                                    clang_defaultEditingTranslationUnitOptions());
		file = clang_getFile(translationUnit, fn);
	}
	else
	{
		if (0 != clang_reparseTranslationUnit(translationUnit, unsavedCount, unsaved, clang_defaultReparseOptions(translationUnit)))
		{
			clang_disposeTranslationUnit(translationUnit);
			translationUnit = 0;
		}
		else
		{
			file = clang_getFile(translationUnit, fn);
		}
	}
	[self rebuildIndex];
}

- (void)lexicalHighlightFile
{
	CXSourceLocation start = clang_getLocation(translationUnit, file, 1, 1);
	CXSourceLocation end = clang_getLocationForOffset(translationUnit, file, (unsigned int)[source length]);
	[self highlightRange:clang_getRange(start, end) syntax:NO];
}

- (void)highlightRange:(CXSourceRange)r syntax:(BOOL)highightSyntax
{
	NSString *TokenTypes[] = {
        SCKTextTokenTypePunctuation,
        SCKTextTokenTypeKeyword,
		SCKTextTokenTypeIdentifier,
        SCKTextTokenTypeLiteral,
		SCKTextTokenTypeComment
    };
    
	if (clang_equalLocations(clang_getRangeStart(r), clang_getRangeEnd(r)))
	{
		NSLog(@"Range has no length!");
		return;
	}
    
	CXToken *tokens;
	unsigned tokenCount;
	clang_tokenize(translationUnit, r , &tokens, &tokenCount);

	if (tokenCount > 0)
	{
		CXCursor *cursors = NULL;
		if (highightSyntax)
		{
			cursors = calloc(sizeof(CXCursor), tokenCount);
			clang_annotateTokens(translationUnit, tokens, tokenCount, cursors);
		}
        
		for (unsigned i = 0 ; i < tokenCount ; i++)
		{
			CXSourceRange sr = clang_getTokenExtent(translationUnit, tokens[i]);
			NSRange range = NSRangeFromCXSourceRange(sr);
			if (range.location > 0)
			{
				if ([[source string] characterAtIndex:range.location - 1] == '@')
				{
					range.location--;
					range.length++;
				}
			}
            
			if (highightSyntax)
			{
				id type;
				switch (cursors[i].kind)
				{
					case CXCursor_FirstRef... CXCursor_LastRef:
						type = SCKTextTypeReference;
						break;
					case CXCursor_MacroDefinition:
						type = SCKTextTypeMacroDefinition;
						break;
					case CXCursor_MacroInstantiation:
						type = SCKTextTypeMacroInstantiation;
						break;
					case CXCursor_FirstDecl...CXCursor_LastDecl:
						type = SCKTextTypeDeclaration;
						break;
					case CXCursor_ObjCMessageExpr:
						type = SCKTextTypeMessageSend;
						break;
					case CXCursor_DeclRefExpr:
						type = SCKTextTypeDeclRef;
						break;
					case CXCursor_PreprocessingDirective:
						type = SCKTextTypePreprocessorDirective;
						break;
					default:
						type = nil;
				}
                
				if (nil != type)
				{
					[source addAttribute:kSCKTextSemanticType
								   value:type
								   range:range];
				}
			}
			[source addAttribute:kSCKTextTokenType
			               value:TokenTypes[clang_getTokenKind(tokens[i])]
			               range:range];
		}
        
		clang_disposeTokens(translationUnit, tokens, tokenCount);
		free(cursors);
	}
}

- (void)syntaxHighlightRange:(NSRange)r
{
	CXSourceLocation start = clang_getLocationForOffset(translationUnit, file, (unsigned int)r.location);
	CXSourceLocation end = clang_getLocationForOffset(translationUnit, file, (unsigned int)r.location + (unsigned int)r.length);
	[self highlightRange:clang_getRange(start, end) syntax:YES];
}

- (void)syntaxHighlightFile
{
	[self syntaxHighlightRange:NSMakeRange(0, [source length])];
}

- (void)collectDiagnostics
{
	unsigned diagnosticCount = clang_getNumDiagnostics(translationUnit);
	unsigned opts = clang_defaultDiagnosticDisplayOptions();
    
	for (unsigned i=0 ; i<diagnosticCount ; i++)
	{
		CXDiagnostic d = clang_getDiagnostic(translationUnit, i);
		unsigned s = clang_getDiagnosticSeverity(d);
		if (s > 0)
		{
			CXString str = clang_getDiagnosticSpelling(d);
			CXSourceLocation loc = clang_getDiagnosticLocation(d);
			unsigned rangeCount = clang_getDiagnosticNumRanges(d);
            
			if (rangeCount == 0) {
				//FIXME: probably somewhat redundant
				SCKSourceLocation* sloc = [[SCKSourceLocation alloc] initWithClangSourceLocation:loc];
				NSDictionary *attr = @{kSCKDiagnosticSeverity: @(s),
                                       kSCKDiagnosticText: [NSString stringWithUTF8String:clang_getCString(str)]};
                
				NSRange r = NSMakeRange(sloc->offset, 1);
                
				[source addAttribute:kSCKDiagnostic
				               value:attr
				               range:r];
			}
			for (unsigned j=0 ; j<rangeCount ; j++)
			{
				NSRange r = NSRangeFromCXSourceRange(clang_getDiagnosticRange(d, j));
				NSDictionary *attr = @{kSCKDiagnosticSeverity: @(s),
                                       kSCKDiagnosticText: [NSString stringWithUTF8String:clang_getCString(str)]};
                
				[source addAttribute:kSCKDiagnostic
				               value:attr
				               range:r];
			}
			clang_disposeString(str);
		}
	}
}

- (SCKCodeCompletionResult*)completeAtLocation:(NSUInteger)location
{
	SCKCodeCompletionResult *result = [SCKCodeCompletionResult new];

	struct CXUnsavedFile unsavedFile;
	unsavedFile.Filename = [fileName UTF8String];
	unsavedFile.Contents = [[source string] UTF8String];
	unsavedFile.Length = [[source string] length];

	CXSourceLocation l = clang_getLocationForOffset(translationUnit, file, (unsigned)location);
	unsigned line, column;
	clang_getInstantiationLocation(l, file, &line, &column, 0);
	clock_t c1 = clock();

	int options = CXCompletionContext_AnyType |
			CXCompletionContext_AnyValue |
			CXCompletionContext_ObjCInterface;

	CXCodeCompleteResults *cr = clang_codeCompleteAt(translationUnit, [fileName UTF8String], line, column, &unsavedFile, 1, options);
	clock_t c2 = clock();
	NSLog(@"Complete time: %f\n", 
	((double)c2 - (double)c1) / (double)CLOCKS_PER_SEC);
	for (unsigned i = 0 ; i < clang_codeCompleteGetNumDiagnostics(cr); i++)
	{
		CXDiagnostic d = clang_codeCompleteGetDiagnostic(cr, i);
		unsigned fixits = clang_getDiagnosticNumFixIts(d);
		printf("Found %d fixits\n", fixits);
		if (1 == fixits)
		{
			CXSourceRange r;
			CXString str = clang_getDiagnosticFixIt(d, 0, &r);
			result.fixitRange = NSRangeFromCXSourceRange(r);
			result.fixitText = [[NSString alloc] initWithUTF8String:clang_getCString(str)];
			clang_disposeString(str);
			break;
		}
		clang_disposeDiagnostic(d);
	}
	NSMutableArray *completions = [NSMutableArray new];
	clang_sortCodeCompletionResults(cr->Results, cr->NumResults);

	for (unsigned i = 0 ; i < cr->NumResults; i++)
	{
		CXCompletionString cs = cr->Results[i].CompletionString;
		NSMutableAttributedString *completion = [NSMutableAttributedString new];
		NSMutableString *s = [completion mutableString];
		unsigned chunks = clang_getNumCompletionChunks(cs);
		for (unsigned j=0 ; j<chunks ; j++)
		{
			switch (clang_getCompletionChunkKind(cs, j))
			{
				case CXCompletionChunk_Optional:
				case CXCompletionChunk_TypedText:
				case CXCompletionChunk_Text:
				{
					CXString str = clang_getCompletionChunkText(cs, j);
					[s appendFormat:@"%s", clang_getCString(str)];
					clang_disposeString(str);
					break;
				}
				case CXCompletionChunk_Placeholder:
				{
					CXString str = clang_getCompletionChunkText(cs, j);
					[s appendFormat:@" %s ", clang_getCString(str)];
					clang_disposeString(str);
					break;
				}
				case CXCompletionChunk_Informative:
				{
					CXString str = clang_getCompletionChunkText(cs, j);
					[s appendFormat:@"/* %s */", clang_getCString(str)];
					clang_disposeString(str);
					break;
				}
				case CXCompletionChunk_CurrentParameter:
				case CXCompletionChunk_LeftParen:
					[s appendString:@"("];
                    break;
				case CXCompletionChunk_RightParen:
					[s appendString:@"("];
                    break;
				case CXCompletionChunk_LeftBracket:
					[s appendString:@"["];
                    break;
				case CXCompletionChunk_RightBracket:
					[s appendString:@"]"];
                    break;
				case CXCompletionChunk_LeftBrace:
					[s appendString:@"{"];
                    break;
				case CXCompletionChunk_RightBrace:
					[s appendString:@"}"];
                    break;
				case CXCompletionChunk_LeftAngle:
					[s appendString:@"<"];
                    break;
				case CXCompletionChunk_RightAngle:
					[s appendString:@">"];
                    break;
				case CXCompletionChunk_Comma:
					[s appendString:@","];
                    break;
				case CXCompletionChunk_ResultType:
					break;
				case CXCompletionChunk_Colon:
					[s appendString:@":"];
                    break;
				case CXCompletionChunk_SemiColon:
					[s appendString:@";"];
                    break;
				case CXCompletionChunk_Equal:
					[s appendString:@"="];
                    break;
				case CXCompletionChunk_HorizontalSpace:
					[s appendString:@" "];
                    break;
				case CXCompletionChunk_VerticalSpace:
					[s appendString:@"\n"];
                    break;
			}
		}
		[completions addObject:completion];
	}
	result.completions = completions;
	clang_disposeCodeCompleteResults(cr);
	return result;
}

@end

