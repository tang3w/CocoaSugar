// COSStyleNodeVal.m
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

#import "COSStyleNodeVal.h"

@implementation COSStyleNodeVal

- (instancetype)initWithAst:(COSStyleAST *)ast {
    if ((self = [super initWithAst:ast]))
        self.stringValue = COSSTYLE_AST_STRING_VALUE(ast);

    return self;
}

- (CGFloat)colorComponentFromString:(NSString *)string start:(NSInteger)start length:(NSInteger)length {
    unsigned component;
    NSString *hex = [string substringWithRange:NSMakeRange(start, length)];

    if (length == 1)
        hex = [hex stringByAppendingString:hex];

    [[NSScanner scannerWithString:hex] scanHexInt:&component];

    return component / 255.0;
}

- (UIColor *)colorValue {
    static dispatch_once_t onceToken;
    static NSRegularExpression *hexColorRegExp = nil;

    dispatch_once(&onceToken, ^{
        hexColorRegExp = (
            [NSRegularExpression
             regularExpressionWithPattern:@"^#?([0-9a-f]+)$"
             options:NSRegularExpressionCaseInsensitive
             error:nil]
        );
    });

    if (self.stringValue) {
        NSRange range = NSMakeRange(0, self.stringValue.length);
        NSArray *matches = [hexColorRegExp matchesInString:self.stringValue options:0 range:range];

        if ([matches count] > 0) {
            NSRange hexRange = [[matches firstObject] rangeAtIndex:1];
            NSString *hexString = [self.stringValue substringWithRange:hexRange];

            CGFloat r, g, b, a;

            switch (hexString.length) {
            case 3:
                r = [self colorComponentFromString:hexString start:0 length:1];
                g = [self colorComponentFromString:hexString start:1 length:1];
                b = [self colorComponentFromString:hexString start:2 length:1];
                a = 1;
                break;
            case 4:
                r = [self colorComponentFromString:hexString start:0 length:1];
                g = [self colorComponentFromString:hexString start:1 length:1];
                b = [self colorComponentFromString:hexString start:2 length:1];
                a = [self colorComponentFromString:hexString start:3 length:1];
                break;
            case 6:
                r = [self colorComponentFromString:hexString start:0 length:2];
                g = [self colorComponentFromString:hexString start:2 length:2];
                b = [self colorComponentFromString:hexString start:4 length:2];
                a = 1;
                break;
            case 8:
                r = [self colorComponentFromString:hexString start:0 length:2];
                g = [self colorComponentFromString:hexString start:2 length:2];
                b = [self colorComponentFromString:hexString start:4 length:2];
                a = [self colorComponentFromString:hexString start:6 length:2];
                break;
            default:
                return nil;
            }

            return [UIColor colorWithRed:r green:g blue:b alpha:a];
        }
    }

    return nil;
}

- (UIImage *)imageValue {
    return [UIImage imageNamed:self.stringValue];
}

- (CGFloat)CGFloatValue {
#if CGFLOAT_IS_DOUBLE
    return [self.stringValue doubleValue];
#else
    return [self.stringValue floatValue];
#endif
}

@end
