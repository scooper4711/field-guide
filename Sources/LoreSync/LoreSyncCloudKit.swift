import CloudKit
import Foundation
import SourcebookLore

/// The CloudKit side of syncing: starting the engine and handing its events to the actor's handlers. Unit tests can't
/// reach this (a container without the entitlement stops the process, and engine events have no public initializers);
/// the end-to-end check in docs/specs/lore-sync covers it.
extension LoreSync {
    /// Starts syncing `store`, whose files are in `folder`, through the container; nil when iCloud isn't available.
    /// The container must be in the app's entitlements, or CloudKit stops the app.
    public static func start(containerIdentifier: String, store: LoreStore, folder: URL,
                             onChange: @escaping @Sendable ([String]) async -> Void) async -> LoreSync? {
        let container = CKContainer(identifier: containerIdentifier)
        guard (try? await container.accountStatus()) == .available else { return nil }
        let sync = LoreSync(store: store, folder: folder, onChange: onChange)
        await sync.attach(to: container.privateCloudDatabase)
        return sync
    }

    private func attach(to database: CKDatabase) async {
        let isFirstSync = state.engine == nil
        let configuration = CKSyncEngine.Configuration(database: database, stateSerialization: state.engine,
                                                       delegate: self)
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        await use(EngineQueue(engine: engine), uploadingEverything: isFirstSync)
    }

    func updateEngineState(_ serialization: CKSyncEngine.State.Serialization) {
        state.engine = serialization
        saveState()
    }
}

extension LoreSync: CKSyncEngineDelegate {
    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            updateEngineState(update.stateSerialization)
        case .accountChange(let change):
            await accountChanged(change.changeType)
        case .fetchedDatabaseChanges(let changes):
            await zonesDeleted(changes.deletions.map(\.zoneID))
        case .fetchedRecordZoneChanges(let changes):
            await receive(changes.modifications.map(\.record))
        case .sentRecordZoneChanges(let sent):
            saved(sent.savedRecords)
            await settle(sent.failedRecordSaves.map { (record: $0.record, error: $0.error) })
        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                          syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            await self.record(for: recordID)
        }
    }
}

/// Queues changes in a sync engine's state.
struct EngineQueue: LoreChangeQueue {
    let engine: CKSyncEngine

    func saveZone() {
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: LoreRecordCoder.zoneID))])
    }

    func saveRecords(_ recordIDs: [CKRecord.ID]) {
        engine.state.add(pendingRecordZoneChanges: recordIDs.map { .saveRecord($0) })
    }
}
