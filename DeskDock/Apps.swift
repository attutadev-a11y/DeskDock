import UIKit
import WebKit
import JavaScriptCore

// MARK: - Code editor with a JavaScript runner

final class CodeEditorView: UIView, UITextViewDelegate {

    private let toolbar = UIView()
    private let runButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let fileLabel = UILabel()
    private let editor = UITextView()
    private let console = UITextView()

    private static var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("main.js")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)

        toolbar.backgroundColor = UIColor(white: 0.17, alpha: 1)
        addSubview(toolbar)

        runButton.setTitle("▶ Run", for: .normal)
        runButton.setTitleColor(.white, for: .normal)
        runButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        runButton.backgroundColor = UIColor(red: 0.2, green: 0.62, blue: 0.35, alpha: 1)
        runButton.layer.cornerRadius = 7
        runButton.addTarget(self, action: #selector(run), for: .touchUpInside)
        toolbar.addSubview(runButton)

        clearButton.setTitle("Clear output", for: .normal)
        clearButton.setTitleColor(UIColor(white: 0.75, alpha: 1), for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 12)
        clearButton.addTarget(self, action: #selector(clearConsole), for: .touchUpInside)
        toolbar.addSubview(clearButton)

        fileLabel.text = "main.js — JavaScript"
        fileLabel.font = .systemFont(ofSize: 12)
        fileLabel.textColor = UIColor(white: 0.6, alpha: 1)
        fileLabel.textAlignment = .right
        toolbar.addSubview(fileLabel)

        editor.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
        editor.textColor = UIColor(red: 0.83, green: 0.85, blue: 0.85, alpha: 1)
        editor.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        editor.autocorrectionType = .no
        editor.autocapitalizationType = .none
        editor.smartQuotesType = .no
        editor.smartDashesType = .no
        editor.smartInsertDeleteType = .no
        editor.spellCheckingType = .no
        editor.alwaysBounceVertical = true
        editor.delegate = self
        addSubview(editor)

        console.backgroundColor = UIColor(white: 0.05, alpha: 1)
        console.textColor = UIColor(red: 0.45, green: 0.9, blue: 0.55, alpha: 1)
        console.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        console.isEditable = false
        console.text = "console output…"
        addSubview(console)

        if let saved = try? String(contentsOf: Self.saveURL, encoding: .utf8), !saved.isEmpty {
            editor.text = saved
        } else {
            editor.text = """
            // Welcome to DeskDock — code on your monitor, straight from your iPhone.
            // Press ▶ Run to execute. console.log prints below.

            function fib(n) {
              return n < 2 ? n : fib(n - 1) + fib(n - 2);
            }

            for (let i = 0; i < 10; i++) {
              console.log("fib(" + i + ") = " + fib(i));
            }
            """
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        toolbar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 40)
        runButton.frame = CGRect(x: 10, y: 7, width: 74, height: 26)
        clearButton.frame = CGRect(x: 94, y: 7, width: 100, height: 26)
        fileLabel.frame = CGRect(x: bounds.width - 190, y: 0, width: 180, height: 40)
        let consoleHeight: CGFloat = min(150, bounds.height * 0.3)
        editor.frame = CGRect(x: 0, y: 40, width: bounds.width,
                              height: bounds.height - 40 - consoleHeight)
        console.frame = CGRect(x: 0, y: bounds.height - consoleHeight,
                               width: bounds.width, height: consoleHeight)
    }

    func textViewDidChange(_ textView: UITextView) {
        guard textView === editor else { return }
        try? editor.text.write(to: Self.saveURL, atomically: true, encoding: .utf8)
    }

    @objc private func clearConsole() {
        console.text = ""
    }

    @objc private func run() {
        console.text = ""
        guard let context = JSContext() else {
            appendConsole("⚠️ Could not create a JavaScript context")
            return
        }
        let log: @convention(block) (String) -> Void = { [weak self] msg in
            self?.appendConsole(msg)
        }
        context.setObject(log, forKeyedSubscript: "__nativeLog" as NSString)
        context.evaluateScript("""
            var console = { log: function() {
                __nativeLog(Array.prototype.map.call(arguments, String).join(' '));
            }};
            console.error = console.warn = console.info = console.log;
            var print = console.log;
            """)
        context.exceptionHandler = { [weak self] _, exception in
            let msg = exception?.toString() ?? "unknown error"
            self?.appendConsole("⚠️ " + msg)
        }
        let result = context.evaluateScript(editor.text)
        if let r = result, !r.isUndefined, !r.isNull {
            appendConsole("→ " + (r.toString() ?? ""))
        }
        if console.text.isEmpty {
            appendConsole("(finished — no output)")
        }
    }

    private func appendConsole(_ line: String) {
        console.text = (console.text ?? "") + line + "\n"
        let end = NSRange(location: (console.text as NSString).length, length: 0)
        console.scrollRangeToVisible(end)
    }
}

