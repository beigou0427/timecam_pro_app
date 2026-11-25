import AVFoundation
import AudioToolbox
import CoreLocation
import CryptoKit
import Flutter
import ImageIO
import Photos
import PhotosUI
import SafariServices
import Security
import StoreKit
import UIKit
import UniformTypeIdentifiers
import Vision

// MARK: - Live Camera Session Manager (AVCaptureSession + Thread-Safe Delegate)

final class LiveCameraManager: NSObject, AVCapturePhotoCaptureDelegate {
  static let shared = LiveCameraManager()

  let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.beigou.timecampro.camera.session")
  private let photoOutput = AVCapturePhotoOutput()
  private var currentDevice: AVCaptureDevice?
  weak var activePreviewLayer: AVCaptureVideoPreviewLayer?
  private var isConfigured = false
  private var pendingZoomFactor: CGFloat = 1.0
  private var currentVideoOrientation: AVCaptureVideoOrientation = .portrait
  private var photoCompletions: [Int64: (Data?) -> Void] = [:]

  var isRunning: Bool {
    return session.isRunning
  }

  func updateVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
    sessionQueue.async { [weak self] in
      self?.currentVideoOrientation = orientation
    }
  }

  func startIfAuthorized(completion: ((String) -> Void)? = nil) {
    guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
      DispatchQueue.main.async { completion?("unavailable") }
      return
    }
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
      configureAndStart {
        DispatchQueue.main.async { completion?("authorized") }
      }
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        if granted {
          self?.configureAndStart {
            DispatchQueue.main.async { completion?("authorized") }
          }
        } else {
          DispatchQueue.main.async { completion?("denied") }
        }
      }
    case .restricted:
      DispatchQueue.main.async { completion?("restricted") }
    default:
      DispatchQueue.main.async { completion?("denied") }
    }
  }

  func stopRunningSession() {
    sessionQueue.async { [weak self] in
      guard let self = self else { return }
      if let dev = self.currentDevice, dev.hasTorch, dev.torchMode == .on {
        if (try? dev.lockForConfiguration()) != nil {
          dev.torchMode = .off
          dev.unlockForConfiguration()
        }
      }
      if self.session.isRunning {
        self.session.stopRunning()
      }
    }
  }

  private func configureAndStart(afterStart: (() -> Void)? = nil) {
    sessionQueue.async { [weak self] in
      guard let self = self else {
        afterStart?()
        return
      }
      if !self.isConfigured {
        self.session.beginConfiguration()
        self.session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           self.session.canAddInput(input) {
          self.session.addInput(input)
          self.currentDevice = device
        }
        if self.session.canAddOutput(self.photoOutput) {
          self.session.addOutput(self.photoOutput)
        }
        self.session.commitConfiguration()
        self.isConfigured = true
      }
      if !self.session.isRunning {
        self.session.startRunning()
      }
      if self.pendingZoomFactor > 1.0, let device = self.currentDevice {
        let maxZoom = min(6.0, device.activeFormat.videoMaxZoomFactor)
        let clamped = max(1.0, min(maxZoom, self.pendingZoomFactor))
        if (try? device.lockForConfiguration()) != nil {
          device.videoZoomFactor = clamped
          device.unlockForConfiguration()
        }
      }
      afterStart?()
    }
  }

  func setZoomFactor(_ factor: Double, completion: @escaping (Double) -> Void) {
    let clampedRequested = max(1.0, min(6.0, CGFloat(factor)))
    sessionQueue.async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async { completion(Double(clampedRequested)) }
        return
      }
      self.pendingZoomFactor = clampedRequested
      guard let device = self.currentDevice else {
        DispatchQueue.main.async { completion(Double(clampedRequested)) }
        return
      }
      let maxZoom = min(6.0, device.activeFormat.videoMaxZoomFactor)
      let applied = max(1.0, min(maxZoom, clampedRequested))
      do {
        try device.lockForConfiguration()
        device.videoZoomFactor = applied
        device.unlockForConfiguration()
      } catch {
        DispatchQueue.main.async { completion(Double(device.videoZoomFactor)) }
        return
      }
      DispatchQueue.main.async { completion(Double(applied)) }
    }
  }

  func setTorchEnabled(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
    sessionQueue.async { [weak self] in
      let device = self?.currentDevice ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
      guard let dev = device, dev.hasTorch else {
        DispatchQueue.main.async { completion(false) }
        return
      }
      do {
        try dev.lockForConfiguration()
        if enabled && dev.isTorchModeSupported(.on) {
          dev.torchMode = .on
        } else if dev.isTorchModeSupported(.off) {
          dev.torchMode = .off
        }
        let isOn = dev.torchMode == .on
        dev.unlockForConfiguration()
        DispatchQueue.main.async { completion(isOn) }
      } catch {
        DispatchQueue.main.async { completion(false) }
      }
    }
  }

  func focusAtNormalizedPoint(x: Double, y: Double, completion: @escaping (Bool) -> Void) {
    let clampedX = max(0.0, min(1.0, CGFloat(x)))
    let clampedY = max(0.0, min(1.0, CGFloat(y)))
    let devicePoint: CGPoint
    if let layer = activePreviewLayer, layer.bounds.width > 1.0, layer.bounds.height > 1.0 {
      let layerPt = CGPoint(x: clampedX * layer.bounds.width, y: clampedY * layer.bounds.height)
      devicePoint = layer.captureDevicePointConverted(fromLayerPoint: layerPt)
    } else {
      devicePoint = CGPoint(x: clampedY, y: 1.0 - clampedX)
    }

    sessionQueue.async { [weak self] in
      guard let self = self, let device = self.currentDevice else {
        DispatchQueue.main.async { completion(false) }
        return
      }
      do {
        try device.lockForConfiguration()
        if device.isFocusPointOfInterestSupported {
          device.focusPointOfInterest = devicePoint
          if device.isFocusModeSupported(.autoFocus) {
            device.focusMode = .autoFocus
          } else if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
          }
        }
        if device.isExposurePointOfInterestSupported {
          device.exposurePointOfInterest = devicePoint
          if device.isExposureModeSupported(.autoExpose) {
            device.exposureMode = .autoExpose
          } else if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
          }
        }
        device.unlockForConfiguration()
        DispatchQueue.main.async { completion(true) }
      } catch {
        DispatchQueue.main.async { completion(false) }
      }
    }
  }

  func pauseForModalPicker() {
    stopRunningSession()
  }

  func resumeAfterModalPicker() {
    guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
    sessionQueue.async { [weak self] in
      guard let self = self, self.isConfigured else { return }
      if !self.session.isRunning {
        self.session.startRunning()
      }
    }
  }

  func capturePhoto(completion: @escaping (Data?) -> Void) {
    sessionQueue.async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async { completion(nil) }
        return
      }
      guard self.isConfigured, self.session.isRunning else {
        DispatchQueue.main.async { completion(nil) }
        return
      }
      if let conn = self.photoOutput.connection(with: .video), conn.isVideoOrientationSupported {
        conn.videoOrientation = self.currentVideoOrientation
      }
      let settings = AVCapturePhotoSettings()
      self.photoCompletions[settings.uniqueID] = completion
      self.photoOutput.capturePhoto(with: settings, delegate: self)
    }
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    let uniqueID = photo.resolvedSettings.uniqueID
    let rawData = (error == nil) ? photo.fileDataRepresentation() : nil
    sessionQueue.async { [weak self] in
      guard let self = self else { return }
      let completion = self.photoCompletions.removeValue(forKey: uniqueID)
      DispatchQueue.main.async {
        completion?(rawData)
      }
    }
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
    error: Error?
  ) {
    let uniqueID = resolvedSettings.uniqueID
    sessionQueue.async { [weak self] in
      guard let self = self else { return }
      if let remaining = self.photoCompletions.removeValue(forKey: uniqueID) {
        DispatchQueue.main.async {
          remaining(nil)
        }
      }
    }
  }
}

final class CameraPreviewContainerView: UIView {
  private let previewLayer = AVCaptureVideoPreviewLayer(session: LiveCameraManager.shared.session)

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = UIColor(red: 9/255, green: 12/255, blue: 18/255, alpha: 1.0)
    previewLayer.videoGravity = .resizeAspectFill
    layer.addSublayer(previewLayer)
    LiveCameraManager.shared.activePreviewLayer = previewLayer
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleOrientationNotification),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
    if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
      LiveCameraManager.shared.startIfAuthorized()
    }
    updatePreviewOrientation()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func handleOrientationNotification() {
    updatePreviewOrientation()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    updatePreviewOrientation()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer.frame = bounds
    updatePreviewOrientation()
  }

  private func updatePreviewOrientation() {
    let interfaceOrientation: UIInterfaceOrientation =
      window?.windowScene?.interfaceOrientation
      ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation
      ?? .portrait

    let videoOrientation: AVCaptureVideoOrientation
    switch interfaceOrientation {
    case .portraitUpsideDown:
      videoOrientation = .portraitUpsideDown
    case .landscapeLeft:
      videoOrientation = .landscapeLeft
    case .landscapeRight:
      videoOrientation = .landscapeRight
    default:
      videoOrientation = .portrait
    }

    if let conn = previewLayer.connection, conn.isVideoOrientationSupported {
      conn.videoOrientation = videoOrientation
    }
    LiveCameraManager.shared.updateVideoOrientation(videoOrientation)
  }
}

