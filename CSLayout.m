// CSLayout.m
//
// Copyright (c) 2014 Tianyong Tang
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
#import "CSEigen.h"
#import "CSLayoutParser.h"

#import <objc/runtime.h>

@class CSLayoutRule;

static const void *CSLayoutKey = &CSLayoutKey;

typedef float(^CSCoordBlock)(CSLayoutRule *);


@interface CSCoord : NSObject

+ (instancetype)coordWithFloat:(float)value;
+ (instancetype)coordWithPercentage:(float)percentage;

@property (nonatomic, strong) NSMutableSet *dependencies;
@property (nonatomic, copy) CSCoordBlock block;

- (instancetype)add:(CSCoord *)other;
- (instancetype)sub:(CSCoord *)other;
- (instancetype)mul:(CSCoord *)other;
- (instancetype)div:(CSCoord *)other;

@end


typedef enum { CSLayoutDirv, CSLayoutDirh } CSLayoutDir;


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


@interface CSCoords : NSObject

+ (instancetype)coordsOfView:(UIView *)view;

@end


@interface CSLayoutRuleHub : NSObject

@property (nonatomic, readonly) NSMutableArray *vRules;
@property (nonatomic, readonly) NSMutableArray *hRules;

- (void)vAddRule:(CSLayoutRule *)rule;
- (void)hAddRule:(CSLayoutRule *)rule;

@end


@interface CSLayout ()

@property (nonatomic, weak) UIView *view;

@property (nonatomic, strong) CSLayoutRuleHub *ruleHub;
@property (nonatomic, strong) NSMutableDictionary *ruleMap;

@property (nonatomic, strong) CSCoord *minw;
@property (nonatomic, strong) CSCoord *maxw;

@property (nonatomic, strong) CSCoord *minh;
@property (nonatomic, strong) CSCoord *maxh;

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

#define CSLAYOUT_SOLVE_SINGLE_H(var, left)   \
do {                                         \
    CSLayoutRule *rule = rules[0];           \
    float var = [[rule coord] block](rule);  \
    UIView *view = _view;                    \
    CGRect frame = CSLAYOUT_FRAME(view);     \
    frame.origin.x = (left);                 \
    return frame;                            \
} while (0)

#define CSLAYOUT_SOLVE_SINGLE_V(var, top)    \
do {                                         \
    CSLayoutRule *rule = rules[0];           \
    float var = [[rule coord] block](rule);  \
    UIView *view = _view;                    \
    CGRect frame = CSLAYOUT_FRAME(view);     \
    frame.origin.y = (top);                  \
    return frame;                            \
} while (0)

#define CSLAYOUT_SOLVE_DOUBLE_H(var1, var2, width_, left)  \
do {                                                       \
    CSLayoutRule *rule0 = rules[0];                        \
    CSLayoutRule *rule1 = rules[1];                        \
    float var1 = [[rule0 coord] block](rule0);             \
    float var2 = [[rule1 coord] block](rule1);             \
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
    float var1 = [[rule0 coord] block](rule0);             \
    float var2 = [[rule1 coord] block](rule1);             \
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
    rule.coord.block(rule) :                     \
    NAN;                                         \
})

#define CS_VALID_DIM(value) (!isnan(value) && (value) >= 0)


@implementation CSLayoutRulesSolver

- (CGFloat)calcWidth:(CGFloat)width {
    CSLayout *layout = objc_getAssociatedObject(_view, CSLayoutKey);

    CGFloat minw = CS_MM_RAW_VALUE(layout, minw);

    if (CS_VALID_DIM(minw) && width < minw) {
        width = minw;
    }

    CGFloat maxw = CS_MM_RAW_VALUE(layout, maxw);

    if (CS_VALID_DIM(maxw) && width > maxw) {
        width = maxw;
    }

    return MAX(width, 0);
}

