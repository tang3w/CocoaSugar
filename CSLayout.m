// CSLayout.m
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

#import "CSLayout.h"

#import <objc/runtime.h>

typedef void(*vIMP)(id, SEL);

typedef enum { CSLayoutDirv, CSLayoutDirh } CSLayoutDir;

static const void *CSLayoutKey = &CSLayoutKey;
static const void *CSLayoutDriverKey = &CSLayoutDriverKey;


@interface CSLayoutRule : NSObject

+ (CSLayoutRule *)layoutRuleWithView:(UIView *)view
    name:(NSString *)name
    coord:(CSCoord *)coord
    dir:(CSLayoutDir)dir;

@property (nonatomic, weak) UIView *view;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) CSCoord *coord;
@property (nonatomic, assign) CSLayoutDir dir;

@end


typedef float(^CSCoordBlock)(CSLayoutRule *);


@interface CSCoord ()

+ (instancetype)coordWithObject:(id)object;

@property (nonatomic, weak) UIView *view;
@property (nonatomic, copy) CSCoordBlock coordBlock;

@end


@interface CSLayoutRuleHub : NSObject

@property (nonatomic, readonly) NSMutableArray *vRules;
@property (nonatomic, readonly) NSMutableArray *hRules;

- (void)vAddRule:(CSLayoutRule *)rule;
- (void)hAddRule:(CSLayoutRule *)rule;

@end


@interface CSLayout ()

@property (nonatomic, weak) UIView *view;
@property (nonatomic, weak) Class originClass;
@property (nonatomic, weak) Class layoutClass;

@property (nonatomic, strong) CSLayoutRuleHub *ruleHub;
@property (nonatomic, strong) NSMutableDictionary *ruleMap;

@property (nonatomic, assign) CGRect frame;

- (void)updateLayoutDriver;

- (NSSet *)dependencies;

- (void)startLayout;

@end


@interface CSLayoutRulesSolver : NSObject

@property (nonatomic, weak) UIView *view;

- (CGRect)solveTt:(NSArray *)rules;
- (CGRect)solveTtCt:(NSArray *)rules;
- (CGRect)solveTtBt:(NSArray *)rules;

- (CGRect)solveLl:(NSArray *)rules;
- (CGRect)solveLlCl:(NSArray *)rules;
- (CGRect)solveLlRl:(NSArray *)rules;

- (CGRect)solveBt:(NSArray *)rules;
- (CGRect)solveBtCt:(NSArray *)rules;
- (CGRect)solveBtTt:(NSArray *)rules;

- (CGRect)solveRl:(NSArray *)rules;
- (CGRect)solveRlCl:(NSArray *)rules;
- (CGRect)solveRlLl:(NSArray *)rules;

- (CGRect)solveCt:(NSArray *)rules;
- (CGRect)solveCtTt:(NSArray *)rules;
- (CGRect)solveCtBt:(NSArray *)rules;

- (CGRect)solveCl:(NSArray *)rules;
- (CGRect)solveClLl:(NSArray *)rules;
- (CGRect)solveClRl:(NSArray *)rules;

@end


@implementation CSLayoutRule

+ (CSLayoutRule *)layoutRuleWithView:(UIView *)view
    name:(NSString *)name
    coord:(CSCoord *)coord
    dir:(CSLayoutDir)dir
{
    CSLayoutRule *rule = [[CSLayoutRule alloc] init];

    rule.view = view;
    rule.name = name;
    rule.coord = coord;
    rule.dir = dir;

    return rule;
}

@end


@implementation CSLayoutRuleHub

@synthesize vRules = _vRules;
@synthesize hRules = _hRules;

- (NSMutableArray *)vRules {
    return _vRules ?: (_vRules = [[NSMutableArray alloc] init]);
}

- (NSMutableArray *)hRules {
    return _hRules ?: (_hRules = [[NSMutableArray alloc] init]);
}

