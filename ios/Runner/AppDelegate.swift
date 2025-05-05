import UIKit
import Flutter
import CloudKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Request permission for notifications on iOS 10+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()

    // Setup iCloud capability check
    checkICloudAvailability()

    // Register method channel for native iCloud communication
    let controller = window?.rootViewController as! FlutterViewController
    let iCloudChannel = FlutterMethodChannel(
        name: "com.heymilo.hey_milo/icloud",
        binaryMessenger: controller.binaryMessenger)

    iCloudChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      // Handle iCloud method calls
      if call.method == "checkAvailability" {
        self.checkICloudAvailability(completion: { available in
          result(available)
        })
      } else if call.method == "saveToiCloud" {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String,
              let fileName = args["fileName"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        self.saveToiCloud(localFilePath: filePath, fileName: fileName, completion: { success, error in
          if success {
            result(true)
          } else {
            result(FlutterError(code: "ICLOUD_SAVE_ERROR", message: error, details: nil))
          }
        })
      } else if call.method == "getFromiCloud" {
        guard let args = call.arguments as? [String: Any],
              let fileName = args["fileName"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        self.getFromiCloud(fileName: fileName, completion: { filePath, error in
          if let path = filePath {
            result(path)
          } else {
            result(FlutterError(code: "ICLOUD_GET_ERROR", message: error, details: nil))
          }
        })
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Check iCloud availability
  private func checkICloudAvailability(completion: ((Bool) -> Void)? = nil) {
    CKContainer.default().accountStatus { (accountStatus, error) in
      var isAvailable = false
      switch accountStatus {
      case .available:
        isAvailable = true
        print("iCloud is available")
      case .noAccount:
        print("No iCloud account available")
      case .restricted:
        print("iCloud is restricted")
      case .couldNotDetermine:
        print("Could not determine iCloud status")
      @unknown default:
        print("Unknown iCloud status")
      }
      DispatchQueue.main.async {
        completion?(isAvailable)
      }
    }
  }

  // Save a file to iCloud Drive
  private func saveToiCloud(localFilePath: String, fileName: String, completion: @escaping (Bool, String?) -> Void) {
    guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
      completion(false, "iCloud Drive not available")
      return
    }

    let fileURL = iCloudURL.appendingPathComponent(fileName)
    let localURL = URL(fileURLWithPath: localFilePath)

    do {
      // Create Documents directory if it doesn't exist
      if !FileManager.default.fileExists(atPath: iCloudURL.path) {
        try FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true, attributes: nil)
      }

      // If file exists, remove it first
      if FileManager.default.fileExists(atPath: fileURL.path) {
        try FileManager.default.removeItem(at: fileURL)
      }

      // Copy file to iCloud
      try FileManager.default.copyItem(at: localURL, to: fileURL)

      // Set file to be uploded to iCloud
      do {
        try (fileURL as NSURL).setResourceValue(true, forKey: .isUploadedToCloudKey)
        completion(true, nil)
      } catch {
        completion(false, "File flagged for upload, but error: \(error.localizedDescription)")
      }
    } catch {
      completion(false, "Failed to save to iCloud: \(error.localizedDescription)")
    }
  }

  // Get a file from iCloud Drive
  private func getFromiCloud(fileName: String, completion: @escaping (String?, String?) -> Void) {
    guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
      completion(nil, "iCloud Drive not available")
      return
    }

    let fileURL = iCloudURL.appendingPathComponent(fileName)

    // Check if file exists locally
    if FileManager.default.fileExists(atPath: fileURL.path) {
      completion(fileURL.path, nil)
    } else {
      // Start downloading file
      do {
        try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
        // Check status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          if FileManager.default.fileExists(atPath: fileURL.path) {
            completion(fileURL.path, nil)
          } else {
            completion(nil, "File not found in iCloud after download attempt")
          }
        }
      } catch {
        completion(nil, "Failed to download from iCloud: \(error.localizedDescription)")
      }
    }
  }
}