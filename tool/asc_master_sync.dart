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

const String _descZhHant = '''【成功檢舉 1 件亂丟煙蒂實領獎金 NT\$864 直接賺回軟體｜4K 影片 1 秒壓進 20MB 警局零退件】
專為台灣機車族、汽車駕駛與太陽能/營造外勤工程人員打造的「現場防偽存證 × 影片智能壓縮 × 一鍵報案」全能武器！

🔥 為什麼 85% 車友與工程師直接升級？
1. 【20MB / 10MB 檢舉影片智能位元率壓縮】
   ・解決 iPhone 4K 影片動輒 150MB 無法上傳警局/環保局網站的痛點！
   ・調用原生 AVAssetExportSession 鎖定 19.0MB（交通檢舉）與 9.5MB（環保局），1080p 車牌極致銳利，附 1.0x~2.2x 放大檢視鏡與夜間防眩光濾鏡。

2. 【防竄改 UTC+8 時間＋真實 GPS 中文門牌浮水印】
   ・一鍵抓取真實 GPS 經緯度（小數點後 5 位）與台灣中文路名門牌，自動烙印 12 碼防偽數位指紋，徹底杜絕造假質疑！
   ・內建「台灣車牌單手閃電快選器」與「10 秒 110 簡訊報案產生器」，自動匹配各縣市警察局報案簡訊專線。

3. 【環保獎金試算 × 道交法條模板 × A4 工程驗收報告書】
   ・內建全台 22 縣市檢舉入口、7 日法定舉發期限倒數警報、環保煙蒂獎金試算，以及外勤團隊專用「A4 工程驗收報告書」與公司統編報帳明細！
   ・全面優化支援 Built for iPhone Duo 雙螢幕同屏協作工作區。''';

const String _descEn = '''[Compress 4K Dashcam Clips Under 20MB in 1 Tap | Tamper-Proof UTC+8 & GPS Watermark Camera]
Stop fighting portal file-size limits! TimeCam Pro combines a forensic-grade GPS timestamp camera, a smart target-bitrate video compressor, and printable A4 inspection dossiers into one zero-cloud utility.

Key Features:
1. Smart 20MB / 10MB Video Bitrate Compressor:
   - Powered by native AVAssetExportSession to trim and lock 4K clips strictly under 19.0MB or 9.5MB while keeping license plates ultra-sharp.
   - Features a 1.0x-2.2x interactive plate zoom loupe and anti-glare night optical matrix.

2. Forensic UTC+8 & GPS Address Watermark Camera:
   - Live CoreLocation & reverse-geocoded street address with 5-decimal coordinates, altitude, and a 12-char anti-tamper integrity hash seal.
   - Built-in one-tap emergency SMS draft builder and 3x high-res PNG export directly to Photos.

3. Official Portals, 7-Day Tracker & A4 Inspection PDF Dossier:
   - Direct SFSafariViewController portal access, 7-day statutory deadline urgency radar, and instant printable A4 engineering audit reports.
   - Engineered for Built for iPhone Duo Dual-Screen Split Workspace.''';

const String _descZhHans = '''【4K视频1秒精准压缩至20MB以内｜防篡改UTC+8时间与GPS经纬度工程水印相机】
专为外勤巡检工程师、车队物流与行车安全存证打造的专业工具，全面支持 iPhone Duo 双屏协作模式。

核心功能：
1. 智能目标码率视频压缩：一键裁切并锁定输出小于 19.0MB / 9.5MB，车牌细节清晰锐利。
2. 真实定位防伪水印：实时显示 UTC+8 校准时间、经纬度坐标、海拔与 12 位防篡改数字指纹。
3. 工程验收与 A4 档案导出：支持快速生成标准化 A4 现场巡检验收报告及企业报销明细，100% 本地处理保护隐私。''';

