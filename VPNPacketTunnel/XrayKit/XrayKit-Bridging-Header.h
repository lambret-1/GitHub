//
//  XrayKit-Bridging-Header.h
//  XrayKit
//
//  用途：桥接头文件，导入 Xray 核心 C API
//  说明：Xray.xcframework 是 Go 编译的静态库，通过 C 接口与 Swift 交互
//  注意：此桥接头文件属于 XrayKit 动态框架，扩展通过链接 XrayKit 间接使用 Xray
//

#ifndef XrayKit_Bridging_Header_h
#define XrayKit_Bridging_Header_h

// 导入 Xray 核心头文件
#import "libxray.h"

#endif /* XrayKit_Bridging_Header_h */
