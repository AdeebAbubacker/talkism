import Flutter
import UIKit
import PushKit
import CallKit
import FirebaseCore
import FirebaseFirestore

@main
@objc class AppDelegate: FlutterAppDelegate {

    private var provider: CXProvider?
    private var callController = CXCallController()
    private var activeCallUUID: UUID?
    private var flutterChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Set up the Flutter method channel once the engine is ready
        if let controller = window?.rootViewController as? FlutterViewController {
            flutterChannel = FlutterMethodChannel(
                name: "com.talkiyo/callkit",
                binaryMessenger: controller.binaryMessenger
            )
            flutterChannel?.setMethodCallHandler { [weak self] call, result in
                switch call.method {
                case "endCall":
                    self?.endActiveCall()
                    result(nil)
                case "getPendingCallId":
                    let callId = UserDefaults.standard.string(forKey: "pendingVoipCallId") ?? ""
                    result(callId.isEmpty ? nil : callId)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        // Configure CallKit provider
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.ringtoneSound = "iphone.mp3"
        provider = CXProvider(configuration: config)
        provider?.setDelegate(self, queue: nil)

        // Register for VoIP push notifications
        let voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func endActiveCall() {
        guard let uuid = activeCallUUID else { return }
        let endAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endAction)
        callController.request(transaction) { _ in }
    }
}

// MARK: - PKPushRegistryDelegate
extension AppDelegate: PKPushRegistryDelegate {

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        // Send the VoIP token to Flutter so it can be saved to Firestore
        DispatchQueue.main.async { [weak self] in
            self?.flutterChannel?.invokeMethod("voipToken", arguments: token)
        }
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }

        let data = payload.dictionaryPayload
        let callId = data["callId"] as? String ?? data["call_id"] as? String ?? ""
        let callerName = data["callerName"] as? String ?? data["caller_name"] as? String ?? "Unknown"
        let callType = data["callType"] as? String ?? data["call_type"] as? String ?? "audio"

        guard !callId.isEmpty else {
            completion()
            return
        }

        // Store pending call data for Flutter to pick up on launch
        UserDefaults.standard.set(callId, forKey: "pendingVoipCallId")
        UserDefaults.standard.set(callerName, forKey: "pendingVoipCallerName")
        UserDefaults.standard.set(callType, forKey: "pendingVoipCallType")
        UserDefaults.standard.synchronize()

        // Show CallKit incoming call UI (required when app is terminated)
        let uuid = UUID()
        activeCallUUID = uuid

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.hasVideo = callType == "video"
        update.localizedCallerName = callerName

        provider?.reportNewIncomingCall(with: uuid, update: update) { error in
            if error == nil {
                // Notify Flutter if it's already running
                DispatchQueue.main.async { [weak self] in
                    self?.flutterChannel?.invokeMethod("incomingCall", arguments: [
                        "callId": callId,
                        "callerName": callerName,
                        "callType": callType
                    ])
                }
            }
            completion()
        }
    }
}

// MARK: - CXProviderDelegate
extension AppDelegate: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        activeCallUUID = nil
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let callId = UserDefaults.standard.string(forKey: "pendingVoipCallId") ?? ""
        DispatchQueue.main.async { [weak self] in
            self?.flutterChannel?.invokeMethod("acceptCall", arguments: ["callId": callId])
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let callId = UserDefaults.standard.string(forKey: "pendingVoipCallId") ?? ""
        if !callId.isEmpty {
            // Update Firestore directly in case Flutter is not running
            let db = Firestore.firestore()
            db.collection("calls").document(callId).getDocument { snapshot, _ in
                guard let data = snapshot?.data(),
                      let status = data["status"] as? String,
                      status == "ringing" else { return }
                db.collection("calls").document(callId).updateData(["status": "rejected"]) { _ in }
            }
            UserDefaults.standard.removeObject(forKey: "pendingVoipCallId")
            UserDefaults.standard.removeObject(forKey: "pendingVoipCallerName")
            UserDefaults.standard.removeObject(forKey: "pendingVoipCallType")
        }
        DispatchQueue.main.async { [weak self] in
            self?.flutterChannel?.invokeMethod("rejectCall", arguments: ["callId": callId])
        }
        activeCallUUID = nil
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        action.fulfill()
    }
}
