// CSLayout.h
//
// Copyright (c) 2014 Tang Tianyong
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface CSCoord : NSObject

- (instancetype)offset:(float)offset;

- (instancetype)factor:(float)factor;

@end


@interface CSCoords : NSObject

+ (instancetype)coordsOfView:(UIView *)view;

@property (nonatomic, readonly) CSCoord *tt;
@property (nonatomic, readonly) CSCoord *tb;

@property (nonatomic, readonly) CSCoord *ll;
@property (nonatomic, readonly) CSCoord *lr;

@property (nonatomic, readonly) CSCoord *bb;
@property (nonatomic, readonly) CSCoord *bt;

@property (nonatomic, readonly) CSCoord *rr;
@property (nonatomic, readonly) CSCoord *rl;

@property (nonatomic, readonly) CSCoord *ct;
@property (nonatomic, readonly) CSCoord *cl;

@property (nonatomic, readonly) CSCoord *w;
@property (nonatomic, readonly) CSCoord *h;

@end


@interface CSLayout : NSObject

+ (instancetype)layoutOfView:(UIView *)view;

@property (nonatomic, strong) id minw;
@property (nonatomic, strong) id maxw;

@property (nonatomic, strong) id minh;
@property (nonatomic, strong) id maxh;

@property (nonatomic, strong) id tt;
@property (nonatomic, strong) id tb;

@property (nonatomic, strong) id ll;
@property (nonatomic, strong) id lr;

@property (nonatomic, strong) id bb;
@property (nonatomic, strong) id bt;

@property (nonatomic, strong) id rr;
@property (nonatomic, strong) id rl;

@property (nonatomic, strong) id ct;
@property (nonatomic, strong) id cl;

@end


@interface CSPercentOffset : NSObject

- (instancetype)initWithPercent:(float)percent offset:(float)offset;

- (float)percentValue;
- (float)offsetValue;

@end


CG_INLINE CSLayout *CSLayoutMake(UIView *view)
{
    return [CSLayout layoutOfView:view];
}

CG_INLINE CSCoords *CSCoordsMake(UIView *view)
{
    return [CSCoords coordsOfView:view];
}

CG_INLINE CSPercentOffset *CSPercentOffsetMake(float percent, float offset)
{
    return [[CSPercentOffset alloc] initWithPercent:percent offset:offset];
}

CG_INLINE CSPercentOffset *CSPercentMake(float percent)
{
    return [[CSPercentOffset alloc] initWithPercent:percent offset:0];
}
