import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

const String keyId = '853IQM8TC6VX';
const String issuerId = '7c8a4cba-398c-4e88-88bb-9252f72ecdc9';
const String bundleId = 'com.beigou.timecampro';
const String supportUrl = 'https://beigou0427.github.io/timecam_pro_app/';
const String privacyUrl =
    'https://beigou0427.github.io/timecam_pro_app/privacy.html';
const String baseUrl = 'https://api.appstoreconnect.apple.com';

const String titleZh = '時間相機 Pro - 違規蒐證與水印錄影';
const String subtitleZh = '110報案助手・檢舉影片自動壓縮';
const String keywordsZh =
    '時間戳記,工程相機,打卡,行車記錄器,定位,經緯度,車牌,環保檢舉,罰單,交通,轉檔,裁切,外勤,巡檢';
const String descZh = '''《時間相機 Pro - 違規蒐證與水印錄影》是專為台灣機車族、汽車駕駛與外勤工程人員打造的專業時間地點水印相機與檢舉影片容量壓縮工具。

【三大核心功能】
1. 即時原生感浮水印相機：
   ・強制校正台灣國家標準時間 (UTC+8)，精準至秒，防止時間遭質疑。
   ・即時顯示中文縣市、區、路名門牌號與小數點後 5 位 GPS 經緯度座標及海拔。
   ・內建「一鍵 110 簡訊報案產生器」，自動匹配各縣市警察局簡訊報案專線並帶入當前地址與座標。

2. 20MB / 10MB 檢舉影片智能位元率壓縮器：
   ・解決 iPhone 拍攝 4K 影片動輒 150MB 無法上傳警局或環保局網站之痛點。
   ・鎖定警政交通檢舉 19.0MB (安全低於 20MB 上限) 與環保局 9.5MB，自動反推最佳視訊位元率，保持 1080p 車牌極致銳利度。
   ・提供 1.0x ~ 2.2x 車牌局部放大檢視鏡與 10s / 15s / 30s 快速裁切。

3. 全台 22 縣市通報入口與道交法條模板庫：
   ・內建全台警察局交通違規檢舉與環保局亂丟煙蒂/垃圾獎金檢舉官方入口。
   ・提供常用道路交通管理處罰條例標準構成要件描述模板（一鍵複製貼上）與 7 日法定舉發期限倒數追蹤。''';

const String titleEn = 'TimeCam Pro: GPS Timestamp Cam';
const String subtitleEn = 'Video Compressor & Location';
const String keywordsEn =
    'watermark,dashcam,bitrate,resize,trim,evidence,inspection,coordinates,address,fieldwork,recorder';
const String descEn = '''TimeCam Pro is a professional timestamp watermark camera and target-bitrate video compressor designed for field inspection, dashcam documentation, and municipal traffic reporting.

Key Features:
1. Real-Time UTC+8 & GPS Address Watermark Camera:
   - Displays verified UTC+8 timestamp, street address, 5-decimal GPS coordinates, altitude, and custom license plate or project notes.
   - Built-in 110 Emergency SMS draft generator with automatic city police recipient matching.

2. Smart 20MB / 10MB Video Bitrate Compressor:
   - Automatically calculates optimal H.264 video bitrate to fit 4K clips strictly under 19.0MB (for 20MB portals) or 9.5MB (for 10MB portals) while preserving 1080p license plate sharpness.
   - Includes interactive license plate zoom loupe and 10s/15s/30s quick trim presets.

3. Official Portals Directory & 7-Day Statutory Vault:
   - Quick access to official traffic and environmental reporting portals, standard legal statement templates, and a 7-day deadline tracker.''';

const String reviewNotes =
    'This app features a real-time UTC+8 & GPS location watermark camera and a custom-bitrate video compression engine (locking output under 19.0MB/9.5MB for official reporting portals). For review convenience without needing external 4K dashcam files or physical travel, 5 preset GPS spots and 3 built-in 4K sample videos are pre-loaded in Tab 1 and Tab 2.';

String generateJwt() {
  final File keyFile = File('./AuthKey_$keyId.p8');
  final String pem = keyFile.readAsStringSync();
  final int now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
  final JWT jwt = JWT(
    <String, dynamic>{
      'iss': issuerId,
      'iat': now - 20,
      'exp': now + 1180,
      'aud': 'appstoreconnect-v1',
    },
    header: const <String, dynamic>{
      'alg': 'ES256',
      'kid': keyId,
      'typ': 'JWT',
    },
  );
  return jwt.sign(ECPrivateKey(pem), algorithm: JWTAlgorithm.ES256);
}