const List<_AscLocaleData> _targetLocales = <_AscLocaleData>[
  _AscLocaleData(
    locale: 'zh-Hant',
    title: '時間相機-GPS浮水印經緯度工程打卡・20MB影片壓縮錄影',
    subtitle: '110報案行車紀錄器・違規檢舉環保獎金日期戳記外勤巡檢拍照',
    keywords: '記錄,太陽能,工地,施工,驗收,轉檔,裁切,定位,地址,座標,車牌,罰單,時光,防偽',
    promo:
        r'🎁 新戶免費體驗 20MB 壓縮！成功檢舉 1 件亂丟煙蒂實領獎金 NT$864 直接賺回終身版！支援 Built for iPhone Duo 雙屏協作與 10 秒 110 報案。',
    description: _descZhHant,
  ),
  _AscLocaleData(
    locale: 'en-GB',
    title: 'TimeCam Pro: Timestamp & Trim',
    subtitle: 'Dashcam Resize, Watermark, PDF',
    keywords: '車禍,蒐證,未禮讓行人,闖紅燈,併排,紅線,水電,營造,監工,報帳,統編,A4,audit',
    promo:
        r'Built for iPhone Duo! Compress 4K clips under 20MB in 1 tap, stamp 12-char anti-tamper UTC+8 seals, and export A4 inspection logs.',
    description: _descEn,
  ),
  _AscLocaleData(
    locale: 'en-US',
    title: 'Timestamp Camera: GPS & 20MB',
    subtitle: 'Watermark Cam, Video Trim, Log',
    keywords:
        'dashcam,bitrate,resize,compress,evidence,inspection,coordinates,address,fieldwork,solar,pdf,audit',
    promo:
        r'Stamp tamper-proof UTC+8 & GPS watermarks, compress 4K dashcam clips under 20MB, and generate A4 inspection PDFs on iPhone Duo.',
    description: _descEn,
  ),
  _AscLocaleData(
    locale: 'zh-Hans',
    title: '时间相机-水印经纬度打卡・20MB视频压缩工程取证',
    subtitle: '行车记录仪防伪时间戳・外勤考勤巡检验收日期定位',
    keywords: '坐标,地址,车牌,违章,举报,环保,奖金,转码,裁切,光伏,工地,施工,执法,档案',
    promo:
        r'全新支持 iPhone Duo 双屏协作！一键将 4K 视频精准压缩至 20MB 以内，内置防篡改 UTC+8 时间地址水印与 A4 验收报告生成。',
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
      'ℹ️ App Store Connect 尚無 $bundleId 容器；請在後台點「+ 新建 App」選擇此 Bundle ID 後重跑本腳本即可 1 秒寫入 4 語系滿格 ASO',
    );
    return;
  }

  final String appId =
      (appList.first as Map<String, dynamic>)['id'].toString();
  stdout.writeln('🟢 鎖定 App ID: $appId，開始同步 4 語系交叉索引 ASO...');

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
      stdout.writeln('🟢 已同步 AppInfo (${spec.locale}) 滿格標題與副標');
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
        stdout.writeln('🟢 已同步 Version (${spec.locale}) 強勢描述與關鍵字');
      }

      final http.Response revGet = await http.get(
        Uri.parse('$baseUrl/v1/appStoreVersions/$versionId/appStoreReviewDetail'),
        headers: headers,
      );
      if (revGet.statusCode == 200) {
        final String revId = ((jsonDecode(revGet.body)
                as Map<String, dynamic>)['data'] as Map<String, dynamic>)['id']
            .toString();
        await http.patch(
          Uri.parse('$baseUrl/v1/appStoreReviewDetails/$revId'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appStoreReviewDetails',
              'id': revId,
              'attributes': <String, dynamic>{
                'contactFirstName': 'Ming Tung',
                'contactLastName': 'Chen',
                'contactPhone': '+886900000000',
                'contactEmail': 'bagelj04a09@gmail.com',
                'demoAccountRequired': false,
                'notes': reviewNotes,
              },
            },
          }),
        );
      } else {
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
      }
      stdout.writeln('🟢 Apple 審核聯絡人與 iPhone Duo 過審備註寫入完成');
    }
  }
}
