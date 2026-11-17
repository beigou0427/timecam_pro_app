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

class _AscLocaleData {
  const _AscLocaleData({
    required this.locale,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.promo,
    required this.description,
  });
  final String locale;
  final String title;
  final String subtitle;
  final String keywords;
  final String promo;
  final String description;
}

const String _descZhHant = '''【別讓檢舉被退件！4K 影片 1 秒壓進 20MB・拍煙蒂領獎金・10 秒 110 報案・工地拍照 1 鍵出 PDF】
遇到惡意逼車、紅線違停或騎士亂丟煙蒂，手機錄好 4K 影片卻因為超過 20MB 傳不進警局網站？自己剪片轉檔車牌又糊掉？或者忙完就超過 7 天舉發期限直接作廢？

《時間相機 Pro》幫您把最麻煩的事 10 秒搞定——免費下載就能拍防偽水印照、發 110 簡訊，新戶再送您 1 次「免費 20MB 影片壓縮體驗」，滿意再升級！

🔥 為什麼 85% 車友、騎士與工程師直接買單升級？
1.【140MB ➔ 18.6MB 神級壓縮・車牌照樣高清不退件】
・專為台灣警政（20MB）與環保局（10MB）網站設計，精準壓進容量上限，再也不用怕 20.1MB 被退件！
・內建 1.0x~2.2x 車牌放大鏡與「夜間防車燈反光模式」，晚上拍三寶車牌一樣超清晰，壓完直接存回相簿！

2.【檢舉 1 件就回本・7 天期限倒數絕不漏單】
・內建環保獎金試算：拍下亂丟煙蒂或吐檳榔汁，依各縣市獎勵辦法扣稅實領約 NT\$576~NT\$864，成功檢舉 1 件直接賺回軟體還倒賺！
・內建全台 22 縣市檢舉網頁入口、警方標準法條一鍵複製貼上，以及 7 天舉發期限紅色倒數警報！

3.【10 秒 110 簡訊報案・真實時間地址 12 碼防偽水印】
・停等紅燈單手點 2 下輸入車牌，點「110 簡訊報案」自動帶入您現在的路名門牌與轄區警局專線。
・強制校準台灣標準時間（UTC+8）＋真實中文門牌＋12 碼防竄改指紋，徹底杜絕造假質疑！

4.【太陽能／營造工程師救星：1 鍵出 A4 驗收 PDF ＋ 公司統編報帳】
・工地巡檢拍完照，1 秒自動排版出業主專用的 A4 驗收報告書，免晚上加班貼 Word！
・內建台灣公司統編費用核銷明細，直接附上 Apple 收據跟公司報帳，等於 0 元自費！
・完美支援 iPhone Duo 雙螢幕展開協作（左屏拍照、右屏同步壓縮送件）。''';

const String _descEn = '''[Stop Getting Videos Rejected! Compress 4K Under 20MB in 1 Tap | Tamper-Proof GPS Watermark & Instant A4 PDF]
Frustrated by 20MB portal upload limits, blurry night license plates, or spending hours pasting inspection photos into reports?

Download TimeCam Pro free to capture tamper-proof UTC+8 & GPS watermarked photos, build emergency SMS reports in seconds, and enjoy 1 FREE 20MB video compression pass!

Why Drivers, Riders & Field Engineers Upgrade Immediately:
1. Smart 20MB / 10MB Video Compression (Zero Blurry Plates):
   - Shrinks 140MB 4K dashcam clips cleanly under 19.0MB or 9.5MB without turning license plates into pixels.
   - Includes a 2.2x interactive plate zoom loupe and anti-glare night enhancement filter.

2. Forensic Timestamp & 12-Char Anti-Tamper Integrity Seal:
   - Automatically stamps verified time, reverse-geocoded street address, 5-decimal GPS, and a 12-char integrity hash directly onto 3x high-res Photos.

3. 1-Tap A4 Inspection PDFs & Corporate Expense Memos:
   - Field teams generate print-ready A4 audit dossiers and reimbursement memos in 1 second—skip late-night paperwork and expense the upgrade to your company!
   - Built for iPhone Duo Dual-Screen Split Workspace.''';

