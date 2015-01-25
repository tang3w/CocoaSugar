// COSStyleNodeSel.m
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

#import "COSStyleNodeSel.h"

@implementation COSStyleNodeSel

- (instancetype)initWithAst:(COSStyleAST *)ast {
    if ((self = [super initWithAst:ast])) {
        if (ast->r != NULL) {
            _clsList = (__bridge COSStyleNodeClsList *)ast->r->data;
        }

        self.stringValue = COSSTYLE_AST_STRING_VALUE(ast) ?: @"UIView";
    }

    return self;
}

- (BOOL)matchName:(NSString *)name andClassNames:(NSSet *)classNames {
    return [self.stringValue isEqualToString:name] && [self matchClassNames:classNames];
}

- (BOOL)matchClassNames:(NSSet *)classNames {
    return [[self allClsNames] isEqual:classNames];
}

- (NSSet *)allClsNames {
    NSArray *allCls = [self.clsList allClses];

    if ([allCls count] > 0) {
        NSMutableSet *clsNames = [[NSMutableSet alloc] init];

        for (COSStyleNodeCls *nodeCls in allCls) {
            [clsNames addObject:nodeCls.stringValue];
        }

        return [clsNames copy];
    }

    return [NSSet set];
}

@end
