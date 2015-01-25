// COSStyleNodeProp.m
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

#import "COSStyleNodeProp.h"

static NSMutableDictionary *COSStyleRenderBlockMap = nil;

typedef void(^COSStyleRenderBlock)(UIView *view, COSStyleNodeVal *nodeVal);

NS_INLINE
void COSStyleAddRenderBlock(NSString *property, COSStyleRenderBlock block) {
    COSStyleRenderBlockMap[property] = [block copy];
}

@implementation COSStyleNodeProp

+ (void)initialize {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        COSStyleRenderBlockMap = [[NSMutableDictionary alloc] init];
    });

    COSStyleAddRenderBlock(@"background-color", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        UIColor *colorValue = [nodeVal colorValue];
        if (colorValue)
            view.backgroundColor = colorValue;
    });

    COSStyleAddRenderBlock(@"background-image", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        UIImage *imageValue = [nodeVal imageValue];
        if (imageValue)
            view.backgroundColor = [UIColor colorWithPatternImage:imageValue];
    });

    COSStyleAddRenderBlock(@"border-radius", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGFloat floatValue = [nodeVal CGFloatValue];
        if (!isnan(floatValue))
            view.layer.cornerRadius = floatValue;
    });

    COSStyleAddRenderBlock(@"overflow", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if ([nodeVal.stringValue isEqualToString:@"hidden"]) {
            view.layer.masksToBounds = YES;
        } else if ([nodeVal.stringValue isEqualToString:@"visible"]) {
            view.layer.masksToBounds = NO;
        }
    });

    COSStyleAddRenderBlock(@"opacity", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGFloat floatValue = [nodeVal CGFloatValue];
        if (!isnan(floatValue))
            view.layer.opacity = floatValue;
    });

    COSStyleAddRenderBlock(@"width", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGFloat floatValue = [nodeVal CGFloatValue];
        if (!isnan(floatValue)) {
            CGRect bounds = view.bounds;
            bounds.size.width = floatValue;
            view.bounds = bounds;
        }
    });

    COSStyleAddRenderBlock(@"height", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGFloat floatValue = [nodeVal CGFloatValue];
        if (!isnan(floatValue)) {
            CGRect bounds = view.bounds;
            bounds.size.height = floatValue;
            view.bounds = bounds;
        }
    });
}

- (instancetype)initWithAst:(COSStyleAST *)ast {
    if ((self = [super initWithAst:ast]))
        self.stringValue = COSSTYLE_AST_STRING_VALUE(ast);

    return self;
}

- (void)renderView:(UIView *)view withNodeVal:(COSStyleNodeVal *)nodeVal {
    COSStyleRenderBlock renderBlock = COSStyleRenderBlockMap[self.stringValue];

    if (renderBlock)
        renderBlock(view, nodeVal);
}

@end
