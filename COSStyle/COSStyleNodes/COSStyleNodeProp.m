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
#import "COSLayout.h"

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
        UIColor *colorValue = nil;
        if ([nodeVal getColorValue:&colorValue])
            view.backgroundColor = colorValue;
    });

    COSStyleAddRenderBlock(@"background-image", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        UIImage *imageValue = [UIImage imageNamed:nodeVal.stringValue];
        if (imageValue)
            view.backgroundColor = [UIColor colorWithPatternImage:imageValue];
    });

    COSStyleAddRenderBlock(@"border-radius", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGFloat floatValue = 0;
        if ([nodeVal getCGFloatValue:&floatValue])
            view.layer.cornerRadius = floatValue;
    });

    COSStyleAddRenderBlock(@"border-width", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGFloat floatValue = 0;
        if ([nodeVal getCGFloatValue:&floatValue])
            view.layer.borderWidth = floatValue;
    });

    COSStyleAddRenderBlock(@"border-color", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        UIColor *colorValue = nil;
        if ([nodeVal getColorValue:&colorValue])
            view.layer.borderColor = colorValue.CGColor;
    });

    COSStyleAddRenderBlock(@"shadow-color", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        UIColor *colorValue = nil;
        if ([nodeVal getColorValue:&colorValue])
            view.layer.shadowColor = colorValue.CGColor;
    });

    COSStyleAddRenderBlock(@"shadow-opacity", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGFloat floatValue = 0;
        if ([nodeVal getCGFloatValue:&floatValue])
            view.layer.shadowOpacity = floatValue;
    });

    COSStyleAddRenderBlock(@"shadow-radius", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGFloat floatValue = 0;
        if ([nodeVal getCGFloatValue:&floatValue])
            view.layer.shadowRadius = floatValue;
    });

    COSStyleAddRenderBlock(@"shadow-offset", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGSize sizeValue = CGSizeZero;
        if ([nodeVal getCGSizeValue:&sizeValue])
            view.layer.shadowOffset = sizeValue;
    });

    COSStyleAddRenderBlock(@"content-mode", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        UIViewContentMode contentMode;
        if ([nodeVal getContentModeValue:&contentMode])
            view.contentMode = contentMode;
    });

    COSStyleAddRenderBlock(@"overflow", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        BOOL visible = NO;
        if ([nodeVal getVisibleValue:&visible])
            view.clipsToBounds = !visible;
    });

    COSStyleAddRenderBlock(@"opacity", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        CGFloat floatValue = 0;
        if ([nodeVal getCGFloatValue:&floatValue])
            view.layer.opacity = floatValue;
    });

    COSStyleAddRenderBlock(@"visibility", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        BOOL visible = NO;
        if ([nodeVal getVisibleValue:&visible])
            view.hidden = !visible;
    });

    COSStyleAddRenderBlock(@"width", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
               [NSString stringWithFormat:@"minw = maxw = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"height", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"minh = maxh = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"top", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"tt = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"left", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"ll = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"right", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"rr = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"bottom", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"bb = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"center-x", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"cl = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"center-y", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"ct = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"min-width", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"minw = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"max-width", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"maxw = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"min-height", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"minh = %@", nodeVal.stringValue]
            )];
    });

    COSStyleAddRenderBlock(@"max-height", ^(UIView *view, COSStyleNodeVal *nodeVal) {
        if (nodeVal.nodeValType == COSStyleNodeValTypeExpression)
            [[COSLayout layoutOfView:view] addRule:(
                [NSString stringWithFormat:@"maxh = %@", nodeVal.stringValue]
            )];
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
