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

@property (atomic, unsafe_unretained) Class eigenClass;

- (void)dispose;

@end


@interface CSEigenSlots : NSObject

+ (instancetype)eigenSlotsOfObject:(NSObject *)object;

@property (atomic, readonly) NSMutableArray *slots;
@property (atomic, assign) OSSpinLock *deallocLock;

- (void)addEigen:(CSEigen *)eigen;

@end


static SEL deallocSel = NULL;
static const void *classKey = &classKey;

NS_INLINE
Class cs_class(id self, SEL _cmd) {
    return objc_getAssociatedObject(self, classKey);
}

NS_INLINE
BOOL cs_responds_to_selector(id self, SEL _cmd, SEL sel) {
    return class_respondsToSelector(object_getClass(self), sel);
}

NS_INLINE
Class cs_create_eigen_class(NSObject *object) {
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

NS_INLINE
void cs_dispose_eigen_class(Class eigenClass) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(eigenClass, &count);

    for (int i = 0; i < count; i++) {
        imp_removeBlock(method_getImplementation(methods[i]));
    }

    objc_disposeClassPair(eigenClass);

    if (count > 0) free(methods);
}


@implementation CSEigenSlots

@synthesize slots = _slots;

+ (void)initialize {
    deallocSel = sel_registerName("dealloc");
}

+ (instancetype)eigenSlotsOfObject:(NSObject *)object {
    static const void *eigenSlotsKey = &eigenSlotsKey;

    CSEigenSlots *eigenSlots = objc_getAssociatedObject(object, eigenSlotsKey);

    if (eigenSlots) return eigenSlots;

    eigenSlots = [[CSEigenSlots alloc] init];

    objc_setAssociatedObject(object, eigenSlotsKey, eigenSlots, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(object, classKey, [object class], OBJC_ASSOCIATION_ASSIGN);

    Class rootEigenClass = cs_create_eigen_class(object);

    CSEigen *rootEigen = [[CSEigen alloc] init];

    rootEigen.eigenClass = rootEigenClass;

    [eigenSlots addEigen:rootEigen];

    IMP superDeallocImp = class_getMethodImplementation(object_getClass(object), deallocSel);

    OSSpinLock *deallocLock = (OSSpinLock *)malloc(sizeof(OSSpinLock));

    *deallocLock = OS_SPINLOCK_INIT;

    eigenSlots.deallocLock = deallocLock;

    class_addMethod(rootEigenClass, deallocSel, imp_implementationWithBlock(^(void *self) {
        OSSpinLockLock(deallocLock);
        ((void(*)(id, SEL))superDeallocImp)((__bridge id)self, deallocSel);
        OSSpinLockUnlock(deallocLock);
    }), "v@:");

    object_setClass(object, rootEigenClass);

    return eigenSlots;
}

- (NSMutableArray *)slots {
    @synchronized(self) {
        return _slots ?: (_slots = [[NSMutableArray alloc] init]);
    }
}

- (void)addEigen:(CSEigen *)eigen {
    [self.slots addObject:eigen];
}

- (void)dealloc {
    NSArray *slots = [self.slots copy];
    OSSpinLock *deallocLock = self.deallocLock;

    dispatch_queue_t queue = [NSThread isMainThread] ?
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) :
    dispatch_get_main_queue();

    dispatch_async(queue, ^{
        OSSpinLockLock(deallocLock);
        for (CSEigen *eigen in slots.reverseObjectEnumerator) {
            [eigen dispose];
        }
        OSSpinLockUnlock(deallocLock);
        free(deallocLock);
    });
}

@end


@implementation CSEigen

+ (instancetype)eigenForObject:(NSObject *)object {
    CSEigen *eigen = nil;

    if (object) {
        CSEigenSlots *eigenSlots = [CSEigenSlots eigenSlotsOfObject:object];

        eigen = [[CSEigen alloc] init];

        Class eigenClass = cs_create_eigen_class(object);

        eigen.eigenClass = eigenClass;

        [eigenSlots addEigen:eigen];

        object_setClass(object, eigenClass);
    }

    return eigen;
}

- (void)setMethod:(SEL)sel types:(const char *)types block:(id)block {
    unsigned int count;
    Method *methods = class_copyMethodList(self.eigenClass, &count);

    while (count--) {
        Method method = methods[count];
        if (sel_isEqual(method_getName(method), sel)) {
            imp_removeBlock(method_getImplementation(method));
            break;
        }
    }

    class_replaceMethod(self.eigenClass, sel, imp_implementationWithBlock(block), types);
}

- (CS_IMP)superImp:(SEL)sel {
    Class superCls = class_getSuperclass(self.eigenClass);

    return (CS_IMP)method_getImplementation(class_getInstanceMethod(superCls, sel));
}

- (void)dispose {
    cs_dispose_eigen_class(self.eigenClass);
}

@end
