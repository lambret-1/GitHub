//
//  SafeKVC.h
//  VPNPacketTunnel
//
//  用途：安全 KVC 调用工具，捕获 NSUnknownKeyException 等 Objective-C 异常
//  原理：Swift 无法捕获 Objective-C 异常，KVC 路径不存在时会直接崩溃；
//        通过 Objective-C 的 @try/@catch 包裹，返回 nil 而非崩溃
//

#import <Foundation/Foundation.h>

/// 安全地调用 valueForKeyPath:，异常时返回 nil
/// - Parameters:
///   - keyPath: KVC 键路径
///   - object: 目标对象
/// - Returns: 键路径对应的值，异常或不存在时返回 nil
id _Nullable safe_valueForKeyPath(NSString * _Nonnull keyPath, id _Nonnull object);
