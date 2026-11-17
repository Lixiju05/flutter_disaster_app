# Firebase 第一階段：獨立 Firestore 唯讀連線

建立日期：2026-11-15（Asia/Taipei）。目標 Android App Project ID：`bitchat-android-disaster-app`。程式不預設此專案，執行者必須明確選擇。

本階段沒有啟動正式 Server、開啟正式 SQLite、寫入正式 Firestore、部署 Rules、產生服務帳號私鑰或修改 Flutter／Android App。唯讀 probe 不做同步、不配對姓名電話，也不啟用通知。

## 設定與保護

| 環境變數 | 預設／規則 |
| --- | --- |
| FIREBASE_ENABLED | false；未啟用則不取得 ADC、不建立 Client／雲端連線 |
| FIREBASE_PROJECT_ID | 無預設；啟用時必填 Project ID，不能是 URL 或 Project Number |
| FIREBASE_DATABASE_ID | (default)；named database 必須明確填入 |
| FIREBASE_READ_ONLY | true；不得同時啟用通知寫入 |
| NOTIFICATIONS_ENABLED | false；唯讀 probe 必須維持 false |
| NOTIFICATION_FIREBASE_PROJECT | 舊相容變數，可不設定；若啟用 Firebase 時仍有設定，須與共用 Project 一致 |

布林設定只接受小寫 true／false，不接受 1、yes 或空字串。無效配置會拒絕，不會默默當成關閉安全限制。通知仍需原 NOTIFICATION_SCOPE=project、管理員允許清單與有效 Session；本階段不需要設定這些權限來跑 probe。

一般 Server 的通知 bootstrap 在 Firebase／通知關閉時不取得 ADC。即使 FIREBASE_ENABLED=true，只要 NOTIFICATIONS_ENABLED=false，通知仍停用，三支通知 API 回 503；目前沒有新增一般 Firebase users API。第一階段用下面獨立 CLI 讀取。

## 手動準備：不下載私鑰

1. Firebase Console 確認目標 Project 與 Firestore Database ID，不能只看專案顯示名稱。
2. Google Cloud Console 確認 Cloud Firestore API 已啟用。
3. 建議建立專用唯讀服務帳號，不建立任何金鑰。給它 Cloud Datastore Viewer (`roles/datastore.viewer`) 或核准的更小自訂唯讀權限，不給 Owner／Editor／Datastore User。Viewer 並非僅限 users collection。
4. 本機使用服務帳號模擬時，啟用 Service Account Credentials API，讓操作人對該服務帳號具有 Service Account Token Creator 權限。不要另外給唯讀服務帳號寫入角色；檢查繼承的有效權限。
5. 安裝／確認 Google Cloud CLI。先前環境檢查未在 PATH 找到 gcloud；這不代表本次已安裝它。
6. 由操作人手動登入 ADC，不列印 access token、不把 ADC 檔放入 Repository。

範例（請換成你核准的唯讀服務帳號 Email；本次沒有執行）：

```powershell
gcloud auth application-default login --impersonate-service-account=YOUR_READONLY_SA_EMAIL
```

這會建立本機 ADC 設定／使用者授權資料，不是建立或下載服務帳號私鑰。ADC 檔仍敏感，不能提交、貼到對話或打包給組員。不得執行 print-access-token 等會顯示 Token 的指令。

若需要設定 quota project，由負責人確認權限後手動操作：

```powershell
gcloud auth application-default set-quota-project bitchat-android-disaster-app
```

quota project 不會代替 FIREBASE_PROJECT_ID，也不會自動授予 Firestore 權限。若有 GOOGLE_APPLICATION_CREDENTIALS，函式庫會優先使用它；確認來源是否正確，不要輸出該檔內容。專用測試 PowerShell 若不應使用該變數，可由你手動移除該**環境變數**，不刪憑證檔：

```powershell
Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS -ErrorAction SilentlyContinue
```

Windows 本機找不到明確憑證路徑或 `%APPDATA%/gcloud/application_default_credentials.json` 時，工具回 ADC_NOT_FOUND，不會默默嘗試 metadata server。此 Windows probe 以本機 ADC 為設計範圍；Windows 雲端受管身分需另行核准／驗證。其他系統保留函式庫 metadata ADC 支援，不代表本次已測過雲端部署。

