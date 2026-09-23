//
//  SignalHandler.c
//  VPNPacketTunnel
//
//  用途：信号处理器，在扩展崩溃时记录崩溃信息到 App Group
//  原理：使用 __attribute__((constructor)) 在库加载时注册信号处理器
//        即使 Swift 代码未执行，也能捕获崩溃信号
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>

// App Group 标识（与 Swift 代码保持一致）
#define APP_GROUP_IDENTIFIER "group.com.github.client"
#define EXTENSION_LOG_KEY "vpn_extension_logs"

/// 崩溃信号处理器
/// - Parameter sig: 信号编号
static void crashSignalHandler(int sig) {
    // 获取当前时间
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", tm_info);

    // 构建崩溃日志
    char log_buffer[1024];
    snprintf(log_buffer, sizeof(log_buffer),
             "[%s] [VPN扩展] ❌ 扩展崩溃！信号: %d (%s)\n",
             time_str, sig,
             sig == SIGABRT ? "SIGABRT" :
             sig == SIGSEGV ? "SIGSEGV" :
             sig == SIGBUS ? "SIGBUS" :
             sig == SIGILL ? "SIGILL" :
             sig == SIGTRAP ? "SIGTRAP" :
             sig == SIGTERM ? "SIGTERM" :
             sig == SIGKILL ? "SIGKILL" : "UNKNOWN");

    // 写入 App Group UserDefaults（通过写入 plist 文件实现）
    // 注意：C 代码无法直接访问 UserDefaults，这里写入到 App Group 目录的文件中
    // Swift 代码会读取这个文件并合并到日志中

    // 获取 App Group 目录路径
    // 注意：C 代码无法直接获取 App Group 容器路径
    // 这里使用环境变量或固定路径
    char log_path[512];

    // 尝试多个可能的 App Group 路径
    // iOS 上 App Group 容器路径通常是：
    // /private/var/mobile/Containers/Shared/AppGroup/<UUID>/
    // 我们无法直接知道 UUID，所以写入到 tmp 目录，Swift 代码会读取
    snprintf(log_path, sizeof(log_path), "/tmp/vpn_extension_crash.log");

    // 追加写入崩溃日志
    FILE *fp = fopen(log_path, "a");
    if (fp != NULL) {
        fputs(log_buffer, fp);
        fclose(fp);
    }

    // 重新注册默认信号处理器，让系统正常终止进程
    signal(sig, SIG_DFL);
    raise(sig);
}

/// 构造函数：在库加载时自动执行（早于 Swift 代码）
__attribute__((constructor))
static void registerSignalHandlers(void) {
    // 注册所有可能导致崩溃的信号
    signal(SIGABRT, crashSignalHandler);  //  abort() 调用
    signal(SIGSEGV, crashSignalHandler);  //  段错误（非法内存访问）
    signal(SIGBUS, crashSignalHandler);   //  总线错误
    signal(SIGILL, crashSignalHandler);   //  非法指令
    signal(SIGTRAP, crashSignalHandler);  //  断点/陷阱
    signal(SIGTERM, crashSignalHandler);  //  终止请求
    // SIGKILL 无法捕获
}