// MARK: - Browser

final class BrowserView: UIView, WKNavigationDelegate {

    private let toolbar = UIView()
    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let reloadButton = UIButton(type: .system)
    let urlField = UITextField()
    private let goButton = UIButton(type: .system)
    private let webView: WKWebView

    override init(frame: CGRect) {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init(frame: frame)
        backgroundColor = .white

        toolbar.backgroundColor = UIColor(white: 0.17, alpha: 1)
        addSubview(toolbar)

        func navButton(_ b: UIButton, _ title: String, _ action: Selector) {
            b.setTitle(title, for: .normal)
            b.setTitleColor(.white, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            b.addTarget(self, action: action, for: .touchUpInside)
            toolbar.addSubview(b)
        }
        navButton(backButton, "‹", #selector(goBack))
        navButton(forwardButton, "›", #selector(goForward))
        navButton(reloadButton, "↻", #selector(reload))

        urlField.backgroundColor = UIColor(white: 0.28, alpha: 1)
        urlField.textColor = .white
        urlField.font = .systemFont(ofSize: 13)
        urlField.layer.cornerRadius = 7
        urlField.autocorrectionType = .no
        urlField.autocapitalizationType = .none
        urlField.smartQuotesType = .no
        urlField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        urlField.leftViewMode = .always
        urlField.text = "google.com"
        urlField.addTarget(self, action: #selector(go), for: .editingDidEndOnExit)
        toolbar.addSubview(urlField)

        goButton.setTitle("Go", for: .normal)
        goButton.setTitleColor(.white, for: .normal)
        goButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        goButton.backgroundColor = UIColor(red: 0.31, green: 0.56, blue: 0.97, alpha: 1)
        goButton.layer.cornerRadius = 7
        goButton.addTarget(self, action: #selector(go), for: .touchUpInside)
        toolbar.addSubview(goButton)

        webView.navigationDelegate = self
        addSubview(webView)
        go()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        toolbar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 40)
        backButton.frame = CGRect(x: 8, y: 4, width: 30, height: 32)
        forwardButton.frame = CGRect(x: 38, y: 4, width: 30, height: 32)
        reloadButton.frame = CGRect(x: 68, y: 4, width: 30, height: 32)
        goButton.frame = CGRect(x: bounds.width - 52, y: 7, width: 44, height: 26)
        urlField.frame = CGRect(x: 104, y: 7, width: bounds.width - 104 - 60, height: 26)
        webView.frame = CGRect(x: 0, y: 40, width: bounds.width, height: bounds.height - 40)
    }

    @objc private func goBack() { webView.goBack() }
    @objc private func goForward() { webView.goForward() }
    @objc private func reload() { webView.reload() }

    @objc private func go() {
        var text = (urlField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !text.contains(".") || text.contains(" ") {
            let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            text = "https://www.google.com/search?q=" + q
        } else if !text.lowercased().hasPrefix("http") {
            text = "https://" + text
        }
        if let url = URL(string: text) {
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        urlField.text = webView.url?.absoluteString
    }
}

// MARK: - Notes

final class NotesView: UIView, UITextViewDelegate {

    private let textView = UITextView()

    private static var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("notes.txt")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        textView.backgroundColor = UIColor(red: 1.0, green: 0.98, blue: 0.86, alpha: 1)
        textView.textColor = UIColor(white: 0.15, alpha: 1)
        textView.font = .systemFont(ofSize: 15)
        textView.autocorrectionType = .no
        textView.smartQuotesType = .no
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.delegate = self
        textView.text = (try? String(contentsOf: Self.saveURL, encoding: .utf8)) ?? ""
        addSubview(textView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
    }

    func textViewDidChange(_ textView: UITextView) {
        try? textView.text.write(to: Self.saveURL, atomically: true, encoding: .utf8)
    }
}
