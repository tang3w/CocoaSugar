// CSEigen.m
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

#import "CSEigen.h"
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>


@interface CSEigen ()

@property (atomic, weak) Class eigenClass;
@property (atomic, assign) OSSpinLock *disposingLock;

@end


static SEL deallocSel = NULL;
static const void *classKey = &classKey;

static inline Class cs_class(id self, SEL _cmd) {
    return objc_getAssociatedObject(self, classKey);
}

static inline BOOL cs_responds_to_selector(id self, SEL _cmd, SEL sel) {
    return class_respondsToSelector([CSEigen eigenOfObject:self].eigenClass, sel);
}

static inline Class cs_create_eigen_class(NSObject *object) {
    Class eigenClass = Nil;

    char *clsname = NULL;
    static const char *fmt = "CSEigen_%s_%p_%u";

    while (eigenClass == Nil) {
        if (asprintf(&clsname, fmt, class_getName([object class]), object, arc4random()) > 0) {
            eigenClass = objc_allocateClassPair(object_getClass(object), clsname, 0);
            free(clsname);
        }
    }

    objc_registerClassPair(eigenClass);

    class_addMethod(eigenClass, @selector(class), (IMP)cs_class, "#@:");
    class_addMethod(eigenClass, @selector(respondsToSelector:), (IMP)cs_responds_to_selector, "c@::");

    return eigenClass;
}

static inline void cs_dispose_eigen_class(Class eigenClass) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(eigenClass, &count);

    for (int i = 0; i < count; i++) {
        imp_removeBlock(method_getImplementation(methods[i]));
    }

    objc_disposeClassPair(eigenClass);

    free(methods);
}


@implementation CSEigen

+ (void)initialize {
    deallocSel = NSSelectorFromString(@"dealloc");
}

+ (NSMutableArray *)slotsOfObject:(NSObject *)object {
    static const void *slotsKey = &slotsKey;

    NSMutableArray *slots = objc_getAssociatedObject(object, slotsKey);

    if (!slots) {
        slots = [[NSMutableArray alloc] init];

        objc_setAssociatedObject(object, slotsKey, slots, OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(object, classKey, [object class], OBJC_ASSOCIATION_ASSIGN);
    }

    return slots;
}

+ (instancetype)eigenOfObject:(NSObject *)object {
    CSEigen *eigen = nil;

    if (object) {
        eigen = [[CSEigen alloc] init];

        Class eigenClass = cs_create_eigen_class(object);
        eigen.eigenClass = eigenClass;

        [[self slotsOfObject:object] addObject:eigen];

        object_setClass(object, eigenClass);
    }

    return eigen;
}

- (void)setMethod:(SEL)name types:(const char *)types block:(id)block {
    IMP imp = NULL;

    if (sel_isEqual(name, deallocSel)) {
        OSSpinLock *disposingLock = _disposingLock;

        if (!disposingLock) {
            disposingLock = (OSSpinLock *)malloc(sizeof(OSSpinLock));
            *disposingLock = OS_SPINLOCK_INIT;
            _disposingLock = disposingLock;
        }

        imp = imp_implementationWithBlock(^(id object) {
            OSSpinLockLock(disposingLock);
            ((void(^)(id))block)(object);
            OSSpinLockUnlock(disposingLock);
        });
    } else {
        imp = imp_implementationWithBlock(block);
    }

    class_replaceMethod(self.eigenClass, name, imp, types);
}

- (CSIMP)superImp:(SEL)name {
    Method method = class_getInstanceMethod(class_getSuperclass(self.eigenClass), name);

    return method != NULL ? (CSIMP)method_getImplementation(method) : NULL;
}

- (void)dealloc {
    Class eigenClass = self.eigenClass;
    OSSpinLock *disposingLock = self.disposingLock;

    if (disposingLock) {
        dispatch_queue_t queue = [NSThread isMainThread] ?
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) :
        dispatch_get_main_queue();

        dispatch_async(queue, ^{
            OSSpinLockLock(disposingLock);
            cs_dispose_eigen_class(eigenClass);
            OSSpinLockUnlock(disposingLock);

            free(disposingLock);
        });
    } else {
        cs_dispose_eigen_class(eigenClass);
    }
}

@end
