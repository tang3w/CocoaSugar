// CSSync.m
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

#import "CSSync.h"
#import "CSObserver.h"


@interface CSSync ()

@property (nonatomic, strong) NSArray *objects;

@end


@implementation CSSync

+ (instancetype)syncOfObjects:(NSObject *)firstObject, ... {
    va_list argv;
    va_start(argv, firstObject);

    CSSync *sync = [[CSSync alloc] init];

    NSObject *object = nil;
    NSMutableArray *objects = [NSMutableArray arrayWithObject:firstObject];

    while ((object = va_arg(argv, NSObject *))) {
        [objects addObject:object];
    }

    sync.objects = objects;

    va_end(argv);

    return sync;
}

- (void)syncObj1:(NSObject *)obj1
            obj2:(NSObject *)obj2
        keyPath1:(NSString *)keyPath1
        keyPath2:(NSString *)keyPath2
{
    CSObserver *observer1 = [CSObserver observerForObject:obj1];
    CSObserver *observer2 = [CSObserver observerForObject:obj2];

    [observer1
     addTarget:obj2
     forKeyPath:keyPath2
     options:NSKeyValueObservingOptionNew
     block:^(id obj1, id obj2, NSDictionary *change) {
         id val1 = [obj1 valueForKeyPath:keyPath1];
         id val2 = change[NSKeyValueChangeNewKey];

         if (val1 != val2 && ![val1 isEqual:val2]) {
             [obj1 setValue:val2 forKeyPath:keyPath1];
         }
     }];

    [observer2
     addTarget:obj1
     forKeyPath:keyPath1
     options:NSKeyValueObservingOptionNew
     block:^(id obj2, id obj1, NSDictionary *change) {
         id val2 = [obj2 valueForKeyPath:keyPath2];
         id val1 = change[NSKeyValueChangeNewKey];

         if (val2 != val1 && ![val2 isEqual:val1]) {
             [obj2 setValue:val1 forKeyPath:keyPath2];
         }
     }];
}

- (void)addKeyPaths:(NSString *)firstKeyPath, ... {
    va_list argv;
    va_start(argv, firstKeyPath);

    NSString *keyPath = nil;
    NSMutableArray *keyPaths = [NSMutableArray arrayWithObject:firstKeyPath];

    while ((keyPath = va_arg(argv, NSString *))) {
        [keyPaths addObject:keyPath];
    }

    va_end(argv);

    NSAssert([keyPaths count] >= [self.objects count], @"Too few key paths for objects");

    NSUInteger count = [self.objects count];

    while (--count) {
        [self syncObj1:self.objects[count]
                  obj2:self.objects[count-1]
              keyPath1:keyPaths[count]
              keyPath2:keyPaths[count-1]];
    }
}

@end
