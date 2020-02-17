// Created by Haitao Li on 2/16/20.

import Cocoa
import UserNotifications
import WebKit

class PopupViewController: NSViewController {
  override func loadView() {
    self.view = NSView()
  }

  override var representedObject: Any? {
    didSet {
      // Update the view, if already loaded.
    }
  }

  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    switch keyPath {
    case "title":
      // view.window?.title = webView.title
      break
    default:
      break
    }
  }

  func showPopupWindow(
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures,
    parentFrame: CGRect) -> WKWebView?
  {
    guard
      let width = windowFeatures.width?.intValue,
      let height = windowFeatures.height?.intValue
    else { return nil }

    let parentSize = parentFrame.size
    // Ignore windowFeatures.x/y and always center popup on the main window
    let x = (Int(parentSize.width.native) - width) / 2
    let y = (Int(parentSize.height.native) - height) / 2

    let contentRect = NSRect(
      x: x + Int(parentFrame.origin.x.native),
      y: y + Int(parentFrame.origin.y.native),
      width: width,
      height: height)

    let window = NSWindow(
      contentRect: contentRect,
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false)

    window.delegate = self
    window.isReleasedWhenClosed = false

    view.frame = CGRect(x: 0, y: 0, width: width, height: height)
    view.autoresizingMask = [.height, .width]

    let webView = WKWebView(frame: view.bounds, configuration: configuration)
    self.webView = webView
    webView.navigationDelegate = self
    webView.uiDelegate = self
    webView.autoresizingMask = [.height, .width]
    webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)

    if navigationAction.request.url?.scheme != nil {
      webView.load(navigationAction.request)
    }

    view.addSubview(webView)

    window.contentViewController = self
    window.makeKeyAndOrderFront(nil)

    return webView
  }

  private var webView: WKWebView?
}

extension PopupViewController: WKNavigationDelegate {
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
  {
    decisionHandler(.allow)
  }
}

extension PopupViewController: WKUIDelegate {
  func webViewDidClose(_ webView: WKWebView) {
    view.window?.close()
  }
}

extension PopupViewController: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    webView?.removeObserver(self, forKeyPath: "title")
  }
}