Future<void> ensureBundleIdRegistered(Map<String, String> headers) async {
  final http.Response checkRes = await http.get(
    Uri.parse('$baseUrl/v1/bundleIds?filter[identifier]=$bundleId'),
    headers: headers,
  );
  if (checkRes.statusCode == 200) {
    final List<dynamic> list =
        (jsonDecode(checkRes.body) as Map<String, dynamic>)['data']
            as List<dynamic>;
    if (list.isNotEmpty) {
      stdout.writeln('🟢 Apple Developer 已存在 Bundle ID: $bundleId');
      return;
    }
  }

  final http.Response createRes = await http.post(
    Uri.parse('$baseUrl/v1/bundleIds'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'bundleIds',
        'attributes': <String, dynamic>{
          'identifier': bundleId,
          'name': 'TimeCam Pro GPS Timestamp Cam',
          'platform': 'IOS',
        },
      },
    }),
  );
  if (createRes.statusCode == 201 || createRes.statusCode == 200) {
    stdout.writeln('🟢 已透過 API 免 2FA 自動向 Apple 註冊全新 Bundle ID: $bundleId！');
  } else {
    stdout.writeln('ℹ️ Bundle ID 註冊回應 (${createRes.statusCode}): ${createRes.body}');
  }
}

Future<void> main() async {
  final int zhBytes = utf8.encode(keywordsZh).length;
  final int enBytes = utf8.encode(keywordsEn).length;
  stdout.writeln(
    '📏 ASO 核驗：繁中關鍵字 $zhBytes/100 Bytes | 英文關鍵字 $enBytes/100 Bytes',
  );

  final File keyFile = File('./AuthKey_$keyId.p8');
  if (!keyFile.existsSync()) {
    stdout.writeln('⚠️ 未偵測到 AuthKey_$keyId.p8，跳過雲端連線。');
    return;
  }

  final Map<String, String> headers = <String, String>{
    'Authorization': 'Bearer ${generateJwt()}',
    'Content-Type': 'application/json',
  };

  await ensureBundleIdRegistered(headers);

  final http.Response appRes = await http.get(
    Uri.parse('$baseUrl/v1/apps?filter[bundleId]=$bundleId'),
    headers: headers,
  );
  if (appRes.statusCode != 200) return;

  final List<dynamic> appList =
      (jsonDecode(appRes.body) as Map<String, dynamic>)['data']
          as List<dynamic>;
  if (appList.isEmpty) {
    stdout.writeln(
      '✅ Bundle ID ($bundleId) 已在 Apple 開發者後台註冊就緒！當您在 App Store Connect 點擊「+ 新建 App」選擇此 Bundle ID 後，再次執行本腳本即可 1 秒填入所有雙語文案、18 項分級與審查備註！',
    );
    return;
  }

  final String appId =
      (appList.first as Map<String, dynamic>)['id'].toString();
  stdout.writeln('🟢 鎖定 App ID: $appId，開始同步全套 ASO 與合規設定...');

  final http.Response infoRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/appInfos'),
    headers: headers,
  );
  if (infoRes.statusCode == 200) {
    final List<dynamic> infos =
        (jsonDecode(infoRes.body) as Map<String, dynamic>)['data']
            as List<dynamic>;
    final String appInfoId =
        (infos.first as Map<String, dynamic>)['id'].toString();

    final http.Response locRes = await http.get(
      Uri.parse('$baseUrl/v1/appInfos/$appInfoId/appInfoLocalizations'),
      headers: headers,
    );
    if (locRes.statusCode == 200) {
      final List<dynamic> locs =
          (jsonDecode(locRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>;
      for (final dynamic item in locs) {
        final Map<String, dynamic> locMap = item as Map<String, dynamic>;
        final String locId = locMap['id'].toString();
        final String locale =
            (locMap['attributes'] as Map<String, dynamic>)['locale'].toString();
        final bool isZh = locale.startsWith('zh');
        await http.patch(
          Uri.parse('$baseUrl/v1/appInfoLocalizations/$locId'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appInfoLocalizations',
              'id': locId,
              'attributes': <String, dynamic>{
                'name': isZh ? titleZh : titleEn,
                'subtitle': isZh ? subtitleZh : subtitleEn,
                'privacyPolicyUrl': privacyUrl,
              },
            },
          }),
        );
      }
      stdout.writeln('🟢 雙語標題、副標題與隱私權網址同步完成');
    }

    final http.Response ageRes = await http.get(
      Uri.parse('$baseUrl/v1/appInfos/$appInfoId/ageRatingDeclaration'),
      headers: headers,
    );
    if (ageRes.statusCode == 200) {
      final Map<String, dynamic> ageData =
          (jsonDecode(ageRes.body) as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final String ageId = ageData['id'].toString();
      final Map<String, dynamic> curAttrs =
          ageData['attributes'] as Map<String, dynamic>;
      final Map<String, dynamic> nextAttrs = <String, dynamic>{};
      for (final MapEntry<String, dynamic> e in curAttrs.entries) {
        if (e.key.contains('Override') ||
            e.key.contains('Url') ||
            e.key == 'kidsAgeBand') {
          continue;
        }
        if (e.value is bool) {
          nextAttrs[e.key] = false;
        } else if (e.value is String) {
          nextAttrs[e.key] = 'NONE';
        }
      }
      await http.patch(
        Uri.parse('$baseUrl/v1/ageRatingDeclarations/$ageId'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'ageRatingDeclarations',
            'id': ageId,
            'attributes': nextAttrs,
          },
        }),
      );
      stdout.writeln('🟢 18 項年齡分級問卷 (4+) 自動填寫完成');
    }
  }

  final http.Response verRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/appStoreVersions'),
    headers: headers,
  );
  if (verRes.statusCode == 200) {
    final List<dynamic> vers =
        (jsonDecode(verRes.body) as Map<String, dynamic>)['data']
            as List<dynamic>;
    if (vers.isNotEmpty) {
      final String versionId =
          (vers.first as Map<String, dynamic>)['id'].toString();
      await http.patch(
        Uri.parse('$baseUrl/v1/appStoreVersions/$versionId'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appStoreVersions',
            'id': versionId,
            'attributes': <String, dynamic>{
              'copyright': '© 2026 Ming Tung Chen',
            },
          },
        }),
      );

      final http.Response vLocRes = await http.get(
        Uri.parse(
          '$baseUrl/v1/appStoreVersions/$versionId/appStoreVersionLocalizations',
        ),
        headers: headers,
      );
      if (vLocRes.statusCode == 200) {
        final List<dynamic> vLocs =
            (jsonDecode(vLocRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>;
        for (final dynamic item in vLocs) {
          final Map<String, dynamic> locMap = item as Map<String, dynamic>;
          final String locId = locMap['id'].toString();
          final String locale =
              (locMap['attributes'] as Map<String, dynamic>)['locale']
                  .toString();
          final bool isZh = locale.startsWith('zh');
          await http.patch(
            Uri.parse('$baseUrl/v1/appStoreVersionLocalizations/$locId'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'type': 'appStoreVersionLocalizations',
                'id': locId,
                'attributes': <String, dynamic>{
                  'description': isZh ? descZh : descEn,
                  'keywords': isZh ? keywordsZh : keywordsEn,
                  'supportUrl': supportUrl,
                },
              },
            }),
          );
        }
        stdout.writeln('🟢 版本雙語描述、100B 關鍵字與支援網址同步完成');
      }

      await http.post(
        Uri.parse('$baseUrl/v1/appStoreReviewDetails'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appStoreReviewDetails',
            'attributes': <String, dynamic>{
              'contactFirstName': 'Ming Tung',
              'contactLastName': 'Chen',
              'contactPhone': '+886900000000',
              'contactEmail': 'bagelj04a09@gmail.com',
              'demoAccountRequired': false,
              'notes': reviewNotes,
            },
            'relationships': <String, dynamic>{
              'appStoreVersion': <String, dynamic>{
                'data': <String, dynamic>{
                  'type': 'appStoreVersions',
                  'id': versionId,
                },
              },
            },
          },
        }),
      );
      stdout.writeln('🟢 Apple 審核聯絡人與 Guideline 4.2 過審備註寫入完成');
    }
  }
}