- (void)vAddRule:(CSLayoutRule *)rule {
    NSMutableArray *vRules = [self vRules];

    [vRules filterUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.name != %@", rule.name]];

    if ([vRules count] > 1) {
        [vRules removeObjectAtIndex:0];
    }

    if (rule.coord) {
        [vRules addObject:rule];
    }
}

- (void)hAddRule:(CSLayoutRule *)rule {
    NSMutableArray *hRules = [self hRules];

    [hRules filterUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.name != %@", rule.name]];

    if ([hRules count] > 1) {
        [hRules removeObjectAtIndex:0];
    }

    if (rule.coord) {
        [hRules addObject:rule];
    }
}

@end


#define CS_FRAME_WIDTH  (frame.size.width)
#define CS_FRAME_HEIGHT (frame.size.height)

#define CS_SUPERVIEW_WIDTH  (view.superview.bounds.size.width)
#define CS_SUPERVIEW_HEIGHT (view.superview.bounds.size.height)

#define CSLAYOUT_FRAME(view) \
([objc_getAssociatedObject(view, CSLayoutKey) frame])

#define CSLAYOUT_SOLVE_SINGLE_H(var, left)        \
do {                                              \
    CSLayoutRule *rule = rules[0];                \
    float var = [[rule coord] coordBlock](rule);  \
    UIView *view = _view;                         \
    CGRect frame = CSLAYOUT_FRAME(view);          \
    frame.origin.x = (left);                      \
    return frame;                                 \
} while (0)

#define CSLAYOUT_SOLVE_SINGLE_V(var, top)         \
do {                                              \
    CSLayoutRule *rule = rules[0];                \
    float var = [[rule coord] coordBlock](rule);  \
    UIView *view = _view;                         \
    CGRect frame = CSLAYOUT_FRAME(view);          \
    frame.origin.y = (top);                       \
    return frame;                                 \
} while (0)

#define CSLAYOUT_SOLVE_DOUBLE_H(var1, var2, width_, left)  \
do {                                                       \
    CSLayoutRule *rule0 = rules[0];                        \
    CSLayoutRule *rule1 = rules[1];                        \
    float var1 = [[rule0 coord] coordBlock](rule0);        \
    float var2 = [[rule1 coord] coordBlock](rule1);        \
    UIView *view = _view;                                  \
    CGRect frame = CSLAYOUT_FRAME(view);                   \
    frame.size.width = [self calcWidth:(width_)];          \
    frame.origin.x = (left);                               \
    return frame;                                          \
} while (0)

#define CSLAYOUT_SOLVE_DOUBLE_V(var1, var2, height_, top)  \
do {                                                       \
    CSLayoutRule *rule0 = rules[0];                        \
    CSLayoutRule *rule1 = rules[1];                        \
    float var1 = [[rule0 coord] coordBlock](rule0);        \
    float var2 = [[rule1 coord] coordBlock](rule1);        \
    UIView *view = _view;                                  \
    CGRect frame = CSLAYOUT_FRAME(view);                   \
    frame.size.height = [self calcHeight:(height_)];       \
    frame.origin.y = (top);                                \
    return frame;                                          \
} while (0)

#define CS_MM_RAW_VALUE(layout, var)             \
({                                               \
    CSLayoutRule *rule = layout.ruleMap[@#var];  \
                                                 \
    rule.coord ?                                 \
    rule.coord.coordBlock(rule) :                \
    NAN;                                         \
})

#define CS_VALID_DIM(value) (!isnan(value) && (value) >= 0)


@implementation CSLayoutRulesSolver

- (CGFloat)calcWidth:(CGFloat)width {
    CSLayout *layout = objc_getAssociatedObject(_view, CSLayoutKey);

    CGFloat minWidth = CS_MM_RAW_VALUE(layout, minWidth);

    if (CS_VALID_DIM(minWidth) && width < minWidth) {
        width = minWidth;
    }

    CGFloat maxWidth = CS_MM_RAW_VALUE(layout, maxWidth);

    if (CS_VALID_DIM(maxWidth) && width > maxWidth) {
        width = maxWidth;
    }

    return MAX(width, 0);
}

- (CGFloat)calcHeight:(CGFloat)height {
    CSLayout *layout = objc_getAssociatedObject(_view, CSLayoutKey);

    CGFloat minHeight = CS_MM_RAW_VALUE(layout, minHeight);

    if (CS_VALID_DIM(minHeight) && height < minHeight) {
        height = minHeight;
    }

    CGFloat maxHeight = CS_MM_RAW_VALUE(layout, maxHeight);

    if (CS_VALID_DIM(maxHeight) && height > maxHeight) {
        height = maxHeight;
    }

    return MAX(height, 0);
}

- (CGRect)solveTt:(NSArray *)rules {
    CSLAYOUT_SOLVE_SINGLE_V(top, top);
}

- (CGRect)solveTtCt:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_V(top, axisY, (axisY - top) * 2, top);
}

- (CGRect)solveTtBt:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_V(top, bottom, bottom - top, top);
}

- (CGRect)solveLl:(NSArray *)rules {
    CSLAYOUT_SOLVE_SINGLE_H(left, left);
}

- (CGRect)solveLlCl:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_H(left, axisX, (axisX - left) * 2, left);
}

