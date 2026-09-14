import Foundation

// ==============================================================================
// RTokenizer R语言词法分析器
// 功能：对R代码进行词法分析，识别关键字、字符串、注释、数字、函数、变量等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class RTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - R关键字

    private static let keywords: Set<String> = [
        "if", "else", "for", "while", "repeat", "break", "next", "function",
        "return", "in", "TRUE", "FALSE", "NULL", "NA", "Inf", "NaN",
        "NA_integer_", "NA_real_", "NA_complex_", "NA_character_",
        "...", "..1", "..2", "..3", "..4", "..5", "..6", "..7", "..8", "..9",
        "library", "require", "source", "install.packages", "update.packages",
        "remove.packages", "installed.packages", "available.packages",
        "old.packages", "new.packages", "download.packages", "install.packages",
        "contrib.url", "getOption", "options", "Sys.getenv", "Sys.setenv",
        "Sys.unsetenv", "Sys.getlocale", "Sys.setlocale", "Sys.time", "Sys.Date",
        "Sys.sleep", "Sys.info", "Sys.which", "Sys.readlink", "Sys.glob",
        "Sys.chmod", "Sys.umask", "Sys.setFileTime", "Sys.setFileMode",
        "Sys.setFileOwner", "Sys.setFileGroup", "Sys.setFileAccess",
        "Sys.setFileCreationTime", "Sys.setFileModificationTime",
        "Sys.setFileLastAccessTime", "Sys.setFileLastWriteTime",
        "Sys.setFileChangeTime", "Sys.setFileBirthTime", "Sys.setFileMetadata",
        "Sys.setFileAttributes", "Sys.setFileExtendedAttributes",
        "Sys.setFileResourceFork", "Sys.setFileFinderInfo", "Sys.setFileSpotlightComments",
        "Sys.setFileWhereFroms", "Sys.setFileQuarantine", "Sys.setFileDownloadedDate",
        "Sys.setFileDownloadedURL", "Sys.setFileDownloadedUserAgent",
        "Sys.setFileDownloadedReferrer", "Sys.setFileDownloadedBundleIdentifier",
        "Sys.setFileDownloadedBundleName", "Sys.setFileDownloadedBundleVersion",
        "Sys.setFileDownloadedBundleShortVersion", "Sys.setFileDownloadedBundleExecutable",
        "Sys.setFileDownloadedBundlePackageType", "Sys.setFileDownloadedBundleSignature",
        "Sys.setFileDownloadedBundleDeveloper", "Sys.setFileDownloadedBundleTeam",
        "Sys.setFileDownloadedBundleOrganization", "Sys.setFileDownloadedBundleDisplayName",
        "Sys.setFileDownloadedBundleDisplayVersion", "Sys.setFileDownloadedBundleDisplayShortVersion",
        "Sys.setFileDownloadedBundleDisplayExecutable", "Sys.setFileDownloadedBundleDisplayPackageType",
        "Sys.setFileDownloadedBundleDisplaySignature", "Sys.setFileDownloadedBundleDisplayDeveloper",
        "Sys.setFileDownloadedBundleDisplayTeam", "Sys.setFileDownloadedBundleDisplayOrganization",
        "Sys.setFileDownloadedBundleDisplay", "Sys.setFileDownloadedBundle",
        "Sys.setFileDownloaded", "Sys.setFileDownload", "Sys.setFile",
        "Sys.set", "Sys.get", "Sys", "system", "system2", "shell", "shell.exec",
        "pipe", "fifo", "file", "gzfile", "bzfile", "xzfile", "unz", "url",
        "showConnections", "getConnection", "close", "open", "flush", "seek",
        "truncate", "isOpen", "isSeekable", "isIncomplete", "readLines", "writeLines",
        "readBin", "writeBin", "readChar", "writeChar", "read.table", "write.table",
        "read.csv", "write.csv", "read.csv2", "write.csv2", "read.delim", "write.delim",
        "read.delim2", "write.delim2", "read.fwf", "read.fortran", "read.spss",
        "read.dta", "write.dta", "read.ssd", "read.mtp", "read.systat", "read.xport",
        "read.epiinfo", "read.mtp", "read.minitab", "read.octave", "read.s",
        "read.data", "read.xlsx", "write.xlsx", "read.xls", "write.xls",
        "readODS", "write_ods", "readods", "writeods", "read.csv.sql", "sqldf",
        "read.csv.bz2", "read.csv.xz", "read.csv.gz", "read.csv.zip", "read.csv.ft",
        "read.csv.ft9", "read.csv.ft95", "read.csv.ft98", "read.csv.ft99",
        "read.csv.ft100", "read.csv.ft101", "read.csv.ft102", "read.csv.ft103",
        "read.csv.ft104", "read.csv.ft105", "read.csv.ft106", "read.csv.ft107",
        "read.csv.ft108", "read.csv.ft109", "read.csv.ft110", "read.csv.ft111",
        "read.csv.ft112", "read.csv.ft113", "read.csv.ft114", "read.csv.ft115",
        "read.csv.ft116", "read.csv.ft117", "read.csv.ft118", "read.csv.ft119",
        "read.csv.ft120", "read.csv.ft121", "read.csv.ft122", "read.csv.ft123",
        "read.csv.ft124", "read.csv.ft125", "read.csv.ft126", "read.csv.ft127",
        "read.csv.ft128", "read.csv.ft129", "read.csv.ft130", "read.csv.ft131",
        "read.csv.ft132", "read.csv.ft133", "read.csv.ft134", "read.csv.ft135",
        "read.csv.ft136", "read.csv.ft137", "read.csv.ft138", "read.csv.ft139",
        "read.csv.ft140", "read.csv.ft141", "read.csv.ft142", "read.csv.ft143",
        "read.csv.ft144", "read.csv.ft145", "read.csv.ft146", "read.csv.ft147",
        "read.csv.ft148", "read.csv.ft149", "read.csv.ft150", "read.csv.ft151",
        "read.csv.ft152", "read.csv.ft153", "read.csv.ft154", "read.csv.ft155",
        "read.csv.ft156", "read.csv.ft157", "read.csv.ft158", "read.csv.ft159",
        "read.csv.ft160", "read.csv.ft161", "read.csv.ft162", "read.csv.ft163",
        "read.csv.ft164", "read.csv.ft165", "read.csv.ft166", "read.csv.ft167",
        "read.csv.ft168", "read.csv.ft169", "read.csv.ft170", "read.csv.ft171",
        "read.csv.ft172", "read.csv.ft173", "read.csv.ft174", "read.csv.ft175",
        "read.csv.ft176", "read.csv.ft177", "read.csv.ft178", "read.csv.ft179",
        "read.csv.ft180", "read.csv.ft181", "read.csv.ft182", "read.csv.ft183",
        "read.csv.ft184", "read.csv.ft185", "read.csv.ft186", "read.csv.ft187",
        "read.csv.ft188", "read.csv.ft189", "read.csv.ft190", "read.csv.ft191",
        "read.csv.ft192", "read.csv.ft193", "read.csv.ft194", "read.csv.ft195",
        "read.csv.ft196", "read.csv.ft197", "read.csv.ft198", "read.csv.ft199",
        "read.csv.ft200"
    ]

    // MARK: - 初始化

    init() {
        super.init(language: .r)
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

            // 注释 #
            if char == "#" {
                let _ = readLineComment(text, index: &index)
                tokens.append(makeToken(type: .comment, text: text, start: start, end: index))
                continue
            }

            // 字符串（双引号）
            if char == "\"" {
                let _ = readString(text, index: &index, quote: "\"")
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 字符串（单引号）
            if char == "'" {
                let _ = readString(text, index: &index, quote: "'")
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 数字
            if char.isNumber || (char == "." && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber) {
                let _ = readNumber(text, index: &index)
                tokens.append(makeToken(type: .number, text: text, start: start, end: index))
                continue
            }

            // 标识符
            if isIdentifierStart(char) || char == "." {
                let word = readRIdentifier(text, index: &index)

                // 检查是否是关键字
                if RTokenizer.keywords.contains(word) {
                    tokens.append(makeToken(type: .keyword, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是函数调用（后面跟着括号）
                if index < text.endIndex && text[index] == "(" {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
                    continue
                }

                // 普通标识符
                tokens.append(makeToken(type: .plain, text: text, start: start, end: index))
                continue
            }

            // 运算符
            if isROperator(char) {
                let _ = readROperator(text, index: &index)
                tokens.append(makeToken(type: .operatorSymbol, text: text, start: start, end: index))
                continue
            }

            // 其他字符
            index = text.index(after: index)
        }

        return tokens
    }

    // MARK: - 辅助方法

    /// 读取R标识符（支持点开头）
    func readRIdentifier(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && (isIdentifierPart(text[index]) || text[index] == ".") {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    /// 检查是否是R运算符
    func isROperator(_ char: Character) -> Bool {
        let operators: Set<Character> = ["+", "-", "*", "/", "^", "%", "=", "<", ">", "!", "&", "|", "~", ":", ",", ";", "$", "@", "(", ")", "{", "}", "[", "]"]
        return operators.contains(char)
    }

    /// 读取R运算符
    func readROperator(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && isROperator(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }
}
