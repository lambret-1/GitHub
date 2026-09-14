import Foundation

// ==============================================================================
// GoTokenizer Go语言词法分析器
// 功能：对Go代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class GoTokenizer: CLikeTokenizer {
    // MARK: - Go关键字

    override var keywords: Set<String> {
        return [
            "break", "case", "chan", "const", "continue", "default", "defer", "else",
            "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
            "map", "package", "range", "return", "select", "struct", "switch", "type",
            "var"
        ]
    }

    // MARK: - Go类型

    override var types: Set<String> {
        return [
            "bool", "byte", "complex64", "complex128", "error", "float32", "float64",
            "int", "int8", "int16", "int32", "int64", "rune", "string", "uint",
            "uint8", "uint16", "uint32", "uint64", "uintptr", "any", "comparable",
            "Reader", "Writer", "ReadWriter", "Closer", "ReadCloser", "WriteCloser",
            "ReadWriteCloser", "Seeker", "ReadSeeker", "WriteSeeker", "ReadWriteSeeker",
            "ReaderAt", "WriterAt", "ReaderFrom", "WriterTo", "ByteReader", "ByteScanner",
            "ByteWriter", "RuneReader", "RuneScanner", "RuneWriter", "StringWriter",
            "Context", "CancelFunc", "ContextKey", "Timer", "Ticker", "Duration",
            "Time", "Location", "Weekday", "Month", "Error", "PathError", "LinkError",
            "SyscallError", "File", "FileInfo", "FileMode", "DirEntry", "FileHeader",
            "Request", "Response", "ResponseWriter", "Handler", "HandlerFunc", "ServeMux",
            "Cookie", "Header", "Conn", "Listener", "Addr", "PacketConn", "UDPConn",
            "TCPConn", "TCPListener", "UnixConn", "UnixListener", "IP", "IPMask", "IPNet",
            "Mutex", "RWMutex", "WaitGroup", "Once", "Cond", "Pool", "Map", "Locker",
            "Channel", "Slice", "Array", "MapType", "StructType", "FuncType", "InterfaceType",
            "PointerType", "SliceType", "ArrayType", "ChanType", "MapType"
        ]
    }

    // MARK: - 初始化

    init() {
        super.init(language: .go)
    }
}