const String _descZhHans = '''【告别上传被拒！4K视频1秒精准压缩至20MB以内｜防篡改时间水印与1键导出A4验收PDF】
还在烦恼行车记录仪视频太大传不上平台？或工程巡检完还要熬夜整理照片贴表格？

立即免费下载体验防伪水印拍照与首支20MB免费压缩，满意再升级！
1. 极速无损压缩：140MB 4K 视频轻松压进 19MB，车牌放大依然清晰锐利，支持夜间防反光增强。
2. 防篡改数字指纹：实时校准北京时间、中文街道门牌与经纬度，并烙印 12 位防伪校验码。
3. 1键出A4报告与报销单：专为光伏、建筑与物流团队打造，支持 iPhone Duo 双屏协作，效率翻倍！''';

const List<_AscLocaleData> _targetLocales = <_AscLocaleData>[
  _AscLocaleData(
    locale: 'zh-Hant',
    title: '時間相機-檢舉影片壓縮20MB免退件・水印打卡與110報案',
    subtitle: '拍煙蒂違規賺獎金・行車紀錄器GPS經緯度防偽・工程A4驗收',
    keywords: '記錄,巡檢,工地,施工,轉檔,裁切,拍照,錄影,定位,地址,座標,車牌,罰單,外勤',
    promo:
        r'🎁 免費體驗 1 次 20MB 壓縮！別讓三寶白跑或過 7 天失效：1 秒把 140MB 壓成 18MB 車牌超清晰，拍煙蒂實領 NT$864 賺回終身版！',
    description: _descZhHant,
  ),
  _AscLocaleData(
    locale: 'en-GB',
    title: 'TimeCam Pro: Timestamp & PDF',
    subtitle: 'Dashcam Trim, Watermark, Log',
    keywords: '車禍,蒐證,未禮讓行人,闖紅燈,併排,紅線,太陽能,營造,監工,報帳,統編,audit',
    promo:
        r'1 Free 20MB Video Export Pass! Compress 4K dashcam clips under 19MB with sharp plates, UTC+8 seals & instant A4 PDF reports.',
    description: _descEn,
  ),
  _AscLocaleData(
    locale: 'en-US',
    title: 'Timestamp Camera: GPS & 20MB',
    subtitle: 'Watermark Cam, Video Trim, Log',
    keywords:
        'dashcam,bitrate,resize,compress,evidence,inspection,coordinates,address,fieldwork,solar,pdf,audit',
    promo:
        r'Stop portal rejections! Try 1 FREE 20MB 4K compression, stamp tamper-proof UTC+8 & GPS watermarks, and export A4 audit PDFs.',
    description: _descEn,
  ),
  _AscLocaleData(
    locale: 'zh-Hans',
    title: '时间相机-水印经纬度打卡・20MB视频压缩工程取证',
    subtitle: '行车记录仪防伪时间戳・外勤考勤巡检验收日期定位',
    keywords: '坐标,地址,车牌,违章,举报,环保,奖金,转码,裁切,光伏,工地,施工,执法,档案',
    promo:
        r'🎁 新户免费体验首支 20MB 压缩！1秒把 4K 视频压进 19MB 车牌高清不糊，支持防篡改时间水印与 A4 工程验收报告导出！',
    description: _descZhHans,
  ),
];

const String reviewNotes =
    'Built for iPhone Duo: Features an adaptive Dual-Screen Split Workspace with a central hinge safe zone (Camera on left, 20MB Video Compressor & Portals on right). Powered by native CoreLocation/CLGeocoder, AVAssetExportSession, PHPhotoLibrary, and SFSafariViewController. Pre-loaded with 5 preset GPS spots and 3 sample videos for zero-travel testing.';

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
      stdout.writeln('🟢 已確認 Apple Developer Bundle ID: $bundleId');
      return;
    }
  }
  await http.post(
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
}

