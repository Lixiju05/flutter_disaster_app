# 第一階段：居民 Firestore 健康回報／SOS 唯讀 API

## 版本與驗收界線

管理端基底為最新 `origin/main`：`7394b2a`。分支 `integration/firestore-health-sos-readonly-20261117`，工作樹為 `C:\Users\User\AppData\Local\Temp\hucares-firestore-reports-20261117`。未修改原工作區 main、正式 SQLite、Flutter UI、居民 App、IAM、Rules 或 ADC。未執行真實 Firebase 讀取或寫入，沒有 Commit／Push／Merge。

居民端 main 已向 GitHub 核對為 `3721b37`，並讀取以下實際程式：

- `flutter_ui/lib/models/health_report.dart`：toDetailJson() 寫 id、reporterId、name、area、status、description、lat、lng、UTC reportTime、sos、survey。
- `flutter_ui/lib/services/health_report_publisher.dart`：batch 寫入 health_reports/{uid} 與 health_report_sensitive/{uid}，前者為每 UID 最新狀態。
- `flutter_ui/lib/services/sos.dart`：SOS 是健康文件的布林標記，patch 不一定更換 id；沒有新 GPS 時可能保留舊座標，仍更新 reportTime。
- 最新 main 的 Flutter Android firebase_options.dart 指向 disaster-app-b2370，原生 app/google-services.json 指向 bitchat-android-disaster-app。先前 Enhancement/supply_items_BLE_Mesh 的 Flutter Android 設定則是後者。

**以上只核對程式與設定，不能證明實際 APK 的連線專案。** App 組須提供實際 APK commit、執行時 Firebase.app().options.projectId 與 Database／collection 確認。管理後端只讀取操作者明確設定的 Project，不猜測 APK 的實際初始化結果。

本次是「Firestore → 管理後端唯讀查詢」；不是 Firestore→SQLite 同步，不代表管理 UI 或跨手機端到端已驗收。mesh_reports、reporter_handles、Sensitive Tier 皆不在第一階段範圍。

## 啟用與授權

沿用既有 FirebaseConfig、ADC factory、GET-only FirestoreReadonlyReader、管理員 Bearer Session，以及 SQLite admins.id 存在性檢查。另有獨立回報允許清單，不因能查使用者就自動授予健康資料讀取權限。

| 設定 | 要求 |
|---|---|
| FIREBASE_ENABLED | true，預設 false |
| FIREBASE_PROJECT_ID | 明確指定已核准的測試專案，無預設 |
| FIREBASE_DATABASE_ID | (default) 或明確指定的 Database |
| FIREBASE_READ_ONLY | true，預設 true |
| NOTIFICATIONS_ENABLED | false，預設 false |
| FIREBASE_REPORTS_ENABLED | true 才啟用；預設 false，停用時不取得 ADC／連線 |
| FIREBASE_REPORTS_SCOPE | project，明確核准此專案的健康回報查詢範圍 |
| FIREBASE_REPORTS_ADMIN_IDS | 允許查詢的 SQLite 數字 admins.id，逗號分隔；不能填 username、Firebase UID 或 U001 |
| NOTIFICATION_FIREBASE_PROJECT | 可省略；若仍保留，依共用設定規則必須與 FIREBASE_PROJECT_ID 一致 |

FIREBASE_USERS_ENABLED 與其管理員清單不變，兩個唯讀服務可以同時啟用。兩者皆要求通知寫入停用。沒有提高 reader 權限或使用通知 writer；如果現有 reader 讀 health_reports 回 PERMISSION_DENIED，就停止驗收並回報，不自行調整 IAM。

每次查詢：驗證 Session → 檢查管理員仍存在 → 檢查回報允許清單 → GET Firestore → 再驗證 Session／帳號存在性 → 回傳。缺 Token／無效／過期為 401，未允許或帳號已刪除為 403。

## 兩支 POST API

POST 到既有 API 根路徑 `/`：

```http
Content-Type: application/json
Authorization: Bearer <login回傳的Token>
```

健康列表：

```json
{"type":"getFirebaseHealthReports","limit":25}
```

SOS 列表：

```json
{"type":"getFirebaseSosReports","limit":25}
```

後續頁：

```json
{"type":"getFirebaseSosReports","limit":25,"pageToken":"<上一頁nextPageToken>"}
```

只接受 type、limit、pageToken。limit 預設 25，必須是 1～100 整數；pageToken 是來源 opaque token，沒有下一頁時省略，不能傳 null／空字串，長度上限 8192。前端不能指定 Project、Database、Collection、管理員 ID、UID 或任意查詢條件。

範例回應（合成資料，不是雲端讀取證據）：

