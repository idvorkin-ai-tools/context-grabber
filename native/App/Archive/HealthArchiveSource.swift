//  Story 270: one Health sample type as an archive stream, read with an anchored query. The anchor is the stream's
//  cursor: Health answers everything since it, deletions included, and a nil anchor is the whole history, paged.
//  A record carries what the mirror reads of a sample (when, how much in the app's unit, which source), never
//  Health's free-form metadata.

import ContextCore
import HealthKit

struct HealthArchiveSource: ArchiveSource {
  let store: HKHealthStore
  let type: HKSampleType
  var stream: String { ArchiveStream.health(type.identifier) }

  /// A stored anchor this build cannot read.
  struct UnreadableAnchor: Error {}

  func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
    // An anchor this build cannot read (an OS upgrade, a restored database) starts the stream over from nothing:
    // the archive dedupes a re-read of the history, and a stream stuck on it would never archive again.
    let anchor = cursor.flatMap { try? Self.anchor(from: $0) }
    let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.sample(type: type)], anchor: anchor, limit: limit)
    let result = try await descriptor.result(for: store)
    var records = result.addedSamples.map(Self.record)
    records += result.deletedObjects.map { ["guid": ArchiveGUID.deleted($0.uuid), "deleted": true] }
    let count = result.addedSamples.count + result.deletedObjects.count
    let newAnchor: HKQueryAnchor? = result.newAnchor
    return ArchivePage(
      records: records, cursor: try newAnchor.map(Self.string), more: count >= limit,
      restarted: cursor != nil && anchor == nil)
  }

  static func string(_ anchor: HKQueryAnchor) throws -> String {
    try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true).base64EncodedString()
  }

  static func anchor(from cursor: String) throws -> HKQueryAnchor {
    guard let data = Data(base64Encoded: cursor),
      let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    else { throw UnreadableAnchor() }
    return anchor
  }

  /// The sample as the archive keeps it: its uuid as the guid, instants as UTC milliseconds, a quantity in the
  /// app's unit for its kind (HealthKitSource.fallbackUnit) with the unit named, a category's value, a workout's
  /// totals as the mirror reads them.
  static func record(_ sample: HKSample) -> [String: Any] {
    var record: [String: Any] = [
      "guid": ArchiveGUID.sample(sample.uuid), "type": sample.sampleType.identifier,
      "start": jsMillis(sample.startDate), "end": jsMillis(sample.endDate),
      "source": sample.sourceRevision.source.name, "source_bundle": sample.sourceRevision.source.bundleIdentifier,
    ]
    if let device = sample.device?.name { record["device"] = device }
    switch sample {
    case let quantity as HKQuantitySample:
      if let kind = QuantityKind.allCases.first(where: { HealthKitSource.type($0) == quantity.quantityType }) {
        let unit = HealthKitSource.fallbackUnit(kind)
        record["value"] = quantity.quantity.doubleValue(for: unit)
        record["unit"] = unit.unitString
      }
    case let category as HKCategorySample:
      record["value"] = category.value
    case let workout as HKWorkout:
      record["activity_type"] = Int(workout.workoutActivityType.rawValue)
      record["duration_s"] = workout.duration
      if let kcal = HealthKitSource.total(workout, .activeEnergyBurned, .kilocalorie()) { record["energy_kcal"] = kcal }
      if let m = HealthKitSource.total(workout, .distanceWalkingRunning, .meter()) { record["distance_m"] = m }
    default:
      break
    }
    return record
  }
}
