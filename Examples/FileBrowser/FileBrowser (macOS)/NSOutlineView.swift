import Cocoa

extension NSOutlineView {
  func targetRows() -> IndexSet {
    let targetRows: IndexSet

    if clickedRow >= 0 {
      targetRows = selectedRowIndexes.contains(clickedRow) ? selectedRowIndexes : IndexSet([clickedRow])
    } else {
      targetRows = IndexSet()
    }

    return targetRows
  }
}

/// NSOutlineView subclass that maps the unmodified spacebar to the standard
/// `quickLookPreviewItems(_:)` responder action. AppKit does NOT auto-route
/// spacebar through `quickLook(with:)` (only F4 does that), so we dispatch the
/// action ourselves — the same pattern used by Apple's QuickLookDownloader
/// sample, which intercepts spacebar in its NSTableView subclass and calls a
/// toggle-the-preview-panel selector via the responder chain.
class FilesOutlineView: NSOutlineView {
  override func keyDown(with event: NSEvent) {
    let isPlainSpace = event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask)
      && event.charactersIgnoringModifiers == " "
    if isPlainSpace {
      NSApp.sendAction(
        #selector(NSResponder.quickLookPreviewItems(_:)),
        to: nil,
        from: self
      )
      return
    }
    super.keyDown(with: event)
  }
}
