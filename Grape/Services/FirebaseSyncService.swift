import Foundation

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore

actor FirebaseSyncService {
    static let shared = FirebaseSyncService()

    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard

    private var pendingFamilyUpload: (familyID: String, state: FamilyCloudState)?
    private var isUploading = false
    private var familyListeners: [String: ListenerRegistration] = [:]
    private var presenceListeners: [String: ListenerRegistration] = [:]
    private var lastUploadedFamilyFingerprints: [String: Int] = [:]
    private var lastUploadedSubcollectionFingerprints: [String: [String: [String: Int]]] = [:]
    private var lastSavedProfileFamilyIDs: [String: String] = [:]
    private let maxFirestoreJSONDocumentBytes = 900 * 1024

    private init() {}

    func bootstrapFamily(localState: FamilyCloudState, familyID: String) async -> FamilyCloudState? {
        do {
            guard currentSignedInUID() != nil else { return nil }

            let docRef = familyStateDocRef(familyID: familyID)
            let localMutationAt = lastLocalMutationAt(familyID: familyID)
            let remote = try await docRef.getDocument()

            if let data = remote.data(),
               let remoteState = try await decodeFamilyState(from: data),
               let remoteUpdatedAt = (data["clientUpdatedAt"] as? Timestamp)?.dateValue(),
               remoteUpdatedAt > localMutationAt {
                rememberFamilyStateFingerprint(from: data, familyID: familyID)
                try await saveFamilyIndexes(for: remoteState, familyID: familyID)
                saveLocalMutationTimestamp(remoteUpdatedAt, familyID: familyID)
                print("Firebase sync: applied remote family state \(familyID).")
                return remoteState
            }

            _ = try await uploadNow(localState, familyID: familyID)
            print("Firebase sync: uploaded local family state during bootstrap \(familyID).")
            return nil
        } catch {
            print("Firebase family bootstrap failed (\(familyID)): \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func queueUploadFamily(state: FamilyCloudState, familyID: String) async -> Bool {
        pendingFamilyUpload = (familyID, state)
        guard !isUploading else { return true }

        isUploading = true
        defer { isUploading = false }

        var didSucceed = true
        while let pending = pendingFamilyUpload {
            pendingFamilyUpload = nil

            do {
                guard currentSignedInUID() != nil else { return false }
                _ = try await uploadNow(pending.state, familyID: pending.familyID)
            } catch {
                didSucceed = false
                print("Firebase family upload failed (\(pending.familyID)): \(error.localizedDescription)")
            }
        }

        return didSucceed
    }

    func loadFamilyState(familyID: String) async -> FamilyCloudState? {
        do {
            guard currentSignedInUID() != nil else { return nil }
            guard let remote = try await fetchFamilyState(familyID: familyID) else { return nil }

            if let remoteUpdatedAt = remote.clientUpdatedAt {
                saveLocalMutationTimestamp(remoteUpdatedAt, familyID: familyID)
            }
            return remote.state
        } catch {
            print("Firebase load family state failed (\(familyID)): \(error.localizedDescription)")
            return nil
        }
    }

    func loadFamilyStateForMember(firebaseUID: String, email: String?) async -> FamilyCloudState? {
        if let state = await loadFamilyStateForMember(field: "memberFirebaseUIDs", value: firebaseUID) {
            return state
        }

        let normalizedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !normalizedEmail.isEmpty else { return nil }
        return await loadFamilyStateForMember(field: "memberEmails", value: normalizedEmail)
    }

    func loadFamilyState(inviteCode: String) async -> FamilyCloudState? {
        let normalizedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else { return nil }

        do {
            guard currentSignedInUID() != nil else { return nil }

            let query = try await db.collection("family_state")
                .whereField("inviteCode", isEqualTo: normalizedCode)
                .limit(to: 1)
                .getDocuments()

            guard let doc = query.documents.first,
                  let remoteState = try await decodeFamilyState(from: doc.data()) else {
                return nil
            }

            rememberFamilyStateFingerprint(from: doc.data(), familyID: doc.documentID)
            if let remoteUpdatedAt = (doc.data()["clientUpdatedAt"] as? Timestamp)?.dateValue() {
                saveLocalMutationTimestamp(remoteUpdatedAt, familyID: doc.documentID)
            }
            return remoteState
        } catch {
            print("Firebase load family by invite failed (\(normalizedCode)): \(error.localizedDescription)")
            return nil
        }
    }

    private func currentSignedInUID() -> String? {
        Auth.auth().currentUser?.uid
    }

    private func uploadNow(_ state: FamilyCloudState, familyID: String) async throws -> Date {
        let mainDocumentState = state.withoutSubcollectionData()
        let data = try await MainActor.run {
            try JSONEncoder.grapeFirebaseSync.encode(mainDocumentState)
        }
        try validateFamilyStateSize(data, familyID: familyID)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "FirebaseSyncService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode family state JSON string."]
            )
        }

        let (memberFirebaseUIDs, memberEmails) = memberIndexes(for: state)
        let fingerprint = json.hashValue
        let didUploadSubcollections = try await uploadFamilySubcollections(state, familyID: familyID)
        guard lastUploadedFamilyFingerprints[familyID] != fingerprint || didUploadSubcollections else {
            return lastLocalMutationAt(familyID: familyID)
        }

        let clientUpdatedAt = Date()
        try await familyStateDocRef(familyID: familyID).setData([
            "schemaVersion": 1,
            "familyID": familyID,
            "inviteCode": state.family.inviteCode,
            "memberEmails": memberEmails,
            "memberFirebaseUIDs": memberFirebaseUIDs,
            "json": json,
            "payloadStorage": "subcollections",
            "clientUpdatedAt": Timestamp(date: clientUpdatedAt),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        lastUploadedFamilyFingerprints[familyID] = fingerprint

        for firebaseUID in memberFirebaseUIDs {
            do {
                try await saveCurrentFamilyIDOrThrow(familyID, for: firebaseUID)
            } catch {
                print("Firebase member profile index failed (\(firebaseUID)): \(error.localizedDescription)")
            }
        }

        saveLocalMutationTimestamp(clientUpdatedAt, familyID: familyID)
        return clientUpdatedAt
    }

    func startListeningToFamily(
        familyID: String,
        onChange: @escaping @MainActor (FamilyCloudState) -> Void
    ) async {
        guard currentSignedInUID() != nil else { return }
        guard familyListeners[familyID] == nil else { return }

        familyListeners[familyID] = familyStateDocRef(familyID: familyID).addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("Firebase family listener failed (\(familyID)): \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data() else { return }

            Task {
                do {
                    guard let self,
                          let remoteState = try await self.decodeFamilyState(from: data),
                          await self.shouldApplyRemoteData(data, familyID: familyID) else {
                        return
                    }

                    await MainActor.run {
                        onChange(remoteState)
                    }
                } catch {
                    print("Firebase family listener decode failed (\(familyID)): \(error.localizedDescription)")
                }
            }
        }
    }

    func stopAllFamilyListeners() async {
        for listener in familyListeners.values {
            listener.remove()
        }
        familyListeners.removeAll()
    }

    func stopAllPresenceListeners() async {
        for listener in presenceListeners.values {
            listener.remove()
        }
        presenceListeners.removeAll()
    }

    func markMemberActive(familyID: String, memberID: String, displayName: String) async {
        do {
            guard let firebaseUID = currentSignedInUID() else { return }
            try await familySubcollectionRef(familyID: familyID, collectionName: "presence")
                .document(memberID)
                .setData([
                    "memberID": memberID,
                    "firebaseUID": firebaseUID,
                    "displayName": displayName,
                    "lastActiveAt": Timestamp(date: Date()),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            print("Firebase presence update failed (\(familyID)/\(memberID)): \(error.localizedDescription)")
        }
    }

    func startListeningToPresence(
        familyID: String,
        activeWithin seconds: TimeInterval,
        onChange: @escaping @MainActor (Set<UUID>) -> Void
    ) async {
        guard currentSignedInUID() != nil else { return }
        guard presenceListeners[familyID] == nil else { return }

        presenceListeners[familyID] = familySubcollectionRef(familyID: familyID, collectionName: "presence")
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("Firebase presence listener failed (\(familyID)): \(error.localizedDescription)")
                    return
                }

                let cutoff = Date().addingTimeInterval(-seconds)
                let activeIDs = Set(
                    snapshot?.documents.compactMap { document -> UUID? in
                        guard
                            let timestamp = document.data()["lastActiveAt"] as? Timestamp,
                            timestamp.dateValue() >= cutoff
                        else {
                            return nil
                        }
                        return UUID(uuidString: document.documentID)
                    } ?? []
                )

                Task { @MainActor in
                    onChange(activeIDs)
                }
            }
    }

    private func saveFamilyIndexes(for state: FamilyCloudState, familyID: String) async throws {
        let (memberFirebaseUIDs, memberEmails) = memberIndexes(for: state)
        try await familyStateDocRef(familyID: familyID).setData([
            "inviteCode": state.family.inviteCode,
            "memberEmails": memberEmails,
            "memberFirebaseUIDs": memberFirebaseUIDs,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        for firebaseUID in memberFirebaseUIDs {
            do {
                try await saveCurrentFamilyIDOrThrow(familyID, for: firebaseUID)
            } catch {
                print("Firebase member profile index failed (\(firebaseUID)): \(error.localizedDescription)")
            }
        }
    }

    private func memberIndexes(for state: FamilyCloudState) -> (firebaseUIDs: [String], emails: [String]) {
        let usersByID = Dictionary(uniqueKeysWithValues: state.users.map { ($0.id, $0) })
        let memberUsers = state.memberships.compactMap { usersByID[$0.userID] }
        let firebaseUIDs = Array(Set(memberUsers.compactMap(\.firebaseUID))).sorted()
        let emails = Array(Set(memberUsers.map {
            $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty })).sorted()
        return (firebaseUIDs, emails)
    }

    private func familyStateDocRef(familyID: String) -> DocumentReference {
        db.collection("family_state").document(familyID)
    }

    private func familySubcollectionRef(familyID: String, collectionName: String) -> CollectionReference {
        familyStateDocRef(familyID: familyID).collection(collectionName)
    }

    private func validateFamilyStateSize(_ data: Data, familyID: String) throws {
        guard data.count <= maxFirestoreJSONDocumentBytes else {
            throw NSError(
                domain: "FirebaseSyncService",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Family metadata \(familyID) is \(data.count) bytes after moving list data to subcollections, which is too large for Firestore."
                ]
            )
        }
    }

    @discardableResult
    private func uploadFamilySubcollections(_ state: FamilyCloudState, familyID: String) async throws -> Bool {
        var didUpload = false
        didUpload = try await uploadJSONDocuments(state.users, familyID: familyID, collectionName: "users") || didUpload
        didUpload = try await uploadJSONDocuments(state.memberships, familyID: familyID, collectionName: "memberships") { membership in
            ["joinedAt": Timestamp(date: membership.joinedAt)]
        } || didUpload
        didUpload = try await uploadJSONDocuments(state.joinRequests, familyID: familyID, collectionName: "join_requests") { request in
            ["requestedAt": Timestamp(date: request.requestedAt)]
        } || didUpload
        didUpload = try await uploadJSONDocuments(state.tasks, familyID: familyID, collectionName: "tasks") { task in
            ["dueDate": Timestamp(date: task.dueDate)]
        } || didUpload
        didUpload = try await uploadJSONDocuments(state.scheduleEntries, familyID: familyID, collectionName: "schedule_entries") { entry in
            ["date": Timestamp(date: entry.date)]
        } || didUpload
        didUpload = try await uploadJSONDocuments(state.groupMessages, familyID: familyID, collectionName: "group_messages") { message in
            ["sentAt": Timestamp(date: message.sentAt)]
        } || didUpload
        didUpload = try await uploadJSONDocuments(state.savedChatMessages, familyID: familyID, collectionName: "saved_chat_messages") { saved in
            [
                "messageSentAt": Timestamp(date: saved.messageSentAt),
                "savedAt": Timestamp(date: saved.savedAt)
            ]
        } || didUpload
        didUpload = try await uploadJSONDocuments(state.expenseTransactions, familyID: familyID, collectionName: "expense_transactions") { transaction in
            ["date": Timestamp(date: transaction.date)]
        } || didUpload
        didUpload = try await uploadJSONDocuments(state.savingsGoals, familyID: familyID, collectionName: "savings_goals") { goal in
            ["updatedAt": Timestamp(date: goal.updatedAt)]
        } || didUpload
        return didUpload
    }

    @discardableResult
    private func uploadJSONDocuments<T: Encodable & Identifiable>(
        _ items: [T],
        familyID: String,
        collectionName: String,
        metadata: (T) -> [String: Any] = { _ in [:] }
    ) async throws -> Bool where T.ID == UUID {
        let collectionRef = familySubcollectionRef(familyID: familyID, collectionName: collectionName)
        let remoteSnapshot = try await collectionRef.getDocuments()
        let remoteIDs = Set(remoteSnapshot.documents.map(\.documentID))
        let desiredIDs = Set(items.map { $0.id.uuidString })
        var familyFingerprints = lastUploadedSubcollectionFingerprints[familyID] ?? [:]
        var fingerprints = familyFingerprints[collectionName] ?? [:]
        var batch = db.batch()
        var pendingFingerprints: [(id: String, fingerprint: Int)] = []
        var pendingDeletedIDs: [String] = []
        var pendingOperationCount = 0
        var didUpload = false

        func commitPendingBatchIfNeeded(force: Bool = false) async throws {
            guard pendingOperationCount >= 450 || (force && pendingOperationCount > 0) else { return }
            try await batch.commit()
            for pending in pendingFingerprints {
                fingerprints[pending.id] = pending.fingerprint
            }
            for id in pendingDeletedIDs {
                fingerprints[id] = nil
            }
            pendingFingerprints.removeAll()
            pendingDeletedIDs.removeAll()
            pendingOperationCount = 0
            batch = db.batch()
            didUpload = true
        }

        for document in remoteSnapshot.documents where !desiredIDs.contains(document.documentID) {
            batch.deleteDocument(document.reference)
            pendingDeletedIDs.append(document.documentID)
            pendingOperationCount += 1
            try await commitPendingBatchIfNeeded()
        }

        for item in items {
            let data = try await MainActor.run {
                try JSONEncoder.grapeFirebaseSync.encode(item)
            }
            guard data.count <= maxFirestoreJSONDocumentBytes else {
                throw NSError(
                    domain: "FirebaseSyncService",
                    code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey: "\(collectionName) document \(item.id.uuidString) is \(data.count) bytes, which is too large for Firestore."
                    ]
                )
            }
            guard let json = String(data: data, encoding: .utf8) else {
                throw NSError(
                    domain: "FirebaseSyncService",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encode \(collectionName) JSON string."]
                )
            }

            let messageID = item.id.uuidString
            let fingerprint = json.hashValue
            guard fingerprints[messageID] != fingerprint || !remoteIDs.contains(messageID) else { continue }

            var payload = metadata(item)
            payload.merge([
                "json": json,
                "updatedAt": FieldValue.serverTimestamp()
            ]) { _, new in new }
            batch.setData(payload, forDocument: collectionRef.document(messageID), merge: true)
            pendingFingerprints.append((messageID, fingerprint))
            pendingOperationCount += 1

            try await commitPendingBatchIfNeeded()
        }

        try await commitPendingBatchIfNeeded(force: true)

        familyFingerprints[collectionName] = fingerprints
        lastUploadedSubcollectionFingerprints[familyID] = familyFingerprints
        return didUpload
    }

    private func applyFamilySubcollections(to state: FamilyCloudState, useFallback: Bool) async throws -> FamilyCloudState {
        let familyID = state.family.id.uuidString
        return FamilyCloudState(
            family: state.family,
            users: try await fetchJSONDocuments(
                familyID: familyID,
                collectionName: "users",
                fallback: useFallback ? state.users : []
            ),
            memberships: try await fetchJSONDocuments(
                familyID: familyID,
                collectionName: "memberships",
                fallback: useFallback ? state.memberships : []
            ),
            joinRequests: try await fetchJSONDocuments(
                familyID: familyID,
                collectionName: "join_requests",
                fallback: useFallback ? state.joinRequests : []
            ),
            tasks: try await fetchJSONDocuments(
                familyID: familyID,
                collectionName: "tasks",
                fallback: useFallback ? state.tasks : []
            ),
            scheduleEntries: try await fetchJSONDocuments(
                familyID: familyID,
                collectionName: "schedule_entries",
                fallback: useFallback ? state.scheduleEntries : []
            ),
            groupMessages: try await fetchJSONDocuments(
                familyID: familyID,
                collectionName: "group_messages",
                fallback: useFallback ? state.groupMessages : []
            ),
            savedChatMessages: try await fetchJSONDocuments(
                familyID: familyID,
                collectionName: "saved_chat_messages",
                fallback: useFallback ? state.savedChatMessages : []
            ),
            expenseTransactions: try await fetchJSONDocuments(
                familyID: familyID,
                collectionName: "expense_transactions",
                fallback: useFallback ? state.expenseTransactions : []
            ),
            savingsGoals: try await fetchJSONDocuments(
                familyID: familyID,
                collectionName: "savings_goals",
                fallback: useFallback ? state.savingsGoals : []
            )
        )
    }

    private func fetchJSONDocuments<T: Decodable & Identifiable>(
        familyID: String,
        collectionName: String,
        fallback: [T]
    ) async throws -> [T] where T.ID == UUID {
        let snapshot = try await familySubcollectionRef(familyID: familyID, collectionName: collectionName)
            .getDocuments()

        guard !snapshot.documents.isEmpty else {
            return fallback
        }

        var itemsByID = Dictionary(uniqueKeysWithValues: fallback.map { ($0.id, $0) })
        var familyFingerprints = lastUploadedSubcollectionFingerprints[familyID] ?? [:]
        var fingerprints = familyFingerprints[collectionName] ?? [:]

        for document in snapshot.documents {
            guard let json = document.data()["json"] as? String,
                  let jsonData = json.data(using: .utf8) else {
                continue
            }

            let item = try await MainActor.run {
                try JSONDecoder.grapeFirebaseSync.decode(T.self, from: jsonData)
            }
            itemsByID[item.id] = item
            fingerprints[item.id.uuidString] = json.hashValue
        }

        familyFingerprints[collectionName] = fingerprints
        lastUploadedSubcollectionFingerprints[familyID] = familyFingerprints
        return Array(itemsByID.values)
    }

    private func fetchFamilyState(familyID: String) async throws -> (state: FamilyCloudState, clientUpdatedAt: Date?)? {
        let doc = try await familyStateDocRef(familyID: familyID).getDocument()
        guard let data = doc.data(),
              let remoteState = try await decodeFamilyState(from: data) else {
            return nil
        }

        rememberFamilyStateFingerprint(from: data, familyID: familyID)
        let remoteUpdatedAt = (data["clientUpdatedAt"] as? Timestamp)?.dateValue()
        return (remoteState, remoteUpdatedAt)
    }

    private func loadFamilyStateForMember(field: String, value: String) async -> FamilyCloudState? {
        do {
            guard currentSignedInUID() != nil else { return nil }

            let query = try await db.collection("family_state")
                .whereField(field, arrayContains: value)
                .limit(to: 1)
                .getDocuments()

            guard let doc = query.documents.first,
                  let remoteState = try await decodeFamilyState(from: doc.data()) else {
                return nil
            }

            rememberFamilyStateFingerprint(from: doc.data(), familyID: doc.documentID)
            if let remoteUpdatedAt = (doc.data()["clientUpdatedAt"] as? Timestamp)?.dateValue() {
                saveLocalMutationTimestamp(remoteUpdatedAt, familyID: doc.documentID)
            }
            return remoteState
        } catch {
            print("Firebase load family by \(field) failed (\(value)): \(error.localizedDescription)")
            return nil
        }
    }

    private func shouldApplyRemoteData(_ data: [String: Any], familyID: String) -> Bool {
        guard let remoteUpdatedAt = (data["clientUpdatedAt"] as? Timestamp)?.dateValue() else {
            rememberFamilyStateFingerprint(from: data, familyID: familyID)
            return true
        }

        guard remoteUpdatedAt > lastLocalMutationAt(familyID: familyID) else {
            return false
        }

        rememberFamilyStateFingerprint(from: data, familyID: familyID)
        saveLocalMutationTimestamp(remoteUpdatedAt, familyID: familyID)
        return true
    }

    private func rememberFamilyStateFingerprint(from data: [String: Any], familyID: String) {
        guard let json = data["json"] as? String else { return }
        lastUploadedFamilyFingerprints[familyID] = json.hashValue
    }

    private func decodeFamilyState(from data: [String: Any]) async throws -> FamilyCloudState? {
        guard let json = data["json"] as? String,
              let jsonData = json.data(using: .utf8) else { return nil }

        let state = try await MainActor.run {
            try JSONDecoder.grapeFirebaseSync.decode(FamilyCloudState.self, from: jsonData)
        }
        let usesSubcollections = (data["payloadStorage"] as? String) == "subcollections"
            || (data["messageStorage"] as? String) == "subcollection"
        return try await applyFamilySubcollections(
            to: state,
            useFallback: !usesSubcollections
        )
    }

    private func saveLocalMutationTimestamp(_ date: Date, familyID: String) {
        userDefaults.set(
            date.timeIntervalSince1970,
            forKey: "grape.firebase.family.\(familyID).lastLocalMutationAt"
        )
    }

    private func lastLocalMutationAt(familyID: String) -> Date {
        let key = "grape.firebase.family.\(familyID).lastLocalMutationAt"
        let ts = userDefaults.double(forKey: key)
        if ts <= 0 { return .distantPast }
        return Date(timeIntervalSince1970: ts)
    }

    func loadCurrentFamilyID(for firebaseUID: String) async -> String? {
        do {
            let doc = try await db.collection("user_profile").document(firebaseUID).getDocument()
            let familyID = doc.data()?["currentFamilyID"] as? String
            lastSavedProfileFamilyIDs[firebaseUID] = familyID ?? ""
            return familyID
        } catch {
            print("Firebase load user profile failed (\(firebaseUID)): \(error.localizedDescription)")
            return nil
        }
    }

    func saveCurrentFamilyID(_ familyID: String?, for firebaseUID: String) async {
        do {
            try await saveCurrentFamilyIDOrThrow(familyID, for: firebaseUID)
        } catch {
            print("Firebase save user profile failed (\(firebaseUID)): \(error.localizedDescription)")
        }
    }

    private func saveCurrentFamilyIDOrThrow(_ familyID: String?, for firebaseUID: String) async throws {
        let storedValue = familyID ?? ""
        guard lastSavedProfileFamilyIDs[firebaseUID] != storedValue else { return }

        var payload: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let familyID {
            payload["currentFamilyID"] = familyID
        } else {
            payload["currentFamilyID"] = FieldValue.delete()
        }
        try await db.collection("user_profile").document(firebaseUID).setData(payload, merge: true)
        lastSavedProfileFamilyIDs[firebaseUID] = storedValue
    }
}

private extension FamilyCloudState {
    nonisolated func withoutSubcollectionData() -> FamilyCloudState {
        FamilyCloudState(
            family: family,
            users: [],
            memberships: [],
            joinRequests: [],
            tasks: [],
            scheduleEntries: [],
            groupMessages: [],
            savedChatMessages: [],
            expenseTransactions: [],
            savingsGoals: []
        )
    }
}

private extension JSONDecoder {
    static var grapeFirebaseSync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var grapeFirebaseSync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
#else
actor FirebaseSyncService {
    static let shared = FirebaseSyncService()

    private init() {}

    func bootstrapFamily(localState: FamilyCloudState, familyID: String) async -> FamilyCloudState? {
        print("Firebase family sync skipped: missing FirebaseAuth or FirebaseFirestore package product.")
        return nil
    }

    @discardableResult
    func queueUploadFamily(state: FamilyCloudState, familyID: String) async -> Bool {
        print("Firebase family sync skipped: missing FirebaseAuth or FirebaseFirestore package product.")
        return false
    }

    func loadFamilyState(familyID: String) async -> FamilyCloudState? {
        nil
    }

    func loadFamilyStateForMember(firebaseUID: String, email: String?) async -> FamilyCloudState? {
        nil
    }

    func loadFamilyState(inviteCode: String) async -> FamilyCloudState? {
        nil
    }

    func startListeningToFamily(
        familyID: String,
        onChange: @escaping @MainActor (FamilyCloudState) -> Void
    ) async {}

    func stopAllFamilyListeners() async {}

    func stopAllPresenceListeners() async {}

    func markMemberActive(familyID: String, memberID: String, displayName: String) async {}

    func startListeningToPresence(
        familyID: String,
        activeWithin seconds: TimeInterval,
        onChange: @escaping @MainActor (Set<UUID>) -> Void
    ) async {}

    func loadCurrentFamilyID(for firebaseUID: String) async -> String? {
        nil
    }

    func saveCurrentFamilyID(_ familyID: String?, for firebaseUID: String) async {}
}
#endif