```json
{
  "success":true,
  "source":"firestore",
  "collection":"health_reports",
  "data":{
    "reports":[{
      "uid":"TEST_UID",
      "eventId":"00000000-0000-4000-8000-000000000001",
      "eventIdIsUuid":true,
      "reporterIdMatchesUid":true,
      "name":"測試回報者",
      "status":"未宣告",
      "description":null,
      "sos":true,
      "latitude":24.123456789,
      "longitude":121.987654321,
      "reportTime":"2026-11-17T00:00:00.000Z",
      "location":{
        "source":"app_reported",
        "precision":"unspecified",
        "freshness":"unknown",
        "capturedAt":null,
        "isRealtime":false
      },
      "dataQuality":[]
    }],
    "nextPageToken":null,
    "scannedCount":1,
    "semantics":"latest_per_uid",
    "pagination":"source_page",
    "sosOnly":true
  }
}
```

健康 API 的 sosOnly 為 false，包含安全、受傷、SOS 已解除及缺少欄位的最新狀態。SOS API **只取 sos 的 Firestore booleanValue 為 true**，不由 status、描述或字串 "true" 推定。未宣告不是安全；未知／缺少 sos 回 null，在健康列表保留但不納入 SOS 列表。

### 分頁與更新的重要語意

- 每次只對固定 health_reports collection GET 一個來源頁，依 `__name__ asc` 排序，不先下載整個集合，不執行 runQuery、commit 或 transaction。
- SOS 在讀完該頁後篩選，因此 reports 可以為空但 nextPageToken 仍非空。必須繼續翻頁，不能以筆數為零判定全部沒有 SOS。
- scannedCount 是此頁來源文件數，不是 SOS 總數。limit 是來源文件上限，不保證回傳這麼多 SOS。
- 不快取回報。相同 UID 再次讀取時可看到已更新的 id、status、sos；SOS 變 false 後不再出現在 SOS 列表。
- 這不是歷史事件表、不是跨頁一致快照。分頁期間文件可能更新，UI 需以 uid 去重、定期從第一頁刷新，不宣稱同一瞬間的準確全體總數。
- 同頁重複 UID、錯 Project／collection／不合法文件路徑會拒絕整頁，不自行猜測應採哪份。跨頁重複由 UI 以 UID 合併，不能無限追加。

## DTO、位置、敏感欄位

- uid 只由 `health_reports/{uid}` 文件路徑取得，永不等同 SQLite userId／自動流水號／admins.id。
- eventId 保留來源 id，不產生替代 UUID。缺少為 null；不是標準 UUID 時 eventIdIsUuid=false 並標記品質。來源 id 不是列表主鍵。
- reporterId 只用於檢查是否與路徑 UID 一致；只回 reporterIdMatchesUid，不外洩不相符的其他 UID，不依姓名／電話／Email 配對。這只是欄位一致性，不代表完成來源簽章驗證或證明已部署 Rules 正確。
- status 是居民身體狀況，非管理端 active／processing／resolved。sos 是居民求救標記，非管理員結案狀態。
- 原始有效 double 座標不四捨五入；缺少任一軸、超界、非有限值或 (0,0) sentinel，兩軸都回 null。沒有地址轉換，也不拿居住 area 補位置。
- reportTime 支援有時區 ISO 字串／Firestore Timestamp，正規化 UTC；缺少、非法日期或無時區回 null，不補現在時間。
- 居民 SOS 可能保留舊 GPS 或用 last-known fix，因此始終聲明位置精度／新鮮度未知、capturedAt=null、isRealtime=false。reportTime 不是 GPS 擷取時間。沒有混入或解碼 geohash。
- 欄位遮罩固定只取 id、reporterId、name、status、description、sos、lat、lng、reportTime；DTO 再做回傳白名單。電話、Email、血型、medicalInfo、聯絡人、survey、area 及整份原始文件都不回傳；不讀 health_report_sensitive。
- dataQuality 只回安全原因代碼，例如 coordinates_missing_or_invalid、report_time_missing_invalid_or_timezone_unknown、reporter_id_missing_or_mismatch、event_id_missing_or_not_uuid、status_missing_or_unrecognized、status_sos_inconsistent。不將異常狀態改成安全，也不以欄位不完整代表需求已被拒絕。

## 錯誤、效能及相容性

