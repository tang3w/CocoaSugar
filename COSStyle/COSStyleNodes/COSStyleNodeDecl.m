// COSStyleNodeDecl.m
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

#import "COSStyleNodeDecl.h"

@implementation COSStyleNodeDecl

- (instancetype)initWithAst:(COSStyleAST *)ast {
    if ((self = [super initWithAst:ast])) {
        _prop = (__bridge COSStyleNodeProp *)ast->l->data;
        _val  = (__bridge COSStyleNodeVal  *)ast->r->data;
    }

    return self;
}

- (void)applyToView:(UIView *)view {
    SEL selector = NSSelectorFromString(@"cosStyleRespondsToProperty:value:");

    if ([view respondsToSelector:selector]) {
        NSMethodSignature* signature = [[view class] instanceMethodSignatureForSelector:selector];

        if (!strcmp([signature methodReturnType], @encode(BOOL)) &&
            !strcmp([signature getArgumentTypeAtIndex:2], @encode(NSString *)) &&
            !strcmp([signature getArgumentTypeAtIndex:3], @encode(NSString *))) {

            BOOL responded = NO;
            NSString *prop = self.prop.stringValue;
            NSString *val = self.val.stringValue;

            NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];

            [invocation setTarget:view];
            [invocation setSelector:selector];
            [invocation setArgument:&prop atIndex:2];
            [invocation setArgument:&val atIndex:3];
            [invocation invoke];
            [invocation getReturnValue:&responded];

            if (responded) return;
        }
    }

    [self.prop renderView:view withNodeVal:self.val];
}

@end
