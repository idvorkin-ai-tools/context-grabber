//
//  Story 1091 (bead context-grabber-ckv5, #1078): the tool the board decides on is the one the tool picker shows
//  selected, taken when a touch goes down. PaperKit's own `drawingTool` logged a black pen for 7,313 iPad touches,
//  erasing ones and blue ones included, so nothing the app chooses reads it; the log still names it beside this.
//

import PencilKit

/// The picker's selected tool, as the board's choices need it: a pen with its ink, the eraser, the lasso, or anything
/// else the picker can hold (the ruler, a custom item), which none of them acts on.
enum PickedTool {
  case ink(PKInkingTool)
  case eraser(PKEraserTool)
  case lasso(PKLassoTool)
  case other(String)

  init(_ item: PKToolPickerItem) {
    switch item {
    case let inking as PKToolPickerInkingItem: self = .ink(inking.inkingTool)
    case let eraser as PKToolPickerEraserItem: self = .eraser(eraser.eraserTool)
    case let lasso as PKToolPickerLassoItem: self = .lasso(lasso.lassoTool)
    default: self = .other(item.identifier)
    }
  }

  /// The board's own tool read the same way: what the choices went on before story 1091, for going back to it.
  init(_ tool: any PKTool) {
    switch tool {
    case let ink as PKInkingTool: self = .ink(ink)
    case let eraser as PKEraserTool: self = .eraser(eraser)
    case let lasso as PKLassoTool: self = .lasso(lasso)
    default: self = .other(String(describing: type(of: tool)))
    }
  }

  /// The pen, when it is one: its colour and width are a shape preview's, and its width Larry's labels'.
  var ink: PKInkingTool? {
    if case .ink(let tool) = self { return tool }
    return nil
  }

  var erases: Bool {
    if case .eraser = self { return true }
    return false
  }

  /// The tool to hand the board back, when it is one PaperKit draws with.
  var tool: (any PKTool)? {
    switch self {
    case .ink(let tool): return tool
    case .eraser(let tool): return tool
    case .lasso(let tool): return tool
    case .other: return nil
    }
  }
}
