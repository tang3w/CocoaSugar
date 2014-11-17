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
        NSObject *object1 = self.objects[count];
        NSObject *object2 = self.objects[count - 1];

        NSString *keyPath1 = keyPaths[count];
        NSString *keyPath2 = keyPaths[count - 1];

        [[CSObserver observerForObject:object1]
         addTarget:object2
         forKeyPath:keyPath2
         options:NSKeyValueObservingOptionNew
         block:^(id object1, id object2, NSDictionary *change) {
             id value1 = [object1 valueForKeyPath:keyPath1];
             id value2 = change[NSKeyValueChangeNewKey];

             if (value1 != value2 && ![value1 isEqual:value2]) {
                 [object1 setValue:value2 forKeyPath:keyPath1];
             }
         }];

        [[CSObserver observerForObject:object2]
         addTarget:object1
         forKeyPath:keyPath1
         options:NSKeyValueObservingOptionNew
         block:^(id object2, id object1, NSDictionary *change) {
             id value2 = [object2 valueForKeyPath:keyPath2];
             id value1 = change[NSKeyValueChangeNewKey];

             if (value2 != value1 && ![value2 isEqual:value1]) {
                 [object2 setValue:value1 forKeyPath:keyPath2];
             }
         }];
    }
}

@end
