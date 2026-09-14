import Foundation

// ==============================================================================
// KotlinTokenizer Kotlin语言词法分析器
// 功能：对Kotlin代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class KotlinTokenizer: CLikeTokenizer {
    // MARK: - Kotlin关键字

    override var keywords: Set<String> {
        return [
            "abstract", "annotation", "as", "break", "by", "catch", "class", "companion",
            "const", "constructor", "continue", "crossinline", "data", "delegate", "do",
            "dynamic", "else", "enum", "expect", "external", "false", "final", "finally",
            "for", "fun", "get", "if", "import", "in", "infix", "init", "inline",
            "inner", "interface", "internal", "is", "it", "lateinit", "lazy", "noinline",
            "null", "object", "open", "operator", "out", "override", "package", "private",
            "protected", "public", "reified", "return", "sealed", "set", "super",
            "suspend", "tailrec", "this", "throw", "true", "try", "typealias", "typeof",
            "val", "var", "vararg", "when", "where", "while", "field", "value",
            "actual", "file", "receive", "param", "setparam", "delegate", "import",
            "constructor", "receiver", "property", "field", "set", "get"
        ]
    }

    // MARK: - Kotlin类型

    override var types: Set<String> {
        return [
            "Any", "Nothing", "Unit", "String", "Char", "Boolean", "Int", "Long",
            "Short", "Byte", "Float", "Double", "Array", "IntArray", "LongArray",
            "ShortArray", "ByteArray", "FloatArray", "DoubleArray", "BooleanArray",
            "CharArray", "List", "MutableList", "ArrayList", "Set", "MutableSet",
            "HashSet", "LinkedHashSet", "TreeSet", "Map", "MutableMap", "HashMap",
            "LinkedHashMap", "TreeMap", "Sequence", "Iterator", "ListIterator",
            "MutableIterator", "MutableListIterator", "Collection", "MutableCollection",
            "Iterable", "MutableIterable", "Comparable", "Comparator", "ClosedRange",
            "CharRange", "IntRange", "LongRange", "CharProgression", "IntProgression",
            "LongProgression", "Pair", "Triple", "Lazy", "LazyThreadSafetyMode",
            "KClass", "KType", "KTypeParameter", "KClassifier", "KProperty",
            "KMutableProperty", "KFunction", "KCallable", "KParameter", "KVisibility",
            "KVariance", "KWrapper", "KDeclarationContainer", "KAnnotatedElement",
            "KAnnotation", "KTypeProjection", "KotlinVersion", "Result", "Failure",
            "Success", "Throwable", "Exception", "RuntimeException", "Error",
            "IllegalArgumentException", "IllegalStateException", "IndexOutOfBoundsException",
            "NullPointerException", "ClassCastException", "UnsupportedOperationException",
            "NumberFormatException", "ArithmeticException", "ConcurrentModificationException",
            "NoSuchElementException", "NoSuchMethodException", "NoSuchFieldException",
            "SecurityException", "IOException", "FileNotFoundException", "EOFException",
            "InterruptedException", "Thread", "Runnable", "ThreadLocal", "synchronized",
            "volatile", "atomic", "AtomicInteger", "AtomicLong", "AtomicReference",
            "AtomicBoolean", "CoroutineScope", "CoroutineContext", "CoroutineDispatcher",
            "Job", "Deferred", "CoroutineStart", "Dispatchers", "MainScope",
            "SupervisorJob", "NonCancellable", "CancellationException", "TimeoutCancellationException",
            "Flow", "StateFlow", "SharedFlow", "MutableStateFlow", "MutableSharedFlow",
            "Channel", "ReceiveChannel", "SendChannel", "BroadcastChannel", "Mutex",
            "Semaphore", "ActorScope", "ProducerScope", "SelectBuilder", "SelectClause0",
            "SelectClause1", "SelectClause2", "File", "Path", "Paths", "Files",
            "InputStream", "OutputStream", "Reader", "Writer", "BufferedReader",
            "BufferedWriter", "FileInputStream", "FileOutputStream", "FileReader",
            "FileWriter", "PrintWriter", "PrintStream", "Scanner", "Formatter",
            "Locale", "Date", "Calendar", "TimeZone", "SimpleDateFormat", "DateFormat",
            "Instant", "Duration", "Period", "LocalDate", "LocalTime", "LocalDateTime",
            "ZonedDateTime", "OffsetDateTime", "OffsetTime", "ZoneId", "ZoneOffset",
            "DateTimeFormatter", "ChronoUnit", "ChronoField", "Temporal", "TemporalAccessor",
            "TemporalAdjuster", "TemporalAmount", "TemporalField", "TemporalUnit",
            "Regex", "MatchResult", "MatchGroup", "MatchGroupCollection", "URLEncoder",
            "URLDecoder", "URL", "URI", "HttpURLConnection", "HttpURLConnection",
            "Socket", "ServerSocket", "DatagramSocket", "InetAddress", "Inet4Address",
            "Inet6Address", "NetworkInterface", "URLConnection", "JarURLConnection",
            "UUID", "Base64", "Base64Encoder", "Base64Decoder", "BitSet", "Random",
            "SecureRandom", "MessageDigest", "Cipher", "Key", "KeyPair", "KeyPairGenerator",
            "KeyStore", "Certificate", "X509Certificate", "Mac", "Signature",
            "AlgorithmParameters", "AlgorithmParameterGenerator", "SecureRandomSpi",
            "Provider", "Security", "Permission", "ProtectionDomain", "AccessController",
            "AccessControlContext", "CodeSource", "CodeSigner", "Timestamp", "CertPath",
            "CertPathValidator", "CertPathBuilder", "CertStore", "CertificateFactory",
            "KeyFactory", "SecretKeyFactory", "KeyAgreement", "SecretKey", "PrivateKey",
            "PublicKey"
        ]
    }

    // MARK: - 初始化

    init() {
        super.init(language: .kotlin)
    }
}
