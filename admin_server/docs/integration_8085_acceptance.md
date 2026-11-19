# 8085 完整管理端隔離驗收

此入口 **尚未由 Codex 啟動真實服務或查詢 Firebase**。自動化測試使用合成 SQLite、Mock Firestore、隨機 loopback port；不代表真實共存驗收已完成。8084 不需停止、重啟或改設定。

## 架構與邊界

- `bin/integration_readonly_server.dart`：只綁定 `127.0.0.1:8085`；不呼叫正式 `main()`。
- 沿用 `serveRequests()` 與正式路由；SQLite 寫入保留原本順序，Firestore GET 經既有有界獨立請求池處理。
- `DatabaseService.init(databasePath: ..., seedDemo: false, createDefaultAdmin: false)`：只初始化已驗證的絕對檔案路徑，等待初始化完成才輸出 READY。正式入口未指定參數時仍使用原路徑；初始化現在會等待 Seed 完成。
- 僅建立測試管理員 ID `1`、帳號 `integration_test`，以及明確命名的合成使用者／物資／OFFICE001 測試資料；初始庫存 20。沒有複製正式資料，沒有預設正式密碼，沒有自動載入原 Seed。
- SQLite 使用者、物資、需求與 SOS API 可在這個檔案內讀寫；「唯讀」指 Firestore，並不表示 SQLite 測試功能不能寫入。
- 不初始化 Firebase Users、通知寫入或外部地理編碼服務。本階段驗收的是 Firestore 健康回報／SOS 與舊 SQLite API 共存。
- Session 僅存在此程序記憶體。8084／正式 Server 的 Token 不可沿用，重啟 8085 後須重新登入。

## 資料庫路徑保護

只接受系統 TEMP 的**直接子目錄**，名稱須為 `hucares-integration-8085-` 加英數、底線或連字號；固定檔名 `integration.sqlite`，不可自行指定其他檔名。

例如：

```text
C:\Users\User\AppData\Local\Temp\hucares-integration-8085-demo-20261118\integration.sqlite
```

這是建議手動路徑，尚未替你建立真實驗收資料庫。啟動時會先列印實際絕對路徑。

拒絕相對路徑、`..`、不正規路徑、TEMP 外目錄、符號連結、junction、解析後路徑別名。檢查所有祖先目錄及 SQLite 主檔／WAL／SHM／journal。既有檔案額外檢查硬連結數量，Windows 使用 `fsutil hardlink list`，檢查不能執行時拒絕啟動。既有 DB 必須具有此入口建立的路徑標記才可重開，**不會退回 data/admin.db**。

路徑與標記只供隔離防誤用，不能取代檔案系統權限；請使用由本人控制、沒有其他程序同時修改的本機 TEMP 目錄。啟動後不要替換目錄或建立連結。首次初始化若中途失敗且沒有標記，請保留現場檢查，另選新的隔離目錄，不要移除正式資料。不要把任何正式資料庫複製進此目錄。

重啟使用相同目錄即可保留測試庫存和需求；啟動不會把已有庫存改回 20。測試密碼以本次安全輸入更新，其他測試紀錄不清空。

## 視窗一：確認設定後，手動啟動

僅在你確認路徑、目標專案與既有 reader ADC 都正確後執行。不要建立私鑰、不要切換或提高 reader 權限。

```powershell
Set-Location 'C:\Users\User\AppData\Local\Temp\hucares-firestore-reports-20261117\admin_server'

$env:INTEGRATION_TEST_SERVER = 'true'
$env:INTEGRATION_TEST_DIRECTORY = Join-Path ([IO.Path]::GetTempPath()) 'hucares-integration-8085-demo-20261118'
Write-Host ('請先確認隔離資料庫：' + (Join-Path $env:INTEGRATION_TEST_DIRECTORY 'integration.sqlite'))

$env:FIREBASE_ENABLED = 'true'
$env:FIREBASE_PROJECT_ID = 'bitchat-android-disaster-app'
$env:FIREBASE_DATABASE_ID = '(default)'
$env:FIREBASE_READ_ONLY = 'true'
$env:NOTIFICATIONS_ENABLED = 'false'
$env:FIREBASE_USERS_ENABLED = 'false'
$env:FIREBASE_REPORTS_ENABLED = 'true'
$env:FIREBASE_REPORTS_SCOPE = 'project'
$env:FIREBASE_REPORTS_ADMIN_IDS = '1'
# 避免此 PowerShell 視窗殘留舊專案別名；不修改持久設定或 ADC。
Remove-Item Env:NOTIFICATION_FIREBASE_PROJECT -ErrorAction SilentlyContinue

$securePassword = Read-Host '請輸入全新的測試密碼（至少 16 字元，不用正式密碼）' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $env:INTEGRATION_TEST_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    $securePassword.Dispose()
}
try {
    & 'C:\Users\User\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe' run bin/integration_readonly_server.dart
} finally {
    Remove-Item Env:INTEGRATION_TEST_PASSWORD -ErrorAction SilentlyContinue
}
```

