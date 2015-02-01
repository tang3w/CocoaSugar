// COSStyle.m
//
// Copyright (c) 2015 Tianyong Tang
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
// KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
// AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#import "COSStyle.h"
#import "COSStyleDefine.h"
#import "COSStyleLex.h"

#import "COSStyleNodeVal.h"
#import "COSStyleNodeProp.h"
#import "COSStyleNodeDecl.h"
#import "COSStyleNodeDeclList.h"
#import "COSStyleNodeCls.h"
#import "COSStyleNodeClsList.h"
#import "COSStyleNodeSel.h"
#import "COSStyleNodeSelList.h"
#import "COSStyleNodeRule.h"
#import "COSStyleNodeRuleList.h"
#import "COSStyleNodeSheet.h"

#import <objc/runtime.h>

#define COSSTYLE_BIND_AST_DATA(data_) do {  \
    ast->data = (__bridge void *)(data_);   \
    [keeper addObject:data_];               \
} while (0)

static NSString *const COSStyleSheetExtName = @".css";

int COSStylelex(yyscan_t yyscanner, char **token_value);


@interface COSStyle ()

@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) NSMutableSet *classNames;

- (instancetype)initWithView:(UIView *)view;

@end


@interface COSStyleSheet : NSObject

@end


@interface COSStyleSheet ()

+ (instancetype)sharedStyleSheet;

@property (nonatomic, strong) NSMutableArray *nodeSheets;
@property (nonatomic, strong) NSMutableDictionary *declListCache;

- (COSStyleNodeDeclList *)declListForView:(UIView *)view classNames:(NSSet *)classNames;

@end


@implementation COSStyleSheet

+ (instancetype)sharedStyleSheet {
    static dispatch_once_t onceToken;
    static COSStyleSheet *instance = nil;

    dispatch_once(&onceToken, ^{
        instance = [[COSStyleSheet alloc] init];
    });

    return instance;
}

- (void)loadFiles:(NSArray *)files inBundle:(NSBundle *)bundle {
    if (!bundle) bundle = [NSBundle mainBundle];

    for (NSString *file in files) {
        if (![file length]) continue;

        NSString *path = file;

        if (![path hasSuffix:COSStyleSheetExtName])
            path = [path stringByAppendingString:COSStyleSheetExtName];

        path = [bundle pathForResource:path ofType:nil];

        if (path) {
            NSString *text = [NSString stringWithContentsOfFile:path
                                                       encoding:NSUTF8StringEncoding
                                                          error:NULL];
            [self scanText:text];
        }
    }
}

- (void)loadURLs:(NSArray *)URLs {
    for (NSURL *URL in URLs) {
        NSString *text = [NSString stringWithContentsOfURL:URL
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
        [self scanText:text];
    }
}

- (void)scanText:(NSString *)text {
    int token = 0;
    COSStyleCtx ctx;
    COSStyleCtxInit(&ctx);

    yyscan_t scanner;
    COSStylelex_init(&scanner);

    const char *str = [text cStringUsingEncoding:NSUTF8StringEncoding];
    YY_BUFFER_STATE state = COSStyle_scan_string(str, scanner);

    void *parser = COSStyleParseAlloc(malloc);

    do {
        char *tokenValue = NULL;
        token = COSStylelex(scanner, &tokenValue);
        COSStyleParse(parser, token, tokenValue, &ctx);
    } while (token > 0 && !ctx.result);

    if (token < 0 || ctx.result) {
        NSLog(@"COSStyle encountered an syntax error!");
    } else {
        [self addStyleGroupForCtx:ctx];
    }

    COSStyleCtxFree(ctx);
    COSStyle_delete_buffer(state, scanner);
    COSStylelex_destroy(scanner);
    COSStyleParseFree(parser, free);
}

- (void)addStyleGroupForCtx:(COSStyleCtx)ctx {
    NSMutableSet *keeper = [NSMutableSet set];
    [self parseAst:ctx.ast parent:NULL keeper:keeper];
    COSStyleNodeSheet *nodeSheet = (__bridge COSStyleNodeSheet *)ctx.ast->data;

    if (nodeSheet) {
        [self.nodeSheets addObject:nodeSheet];
    }
}

- (void)parseAst:(COSStyleAST *)ast parent:(COSStyleAST *)parent keeper:(NSMutableSet *)keeper {
    if (ast == NULL) return;

    [self parseAst:ast->l parent:ast keeper:keeper];
    [self parseAst:ast->r parent:ast keeper:keeper];

    switch ((COSStyleNodeType)ast->nodeType) {
    case COSStyleNodeTypeVal:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeVal alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeProp:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeProp alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeDecl:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeDecl alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeDeclList:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeDeclList alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeCls:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeCls alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeClsList:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeClsList alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeSel:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeSel alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeSelList:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeSelList alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeRule:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeRule alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeRuleList:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeRuleList alloc] initWithAst:ast]);
        break;
    case COSStyleNodeTypeSheet:
        COSSTYLE_BIND_AST_DATA([[COSStyleNodeSheet alloc] initWithAst:ast]);
        break;
    }
}