相關官方文件：[ADC](https://cloud.google.com/docs/authentication/application-default-credentials)、[服務帳號模擬](https://cloud.google.com/docs/authentication/use-service-account-impersonation)、[Firestore IAM](https://cloud.google.com/iam/docs/roles-permissions/firestore)。伺服器 IAM 存取不能靠放寬 App Rules 解決，本次不修改 Rules。

## 執行唯讀 probe

在專案根目錄開新的 PowerShell：

```powershell
cd admin_server
$env:FIREBASE_ENABLED = 'true'
$env:FIREBASE_PROJECT_ID = 'bitchat-android-disaster-app'
$env:FIREBASE_DATABASE_ID = '(default)'
$env:FIREBASE_READ_ONLY = 'true'
$env:NOTIFICATIONS_ENABLED = 'false'

# 舊變數若仍存在，設定成相同 Project，避免繼承舊專案造成衝突。
if (Test-Path Env:NOTIFICATION_FIREBASE_PROJECT) {
  $env:NOTIFICATION_FIREBASE_PROJECT = $env:FIREBASE_PROJECT_ID
}

dart run bin/firebase_readonly_probe.dart
$LASTEXITCODE
```

必要時先確認 database metadata，再讀 users：

```powershell
dart run bin/firebase_readonly_probe.dart --metadata
```

**不要改跑 bin/admin_server.dart**，一般入口仍有既有 SQLite 初始化／Seed／Schema 流程。獨立 probe 完全不匯入該入口或 DatabaseService。

唯讀流程：解析設定 → 驗證 read-only／notifications=false → 真實 ADC → 可選 metadata GET → users list GET，pageSize=1。不分頁、不 retry 掃描、不開資料交易、不寫入任何收件匣。

Firestore 只允許 HTTPS 固定主機的 GET，不跟隨 redirect。ADC/OAuth 取得短效 Token 可能使用 POST，那不是 Firestore 資料寫入。正常 probe 只有一個資料 GET，--metadata 增加一個 metadata GET。

讀取遮罩限定 id、email、name、phone、area、registeredAt、createdAt、updatedAt；只輸出已取得欄位的名稱／型別，不顯示值或文件路徑。未知欄位不列印、不遞迴顯示 map／array，不輸出 UID、姓名、電話、Email、Token、原始 JSON 或原始例外。

成功輸出格式示意（不是本次真實連線結果）：

```json
{"verification":"live_adc","projectId":"bitchat-android-disaster-app","databaseId":"(default)","status":"read_ok","httpStatus":200,"documentsRead":1,"fieldTypes":{"id":"string","email":"string","name":"string"}}
```

`documentsRead` 只有 0 或 1，是本次回傳／驗證的文件數，不是整個集合總人數。status=read_ok_empty 表示 GET 成功但未取得文件，不能證明集合一定存在或 profile 模型完整。遮罩沒有涵蓋的實際 AppUser 欄位仍需 App 組提供契約。

設定錯誤會回安全的 code／message；其餘錯誤只包含目標、階段、HTTP status、固定分類及 documentsRead=0，不輸出 Google 回應原文。失敗時的 0 不能解讀為集合真的為空。

## 結果判讀

| code／status | 意義與下一步 |
| --- | --- |
| read_ok / read_ok_empty | 真實 CLI 取得 HTTP200 並通過回應結構驗證；不是同步或通知已完成 |
| FIREBASE_DISABLED | 明確停用，沒有 ADC 或連線，並非連線成功 |
| FIREBASE_PROJECT_REQUIRED / INVALID_FIREBASE_PROJECT | 專案未明確指定或格式錯誤 |
| FIREBASE_PROJECT_MISMATCH | 舊通知專案與共用專案不同 |
| FIREBASE_READ_ONLY / READONLY_PROBE_REQUIRED | 通知寫入與唯讀設定衝突，或 probe 被要求用可寫模式 |
| ADC_NOT_FOUND | 本機找不到所選 ADC 路徑／Windows ADC 檔 |
| ADC_INVALID_OR_UNREADABLE | ADC 不可讀或格式不合法；不要貼出檔案排查 |
| ADC_REJECTED | ADC／Token 被拒絕或失效，需操作人重新驗證 |
| ADC_PERMISSION_DENIED | ADC 模擬／授權階段被拒，檢查 Token Creator 與 IAM Credentials API |
| PERMISSION_DENIED | Firestore HTTP403，檢查有效 IAM、scope、quota project 與組織政策；不放寬 App Rules |
| API_NOT_ENABLED | Google 回覆 SERVICE_DISABLED／API_DISABLED，先手動檢查 API 狀態 |
| DATABASE_NOT_FOUND_OR_INACCESSIBLE | HTTP404，確認 Project／Database，不可當成 users 集合為空 |
| NETWORK_ERROR / NETWORK_TIMEOUT | 無網路／DNS／TLS／代理等問題，或超時；不 fallback Mock |
| QUOTA_EXCEEDED | HTTP429，檢查配額，不持續重試 |
| INVALID_FIRESTORE_RESPONSE / DATABASE_TARGET_MISMATCH | 回應結構或目標不符，不能標成功 |
| FIRESTORE_HTTP_ERROR / UNEXPECTED_RESPONSE | 其他未確認錯誤，需由負責人安全排查 |

沒有機器可判讀的 API-disabled reason 時，403 只能歸 PERMISSION_DENIED，不能憑空斷定是 API 未啟用。HTTP status 在未收到 Firestore 回應時為 null。Firestore／OAuth timeout 目前各 20 秒，包含 Token 取得時可能有不只一個網路階段，不宣稱整個程序 20 秒內必定結束。

程序 exit code：0=已完成真實資料讀取驗證；2=停用／設定拒絕；1=授權、網路或遠端讀取失敗。參數只接受 --metadata，沒有 --mock／--write 選項。

執行後如需關閉未來的 Firebase 操作：

```powershell
$env:FIREBASE_ENABLED = 'false'
$env:NOTIFICATIONS_ENABLED = 'false'
```

變更環境變數只影響後續啟動的程序，不會更改其他正在執行的 Server。本次不啟停任何正式程序。

## 單元測試與真實驗證界線

```powershell
dart analyze
dart test test/firebase_config_test.dart test/firebase_readonly_probe_test.dart test/notification_service_test.dart test/notification_http_test.dart test/notification_firestore_rest_test.dart
```

上述測試使用明確 Mock 或停用的真 CLI，不取得真實 ADC、不連線 Firebase。Mock 測試成功不等於真實 IAM／Firebase 成功。

真實驗證只由操作人完成前述 ADC 與環境設定後，手動跑 `bin/firebase_readonly_probe.dart`；本次實作沒有自動執行已啟用的 probe。沒有憑證時不創造假成功。使用 ADC scope 不等於唯讀授權，專用唯讀 IAM 與 GET-only 程式共同提供保護。

既有通知權限／收件者／去重／交易規格仍在 [notifications_api.md](notifications_api.md)，但本階段不要啟用發送。SQLite UID 對照、三種回報同步、App 收件匣、Rules 合併與通知真實發送仍屬後續階段。

## 本次實測紀錄

- Firebase 新增測試 30 項，搭配原通知 20 項回歸：50 項全數通過。新測試涵蓋設定拒絕、零 ADC／傳輸、GET-only、欄位遮罩／遮蔽、網路／IAM／API錯誤、資料庫目標與停用 CLI。
- 完整後端 dart test：160 項通過、1 項既存載入失敗；空白 test/admin_server_test.dart 缺少 main()。未修改該檔，不能將全套宣稱為全綠。
- dart analyze：exit 0，無 error／warning，仍有 2 項既存 info（主入口多餘字串跳脫、healthReport.dart 檔名）。
- 本次相關既有檔案 git diff --check 通過。
- 未執行啟用的真實 ADC probe；目前沒有真實 Firebase 連線成功證據。測試中的 Mock 成功僅證明程式行為，不能代替手動 IAM／ADC 與真實讀取驗收。
- 未修改 Flutter／Android App、正式 SQLite、Rules；未取得或輸出憑證／個資、未發送通知或執行任何正式 Firestore 寫入，未執行 git add／commit／push／pull／merge。

修改檔案：新增 firebase_config.dart、firebase_connection.dart、firestore_readonly_probe.dart、bin/firebase_readonly_probe.dart、兩個 Firebase 測試、test/support/notification_fixture.dart 與本文件；修改 notification_bootstrap.dart、notification_store.dart、主入口的安全錯誤碼日誌、三個既有通知測試與 notifications_api.md。未更動通知業務 Service 的權限／收件者／交易規則，未增加套件依賴。
