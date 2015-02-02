// COSStyleNodeSheet.m
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

#import "COSStyleNodeSheet.h"

#import <objc/runtime.h>

@implementation COSStyleNodeSheet

- (instancetype)initWithAst:(COSStyleAST *)ast {
    if ((self = [super initWithAst:ast]))
        if (ast->r)
            _ruleList = (__bridge COSStyleNodeRuleList *)ast->r->data;

    return self;
}

- (COSStyleNodeDeclList *)declListForView:(UIView *)view classNames:(NSSet *)classNames {
    NSArray *superNames = [self superNamesOfView:view];
    COSStyleNodeDeclList *nodeDeclList = [[COSStyleNodeDeclList alloc] init];

    for (NSString *superName in superNames) {
        for (COSStyleNodeRule *nodeRule in [self.ruleList allRules]) {
            if ([nodeRule matchName:superName andClassNames:classNames]) {
                [nodeDeclList addDeclsFromDeclList:nodeRule.declList];
            }
        }
    }

    return nodeDeclList;
}

- (NSArray *)superNamesOfView:(UIView *)view {
    Class rootClazz = [UIView class];

    if ([view isKindOfClass:rootClazz]) {
        Class clazz = object_getClass(view);
        NSMutableArray *superNames = [[NSMutableArray alloc] init];

        while (YES) {
            [superNames addObject:NSStringFromClass(clazz)];

            if (clazz != rootClazz)
                clazz = class_getSuperclass(clazz);
            else
                break;
        }

        return [superNames copy];
    }

    return @[];
}

@end