- (CGRect)solveLlRl:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_H(left, right, right - left, left);
}

- (CGRect)solveBt:(NSArray *)rules {
    CSLAYOUT_SOLVE_SINGLE_V(bottom, bottom - CS_FRAME_HEIGHT);
}

- (CGRect)solveBtCt:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_V(bottom, axisY, (bottom - axisY) * 2, axisY - CS_FRAME_HEIGHT / 2);
}

- (CGRect)solveBtTt:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_V(bottom, top, bottom - top, top);
}

- (CGRect)solveRl:(NSArray *)rules {
    CSLAYOUT_SOLVE_SINGLE_H(right, right - CS_FRAME_WIDTH);
}

- (CGRect)solveRlCl:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_H(right, axisX, (right - axisX) * 2, axisX - CS_FRAME_WIDTH / 2);
}

- (CGRect)solveRlLl:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_H(right, left, right - left, left);
}

- (CGRect)solveCt:(NSArray *)rules {
    CSLAYOUT_SOLVE_SINGLE_V(axisY, axisY - CS_FRAME_HEIGHT / 2);
}

- (CGRect)solveCtTt:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_V(axisY, top, (axisY - top) * 2, top);
}

- (CGRect)solveCtBt:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_V(axisY, bottom, (bottom - axisY) * 2, bottom - CS_FRAME_HEIGHT);
}

- (CGRect)solveCl:(NSArray *)rules {
    CSLAYOUT_SOLVE_SINGLE_H(axisX, axisX - CS_FRAME_WIDTH / 2);
}

- (CGRect)solveClLl:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_H(axisX, left, (axisX - left) * 2, left);
}

- (CGRect)solveClRl:(NSArray *)rules {
    CSLAYOUT_SOLVE_DOUBLE_H(axisX, right, (right - axisX) * 2, right - CS_FRAME_WIDTH);
}

@end


enum CSLayoutVisitStat {
    CSLayoutVisitStatUnvisited,
    CSLayoutVisitStatVisiting,
    CSLayoutVisitStatVisited
};

typedef enum CSLayoutVisitStat CSLayoutVisitStat;

static const void *CSVisitKey = &CSVisitKey;

CG_INLINE void CSMakeViewUnvisited(UIView *view) {
    objc_setAssociatedObject(view, CSVisitKey, nil, OBJC_ASSOCIATION_RETAIN);
}

CG_INLINE void CSMakeViewVisiting(UIView *view) {
    objc_setAssociatedObject(view, CSVisitKey, @(CSLayoutVisitStatVisiting), OBJC_ASSOCIATION_RETAIN);
}

CG_INLINE void CSMakeViewVisited(UIView *view) {
    objc_setAssociatedObject(view, CSVisitKey, @(CSLayoutVisitStatVisited), OBJC_ASSOCIATION_RETAIN);
}


@interface CSLayoutParser : NSObject

@property (nonatomic, strong) NSSet *layouts;

- (NSMutableArray *)viewTopo;

- (void)parse;

@end


@implementation CSLayoutParser {
    NSMutableSet *_viewSet;
    NSMutableArray *_viewTopo;
}

- (NSMutableSet *)viewSet {
    return (_viewSet ?: (_viewSet = [[NSMutableSet alloc] init]));
}

- (NSMutableArray *)viewTopo {
    return (_viewTopo ?: (_viewTopo = [[NSMutableArray alloc] init]));
}

- (void)parse {
    [self makeViewSet];
    [self cleanVisitFlag];
    [self makeViewTopo];
    [self cleanVisitFlag];
}

