import Foundation

// ==============================================================================
// ShellTokenizer Shell/Bash语言词法分析器
// 功能：对Shell/Bash代码进行词法分析，识别关键字、字符串、注释、数字、函数、变量等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class ShellTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - Shell关键字

    private static let keywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "case", "esac", "for", "select",
        "while", "until", "do", "done", "in", "function", "time", "coproc",
        "!", "{", "}", "[[", "]]", "test", "exit", "return", "break", "continue",
        "export", "local", "readonly", "declare", "typeset", "unset", "shift",
        "set", "unset", "alias", "unalias", "builtin", "command", "compgen",
        "complete", "compopt", "continue", "dirs", "disown", "echo", "enable",
        "eval", "exec", "false", "fc", "fg", "getopts", "hash", "help", "history",
        "jobs", "kill", "let", "logout", "mapfile", "popd", "printf", "pushd",
        "pwd", "read", "readarray", "readonly", "return", "set", "shift", "shopt",
        "source", "suspend", "test", "times", "trap", "true", "type", "typeset",
        "ulimit", "umask", "unalias", "unset", "wait", "yes", "zmodload",
        "autoload", "bg", "bind", "bindkey", "bye", "chdir", "comparguments",
        "compcall", "compdef", "compdescribe", "compfiles", "compgroups", "compquote",
        "comptags", "comptry", "compvalues", "compwidget", "echotc", "echoti",
        "emulate", "fc", "float", "functions", "getln", "history", "integer",
        "kill", "limit", "log", "noglob", "popd", "print", "printf", "prompt",
        "pushd", "pushln", "r", "read", "readonly", "rehash", "repeat", "return",
        "sched", "set", "setopt", "shift", "source", "suspend", "test", "times",
        "trap", "true", "type", "typeset", "ulimit", "umask", "unalias", "unfunction",
        "unhash", "unlimit", "unset", "unsetopt", "wait", "whence", "where",
        "which", "zcompile", "zformat", "zftp", "zle", "zmodload", "zparseopts",
        "zprof", "zpty", "zregexparse", "zsocket", "zstyle", "ztcp", "zftp"
    ]

    // MARK: - Shell内置命令

    private static let builtins: Set<String> = [
        "echo", "printf", "read", "cd", "pwd", "ls", "cat", "grep", "sed", "awk",
        "cut", "sort", "uniq", "wc", "head", "tail", "tr", "tee", "xargs", "find",
        "locate", "which", "whereis", "whatis", "man", "info", "help", "apropos",
        "date", "cal", "time", "uptime", "w", "who", "whoami", "id", "groups",
        "users", "last", "lastlog", "finger", "write", "wall", "mesg", "talk",
        "mail", "mailx", "mutt", "pine", "elm", "vi", "vim", "emacs", "nano",
        "pico", "ed", "ex", "sed", "awk", "perl", "python", "ruby", "php",
        "node", "deno", "bun", "go", "rustc", "cargo", "javac", "java", "kotlin",
        "swift", "swiftc", "clang", "clang++", "gcc", "g++", "make", "cmake",
        "ninja", "meson", "autoconf", "automake", "libtool", "pkg-config",
        "git", "svn", "hg", "bzr", "cvs", "fossil", "darcs", "pijul", "jj",
        "docker", "podman", "kubectl", "helm", "terraform", "ansible", "vagrant",
        "ssh", "scp", "sftp", "rsync", "curl", "wget", "httpie", "aria2c",
        "tar", "zip", "unzip", "gzip", "gunzip", "bzip2", "bunzip2", "xz",
        "unxz", "lzma", "unlzma", "zstd", "unzstd", "7z", "rar", "unrar",
        "chmod", "chown", "chgrp", "chattr", "lsattr", "chroot", "mount",
        "umount", "fsck", "mkfs", "fdisk", "parted", "gdisk", "cfdisk",
        "df", "du", "free", "vmstat", "iostat", "sar", "top", "htop", "btop",
        "glances", "nmon", "dstat", "pidstat", "mpstat", "netstat", "ss",
        "ip", "ifconfig", "route", "arp", "ping", "traceroute", "mtr", "dig",
        "nslookup", "host", "getent", "resolvectl", "systemd-resolve", "nmap",
        "tcpdump", "wireshark", "tshark", "netcat", "nc", "socat", "telnet",
        "openssl", "ssh-keygen", "ssh-copy-id", "ssh-agent", "ssh-add",
        "gpg", "gpg2", "pass", "openssl", "keytool", "certutil", "pk12util",
        "cron", "crontab", "at", "batch", "systemctl", "service", "journalctl",
        "loginctl", "hostnamectl", "timedatectl", "localectl", "bootctl",
        "kernel-install", "machinectl", "portablectl", "systemd-analyze",
        "systemd-cgls", "systemd-cgtop", "systemd-delta", "systemd-detect-virt",
        "systemd-escape", "systemd-hwdb", "systemd-id128", "systemd-machine-id-setup",
        "systemd-mount", "systemd-notify", "systemd-nspawn", "systemd-path",
        "systemd-run", "systemd-socket-activate", "systemd-stdio-bridge",
        "systemd-sysusers", "systemd-tmpfiles", "systemd-tty-ask-password-agent",
        "systemd-umount", "systemd-user-sessions", "udevadm", "dbus-send",
        "dbus-monitor", "dbus-launch", "dbus-uuidgen", "busctl", "systemd",
        "apt", "apt-get", "apt-cache", "apt-config", "dpkg", "dpkg-reconfigure",
        "yum", "dnf", "rpm", "zypper", "pacman", "yaourt", "yay", "paru",
        "emerge", "equery", "eix", "layman", "eselect", "revdep-rebuild",
        "brew", "port", "fink", "choco", "scoop", "winget", "snap", "flatpak",
        "appimage", "nix", "nix-env", "nix-shell", "guix", "spack", "easybuild",
        "module", "lmod", "environment-modules", "conda", "mamba", "micromamba",
        "pip", "pip3", "pipx", "poetry", "uv", "pdm", "hatch", "flit", "setuptools",
        "npm", "yarn", "pnpm", "bun", "npx", "lerna", "nx", "turbo", "rush",
        "maven", "mvn", "gradle", "ant", "ivy", "sbt", "mill", "bazel", "buck",
        "pants", "please", "build2", "meson", "cmake", "make", "ninja", "gn",
        "xcodebuild", "xcrun", "simctl", "swift", "swiftc", "swift package",
        "pod", "pod install", "pod update", "carthage", "swift package",
        "tuist", "xcodegen", "fastlane", "match", "gym", "sigh", "deliver",
        "pilot", "boarding", "screengrab", "frameit", "pem", "cert", "produce",
        "register_devices", "match", "precheck", "supply", "beta", "testflight",
        "appstore", "itunesconnect", "spaceship", "pilot", "boarding", "screengrab",
        "frameit", "pem", "cert", "produce", "register_devices", "match", "precheck",
        "supply", "beta", "testflight", "appstore", "itunesconnect", "spaceship"
    ]

    // MARK: - 初始化

    init() {
        super.init(language: .shell)
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

            // 变量 $
            if char == "$" {
                let _ = readShellVariable(text, index: &index)
                tokens.append(makeToken(type: .variable, text: text, start: start, end: index))
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

            // 反引号命令替换
            if char == "`" {
                let _ = readString(text, index: &index, quote: "`")
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 数字
            if char.isNumber {
                let _ = readNumber(text, index: &index)
                tokens.append(makeToken(type: .number, text: text, start: start, end: index))
                continue
            }

            // 标识符
            if isIdentifierStart(char) {
                let word = readIdentifier(text, index: &index)

                // 检查是否是关键字
                if ShellTokenizer.keywords.contains(word) {
                    tokens.append(makeToken(type: .keyword, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是内置命令
                if ShellTokenizer.builtins.contains(word) {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是函数调用（后面跟着括号）
                if index < text.endIndex && text[index] == "(" {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
                    continue
                }

                // 普通命令
                tokens.append(makeToken(type: .plain, text: text, start: start, end: index))
                continue
            }

            // 运算符和特殊字符
            if isShellOperator(char) {
                let _ = readShellOperator(text, index: &index)
                tokens.append(makeToken(type: .operatorSymbol, text: text, start: start, end: index))
                continue
            }

            // 其他字符
            index = text.index(after: index)
        }

        return tokens
    }

    // MARK: - 辅助方法

    /// 读取Shell变量
    func readShellVariable(_ text: String, index: inout String.Index) -> String {
        let start = index
        // 跳过$
        index = text.index(after: index)

        // 检查是否是 ${...} 形式
        if index < text.endIndex && text[index] == "{" {
            index = text.index(after: index)
            while index < text.endIndex && text[index] != "}" {
                index = text.index(after: index)
            }
            if index < text.endIndex {
                index = text.index(after: index) // 跳过}
            }
            return String(text[start..<index])
        }

        // 读取标识符
        while index < text.endIndex && isIdentifierPart(text[index]) {
            index = text.index(after: index)
        }

        // 特殊变量 $? $! $$ $# $* $@ $0-$9
        if index == text.index(after: start) && index < text.endIndex {
            let specialChars: Set<Character> = ["?", "!", "$", "#", "*", "@", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "_"]
            if specialChars.contains(text[index]) {
                index = text.index(after: index)
            }
        }

        return String(text[start..<index])
    }

    /// 检查是否是Shell运算符
    func isShellOperator(_ char: Character) -> Bool {
        let operators: Set<Character> = ["|", "&", ";", ">", "<", "(", ")", "{", "}", "!", "=", "+", "-", "*", "/", "%", "^", "~", "?", ":", ",", "."]
        return operators.contains(char)
    }

    /// 读取Shell运算符
    func readShellOperator(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && isShellOperator(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }
}