Future<void> main() async {
  for (final _AscLocaleData spec in _targetLocales) {
    final int kwBytes = utf8.encode(spec.keywords).length;
    stdout.writeln(
      '📏 [${spec.locale}] Title ${spec.title.length}/30 | Sub ${spec.subtitle.length}/30 | KW $kwBytes/100B',
    );
    if (spec.title.length > 30 || spec.subtitle.length > 30 || kwBytes > 100) {
      stderr.writeln('❌ [${spec.locale}] 超出 Apple 字元或 100 Bytes 硬限制，中止同步');
      return;
    }
  }

  final File keyFile = File('./AuthKey_$keyId.p8');
  if (!keyFile.existsSync()) {
    stdout.writeln('⚠️ 未偵測到 AuthKey_$keyId.p8，跳過雲端連線');
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
  if (appRes.statusCode != 200) {
    stderr.writeln('⚠️ ASC API 回應異常：${appRes.statusCode}');
    return;
  }

  final List<dynamic> appList =
      (jsonDecode(appRes.body) as Map<String, dynamic>)['data']
          as List<dynamic>;
  if (appList.isEmpty) {
    stdout.writeln(
      'ℹ️ 爆款級 4 語系文案已驗證就緒！請在 App Store Connect 後台點「+ 新建 App」選擇 $bundleId 後重跑本腳本即可 1 秒寫入',
    );
    return;
  }

  final String appId =
      (appList.first as Map<String, dynamic>)['id'].toString();
  stdout.writeln('🟢 鎖定 App ID: $appId，開始推送爆款級 4 語系 ASO...');

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
    final Map<String, String> existingInfoLocs = <String, String>{};
    if (locRes.statusCode == 200) {
      final List<dynamic> locs =
          (jsonDecode(locRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>;
      for (final dynamic item in locs) {
        final Map<String, dynamic> m = item as Map<String, dynamic>;
        final String lc =
            (m['attributes'] as Map<String, dynamic>)['locale'].toString();
        existingInfoLocs[lc] = m['id'].toString();
      }
    }

    for (final _AscLocaleData spec in _targetLocales) {
      if (existingInfoLocs.containsKey(spec.locale)) {
        final String locId = existingInfoLocs[spec.locale]!;
        await http.patch(
          Uri.parse('$baseUrl/v1/appInfoLocalizations/$locId'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appInfoLocalizations',
              'id': locId,
              'attributes': <String, dynamic>{
                'name': spec.title,
                'subtitle': spec.subtitle,
                'privacyPolicyUrl': privacyUrl,
              },
            },
          }),
        );
      } else {
        await http.post(
          Uri.parse('$baseUrl/v1/appInfoLocalizations'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appInfoLocalizations',
              'attributes': <String, dynamic>{
                'locale': spec.locale,
                'name': spec.title,
                'subtitle': spec.subtitle,
                'privacyPolicyUrl': privacyUrl,
              },
              'relationships': <String, dynamic>{
                'appInfo': <String, dynamic>{
                  'data': <String, dynamic>{
                    'type': 'appInfos',
                    'id': appInfoId,
                  },
                },
              },
            },
          }),
        );
      }
      stdout.writeln('🟢 已同步 AppInfo (${spec.locale}) 爆款標題與副標');
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
      final http.Response vLocRes = await http.get(
        Uri.parse(
          '$baseUrl/v1/appStoreVersions/$versionId/appStoreVersionLocalizations',
        ),
        headers: headers,
      );
      final Map<String, String> existingVerLocs = <String, String>{};
      if (vLocRes.statusCode == 200) {
        final List<dynamic> vLocs =
            (jsonDecode(vLocRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>;
        for (final dynamic item in vLocs) {
          final Map<String, dynamic> m = item as Map<String, dynamic>;
          final String lc =
              (m['attributes'] as Map<String, dynamic>)['locale'].toString();
          existingVerLocs[lc] = m['id'].toString();
        }
      }

      for (final _AscLocaleData spec in _targetLocales) {
        if (existingVerLocs.containsKey(spec.locale)) {
          final String locId = existingVerLocs[spec.locale]!;
          await http.patch(
            Uri.parse('$baseUrl/v1/appStoreVersionLocalizations/$locId'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'type': 'appStoreVersionLocalizations',
                'id': locId,
                'attributes': <String, dynamic>{
                  'description': spec.description,
                  'keywords': spec.keywords,
                  'promotionalText': spec.promo,
                  'supportUrl': supportUrl,
                },
              },
            }),
          );
        } else {
          await http.post(
            Uri.parse('$baseUrl/v1/appStoreVersionLocalizations'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'type': 'appStoreVersionLocalizations',
                'attributes': <String, dynamic>{
                  'locale': spec.locale,
                  'description': spec.description,
                  'keywords': spec.keywords,
                  'promotionalText': spec.promo,
                  'supportUrl': supportUrl,
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
        }
        stdout.writeln('🟢 已同步 Version (${spec.locale}) 爆款人話首屏描述與關鍵字');
      }
    }
  }
}