| HTTP | 代表情況 |
|---|---|
| 400 | INVALID_ARGUMENT、INVALID_PAGE_TOKEN |
| 401 | ADMIN_SESSION_REQUIRED |
| 403 | ADMIN_DISABLED、FIREBASE_REPORTS_FORBIDDEN |
| 429 | FIREBASE_REPORTS_BUSY，最多四個並行回報查詢 |
| 503 | FIREBASE_REPORTS_DISABLED、FIREBASE_REPORTS_SHUTTING_DOWN、Firestore 權限／API／網路／格式等失敗 |
| 504 | FIRESTORE_NETWORK_TIMEOUT；每個來源 GET timeout 10 秒，發出 abort 訊號，不自動重試 |

錯誤範例：

```json
{"success":false,"source":"firestore","code":"FIREBASE_REPORTS_DISABLED","message":"Firebase report queries are disabled or not configured"}
```

上游 PERMISSION_DENIED 以 HTTP 503＋FIRESTORE_PERMISSION_DENIED 回傳，與本地管理員 403 分開。沒有資料時回 success=true、reports=[]；發生錯誤不回假空資料、不 fallback SQLite。回應 Cache-Control: no-store，不在日誌記錄姓名、UID、Token、游標、描述或原始 Firestore 回應。

新路由使用既有 IsolatedRequestPool 的獨立四槽池，Firestore await 不會佔用原本逐筆 SQLite 路由迴圈；例外均接住，關閉時先 drain，再關閉 client／SQLite。SOS 寫入邏輯不變。這只隔離來源 Firestore 等待，不代表主 Server 的所有慢請求、HTTP body 讀取或舊通知路由都已隔離。

舊 getAllReports、getHealthReportsByAdmin、getEmergencyRequestsByAdmin、healthReport、addEmergencyRequest 及既有 SQLite Model／Schema／Seed 均未修改；新查詢只 SELECT 管理員存在性，不匯入或寫入 SQLite。

## 管理 UI 下一步

1. 建立獨立 FirestoreReport DTO／Repository，兩支 API 都帶現有登入 Bearer Token，不直接使用舊 SQLite HealthReport/EmergencyRequest Model。
2. 頁面明確選擇來源；不要把 SQLite Seed 與 Firestore 清單直接串接成一份人數，也不要用 getAllUsers 補猜 Firebase UID 對應。
3. 以 source＋uid 作列表識別；eventId 供來源事件辨識，不當歷史筆數或固定主鍵。時間可能 null，顯示未知。
4. 刷新時建立新的一輪結果集合，完成所有來源頁後再替換 SOS 清單，避免已解除的 SOS 永遠留在 UI。刷新失敗保留舊資料並標示過期／失敗，不當成 SOS 已消失。
5. 顯示原始 status、sos、dataQuality 與位置限制；未宣告不可套成安全，來源身分不一致需提示待確認。
6. **先不要把舊 markHandled／updateEmergencyStatus 接到這些 Firestore 資料。** 那些 API 只更新 SQLite，可能看似成功卻未改 Firestore。後續另設管理員處理進度，不能把居民 sos 或健康 status 覆寫成 resolved。

## 使用測試 Firebase 做人工唯讀驗收

本次未執行以下真實連線步驟。先請 App 組確認實際 APK 專案並提供去識別化文件格式；使用既有 reader 已核准可讀的測試環境。沒有 health_reports 權限就停止，不新增服務帳號、不提高 reader 權限、不改 Rules／ADC。

### 視窗一：獨立入口

沿用原本已成功的 reader ADC 環境，開新的 PowerShell，不使用通知 writer ADC、不執行 gcloud login 或列印任何憑證。只有以下入口可用於此次驗收，不能啟動正式 admin_server.dart。

```powershell
Set-Location 'C:\Users\User\AppData\Local\Temp\hucares-firestore-reports-20261117\admin_server'
$env:FIREBASE_ENABLED = 'true'
$env:FIREBASE_PROJECT_ID = Read-Host '已核准且reader可讀的測試Project ID'
$env:FIREBASE_DATABASE_ID = '(default)'
$env:FIREBASE_READ_ONLY = 'true'
$env:NOTIFICATIONS_ENABLED = 'false'
$env:FIREBASE_REPORTS_ENABLED = 'true'
$env:FIREBASE_REPORTS_SCOPE = 'project'
$env:FIREBASE_REPORTS_ADMIN_IDS = '1'
$env:FIREBASE_REPORTS_READONLY_TEST_SERVER = 'true'
$env:FIREBASE_REPORTS_TEST_PORT = '8084'
$secret = Read-Host '本次測試密碼，至少16字元' -AsSecureString
$buffer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try { $env:FIREBASE_REPORTS_TEST_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($buffer) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($buffer) }
try { dart run bin/firebase_reports_readonly_server.dart }
finally {
    Remove-Item Env:FIREBASE_REPORTS_TEST_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:FIREBASE_REPORTS_ENABLED -ErrorAction SilentlyContinue
}
```

