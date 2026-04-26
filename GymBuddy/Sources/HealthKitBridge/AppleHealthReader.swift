import Foundation

#if canImport(HealthKit) && !os(macOS)
import HealthKit

/// Apple HealthKit–backed reader. Read-only (ADR-compliant).
public final class AppleHealthReader: HealthReader, @unchecked Sendable {
    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(hr)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()

    public init() {}

    public func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        return try await withCheckedThrowingContinuation { cont in
            store.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: success) }
            }
        }
    }

    public func latestHRV() async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        return try await latestQuantity(for: type, unit: HKUnit.secondUnit(with: .milli))
    }

    public func latestHeartRate() async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
        return try await latestQuantity(for: type, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    public func sleepLastNight() async throws -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let end = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -18, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let categories = (samples ?? []).compactMap { $0 as? HKCategorySample }
                let asleepValue = HKCategoryValueSleepAnalysis.asleep.rawValue
                let asleep = categories.filter { $0.value == asleepValue }
                let totalSeconds = asleep.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }
            self.store.execute(query)
        }
    }

    private func latestQuantity(for type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                cont.resume(returning: value)
            }
            self.store.execute(q)
        }
    }
}

#endif
