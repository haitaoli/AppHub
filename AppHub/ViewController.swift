// Created by Haitao Li on 1/30/20.

import Cocoa
import UserNotifications
import WebKit

class ViewController: NSViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    let configuration = WKWebViewConfiguration()

    configuration.applicationNameForUserAgent = "Version/\(safariVersion()) Safari/0.0.0"

    let notificationUserScript = loadUserScript(name: "NotificationUserScript", injectionTime: .atDocumentEnd)
    configuration.userContentController.addUserScript(notificationUserScript)
    configuration.userContentController.add(self, name: "notify")

    if let cssUserScript = userScriptForCSS() {
      configuration.userContentController.addUserScript(cssUserScript)
    }

    var rect = view.bounds
    rect.size.height += topMarginToCut

    webView = WKWebView(frame: rect, configuration: configuration)

    webView.navigationDelegate = self
    webView.uiDelegate = self
    webView.autoresizingMask = [.height, .width]
    view.addSubview(webView)

    webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)

    let url = URL(string: "https://mail.google.com/")
    let request = URLRequest(url: url!)

    self.webView.load(request)
  }

  override func viewDidAppear() {
    view.window?.delegate = self
  }

  override var representedObject: Any? {
    didSet {
      // Update the view, if already loaded.
    }
  }

  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    switch keyPath {
    case "title":
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

  private func loadUserScript(name: String, injectionTime: WKUserScriptInjectionTime) -> WKUserScript {
    let userScriptURL = Bundle.main.url(forResource: name, withExtension: "js")!
    let userScriptCode = try! String(contentsOf: userScriptURL)
    return WKUserScript(source: userScriptCode, injectionTime: injectionTime, forMainFrameOnly: true)
  }

  private func updateTitleBarBackground() {
    guard let window = self.view.window else { return }

    guard let webView = self.webView else {
      window.backgroundColor = NSColor.white
      return
    }

    let snapshotConfiguration = WKSnapshotConfiguration()
    snapshotConfiguration.rect = CGRect(x: 0, y: topMarginToCut, width: webView.bounds.size.width, height: 1)

    webView.takeSnapshot(with: snapshotConfiguration) { image, error in
      if let image = image {
        window.backgroundColor = NSColor(patternImage: image)
      }
    }
  }

  private var webView: WKWebView!
  private let topMarginToCut: CGFloat = 6
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

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if webView == self.webView {
      updateTitleBarBackground()
    }
  }

}

extension ViewController: WKUIDelegate {
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView?
  {
    if windowFeatures.width != nil && windowFeatures.height != nil {
      let popupViewController = PopupViewController()

      let wv = popupViewController.showPopupWindow(
        createWebViewWith: configuration,
        for: navigationAction,
        windowFeatures: windowFeatures,
        parentFrame: view.window!.frame)

      return wv
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

  func webView(
    _ webView: WKWebView,
    runJavaScriptAlertPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping () -> Void)
  {
    guard let window = view.window else { return }

    let alert = NSAlert()

    alert.messageText = message
    alert.addButton(withTitle: "OK")

    alert.beginSheetModal(for: window) { _ in
      completionHandler()
    }
  }

  func webView(
    _ webView: WKWebView,
    runJavaScriptConfirmPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping (Bool) -> Void)
  {
    guard let window = view.window else {
      completionHandler(false)
      return
    }

    let alert = NSAlert()

    alert.messageText = message
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")

    alert.beginSheetModal(for: window) { response in
      completionHandler(response == .alertFirstButtonReturn)
    }
  }

  func webView(
    _ webView: WKWebView,
    runJavaScriptTextInputPanelWithPrompt prompt: String,
    defaultText: String?,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping (String?) -> Void)
  {
    // TODO: implement
  }
}

extension ViewController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    switch message.name {
    case "notify":
      handleNotification(message)
      break
    default:
      break
    }
  }

  private func handleNotification(_ message: WKScriptMessage) {
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

extension ViewController: NSWindowDelegate {
  func windowDidResize(_ notification: Notification) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.updateTitleBarBackground()
    }
  }

  func windowWillClose(_ notification: Notification) {
    webView.removeObserver(self, forKeyPath: "title")
  }

}
