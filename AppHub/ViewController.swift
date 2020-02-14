// Created by Haitao Li on 1/30/20.

import Cocoa
import UserNotifications
import WebKit

class ViewController: NSViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    let userScriptURL = Bundle.main.url(forResource: "NotificationUserScript", withExtension: "js")!
    let userScriptCode = try! String(contentsOf: userScriptURL)
    let userScript = WKUserScript(source: userScriptCode, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.addUserScript(userScript)
    configuration.userContentController.add(self, name: "notify")
    configuration.applicationNameForUserAgent = "Version/\(safariVersion()) Safari/0.0.0"

    if let cssUserScript = userScriptForCSS() {
      configuration.userContentController.addUserScript(cssUserScript)
    }
    
    webView = WKWebView(frame: self.view.bounds, configuration: configuration)

    webView.navigationDelegate = self
    webView.uiDelegate = self
    webView.autoresizingMask = [.height, .width]
    view.addSubview(webView)

    webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)

    let url = URL(string: "https://www.gmail.com")
    let request = URLRequest(url: url!)

    self.webView.load(request)
  }

  override var representedObject: Any? {
    didSet {
      // Update the view, if already loaded.
    }
  }

  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    switch keyPath {
    case "title":
      self.view.window?.title = webView.title ?? ""
      NSApplication.shared.dockTile.badgeLabel = parseNumber(webView.title)
      break
    default:
      break
    }
  }

  private func safariVersion() -> String {
    let safariVersionPlist = URL(fileURLWithPath: "/Applications/Safari.app/Contents/version.plist")
    let plist = NSDictionary(contentsOf: safariVersionPlist) as! [String: Any]
    let safariVersion = plist["CFBundleShortVersionString"] as! String

    return safariVersion
  }

  private func parseNumber(_ title: String?) -> String? {
    guard let title = title else { return nil }

    let regex = try! NSRegularExpression(pattern: #"\((\d+)\)"#, options: [])

    if let match = regex.firstMatch(in: title, options: [], range: NSRange(location: 0, length: title.count)),
       let numberRange = Range(match.range(at: 1), in: title)
    {
      let number = title[numberRange]
      return String(number)
    }

    return nil
  }

  private func userScriptForCSS() -> WKUserScript? {
    guard let path = Bundle.main.path(forResource: "site", ofType: "css") else {
      return nil
    }

    let cssString = try! String(contentsOfFile: path).components(separatedBy: .newlines).joined()

    let source = """
      var style = document.createElement('style');
      style.innerHTML = '\(cssString)';
      document.head.appendChild(style);
    """

    return WKUserScript(
      source: source,
      injectionTime: .atDocumentEnd,
      forMainFrameOnly: true)
  }

  private var webView: WKWebView!
}

extension ViewController: WKNavigationDelegate {
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
  {
    guard let url = navigationAction.request.url
    else {
      decisionHandler(.cancel)
      return
    }

    guard let targetFrame = navigationAction.targetFrame else {
      // Opening a new tab
      decisionHandler(.cancel)
      NSWorkspace.shared.open(url)
      return
    }

    if !targetFrame.isMainFrame {
      // Allow all navigation in subframes
      decisionHandler(.allow)
      return
    }

    if webView.isHidden {
      // Navigation inside a new tab (window.open?)
      webView.removeFromSuperview()
      decisionHandler(.cancel)
      NSWorkspace.shared.open(url)
      return
    }

    decisionHandler(.allow)
  }
}

extension ViewController: WKUIDelegate {
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView?
  {
    let windowSize = view.bounds.size

    if let width = windowFeatures.width?.intValue, let height = windowFeatures.height?.intValue {
      let x = windowFeatures.x?.intValue ?? (Int(windowSize.width.native) - width)/2
      let y = windowFeatures.y?.intValue ?? (Int(windowSize.height.native) - height)/2

      /*
      let contentRect = NSRect(x: x, y: y, width: width, height: height)
      // Popup window
      let window = NSWindow(
        contentRect: contentRect,
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false)
      */

      let frame = NSRect(x: x, y: y, width: width, height: height)
      let webView = WKWebView(frame: frame, configuration: configuration)
      webView.autoresizingMask = [.height, .width]
      webView.navigationDelegate = self
      webView.uiDelegate = self
      self.view.addSubview(webView)
      // window.contentView?.addSubview(webView)

      // NSApplication.shared.runModal(for: window)
      return webView
    }

    // A new tab
    if let url = navigationAction.request.url,
       url.scheme != nil,
       url.scheme != "about"
    {
      NSWorkspace.shared.open(url)
      return nil
    } else {
      // We don't have the URL yet, build a hidden WKWebView and wait for navigation
      let webView = WKWebView(frame: .zero, configuration: configuration)
      webView.navigationDelegate = self
      webView.isHidden = true
      self.view.addSubview(webView)
      return webView
    }
  }

  func webViewDidClose(_ webView: WKWebView) {
    webView.removeFromSuperview()
  }
}

extension ViewController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard
      let data = message.body as? [String: Any],
      let options = data["options"] as? [String: Any]
    else { return }

    let content = UNMutableNotificationContent()
    content.title = data["title"] as? String ?? ""
    content.body = options["body"] as? String ?? ""

    let uuidString = UUID().uuidString
    let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: nil)

    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.add(request) { error in
      if error != nil {
        NSLog(error.debugDescription)
      }
    }
  }
}
