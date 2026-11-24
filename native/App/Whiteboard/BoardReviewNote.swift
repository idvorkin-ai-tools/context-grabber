//  What the board shows of a session's review (spec 2026-11-23-board-interaction-review-design.md, *What Igor sees*;
//  stories 1242–1246): a quiet line in the board's corner, only when there is something to look at or he asked; a tap
//  lists the findings, newest first, each copyable, each with *Show me*; an unclear one asks whether he meant it.

import ContextCore
import SwiftUI
import UIKit

/// The corner's line: *Reviewed · 1 to look at*, never a sheet or an alert.
struct BoardReviewChip: View {
  let note: String
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      Label(note, systemImage: "checklist")
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("whiteboard-review-note")
    .accessibilityLabel(note)
  }
}

/// The findings, newest first; a clean review lists what it checked and what it couldn't.
struct BoardReviewList: View {
  @ObservedObject var model: WhiteboardModel
  @Environment(\.dismiss) private var dismiss
  @State private var showing: ShownFinding?
  @State private var copied: String?

  var body: some View {
    NavigationStack {
      List {
        if let report = model.review.report {
          if report.findings.isEmpty {
            Section("Clean") {
              Text("Nothing to look at in \(report.steps) steps.")
            }
          }
          ForEach(model.review.findings, id: \.key) { finding in
            Section {
              row(finding, report)
            }
          }
          Section("Checked") {
            ForEach(report.checks, id: \.check) { check in
              Text("\(check.check). \(check.name.replacingOccurrences(of: "_", with: " ")): \(sight(check))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .navigationTitle("Session review")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }.accessibilityIdentifier("whiteboard-review-done")
        }
      }
      .sheet(item: $showing) { shown in
        if let record = model.review.record {
          BoardReviewStepView(finding: shown.finding, record: record)
        }
      }
    }
  }

  private func sight(_ check: BoardReview.CheckResult) -> String {
    switch check.sight {
    case .notChecked: return "not checked"
    case .approximate: return "approximate"
    case .checked:
      let n = check.bug + check.unclear + check.asDesigned
      return n == 0 ? "clean" : "\(check.bug) bug, \(check.unclear) unclear, \(check.asDesigned) as designed"
    }
  }

  private func verdict(_ v: BoardReview.Verdict) -> String {
    switch v {
    case .bug: return "Bug"
    case .unclear: return "Unclear"
    case .asDesigned: return "As designed"
    }
  }

  @ViewBuilder
  private func row(_ finding: BoardReview.Finding, _ report: BoardReview.Report) -> some View {
    let key = BoardReviewShown.key(finding)
    VStack(alignment: .leading, spacing: 6) {
      Text("\(verdict(finding.verdict)) · \(finding.name.replacingOccurrences(of: "_", with: " "))")
        .font(.headline)
      Text(finding.summary)
      Text(Date(timeIntervalSince1970: finding.t / 1000), style: .time)
        .font(.footnote)
        .foregroundStyle(.secondary)
      if let answer = model.review.answers[key] {
        Text(answer == .meant ? "You meant that" : "Not what you meant")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("whiteboard-review-finding")
    HStack {
      Button(copied == key ? "Copied" : "Copy") {
        UIPasteboard.general.string = BoardReviewText.copy(finding, of: report)
        copied = key
      }
      .accessibilityIdentifier("whiteboard-review-copy")
      Spacer()
      Button("Show me") { showing = ShownFinding(finding: finding) }
        .accessibilityIdentifier("whiteboard-review-show")
    }
    .buttonStyle(.borderless)
    if finding.verdict == .unclear, model.review.answers[key] == nil {
      HStack {
        Button("I meant that") { model.answerReview(finding, meant: true) }
        Spacer()
        Button("Not what I meant") { model.answerReview(finding, meant: false) }
      }
      .buttonStyle(.borderless)
    }
  }
}

extension BoardReview.Finding {
  var key: String { BoardReviewShown.key(self) }
}

/// A finding *Show me* is open on.
struct ShownFinding: Identifiable {
  let finding: BoardReview.Finding
  var id: String { finding.key }
}

/// Story 1245: the step as the review saw it, the board just before and once it settled, each stroke as its outline;
/// the ink the finding names is marked, and ink erased in the step shows in the before as it was.
struct BoardReviewStepView: View {
  let finding: BoardReview.Finding
  let record: BoardSessionRecord
  @State private var after = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let boards = BoardReview.around(record, step: finding.step)
    let shown = after ? boards.after : boards.before
    let named = Set(finding.ids)
    NavigationStack {
      VStack(spacing: 12) {
        Picker("When", selection: $after) {
          Text("Before").tag(false)
          Text("After").tag(true)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("whiteboard-review-before-after")
        Text(finding.summary).font(.footnote)
        Canvas { context, size in
          let all = (boards.before + boards.after).filter { !$0.hidden }.map(\.box)
          guard let bounds = Self.bounds(all) else { return }
          let scale = min(size.width / bounds.width, size.height / bounds.height)
          for unit in shown where !unit.hidden {
            let b = unit.box
            let rect = CGRect(
              x: (b.x - bounds.minX) * scale, y: (b.y - bounds.minY) * scale, width: max(1, b.w * scale),
              height: max(1, b.h * scale))
            let colour: Color = named.contains(unit.id) ? .orange : (unit.owner == "igor" ? .primary : .purple)
            context.stroke(Path(rect), with: .color(colour), lineWidth: named.contains(unit.id) ? 2 : 1)
          }
        }
        .accessibilityIdentifier("whiteboard-review-step")
        .accessibilityLabel(after ? "the board after the step" : "the board before the step")
      }
      .padding()
      .navigationTitle("Step \(finding.step): \(finding.kind)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
    }
  }

  static func bounds(_ boxes: [BoardSessionRecord.Box]) -> CGRect? {
    guard let first = boxes.first else { return nil }
    var r = CGRect(x: first.x, y: first.y, width: first.w, height: first.h)
    for b in boxes.dropFirst() { r = r.union(CGRect(x: b.x, y: b.y, width: b.w, height: b.h)) }
    return r.insetBy(dx: -20, dy: -20)
  }
}
