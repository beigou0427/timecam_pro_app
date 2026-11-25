import AVFoundation
import CoreMediaIO
import Foundation

final class ScreenRecorderDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    var didFinish = false
    var finishError: Error?

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        finishError = error
        didFinish = true
        CFRunLoopStop(CFRunLoopGetMain())
    }
}

func enableCoreMediaIOScreenCaptureDevices() {
    var prop = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
    var allow: UInt32 = 1
    let size = UInt32(MemoryLayout<UInt32>.size)
    let status = CMIOObjectSetPropertyData(
        CMIOObjectID(kCMIOObjectSystemObject),
        &prop,
        0,
        nil,
        size,
        &allow
    )
    if status != noErr {
        fputs("⚠️ CoreMediaIO 啟用提示 (status=\(status))，繼續偵測裝置...\n", stderr)
    }
}

func findConnectedIosCaptureDevice(timeoutSeconds: Double = 3.0) -> AVCaptureDevice? {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: nil,
            position: .unspecified
        )
        let candidates = session.devices.filter { dev in
            dev.hasMediaType(.muxed) || dev.hasMediaType(.video)
        }
        if let iphone = candidates.first(where: {
            let name = $0.localizedName.lowercased()
            return name.contains("iphone") || name.contains("ipad")
        }) {
            return iphone
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
    return nil
}

struct CuePrompt {
    let atSecond: Int
    let text: String
    let voice: String
}

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "build/review_recording/review_raw_45s.mov"
let durationSeconds = args.count > 2 ? max(10, Int(args[2]) ?? 45) : 45
let speakCues = !args.contains("--mute")

enableCoreMediaIOScreenCaptureDevices()
print("🔍 正在偵測 USB 連接的 iPhone 畫面裝置...")
fflush(stdout)

guard let device = findConnectedIosCaptureDevice(timeoutSeconds: 3.5) else {
    fputs("""
    ❌ 找不到 iPhone USB 螢幕擷取裝置！
    請確認以下 3 件事：
      1. iPhone 已用傳輸線接上這台 Mac，且螢幕已「解鎖」。
      2. iPhone 若跳出「要信任這部電腦嗎？」，請點「信任」。
      3. 若剛插上線，請重插一次線或先打開 QuickTime Player 確認看得到 iPhone 螢幕。
    替代方案：直接用 iPhone 控制中心內建「螢幕錄影」錄 45 秒 AirDrop 到 Mac，再跑：
      ./scripts/record_review_45s.sh --convert /你的影片路徑/RPReplay.mov
    \n
    """, stderr)
    exit(2)
}

print("✅ 已鎖定實機畫面來源：\(device.localizedName)")

let session = AVCaptureSession()
session.beginConfiguration()
if session.canSetSessionPreset(.high) {
    session.sessionPreset = .high
}

do {
    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
        fputs("❌ 無法加入 iPhone 影像輸入源。\n", stderr)
        exit(3)
    }
    session.addInput(input)
} catch {
    fputs("❌ 建立 iPhone 擷取輸入失敗：\(error.localizedDescription)\n", stderr)
    exit(3)
}

let movieOutput = AVCaptureMovieFileOutput()
guard session.canAddOutput(movieOutput) else {
    fputs("❌ 無法加入影片輸出管線。\n", stderr)
    exit(3)
}
session.addOutput(movieOutput)
session.commitConfiguration()

let outURL = URL(fileURLWithPath: outPath)
try? FileManager.default.createDirectory(
    at: outURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try? FileManager.default.removeItem(at: outURL)

let delegate = ScreenRecorderDelegate()
session.startRunning()
// Give the muxed iOS stream ~0.8s to stabilize keyframes before starting file recording
RunLoop.current.run(until: Date().addingTimeInterval(0.8))

print("\n🎬 開始錄製 \(durationSeconds) 秒 Apple 2.1 審核操作影片！請照下方提示依序點擊：")
print("────────────────────────────────────────────────────────────")
fflush(stdout)

let cues: [CuePrompt] = [
    CuePrompt(
        atSecond: 0,
        text: "[00-06s] ① 桌面冷啟動「時間相機 Pro」（若出現 3 秒場景選擇點任一項進入）",
        voice: "第一步，桌面打開時間相機"
    ),
    CuePrompt(
        atSecond: 6,
        text: "[06-16s] ② 移動實機鏡頭對準實物，點左上角「同步定位」展示即時 GPS 門牌與跳秒",
        voice: "第二步，移動鏡頭並點同步定位"
    ),
    CuePrompt(
        atSecond: 16,
        text: "[16-23s] ③ 按中央白色快門拍存浮水印照，順手點一下右上「?」快速上手後關閉",
        voice: "第三步，按快門拍照並打開問號說明"
    ),
    CuePrompt(
        atSecond: 23,
        text: "[23-34s] ④ 切到「20MB壓縮」壓縮匯出 → 跳轉「案件與通報」點「匯出 A4 PDF」展示分享表單",
        voice: "第四步，壓縮影片並匯出PDF"
    ),
    CuePrompt(
        atSecond: 34,
        text: "[34-45s] ⑤ 點右上「Pro」展示 StoreKit 真實價格，點購買叫出 Apple 確認框（取消即可）或點「恢復購買」",
        voice: "第五步，打開升級頁並點擊購買確認"
    )
]

func triggerSpeech(_ phrase: String) {
    guard speakCues else { return }
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    proc.arguments = ["-r", "210", phrase]
    try? proc.run()
}

var stopRequested = false
signal(SIGINT, SIG_IGN)
let sigSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigSrc.setEventHandler {
    if !stopRequested {
        stopRequested = true
        print("\n⏹️ 收到中斷指令，正在收尾儲存影片...")
        movieOutput.stopRecording()
    }
}
sigSrc.resume()

movieOutput.startRecording(to: outURL, recordingDelegate: delegate)

var cueTimers: [Timer] = []
for cue in cues where cue.atSecond < durationSeconds {
    let t = Timer.scheduledTimer(withTimeInterval: TimeInterval(cue.atSecond), repeats: false) { _ in
        print(cue.text)
        fflush(stdout)
        triggerSpeech(cue.voice)
    }
    cueTimers.append(t)
}

let stopTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(durationSeconds), repeats: false) { _ in
    if !stopRequested {
        stopRequested = true
        print("────────────────────────────────────────────────────────────")
        print("⏹️ \(durationSeconds) 秒錄影結束，正在寫入檔案...")
        fflush(stdout)
        movieOutput.stopRecording()
    }
}

while !delegate.didFinish {
    CFRunLoopRunInMode(.defaultMode, 0.2, false)
}

stopTimer.invalidate()
cueTimers.forEach { $0.invalidate() }
session.stopRunning()

if let err = delegate.finishError {
    // AVErrorRecordingSuccessfullyFinished can be present in userInfo even when error != nil on macOS
    let nsErr = err as NSError
    let finishedOk = (nsErr.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? false
    if !finishedOk {
        fputs("❌ 錄影儲存失敗：\(err.localizedDescription)\n", stderr)
        exit(4)
    }
}

print("✅ 原始畫面已儲存：\(outPath)")
