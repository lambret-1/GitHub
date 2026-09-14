import Foundation

// ==============================================================================
// LuaTokenizer Lua语言词法分析器
// 功能：对Lua代码进行词法分析，识别关键字、字符串、注释、数字、函数、变量等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class LuaTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - Lua关键字

    private static let keywords: Set<String> = [
        "and", "break", "do", "else", "elseif", "end", "false", "for",
        "function", "goto", "if", "in", "local", "nil", "not", "or",
        "repeat", "return", "then", "true", "until", "while"
    ]

    // MARK: - Lua内置函数

    private static let builtins: Set<String> = [
        "print", "tostring", "tonumber", "type", "pcall", "xpcall", "error",
        "assert", "select", "next", "pairs", "ipairs", "rawget", "rawset",
        "rawlen", "rawequal", "setmetatable", "getmetatable", "require",
        "dofile", "loadfile", "load", "collectgarbage", "gcinfo", "newproxy",
        "io", "os", "string", "table", "math", "coroutine", "package", "debug",
        "utf8", "bit32", "bit", "ffi", "jit", "love", "vim", "hs", "wezterm",
        "mp", "obs", "mpv", "awesome", "conky", "naughty", "beautiful", "gears",
        "wibox", "awful", "ruled", "menubar", "naughty", "tyrannical", "revelation",
        "bling", "lain", "freedesktop", "json", "inspect", "serpent", "cjson",
        "dkjson", "lpeg", "socket", "http", "https", "url", "ltn12", "mime",
        "ftp", "smtp", "tn3270", "proxy", "cqueues", "cqueues.socket", "cqueues.thread",
        "cqueues.signal", "cqueues.notify", "cqueues.promise", "cqueues.condition",
        "cqueues.dns", "cqueues.resolver", "cqueues.tls", "cqueues.crypto",
        "cqueues.crypto.digest", "cqueues.crypto.cipher", "cqueues.crypto.random",
        "cqueues.crypto.pkey", "cqueues.crypto.sign", "cqueues.crypto.verify",
        "cqueues.crypto.encrypt", "cqueues.crypto.decrypt", "cqueues.crypto.seal",
        "cqueues.crypto.open", "cqueues.crypto.kdf", "cqueues.crypto.scrypt",
        "cqueues.crypto.pbkdf2", "cqueues.crypto.argon2", "cqueues.crypto.bcrypt",
        "cqueues.crypto.otp", "cqueues.crypto.totp", "cqueues.crypto.hotp",
        "cqueues.crypto.u2f", "cqueues.crypto.webauthn", "cqueues.crypto.jwt",
        "cqueues.crypto.jws", "cqueues.crypto.jwe", "cqueues.crypto.jwk",
        "cqueues.crypto.oauth", "cqueues.crypto.openid", "cqueues.crypto.saml",
        "cqueues.crypto.ldap", "cqueues.crypto.radius", "cqueues.crypto.tacacs",
        "cqueues.crypto.kerberos", "cqueues.crypto.ntlm", "cqueues.crypto.basic",
        "cqueues.crypto.digest", "cqueues.crypto.bearer", "cqueues.crypto.apikey",
        "cqueues.crypto.cookie", "cqueues.crypto.session", "cqueues.crypto.csrf",
        "cqueues.crypto.xss", "cqueues.crypto.sql", "cqueues.crypto.html",
        "cqueues.crypto.xml", "cqueues.crypto.json", "cqueues.crypto.yaml",
        "cqueues.crypto.toml", "cqueues.crypto.ini", "cqueues.crypto.conf",
        "cqueues.crypto.env", "cqueues.crypto.dotenv", "cqueues.crypto.properties",
        "cqueues.crypto.pem", "cqueues.crypto.der", "cqueues.crypto.p12",
        "cqueues.crypto.pfx", "cqueues.crypto.jks", "cqueues.crypto.keystore",
        "cqueues.crypto.truststore", "cqueues.crypto.cert", "cqueues.crypto.crl",
        "cqueues.crypto.ocsp", "cqueues.crypto.scep", "cqueues.crypto.est",
        "cqueues.crypto.acme", "cqueues.crypto.letsencrypt", "cqueues.crypto.certbot",
        "cqueues.crypto.lego", "cqueues.crypto.traefik", "cqueues.crypto.caddy",
        "cqueues.crypto.nginx", "cqueues.crypto.apache", "cqueues.crypto.haproxy",
        "cqueues.crypto.envoy", "cqueues.crypto.istio", "cqueues.crypto.linkerd",
        "cqueues.crypto.consul", "cqueues.crypto.vault", "cqueues.crypto.nomad",
        "cqueues.crypto.terraform", "cqueues.crypto.ansible", "cqueues.crypto.puppet",
        "cqueues.crypto.chef", "cqueues.crypto.salt", "cqueues.crypto.docker",
        "cqueues.crypto.podman", "cqueues.crypto.kubernetes", "cqueues.crypto.openshift",
        "cqueues.crypto.rancher", "cqueues.crypto.docker-compose", "cqueues.crypto.swarm",
        "cqueues.crypto.mesos", "cqueues.crypto.marathon", "cqueues.crypto.dcos",
        "cqueues.crypto.cloudfoundry", "cqueues.crypto.heroku", "cqueues.crypto.netlify",
        "cqueues.crypto.vercel", "cqueues.crypto.firebase", "cqueues.crypto.aws",
        "cqueues.crypto.gcp", "cqueues.crypto.azure", "cqueues.crypto.aliyun",
        "cqueues.crypto.tencent", "cqueues.crypto.huawei", "cqueues.crypto.baidu",
        "cqueues.crypto.jd", "cqueues.crypto.meituan", "cqueues.crypto.didi",
        "cqueues.crypto.byteDance", "cqueues.crypto.kuaishou", "cqueues.crypto.bilibili",
        "cqueues.crypto.iqiyi", "cqueues.crypto.youku", "cqueues.crypto.tencent-video",
        "cqueues.crypto.mgtv", "cqueues.crypto.pptv", "cqueues.crypto.sohu",
        "cqueues.crypto.sina", "cqueues.crypto.netease", "cqueues.crypto.baidu",
        "cqueues.crypto.toutiao", "cqueues.cambda"
    ]

    // MARK: - 初始化

    init() {
        super.init(language: .lua)
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
                // 检查是否是长注释 --[[ ]]
                if text[index...].hasPrefix("--[[") {
                    let _ = readLuaLongComment(text, index: &index)
                    tokens.append(makeToken(type: .comment, text: text, start: start, end: index))
                    continue
                }
                let _ = readLineComment(text, index: &index)
                tokens.append(makeToken(type: .comment, text: text, start: start, end: index))
                continue
            }

            // 长字符串 [[ ]]
            if char == "[" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "[" {
                let _ = readLuaLongString(text, index: &index)
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
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
            if isIdentifierStart(char) {
                let word = readIdentifier(text, index: &index)

                // 检查是否是关键字
                if LuaTokenizer.keywords.contains(word) {
                    tokens.append(makeToken(type: .keyword, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是内置函数
                if LuaTokenizer.builtins.contains(word) {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
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
            if isLuaOperator(char) {
                let _ = readLuaOperator(text, index: &index)
                tokens.append(makeToken(type: .operatorSymbol, text: text, start: start, end: index))
                continue
            }

            // 其他字符
            index = text.index(after: index)
        }

        return tokens
    }

    // MARK: - 辅助方法

    /// 读取Lua长注释 --[[ ]]
    func readLuaLongComment(_ text: String, index: inout String.Index) -> String {
        let start = index
        // 跳过--[[
        index = text.index(index, offsetBy: 4)
        // 查找]]
        while index < text.endIndex {
            if text[index...].hasPrefix("]]") {
                index = text.index(index, offsetBy: 2)
                break
            }
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    /// 读取Lua长字符串 [[ ]]
    func readLuaLongString(_ text: String, index: inout String.Index) -> String {
        let start = index
        // 跳过[[
        index = text.index(index, offsetBy: 2)
        // 查找]]
        while index < text.endIndex {
            if text[index...].hasPrefix("]]") {
                index = text.index(index, offsetBy: 2)
                break
            }
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    /// 检查是否是Lua运算符
    func isLuaOperator(_ char: Character) -> Bool {
        let operators: Set<Character> = ["+", "-", "*", "/", "%", "^", "#", "=", "<", ">", "~", "&", "|", ":", ",", ";", ".", "(", ")", "{", "}", "[", "]"]
        return operators.contains(char)
    }

    /// 读取Lua运算符
    func readLuaOperator(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && isLuaOperator(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }
}