- (COSStyleNodeDeclList *)declListForView:(UIView *)view classNames:(NSSet *)classNames {
    Class clazz = object_getClass(view);

    NSSet *key = [classNames setByAddingObject:clazz];
    COSStyleNodeDeclList *cachedDeclList = self.declListCache[key];

    if (cachedDeclList)
        return cachedDeclList;

    NSArray *combinations = [self allCombinationsOfSet:classNames];
    COSStyleNodeDeclList *declList = [[COSStyleNodeDeclList alloc] init];

    for (COSStyleNodeSheet *nodeSheet in self.nodeSheets) {
        for (NSArray *combination in combinations) {
            COSStyleNodeDeclList *subDeclList = (
                [nodeSheet declListForView:view classNames:[NSSet setWithArray:combination]]
            );
            [declList addDeclsFromDeclList:subDeclList];
        }
    }

    self.declListCache[key] = declList;

    return declList;
}

- (NSArray *)allCombinationsOfSet:(NSSet *)set {
    NSInteger count = [set count];

    if (count > 0) {
        NSArray *elements = [set allObjects];
        NSMutableArray *combinations = [[NSMutableArray alloc] init];

        for (NSInteger i = 1; i <= count; ++i) {
            NSArray *subCombinations = [self combinationsOfElements:elements size:i];
            [combinations addObjectsFromArray:subCombinations];
        }

        return [combinations copy];
    }

    return @[];
}

- (NSArray *)combinationsOfElements:(NSArray *)elements size:(NSInteger)size {
    NSInteger count = [elements count];
    NSMutableArray *combinations = [[NSMutableArray alloc] init];

    if (size <= 0)
        return @[];
    else if (size == 1) {
        for (id element in elements) {
            [combinations addObject:@[element]];
        }
    }
    else if (size > count) return nil;
    else {
        for (NSInteger i = count - 1; i >= size - 1; i--) {
            id largest = [elements objectAtIndex:i];
            NSArray *others = [elements subarrayWithRange:NSMakeRange(0, i)];

            for (NSArray *c in [self combinationsOfElements:others size:(size - 1)]) {
                [combinations addObject:[c arrayByAddingObject:largest]];
            }
        }
    }

    return combinations;
}

- (NSMutableArray *)nodeSheets {
    if (!_nodeSheets)
        _nodeSheets = [[NSMutableArray alloc] init];

    return _nodeSheets;
}

- (NSMutableDictionary *)declListCache {
    if (!_declListCache)
        _declListCache = [[NSMutableDictionary alloc] init];

    return _declListCache;
}

@end


@implementation COSStyle

+ (void)loadFiles:(NSArray *)files inBundle:(NSBundle *)bundle {
    [[COSStyleSheet sharedStyleSheet] loadFiles:files inBundle:bundle];
}

+ (void)loadFiles:(NSString *)file, ... {
    NSMutableArray *files = [[NSMutableArray alloc] init];

    if (file) [files addObject:file];

    va_list argv;
    va_start(argv, file);

    while ((file = va_arg(argv, NSString *)))
        [files addObject:file];

    va_end(argv);

    [self loadFiles:files inBundle:[NSBundle mainBundle]];
}

+ (void)loadURLs:(NSURL *)URL, ... {
    NSMutableArray *URLs = [[NSMutableArray alloc] init];

    if (URL) [URLs addObject:URL];

    va_list argv;
    va_start(argv, URL);

    while ((URL = va_arg(argv, NSURL *)))
        [URLs addObject:URL];

    va_end(argv);

    [[COSStyleSheet sharedStyleSheet] loadURLs:URLs];
}

+ (instancetype)styleOfView:(UIView *)view {
    static const void *COSStyleKey = &COSStyleKey;

    COSStyle *style = objc_getAssociatedObject(view, COSStyleKey);

    if (!style) {
        style = [[COSStyle alloc] initWithView:view];
        objc_setAssociatedObject(view, COSStyleKey, style, OBJC_ASSOCIATION_RETAIN);
    }

    return style;
}

- (instancetype)initWithView:(UIView *)view {
    self = [super init];

    if (self) _view = view;

    return self;
}

- (void)addClassName:(NSString *)className {
    NSMutableSet *classNames = [[NSMutableSet alloc] init];

    NSCharacterSet *spaces = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSArray *slices = [className componentsSeparatedByCharactersInSet:spaces];

    for (NSString *slice in slices) {
        NSString *trimedSlice = [slice stringByTrimmingCharactersInSet:spaces];

        if ([trimedSlice length])
            [classNames addObject:trimedSlice];
    }

    [self.classNames unionSet:classNames];
    [self renderStyle];
}

- (void)renderStyle {
    COSStyleNodeDeclList *nodeDeclList = (
        [[COSStyleSheet sharedStyleSheet] declListForView:self.view classNames:self.classNames]
    );

    for (COSStyleNodeDecl *nodeDecl in nodeDeclList.allDecls) {
        [nodeDecl applyToView:self.view];
    }
}

- (NSMutableSet *)classNames {
    if (!_classNames)
        _classNames = [[NSMutableSet alloc] init];

    return _classNames;
}

@end


@implementation UIView (COSStyle)

- (COSStyle *)cosStyle {
    return [COSStyle styleOfView:self];
}

@end