需看到正確的 `ISOLATED_SQLITE` 路徑，以及 `READY http://127.0.0.1:8085`。若安全檢查、密碼、ADC、設定或 Port 有問題，入口失敗退出，**不要改用正式 Server 或解除唯讀限制**。目前啟動錯誤只輸出固定安全訊息；ADC 細部診斷可使用既有唯讀 probe，不要輸出原始錯誤或憑證。

密碼只以程序環境變數傳入；依現有測試登入架構保存於此隔離 SQLite，請使用一次性測試密碼並保護檔案。不要截圖或輸出環境變數、請求內容、Token 或整份回應。

## 視窗二：能力檢查、登入、去識別化 API 摘要

```powershell
$apiUrl = 'http://127.0.0.1:8085'
$capability = Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType 'application/json' -Body '{"type":"getServiceStatus"}'
[pscustomobject]@{
    Http = $capability.data.http
    SQLite = $capability.data.sqlite
    FirestoreConfigured = $capability.data.firestoreReports
    FirestoreState = $capability.data.firestoreReportsState
}

$securePassword = Read-Host '輸入剛才設定的測試密碼' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$loginBody = $null
try {
    $loginBody = @{ type='login'; username='integration_test'; password=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) } | ConvertTo-Json -Compress
    $login = Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType 'application/json' -Body $loginBody
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    $securePassword.Dispose()
    $loginBody = $null
}
if (-not $login.success -or -not $login.token) { throw '測試登入未成功' }
$headers = @{ Authorization = 'Bearer ' + $login.token }
$login = $null

foreach ($type in @('getAllUsers','getInventory','getSupplyRequestDetails','getEmergencyRequestsByAdmin')) {
    $request = @{type=$type}
    if ($type -eq 'getEmergencyRequestsByAdmin') { $request.receiverAdminId = 'integration_test' }
    $local = Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType 'application/json' -Headers $headers -Body ($request | ConvertTo-Json -Compress)
    [pscustomobject]@{ API=$type; Success=$local.success; Count=@($local.data).Count; Source='sqlite_test' }
    $local = $null
}

foreach ($type in @('getFirebaseHealthReports','getFirebaseSosReports')) {
    $cursor = $null
    $total = 0
    $page = 0
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    do {
        $request = @{ type=$type; limit=25 }
        if ($cursor) { $request.pageToken = $cursor }
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType 'application/json' -Headers $headers -Body ($request | ConvertTo-Json -Compress)
        if (-not $response.success -or $response.source -ne 'firestore' -or $response.collection -ne 'health_reports') { throw '資料來源或回應不符' }
        $records = @($response.data.reports)
        if ($type -eq 'getFirebaseSosReports' -and @($records | Where-Object { $_.sos -ne $true }).Count -gt 0) { throw 'SOS 格式不符' }
        $total += $records.Count
        $page++
        $cursor = $response.data.nextPageToken
        [pscustomobject]@{ API=$type; Success=$true; Source=$response.source; Collection=$response.collection; Page=$page; Count=$records.Count; HasNext=[bool]$cursor }
        if ($cursor -and (-not $seen.Add($cursor) -or $page -ge 20)) { throw '分頁尚未完成，不能把部分筆數視為完整統計' }
        $response = $null
        $records = $null
    } while ($cursor) # 空 SOS 頁仍可能有下一頁
    [pscustomobject]@{ API=$type; TraversalComplete=$true; RowsAcrossPages=$total }
}
$headers = $null
$request = $null
$cursor = $null
$seen = $null
```

能力查詢的 `configured_not_verified` 只代表已設定 reader，**不代表 IAM／Firestore 查詢成功**。只有兩支查詢 API 實際成功才是讀取驗收。沒有資料就回報成功空集合；403、逾時或停用則回報失敗，不以 Mock 代替。

## 視窗三：Flutter

```powershell
Set-Location 'C:\Users\User\AppData\Local\Temp\hucares-firestore-reports-20261117'
& 'C:\Users\User\Flutter\flutter\bin\flutter.bat' run -d chrome --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8085
```

在 UI 重新以 `integration_test` 和測試密碼登入，不能重用 8084 登入 Session。

