//
//  SignalHandler.c
//  VPNPacketTunnel
//
//  用途：C 级信号处理器，在扩展进程被崩溃信号终止前写入崩溃标记
//  原理：__attribute__((constructor)) 在动态链接阶段注册处理器，
//        早于 Swift 运行时初始化，可覆盖 Go/XrayKit 加载期崩溃。
//  说明：崩溃日志写入 /tmp/vpn_extension_crash.log；
//        PacketTunnelProvider 启动时读取并转存到 App Group 文件日志。
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>

/// 崩溃日志临时文件路径（扩展沙盒内，Swift 侧启动时读取）
#define CRASH_LOG_PATH "/tmp/vpn_extension_crash.log"

/// 崩溃信号处理器
/// - Parameter sig: 信号编号
static void crashSignalHandler(int sig) {
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", tm_info);

    const char *信号名 = "UNKNOWN";
    switch (sig) {
        case SIGABRT: 信号名 = "SIGABRT"; break;
        case SIGSEGV: 信号名 = "SIGSEGV"; break;
        case SIGBUS:  信号名 = "SIGBUS";  break;
        case SIGILL:  信号名 = "SIGILL";  break;
        case SIGTRAP: 信号名 = "SIGTRAP"; break;
        case SIGTERM: 信号名 = "SIGTERM"; break;
        default: break;
    }

    char log_buffer[256];
    snprintf(log_buffer, sizeof(log_buffer),
             "[%s] ❌ 扩展进程收到崩溃信号：%d (%s)，进程标识：%d\n",
             time_str, sig, 信号名, (int)getpid());

    FILE *fp = fopen(CRASH_LOG_PATH, "a");
    if (fp != NULL) {
        fputs(log_buffer, fp);
        fclose(fp);
    }

    // 恢复默认处理器并重新抛出信号，让系统生成标准崩溃报告
    signal(sig, SIG_DFL);
    raise(sig);
}

/// 构造函数：动态库加载阶段自动注册（早于 Swift/Go 初始化）
__attribute__((constructor))
static void registerSignalHandlers(void) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = crashSignalHandler;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0;

    sigaction(SIGABRT, &action, NULL);
    sigaction(SIGSEGV, &action, NULL);
    sigaction(SIGBUS,  &action, NULL);
    sigaction(SIGILL,  &action, NULL);
    sigaction(SIGTRAP, &action, NULL);
    sigaction(SIGTERM, &action, NULL);
    // SIGKILL 无法捕获
}
