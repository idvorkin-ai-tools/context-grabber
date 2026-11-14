//  Stories 821, 822 (#907): a chat picture opened full size. It is fetched once, for showing and for sharing; it
//  pinches, double taps and pans by `ChatImageZoom`'s rules, and a swipe down closes it only when fitted
//  (`ChatImageClose`).

import BugKit
import ContextCore
import SwiftUI
import UIKit

struct ChatImageFull: View {
  let url: URL
  let message: String
  let logger: BugLogger
  /// A swipe down on a fitted picture.
  let swipeClosed: () -> Void

  @State private var picture: UIImage?
  @State private var problem: BugProblem?
  @State private var sharing = false
  /// Times the fitted size; each opening is a new view, so it starts fitted.
  @State private var scale: CGFloat = 1
  /// Points from the screen's centre.
  @State private var offset: CGSize = .zero
  /// Where the pinch under way began.
  @State private var pinchStart: (scale: CGFloat, offset: CGSize)?
  /// The drag under way: its translation at its last change, and whether a pinch joined it.
  @State private var dragLast: CGSize?
  @State private var pinched = false

  var body: some View {
    ZStack(alignment: .topLeading) {
      GeometryReader { geo in
        if let picture {
          zoomable(picture, in: geo.size)
        } else if let problem {
          BugProblemView(problem: problem, logger: logger)
            .padding(8).background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding().frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle()).gesture(drag(picture: .zero, in: geo.size))
        } else {
          ProgressView().tint(.white).frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle()).gesture(drag(picture: .zero, in: geo.size))
        }
      }
      // Drawn like Done (#592), so it shows over a white picture.
      Button(action: share) {
        Text("Share").font(.headline).padding(.horizontal, 16).padding(.vertical, 8)
          .background(.black.opacity(0.65), in: Capsule())
      }
      .foregroundStyle(.white).disabled(picture == nil).padding().accessibilityIdentifier("chat-image-share")
    }
    .task { await fetch() }
    .sheet(isPresented: $sharing) {
      if let picture { ShareSheet(items: [picture]) }
    }
  }

  private func zoomable(_ picture: UIImage, in screen: CGSize) -> some View {
    let fitted = ChatImageZoom.fitted(picture.size, in: screen)
    let fromCentre = { (point: CGPoint) in CGPoint(x: point.x - screen.width / 2, y: point.y - screen.height / 2) }
    return Image(uiImage: picture).resizable().scaledToFit()
      .frame(width: fitted.width, height: fitted.height)
      .scaleEffect(scale)
      .offset(offset)
      .frame(width: screen.width, height: screen.height)
      .contentShape(Rectangle())
      .onTapGesture(count: 2) { location in
        let new = ChatImageZoom.doubleTapped(scale)
        let moved = ChatImageZoom.anchored(offset, around: fromCentre(location), from: scale, to: new)
        withAnimation(.easeOut(duration: 0.25)) {
          offset = ChatImageZoom.clamped(moved, scale: new, picture: fitted, in: screen)
          scale = new
        }
        logZoom(new, how: "double_tap")
      }
      .gesture(drag(picture: fitted, in: screen))
      .simultaneousGesture(
        MagnifyGesture()
          .onChanged { pinch in
            let start = pinchStart ?? (scale, offset)
            pinchStart = start
            pinched = true
            let new = ChatImageZoom.pinching(start.scale * pinch.magnification)
            offset = ChatImageZoom.anchored(
              start.offset, around: fromCentre(pinch.startLocation), from: start.scale, to: new)
            scale = new
          }
          .onEnded { _ in
            pinchStart = nil
            pinched = dragLast != nil
            let settled = ChatImageZoom.settled(scale)
            withAnimation(.easeOut(duration: 0.25)) {
              offset = ChatImageZoom.clamped(offset, scale: settled, picture: fitted, in: screen)
              scale = settled
            }
            logZoom(settled, how: "pinch")
          }
      )
  }

  /// Zoomed, a drag pans; fitted (or with no picture yet), a swipe down closes.
  private func drag(picture fitted: CGSize, in screen: CGSize) -> some Gesture {
    DragGesture(minimumDistance: scale > 1 ? 10 : ChatImageClose.minimumDrag)
      .onChanged { drag in
        let travel = ChatImageZoom.travel(from: dragLast, to: drag.translation)
        dragLast = drag.translation
        guard pinchStart == nil else { return }
        offset = ChatImageZoom.panned(offset, by: travel, scale: scale, picture: fitted, in: screen)
      }
      .onEnded { drag in
        let closes = ChatImageClose.closes(dragHeight: drag.translation.height, scale: scale, pinched: pinched)
        dragLast = nil
        pinched = false
        if closes { swipeClosed() }
      }
  }

  private func logZoom(_ scale: CGFloat, how: String) {
    logger(
      "ui",
      [
        "action": "zoom_chat_image", "message": .string(message), "scale": .double(ChatImageZoom.logged(scale)),
        "how": .string(how),
      ])
  }

  /// The picture itself goes to the share sheet, not its address: the Cockpit's is tailnet-only.
  private func share() {
    logger("ui", ["action": "share_chat_image", "message": .string(message)])
    sharing = true
  }

  private func fetch() async {
    guard picture == nil else { return }
    problem = nil
    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      let status = (response as? HTTPURLResponse)?.statusCode ?? 200
      guard (200..<300).contains(status), let image = UIImage(data: data) else {
        problem = failed("the Cockpit answered \(status) with \(data.count) bytes that aren't a picture")
        return
      }
      picture = image
    } catch {
      problem = failed(error.localizedDescription)
    }
  }

  private func failed(_ reason: String) -> BugProblem {
    .grabber(
      "The picture could not be fetched: \(reason)", context: "ChatThreadView.image",
      extra: ["url": .string(url.absoluteString), "message": .string(message)])
  }
}