- (void)makeViewSet {
    for (CSLayout *layout in _layouts) {
        [self makeViewSetVisit:layout.view];
    }
}

- (void)makeViewSetVisit:(UIView *)view {
    CSMakeViewVisiting(view);

    CSLayout *layout = objc_getAssociatedObject(view, CSLayoutKey);

    for (UIView *adjView in [layout dependencies]) {
        NSNumber *stat = objc_getAssociatedObject(adjView, CSVisitKey);
        CSLayoutVisitStat istat = stat ? [stat intValue] : CSLayoutVisitStatUnvisited;

        if (istat == CSLayoutVisitStatUnvisited) {
            [self makeViewSetVisit:adjView];
        } else if (istat == CSLayoutVisitStatVisiting) {
            [self cleanVisitFlag];
            [self cycleError];
        }
    }

    [[self viewSet] addObject:view];

    CSMakeViewVisited(view);
}

- (void)makeViewTopo {
    for (UIView *view in [self viewSet]) {
        NSNumber *stat = objc_getAssociatedObject(view, CSVisitKey);
        CSLayoutVisitStat istat = stat ? [stat intValue] : CSLayoutVisitStatUnvisited;
        if (istat == CSLayoutVisitStatUnvisited) {
            [self makeViewTopoVisit:view];
        }
    }
}

- (void)makeViewTopoVisit:(UIView *)view {
    CSMakeViewVisiting(view);

    CSLayout *layout = objc_getAssociatedObject(view, CSLayoutKey);

    for (UIView *adjView in [layout dependencies]) {
        NSNumber *stat = objc_getAssociatedObject(adjView, CSVisitKey);
        CSLayoutVisitStat istat = stat ? [stat intValue] : CSLayoutVisitStatUnvisited;

        if (istat == CSLayoutVisitStatUnvisited) {
            [self makeViewTopoVisit:adjView];
        } else if (istat == CSLayoutVisitStatVisiting) {
            [self cleanVisitFlag];
            [self cycleError];
        }
    }

    [[self viewTopo] addObject:view];

    CSMakeViewVisited(view);
}

- (void)cleanVisitFlag {
    for (UIView *view in [self viewSet]) {
        CSMakeViewUnvisited(view);
    }

    for (UIView *view in [self viewTopo]) {
        CSMakeViewUnvisited(view);
    }
}

- (void)cycleError {
    [NSException raise:@"CSLayoutCycleException" format:@"Layout can not be solved because of cycle"];
}

@end


@interface CSLayoutSolver : NSObject

@property (nonatomic, weak) UIView *view;

- (instancetype)initWithView:(UIView *)view;

- (void)solve;

@end


@implementation CSLayoutSolver

- (instancetype)initWithView:(UIView *)view {
    self = [super init];

    if (self) _view = view;

    return self;
}

- (void)solve {
    NSArray *subviews = [self.view subviews];

    NSMutableSet *layouts = [[NSMutableSet alloc] init];

    for (UIView *subview in subviews) {
        CSLayout *layout = objc_getAssociatedObject(subview, CSLayoutKey);

        if (layout) {
            [layouts addObject:layout];
        }
    }

    CSLayoutParser *parser = [[CSLayoutParser alloc] init];

    parser.layouts = layouts;

    [parser parse];

    for (UIView *view in [parser viewTopo]) {
        if (view == _view) continue;

        CSLayout *layout = objc_getAssociatedObject(view, CSLayoutKey);

        [layout startLayout];
    }
}

@end


@interface CSLayoutDriver : NSObject

+ (instancetype)layoutDriverOfView:(UIView *)view;

@property (nonatomic, weak) UIView *view;
@property (nonatomic, weak) Class originClass;
@property (nonatomic, weak) Class driverClass;

@property (nonatomic, strong) CSLayoutSolver *solver;

- (void)layoutSubviews;

@end


static Class cs_driver_class(id self, SEL _cmd) {
    CSLayoutDriver *layoutDriver = objc_getAssociatedObject(self, CSLayoutDriverKey);

    return layoutDriver.originClass;
}

