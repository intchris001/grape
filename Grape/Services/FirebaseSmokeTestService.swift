import Foundation

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore

enum FirebaseSmokeTestService {
    static func runOnce() async {
        do {
            let result = try await Auth.auth().signInAnonymously()
            let uid = result.user.uid

            try await Firestore.firestore()
                .collection("healthcheck")
                .document(uid)
                .setData([
                    "ok": true,
                    "platform": "ios",
                    "createdAt": Timestamp(date: Date())
                ])

            print("Firebase smoke test succeeded. uid=\(uid)")
        } catch {
            print("Firebase smoke test failed: \(error.localizedDescription)")
        }
    }
}
#else
enum FirebaseSmokeTestService {
    static func runOnce() async {
        print("Firebase smoke test skipped: missing FirebaseAuth or FirebaseFirestore package product.")
    }
}
#endif
