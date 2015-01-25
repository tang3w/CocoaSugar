// COSStyleNodeSelList.m
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

#import "COSStyleNodeSelList.h"

@interface COSStyleNodeSelList ()

@property (nonatomic, strong) NSMutableArray *mutableAllSels;

@end

@implementation COSStyleNodeSelList

- (instancetype)initWithAst:(COSStyleAST *)ast {
    if ((self = [super initWithAst:ast])) {
        if (ast->l != NULL)
            [self addSelsFromSelList:(__bridge COSStyleNodeSelList *)ast->l->data];

        [self addSel:(__bridge COSStyleNodeSel *)ast->r->data];
    }

    return self;
}

- (NSArray *)allSels {
    return [self.mutableAllSels copy];
}

- (void)addSelsFromSelList:(COSStyleNodeSelList *)selList {
    [self.mutableAllSels addObjectsFromArray:[selList allSels]];
}

- (void)addSel:(COSStyleNodeSel *)sel {
    [self.mutableAllSels addObject:sel];
}

- (NSMutableArray *)mutableAllSels {
    if (!_mutableAllSels)
        _mutableAllSels = [[NSMutableArray alloc] init];

    return _mutableAllSels;
}

@end
