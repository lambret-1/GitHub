//
//  SafeKVC.m
//  VPNPacketTunnel
//

#import "SafeKVC.h"

id safe_valueForKeyPath(NSString *keyPath, id object) {
    if (keyPath == nil || object == nil) {
        return nil;
    }
    @try {
        return [object valueForKeyPath:keyPath];
    } @catch (NSException *exception) {
        // 键路径不存在或其他 KVC 异常，返回 nil 而非崩溃
        return nil;
    }
}
