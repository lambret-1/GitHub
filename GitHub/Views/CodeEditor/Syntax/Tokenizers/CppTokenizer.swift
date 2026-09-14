import Foundation

// ==============================================================================
// CppTokenizer C++语言词法分析器
// 功能：对C++代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class CppTokenizer: CLikeTokenizer {
    // MARK: - C++关键字

    override var keywords: Set<String> {
        return [
            "alignas", "alignof", "and", "and_eq", "asm", "auto", "bitand", "bitor",
            "bool", "break", "case", "catch", "char", "char8_t", "char16_t", "char32_t",
            "class", "compl", "concept", "const", "consteval", "constexpr", "constinit",
            "const_cast", "continue", "co_await", "co_return", "co_yield", "decltype",
            "default", "delete", "do", "double", "dynamic_cast", "else", "enum", "explicit",
            "export", "extern", "false", "float", "for", "friend", "goto", "if", "inline",
            "int", "long", "mutable", "namespace", "new", "noexcept", "not", "not_eq",
            "nullptr", "operator", "or", "or_eq", "private", "protected", "public",
            "register", "reinterpret_cast", "requires", "return", "short", "signed",
            "sizeof", "static", "static_assert", "static_cast", "struct", "switch",
            "template", "this", "thread_local", "throw", "true", "try", "typedef",
            "typeid", "typename", "union", "unsigned", "using", "virtual", "void",
            "volatile", "wchar_t", "while", "xor", "xor_eq", "override", "final"
        ]
    }

    // MARK: - C++类型

    override var types: Set<String> {
        return [
            "string", "wstring", "u8string", "u16string", "u32string", "string_view",
            "wstring_view", "u8string_view", "u16string_view", "u32string_view",
            "vector", "list", "deque", "queue", "stack", "priority_queue", "set",
            "multiset", "map", "multimap", "unordered_set", "unordered_multiset",
            "unordered_map", "unordered_multimap", "array", "tuple", "pair", "optional",
            "variant", "any", "bitset", "complex", "valarray", "ratio", "chrono",
            "time_point", "duration", "system_clock", "steady_clock", "high_resolution_clock",
            "function", "bind", "reference_wrapper", "mem_fn", "not_fn", "invoke",
            "thread", "mutex", "recursive_mutex", "timed_mutex", "recursive_timed_mutex",
            "shared_mutex", "shared_timed_mutex", "lock_guard", "unique_lock", "shared_lock",
            "scoped_lock", "condition_variable", "condition_variable_any", "future",
            "shared_future", "promise", "packaged_task", "async", "atomic", "atomic_flag",
            "memory", "unique_ptr", "shared_ptr", "weak_ptr", "auto_ptr", "allocator",
            "iterator", "reverse_iterator", "const_iterator", "move_iterator",
            "back_insert_iterator", "front_insert_iterator", "insert_iterator",
            "istream_iterator", "ostream_iterator", "istreambuf_iterator", "ostreambuf_iterator",
            "iostream", "istream", "ostream", "fstream", "ifstream", "ofstream",
            "stringstream", "istringstream", "ostringstream", "wistringstream", "wostringstream",
            "streambuf", "filebuf", "stringbuf", "ios", "ios_base", "streampos", "streamoff",
            "exception", "runtime_error", "logic_error", "domain_error", "invalid_argument",
            "length_error", "out_of_range", "range_error", "overflow_error", "underflow_error",
            "bad_alloc", "bad_cast", "bad_typeid", "bad_exception", "bad_optional_access",
            "bad_variant_access", "bad_any_cast", "bad_weak_ptr", "bad_function_call",
            "error_code", "error_condition", "error_category", "system_error", "errc",
            "expected", "unexpected", "source_location", "span", "mdspan", "ranges",
            "views", "actions", "algorithms", "numeric", "random", "regex", "filesystem",
            "path", "directory_entry", "directory_iterator", "recursive_directory_iterator",
            "file_status", "space_info", "file_time_type", "perms", "perm_options",
            "copy_options", "directory_options", "file_type", "streamoff", "streampos"
        ]
    }

    // MARK: - 初始化

    init() {
        super.init(language: .cpp)
    }
}
