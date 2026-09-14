import Foundation

// ==============================================================================
// JavaTokenizer Java语言词法分析器
// 功能：对Java代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class JavaTokenizer: CLikeTokenizer {
    // MARK: - Java关键字

    override var keywords: Set<String> {
        return [
            "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
            "class", "const", "continue", "default", "do", "double", "else", "enum",
            "extends", "final", "finally", "float", "for", "goto", "if", "implements",
            "import", "instanceof", "int", "interface", "long", "native", "new", "package",
            "private", "protected", "public", "return", "short", "static", "strictfp",
            "super", "switch", "synchronized", "this", "throw", "throws", "transient",
            "try", "void", "volatile", "while", "var", "record", "sealed", "permits",
            "yield", "non-sealed"
        ]
    }

    // MARK: - Java类型

    override var types: Set<String> {
        return [
            "String", "Integer", "Long", "Double", "Float", "Boolean", "Byte", "Short",
            "Character", "Object", "Class", "System", "Math", "StringBuilder", "StringBuffer",
            "ArrayList", "LinkedList", "HashMap", "HashSet", "TreeMap", "TreeSet",
            "LinkedHashMap", "LinkedHashSet", "ConcurrentHashMap", "CopyOnWriteArrayList",
            "List", "Map", "Set", "Queue", "Deque", "Collection", "Iterator", "Iterable",
            "Comparator", "Comparable", "Optional", "Stream", "Collectors", "Predicate",
            "Function", "Consumer", "Supplier", "BiFunction", "BiConsumer", "BiPredicate",
            "Runnable", "Callable", "Future", "CompletableFuture", "ExecutorService",
            "Thread", "Exception", "RuntimeException", "Error", "Throwable", "IOException",
            "File", "Path", "Paths", "Files", "InputStream", "OutputStream", "Reader", "Writer",
            "BufferedReader", "BufferedWriter", "FileInputStream", "FileOutputStream",
            "URL", "URI", "HttpURLConnection", "HttpClient", "HttpRequest", "HttpResponse",
            "LocalDate", "LocalTime", "LocalDateTime", "Instant", "Duration", "Period",
            "ZoneId", "ZonedDateTime", "DateTimeFormatter", "Calendar", "Date", "Timestamp",
            "BigDecimal", "BigInteger", "AtomicInteger", "AtomicLong", "AtomicReference",
            "ReentrantLock", "Semaphore", "CountDownLatch", "CyclicBarrier", "Phaser"
        ]
    }

    // MARK: - 初始化

    init() {
        super.init(language: .java)
    }
}
