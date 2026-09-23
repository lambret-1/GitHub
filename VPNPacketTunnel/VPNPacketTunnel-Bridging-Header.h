//
//  VPNPacketTunnel-Bridging-Header.h
//  VPNPacketTunnel
//
//  用途：桥接头文件，导入 Xray 核心 C API
//  说明：Xray.xcframework 是 Go 编译的静态库，通过 C 接口与 Swift 交互
//

#ifndef VPNPacketTunnel_Bridging_Header_h
#define VPNPacketTunnel_Bridging_Header_h

// 导入 Xray 核心头文件
#import "libxray.h"

#endif /* VPNPacketTunnel_Bridging_Header_h */
