import Cocoa

extension NSOutlineView {
  func targetRows() -> IndexSet {
    let targetRows: IndexSet

    let clickedRow = clickedRow
    let selectedRowIndexes = selectedRowIndexes
    if clickedRow >= 0 {
      targetRows = selectedRowIndexes.contains(clickedRow) ? selectedRowIndexes : IndexSet([clickedRow])
    } else {
      targetRows = IndexSet()
    }

    return targetRows
  }
}