final class LiveCameraPlatformView: NSObject, FlutterPlatformView {
  private let containerView: CameraPreviewContainerView

  init(frame: CGRect) {
    containerView = CameraPreviewContainerView(frame: frame)
    super.init()
  }

  func view() -> UIView {
    return containerView
  }
}

final class LiveCameraPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return LiveCameraPlatformView(frame: frame)
  }
}

// MARK: - AppDelegate

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
  private let channelName = "com.beigou.timecampro/native"
  private let previewViewType = "com.beigou.timecampro/live_camera_preview"
  private let legacyPersistedStateKey = "timecam_pro_state_v1"
  private let keychainQuotaService = "com.beigou.timecampro.quota"
  private let keychainQuotaAccount = "usedFreeExports"

  private var isEngineConfigured = false
  private var methodChannel: FlutterMethodChannel?
  private var locationManager: CLLocationManager?
  private var pendingLocationResult: FlutterResult?
  private var pendingLocationTimeoutWork: DispatchWorkItem?
  private var pendingLocationIsZh = true
  private var pendingCameraResult: FlutterResult?
  private var pendingVideoPickResult: FlutterResult?
  private var selectedVideoUrl: URL?
  private var storeKitUpdatesTask: Task<Void, Never>?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    cleanupStaleTempFiles()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )

    if let controller = window?.rootViewController as? FlutterViewController {
      configureFlutterEngine(controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func cleanupStaleTempFiles() {
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    guard let items = try? FileManager.default.contentsOfDirectory(
      at: tmpDir,
      includingPropertiesForKeys: nil
    ) else { return }
    for url in items where url.lastPathComponent.hasPrefix("TimeCamPro_") {
      try? FileManager.default.removeItem(at: url)
    }
  }

  deinit {
    storeKitUpdatesTask?.cancel()
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func handleAppDidEnterBackground() {
    LiveCameraManager.shared.stopRunningSession()
  }

  func configureFlutterEngine(_ controller: FlutterViewController) {
    guard !isEngineConfigured else { return }
    isEngineConfigured = true

    GeneratedPluginRegistrant.register(with: controller)

    if let registrar = controller.registrar(forPlugin: "TimeCamProLiveCameraPlugin") {
      registrar.register(LiveCameraPlatformViewFactory(), withId: previewViewType)
    }

    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
    methodChannel = channel
    startStoreKitTransactionObserver()

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "captureAndRenderWatermarkPhoto":
        let args = call.arguments as? [String: Any] ?? [:]
        self.handleCaptureAndRenderWatermarkPhoto(args: args, result: result)
      case "captureRealCameraPhoto":
        let args = call.arguments as? [String: Any]
        let preferLive = args?["preferLiveSession"] as? Bool ?? true
        self.handleCapturePhoto(preferLiveSession: preferLive, result: result)
      case "recordRealCameraVideo":
        self.handleRecordVideo(result: result)
      case "getLiveGpsAddress":
        let args = call.arguments as? [String: Any]
        let isZh = args?["isZh"] as? Bool ?? true
        self.handleGetLiveGpsAddress(isZh: isZh, result: result)
      case "pickVideoFromLibrary":
        self.handlePickVideo(result: result)
      case "compressAndSaveRealVideo":
        let args = call.arguments as? [String: Any]
        let startSeconds = args?["startSeconds"] as? Double ?? 0.0
        let trimSeconds = args?["trimSeconds"] as? Double ?? 15.0
        let targetLimitMB = args?["targetLimitMB"] as? Double ?? 19.0
        self.handleCompressAndSave(
          startSeconds: startSeconds,
          trimSeconds: trimSeconds,
          targetLimitMB: targetLimitMB,
          result: result
        )
      case "startLiveCameraSession":
        LiveCameraManager.shared.startIfAuthorized { status in
          result(status)
        }
      case "stopLiveCameraSession":
        LiveCameraManager.shared.stopRunningSession()
        result(true)
      case "setCameraZoom":
        let args = call.arguments as? [String: Any]
        let factor = args?["factor"] as? Double ?? 1.0
        LiveCameraManager.shared.setZoomFactor(factor) { applied in
          result(applied)
        }
      case "setCameraTorch":
        let args = call.arguments as? [String: Any]
        let enabled = args?["enabled"] as? Bool ?? false
        LiveCameraManager.shared.setTorchEnabled(enabled) { isOn in
          result(isOn)
        }
      case "focusCameraAt":
        let args = call.arguments as? [String: Any]
        let x = args?["x"] as? Double ?? 0.5
        let y = args?["y"] as? Double ?? 0.5
        LiveCameraManager.shared.focusAtNormalizedPoint(x: x, y: y) { ok in
          result(ok)
        }
      case "shareImageBytes":
        if let args = call.arguments as? [String: Any],
           let typedData = args["pngBytes"] as? FlutterStandardTypedData {
          let text = args["text"] as? String ?? ""
          self.handleShareImageBytes(data: typedData.data, text: text, result: result)
        } else {
          result(false)
        }
      case "saveCaseThumbnail":
        if let args = call.arguments as? [String: Any],
           let typedData = args["pngBytes"] as? FlutterStandardTypedData {
          let caseId = args["caseId"] as? String ?? "case"
          self.handleSaveCaseThumbnail(data: typedData.data, caseId: caseId, result: result)
        } else {
          result(nil)
        }
      case "deleteCaseThumbnail":
        if let args = call.arguments as? [String: Any],
           let path = args["path"] as? String {
          self.handleDeleteCaseThumbnail(path: path, result: result)
        } else {
          result(false)
        }
      case "openOfficialPortalSafari":
        let args = call.arguments as? [String: Any]
        let urlStr = args?["url"] as? String ?? "https://www.npa.gov.tw/"
        self.handleOpenSafari(urlStr: urlStr, result: result)
      case "saveWatermarkPhotoBytes":
        if let args = call.arguments as? [String: Any],
           let typedData = args["pngBytes"] as? FlutterStandardTypedData {
          let lat = (args["latitude"] as? NSNumber)?.doubleValue
          let lng = (args["longitude"] as? NSNumber)?.doubleValue
          let alt = (args["altitude"] as? NSNumber)?.doubleValue
          let tsMs = (args["timestampMs"] as? NSNumber)?.doubleValue
          self.handleSavePhotoBytes(
            data: typedData.data,
            latitude: lat,
            longitude: lng,
            altitude: alt,
            timestampMs: tsMs,
            result: result
          )
        } else {
          result(false)
        }
      case "checkActiveEntitlements":
        self.handleCheckActiveEntitlements(result: result)
      case "syncStoreKitRestore":
        self.handleSyncStoreKitRestore(result: result)
      case "fetchStoreKitProducts":
        let args = call.arguments as? [String: Any]
        let ids = args?["productIds"] as? [String] ?? []
        self.handleFetchStoreKitProducts(productIds: ids, result: result)
      case "purchaseStoreKitProduct":
        let args = call.arguments as? [String: Any]
        let productId = args?["productId"] as? String ?? ""
        self.handlePurchaseStoreKitProduct(productId: productId, result: result)
      case "loadKeychainQuota":
        result(self.loadKeychainQuota())
      case "saveKeychainQuota":
        let args = call.arguments as? [String: Any]
        let count = (args?["usedFreeExports"] as? NSNumber)?.intValue ?? 0
        result(self.saveKeychainQuota(max(0, count)))
      case "openExternalUrl":
        let args = call.arguments as? [String: Any]
        let urlStr = args?["url"] as? String ?? ""
        self.handleOpenExternalUrl(urlStr: urlStr, result: result)
      case "loadPersistedState":
        result(self.loadProtectedStateJson())
      case "savePersistedState":
        if let args = call.arguments as? [String: Any],
           let json = args["json"] as? String {
          result(self.saveProtectedStateJson(json))
        } else {
          result(false)
        }
      case "requestInAppReview":
        self.handleRequestInAppReview(result: result)
      case "exportAndSharePdfReport":
        if let args = call.arguments as? [String: Any],
           let html = args["html"] as? String {
          let fileName = args["fileName"] as? String ?? "TimeCamPro_Report.pdf"
          self.handleExportAndSharePdf(html: html, fileName: fileName, result: result)
        } else {
          result(false)
        }
      case "openAppSettings":
        self.handleOpenAppSettings(result: result)
      case "recognizeLicensePlateFromBytes":
        if let args = call.arguments as? [String: Any],
           let typedData = args["imageBytes"] as? FlutterStandardTypedData {
          self.handleRecognizePlate(imageData: typedData.data, result: result)
        } else {
          result(nil)
        }
      case "scanLiveLicensePlate":
        if LiveCameraManager.shared.isRunning {
          LiveCameraManager.shared.capturePhoto { [weak self] data in
            if let bytes = data {
              self?.handleRecognizePlate(imageData: bytes, result: result)
            } else {
              result(nil)
            }
          }
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func topMostViewController() -> UIViewController? {
    var root: UIViewController?
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene {
        if let keyWin = windowScene.windows.first(where: { $0.isKeyWindow }) {
          root = keyWin.rootViewController
          break
        }
        if root == nil, let firstWin = windowScene.windows.first {
          root = firstWin.rootViewController
        }
      }
    }
    if root == nil {
      root = window?.rootViewController
    }
    var current = root
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }

  // MARK: - 1. Native Full-Res Watermark Capture & SHA-256

  private func handleCaptureAndRenderWatermarkPhoto(args: [String: Any], result: @escaping FlutterResult) {
    let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
    if authStatus == .denied || authStatus == .restricted {
      result([
        "ok": false,
        "savedToPhotos": false,
        "errorCode": "CAMERA_PERMISSION_DENIED"
      ])
      return
    }
    guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
      result([
        "ok": false,
        "savedToPhotos": false,
        "errorCode": "CAMERA_UNAVAILABLE"
      ])
      return
    }

    let processCapturedData: (Data?) -> Void = { [weak self] rawData in
      guard let self = self, let rawData = rawData else {
        DispatchQueue.main.async {
          result([
            "ok": false,
            "savedToPhotos": false,
            "errorCode": "CAMERA_CAPTURE_FAILED"
          ])
        }
        return
      }
      self.renderCompositeAndSaveWatermarkPhoto(rawData: rawData, args: args, result: result)
    }

    if LiveCameraManager.shared.isRunning {
      LiveCameraManager.shared.capturePhoto(completion: processCapturedData)
    } else {
      LiveCameraManager.shared.startIfAuthorized { status in
        guard status == "authorized" else {
          result([
            "ok": false,
            "savedToPhotos": false,
            "errorCode": "CAMERA_PERMISSION_DENIED"
          ])
          return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          LiveCameraManager.shared.capturePhoto(completion: processCapturedData)
        }
      }
    }
  }

  private func renderCompositeAndSaveWatermarkPhoto(
    rawData: Data,
    args: [String: Any],
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self, let rawImage = UIImage(data: rawData) else {
        DispatchQueue.main.async {
          result([
            "ok": false,
            "savedToPhotos": false,
            "errorCode": "IMAGE_DECODE_FAILED"
          ])
        }
        return
      }

      let autoDetectPlate = args["autoDetectPlate"] as? Bool ?? false
      let initialNote = (args["noteText"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      var recognizedPlate: String?
      if autoDetectPlate && initialNote.isEmpty {
        recognizedPlate = Self.recognizePlateSync(from: rawImage)
      }
      let finalNote = initialNote.isEmpty ? (recognizedPlate ?? "") : initialNote

      let upright = Self.normalizeImageUp(rawImage)
      guard let canonicalPhotoBytes = upright.jpegData(compressionQuality: 0.90) else {
        DispatchQueue.main.async {
          result([
            "ok": false,
            "savedToPhotos": false,
            "errorCode": "IMAGE_ENCODE_FAILED"
          ])
        }
        return
      }

      let timestampText = args["timestampText"] as? String ?? ""
      let headerText = args["headerText"] as? String ?? ""
      let addressText = args["addressText"] as? String ?? ""
      let coordsText = args["coordsText"] as? String ?? ""
      let showBrandBadge = args["showBrandBadge"] as? Bool ?? true
      let watermarkOpacity = CGFloat(max(0.25, min(0.92, args["watermarkOpacity"] as? Double ?? 0.72)))
      let lat = (args["latitude"] as? NSNumber)?.doubleValue
      let lng = (args["longitude"] as? NSNumber)?.doubleValue
      let alt = (args["altitude"] as? NSNumber)?.doubleValue
      let tsMs = (args["timestampMs"] as? NSNumber)?.doubleValue
      let caseId = args["caseId"] as? String ?? "CASE-\(Int(Date().timeIntervalSince1970 * 1000))"

      let latStr: String
      let lngStr: String
      let altStr: String
      if let la = lat, let lo = lng, la.isFinite, lo.isFinite, !(abs(la) < 0.0001 && abs(lo) < 0.0001), abs(la) <= 90.0, abs(lo) <= 180.0 {
        latStr = String(format: "%.5f", la)
        lngStr = String(format: "%.5f", lo)
        altStr = (alt != nil && alt!.isFinite) ? String(format: "%.1f", alt!) : "0.0"
      } else {
        latStr = "0.00000"
        lngStr = "0.00000"
        altStr = "0.0"
      }
      let canonicalMeta = "\(timestampText)|\(latStr),\(lngStr),\(altStr)|\(addressText)|\(finalNote)"
      var hasher = SHA256()
      hasher.update(data: canonicalPhotoBytes)
      hasher.update(data: Data(canonicalMeta.utf8))
      let digest = hasher.finalize()
      let sha256Hex = digest.map { String(format: "%02X", $0) }.joined()
      let idx4 = sha256Hex.index(sha256Hex.startIndex, offsetBy: 4)
      let idx8 = sha256Hex.index(sha256Hex.startIndex, offsetBy: 8)
      let idx12 = sha256Hex.index(sha256Hex.startIndex, offsetBy: 12)
      let shortSeal = "SHA-\(sha256Hex[..<idx4])-\(sha256Hex[idx4..<idx8])-\(sha256Hex[idx8..<idx12])"
      let isProFreeSealLabel = showBrandBadge
        ? "SHA-256 \(String(shortSeal.prefix(13)))-**** (Pro)"
        : "SHA-256 \(shortSeal)"

      let composited = Self.drawFullResWatermark(
        on: upright,
        timestampText: timestampText,
        headerText: headerText,
        addressText: addressText,
        coordsText: coordsText,
        noteText: finalNote,
        sealLabel: isProFreeSealLabel,
        showBrandBadge: showBrandBadge,
        opacity: watermarkOpacity
      )

      guard let finalJpeg = composited.jpegData(compressionQuality: 0.88) else {
        DispatchQueue.main.async {
          result([
            "ok": false,
            "savedToPhotos": false,
            "errorCode": "IMAGE_ENCODE_FAILED"
          ])
        }
        return
      }

      let thumbPath = self.writeProtectedThumbnail(image: composited, caseId: caseId)
      let previewData = Self.makeScaledJpeg(image: composited, maxSide: 900.0, quality: 0.78) ?? finalJpeg

      let capturedDate: Date = (tsMs != nil && tsMs!.isFinite && tsMs! > 0)
        ? Date(timeIntervalSince1970: tsMs! / 1000.0)
        : Date()
      let validLocation: CLLocation?
      if let la = lat, let lo = lng, la.isFinite, lo.isFinite, !(abs(la) < 0.0001 && abs(lo) < 0.0001), abs(la) <= 90.0, abs(lo) <= 180.0 {
        let safeAlt = (alt != nil && alt!.isFinite) ? alt! : 0.0
        validLocation = CLLocation(
          coordinate: CLLocationCoordinate2D(latitude: la, longitude: lo),
          altitude: safeAlt,
          horizontalAccuracy: 10.0,
          verticalAccuracy: 10.0,
          timestamp: capturedDate
        )
      } else {
        validLocation = nil
      }

      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        if status == .authorized || status == .limited {
          PHPhotoLibrary.shared().performChanges({
            let req = PHAssetCreationRequest.forAsset()
            req.addResource(with: .photo, data: finalJpeg, options: nil)
            req.creationDate = capturedDate
            if let loc = validLocation {
              req.location = loc
            }
          }) { saved, _ in
            DispatchQueue.main.async {
              result([
                "ok": true,
                "savedToPhotos": saved,
                "errorCode": saved ? NSNull() : "PHOTO_SAVE_FAILED",
                "thumbnailPath": (thumbPath as Any?) ?? NSNull(),
                "previewJpeg": FlutterStandardTypedData(bytes: previewData),
                "sha256Hex": sha256Hex,
                "shortSeal": shortSeal,
                "recognizedPlate": (recognizedPlate as Any?) ?? NSNull()
              ])
            }
          }
        } else {
          DispatchQueue.main.async {
            result([
              "ok": true,
              "savedToPhotos": false,
              "errorCode": "PHOTO_PERMISSION_DENIED",
              "thumbnailPath": (thumbPath as Any?) ?? NSNull(),
              "previewJpeg": FlutterStandardTypedData(bytes: previewData),
              "sha256Hex": sha256Hex,
              "shortSeal": shortSeal,
              "recognizedPlate": (recognizedPlate as Any?) ?? NSNull()
            ])
          }
        }
      }
    }
  }

  private static func normalizeImageUp(_ image: UIImage) -> UIImage {
    if image.imageOrientation == .up { return image }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1.0
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }

  private static func makeScaledJpeg(image: UIImage, maxSide: CGFloat, quality: CGFloat) -> Data? {
    let origSize = image.size
    let scale = min(1.0, maxSide / max(origSize.width, max(1.0, origSize.height)))
    let targetSize = CGSize(
      width: max(1.0, (origSize.width * scale).rounded()),
      height: max(1.0, (origSize.height * scale).rounded())
    )
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1.0
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    return resized.jpegData(compressionQuality: quality)
  }

  private static func drawFullResWatermark(
    on image: UIImage,
    timestampText: String,
    headerText: String,
    addressText: String,
    coordsText: String,
    noteText: String,
    sealLabel: String,
    showBrandBadge: Bool,
    opacity: CGFloat
  ) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1.0
    format.opaque = true
    let size = image.size
    let minSide = min(size.width, size.height)
    let unit = max(1.0, minSide / 390.0)

    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { ctx in
      image.draw(in: CGRect(origin: .zero, size: size))
      let cg = ctx.cgContext

      let barHeight = min(size.height * 0.44, 195.0 * unit)
      let barRect = CGRect(x: 0, y: size.height - barHeight, width: size.width, height: barHeight)
      let colors = [
        UIColor.black.withAlphaComponent(0.0).cgColor,
        UIColor.black.withAlphaComponent(min(0.95, opacity * 0.72)).cgColor,
        UIColor.black.withAlphaComponent(min(0.96, opacity * 1.15)).cgColor,
      ] as CFArray
      if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 0.32, 1.0]) {
        cg.drawLinearGradient(
          gradient,
          start: CGPoint(x: 0, y: barRect.minY),
          end: CGPoint(x: 0, y: barRect.maxY),
          options: []
        )
      }

      let padX = 16.0 * unit
      var curY = size.height - 14.0 * unit
      let maxTextW = size.width - padX * 2.0
      let gold = UIColor(red: 245/255, green: 183/255, blue: 59/255, alpha: 1.0)

      if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let noteFont = UIFont.systemFont(ofSize: 13.0 * unit, weight: .bold)
        let noteAttr: [NSAttributedString.Key: Any] = [.font: noteFont, .foregroundColor: gold]
        let noteSize = (noteText as NSString).boundingRect(
          with: CGSize(width: maxTextW - 18.0 * unit, height: 48.0 * unit),
          options: .usesLineFragmentOrigin,
          attributes: noteAttr,
          context: nil
        ).size
        let pillW = min(maxTextW, noteSize.width + 18.0 * unit)
        let pillH = noteSize.height + 10.0 * unit
        curY -= pillH
        let pillRect = CGRect(x: padX, y: curY, width: pillW, height: pillH)
        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: 6.0 * unit)
        UIColor(red: 18/255, green: 20/255, blue: 26/255, alpha: 0.90).setFill()
        pillPath.fill()
        gold.withAlphaComponent(0.42).setStroke()
        pillPath.lineWidth = max(1.0, 1.0 * unit)
        pillPath.stroke()
        (noteText as NSString).draw(
          in: CGRect(x: padX + 9.0 * unit, y: curY + 5.0 * unit, width: pillW - 18.0 * unit, height: noteSize.height),
          withAttributes: noteAttr
        )
        curY -= 6.0 * unit
      }

      let metaFont = UIFont.monospacedDigitSystemFont(ofSize: 10.5 * unit, weight: .medium)
      let metaLine = coordsText.isEmpty ? sealLabel : "\(coordsText) · \(sealLabel)"
      let metaAttr: [NSAttributedString.Key: Any] = [
        .font: metaFont,
        .foregroundColor: UIColor.white.withAlphaComponent(0.76)
      ]
      let metaMaxW = max(80.0 * unit, maxTextW - (showBrandBadge ? 95.0 * unit : 0))
      let metaRect = (metaLine as NSString).boundingRect(
        with: CGSize(width: metaMaxW, height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: metaAttr,
        context: nil
      )
      let metaH = ceil(metaRect.height)
      curY -= metaH
      (metaLine as NSString).draw(
        with: CGRect(x: padX, y: curY, width: metaMaxW, height: metaH),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: metaAttr,
        context: nil
      )
      if showBrandBadge {
        let brandAttr: [NSAttributedString.Key: Any] = [
          .font: UIFont.systemFont(ofSize: 9.5 * unit, weight: .bold),
          .foregroundColor: gold.withAlphaComponent(0.85)
        ]
        let bSize = ("TimeCam Pro" as NSString).size(withAttributes: brandAttr)
        ("TimeCam Pro" as NSString).draw(
          at: CGPoint(x: size.width - padX - bSize.width, y: curY + max(0, metaH - ceil(bSize.height))),
          withAttributes: brandAttr
        )
      }
      curY -= 4.0 * unit

      let addrFont = UIFont.systemFont(ofSize: 13.0 * unit, weight: .semibold)
      let addrAttr: [NSAttributedString.Key: Any] = [
        .font: addrFont,
        .foregroundColor: UIColor.white.withAlphaComponent(0.94)
      ]
      let addrRect = (addressText as NSString).boundingRect(
        with: CGSize(width: maxTextW, height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: addrAttr,
        context: nil
      )
      let addrH = ceil(addrRect.height)
      curY -= addrH
      (addressText as NSString).draw(
        with: CGRect(x: padX, y: curY, width: maxTextW, height: addrH),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: addrAttr,
        context: nil
      )
      curY -= 5.0 * unit

      let timeFont = UIFont.monospacedDigitSystemFont(ofSize: 18.0 * unit, weight: .bold)
      let timeAttr: [NSAttributedString.Key: Any] = [.font: timeFont, .foregroundColor: UIColor.white]
      let timeH = ceil((timestampText as NSString).size(withAttributes: timeAttr).height)
      curY -= timeH
      (timestampText as NSString).draw(
        in: CGRect(x: padX, y: curY, width: maxTextW, height: timeH),
        withAttributes: timeAttr
      )

      if !headerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        curY -= 5.0 * unit
        let hdrFont = UIFont.systemFont(ofSize: 11.0 * unit, weight: .bold)
        let hdrAttr: [NSAttributedString.Key: Any] = [.font: hdrFont, .foregroundColor: gold]
        let hdrSize = (headerText as NSString).size(withAttributes: hdrAttr)
        curY -= ceil(hdrSize.height)
        (headerText as NSString).draw(
          in: CGRect(x: padX, y: curY, width: maxTextW, height: ceil(hdrSize.height)),
          withAttributes: hdrAttr
        )
      }
    }
  }

  private func handleCapturePhoto(preferLiveSession: Bool, result: @escaping FlutterResult) {
    if preferLiveSession && LiveCameraManager.shared.isRunning {
      LiveCameraManager.shared.capturePhoto { [weak self] rawData in
        if let raw = rawData,
           let img = UIImage(data: raw),
           let jpeg = Self.normalizeImageUp(img).jpegData(compressionQuality: 0.88) {
          result(FlutterStandardTypedData(bytes: jpeg))
        } else {
          self?.presentCameraPicker(mode: .photo, result: result)
        }
      }
      return
    }
    presentCameraPicker(mode: .photo, result: result)
  }

  private func handleRecordVideo(result: @escaping FlutterResult) {
    presentCameraPicker(mode: .video, result: result)
  }

  private func presentCameraPicker(mode: UIImagePickerController.CameraCaptureMode, result: @escaping FlutterResult) {
    guard let presenter = topMostViewController(),
          UIImagePickerController.isSourceTypeAvailable(.camera) else {
      result(nil)
      return
    }

    LiveCameraManager.shared.pauseForModalPicker()

    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = self

    if mode == .video {
      if let prev = pendingVideoPickResult {
        pendingVideoPickResult = nil
        prev(nil)
      }
      pendingVideoPickResult = result
      picker.mediaTypes = ["public.movie"]
      picker.cameraCaptureMode = .video
      picker.videoQuality = .typeHigh
      picker.videoMaximumDuration = 120
    } else {
      if let prev = pendingCameraResult {
        pendingCameraResult = nil
        prev(nil)
      }
      pendingCameraResult = result
      picker.mediaTypes = ["public.image"]
      picker.cameraCaptureMode = .photo
    }

    presenter.present(picker, animated: true)
  }

  // MARK: - 2. Real GPS & Reverse Geocoding (with 10s timeout & explicit error codes)

  private func startLocationTimeout(seconds: TimeInterval = 10.0) {
    pendingLocationTimeoutWork?.cancel()
    let timeoutWork = DispatchWorkItem { [weak self] in
      guard let self = self, let cb = self.pendingLocationResult else { return }
      self.pendingLocationResult = nil
      self.pendingLocationTimeoutWork = nil
      cb(["errorCode": "LOCATION_TIMEOUT"])
    }
    pendingLocationTimeoutWork = timeoutWork
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: timeoutWork)
  }

  private func handleGetLiveGpsAddress(isZh: Bool, result: @escaping FlutterResult) {
    pendingLocationTimeoutWork?.cancel()
    pendingLocationTimeoutWork = nil
    if let prev = pendingLocationResult {
      pendingLocationResult = nil
      prev(["errorCode": "LOCATION_SUPERSEDED"])
    }
    pendingLocationIsZh = isZh
    if locationManager == nil {
      locationManager = CLLocationManager()
      locationManager?.delegate = self
      locationManager?.desiredAccuracy = kCLLocationAccuracyBest
    }
    pendingLocationResult = result

    let status = locationManager?.authorizationStatus ?? .notDetermined
    switch status {
    case .notDetermined:
      locationManager?.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      startLocationTimeout(seconds: 10.0)
      locationManager?.requestLocation()
    default:
      pendingLocationTimeoutWork?.cancel()
      pendingLocationTimeoutWork = nil
      pendingLocationResult = nil
      result(["errorCode": "LOCATION_DENIED"])
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    guard pendingLocationResult != nil else { return }
    if status == .authorizedWhenInUse || status == .authorizedAlways {
      startLocationTimeout(seconds: 10.0)
      manager.requestLocation()
    } else if status == .denied || status == .restricted {
      pendingLocationTimeoutWork?.cancel()
      pendingLocationTimeoutWork = nil
      let cb = pendingLocationResult
      pendingLocationResult = nil
      cb?(["errorCode": "LOCATION_DENIED"])
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last, let cb = pendingLocationResult else { return }
    pendingLocationTimeoutWork?.cancel()
    pendingLocationTimeoutWork = nil
    let isZh = pendingLocationIsZh
    pendingLocationResult = nil

    var replied = false
    let geoFallback = DispatchWorkItem {
      guard !replied else { return }
      replied = true
      cb([
        "latitude": loc.coordinate.latitude,
        "longitude": loc.coordinate.longitude,
        "altitude": loc.altitude,
        "city": isZh ? "即時衛星定位" : "Live GPS Fix",
        "street": isZh ? "已完成座標鎖定" : "Coordinates Locked"
      ])
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: geoFallback)

    let geocoder = CLGeocoder()
    let locale = Locale(identifier: isZh ? "zh_TW" : "en_US")
    geocoder.reverseGeocodeLocation(loc, preferredLocale: locale) { placemarks, _ in
      DispatchQueue.main.async {
        geoFallback.cancel()
        guard !replied else { return }
        replied = true
        let pm = placemarks?.first
        let city: String
        let street: String
        if isZh {
          city = (pm?.administrativeArea ?? "") + (pm?.subAdministrativeArea ?? "") + (pm?.locality ?? "")
          street = (pm?.thoroughfare ?? "") + (pm?.subThoroughfare ?? "")
        } else {
          city = [pm?.locality, pm?.administrativeArea]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
          let rawStreet = [pm?.subThoroughfare, pm?.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
          street = rawStreet.isEmpty ? (pm?.name ?? "") : rawStreet
        }
        cb([
          "latitude": loc.coordinate.latitude,
          "longitude": loc.coordinate.longitude,
          "altitude": loc.altitude,
          "city": city.isEmpty ? (isZh ? "即時衛星定位" : "Live GPS Fix") : city,
          "street": street.isEmpty ? (isZh ? "已完成座標鎖定" : "Coordinates Locked") : street
        ])
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    pendingLocationTimeoutWork?.cancel()
    pendingLocationTimeoutWork = nil
    if let cb = pendingLocationResult {
      pendingLocationResult = nil
      cb(["errorCode": "LOCATION_FAILED"])
    }
  }

  // MARK: - 3. PHPicker (iOS 14+, Supports .limited) & Async Video Staging

  private func handlePickVideo(result: @escaping FlutterResult) {
    guard let presenter = topMostViewController() else {
      result(nil)
      return
    }
    if let prev = pendingVideoPickResult {
      pendingVideoPickResult = nil
      prev(nil)
    }
    pendingVideoPickResult = result
    var config = PHPickerConfiguration(photoLibrary: .shared())
    config.filter = .videos
    config.selectionLimit = 1
    config.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true) {
      LiveCameraManager.shared.resumeAfterModalPicker()
    }
    guard let cb = pendingVideoPickResult else { return }
    pendingVideoPickResult = nil

    guard let itemProvider = results.first?.itemProvider,
          itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
      cb(nil)
      return
    }

    itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] srcUrl, _ in
      guard let self = self, let srcUrl = srcUrl else {
        DispatchQueue.main.async { cb(nil) }
        return
      }
      // Must copy synchronously before loadFileRepresentation returns and purges srcUrl
      let ext = srcUrl.pathExtension.isEmpty ? "mov" : srcUrl.pathExtension
      let stableUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TimeCamPro_Source_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).\(ext)")
      do {
        try FileManager.default.copyItem(at: srcUrl, to: stableUrl)
        try? FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.complete],
          ofItemAtPath: stableUrl.path
        )
      } catch {
        DispatchQueue.main.async { cb(nil) }
        return
      }

      let asset = AVURLAsset(url: stableUrl)
      let rawDuration = CMTimeGetSeconds(asset.duration)
      let durationSec = rawDuration.isFinite && rawDuration > 0 ? max(1.0, rawDuration) : 15.0
      let fileValues = try? stableUrl.resourceValues(forKeys: [.fileSizeKey])
      let sizeBytes = Double(fileValues?.fileSize ?? (25 * 1024 * 1024))
      let sizeMB = max(0.2, sizeBytes / (1024.0 * 1024.0))
      let suggestedName = (itemProvider.suggestedName ?? srcUrl.deletingPathExtension().lastPathComponent) + ".\(ext)"

      DispatchQueue.main.async {
        if let oldUrl = self.selectedVideoUrl, oldUrl != stableUrl {
          try? FileManager.default.removeItem(at: oldUrl)
        }
        self.selectedVideoUrl = stableUrl
        cb([
          "path": stableUrl.path,
          "sizeMB": sizeMB,
          "durationSeconds": durationSec,
          "fileName": suggestedName
        ])
      }
    }
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    picker.dismiss(animated: true) {
      LiveCameraManager.shared.resumeAfterModalPicker()
    }

    if let photoCb = pendingCameraResult {
      pendingCameraResult = nil
      if let image = info[.originalImage] as? UIImage {
        DispatchQueue.global(qos: .userInitiated).async {
          let jpeg = Self.normalizeImageUp(image).jpegData(compressionQuality: 0.88)
          DispatchQueue.main.async {
            photoCb(jpeg != nil ? FlutterStandardTypedData(bytes: jpeg!) : nil)
          }
        }
      } else {
        photoCb(nil)
      }
      return
    }

    guard let cb = pendingVideoPickResult else { return }
    pendingVideoPickResult = nil

    guard let mediaUrl = info[.mediaURL] as? URL else {
      cb(nil)
      return
    }

    let previousUrl = selectedVideoUrl
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let ext = mediaUrl.pathExtension.isEmpty ? "mov" : mediaUrl.pathExtension
      let stableUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TimeCamPro_Source_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).\(ext)")
      let workingUrl: URL
      if (try? FileManager.default.copyItem(at: mediaUrl, to: stableUrl)) != nil {
        try? FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.complete],
          ofItemAtPath: stableUrl.path
        )
        workingUrl = stableUrl
      } else {
        workingUrl = mediaUrl
      }

      let asset = AVURLAsset(url: workingUrl)
      let rawDuration = CMTimeGetSeconds(asset.duration)
      let durationSec = rawDuration.isFinite && rawDuration > 0 ? max(1.0, rawDuration) : 15.0
      let fileValues = try? workingUrl.resourceValues(forKeys: [.fileSizeKey])
      let sizeBytes = Double(fileValues?.fileSize ?? (25 * 1024 * 1024))
      let sizeMB = max(0.2, sizeBytes / (1024.0 * 1024.0))

      let finishPicker: (Bool) -> Void = { savedToPhotos in
        DispatchQueue.main.async {
          if let oldUrl = previousUrl, oldUrl != workingUrl {
            try? FileManager.default.removeItem(at: oldUrl)
          }
          self?.selectedVideoUrl = workingUrl
          cb([
            "path": workingUrl.path,
            "sizeMB": sizeMB,
            "durationSeconds": durationSec,
            "fileName": mediaUrl.lastPathComponent,
            "savedToPhotos": savedToPhotos
          ])
        }
      }

      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        if status == .authorized || status == .limited {
          PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: workingUrl)
          }) { saved, _ in
            finishPicker(saved)
          }
        } else {
          finishPicker(false)
        }
      }
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true) {
      LiveCameraManager.shared.resumeAfterModalPicker()
    }
    if let cb = pendingCameraResult {
      pendingCameraResult = nil
      cb(nil)
    }
    if let cb = pendingVideoPickResult {
      pendingVideoPickResult = nil
      cb(nil)
    }
  }

  // MARK: - 4. Hardware AVAssetReader + AVAssetWriter Bitrate Compression (with ExportSession Fallback)

  private func transcodeWithAssetWriter(
    asset: AVURLAsset,
    videoTrack: AVAssetTrack,
    audioTrack: AVAssetTrack?,
    timeRange: CMTimeRange,
    exportSec: Double,
    videoBps: Int,
    outW: Int,
    outH: Int,
    outUrl: URL
  ) -> Bool {
    do {
      let reader = try AVAssetReader(asset: asset)
      reader.timeRange = timeRange
      let writer = try AVAssetWriter(outputURL: outUrl, fileType: .mp4)
      writer.shouldOptimizeForNetworkUse = true

      let readerVideoOutput = AVAssetReaderTrackOutput(
        track: videoTrack,
        outputSettings: [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
      )
      readerVideoOutput.alwaysCopiesSampleData = false
      guard reader.canAdd(readerVideoOutput) else {
        return false
      }
      reader.add(readerVideoOutput)

      let writerVideoInput = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
          AVVideoCodecKey: AVVideoCodecType.h264,
          AVVideoWidthKey: outW,
          AVVideoHeightKey: outH,
          AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
          AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: videoBps
          ]
        ]
      )
      writerVideoInput.expectsMediaDataInRealTime = false
      writerVideoInput.transform = videoTrack.preferredTransform
      guard writer.canAdd(writerVideoInput) else {
        return false
      }
      writer.add(writerVideoInput)

      var readerAudioOutput: AVAssetReaderTrackOutput?
      var writerAudioInput: AVAssetWriterInput?
      if let aTrack = audioTrack {
        var stereoLayout = AudioChannelLayout()
        stereoLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        let stereoLayoutData = Data(bytes: &stereoLayout, count: MemoryLayout<AudioChannelLayout>.size)

        let rAudio = AVAssetReaderTrackOutput(
          track: aTrack,
          outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: stereoLayoutData,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
          ]
        )
        rAudio.alwaysCopiesSampleData = false
        let wAudio = AVAssetWriterInput(
          mediaType: .audio,
          outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: stereoLayoutData,
            AVEncoderBitRateKey: 96000
          ]
        )
        wAudio.expectsMediaDataInRealTime = false
        if reader.canAdd(rAudio) && writer.canAdd(wAudio) {
          reader.add(rAudio)
          writer.add(wAudio)
          readerAudioOutput = rAudio
          writerAudioInput = wAudio
        }
      }

      guard writer.startWriting() else {
        return false
      }
      guard reader.startReading() else {
        writer.cancelWriting()
        return false
      }
      writer.startSession(atSourceTime: timeRange.start)

      let group = DispatchGroup()
      let videoQueue = DispatchQueue(label: "com.beigou.timecampro.compress.video")
      let audioQueue = DispatchQueue(label: "com.beigou.timecampro.compress.audio")
      var lastProgressEmit = Date.distantPast

      group.enter()
      var videoFinished = false
      let finishVideo = {
        guard !videoFinished else { return }
        videoFinished = true
        writerVideoInput.markAsFinished()
        group.leave()
      }
      writerVideoInput.requestMediaDataWhenReady(on: videoQueue) {
        if writer.status == .failed || writer.status == .cancelled || reader.status == .failed || reader.status == .cancelled {
          finishVideo()
          return
        }
        while writerVideoInput.isReadyForMoreMediaData && !videoFinished {
          if writer.status == .failed || writer.status == .cancelled || reader.status == .failed || reader.status == .cancelled {
            finishVideo()
            break
          }
          if let sample = readerVideoOutput.copyNextSampleBuffer() {
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            let elapsed = CMTimeGetSeconds(CMTimeSubtract(pts, timeRange.start))
            if elapsed.isFinite && exportSec > 0 {
              let now = Date()
              if now.timeIntervalSince(lastProgressEmit) >= 0.12 {
                lastProgressEmit = now
                let pct = max(0.02, min(0.96, elapsed / exportSec))
                DispatchQueue.main.async {
                  self.methodChannel?.invokeMethod("onVideoCompressionProgress", arguments: pct)
                }
              }
            }
            if !writerVideoInput.append(sample) {
              finishVideo()
              break
            }
          } else {
            finishVideo()
            break
          }
        }
      }

      if let rAudio = readerAudioOutput, let wAudio = writerAudioInput {
        group.enter()
        var audioFinished = false
        let finishAudio = {
          guard !audioFinished else { return }
          audioFinished = true
          wAudio.markAsFinished()
          group.leave()
        }
        wAudio.requestMediaDataWhenReady(on: audioQueue) {
          if writer.status == .failed || writer.status == .cancelled || reader.status == .failed || reader.status == .cancelled {
            finishAudio()
            return
          }
          while wAudio.isReadyForMoreMediaData && !audioFinished {
            if writer.status == .failed || writer.status == .cancelled || reader.status == .failed || reader.status == .cancelled {
              finishAudio()
              break
            }
            if let sample = rAudio.copyNextSampleBuffer() {
              if !wAudio.append(sample) {
                finishAudio()
                break
              }
            } else {
              finishAudio()
              break
            }
          }
        }
      }

      group.wait()
      let finishSem = DispatchSemaphore(value: 0)
      writer.finishWriting {
        finishSem.signal()
      }
      finishSem.wait()
      return writer.status == .completed && FileManager.default.fileExists(atPath: outUrl.path)
    } catch {
      return false
    }
  }

  private func transcodeWithExportSession(
    asset: AVURLAsset,
    timeRange: CMTimeRange,
    videoBps: Int,
    outUrl: URL
  ) -> Bool {
    let preset: String
    if videoBps >= 1_500_000 {
      preset = AVAssetExportPreset1280x720
    } else if videoBps >= 700_000 {
      preset = AVAssetExportPreset960x540
    } else {
      preset = AVAssetExportPresetMediumQuality
    }
    guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
      return false
    }
    session.outputURL = outUrl
    session.outputFileType = .mp4
    session.timeRange = timeRange
    session.shouldOptimizeForNetworkUse = true

    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
    timer.schedule(deadline: .now() + 0.1, repeating: 0.15)
    timer.setEventHandler { [weak self, weak session] in
      guard let self = self, let s = session else { return }
      let pct = max(0.05, min(0.96, Double(s.progress)))
      DispatchQueue.main.async {
        self.methodChannel?.invokeMethod("onVideoCompressionProgress", arguments: pct)
      }
    }
    timer.resume()

    let sem = DispatchSemaphore(value: 0)
    session.exportAsynchronously {
      sem.signal()
    }
    sem.wait()
    timer.cancel()
    return session.status == .completed && FileManager.default.fileExists(atPath: outUrl.path)
  }

  private func handleCompressAndSave(
    startSeconds: Double,
    trimSeconds: Double,
    targetLimitMB: Double,
    result: @escaping FlutterResult
  ) {
    guard let srcUrl = selectedVideoUrl, FileManager.default.fileExists(atPath: srcUrl.path) else {
      result([
        "ok": false,
        "savedToPhotos": false,
        "errorCode": "NO_SOURCE_VIDEO"
      ])
      return
    }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      let asset = AVURLAsset(url: srcUrl)
      guard let videoTrack = asset.tracks(withMediaType: .video).first else {
        DispatchQueue.main.async {
          result(["ok": false, "savedToPhotos": false, "errorCode": "INVALID_VIDEO_TRACK"])
        }
        return
      }

      let rawTotal = CMTimeGetSeconds(asset.duration)
      let totalSec = rawTotal.isFinite && rawTotal > 0 ? max(1.0, rawTotal) : trimSeconds
      let safeStart = max(0.0, min(max(0.0, totalSec - 1.0), startSeconds))
      let maxAvailable = max(1.0, totalSec - safeStart)
      let exportSec = min(maxAvailable, max(1.0, trimSeconds))
      let safeLimitMB = max(1.0, targetLimitMB)

      let targetBytes = safeLimitMB * 0.90 * 1024.0 * 1024.0
      let audioTrack = asset.tracks(withMediaType: .audio).first
      let audioBitrate = audioTrack != nil ? 96_000.0 : 0.0
      let totalBps = (targetBytes * 8.0) / exportSec
      let videoBps = Int(max(420_000.0, min(12_000_000.0, totalBps - audioBitrate)))

      let natW = max(2.0, abs(videoTrack.naturalSize.width))
      let natH = max(2.0, abs(videoTrack.naturalSize.height))
      let maxLongEdge: CGFloat
      if videoBps >= 3_500_000 {
        maxLongEdge = 1920.0
      } else if videoBps >= 1_400_000 {
        maxLongEdge = 1280.0
      } else if videoBps >= 650_000 {
        maxLongEdge = 960.0
      } else {
        maxLongEdge = 640.0
      }
      let scale = min(1.0, maxLongEdge / max(natW, natH))
      let outW = max(2, Int(((natW * scale) / 2.0).rounded()) * 2)
      let outH = max(2, Int(((natH * scale) / 2.0).rounded()) * 2)

      let timeRange = CMTimeRange(
        start: CMTime(seconds: safeStart, preferredTimescale: 600),
        duration: CMTime(seconds: exportSec, preferredTimescale: 600)
      )

      let outUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TimeCamPro_Out_\(UUID().uuidString).mp4")
      try? FileManager.default.removeItem(at: outUrl)

      var transcodeOk = self.transcodeWithAssetWriter(
        asset: asset,
        videoTrack: videoTrack,
        audioTrack: audioTrack,
        timeRange: timeRange,
        exportSec: exportSec,
        videoBps: videoBps,
        outW: outW,
        outH: outH,
        outUrl: outUrl
      )
      if !transcodeOk {
        try? FileManager.default.removeItem(at: outUrl)
        transcodeOk = self.transcodeWithExportSession(
          asset: asset,
          timeRange: timeRange,
          videoBps: videoBps,
          outUrl: outUrl
        )
      }

      guard transcodeOk else {
        try? FileManager.default.removeItem(at: outUrl)
        DispatchQueue.main.async {
          result(["ok": false, "savedToPhotos": false, "errorCode": "TRANSCODE_FAILED"])
        }
        return
      }

      DispatchQueue.main.async {
        self.methodChannel?.invokeMethod("onVideoCompressionProgress", arguments: 1.0)
      }

      let vals = try? outUrl.resourceValues(forKeys: [.fileSizeKey])
      let outMB = max(0.1, Double(vals?.fileSize ?? 0) / (1024.0 * 1024.0))

      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        if status == .authorized || status == .limited {
          PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outUrl)
          }) { saved, saveErr in
            try? FileManager.default.removeItem(at: outUrl)
            DispatchQueue.main.async {
              result([
                "ok": saved,
                "savedToPhotos": saved,
                "outputMB": outMB,
                "startSeconds": safeStart,
                "durationSeconds": exportSec,
                "errorCode": saved ? NSNull() : "PHOTO_SAVE_FAILED",
                "errorDetail": (saveErr?.localizedDescription as Any?) ?? NSNull()
              ])
            }
          }
        } else {
          try? FileManager.default.removeItem(at: outUrl)
          DispatchQueue.main.async {
            result([
              "ok": false,
              "savedToPhotos": false,
              "outputMB": outMB,
              "startSeconds": safeStart,
              "durationSeconds": exportSec,
              "errorCode": "PHOTO_PERMISSION_DENIED"
            ])
          }
        }
      }
    }
  }

  // MARK: - 5. SFSafariViewController, Photo Save, StoreKit 2 & Security Storage

  private func handleOpenSafari(urlStr: String, result: @escaping FlutterResult) {
    guard let url = URL(string: urlStr),
          url.scheme?.lowercased() == "https",
          let presenter = topMostViewController() else {
      result(false)
      return
    }
    let safariVC = SFSafariViewController(url: url)
    safariVC.preferredControlTintColor = UIColor(red: 245/255, green: 183/255, blue: 59/255, alpha: 1.0)
    presenter.present(safariVC, animated: true)
    result(true)
  }

  private func handleSavePhotoBytes(
    data: Data,
    latitude: Double?,
    longitude: Double?,
    altitude: Double?,
    timestampMs: Double?,
    result: @escaping FlutterResult
  ) {
    guard let image = UIImage(data: data) else {
      result(false)
      return
    }
    let capturedDate: Date = (timestampMs != nil && timestampMs!.isFinite && timestampMs! > 0)
      ? Date(timeIntervalSince1970: timestampMs! / 1000.0)
      : Date()
    let validLocation: CLLocation?
    if let lat = latitude, let lng = longitude,
       lat.isFinite, lng.isFinite,
       !(abs(lat) < 0.0001 && abs(lng) < 0.0001),
       abs(lat) <= 90.0, abs(lng) <= 180.0 {
      let alt = (altitude != nil && altitude!.isFinite) ? altitude! : 0.0
      validLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
        altitude: alt,
        horizontalAccuracy: 10.0,
        verticalAccuracy: 10.0,
        timestamp: capturedDate
      )
    } else {
      validLocation = nil
    }

    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      if status == .authorized || status == .limited {
        PHPhotoLibrary.shared().performChanges({
          let req = PHAssetChangeRequest.creationRequestForAsset(from: image)
          req.creationDate = capturedDate
          if let loc = validLocation {
            req.location = loc
          }
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

  private func startStoreKitTransactionObserver() {
    guard storeKitUpdatesTask == nil else { return }
    if #available(iOS 15.0, *) {
      storeKitUpdatesTask = Task.detached { [weak self] in
        for await verification in StoreKit.Transaction.updates {
          if case .verified(let transaction) = verification {
            await transaction.finish()
          }
          guard let self = self else { continue }
          let activeIds = await self.collectActiveProductIds()
          await MainActor.run {
            self.methodChannel?.invokeMethod("onStoreKitEntitlementsChanged", arguments: activeIds)
          }
        }
      }
    }
  }

  @available(iOS 15.0, *)
  private func collectActiveProductIds() async -> [String] {
    var activeIds: [String] = []
    for await verification in StoreKit.Transaction.currentEntitlements {
      if case .verified(let transaction) = verification,
         transaction.revocationDate == nil,
         (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
        activeIds.append(transaction.productID)
      }
    }
    return activeIds
  }

  private func handleCheckActiveEntitlements(result: @escaping FlutterResult) {
    if #available(iOS 15.0, *) {
      Task {
        let activeIds = await self.collectActiveProductIds()
        DispatchQueue.main.async {
          result(activeIds)
        }
      }
    } else {
      result(nil)
    }
  }

  private func handleSyncStoreKitRestore(result: @escaping FlutterResult) {
    if #available(iOS 15.0, *) {
      Task {
        try? await AppStore.sync()
        let activeIds = await self.collectActiveProductIds()
        DispatchQueue.main.async {
          result(activeIds)
        }
      }
    } else {
      result([])
    }
  }

  private func handleFetchStoreKitProducts(productIds: [String], result: @escaping FlutterResult) {
    if #available(iOS 15.0, *) {
      Task {
        do {
          let products = try await StoreKit.Product.products(for: Set(productIds))
          let mapped: [[String: Any]] = products.map { p in
            let currency: String
            if #available(iOS 16.0, *) {
              currency = p.priceFormatStyle.currencyCode
            } else {
              currency = p.priceFormatStyle.locale.currencyCode ?? Locale.current.currencyCode ?? "USD"
            }
            return [
              "id": p.id,
              "displayPrice": p.displayPrice,
              "price": NSDecimalNumber(decimal: p.price).doubleValue,
              "displayName": p.displayName,
              "currencyCode": currency
            ]
          }
          DispatchQueue.main.async {
            result(mapped)
          }
        } catch {
          DispatchQueue.main.async {
            result([[String: Any]]())
          }
        }
      }
    } else {
      result([[String: Any]]())
    }
  }

  private func handlePurchaseStoreKitProduct(productId: String, result: @escaping FlutterResult) {
    if #available(iOS 15.0, *) {
      Task {
        do {
          let products = try await StoreKit.Product.products(for: [productId])
          guard let product = products.first else {
            DispatchQueue.main.async {
              result([
                "status": "error",
                "message": "App Store 尚未回傳此商品資訊 (\(productId))，請確認網路與 Sandbox 帳號設定。"
              ])
            }
            return
          }
          let purchaseResult = try await product.purchase()
          switch purchaseResult {
          case .success(let verification):
            switch verification {
            case .verified(let tx):
              await tx.finish()
              let activeIds = await self.collectActiveProductIds()
              DispatchQueue.main.async {
                self.methodChannel?.invokeMethod("onStoreKitEntitlementsChanged", arguments: activeIds)
                result([
                  "status": "purchased",
                  "productId": tx.productID
                ])
              }
            case .unverified(_, let verErr):
              DispatchQueue.main.async {
                result([
                  "status": "error",
                  "message": verErr.localizedDescription
                ])
              }
            }
          case .userCancelled:
            DispatchQueue.main.async {
              result(["status": "canceled"])
            }
          case .pending:
            DispatchQueue.main.async {
              result(["status": "pending"])
            }
          @unknown default:
            DispatchQueue.main.async {
              result(["status": "error", "message": "Unknown purchase state"])
            }
          }
        } catch {
          DispatchQueue.main.async {
            result([
              "status": "error",
              "message": error.localizedDescription
            ])
          }
        }
      }
    } else {
      result(["status": "error", "message": "Requires iOS 15.0 or newer"])
    }
  }

  // MARK: - Keychain Free-Quota Lock & FileProtection State Store

  private func loadKeychainQuota() -> Int {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainQuotaService,
      kSecAttrAccount as String: keychainQuotaAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess,
          let data = item as? Data,
          let str = String(data: data, encoding: .utf8),
          let val = Int(str) else {
      return 0
    }
    return max(0, val)
  }

  private func saveKeychainQuota(_ count: Int) -> Bool {
    let data = Data("\(max(0, count))".utf8)
    let baseQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainQuotaService,
      kSecAttrAccount as String: keychainQuotaAccount
    ]
    let updateAttrs: [String: Any] = [kSecValueData as String: data]
    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
    if updateStatus == errSecSuccess {
      return true
    }
    var addQuery = baseQuery
    addQuery[kSecValueData as String] = data
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
  }

  private func protectedStateFileUrl() -> URL? {
    guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }
    var dir = appSupport.appendingPathComponent("TimeCamPro", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    var dirRes = URLResourceValues()
    dirRes.isExcludedFromBackup = true
    try? dir.setResourceValues(dirRes)
    return dir.appendingPathComponent("timecam_state.json")
  }

  private func loadProtectedStateJson() -> String? {
    if let fileUrl = protectedStateFileUrl(),
       FileManager.default.fileExists(atPath: fileUrl.path),
       let json = try? String(contentsOf: fileUrl, encoding: .utf8),
       !json.isEmpty {
      return json
    }
    if let legacy = UserDefaults.standard.string(forKey: legacyPersistedStateKey), !legacy.isEmpty {
      _ = saveProtectedStateJson(legacy)
      UserDefaults.standard.removeObject(forKey: legacyPersistedStateKey)
      return legacy
    }
    return nil
  }

  private func saveProtectedStateJson(_ json: String) -> Bool {
    guard let fileUrl = protectedStateFileUrl() else { return false }
    do {
      try Data(json.utf8).write(to: fileUrl, options: [.atomic, .completeFileProtection])
      var mutableUrl = fileUrl
      var res = URLResourceValues()
      res.isExcludedFromBackup = true
      try? mutableUrl.setResourceValues(res)
      UserDefaults.standard.removeObject(forKey: legacyPersistedStateKey)
      return true
    } catch {
      return false
    }
  }

  private func handleOpenExternalUrl(urlStr: String, result: @escaping FlutterResult) {
    guard let url = URL(string: urlStr),
          let scheme = url.scheme?.lowercased(),
          (scheme == "mailto" || scheme == "https") else {
      result(false)
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { ok in
        result(ok)
      }
    }
  }

  private func handleRequestInAppReview(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      if let windowScene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        SKStoreReviewController.requestReview(in: windowScene)
        result(true)
      } else {
        result(false)
      }
    }
  }

  private func handleExportAndSharePdf(html: String, fileName: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let presenter = self.topMostViewController() else {
        result(false)
        return
      }
      let formatter = UIMarkupTextPrintFormatter(markupText: html)
      let renderer = UIPrintPageRenderer()
      renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

      let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
      let printableRect = pageRect.insetBy(dx: 32, dy: 36)
      renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
      renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

      let pdfData = NSMutableData()
      UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
      let pageCount = max(1, renderer.numberOfPages)
      for i in 0..<pageCount {
        UIGraphicsBeginPDFPage()
        renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
      }
      UIGraphicsEndPDFContext()

      let rawBase = (fileName as NSString).lastPathComponent
      let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
      let cleanedBase = String(rawBase.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
      let nonEmptyBase = cleanedBase.isEmpty ? "TimeCamPro_Report.pdf" : cleanedBase
      let safeName = nonEmptyBase.hasSuffix(".pdf") ? nonEmptyBase : "\(nonEmptyBase).pdf"
      let outUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(safeName)
      do {
        try (pdfData as Data).write(to: outUrl, options: [.atomic, .completeFileProtection])
      } catch {
        result(false)
        return
      }

      let activityVC = UIActivityViewController(activityItems: [outUrl], applicationActivities: nil)
      activityVC.completionWithItemsHandler = { _, _, _, _ in
        try? FileManager.default.removeItem(at: outUrl)
      }
      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
      }
      presenter.present(activityVC, animated: true)
      result(true)
    }
  }

  private func caseThumbsDirectory() -> URL? {
    guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return nil
    }
    var dir = docs.appendingPathComponent("case_thumbs", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    var res = URLResourceValues()
    res.isExcludedFromBackup = true
    try? dir.setResourceValues(res)
    return dir
  }

  private func writeProtectedThumbnail(image: UIImage, caseId: String) -> String? {
    guard let dir = caseThumbsDirectory(),
          let jpegData = Self.makeScaledJpeg(image: image, maxSide: 640.0, quality: 0.74) else {
      return nil
    }
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
    let safeId = String(caseId.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    let fileName = (safeId.isEmpty ? UUID().uuidString : safeId) + ".jpg"
    var destUrl = dir.appendingPathComponent(fileName)
    do {
      try jpegData.write(to: destUrl, options: [.atomic, .completeFileProtection])
      var res = URLResourceValues()
      res.isExcludedFromBackup = true
      try? destUrl.setResourceValues(res)
      return destUrl.path
    } catch {
      return nil
    }
  }

  private func handleShareImageBytes(data: Data, text: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let presenter = self.topMostViewController(),
            let image = UIImage(data: data) else {
        result(false)
        return
      }
      let outUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TimeCamPro_Evidence_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(4)).jpg")
      let cleanBytes = image.jpegData(compressionQuality: 0.90) ?? data
      let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      var wroteTempFile = false
      let activityItems: [Any]
      if (try? cleanBytes.write(to: outUrl, options: [.atomic, .completeFileProtection])) != nil {
        wroteTempFile = true
        activityItems = hasText ? [outUrl, text] : [outUrl]
      } else {
        activityItems = hasText ? [image, text] : [image]
      }
      let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
      activityVC.completionWithItemsHandler = { _, _, _, _ in
        if wroteTempFile {
          try? FileManager.default.removeItem(at: outUrl)
        }
      }
      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
      }
      presenter.present(activityVC, animated: true)
      result(true)
    }
  }

  private func handleSaveCaseThumbnail(data: Data, caseId: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .utility).async { [weak self] in
      guard let self = self, let image = UIImage(data: data) else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let path = self.writeProtectedThumbnail(image: Self.normalizeImageUp(image), caseId: caseId)
      DispatchQueue.main.async { result(path) }
    }
  }

  private func handleDeleteCaseThumbnail(path: String, result: @escaping FlutterResult) {
    guard let dir = caseThumbsDirectory() else {
      result(false)
      return
    }
    let dirPrefix = dir.standardizedFileURL.path + "/"
    let targetUrl = URL(fileURLWithPath: path).standardizedFileURL
    guard targetUrl.path.hasPrefix(dirPrefix),
          FileManager.default.fileExists(atPath: targetUrl.path) else {
      result(false)
      return
    }
    do {
      try FileManager.default.removeItem(at: targetUrl)
      result(true)
    } catch {
      result(false)
    }
  }

  private func handleOpenAppSettings(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let url = URL(string: UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(url) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { ok in
        result(ok)
      }
    }
  }

  // MARK: - 6. Vision OCR (with full EXIF orientation support)

  private static func cgImagePropertyOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch orientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }

  private static func recognizePlateSync(from image: UIImage) -> String? {
    guard let cgImage = image.cgImage else { return nil }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US"]

    let orientation = cgImagePropertyOrientation(for: image.imageOrientation)
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
    do {
      try handler.perform([request])
    } catch {
      return nil
    }

    let observations = request.results ?? []
    var candidates: [String] = []
    for obs in observations {
      for cand in obs.topCandidates(3) {
        candidates.append(cand.string)
      }
    }
    return extractTaiwanPlate(from: candidates)
  }

  private func handleRecognizePlate(imageData: Data, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let image = UIImage(data: imageData) else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let plate = Self.recognizePlateSync(from: image)
      DispatchQueue.main.async {
        result(plate)
      }
    }
  }

  private static func normalizeDigits(_ raw: String) -> String {
    return raw.replacingOccurrences(of: "O", with: "0")
      .replacingOccurrences(of: "Q", with: "0")
      .replacingOccurrences(of: "I", with: "1")
  }

  private static func extractTaiwanPlate(from rawStrings: [String]) -> String? {
    let cleanedList = rawStrings.map {
      $0.uppercased()
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "·", with: "-")
        .replacingOccurrences(of: "•", with: "-")
    }

    if let p1 = try? NSRegularExpression(pattern: "([A-Z]{3})-?([0-9OI]{4})") {
      for s in cleanedList {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        if let m = p1.firstMatch(in: s, range: range),
           let r1 = Range(m.range(at: 1), in: s),
           let r2 = Range(m.range(at: 2), in: s) {
          return "\(s[r1])-\(normalizeDigits(String(s[r2])))"
        }
      }
    }

    if let p2 = try? NSRegularExpression(pattern: "([A-Z]{2,3})-?([0-9OI]{3,4})") {
      for s in cleanedList {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        if let m = p2.firstMatch(in: s, range: range),
           let r1 = Range(m.range(at: 1), in: s),
           let r2 = Range(m.range(at: 2), in: s) {
          return "\(s[r1])-\(normalizeDigits(String(s[r2])))"
        }
      }
    }

    if let p3 = try? NSRegularExpression(pattern: "([0-9OI]{3,4})-?([A-Z]{2,3})") {
      for s in cleanedList {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        if let m = p3.firstMatch(in: s, range: range),
           let r1 = Range(m.range(at: 1), in: s),
           let r2 = Range(m.range(at: 2), in: s) {
          return "\(normalizeDigits(String(s[r1])))-\(s[r2])"
        }
      }
    }

    if let p4 = try? NSRegularExpression(pattern: "([A-Z0-9]{2,4})-([A-Z0-9]{2,4})") {
      for s in cleanedList {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        for m in p4.matches(in: s, range: range) {
          guard let rFull = Range(m.range(at: 0), in: s) else { continue }
          let candidate = String(s[rFull])
          let alnum = candidate.replacingOccurrences(of: "-", with: "")
          let letters = alnum.filter { $0.isLetter }.count
          let digits = alnum.filter { $0.isNumber }.count
          if alnum.count >= 5 && alnum.count <= 7 && letters >= 1 && digits >= 2 {
            return candidate
          }
        }
      }
    }
    return nil
  }

  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: "flutter", sessionRole: connectingSceneSession.role)
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }
}
