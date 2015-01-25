// COSStyleNodeClsList.m
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

#import "COSStyleNodeClsList.h"

@interface COSStyleNodeClsList ()

@property (nonatomic, strong) NSMutableArray *mutableAllClses;

@end

@implementation COSStyleNodeClsList

- (instancetype)initWithAst:(COSStyleAST *)ast {
    if ((self = [super initWithAst:ast])) {
        if (ast->l != NULL)
            [self addClsesFromClsList:(__bridge COSStyleNodeClsList *)ast->l->data];

        [self addCls:(__bridge COSStyleNodeCls *)ast->r->data];
    }

    return self;
}

- (NSArray *)allClses {
    return [self.mutableAllClses copy];
}

- (void)addClsesFromClsList:(COSStyleNodeClsList *)clsList {
    [self.mutableAllClses addObjectsFromArray:[clsList allClses]];
}

- (void)addCls:(COSStyleNodeCls *)cls {
    [self.mutableAllClses addObject:cls];
}

- (NSMutableArray *)mutableAllClses {
    if (!_mutableAllClses)
        _mutableAllClses = [[NSMutableArray alloc] init];

    return _mutableAllClses;
}

@end