- (CGFloat)calcHeight:(CGFloat)height {
    CSLayout *layout = objc_getAssociatedObject(_view, CSLayoutKey);

    CGFloat minh = CS_MM_RAW_VALUE(layout, minh);

    if (CS_VALID_DIM(minh) && height < minh) {
        height = minh;
    }

    CGFloat maxh = CS_MM_RAW_VALUE(layout, maxh);

    if (CS_VALID_DIM(maxh) && height > maxh) {
        height = maxh;
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

NS_INLINE
void CSMakeViewUnvisited(UIView *view) {
    objc_setAssociatedObject(view, CSVisitKey, nil, OBJC_ASSOCIATION_RETAIN);
}

NS_INLINE
void CSMakeViewVisiting(UIView *view) {
    objc_setAssociatedObject(view, CSVisitKey, @(CSLayoutVisitStatVisiting), OBJC_ASSOCIATION_RETAIN);
}

NS_INLINE
void CSMakeViewVisited(UIView *view) {
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

+ (instancetype)layoutSolverOfView:(UIView *)view;

@property (nonatomic, weak) UIView *view;

- (void)solve;

@end


@implementation CSLayoutSolver

+ (instancetype)layoutSolverOfView:(UIView *)view {
    static const void *layoutSolverKey = &layoutSolverKey;

    CSLayoutSolver *solver = objc_getAssociatedObject(view, layoutSolverKey);

    if (!solver) {
        solver = [[CSLayoutSolver alloc] init];

        solver.view = view;

        objc_setAssociatedObject(view, layoutSolverKey, solver, OBJC_ASSOCIATION_RETAIN);
    }

    return solver;
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


#define CSCOORD_MAKE(dependencies_, expr)       \
({                                              \
    __weak UIView *__view = _view;              \
                                                \
    CSCoord *coord = [[CSCoord alloc] init];    \
                                                \
    coord.dependencies = (dependencies_);       \
    coord.block = ^float(CSLayoutRule *rule) {  \
        UIView *view = __view;                  \
                                                \
        return (expr);                          \
    };                                          \
                                                \
    coord;                                      \
})

#define CSLAYOUT_ADD_RULE(var, dir_)        \
do {                                        \
    _##var = (var);                         \
    NSString *name = @#var;                 \
                                            \
    CSLayoutRule *rule =                    \
    [CSLayoutRule layoutRuleWithView:_view  \
        name:name                           \
        coord:_##var                        \
        dir:CSLayoutDir##dir_];             \
                                            \
    [self.ruleHub dir_##AddRule:rule];      \
} while (0)

#define CSLAYOUT_ADD_RULE_MAP(var, dir_)    \
do {                                        \
    _##var = (var);                         \
    NSString *name = @#var;                 \
                                            \
    CSLayoutRule *rule =                    \
    [CSLayoutRule layoutRuleWithView:_view  \
        name:name                           \
        coord:_##var                        \
        dir:CSLayoutDir##dir_];             \
                                            \
    self.ruleMap[name] = rule;              \
} while (0)

NS_INLINE
void cs_initialize_layout_if_needed(UIView *view) {
    static const void *eigenKey = &eigenKey;

    if (objc_getAssociatedObject(view, eigenKey)) return;

    __weak CSEigen *eigen = [CSEigen eigenForObject:view];

    objc_setAssociatedObject(view, eigenKey, eigen, OBJC_ASSOCIATION_RETAIN);

    SEL selector = @selector(didMoveToSuperview);

    [eigen setMethod:selector types:"v@:" block:^(UIView *view) {
        ((CS_IMP_V)[eigen superImp:selector])(view, selector);

        [[CSLayout layoutOfView:view] updateLayoutDriver];
    }];
}

NS_INLINE
void cs_initialize_driver_if_needed(UIView *view) {
    static const void *eigenKey = &eigenKey;

    if (objc_getAssociatedObject(view, eigenKey)) return;

    __weak CSEigen *eigen = [CSEigen eigenForObject:view];

    objc_setAssociatedObject(view, eigenKey, eigen, OBJC_ASSOCIATION_RETAIN);

    SEL selector = @selector(layoutSubviews);

    [eigen setMethod:selector types:"v@:" block:^(UIView *view) {
        ((CS_IMP_V)[eigen superImp:selector])(view, selector);

        [[CSLayoutSolver layoutSolverOfView:(view)] solve];
    }];
}


@implementation CSLayout

+ (instancetype)layoutOfView:(UIView *)view {
    if (![view isKindOfClass:[UIView class]]) return nil;

    CSLayout *layout = objc_getAssociatedObject(view, CSLayoutKey);

    if (!layout) {
        layout = [[CSLayout alloc] init];

        layout.view = view;

        objc_setAssociatedObject(view, CSLayoutKey, layout, OBJC_ASSOCIATION_RETAIN);

        cs_initialize_layout_if_needed(view);

        [layout updateLayoutDriver];
    }

    return layout;
}

- (void)addRule:(NSString *)format, ... {
    va_list argv;
    va_start(argv, format);

    NSArray *subRules = [format componentsSeparatedByString:@","];

    for (NSString *subRule in subRules) {
        int argc = 0;
        char *expr = (char *)[subRule cStringUsingEncoding:NSASCIIStringEncoding];
        CSLAYOUT_AST *ast = cslayout_parse_rule(expr, &argc);

        if (ast != NULL) {
            NSMutableArray *views = nil;

            if (argc > 0) {
                views = [[NSMutableArray alloc] init];
                while (argc--) [views addObject:va_arg(argv, UIView *)];
            }

            NSMutableSet *keeper = [NSMutableSet set];

            [self parseAst:ast withViews:views keeper:keeper];

            cslayout_destroy_ast(ast);
        } else {
            break;
        }
    }

    va_end(argv);
}

- (void)parseAst:(CSLAYOUT_AST *)ast withViews:(NSMutableArray *)views keeper:(NSMutableSet *)keeper {
    if (ast == NULL) return;

    [self parseAst:ast->l withViews:views keeper:keeper];
    [self parseAst:ast->r withViews:views keeper:keeper];

    switch (ast->node_type) {
    case CSLAYOUT_TOKEN_ATTR: {
        NSString *key = [NSString stringWithCString:ast->value.coord encoding:NSASCIIStringEncoding];
        CSCoord *coord = [self valueForKey:key];

        if (!coord) {
            coord = [CSCoord coordWithFloat:0];
            [keeper addObject:coord];
        }

        ast->data = (__bridge void *)(coord);
    }
        break;

    case CSLAYOUT_TOKEN_NUMBER: {
        CSCoord *coord = [CSCoord coordWithFloat:ast->value.number];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case CSLAYOUT_TOKEN_PERCENTAGE: {
        CSCoord *coord = [CSCoord coordWithPercentage:ast->value.percentage];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case CSLAYOUT_TOKEN_COORD: {
        NSString *key = [NSString stringWithCString:ast->value.coord encoding:NSASCIIStringEncoding];
        CSCoord *coord = [[CSCoords coordsOfView:[views firstObject]] valueForKey:key];

        ast->data = (__bridge void *)(coord);

        [views removeObjectAtIndex:0];
    }
        break;

    case '+': {
        CSCoord *coord1 = (__bridge CSCoord *)(ast->l->data);
        CSCoord *coord2 = (__bridge CSCoord *)(ast->r->data);

        CSCoord *coord = [coord1 add:coord2];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case '-': {
        CSCoord *coord1 = (__bridge CSCoord *)(ast->l->data);
        CSCoord *coord2 = (__bridge CSCoord *)(ast->r->data);

        CSCoord *coord = [coord1 sub:coord2];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case '*': {
        CSCoord *coord1 = (__bridge CSCoord *)(ast->l->data);
        CSCoord *coord2 = (__bridge CSCoord *)(ast->r->data);

        CSCoord *coord = [coord1 mul:coord2];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;
    case '/': {
        CSCoord *coord1 = (__bridge CSCoord *)(ast->l->data);
        CSCoord *coord2 = (__bridge CSCoord *)(ast->r->data);

        CSCoord *coord = [coord1 div:coord2];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case '=': {
        CSCoord *coord = (__bridge CSCoord *)(ast->r->data);
        NSString *key = [NSString stringWithCString:ast->l->value.coord encoding:NSASCIIStringEncoding];

        [self setValue:coord forKey:key];

        ast->data = (__bridge void *)(coord);
    }
        break;

    default:
        break;
    }
}

- (void)updateLayoutDriver {
    if (_view.superview) {
        cs_initialize_driver_if_needed(_view.superview);
    }
}

- (NSSet *)dependencies {
    NSMutableSet *set = [[NSMutableSet alloc] init];

    for (CSLayoutRule *rule in _ruleHub.vRules) {
        [set unionSet:rule.coord.dependencies];
    }

    for (CSLayoutRule *rule in _ruleHub.hRules) {
        [set unionSet:rule.coord.dependencies];
    }

    for (CSLayoutRule *rule in [_ruleMap allValues]) {
        [set unionSet:rule.coord.dependencies];
    }

    if ([set containsObject:[NSNull null]]) {
        [set removeObject:[NSNull null]];
        [set addObject:_view.superview];
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

    CGFloat minw = CS_MM_RAW_VALUE(self, minw);

    if (CS_VALID_DIM(minw) && size.width < minw) {
        size.width = minw;
    }

    CGFloat maxw = CS_MM_RAW_VALUE(self, maxw);

    if (CS_VALID_DIM(maxw) && size.width > maxw) {
        size.width = maxw;
    }

    CGFloat minh = CS_MM_RAW_VALUE(self, minh);

    if (CS_VALID_DIM(minh) && size.height < minh) {
        size.height = minh;
    }

    CGFloat maxh = CS_MM_RAW_VALUE(self, maxh);

    if (CS_VALID_DIM(maxh) && size.height > maxh) {
        size.height = maxh;
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

- (void)setMinw:(CSCoord *)minw {
    CSLAYOUT_ADD_RULE_MAP(minw, h);
}

- (void)setMaxw:(CSCoord *)maxw {
    CSLAYOUT_ADD_RULE_MAP(maxw, h);
}

- (void)setMinh:(CSCoord *)minh {
    CSLAYOUT_ADD_RULE_MAP(minh, v);
}

- (void)setMaxh:(CSCoord *)maxh {
    CSLAYOUT_ADD_RULE_MAP(maxh, v);
}

- (void)setTt:(CSCoord *)tt {
    CSLAYOUT_ADD_RULE(tt, v);
}

- (void)setTb:(CSCoord *)tb {
    _tb = tb;

    CSCoord *tt = tb ? CSCOORD_MAKE(tb.dependencies, CS_SUPERVIEW_HEIGHT - tb.block(rule)) : nil;

    [self setTt:tt];
}

- (void)setLl:(CSCoord *)ll {
    CSLAYOUT_ADD_RULE(ll, h);
}

- (void)setLr:(CSCoord *)lr {
    _lr = lr;

    CSCoord *ll = lr ? CSCOORD_MAKE(lr.dependencies, CS_SUPERVIEW_WIDTH - lr.block(rule)) : nil;

    [self setLl:ll];
}

- (void)setBb:(CSCoord *)bb {
    _bb = bb;

    CSCoord *bt = bb ? CSCOORD_MAKE(bb.dependencies, CS_SUPERVIEW_HEIGHT - bb.block(rule)) : nil;

    [self setBt:bt];
}

- (void)setBt:(CSCoord *)bt {
    CSLAYOUT_ADD_RULE(bt, v);
}

- (void)setRr:(CSCoord *)rr {
    _rr = rr;

    CSCoord *rl = rr ? CSCOORD_MAKE(rr.dependencies, CS_SUPERVIEW_WIDTH - rr.block(rule)) : nil;

    [self setRl:rl];
}

- (void)setRl:(CSCoord *)rl {
    CSLAYOUT_ADD_RULE(rl, h);
}

- (void)setCt:(CSCoord *)ct {
    CSLAYOUT_ADD_RULE(ct, v);
}

- (void)setCl:(CSCoord *)cl {
    CSLAYOUT_ADD_RULE(cl, h);
}

- (CSLayoutRuleHub *)ruleHub {
    return (_ruleHub ?: (_ruleHub = [[CSLayoutRuleHub alloc] init]));
}

- (NSMutableDictionary *)ruleMap {
    return (_ruleMap ?: (_ruleMap = [[NSMutableDictionary alloc] init]));
}

@end


#define CSCOORD_CALC(expr)                           \
do {                                                 \
    CSCoord *coord = [[CSCoord alloc] init];         \
    NSMutableSet *dependencies = self.dependencies;  \
                                                     \
    [dependencies unionSet:other.dependencies];      \
                                                     \
    coord.dependencies = dependencies;               \
    coord.block = ^float(CSLayoutRule *rule) {       \
        return (expr);                               \
    };                                               \
                                                     \
    return coord;                                    \
} while (0);


@implementation CSCoord

+ (instancetype)coordWithFloat:(float)value {
    CSCoord *coord = [[CSCoord alloc] init];

    coord.dependencies = [NSMutableSet setWithObject:[NSNull null]];
    coord.block = ^float(CSLayoutRule *rule) {
        return value;
    };

    return coord;
}

+ (instancetype)coordWithPercentage:(float)percentage {
    CSCoord *coord = [[CSCoord alloc] init];

    percentage /= 100.0f;

    coord.dependencies = [NSMutableSet setWithObject:[NSNull null]];
    coord.block = ^float(CSLayoutRule *rule) {
        UIView *view = rule.view;
        CGFloat size = (rule.dir == CSLayoutDirv ? CS_SUPERVIEW_HEIGHT : CS_SUPERVIEW_WIDTH);

        return size * percentage;
    };

    return coord;
}

- (instancetype)add:(CSCoord *)other {
    CSCOORD_CALC(self.block(rule) + other.block(rule));
}

- (instancetype)sub:(CSCoord *)other {
    CSCOORD_CALC(self.block(rule) - other.block(rule));
}

- (instancetype)mul:(CSCoord *)other {
    CSCOORD_CALC(self.block(rule) * other.block(rule));
}

- (instancetype)div:(CSCoord *)other {
    CSCOORD_CALC(self.block(rule) / other.block(rule));
}

- (NSMutableSet *)dependencies {
    return _dependencies ?: (_dependencies = [[NSMutableSet alloc] init]);
}

@end


@interface CSCoords ()

@property (nonatomic, weak) UIView *view;

@property (nonatomic, strong) CSCoord *w;
@property (nonatomic, strong) CSCoord *h;

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

#define LAZY_LOAD_COORD(ivar, expr) \
    (ivar ?: (ivar = CSCOORD_MAKE([NSMutableSet setWithObject:_view], expr)))


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

- (CSCoord *)w {
    return LAZY_LOAD_COORD(_w, CS_VIEW_WIDTH);
}

- (CSCoord *)h {
    return LAZY_LOAD_COORD(_h, CS_VIEW_HEIGHT);
}

@end
