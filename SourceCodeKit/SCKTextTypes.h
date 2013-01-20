#import <Foundation/Foundation.h>

/**
 * The type of the token.  This key indicates the type that lexical analysis
 * records for this token.  
 */
NSString *const kSCKTextTokenType;
/**
 * Token is punctuation.
 */
NSString *const SCKTextTokenTypePunctuation;
/**
 * Token is a keyword.
 */
NSString *const SCKTextTokenTypeKeyword;
/**
 * Token is an identifier.
 */
NSString *const SCKTextTokenTypeIdentifier;
/**
 * Token is a literal value.
 */
NSString *const SCKTextTokenTypeLiteral;
/**
 * Token is a comment.
 */
NSString *const SCKTextTokenTypeComment;
/**
 * The type that semantic analysis records for this
 */
NSString *const kSCKTextSemanticType;
/**
 * Reference to a type declared elsewhere.
 */
NSString *const SCKTextTypeReference;
/**
 * Instantiation of a macro.
 */
NSString *const SCKTextTypeMacroInstantiation;
/**
 * Definition of a macro.
 */
NSString *const SCKTextTypeMacroDefinition;
/**
 * A declaration.
 */
NSString *const SCKTextTypeDeclaration;
/**
 * A message send expression.
 */
NSString *const SCKTextTypeMessageSend;
/**
 * A reference to a declaration.
 */
NSString *const SCKTextTypeDeclRef;
/**
 * A preprocessor directive, such as #import or #include.
 */
NSString *const SCKTextTypePreprocessorDirective;
/**
 * Something is wrong with the text for this range.  The value for this
 * attribute is a dictionary describing exactly what.
 */
NSString *const kSCKDiagnostic;
/**
 * The severity of the diagnostic.  An NSNumber from 1 (hint) to 5 (fatal
 * error).
 */
NSString *const kSCKDiagnosticSeverity;
/**
 * A human-readable string giving the text of the diagnostic, suitable for
 * display.
 */
NSString *const kSCKDiagnosticText;
