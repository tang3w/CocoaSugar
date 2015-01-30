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

static NSDictionary *COSStyleW3CNamedColors(void);

@interface COSStyleNodeVal ()

@property (nonatomic, assign) COSStyleNodeValType nodeValType;

@end

@implementation COSStyleNodeVal

- (instancetype)initWithAst:(COSStyleAST *)ast {
    if ((self = [super initWithAst:ast])) {
        self.stringValue = COSSTYLE_AST_STRING_VALUE(ast);
        self.nodeValType = ast->nodeValueType;
    }

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

- (BOOL)getColorValue:(UIColor *__autoreleasing *)value {
    if (self.nodeValType != COSStyleNodeValTypeID &&
        self.nodeValType != COSStyleNodeValTypeHex)
        return NO;

    NSString *hexString = self.stringValue;

    if (!hexString.length)
        return NO;

    if (![hexString hasPrefix:@"#"]) {
        NSString *key = [hexString lowercaseString];
        hexString = COSStyleW3CNamedColors()[key];

        if (!hexString)
            return NO;
    }

    static dispatch_once_t onceToken;
    static NSRegularExpression *hexColorRegExp = nil;

    dispatch_once(&onceToken, ^{
        hexColorRegExp = (
            [NSRegularExpression
             regularExpressionWithPattern:@"^#?[0-9a-f]+$"
             options:NSRegularExpressionCaseInsensitive
             error:nil]
        );
    });

    NSRange range = NSMakeRange(0, hexString.length);
    NSArray *matches = [hexColorRegExp matchesInString:hexString options:0 range:range];

    if (![matches count])
        return NO;

    hexString = [hexString substringFromIndex:1];

    if (hexString) {
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
            return NO;
        }

        *value = [UIColor colorWithRed:r green:g blue:b alpha:a];

        return YES;
    }

    return NO;
}

- (BOOL)getCGFloatValue:(CGFloat *)value {
    if (self.nodeValType != COSStyleNodeValTypeExpression)
        return NO;

    NSScanner *scanner = [NSScanner scannerWithString:self.stringValue];

#if CGFLOAT_IS_DOUBLE
    BOOL valid = [scanner scanDouble:value];
#else
    BOOL valid = [scanner scanFloat:value];
#endif

    return valid;
}

- (BOOL)getContentModeValue:(UIViewContentMode *)contentMode {
    if (self.nodeValType != COSStyleNodeValTypeID)
        return NO;

    static dispatch_once_t onceToken;
    static NSDictionary *contentModeMap = nil;

    dispatch_once(&onceToken, ^{
        contentModeMap = @{
            @"scale-to-fill":     @(UIViewContentModeScaleToFill),
            @"scale-aspect-fit":  @(UIViewContentModeScaleAspectFit),
            @"scale-aspect-fill": @(UIViewContentModeScaleAspectFill),
            @"redraw":            @(UIViewContentModeRedraw),
            @"center":            @(UIViewContentModeCenter),
            @"top":               @(UIViewContentModeTop),
            @"bottom":            @(UIViewContentModeBottom),
            @"left":              @(UIViewContentModeLeft),
            @"right":             @(UIViewContentModeRight),
            @"top-left":          @(UIViewContentModeTopLeft),
            @"top-right":         @(UIViewContentModeTopRight),
            @"bottom-left":       @(UIViewContentModeBottomLeft),
            @"bottom-right":      @(UIViewContentModeBottomRight)
        };
    });

    NSNumber *modeNumber = contentModeMap[self.stringValue];

    if (modeNumber)
        *contentMode = [modeNumber integerValue];

    return modeNumber != nil;
}

- (BOOL)getVisibleValue:(BOOL *)value {
    if (self.nodeValType != COSStyleNodeValTypeID)
        return NO;

    static dispatch_once_t onceToken;
    static NSDictionary *visibilityMap = nil;

    dispatch_once(&onceToken, ^{
        visibilityMap = @{
            @"visible": @YES,
            @"hidden": @NO
        };
    });

    NSNumber *visibility = visibilityMap[self.stringValue];

    if (visibility)
        *value = [visibility boolValue];

    return visibility != nil;
}

