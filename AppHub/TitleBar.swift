// Created by Haitao Li on 2/26/20.
// Copyright © 2020 Airbnb Inc. All rights reserved.

import AppKit
import Foundation

class TitleBar: NSView {
  override public func mouseDown(with event: NSEvent) {
    guard let window = window else { return }

    if event.clickCount > 1 {
      window.zoom(nil)
    } else {
      window.performDrag(with: event)
    }
  }
}
