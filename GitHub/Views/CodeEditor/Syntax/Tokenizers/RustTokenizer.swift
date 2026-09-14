import Foundation

// ==============================================================================
// RustTokenizer Rust语言词法分析器
// 功能：对Rust代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class RustTokenizer: CLikeTokenizer {
    // MARK: - Rust关键字

    override var keywords: Set<String> {
        return [
            "as", "break", "const", "continue", "crate", "else", "enum", "extern",
            "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod",
            "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct",
            "super", "trait", "true", "type", "unsafe", "use", "where", "while",
            "async", "await", "dyn", "abstract", "become", "box", "do", "final",
            "macro", "override", "priv", "typeof", "unsized", "virtual", "yield",
            "try", "union", "'static", "macro_rules!"
        ]
    }

    // MARK: - Rust类型

    override var types: Set<String> {
        return [
            "i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64",
            "u128", "usize", "f32", "f64", "bool", "char", "str", "String", "Vec",
            "HashMap", "HashSet", "BTreeMap", "BTreeSet", "LinkedList", "VecDeque",
            "BinaryHeap", "Option", "Result", "Box", "Rc", "Arc", "Cell", "RefCell",
            "UnsafeCell", "Mutex", "RwLock", "Condvar", "Once", "Barrier", "Channel",
            "Sender", "Receiver", "SyncSender", "Iterator", "IntoIterator", "FromIterator",
            "DoubleEndedIterator", "ExactSizeIterator", "FusedIterator", "TrustedLen",
            "Clone", "Copy", "Debug", "Default", "Hash", "PartialEq", "Eq", "PartialOrd",
            "Ord", "AsRef", "AsMut", "Into", "From", "TryFrom", "TryInto", "ToOwned",
            "Borrow", "BorrowMut", "Deref", "DerefMut", "Drop", "Fn", "FnMut", "FnOnce",
            "Read", "Write", "Seek", "BufRead", "Cursor", "BufReader", "BufWriter",
            "LineWriter", "Stdin", "Stdout", "Stderr", "File", "OpenOptions", "Metadata",
            "FileType", "Permissions", "DirBuilder", "ReadDir", "DirEntry", "Path",
            "PathBuf", "Component", "Components", "Iter", "Prefix", "PrefixComponent",
            "Error", "ErrorKind", "Result", "io::Result", "io::Error", "io::ErrorKind",
            "Duration", "Instant", "SystemTime", "SystemTimeError", "UNIX_EPOCH",
            "Thread", "JoinHandle", "Builder", "ThreadId", "LocalKey", "thread::Result",
            "panic::Location", "panic::PanicInfo", "panic::AssertUnwindSafe",
            "panic::UnwindSafe", "panic::RefUnwindSafe", "any::Any", "any::TypeId",
            "marker::Copy", "marker::Send", "marker::Sync", "marker::Sized",
            "marker::Unpin", "marker::PhantomData", "marker::PhantomPinned",
            "ops::Range", "ops::RangeFrom", "ops::RangeTo", "ops::RangeFull",
            "ops::RangeInclusive", "ops::RangeToInclusive", "ops::Bound",
            "ops::Add", "ops::Sub", "ops::Mul", "ops::Div", "ops::Rem", "ops::Neg",
            "ops::Not", "ops::BitAnd", "ops::BitOr", "ops::BitXor", "ops::Shl", "ops::Shr",
            "ops::AddAssign", "ops::SubAssign", "ops::MulAssign", "ops::DivAssign",
            "ops::RemAssign", "ops::BitAndAssign", "ops::BitOrAssign", "ops::BitXorAssign",
            "ops::ShlAssign", "ops::ShrAssign", "ops::Index", "ops::IndexMut",
            "ops::Deref", "ops::DerefMut", "ops::Drop", "ops::Fn", "ops::FnMut",
            "ops::FnOnce", "ops::ControlFlow", "ops::Try", "cmp::Ordering", "cmp::PartialOrd",
            "cmp::Ord", "cmp::PartialEq", "cmp::Eq", "cmp::Reverse", "cmp::min", "cmp::max",
            "slice::Iter", "slice::IterMut", "slice::Chunks", "slice::ChunksMut",
            "slice::Windows", "slice::Split", "slice::SplitMut", "slice::RSplit",
            "slice::RSplitMut", "slice::SplitN", "slice::SplitNMut", "slice::RSplitN",
            "slice::RSplitNMut", "slice::SplitInclusive", "slice::SplitInclusiveMut",
            "slice::RSplitInclusive", "slice::RSplitInclusiveMut", "slice::ArrayChunks",
            "slice::ArrayChunksMut", "slice::ArrayWindows", "slice::GroupBy",
            "slice::GroupByMut", "slice::ChunkBy", "slice::ChunkByMut"
        ]
    }

    // MARK: - 初始化

    init() {
        super.init(language: .rust)
    }
}
