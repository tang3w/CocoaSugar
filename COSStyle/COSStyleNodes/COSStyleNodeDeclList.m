// COSStyleNodeDeclList.m
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

#import "COSStyleNodeDeclList.h"


@interface COSStyleNodeDeclList ()

@property (nonatomic, strong) NSMutableArray *mutableAllDecls;

@end


@implementation COSStyleNodeDeclList

- (instancetype)initWithAst:(COSStyleAST *)ast {
    if ((self = [super initWithAst:ast])) {
        if (ast->l != NULL)
            [self addDeclsFromDeclList:(__bridge COSStyleNodeDeclList *)ast->l->data];

        [self addDecl:(__bridge COSStyleNodeDecl *)ast->r->data];
    }

    return self;
}

- (NSArray *)allDecls {
    return [self.mutableAllDecls copy];
}

- (void)addDeclsFromDeclList:(COSStyleNodeDeclList *)declList {
    [self.mutableAllDecls addObjectsFromArray:[declList allDecls]];
}

- (void)addDecl:(COSStyleNodeDecl *)decl {
    [self.mutableAllDecls addObject:decl];
}

- (NSMutableArray *)mutableAllDecls {
    if (!_mutableAllDecls)
        _mutableAllDecls = [[NSMutableArray alloc] init];

    return _mutableAllDecls;
}

@end
