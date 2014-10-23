// CSObserver.m
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

#import "CSObserver.h"
#import <objc/runtime.h>

typedef void (*vIMP)(id, SEL);


@interface CSObserver ()

@property (nonatomic, weak) NSObject *object;

@end


@interface CSObservation : NSObject

@property (nonatomic, unsafe_unretained) NSObject *object;
@property (nonatomic, unsafe_unretained) NSObject *target;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, assign) NSKeyValueObservingOptions options;
@property (nonatomic, copy) CSObserverBlock block;

- (void)deregister;

@end


static SEL deallocSel = NULL;
static const void *classKey = &classKey;
static const void *hookClassKey = &hookClassKey;
static void *csContext = &csContext;

static inline
NSMutableSet *cs_observation_pool(NSObject *object) {
    static const void *CSObservationPoolKey = &CSObservationPoolKey;

    NSMutableSet *observationPool = objc_getAssociatedObject(object, CSObservationPoolKey);

    if (!observationPool) {
        observationPool = [[NSMutableSet alloc] init];

        objc_setAssociatedObject(object, CSObservationPoolKey, observationPool, OBJC_ASSOCIATION_RETAIN);
    }

    return observationPool;
}

static inline
Class cs_class(id self, SEL _cmd) {
    return objc_getAssociatedObject(self, classKey);
}

static inline
void cs_dealloc(void *self, SEL _cmd) {
    for (CSObservation *observation in cs_observation_pool((__bridge id)self)) {
        [observation deregister];
    }

    Class hookClass = objc_getAssociatedObject((__bridge id)self, hookClassKey);

    vIMP superImp = (vIMP)class_getMethodImplementation(class_getSuperclass(hookClass), deallocSel);

    objc_disposeClassPair(hookClass);

    superImp((__bridge id)self, deallocSel);
}

static inline
Class cs_create_hook_class(NSObject *object) {
    Class hookClass = Nil;

    char *clsname = NULL;
    static const char *fmt = "CSObserver_%s_%p_%u";

    while (hookClass == Nil) {
        if (asprintf(&clsname, fmt, class_getName([object class]), object, arc4random()) > 0) {
            hookClass = objc_allocateClassPair(object_getClass(object), clsname, 0);
            free(clsname);
        }
    }

    objc_registerClassPair(hookClass);

    class_addMethod(hookClass, @selector(class), (IMP)cs_class, "#@:");
    class_addMethod(hookClass, deallocSel, (IMP)cs_dealloc, "v@:");

    return hookClass;
}

static inline
void cs_hook_object_if_needed(NSObject *object) {
    static const void *neededKey = &neededKey;

    if (!objc_getAssociatedObject(object, classKey)) {
        Class hookClass = cs_create_hook_class(object);

        objc_setAssociatedObject(object, classKey, [object class], OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(object, hookClassKey, hookClass, OBJC_ASSOCIATION_ASSIGN);

        object_setClass(object, hookClass);
    }
}


@implementation CSObserver

+ (void)initialize {
    deallocSel = NSSelectorFromString(@"dealloc");
}

+ (instancetype)observerForObject:(NSObject *)object {
    static const void *observerKey = &observerKey;

    CSObserver *observer = nil;

    if (object) {
        observer = objc_getAssociatedObject(object, observerKey);

        if (!observer) {
            observer = [[CSObserver alloc] init];

            observer.object = object;

            objc_setAssociatedObject(object, observerKey, observer, OBJC_ASSOCIATION_RETAIN);
        }
    }

    return observer;
}

- (void)addTarget:(NSObject *)target
       forKeyPath:(NSString *)keyPath
          options:(NSKeyValueObservingOptions)options
            block:(CSObserverBlock)block {
    if (target) {
        NSObject *object = self.object;

        cs_hook_object_if_needed(object);
        cs_hook_object_if_needed(target);

        CSObservation *observation = [[CSObservation alloc] init];

        observation.object = object;
        observation.target = target;
        observation.keyPath = keyPath;
        observation.options = options;
        observation.block = block;

        [cs_observation_pool(object) addObject:observation];
        [cs_observation_pool(target) addObject:observation];

        [target addObserver:observation
                 forKeyPath:keyPath
                    options:options
                    context:csContext];
    }
}

- (void)removeTarget:(NSObject *)target forKeyPath:(NSString *)keyPath {
    if (target && keyPath) {
        NSMutableSet *find = [[NSMutableSet alloc] init];

        for (CSObservation *observation in cs_observation_pool(self.object)) {
            if (observation.target == target && [observation.keyPath isEqualToString:keyPath]) {
                [find addObject:observation];
            }
        }

        for (CSObservation *observation in find) {
            [observation deregister];
        }
    } else if (target) {
        [self removeTarget:target];
    } else {
        [self removeTarget:nil];
    }
}

- (void)removeTarget:(NSObject *)target {
    NSMutableSet *find = nil;
    NSMutableSet *observationPool = cs_observation_pool(self.object);

    if (target) {
        find = [[NSMutableSet alloc] init];

        for (CSObservation *observation in observationPool) {
            if (observation.target == target) {
                [find addObject:observation];
            }
        }
    } else {
        find = [observationPool mutableCopy];
    }

    for (CSObservation *observation in find) {
        [observation deregister];
    }
}

@end


@implementation CSObservation

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (context == csContext) {
        self.block(self.object, self.target, change);
    } else {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

- (void)deregister {
    [cs_observation_pool(self.object) removeObject:self];
    [cs_observation_pool(self.target) removeObject:self];
}

- (void)dealloc {
    [self.target removeObserver:self forKeyPath:self.keyPath];
}

@end
