import Foundation

// ==============================================================================
// CTokenizer C语言词法分析器
// 功能：对C代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class CTokenizer: CLikeTokenizer {
    // MARK: - C关键字

    override var keywords: Set<String> {
        return [
            "auto", "break", "case", "char", "const", "continue", "default", "do",
            "double", "else", "enum", "extern", "float", "for", "goto", "if",
            "inline", "int", "long", "register", "restrict", "return", "short",
            "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
            "unsigned", "void", "volatile", "while", "_Alignas", "_Alignof", "_Atomic",
            "_Bool", "_Complex", "_Generic", "_Imaginary", "_Noreturn", "_Static_assert",
            "_Thread_local"
        ]
    }

    // MARK: - C类型

    override var types: Set<String> {
        return [
            "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t",
            "uint32_t", "uint64_t", "intptr_t", "uintptr_t", "size_t", "ssize_t",
            "ptrdiff_t", "wchar_t", "char16_t", "char32_t", "float_t", "double_t",
            "FILE", "DIR", "fpos_t", "mbstate_t", "div_t", "ldiv_t", "lldiv_t",
            "imaxdiv_t", "time_t", "clock_t", "timespec", "timeval", "tm", "jmp_buf",
            "sig_atomic_t", "va_list", "pthread_t", "pthread_mutex_t", "pthread_cond_t",
            "pthread_attr_t", "pthread_mutexattr_t", "pthread_condattr_t", "pthread_key_t",
            "pthread_once_t", "sem_t", "mode_t", "off_t", "pid_t", "uid_t", "gid_t",
            "id_t", "socklen_t", "sa_family_t", "in_addr_t", "in_port_t", "struct",
            "union", "enum"
        ]
    }

    // MARK: - 初始化

    init() {
        super.init(language: .c)
    }
}