1. 用戶／物資頁應顯示合成 SQLite 資料。可在測試庫存上執行入庫，確認刷新後保留。
2. 健康回報／緊急事件頁選 Firestore，確認真實來源、清單及詳細資料；不能把 SQLite 的合成居民當成 Firebase UID。
3. 指揮中心預設 Firestore SOS；完整查詢後與緊急事件頁一致。資料可能在兩次查詢間更新，請以各頁最近成功時間確認。
4. 無 GPS 的 SOS 仍計數並列出「位置未知／轄區未確認」，地圖顯示「目前沒有可標示的 SOS 位置」，沒有預設求救標記。
5. 有效 GPS 使用原座標，地圖調整到標記；提示精度與取得時間未知。地圖沿用國土測繪圖磚，顯示地圖時會向圖磚供應商發出請求，不是地理編碼。
6. Dashboard 與緊急事件頁共用 SOS 快照及單一輪詢；前景每 30 秒刷新、可手動刷新。其他頁面不持續輪詢 SOS。健康回報頁維持自己的前景輪詢。
7. 切換 SQLite 來源後使用原本事件及處理流程；已處理事件卡片固定為 SQLite。來源不相加，Firestore 無完成／刪除／指派操作。
8. 斷線／服務失敗保留上次成功 SOS 並顯示資料可能過期；401／403 清除受保護資料並提示錯誤。首次失敗顯示尚未取得，不顯示假 0。
9. HTTP／SQLite／Firestore 分開顯示。舊的正在執行中 8084 不會因程式檔更新而自動取得新能力路由；若回 404，顯示能力未知，不代表 Firestore 失敗。

## 停止與重啟

視窗一輸入 `STOP` 並 Enter，等待處理中請求結束、程序退出。不要結束其他 Dart 程序，也不要操作 8084。測試 DB 保留。重啟同一路徑再登入，先前入庫仍存在，先前 Token 應回 401。

目前沒有 Android 居民手機；新增／更新／撤回 SOS、居民 APK 實際 Firebase 專案與 UUID／時間戳的手機端到端驗收仍待完成。輪詢不等於推播。正式部署、正式 Migration 與 Git 合併均不在本次操作內。

## 本次實際執行的離線回歸（2026-11-18）

| 檢查 | 結果 |
| --- | --- |
| 後端 `dart test -r expanded` 完整測試 | 241 項通過；含新增 10 項隔離共存／路徑／重啟測試 |
| Flutter：Dashboard、Firestore UI、地址相容性、逆地理編碼四份測試 | 44 項通過；其中 Dashboard 新增 16 項 |
| 後端 `dart analyze` | exit 0；0 error／warning，2 個既存 info |
| `flutter analyze --no-pub` | 0 error、6 warning、103 info；工具因既存提示 exit 1 |

既存 warning：citizen_page 的未使用方法、dashboard_page 的未使用 import、user_management_page 的未使用變數，以及 test/main.dart、test/model_test.dart 的三個未使用 import。後端既存 info 是 admin_server.dart 字串 escape、healthReport.dart 檔名。未為這些提示大幅重構。

最初的沙箱測試遇到 Windows 祖先目錄及 Flutter SDK cache 權限限制；核准工具存取後重新執行並通過。這些核准沒有啟用任何 Firebase 寫入或真實 8085 服務。

### Dashboard 修改前後

| 原本 | 現在 |
| --- | --- |
| SOS 統計固定讀 SQLite | 預設 Firestore，可明確切回 SQLite |
| 資料取得失敗可能顯示空集合／0 | Firestore 首次未成功顯示未知；一般失敗保留快照並警告，401／403 清除 |
| 地圖固定校園視野，沒有完整座標檢查 | Firestore 地圖只用有效真實座標調整視野；無座標仍保留 SOS，原 SQLite 標記也加上有效座標檢查 |
| 以 getInventory 判斷整個後端是否連線 | HTTP、SQLite 能力與 Firestore 設定／查詢狀態分開 |
| 指揮中心、SOS 頁各自資料來源 | Firestore SOS 共用 ViewModel／快照，避免雙重輪詢；SQLite DTO／流程獨立 |

保留導覽、配色、統計卡、兩欄地圖／清單與下方待辦布局；必要改動是來源選擇、提示、唯讀詳情與資料綁定。實際 Chrome 外觀、完整 8085 真實共存與 30 秒真實更新仍須依上文手動驗收。沒有執行全部舊 Flutter 示範測試；上述 44 是明確指定的相關測試，不是宣稱整份 Flutter 測試目錄全部通過。
