import Foundation

// ==============================================================================
// SQLTokenizer SQL语言词法分析器
// 功能：对SQL代码进行词法分析，识别关键字、字符串、数字、注释、函数等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class SQLTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - SQL关键字

    private static let sqlKeywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "IS", "NULL",
        "LIKE", "BETWEEN", "AS", "ORDER", "BY", "ASC", "DESC", "LIMIT",
        "OFFSET", "GROUP", "HAVING", "JOIN", "INNER", "LEFT", "RIGHT",
        "FULL", "OUTER", "ON", "UNION", "ALL", "DISTINCT", "INSERT",
        "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE",
        "DATABASE", "INDEX", "VIEW", "ALTER", "DROP", "TRUNCATE", "RENAME",
        "ADD", "COLUMN", "CONSTRAINT", "PRIMARY", "KEY", "FOREIGN",
        "REFERENCES", "UNIQUE", "CHECK", "DEFAULT", "AUTO_INCREMENT",
        "NOT NULL", "CASE", "WHEN", "THEN", "ELSE", "END", "EXISTS",
        "ANY", "SOME", "WITH", "RECURSIVE", "CTE", "WINDOW", "OVER",
        "PARTITION", "RANK", "ROW_NUMBER", "DENSE_RANK", "LAG", "LEAD",
        "FIRST_VALUE", "LAST_VALUE", "NTH_VALUE", "NTILE", "CUME_DIST",
        "PERCENT_RANK", "PERCENTILE_CONT", "PERCENTILE_DISC", "WITHIN",
        "GROUP_CONCAT", "STRING_AGG", "ARRAY_AGG", "JSON_AGG", "JSON_OBJECT_AGG",
        "COALESCE", "NULLIF", "GREATEST", "LEAST", "IFNULL", "NVL", "DECODE",
        "CAST", "CONVERT", "TRY_CAST", "TRY_CONVERT", "EXTRACT", "DATE_PART",
        "DATE_TRUNC", "TO_CHAR", "TO_DATE", "TO_TIMESTAMP", "NOW", "CURRENT_DATE",
        "CURRENT_TIME", "CURRENT_TIMESTAMP", "LOCALTIME", "LOCALTIMESTAMP",
        "INTERVAL", "YEAR", "MONTH", "DAY", "HOUR", "MINUTE", "SECOND",
        "QUARTER", "WEEK", "DOW", "DOY", "CENTURY", "DECADE", "MILLENNIUM",
        "EPOCH", "TIMEZONE", "TZ_OFFSET", "AT", "TIME", "ZONE", "BEGIN",
        "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE", "TRANSACTION", "WORK",
        "GRANT", "REVOKE", "PRIVILEGES", "USER", "ROLE", "SCHEMA", "SEQUENCE",
        "TRIGGER", "FUNCTION", "PROCEDURE", "RETURNS", "LANGUAGE", "PLPGSQL",
        "SQL", "SECURITY", "DEFINER", "INVOKER", "VOLATILE", "STABLE",
        "IMMUTABLE", "LEAKPROOF", "PARALLEL", "SAFE", "UNSAFE", "RESTRICTED",
        "COST", "ROWS", "SUPPORT", "SET", "RESET", "SHOW", "EXPLAIN", "ANALYZE",
        "VERBOSE", "FORMAT", "TEXT", "JSON", "XML", "YAML", "BUFFERS", "TIMING",
        "SUMMARY", "WAL", "PLAN", "FOR", "UPDATE", "SHARE", "NO", "KEY",
        "SKIP", "LOCKED", "NOWAIT", "WAIT", "OF", "ESCAPE", "COLLATE",
        "USING", "BTREE", "HASH", "GIN", "GIST", "SPGIST", "BRIN", "INCLUDE",
        "FILLFACTOR", "PAGES_PER_RANGE", "TABLESPACE", "WHERE", "CURRENT",
        "OF", "CASCADE", "RESTRICT", "IF", "EXISTS", "TEMPORARY", "TEMP",
        "UNLOGGED", "GLOBAL", "LOCAL", "PRESERVE", "ROWS", "DROP", "BEHAVIOR",
        "INCLUDING", "EXCLUDING", "DEFAULTS", "IDENTITY", "GENERATED", "ALWAYS",
        "STORED", "VIRTUAL", "CHECK", "OPTION", "CASCADED", "LOCAL", "GLOBAL",
        "TEMP", "TEMPORARY", "UNLOGGED", "FOREIGN", "DATA", "WRAPPER", "SERVER",
        "MAPPING", "OPTIONS", "OWNER", "MODE", "PERMISSION", "GRANT", "REVOKE",
        "ADMIN", "OPTION", "GRANTED", "BY", "PUBLIC", "CURRENT_USER", "SESSION_USER",
        "SYSTEM_USER", "CURRENT_ROLE", "CURRENT_SCHEMA", "CURRENT_CATALOG",
        "SEARCH_PATH", "SCHEMA", "PUBLIC", "PG_CATALOG", "PG_TOAST", "PG_TEMP",
        "INFORMATION_SCHEMA", "PG_INHERITS", "PG_CLASS", "PG_ATTRIBUTE",
        "PG_TYPE", "PG_CONSTRAINT", "PG_INDEX", "PG_NAMESPACE", "PG_PROC",
        "PG_USER", "PG_GROUP", "PG_DATABASE", "PG_TABLESPACE", "PG_SETTINGS",
        "PG_STAT_ACTIVITY", "PG_STAT_DATABASE", "PG_STAT_USER_TABLES",
        "PG_STAT_USER_INDEXES", "PG_STAT_USER_FUNCTIONS", "PG_STATIO_USER_TABLES",
        "PG_STATIO_USER_INDEXES", "PG_STATIO_USER_SEQUENCES", "PG_LOCKS",
        "PG_PREPARED_XACTS", "PG_PREPARED_STATEMENTS", "PG_SESSION_WAL",
        "PG_REPLICATION_SLOTS", "PG_STAT_REPLICATION", "PG_STAT_WAL_RECEIVER",
        "PG_STAT_WAL_SENDER", "PG_STAT_SUBSCRIPTION", "PG_STAT_SUBSCRIPTION_REL",
        "PG_STAT_SUBSCRIPTION_TABLES", "PG_PUBLICATION", "PG_PUBLICATION_REL",
        "PG_PUBLICATION_TABLES", "PG_SUBSCRIPTION", "PG_SUBSCRIPTION_REL",
        "PG_SUBSCRIPTION_TABLES", "PG_SHADOW", "PG_AUTHID", "PG_AUTH_MEMBERS",
        "PG_ROLES", "PG_DB_ROLE_SETTING", "PG_RESERVED_WORDS", "PG_CONFIG",
        "PG_HBA_FILE_RULES", "PG_IDENT_FILE_MAPPINGS", "PG_FILE_SETTINGS",
        "PG_TIMEZONE_ABBREVS", "PG_TIMEZONE_NAMES", "PG_VERSION", "PG_CONTROL_CHECKPOINT",
        "PG_BACKEND_MEMORY_CONTEXTS", "PG_BACKEND_WAL", "PG_WAL", "PG_WAL_SUMMARY",
        "PG_CHECKPOINTS", "PG_REPLICATION_ORIGIN", "PG_REPLICATION_ORIGIN_STATUS",
        "PG_STAT_REPLICATION_ORIGIN", "PG_LOG_SNAPSHOT", "PG_LOGICAL_SLOT_PEEK_CHANGES",
        "PG_LOGICAL_SLOT_GET_CHANGES", "PG_LOGICAL_SLOT_PEEK_BINARY_CHANGES",
        "PG_LOGICAL_SLOT_GET_BINARY_CHANGES", "PG_LOGICAL_EMIT_MESSAGE",
        "PG_LOGICAL_DECODING_GET_MESSAGE", "PG_REPLICATION_SLOT_ADVANCE",
        "PG_CREATE_LOGICAL_REPLICATION_SLOT", "PG_CREATE_PHYSICAL_REPLICATION_SLOT",
        "PG_DROP_REPLICATION_SLOT", "PG_START_REPLICATION", "PG_BASEBACKUP",
        "PG_IDENTIFY_SYSTEM", "PG_TIMELINE_HISTORY", "PG_READ_BINARY_FILE",
        "PG_READ_FILE", "PG_LS_DIR", "PG_STAT_FILE", "PG_RELOAD_CONF",
        "PG_ROTATE_LOGFILE", "PG_RESTART", "PG_PROMOTE", "PG_FADVISE",
        "PG_PREWARM", "PG_BUFFER_USAGE_COUNTERS", "PG_BACKEND_CONTEXT_MEMORY",
        "PG_GET_BUFFER_USAGE_COUNTERS", "PG_RESET_BUFFER_USAGE_COUNTERS",
        "PG_GET_WAL_USAGE_COUNTERS", "PG_RESET_WAL_USAGE_COUNTERS",
        "PG_GET_MEMORY_CONTEXT_RECURSIVE", "PG_GET_BACKEND_MEMORY_CONTEXTS",
        "PG_GET_ACTIVE_BACKEND_PIDS", "PG_CANCEL_BACKEND", "PG_TERMINATE_BACKEND",
        "PG_SIGNAL_BACKEND", "PG_RELOAD_CONF", "PG_ROTATE_LOGFILE", "PG_RESTART",
        "PG_PROMOTE", "PG_FADVISE", "PG_PREWARM", "PG_BUFFER_USAGE_COUNTERS",
        "PG_BACKEND_CONTEXT_MEMORY", "PG_GET_BUFFER_USAGE_COUNTERS",
        "PG_RESET_BUFFER_USAGE_COUNTERS", "PG_GET_WAL_USAGE_COUNTERS",
        "PG_RESET_WAL_USAGE_COUNTERS", "PG_GET_MEMORY_CONTEXT_RECURSIVE",
        "PG_GET_BACKEND_MEMORY_CONTEXTS", "PG_GET_ACTIVE_BACKEND_PIDS",
        "PG_CANCEL_BACKEND", "PG_TERMINATE_BACKEND", "PG_SIGNAL_BACKEND"
    ]

    // MARK: - SQL函数

    private static let sqlFunctions: Set<String> = [
        "COUNT", "SUM", "AVG", "MIN", "MAX", "STDDEV", "VARIANCE", "MEDIAN",
        "PERCENTILE", "PERCENTILE_CONT", "PERCENTILE_DISC", "MODE", "RANK",
        "DENSE_RANK", "ROW_NUMBER", "NTILE", "CUME_DIST", "PERCENT_RANK",
        "LAG", "LEAD", "FIRST_VALUE", "LAST_VALUE", "NTH_VALUE", "FIRST",
        "LAST", "NTH", "GROUP_CONCAT", "STRING_AGG", "ARRAY_AGG", "JSON_AGG",
        "JSON_OBJECT_AGG", "JSONB_AGG", "JSONB_OBJECT_AGG", "XMLAGG", "XMLCONCAT",
        "XMLELEMENT", "XMLFOREST", "XMLPARSE", "XMLPI", "XMLROOT", "XMLSERIALIZE",
        "XMLTABLE", "COALESCE", "NULLIF", "GREATEST", "LEAST", "IFNULL", "NVL",
        "DECODE", "CASE", "CAST", "CONVERT", "TRY_CAST", "TRY_CONVERT", "EXTRACT",
        "DATE_PART", "DATE_TRUNC", "TO_CHAR", "TO_DATE", "TO_TIMESTAMP", "TO_NUMBER",
        "TO_BINARY_FLOAT", "TO_BINARY_DOUBLE", "TO_DSINTERVAL", "TO_YMINTERVAL",
        "TO_SINGLE_BYTE", "TO_MULTI_BYTE", "TO_LOB", "TO_NCLOB", "TO_CLOB",
        "TO_BLOB", "TO_NCHAR", "TO_CHAR", "TO_DATE", "TO_TIMESTAMP", "TO_TIMESTAMP_TZ",
        "TO_TIME", "TO_TIME_TZ", "TO_DATETIME", "TO_DATETIME_TZ", "NOW", "CURRENT_DATE",
        "CURRENT_TIME", "CURRENT_TIMESTAMP", "LOCALTIME", "LOCALTIMESTAMP", "SYSDATE",
        "SYSTIMESTAMP", "SESSIONTIMEZONE", "DBTIMEZONE", "TZ_OFFSET", "NEW_TIME",
        "MONTHS_BETWEEN", "ADD_MONTHS", "LAST_DAY", "NEXT_DAY", "ROUND", "TRUNC",
        "CEIL", "FLOOR", "ABS", "MOD", "POWER", "SQRT", "EXP", "LN", "LOG",
        "SIN", "COS", "TAN", "ASIN", "ACOS", "ATAN", "ATAN2", "SINH", "COSH",
        "TANH", "BITAND", "BITOR", "BITXOR", "BITNOT", "BITCOUNT", "BITLENGTH",
        "CONCAT", "SUBSTR", "SUBSTRING", "LENGTH", "CHAR_LENGTH", "CHARACTER_LENGTH",
        "OCTET_LENGTH", "LOWER", "UPPER", "INITCAP", "TRIM", "LTRIM", "RTRIM",
        "LPAD", "RPAD", "REPLACE", "TRANSLATE", "REGEXP_REPLACE", "REGEXP_LIKE",
        "REGEXP_INSTR", "REGEXP_SUBSTR", "REGEXP_COUNT", "REGEXP_MATCHES",
        "REGEXP_SPLIT_TO_ARRAY", "REGEXP_SPLIT_TO_TABLE", "ASCII", "CHR", "ORD",
        "POSITION", "STRPOS", "INSTR", "LOCATE", "FIND_IN_SET", "FIELD", "ELT",
        "EXPORT_SET", "MAKE_SET", "QUOTE", "QUOTE_IDENT", "QUOTE_LITERAL", "QUOTE_NULLABLE",
        "FORMAT", "TO_BASE64", "FROM_BASE64", "MD5", "SHA1", "SHA224", "SHA256",
        "SHA384", "SHA512", "CRC32", "FNV_HASH", "MURMUR3_32", "MURMUR3_64",
        "XXHASH64", "CITYHASH64", "METROHASH64", "SPOOKYHASH", "SIPHASH", "HMAC",
        "ENCRYPT", "DECRYPT", "PGP_SYM_ENCRYPT", "PGP_SYM_DECRYPT", "PGP_PUB_ENCRYPT",
        "PGP_PUB_DECRYPT", "PGP_KEY_ID", "ARMOR", "DEARMOR", "PGP_SYM_ENCRYPT_BYTEA",
        "PGP_SYM_DECRYPT_BYTEA", "PGP_PUB_ENCRYPT_BYTEA", "PGP_PUB_DECRYPT_BYTEA",
        "GEN_RANDOM_UUID", "UUID_GENERATE_V1", "UUID_GENERATE_V1MC", "UUID_GENERATE_V3",
        "UUID_GENERATE_V4", "UUID_GENERATE_V5", "UUID_NS_URL", "UUID_NS_DNS",
        "UUID_NS_OID", "UUID_NS_X500", "ARRAY", "ARRAY_APPEND", "ARRAY_PREPEND",
        "ARRAY_CAT", "ARRAY_TO_STRING", "STRING_TO_ARRAY", "ARRAY_LENGTH", "ARRAY_NDIMS",
        "ARRAY_DIMS", "ARRAY_LOWER", "ARRAY_UPPER", "ARRAY_REPLACE", "ARRAY_REMOVE",
        "ARRAY_UNIQ", "ARRAY_SORT", "ARRAY_AGG", "UNNEST", "ARRAY_CONTAINS",
        "ARRAY_CONTAINS_ALL", "ARRAY_CONTAINS_ANY", "ARRAY_OVERLAP", "CARDINALITY",
        "TRIM_ARRAY", "ARRAY_POSITION", "ARRAY_POSITIONS", "ARRAY_SHUFFLE", "ARRAY_SAMPLE",
        "JSON", "JSONB", "JSON_BUILD_ARRAY", "JSON_BUILD_OBJECT", "JSON_OBJECT",
        "JSON_ARRAY", "JSON_TO_RECORD", "JSON_TO_RECORDSET", "JSON_POPULATE_RECORD",
        "JSON_POPULATE_RECORDSET", "JSON_ARRAY_ELEMENTS", "JSON_ARRAY_ELEMENTS_TEXT",
        "JSON_OBJECT_KEYS", "JSON_EACH", "JSON_EACH_TEXT", "JSON_EXTRACT_PATH",
        "JSON_EXTRACT_PATH_TEXT", "JSONB_EXTRACT_PATH", "JSONB_EXTRACT_PATH_TEXT",
        "JSON_SET", "JSONB_SET", "JSON_INSERT", "JSONB_INSERT", "JSON_REPLACE",
        "JSONB_REPLACE", "JSON_DELETE", "JSONB_DELETE", "JSONB_DELETE_PATH", "JSON_STRIP_NULLS",
        "JSONB_STRIP_NULLS", "JSON_TYPEOF", "JSONB_TYPEOF", "JSON_ARRAY_LENGTH",
        "JSONB_ARRAY_LENGTH", "JSON_OBJECT_KEYS", "JSONB_OBJECT_KEYS", "JSONB_PRETTY",
        "JSON_PRETTY", "JSONB_PATH_QUERY", "JSONB_PATH_QUERY_ARRAY", "JSONB_PATH_EXISTS",
        "JSONB_PATH_MATCH", "JSONB_PATH_QUERY_FIRST", "JSONB_PATH_QUERY_ARRAY_FIRST",
        "XML", "XMLAGG", "XMLCONCAT", "XMLELEMENT", "XMLFOREST", "XMLPARSE",
        "XMLPI", "XMLROOT", "XMLSERIALIZE", "XMLTABLE", "XMLCOMMENT", "XMLCDATA",
        "XMLTEXT", "XMLDOCUMENT", "XMLFRAGMENT", "XMLNAMESPACES", "XMLEXISTS",
        "XMLQUERY", "XMLTABLE", "XMLISNODE", "XMLISWELLFORMED", "XMLVALIDATE",
        "XPATH", "XPATH_EXISTS", "XPATH_TABLE", "XMLCAST", "CAST", "CONVERT",
        "TRY_CAST", "TRY_CONVERT", "PARSE", "TRY_PARSE", "FORMAT", "TO_CHAR",
        "TO_DATE", "TO_TIMESTAMP", "TO_NUMBER", "TO_BINARY_FLOAT", "TO_BINARY_DOUBLE",
        "TO_DSINTERVAL", "TO_YMINTERVAL", "TO_SINGLE_BYTE", "TO_MULTI_BYTE", "TO_LOB",
        "TO_NCLOB", "TO_CLOB", "TO_BLOB", "TO_NCHAR", "TO_CHAR", "TO_DATE",
        "TO_TIMESTAMP", "TO_TIMESTAMP_TZ", "TO_TIME", "TO_TIME_TZ", "TO_DATETIME",
        "TO_DATETIME_TZ", "NOW", "CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP",
        "LOCALTIME", "LOCALTIMESTAMP", "SYSDATE", "SYSTIMESTAMP", "SESSIONTIMEZONE",
        "DBTIMEZONE", "TZ_OFFSET", "NEW_TIME", "MONTHS_BETWEEN", "ADD_MONTHS",
        "LAST_DAY", "NEXT_DAY", "ROUND", "TRUNC", "CEIL", "FLOOR", "ABS", "MOD",
        "POWER", "SQRT", "EXP", "LN", "LOG", "SIN", "COS", "TAN", "ASIN", "ACOS",
        "ATAN", "ATAN2", "SINH", "COSH", "TANH", "BITAND", "BITOR", "BITXOR",
        "BITNOT", "BITCOUNT", "BITLENGTH", "CONCAT", "SUBSTR", "SUBSTRING", "LENGTH",
        "CHAR_LENGTH", "CHARACTER_LENGTH", "OCTET_LENGTH", "LOWER", "UPPER", "INITCAP",
        "TRIM", "LTRIM", "RTRIM", "LPAD", "RPAD", "REPLACE", "TRANSLATE",
        "REGEXP_REPLACE", "REGEXP_LIKE", "REGEXP_INSTR", "REGEXP_SUBSTR", "REGEXP_COUNT",
        "REGEXP_MATCHES", "REGEXP_SPLIT_TO_ARRAY", "REGEXP_SPLIT_TO_TABLE", "ASCII",
        "CHR", "ORD", "POSITION", "STRPOS", "INSTR", "LOCATE", "FIND_IN_SET", "FIELD",
        "ELT", "EXPORT_SET", "MAKE_SET", "QUOTE", "QUOTE_IDENT", "QUOTE_LITERAL",
        "QUOTE_NULLABLE", "FORMAT", "TO_BASE64", "FROM_BASE64", "MD5", "SHA1", "SHA224",
        "SHA256", "SHA384", "SHA512", "CRC32", "FNV_HASH", "MURMUR3_32", "MURMUR3_64",
        "XXHASH64", "CITYHASH64", "METROHASH64", "SPOOKYHASH", "SIPHASH", "HMAC",
        "ENCRYPT", "DECRYPT", "PGP_SYM_ENCRYPT", "PGP_SYM_DECRYPT", "PGP_PUB_ENCRYPT",
        "PGP_PUB_DECRYPT", "PGP_KEY_ID", "ARMOR", "DEARMOR", "PGP_SYM_ENCRYPT_BYTEA",
        "PGP_SYM_DECRYPT_BYTEA", "PGP_PUB_ENCRYPT_BYTEA", "PGP_PUB_DECRYPT_BYTEA",
        "GEN_RANDOM_UUID", "UUID_GENERATE_V1", "UUID_GENERATE_V1MC", "UUID_GENERATE_V3",
        "UUID_GENERATE_V4", "UUID_GENERATE_V5", "UUID_NS_URL", "UUID_NS_DNS", "UUID_NS_OID",
        "UUID_NS_X500", "ARRAY", "ARRAY_APPEND", "ARRAY_PREPEND", "ARRAY_CAT",
        "ARRAY_TO_STRING", "STRING_TO_ARRAY", "ARRAY_LENGTH", "ARRAY_NDIMS", "ARRAY_DIMS",
        "ARRAY_LOWER", "ARRAY_UPPER", "ARRAY_REPLACE", "ARRAY_REMOVE", "ARRAY_UNIQ",
        "ARRAY_SORT", "ARRAY_AGG", "UNNEST", "ARRAY_CONTAINS", "ARRAY_CONTAINS_ALL",
        "ARRAY_CONTAINS_ANY", "ARRAY_OVERLAP", "CARDINALITY", "TRIM_ARRAY", "ARRAY_POSITION",
        "ARRAY_POSITIONS", "ARRAY_SHUFFLE", "ARRAY_SAMPLE", "JSON", "JSONB", "JSON_BUILD_ARRAY",
        "JSON_BUILD_OBJECT", "JSON_OBJECT", "JSON_ARRAY", "JSON_TO_RECORD", "JSON_TO_RECORDSET",
        "JSON_POPULATE_RECORD", "JSON_POPULATE_RECORDSET", "JSON_ARRAY_ELEMENTS",
        "JSON_ARRAY_ELEMENTS_TEXT", "JSON_OBJECT_KEYS", "JSON_EACH", "JSON_EACH_TEXT",
        "JSON_EXTRACT_PATH", "JSON_EXTRACT_PATH_TEXT", "JSONB_EXTRACT_PATH",
        "JSONB_EXTRACT_PATH_TEXT", "JSON_SET", "JSONB_SET", "JSON_INSERT", "JSONB_INSERT",
        "JSON_REPLACE", "JSONB_REPLACE", "JSON_DELETE", "JSONB_DELETE", "JSONB_DELETE_PATH",
        "JSON_STRIP_NULLS", "JSONB_STRIP_NULLS", "JSON_TYPEOF", "JSONB_TYPEOF",
        "JSON_ARRAY_LENGTH", "JSONB_ARRAY_LENGTH", "JSON_OBJECT_KEYS", "JSONB_OBJECT_KEYS",
        "JSONB_PRETTY", "JSON_PRETTY", "JSONB_PATH_QUERY", "JSONB_PATH_QUERY_ARRAY",
        "JSONB_PATH_EXISTS", "JSONB_PATH_MATCH", "JSONB_PATH_QUERY_FIRST",
        "JSONB_PATH_QUERY_ARRAY_FIRST", "XML", "XMLAGG", "XMLCONCAT", "XMLELEMENT",
        "XMLFOREST", "XMLPARSE", "XMLPI", "XMLROOT", "XMLSERIALIZE", "XMLTABLE",
        "XMLCOMMENT", "XMLCDATA", "XMLTEXT", "XMLDOCUMENT", "XMLFRAGMENT", "XMLNAMESPACES",
        "XMLEXISTS", "XMLQUERY", "XMLTABLE", "XMLISNODE", "XMLISWELLFORMED", "XMLVALIDATE",
        "XPATH", "XPATH_EXISTS", "XPATH_TABLE", "XMLCAST"
    ]

    // MARK: - 初始化

    init() {
        super.init(language: .sql)
    }

    // MARK: - 词法分析

    func tokenize(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            let start = index

            // 跳过空白字符
            if char.isWhitespace {
                index = text.index(after: index)
                continue
            }

            // 单行注释 --
            if char == "-" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "-" {
                let commentStart = index
                while index < text.endIndex && text[index] != "\n" {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: commentStart), length: text.distance(from: commentStart, to: index))
                tokens.append(SyntaxToken(type: .comment, range: range, text: String(text[commentStart..<index])))
                continue
            }

            // 多行注释 /* */
            if char == "/" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "*" {
                let commentStart = index
                index = text.index(index, offsetBy: 2)
                while index < text.endIndex && !(text[index] == "*" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "/") {
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(index, offsetBy: 2)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: commentStart), length: text.distance(from: commentStart, to: index))
                tokens.append(SyntaxToken(type: .comment, range: range, text: String(text[commentStart..<index])))
                continue
            }

            // 字符串（单引号）
            if char == "'" {
                let stringStart = index
                index = text.index(after: index)
                while index < text.endIndex {
                    if text[index] == "'" {
                        if index < text.index(before: text.endIndex) && text[text.index(after: index)] == "'" {
                            // 转义的单引号
                            index = text.index(after: index)
                        } else {
                            break
                        }
                    }
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: stringStart), length: text.distance(from: stringStart, to: index))
                tokens.append(SyntaxToken(type: .string, range: range, text: String(text[stringStart..<index])))
                continue
            }

            // 字符串（双引号，用于标识符）
            if char == "\"" {
                let stringStart = index
                index = text.index(after: index)
                while index < text.endIndex && text[index] != "\"" {
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: stringStart), length: text.distance(from: stringStart, to: index))
                tokens.append(SyntaxToken(type: .variable, range: range, text: String(text[stringStart..<index])))
                continue
            }

            // 数字
            if char.isNumber || (char == "-" && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber) {
                let numberStart = index
                if char == "-" {
                    index = text.index(after: index)
                }
                while index < text.endIndex && (text[index].isNumber || text[index] == "." || text[index] == "e" || text[index] == "E" || text[index] == "+" || text[index] == "-") {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: numberStart), length: text.distance(from: numberStart, to: index))
                tokens.append(SyntaxToken(type: .number, range: range, text: String(text[numberStart..<index])))
                continue
            }

            // 标识符
            if isIdentifierStart(char) || char == "@" || char == "#" || char == "$" {
                let wordStart = index
                if char == "@" || char == "#" || char == "$" {
                    index = text.index(after: index)
                }
                while index < text.endIndex && (isIdentifierPart(text[index]) || text[index] == "_" || text[index] == ".") {
                    index = text.index(after: index)
                }
                let word = String(text[wordStart..<index])
                let upperWord = word.uppercased()

                // 检查是否是关键字
                if SQLTokenizer.sqlKeywords.contains(upperWord) {
                    let range = NSRange(location: text.distance(from: text.startIndex, to: wordStart), length: text.distance(from: wordStart, to: index))
                    tokens.append(SyntaxToken(type: .keyword, range: range, text: word))
                    continue
                }

                // 检查是否是函数
                if SQLTokenizer.sqlFunctions.contains(upperWord) {
                    // 检查后面是否跟着括号
                    var tempIndex = index
                    while tempIndex < text.endIndex && text[tempIndex].isWhitespace {
                        tempIndex = text.index(after: tempIndex)
                    }
                    if tempIndex < text.endIndex && text[tempIndex] == "(" {
                        let range = NSRange(location: text.distance(from: text.startIndex, to: wordStart), length: text.distance(from: wordStart, to: index))
                        tokens.append(SyntaxToken(type: .function, range: range, text: word))
                        continue
                    }
                }

                // 普通标识符
                let range = NSRange(location: text.distance(from: text.startIndex, to: wordStart), length: text.distance(from: wordStart, to: index))
                tokens.append(SyntaxToken(type: .plain, range: range, text: word))
                continue
            }

            // 运算符
            if isSQLOperator(char) {
                let opStart = index
                while index < text.endIndex && isSQLOperator(text[index]) {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: opStart), length: text.distance(from: opStart, to: index))
                tokens.append(SyntaxToken(type: .operatorSymbol, range: range, text: String(text[opStart..<index])))
                continue
            }

            // 其他字符
            index = text.index(after: index)
        }

        return tokens
    }

    // MARK: - 辅助方法

    /// 检查是否是SQL运算符
    func isSQLOperator(_ char: Character) -> Bool {
        let operators: Set<Character> = ["+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "(", ")", ",", ";"]
        return operators.contains(char)
    }
}
