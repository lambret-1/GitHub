//
//  SafeKVC.m
//  VPNPacketTunnel
//

#import "SafeKVC.h"
#import <objc/runtime.h>

id safe_valueForKeyPath(NSString *keyPath, id object) {
    if (keyPath == nil || object == nil) {
        return nil;
    }
    @try {
        return [object valueForKeyPath:keyPath];
    } @catch (NSException *exception) {
        return nil;
    }
}

id safe_valueForKey(NSString *key, id object) {
    if (key == nil || object == nil) {
        return nil;
    }
    @try {
        return [object valueForKey:key];
    } @catch (NSException *exception) {
        return nil;
    }
}

NSArray<NSString *> *enumerate_property_names(id object) {
    if (object == nil) {
        return @[];
    }

    NSMutableArray<NSString *> *names = [NSMutableArray array];
    Class cls = [object class];

    while (cls != nil && cls != [NSObject class]) {
        unsigned int count = 0;
        objc_property_t *properties = class_copyPropertyList(cls, &count);
        if (properties != NULL) {
            for (unsigned int i = 0; i < count; i++) {
                const char *name = property_getName(properties[i]);
                if (name != NULL) {
                    [names addObject:[NSString stringWithUTF8String:name]];
                }
            }
            free(properties);
        }
        cls = class_getSuperclass(cls);
    }

    return [names sortedArrayUsingSelector:@selector(compare:)];
}

NSArray<NSString *> *enumerate_method_names(id object) {
    if (object == nil) {
        return @[];
    }

    NSMutableArray<NSString *> *names = [NSMutableArray array];
    Class cls = [object class];

    while (cls != nil && cls != [NSObject class]) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        if (methods != NULL) {
            for (unsigned int i = 0; i < count; i++) {
                SEL sel = method_getName(methods[i]);
                const char *name = sel_getName(sel);
                if (name != NULL) {
                    [names addObject:[NSString stringWithUTF8String:name]];
                }
            }
            free(methods);
        }
        cls = class_getSuperclass(cls);
    }

    return [names sortedArrayUsingSelector:@selector(compare:)];
}
