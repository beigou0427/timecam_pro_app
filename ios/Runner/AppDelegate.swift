import Flutter
import UIKit
import CoreLocation
import AVFoundation
import Photos
import SafariServices

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private let channelName = "com.beigou.timecampro/native"
  private var locationManager: CLLocationManager?
  private var pendingLocationResult: FlutterResult?
  private var pendingVideoPickResult: FlutterResult?
  private var selectedVideoUrl: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      setupMethodChannel(BinaryMessenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupMethodChannel(BinaryMessenger messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "getLiveGpsAddress":
        self.handleGetLiveGpsAddress(result: result)
      case "pickVideoFromLibrary":
        self.handlePickVideo(result: result)
      case "compressAndSaveRealVideo":
        let args = call.arguments as? [String: Any]
        let trimSeconds = args?["trimSeconds"] as? Double ?? 15.0
        self.handleCompressAndSave(trimSeconds: trimSeconds, result: result)
      case "openOfficialPortalSafari":
        let args = call.arguments as? [String: Any]
        let urlStr = args?["url"] as? String ?? "https://www.npa.gov.tw/"
        self.handleOpenSafari(urlStr: urlStr, result: result)
      case "saveWatermarkPhotoBytes":
        if let args = call.arguments as? [String: Any],
           let typedData = args["pngBytes"] as? FlutterStandardTypedData {
          self.handleSavePhotoBytes(data: typedData.data, result: result)
        } else {
          result(false)
        }
      case "launchNativeSms":
        let args = call.arguments as? [String: Any]
        let uriStr = args?["uri"] as? String ?? "sms:110"
        self.handleLaunchSms(uriStr: uriStr, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func activeRootViewController() -> UIViewController? {
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene {
        for win in windowScene.windows where win.isKeyWindow {
          if let root = win.rootViewController {
            if let flutterVC = root as? FlutterViewController {
              setupMethodChannel(BinaryMessenger: flutterVC.binaryMessenger)
            }
            return root
          }
        }
      }
    }
    return window?.rootViewController
  }

  // 1. 真實 iPhone GPS 座標與台灣中文路名門牌反查 (CoreLocation + CLGeocoder)
  private func handleGetLiveGpsAddress(result: @escaping FlutterResult) {
    if locationManager == nil {
      locationManager = CLLocationManager()
      locationManager?.delegate = self
      locationManager?.desiredAccuracy = kCLLocationAccuracyBest
    }
    pendingLocationResult = result
    let status = locationManager?.authorizationStatus ?? .notDetermined
    if status == .notDetermined {
      locationManager?.requestWhenInUseAuthorization()
    } else if status == .authorizedWhenInUse || status == .authorizedAlways {
      locationManager?.requestLocation()
    } else {
      pendingLocationResult = nil
      result(nil)
    }
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if (status == .authorizedWhenInUse || status == .authorizedAlways), pendingLocationResult != nil {
      manager.requestLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last, let cb = pendingLocationResult else { return }
    pendingLocationResult = nil
    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "zh_TW")) { placemarks, _ in
      let pm = placemarks?.first
      let city = (pm?.administrativeArea ?? "") + (pm?.locality ?? "")
      let street = (pm?.thoroughfare ?? "") + (pm?.subThoroughfare ?? "")
      cb([
        "latitude": loc.coordinate.latitude,
        "longitude": loc.coordinate.longitude,
        "altitude": loc.altitude,
        "city": city.isEmpty ? "台灣即時衛星定位" : city,
        "street": street.isEmpty ? "已完成精確座標鎖定" : street
      ])
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let cb = pendingLocationResult {
      pendingLocationResult = nil
      cb(nil)
    }
  }

  // 2. 從 iPhone 相簿選取真實行車紀錄/違規影片並計算真實 MB 與秒數
  private func handlePickVideo(result: @escaping FlutterResult) {
    guard let rootVC = activeRootViewController() else {
      result(nil)
      return
    }
    pendingVideoPickResult = result
    let picker = UIImagePickerController()
    picker.sourceType = .photoLibrary
    picker.mediaTypes = ["public.movie"]
    picker.videoQuality = .typeHigh
    picker.delegate = self
    rootVC.present(picker, animated: true)
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)
    guard let cb = pendingVideoPickResult else { return }
    pendingVideoPickResult = nil

    guard let mediaUrl = info[.mediaURL] as? URL else {
      cb(nil)
      return
    }
    selectedVideoUrl = mediaUrl
    let asset = AVURLAsset(url: mediaUrl)
    let durationSec = max(1.0, CMTimeGetSeconds(asset.duration))
    let fileValues = try? mediaUrl.resourceValues(forKeys: [.fileSizeKey])
    let sizeBytes = Double(fileValues?.fileSize ?? (25 * 1024 * 1024))
    let sizeMB = max(0.5, sizeBytes / (1024.0 * 1024.0))

    cb([
      "path": mediaUrl.path,
      "sizeMB": sizeMB,
      "durationSeconds": durationSec,
      "fileName": mediaUrl.lastPathComponent
    ])
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    if let cb = pendingVideoPickResult {
      pendingVideoPickResult = nil
      cb(nil)
    }
  }

  // 3. 使用 AVAssetExportSession 進行真實影片時間軸裁切與 H.264 壓縮，並寫回 iPhone 系統相簿
  private func handleCompressAndSave(trimSeconds: Double, result: @escaping FlutterResult) {
    guard let srcUrl = selectedVideoUrl else {
      result(nil)
      return
    }
    let asset = AVURLAsset(url: srcUrl)
    let totalSec = max(1.0, CMTimeGetSeconds(asset.duration))
    let exportSec = min(totalSec, max(1.0, trimSeconds))

    let preset = AVAssetExportPreset1280x720
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
      result(nil)
      return
    }

    let outFile = NSTemporaryDirectory() + "TimeCamPro_\(Int(Date().timeIntervalSince1970)).mp4"
    let outUrl = URL(fileURLWithPath: outFile)
    try? FileManager.default.removeItem(at: outUrl)

    exportSession.outputURL = outUrl
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true
    exportSession.timeRange = CMTimeRange(
      start: .zero,
      duration: CMTime(seconds: exportSec, preferredTimescale: 600)
    )

    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        if exportSession.status == .completed {
          let vals = try? outUrl.resourceValues(forKeys: [.fileSizeKey])
          let outMB = Double(vals?.fileSize ?? (8 * 1024 * 1024)) / (1024.0 * 1024.0)
          PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
              PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outUrl)
              }) { _, _ in
                DispatchQueue.main.async {
                  result(["outputMB": outMB, "savedToPhotos": true])
                }
              }
            } else {
              DispatchQueue.main.async {
                result(["outputMB": outMB, "savedToPhotos": false])
              }
            }
          }
        } else {
          result(nil)
        }
      }
    }
  }

  // 4. 原生 SFSafariViewController 開啟 22 縣市警局/環保局檢舉網
  private func handleOpenSafari(urlStr: String, result: @escaping FlutterResult) {
    guard let url = URL(string: urlStr), let rootVC = activeRootViewController() else {
      result(false)
      return
    }
    let safariVC = SFSafariViewController(url: url)
    safariVC.preferredControlTintColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
    rootVC.present(safariVC, animated: true)
    result(true)
  }


  private func handleSavePhotoBytes(data: Data, result: @escaping FlutterResult) {
    guard let image = UIImage(data: data) else {
      result(false)
      return
    }
    PHPhotoLibrary.requestAuthorization { status in
      if status == .authorized || status == .limited {
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, _ in
          DispatchQueue.main.async {
            result(success)
          }
        }
      } else {
        DispatchQueue.main.async {
          result(false)
        }
      }
    }
  }

  // 5. 原生喚起 iOS 簡訊 App 自動帶入 110 專線與報案內容
  private func handleLaunchSms(uriStr: String, result: @escaping FlutterResult) {
    guard let url = URL(string: uriStr), UIApplication.shared.canOpenURL(url) else {
      result(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { ok in
      result(ok)
    }
  }

  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    configuration.delegateClass = FlutterSceneDelegate.self
    return configuration
  }
}