static void cs_layout_subviews(id self, SEL _cmd) {
    CSLayoutDriver *layoutDriver = [CSLayoutDriver layoutDriverOfView:self];

    Class superCls = class_getSuperclass(layoutDriver.driverClass);
    vIMP  superImp = (vIMP)class_getMethodImplementation(superCls, _cmd);

    superImp(self, _cmd);

    [layoutDriver layoutSubviews];
}

static Class cs_create_driver_class(UIView *view) {
    Class driverClass = Nil;

    char *clsname = NULL;
    static const char *fmt = "CSLayoutDriverView_%p_%u";

    while (driverClass == Nil) {
        if (asprintf(&clsname, fmt, view, arc4random()) > 0) {
            driverClass = objc_allocateClassPair(object_getClass(view), clsname, 0);
            free(clsname);
        }
    }

    objc_registerClassPair(driverClass);

    class_addMethod(driverClass, @selector(layoutSubviews), (IMP)cs_layout_subviews, "v@:");
    class_addMethod(driverClass, @selector(class), (IMP)cs_driver_class, "#@:");

    return driverClass;
}


@implementation CSLayoutDriver

+ (instancetype)layoutDriverOfView:(UIView *)view {
    CSLayoutDriver *layoutDriver = objc_getAssociatedObject(view, CSLayoutDriverKey);

    if (!layoutDriver) {
        Class driverClass = cs_create_driver_class(view);

        layoutDriver = [[CSLayoutDriver alloc] init];

        layoutDriver.view = view;
        layoutDriver.originClass = [view class];
        layoutDriver.driverClass = driverClass;

        objc_setAssociatedObject(view, CSLayoutDriverKey, layoutDriver, OBJC_ASSOCIATION_RETAIN);
        object_setClass(view, driverClass);
    }

    return layoutDriver;
}

- (CSLayoutSolver *)solver {
    return (_solver ?: (_solver = [[CSLayoutSolver alloc] initWithView:_view]));
}

- (void)layoutSubviews {
    [self.solver solve];
}

- (void)dealloc {
    objc_disposeClassPair(self.driverClass);
}

@end


#define CSCOORD_MAKE(bound, expr)                    \
({                                                   \
    __weak UIView *__view = _view;                   \
                                                     \
    CSCoord *coord = [[CSCoord alloc] init];         \
                                                     \
    coord.view = (bound);                            \
    coord.coordBlock = ^float(CSLayoutRule *rule) {  \
        UIView *view = __view;                       \
                                                     \
        return (expr);                               \
    };                                               \
                                                     \
    coord;                                           \
})