- (BOOL)getCGSizeValue:(CGSize *)value {
    if (self.nodeValType != COSStyleNodeValTypeSize)
        return NO;

    NSArray *components = [self.stringValue componentsSeparatedByString:@","];

    NSCharacterSet *spaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    NSString *wstr = [components[0] stringByTrimmingCharactersInSet:spaceSet];
    NSString *hstr = [components[1] stringByTrimmingCharactersInSet:spaceSet];

    CGFloat width = 0, height = 0;

#if CGFLOAT_IS_DOUBLE
    width = [wstr doubleValue];
    height = [hstr doubleValue];
#else
    width = [wstr floatValue];
    height = [hstr floatValue];
#endif

    *value = CGSizeMake(width, height);

    return YES;
}

@end


static NSDictionary *COSStyleW3CNamedColors(void) {
    static dispatch_once_t onceToken;
    static NSDictionary *namedColorMap = nil;

    dispatch_once(&onceToken, ^{
        namedColorMap = @{
            @"aliceblue"            : @"#f0f8ff",
            @"antiquewhite"         : @"#faebd7",
            @"aqua"                 : @"#00ffff",
            @"aquamarine"           : @"#7fffd4",
            @"azure"                : @"#f0ffff",
            @"beige"                : @"#f5f5dc",
            @"bisque"               : @"#ffe4c4",
            @"black"                : @"#000000",
            @"blanchedalmond"       : @"#ffebcd",
            @"blue"                 : @"#0000ff",
            @"blueviolet"           : @"#8a2be2",
            @"brown"                : @"#a52a2a",
            @"burlywood"            : @"#deb887",
            @"cadetblue"            : @"#5f9ea0",
            @"chartreuse"           : @"#7fff00",
            @"chocolate"            : @"#d2691e",
            @"coral"                : @"#ff7f50",
            @"cornflowerblue"       : @"#6495ed",
            @"cornsilk"             : @"#fff8dc",
            @"crimson"              : @"#dc143c",
            @"cyan"                 : @"#00ffff",
            @"darkblue"             : @"#00008b",
            @"darkcyan"             : @"#008b8b",
            @"darkgoldenrod"        : @"#b8860b",
            @"darkgray"             : @"#a9a9a9",
            @"darkgrey"             : @"#a9a9a9",
            @"darkgreen"            : @"#006400",
            @"darkkhaki"            : @"#bdb76b",
            @"darkmagenta"          : @"#8b008b",
            @"darkolivegreen"       : @"#556b2f",
            @"darkorange"           : @"#ff8c00",
            @"darkorchid"           : @"#9932cc",
            @"darkred"              : @"#8b0000",
            @"darksalmon"           : @"#e9967a",
            @"darkseagreen"         : @"#8fbc8f",
            @"darkslateblue"        : @"#483d8b",
            @"darkslategray"        : @"#2f4f4f",
            @"darkslategrey"        : @"#2f4f4f",
            @"darkturquoise"        : @"#00ced1",
            @"darkviolet"           : @"#9400d3",
            @"deeppink"             : @"#ff1493",
            @"deepskyblue"          : @"#00bfff",
            @"dimgray"              : @"#696969",
            @"dimgrey"              : @"#696969",
            @"dodgerblue"           : @"#1e90ff",
            @"firebrick"            : @"#b22222",
            @"floralwhite"          : @"#fffaf0",
            @"forestgreen"          : @"#228b22",
            @"fuchsia"              : @"#ff00ff",
            @"gainsboro"            : @"#dcdcdc",
            @"ghostwhite"           : @"#f8f8ff",
            @"gold"                 : @"#ffd700",
            @"goldenrod"            : @"#daa520",
            @"gray"                 : @"#808080",
            @"grey"                 : @"#808080",
            @"green"                : @"#008000",
            @"greenyellow"          : @"#adff2f",
            @"honeydew"             : @"#f0fff0",
            @"hotpink"              : @"#ff69b4",
            @"indianred"            : @"#cd5c5c",
            @"indigo"               : @"#4b0082",
            @"ivory"                : @"#fffff0",
            @"khaki"                : @"#f0e68c",
            @"lavender"             : @"#e6e6fa",
            @"lavenderblush"        : @"#fff0f5",
            @"lawngreen"            : @"#7cfc00",
            @"lemonchiffon"         : @"#fffacd",
            @"lightblue"            : @"#add8e6",
            @"lightcoral"           : @"#f08080",
            @"lightcyan"            : @"#e0ffff",
            @"lightgoldenrodyellow" : @"#fafad2",
            @"lightgray"            : @"#d3d3d3",
            @"lightgrey"            : @"#d3d3d3",
            @"lightgreen"           : @"#90ee90",
            @"lightpink"            : @"#ffb6c1",
            @"lightsalmon"          : @"#ffa07a",
            @"lightseagreen"        : @"#20b2aa",
            @"lightskyblue"         : @"#87cefa",
            @"lightslategray"       : @"#778899",
            @"lightslategrey"       : @"#778899",
            @"lightsteelblue"       : @"#b0c4de",
            @"lightyellow"          : @"#ffffe0",
            @"lime"                 : @"#00ff00",
            @"limegreen"            : @"#32cd32",
            @"linen"                : @"#faf0e6",
            @"magenta"              : @"#ff00ff",
            @"maroon"               : @"#800000",
            @"mediumaquamarine"     : @"#66cdaa",
            @"mediumblue"           : @"#0000cd",
            @"mediumorchid"         : @"#ba55d3",
            @"mediumpurple"         : @"#9370db",
            @"mediumseagreen"       : @"#3cb371",
            @"mediumslateblue"      : @"#7b68ee",
            @"mediumspringgreen"    : @"#00fa9a",
            @"mediumturquoise"      : @"#48d1cc",
            @"mediumvioletred"      : @"#c71585",
            @"midnightblue"         : @"#191970",
            @"mintcream"            : @"#f5fffa",
            @"mistyrose"            : @"#ffe4e1",
            @"moccasin"             : @"#ffe4b5",
            @"navajowhite"          : @"#ffdead",
            @"navy"                 : @"#000080",
            @"oldlace"              : @"#fdf5e6",
            @"olive"                : @"#808000",
            @"olivedrab"            : @"#6b8e23",
            @"orange"               : @"#ffa500",
            @"orangered"            : @"#ff4500",
            @"orchid"               : @"#da70d6",
            @"palegoldenrod"        : @"#eee8aa",
            @"palegreen"            : @"#98fb98",
            @"paleturquoise"        : @"#afeeee",
            @"palevioletred"        : @"#db7093",
            @"papayawhip"           : @"#ffefd5",
            @"peachpuff"            : @"#ffdab9",
            @"peru"                 : @"#cd853f",
            @"pink"                 : @"#ffc0cb",
            @"plum"                 : @"#dda0dd",
            @"powderblue"           : @"#b0e0e6",
            @"purple"               : @"#800080",
            @"red"                  : @"#ff0000",
            @"rosybrown"            : @"#bc8f8f",
            @"royalblue"            : @"#4169e1",
            @"saddlebrown"          : @"#8b4513",
            @"salmon"               : @"#fa8072",
            @"sandybrown"           : @"#f4a460",
            @"seagreen"             : @"#2e8b57",
            @"seashell"             : @"#fff5ee",
            @"sienna"               : @"#a0522d",
            @"silver"               : @"#c0c0c0",
            @"skyblue"              : @"#87ceeb",
            @"slateblue"            : @"#6a5acd",
            @"slategray"            : @"#708090",
            @"slategrey"            : @"#708090",
            @"snow"                 : @"#fffafa",
            @"springgreen"          : @"#00ff7f",
            @"steelblue"            : @"#4682b4",
            @"tan"                  : @"#d2b48c",
            @"teal"                 : @"#008080",
            @"thistle"              : @"#d8bfd8",
            @"tomato"               : @"#ff6347",
            @"turquoise"            : @"#40e0d0",
            @"violet"               : @"#ee82ee",
            @"wheat"                : @"#f5deb3",
            @"white"                : @"#ffffff",
            @"whitesmoke"           : @"#f5f5f5",
            @"yellow"               : @"#ffff00",
            @"yellowgreen"          : @"#9acd32"
        };
    });

    return namedColorMap;
}
