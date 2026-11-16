import Foundation

/// The rules of the export gate, with no storage and no UI so they can be unit tested.
///
/// One grant belongs to one document and covers one export. A grant expires 24 hours after it was created.
/// A second grant for the same document while one is still valid does not stack and does not extend the first.
struct ExportGateLogic: Equatable, Codable {
    struct Grant: Equatable, Codable {
        let documentID: UUID
        let grantedAt: Date
    }

    /// How long a grant stays usable.
    static let lifetime: TimeInterval = 24 * 60 * 60
    /// A grant dated this far in the future (device clock moved back) is treated as invalid.
    static let clockSkewTolerance: TimeInterval = 5 * 60
    /// Safety cap so the stored list can never grow without bound.
    static let maxStoredGrants = 200

    private(set) var grants: [Grant]

    init(grants: [Grant] = []) {
        self.grants = grants
    }

    static func isValid(_ grant: Grant, now: Date) -> Bool {
        let age = now.timeIntervalSince(grant.grantedAt)
        return age >= -clockSkewTolerance && age < lifetime
    }

    func hasGrant(for documentID: UUID, now: Date) -> Bool {
        grants.contains { $0.documentID == documentID && Self.isValid($0, now: now) }
    }

    /// When the current grant for this document stops being valid, or nil if there is none.
    func expiryDate(for documentID: UUID, now: Date) -> Date? {
        guard let grant = grants.first(where: { $0.documentID == documentID && Self.isValid($0, now: now) }) else {
            return nil
        }
        return grant.grantedAt.addingTimeInterval(Self.lifetime)
    }

    /// Records a verified reward. A no-op when this document already has a valid grant.
    mutating func grant(for documentID: UUID, now: Date) {
        purgeExpired(now: now)
        guard !hasGrant(for: documentID, now: now) else { return }
        grants.removeAll { $0.documentID == documentID }
        grants.append(Grant(documentID: documentID, grantedAt: now))
        if grants.count > Self.maxStoredGrants {
            grants.removeFirst(grants.count - Self.maxStoredGrants)
        }
    }

    /// Uses up the grant after an export really completed. Returns true if a valid grant was consumed.
    @discardableResult
    mutating func consume(for documentID: UUID, now: Date) -> Bool {
        let hadValidGrant = hasGrant(for: documentID, now: now)
        grants.removeAll { $0.documentID == documentID }
        purgeExpired(now: now)
        return hadValidGrant
    }

    /// Removes any grant for a document, for example when the document is deleted.
    mutating func forget(documentID: UUID) {
        grants.removeAll { $0.documentID == documentID }
    }

    mutating func purgeExpired(now: Date) {
        grants.removeAll { !Self.isValid($0, now: now) }
    }

    // MARK: Persistence helpers

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Never throws: missing or corrupt data simply means "no grants".
    static func decoded(from data: Data?) -> ExportGateLogic {
        guard let data = data, let value = try? JSONDecoder().decode(ExportGateLogic.self, from: data) else {
            return ExportGateLogic()
        }
        return value
    }
}

/// Persisted export grants, keyed by document id. Injected at the app root as an environment object.
@MainActor
final class ExportGate: ObservableObject {
    @Published private(set) var logic: ExportGateLogic

    private let defaults: UserDefaults
    private let storageKey: String
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "ck.exportGate.grants.v1",
        now: @escaping () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.now = now
        var loaded = ExportGateLogic.decoded(from: defaults.data(forKey: storageKey))
        loaded.purgeExpired(now: now())
        self.logic = loaded
    }

    func hasGrant(for documentID: UUID) -> Bool {
        logic.hasGrant(for: documentID, now: now())
    }

    /// Called only by ExportFlowSheet after `RewardedAdController.present()` returned true.
    func grant(for documentID: UUID) {
        logic.grant(for: documentID, now: now())
        persist()
    }

    /// Called only after a share, save or print really completed.
    func consume(for documentID: UUID) {
        logic.consume(for: documentID, now: now())
        persist()
    }

    /// Extra to the contract: lets the app drop a grant when a document is deleted.
    func forget(documentID: UUID) {
        logic.forget(documentID: documentID)
        persist()
    }

    private func persist() {
        if let data = try? logic.encoded() {
            defaults.set(data, forKey: storageKey)
        }
    }
}