#define CSLAYOUT_ADD_RULE(var, dir_)            \
do {                                            \
    _##var = (var);                             \
    NSString *name = @#var;                     \
                                                \
    CSLayoutRule *rule =                        \
    [CSLayoutRule layoutRuleWithView:_view      \
        name:name                               \
        coord:[CSCoord coordWithObject:_##var]  \
        dir:CSLayoutDir##dir_];                 \
                                                \
    [self.ruleHub dir_##AddRule:rule];          \
} while (0)

#define CSLAYOUT_ADD_RULE_MAP(var, dir_)        \
do {                                            \
    _##var = (var);                             \
    NSString *name = @#var;                     \
                                                \
    CSLayoutRule *rule =                        \
    [CSLayoutRule layoutRuleWithView:_view      \
        name:name                               \
        coord:[CSCoord coordWithObject:_##var]  \
        dir:CSLayoutDir##dir_];                 \
                                                \
    [self.ruleMap setObject:rule forKey:name];  \
} while (0)

static Class cs_layout_class(id self, SEL _cmd) {
    CSLayout *layout = objc_getAssociatedObject(self, CSLayoutKey);

    return layout.originClass;
}

static void cs_did_move_to_superview(id self, SEL _cmd) {
    CSLayout *layout = [CSLayout layoutOfView:self];

    Class superCls = class_getSuperclass(layout.layoutClass);
    vIMP  superImp = (vIMP)class_getMethodImplementation(superCls, _cmd);

    superImp(self, _cmd);

    [layout updateLayoutDriver];
}

static Class cs_create_layout_class(UIView *view) {
    Class layoutClass = Nil;

    char *clsname = NULL;
    static const char *fmt = "CSLayoutView_%p_%u";

    while (layoutClass == Nil) {
        if (asprintf(&clsname, fmt, view, arc4random()) > 0) {
            layoutClass = objc_allocateClassPair(object_getClass(view), clsname, 0);
            free(clsname);
        }
    }

    objc_registerClassPair(layoutClass);

    class_addMethod(layoutClass, @selector(didMoveToSuperview), (IMP)cs_did_move_to_superview, "v@:");
    class_addMethod(layoutClass, @selector(class), (IMP)cs_layout_class, "#@:");

    return layoutClass;
}


@implementation CSLayout

+ (instancetype)layoutOfView:(UIView *)view {
    if ([view isKindOfClass:[UIView class]]) {
        CSLayout *layout = objc_getAssociatedObject(view, CSLayoutKey);

        if (!layout) {
            Class layoutClass = cs_create_layout_class(view);

            layout = [[CSLayout alloc] init];

            layout.view = view;
            layout.originClass = [view class];
            layout.layoutClass = layoutClass;

            [layout updateLayoutDriver];

            objc_setAssociatedObject(view, CSLayoutKey, layout, OBJC_ASSOCIATION_RETAIN);
            object_setClass(view, layoutClass);
        }

        return layout;
    }

    return nil;
}

- (void)updateLayoutDriver {
    if (_view.superview) {
        [CSLayoutDriver layoutDriverOfView:_view.superview];
    }
}

- (NSSet *)dependencies {
    NSMutableSet *set = [[NSMutableSet alloc] init];

    for (CSLayoutRule *rule in _ruleHub.vRules) {
        [set addObject:(rule.coord.view ?: _view.superview)];
    }

    for (CSLayoutRule *rule in _ruleHub.hRules) {
        [set addObject:(rule.coord.view ?: _view.superview)];
    }

    for (CSLayoutRule *rule in [_ruleMap allValues]) {
        [set addObject:(rule.coord.view ?: _view.superview)];
    }

    return set;
}

- (void)solveRules:(NSArray *)rules {
    CSLayoutRulesSolver *solver = [[CSLayoutRulesSolver alloc] init];

    solver.view = _view;

    NSMutableString *selStr = [NSMutableString stringWithString:@"solve"];

    for (CSLayoutRule *rule in rules) {
        [selStr appendString:[rule.name capitalizedString]];
    }

    [selStr appendString:@":"];

    SEL sel = NSSelectorFromString(selStr);
    CGRect (*imp)(id, SEL, NSArray *) = (void *)[solver methodForSelector:sel];

    _frame = imp(solver, sel, rules);

    [self checkBounds];
}

- (void)checkBounds {
    CGSize size = _frame.size;

    CGFloat minWidth = CS_MM_RAW_VALUE(self, minWidth);

    if (CS_VALID_DIM(minWidth) && size.width < minWidth) {
        size.width = minWidth;
    }

    CGFloat maxWidth = CS_MM_RAW_VALUE(self, maxWidth);

    if (CS_VALID_DIM(maxWidth) && size.width > maxWidth) {
        size.width = maxWidth;
    }

    CGFloat minHeight = CS_MM_RAW_VALUE(self, minHeight);

    if (CS_VALID_DIM(minHeight) && size.height < minHeight) {
        size.height = minHeight;
    }

    CGFloat maxHeight = CS_MM_RAW_VALUE(self, maxHeight);

    if (CS_VALID_DIM(maxHeight) && size.height > maxHeight) {
        size.height = maxHeight;
    }

    _frame.size = size;
}

- (void)startLayout {
    _frame = _view.frame;

    [self checkBounds];

    if ([_ruleHub.vRules count]) {
        [self solveRules:_ruleHub.vRules];
    }

    if ([_ruleHub.hRules count]) {
        [self solveRules:_ruleHub.hRules];
    }

    [self checkBounds];

    if (!CGRectEqualToRect(_frame, _view.frame)) {
        _view.frame = _frame;
    }
}

- (void)setMinWidth:(id)minWidth {
    CSLAYOUT_ADD_RULE_MAP(minWidth, h);
}

- (void)setMaxWidth:(id)maxWidth {
    CSLAYOUT_ADD_RULE_MAP(maxWidth, h);
}

- (void)setMinHeight:(id)minHeight {
    CSLAYOUT_ADD_RULE_MAP(minHeight, v);
}

- (void)setMaxHeight:(id)maxHeight {
    CSLAYOUT_ADD_RULE_MAP(maxHeight, v);
}

- (void)setTt:(id)tt {
    CSLAYOUT_ADD_RULE(tt, v);
}

- (void)setTb:(id)tb {
    _tb = tb;

    CSCoord *tbCoord = [CSCoord coordWithObject:tb];
    CSCoord *ttCoord = tbCoord ? CSCOORD_MAKE(tbCoord.view, CS_SUPERVIEW_HEIGHT - tbCoord.coordBlock(rule)) : nil;

    [self setTt:ttCoord];
}

- (void)setLl:(id)ll {
    CSLAYOUT_ADD_RULE(ll, h);
}

- (void)setLr:(id)lr {
    _lr = lr;

    CSCoord *lrCoord = [CSCoord coordWithObject:lr];
    CSCoord *llCoord = lrCoord ? CSCOORD_MAKE(lrCoord.view, CS_SUPERVIEW_WIDTH - lrCoord.coordBlock(rule)) : nil;

    [self setLl:llCoord];
}

- (void)setBb:(id)bb {
    _bb = bb;

    CSCoord *bbCoord = [CSCoord coordWithObject:bb];
    CSCoord *btCoord = bbCoord ? CSCOORD_MAKE(bbCoord.view, CS_SUPERVIEW_HEIGHT - bbCoord.coordBlock(rule)) : nil;

    [self setBt:btCoord];
}

- (void)setBt:(id)bt {
    CSLAYOUT_ADD_RULE(bt, v);
}

- (void)setRr:(id)rr {
    _rr = rr;

    CSCoord *rrCoord = [CSCoord coordWithObject:rr];
    CSCoord *rlCoord = rrCoord ? CSCOORD_MAKE(rrCoord.view, CS_SUPERVIEW_WIDTH - rrCoord.coordBlock(rule)) : nil;

    [self setRl:rlCoord];
}

- (void)setRl:(id)rl {
    CSLAYOUT_ADD_RULE(rl, h);
}

- (void)setCt:(id)ct {
    CSLAYOUT_ADD_RULE(ct, v);
}

- (void)setCl:(id)cl {
    CSLAYOUT_ADD_RULE(cl, h);
}

- (CSLayoutRuleHub *)ruleHub {
    return (_ruleHub ?: (_ruleHub = [[CSLayoutRuleHub alloc] init]));
}

- (NSMutableDictionary *)ruleMap {
    return (_ruleMap ?: (_ruleMap = [[NSMutableDictionary alloc] init]));
}

- (void)dealloc {
    objc_disposeClassPair(self.layoutClass);
}

@end


@implementation CSCoord

+ (CSCoord *)coordWithNumber:(NSNumber *)number {
    CSCoord *coord = [[CSCoord alloc] init];

    float value = [number floatValue];

    coord.coordBlock = ^float(CSLayoutRule *rule) {
        return value;
    };

    return coord;
}

+ (CSCoord *)coordWithPercentOffset:(CSPercentOffset *)object {
    CSCoord *coord = [[CSCoord alloc] init];

    float percent = [object percent] / 100;
    float offset = [object offset];

    coord.coordBlock = ^float(CSLayoutRule *rule) {
        UIView *view = rule.view;
        CGFloat size = (rule.dir == CSLayoutDirv ? CS_SUPERVIEW_HEIGHT : CS_SUPERVIEW_WIDTH);

        return size * percent + offset;
    };

    return coord;
}

+ (instancetype)coordWithObject:(id)object {
    CSCoord *coord = nil;

    if ([object isKindOfClass:[NSNumber class]]) {
        coord = [self coordWithNumber:object];
    } else if ([object isKindOfClass:[CSPercentOffset class]]) {
        coord = [self coordWithPercentOffset:object];
    } else if ([object isKindOfClass:[CSCoord class]]) {
        coord = object;
    }

    return coord;
}

- (instancetype)add:(float)value {
    CSCoord *coord = [[CSCoord alloc] init];

    __weak CSCoord *that = self;

    coord.view = _view;
    coord.coordBlock = ^float(CSLayoutRule *rule) {
        CSCoord *this = that;
        return this.coordBlock(rule) + value;
    };

    return coord;
}

- (instancetype)times:(float)value {
    CSCoord *coord = [[CSCoord alloc] init];

    __weak CSCoord *that = self;

    coord.view = _view;
    coord.coordBlock = ^float(CSLayoutRule *rule) {
        CSCoord *this = that;
        return this.coordBlock(rule) * value;
    };

    return coord;
}

@end


@interface CSCoords ()

@property (nonatomic, weak) UIView *view;

@property (nonatomic, strong) CSCoord *width;
@property (nonatomic, strong) CSCoord *height;

@property (nonatomic, strong) CSCoord *tt;
@property (nonatomic, strong) CSCoord *tb;

@property (nonatomic, strong) CSCoord *ll;
@property (nonatomic, strong) CSCoord *lr;

@property (nonatomic, strong) CSCoord *bb;
@property (nonatomic, strong) CSCoord *bt;

@property (nonatomic, strong) CSCoord *rr;
@property (nonatomic, strong) CSCoord *rl;

@property (nonatomic, strong) CSCoord *ct;
@property (nonatomic, strong) CSCoord *cl;

@end


#define CS_VIEW_TOP    (view.frame.origin.y)
#define CS_VIEW_LEFT   (view.frame.origin.x)
#define CS_VIEW_WIDTH  (view.bounds.size.width)
#define CS_VIEW_HEIGHT (view.bounds.size.height)

#define LAZY_LOAD_COORD(ivar, expr) (ivar ?: (ivar = CSCOORD_MAKE(_view, expr)))


@implementation CSCoords

+ (instancetype)coordsOfView:(UIView *)view {
    static const void *coordsKey = &coordsKey;

    if ([view isKindOfClass:[UIView class]]) {
        CSCoords *coords = objc_getAssociatedObject(view, coordsKey);

        if (!coords) {
            coords = [[CSCoords alloc] init];

            coords.view = view;

            objc_setAssociatedObject(view, coordsKey, coords, OBJC_ASSOCIATION_RETAIN);
        }

        return coords;
    }

    return nil;
}

- (CSCoord *)tt {
    return LAZY_LOAD_COORD(_tt, CS_VIEW_TOP);
}

- (CSCoord *)tb {
    return LAZY_LOAD_COORD(_tb, CS_SUPERVIEW_HEIGHT - CS_VIEW_TOP);
}

- (CSCoord *)ll {
    return LAZY_LOAD_COORD(_ll, CS_VIEW_LEFT);
}

- (CSCoord *)lr {
    return LAZY_LOAD_COORD(_lr, CS_SUPERVIEW_WIDTH - CS_VIEW_LEFT);
}

- (CSCoord *)bb {
    return LAZY_LOAD_COORD(_bb, CS_SUPERVIEW_HEIGHT - CS_VIEW_TOP - CS_VIEW_HEIGHT);
}

- (CSCoord *)bt {
    return LAZY_LOAD_COORD(_bt, CS_VIEW_TOP + CS_VIEW_HEIGHT);
}

- (CSCoord *)rr {
    return LAZY_LOAD_COORD(_rr, CS_SUPERVIEW_WIDTH - CS_VIEW_LEFT - CS_VIEW_WIDTH);
}

- (CSCoord *)rl {
    return LAZY_LOAD_COORD(_rl, CS_VIEW_LEFT + CS_VIEW_WIDTH);
}

- (CSCoord *)ct {
    return LAZY_LOAD_COORD(_ct, CS_VIEW_TOP + CS_VIEW_HEIGHT / 2);
}

- (CSCoord *)cl {
    return LAZY_LOAD_COORD(_cl, CS_VIEW_LEFT + CS_VIEW_WIDTH / 2);
}

- (CSCoord *)width {
    return LAZY_LOAD_COORD(_width, CS_VIEW_WIDTH);
}

- (CSCoord *)height {
    return LAZY_LOAD_COORD(_height, CS_VIEW_HEIGHT);
}

@end


@implementation CSPercentOffset {
    float _percent;
    float _offset;
}

- (instancetype)initWithPercent:(float)percent offset:(float)offset {
    self = [super init];

    if (self) {
        _percent = percent;
        _offset = offset;
    }

    return self;
}

- (float)percent {
    return _percent;
}

- (float)offset {
    return _offset;
}

@end