預設監聽 127.0.0.1:8084，只建立記憶體 admins 表，不初始化 data/admin.db 或 Seed。測試帳號為 firebase_reports_test、數字 ID=1；只能登入及查新兩支路由。啟動輸出的 Project／Database 只是後端目標，不證明 APK 的目標。

### 視窗二：只顯示安全摘要

不啟用 Transcript，不輸出 $login、$token、$body 或完整回應。

```powershell
$apiUrl = 'http://127.0.0.1:8084/'
function Invoke-ReportCheck($Body, [string]$Token = '') {
    $headers = @{}
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    try {
        $reply = Invoke-WebRequest -UseBasicParsing -Uri $apiUrl -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ($Body | ConvertTo-Json -Depth 6) -TimeoutSec 30
        [pscustomobject]@{Http=[int]$reply.StatusCode;Json=($reply.Content | ConvertFrom-Json)}
    } catch {
        $status = if ($null -ne $_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        [pscustomobject]@{Http=$status;Json=$null}
    }
}
$secret = Read-Host '視窗一相同測試密碼' -AsSecureString
$buffer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
    $login = Invoke-ReportCheck @{type='login';username='firebase_reports_test';password=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($buffer)}
} finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($buffer) }
if ($login.Http -ne 200 -or $login.Json.success -ne $true) { throw '測試登入失敗' }
$token = $login.Json.token
Remove-Variable login
foreach ($type in @('getFirebaseHealthReports','getFirebaseSosReports')) {
    $result = Invoke-ReportCheck @{type=$type;limit=25} $token
    $count = $null
    $hasNext = $false
    if ($result.Http -eq 200 -and $result.Json.success -eq $true) {
        $count = @($result.Json.data.reports).Count
        $hasNext = [bool]$result.Json.data.nextPageToken
    }
    [pscustomobject]@{Type=$type;Http=$result.Http;Success=($result.Json.success -eq $true);Count=$count;HasNext=$hasNext}
}
```

後續頁在相同 endpoint 帶上一頁 nextPageToken，游標只保留在變數，不輸出。401 重新登入、403 本地權限不符、503/504 停止並核對安全錯誤碼；不要因錯誤回傳就改用舊 SQLite。

有測試文件時，請由 App 組在另行核准的測試環境送出／解除一筆 SOS，這個驗收工具仍只讀。重新從第一頁查詢：同 UID 應更新，sos=false 後應從完整 SOS 結果集合消失。只有 API 200 或空集合，不能證明讀到正確 APK 專案或完成居民→UI 串接。

在視窗一輸入 STOP，停止接收並等待已派發讀取結束後關閉 client 與記憶體資料庫；舊 Token 重啟失效。完成後關閉兩個獨立 PowerShell 視窗，不修改或撤銷原 reader ADC。

## 第二階段與 App 組確認清單

- 實際部署 APK commit、執行時 projectId、Database 與 collection；釐清 Flutter／原生 Firebase 初始化設定差異。
- id 的生命週期、同 UID 更新／撤回 SOS 範例、舊無時區時間的來源時區；不可推測或補造。
- GPS 的擷取時間、last-known fix 使用方式、精度與 age 欄位，能否由 App 另行提供；本階段一律標未知。
- 已部署 Rules／實際測試文件欄位、允許的管理員資料範圍；不要求提供 Token、私鑰或居民個資。
- 第二階段再規劃 mesh_reports、reporter_handles、安全驗簽、降精度位置、來源去重與匿名處理，本次沒有讀取或合併它們。
- 管理端處理進度與居民自身狀態的權責，以及 UI 人工切換到新 API 的驗收；本次只有後端。

## 離線驗證

新增 firebase_reports_reader_test.dart 與 firebase_reports_http_test.dart，注入 MockClient 並使用記憶體 SQLite；不讀取本機 ADC。涵蓋固定 GET／遮罩／目標、Session／允許清單、停用零連線、缺欄位／錯誤格式、UTC、GPS、防重與更新、來源分頁、SOS 解除、權限錯誤、安全日誌、舊 SQLite 相容、逾時／容量及關閉 drain。實際執行結果以此次回報為準，不把 Mock 當真實 Firestore 驗收。

本次實際執行：新增測試 **27 項**，完整後端 **231 項全部通過**；dart analyze exit 0，無 error／warning，只有既存的 admin_server 字串跳脫及 healthReport.dart 檔名兩個 info；git diff --check 與新增檔案 whitespace 檢查通過。沒有執行真實 Firebase API、Flutter 測試或居民手機端到端驗收。
