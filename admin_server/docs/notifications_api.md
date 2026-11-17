# 管理員通知 API：Firestore 第一版

## 實作與驗證範圍

已實作三支 Dart POST type、管理員 Session／帳號存在性／通知權限檢查、通知服務、Firestore REST transaction adapter、ADC 啟動設定、單元及 Mock／HTTP 整合測試。

**本次沒有連線讀取或寫入正式 Firebase，沒有使用正式憑證，沒有部署 Rules，沒有修改正式 admin.db 或啟動正式 Migration，沒有改任何 Flutter UI 或使用者 App Repository。** 真實 Firestore IAM、已部署 Rules、實際使用者模型及雲端端到端收件尚未驗證。預設 API 回 503，絕不自動用 Mock 回報成功。

Firebase Project 現改由共用 `FIREBASE_PROJECT_ID` 明確設定，不再固定舊專案，也不從 Flutter 設定或 ADC 憑證推測。Android App 目前預計目標為 `bitchat-android-disaster-app`，這是操作設定，不是程式預設值。管理端 UI 仍只需呼叫 Dart API，不需要服務帳號，也不需要改成 Firebase 管理員登入。

**2026-11-15 第一階段只開放獨立唯讀連線驗證，通知發送保持停用。** 請先閱讀 [Firebase 唯讀操作文件](firebase_readonly_connection.md)。`FIREBASE_READ_ONLY=true` 與 `NOTIFICATIONS_ENABLED=true` 同時出現時，啟動設定會在取得 ADC 前拒絕。以下通知 request／response 為既有契約，並非已執行正式發布。

## 授權與正式串接前設定

既有 login 成功回傳 token。三支 API 全部帶：

```http
POST /
Content-Type: application/json
Authorization: Bearer <login 回傳的 token>
```

Session 綁定 SQLite admins.id、有效 8 小時、Server 重啟失效。每次 API 都檢查帳號仍存在；另以伺服器設定的 ID 允許清單作通知權限。資料庫目前沒有另外的啟用／停用或角色欄位，不會假設前端 adminId／Firebase 使用者 Token 代表管理員。

伺服器設定，以下均為待操作人配置的範例，**本次沒有執行啟用或啟動正式 Server**：

```powershell
$env:FIREBASE_ENABLED = 'true'
$env:FIREBASE_PROJECT_ID = 'bitchat-android-disaster-app'
$env:FIREBASE_DATABASE_ID = '(default)'
$env:FIREBASE_READ_ONLY = 'true'
$env:NOTIFICATIONS_ENABLED = 'false'
$env:NOTIFICATION_SCOPE = 'project'
$env:NOTIFICATION_ADMIN_IDS = '<允許通知操作的數字管理員ID，逗號分隔>'
$env:NOTIFICATION_BROADCAST_ADMIN_IDS = '<其中允許廣播的管理員ID，逗號分隔>'
```

上述唯讀配置不會建立通知服務，因此三支通知 API 保持 503；請執行獨立 probe，不要為了測試讀取就啟動正式 Server。將來另行核准通知寫入，才可明確設定 `FIREBASE_READ_ONLY=false`、`NOTIFICATIONS_ENABLED=true`，並完成 IAM 與下方權限設定。既有管理員、收件者、廣播及 transaction 語意不變。

`FIREBASE_ENABLED` 預設 false；啟用時缺少 Project ID 會回報 `FIREBASE_PROJECT_REQUIRED`。`FIREBASE_DATABASE_ID` 預設 `(default)`，可明確指定 named database。舊 `NOTIFICATION_FIREBASE_PROJECT` 可省略；若仍設定，必須與共用 Project ID 一致，否則 `FIREBASE_PROJECT_MISMATCH`。切換 Project 不會搬移、修改或刪除舊通知。

廣播清單必須是通知管理員清單的子集，可留空表示不開放廣播。ID 是 SQLite admins.id，不是 username、U010 或 Firebase UID。撤銷帳號會使後續操作拒絕；調整環境變數允許清單需要重啟程序。

`NOTIFICATION_SCOPE=project` 必須明確設定，代表允許清單中的管理員可查看／選擇本 Firebase 專案 `users/{uid}` 全體使用者，廣播也對本專案已註冊且 Email 驗證的 App 使用者可見。**不是依自由填寫的 area 推定社區權限。** 若需要跨社區隔離，須先另訂可信成員範圍，不要直接啟用全專案範圍。

Google 授權採後端專用 `googleapis_auth` Application Default Credentials，優先使用受管身分或服務帳號模擬。本階段不建立或下載私鑰；本機 ADC 設定必須保存在 Repository 外，不得放進 Flutter assets、版本控制或回應／日誌。既有 `GOOGLE_APPLICATION_CREDENTIALS` 會優先於本機 gcloud ADC，需確認來源但不可列印內容。部署身分需有目標專案必要的 Firestore IAM，避免配置 Owner；ADC 自動更新短效 OAuth Token。

未設定、明確範圍不符或啟動授權失敗時，通知功能保持停用，其他原 API 仍可用。正式對外 API 應使用 HTTPS。使用服務帳號的 Firestore REST 請求以 IAM 授權，不受客戶端 Security Rules 保護，因此發送範圍與操作人檢查留在後端。[官方授權文件](https://firebase.google.com/docs/firestore/use-rest-api)

## 1. getNotificationRecipients

```json
{"type":"getNotificationRecipients","limit":50}
```

limit 可省略，預設 50，範圍 1～100。後續頁帶上一頁 nextPageToken：

```json
{"type":"getNotificationRecipients","limit":50,"pageToken":"<opaque cursor>"}
```

HTTP 200 範例：

```json
{
  "success":true,
  "message":"查詢成功",
  "data":{
    "recipients":[{
      "uid":"firebase-uid-example",
      "id":"firebase-uid-example",
      "email":"user@example.test",
      "name":"測試使用者",
      "phone":"",
      "area":"社區"
    }],
    "nextPageToken":null,
    "skippedInvalidProfiles":0,
    "scope":{"type":"project","projectId":"bitchat-android-disaster-app"}
  }
}
```

### 使用者模型對應與限制

- UID **只取自文件路徑 users/{uid}**，不從姓名、Email、SQLite 業務 ID 或文件內 id 猜測。
- 回應 id 是文件內原值，非字串／缺少時 null，不能作為通知路由。即使 id 與 uid 不同也以 uid 為準。
- 假設 email 是非空字串；不符合者不列入可選名單，並計入 skippedInvalidProfiles。name、phone、area 非字串／缺少時回空字串。
- 不回傳其他欄位，例如醫療、緊急聯絡人或完整原始文件。
- **尚未取得另一個 App 的實際 AppUser 原始碼或正式樣本**；上述相容解析已用 Mock 測試，不宣稱已核對正式模型。
- 目前只查 Firestore 使用者文件，沒有查 Firebase Auth 管理目錄，也不宣稱可即時確認帳號 emailVerified／disabled 狀態。使用者 App 必須維持「驗證後建立文件」與安全的 users 主檔 Rules。

分頁是來源文件分頁；因為會略過無效文件，某頁可能少於 limit。必須以 nextPageToken 是否為 null 決定結束，不要只看筆數。

## 2. sendNotification

### 指定單一使用者

```json
{
  "type":"sendNotification",
  "audience":"users",
  "recipientUids":["firebase-uid-example"],
  "title":"物資領取通知",
  "body":"請於下午至社區管理中心領取。",
  "category":"supply",
  "expiresAt":"2026-11-11T10:00:00Z",
  "clientRequestId":"<每次新發送產生的UUID>"
}
```

時間是格式示例，實際呼叫請使用相對伺服器目前時間的未來期限。

### 指定多位使用者

相同格式，recipientUids 改為多個 Firebase UID。限制 1～100 位，重複 UID 拒絕，不會靜默去除或只發布給部分人。所有收件者都須存在且有非空 email 字串。選擇無效／不存在文件回 422，整筆不寫入。

### 全體廣播

```json
{
  "type":"sendNotification",
  "audience":"broadcast",
  "title":"社區防災公告",
  "body":"請留意管理中心最新公告。",
  "category":"safety",
  "expiresAt":"2026-11-11T10:00:00Z",
  "clientRequestId":"<另一個新的UUID>"
}
```

廣播不帶 recipientUids，或帶空陣列。僅 NOTIFICATION_BROADCAST_ADMIN_IDS 成員可發布。廣播不是發送當下的使用者名單快照，有效期內新註冊且符合 Rules 的使用者也可看到；不計算或推定送達人數。

### 欄位驗證

| 欄位 | 規則 |
|---|---|
| audience | users / broadcast |
| recipientUids | users 時 1～100 個、不重複；採 users/{uid} 路徑 |
| title | 非空，最多 100 字 |
| body | 非空，最多 4000 字 |
| category | 非空，最多 40 字；省略預設 general |
| expiresAt | 有時區的 ISO 8601，未來 30 天內 |
| clientRequestId | 非空，最多 128 字，限英數字／底線／連字號，建議 UUID |

messageId、createdAt、createdByAdminId、status 一律由後端產生，不接受前端覆寫。Firestore 中 createdAt、expiresAt 為 Timestamp；HTTP 回應轉為 UTC ISO 8601 字串。

### 成功回應

```json
{
  "success":true,
  "message":"通知已發布（不代表已送達或已讀）",
  "data":{
    "messageId":"<64字元識別碼>",
    "status":"published",
    "replayed":false,
    "createdAt":"2026-11-10T08:00:00.000Z",
    "expiresAt":"2026-11-11T10:00:00.000Z",
    "audience":"users",
    "recipientCount":1,
    "deliveryStatus":"not_tracked",
    "readStatus":"not_tracked"
  }
}
```

廣播 recipientCount=null，不代表零人；代表未計算目標人數。

### 原子寫入與防重

一次 Firestore transaction 先讀取防重發送紀錄，再讀全部指定使用者，最後一次 commit 建立：

- notification_sends/{messageId}：管理端紀錄。
- 廣播：broadcasts/{messageId} 一份。
- 私人通知：每位 users/{uid}/notifications/{messageId} 一份。

使用者讀取與通知寫入在同一 transaction，併發修改會由 Firestore 衝突保護處理；不逐人先行提交。最多 101 個建立操作，並使用 exists=false 防止覆寫。ABORTED／ALREADY_EXISTS 衝突最多重試交易三次。[官方 commit 原子保證](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/commit)

messageId 由 projectId、已驗證 adminId、clientRequestId 的 SHA-256 決定；紀錄另存正規化內容指紋。相同管理員、相同 key、相同內容重送會回原訊息，replayed=true；收件者順序不同仍視為相同內容。改內容卻重用 key 回 409 IDEMPOTENCY_CONFLICT。不同管理員的 key 分開處理。

僅在 commit 成功確認後回 published。網路中斷可能造成「已提交但回應遺失」，這時 API 回 503／未確認，**不能斷言完全未發布，也不能用新 key 盲目重送**。應保留相同 key、內容與期限重試，或查自己紀錄的 clientRequestId。已存在的相同發送即使目前過期，也只回原始紀錄，不重新發布。

不要任意刪除 notification_sends 防重紀錄，否則會破壞長期防重保證；本次沒有設定 TTL 刪除或刪除 API。

## 3. getSentNotifications

```json
{"type":"getSentNotifications","limit":50}
```

後續頁使用 pageToken。查單筆：

```json
{"type":"getSentNotifications","messageId":"<sendNotification 回傳的64字元ID>"}
```

HTTP 200：

```json
{
  "success":true,
  "message":"查詢成功",
  "data":{
    "notifications":[{
      "messageId":"<64字元識別碼>",
      "title":"物資領取通知",
      "body":"請於下午至社區管理中心領取。",
      "category":"supply",
      "createdAt":"2026-11-10T08:00:00.000Z",
      "expiresAt":"2026-11-11T10:00:00.000Z",
      "createdByAdminId":7,
      "clientRequestId":"<原發送UUID>",
      "audience":"users",
      "recipientUids":["firebase-uid-example"],
      "recipientCount":1,
      "status":"published",
      "deliveryStatus":"not_tracked",
      "readStatus":"not_tracked"
    }],
    "nextPageToken":null
  }
}
```

第一版只回查詢管理員自己的紀錄，不開放查其他管理員。查他人／不存在的 messageId 統一回 404。列表按 createdAt 降序讀取，再過濾自己的紀錄，所以可能有空頁但 nextPageToken 非空，需繼續翻頁。沒有整個中心跨管理員查閱權限介面。

紀錄不額外複製姓名、電話、Email，僅保存必要 UID、訊息內容及操作人。status=published 只表示 Firestore 已持久化；deliveryStatus/readStatus 固定 not_tracked，沒有裝置送達、已讀統計、FCM 或 DTN 實作。

## 錯誤回應

```json
{"success":false,"code":"NOTIFICATIONS_DISABLED","message":"通知服務尚未設定伺服器授權或尚未啟用"}
```

| HTTP | 主要 code / 情況 |
|---|---|
| 400 | INVALID_ARGUMENT、INVALID_RECIPIENTS、INVALID_EXPIRY：參數或期限不符 |
| 401 | ADMIN_SESSION_REQUIRED：管理員 Token 無效／過期 |
| 403 | ADMIN_DISABLED、NOTIFICATION_FORBIDDEN：帳號不存在或未授權，含無廣播權限 |
| 404 | NOT_FOUND：沒有自己的發送紀錄 |
| 409 | IDEMPOTENCY_CONFLICT、RETRY_REQUIRED：key 衝突或交易持續衝突 |
| 422 | RECIPIENT_UNAVAILABLE：不存在或格式不符的收件者，整筆未提交 |
| 503 | NOTIFICATIONS_DISABLED、FIRESTORE_UNAVAILABLE、FIRESTORE_UNCONFIRMED 等：未啟用、授權／連線失敗或結果未確認 |

不將 Google 的原始錯誤、Token、憑證內容傳回 UI 或寫入應用日誌。Mock 測試失敗注入用的 code 僅出現在測試替身，不是正式 Firestore 狀態。

## 使用者 App 串接與建議 Rules

App 組需新增 Notification Model／收件匣，在 Firebase Auth 已登入且已驗證 Email 後監聽：

```text
broadcasts
users/{FirebaseAuth.currentUser.uid}/notifications
```

可各自 orderBy(createdAt, descending=true)、limit 分頁；Firestore 日期是 Timestamp。合併時以 messageId 去重，依 expiresAt 隱藏過期內容並依需要保留本機已讀狀態。通知文件由後端管理，不允許 App 直接加 readAt、修改內容或自行發布。

建議規則位於 `firestore_notifications.rules.example`，只供 App 組合併審查，沒有部署或設定 firebase.json：

- 已驗證 Email 且有 users/{uid} 文件者才可讀廣播。
- 只有本人可讀 users/{uid}/notifications。
- 一般 App 禁止 create/update/delete 任何通知與管理端紀錄。
- notification_sends 僅由經驗證 Dart API 讀取，客戶端禁止直接讀寫。
- 保留並核對既有 users/{uid} 註冊／修改規則，例如 Email 應與 Auth 綁定，不能讓他人建立／覆寫另一個 UID。
- Firestore 的 allow 規則採 OR，這份 deny 不能抵銷原本寬鬆的遞迴 wildcard。必須一併移除／收窄允許任意寫入的重疊規則。
- Email 驗證後需讓 ID Token 取得最新 email_verified claim；未刷新可能仍被拒絕。

**Rules 範例沒有經 Emulator 或實際專案驗證。** 合併後應先在 Emulator 測試未登入、未驗證、讀他人收件匣、用戶偽造廣播、修改通知、讀自己的通知及讀廣播，再由團隊決定是否部署。

此版不做 FCM。Firestore listener 不是背景系統推播，也不是離線多跳。未來收到／已讀回執應另建受保護機制，不得從「文件已存在」推定送達；DTN 還需封包驗簽、加密、TTL、持久去重與雙向回執。

## UI 組配合

管理端：保存登入 token；新增廣播／指定名單表單、發送紀錄；名單選擇使用 uid，不用 id／姓名／Email；發送前產生一次 UUID，直到結果確認前保留相同 clientRequestId 與內容。新通知發送涉及多筆雲端讀取，應配置較長 HTTP timeout（例如 60 秒）並處理未確認結果，不能只顯示已送達。

使用者 App：核對實際 AppUser 欄位、初始化目標專案、Email 驗證與 Rules；新增上述兩個監聽與通知畫面，並將 createdAt/expiresAt 轉當地時間。提供去識別化文件樣本及實際模型供正式前相容性核對，不要提供私鑰或使用者 Token。

正式串接尚需：後端 ADC／服務帳號與 IAM、明確管理員 ID 清單、專案範圍確認、實際模型核對、Rules 合併及測試環境端到端驗證。這些不是本次已成功完成的雲端操作。

## 修改檔案與實際測試

- `bin/admin_server.dart`：三支路由、既有 Session／帳號存在檢查、通知服務注入與安全失敗回應。
- `lib/services/notifications/notification_bootstrap.dart`：明確啟用、專案／範圍／ID 清單及 ADC 設定。
- `lib/services/notifications/notification_service.dart`：驗證、收件者名單、發送、防重、紀錄查詢與個資欄位白名單。
- `lib/services/notifications/notification_store.dart`：可替換介面、Firestore REST transaction 與 Timestamp codec。
- `pubspec.yaml`、`pubspec.lock`：後端專用 googleapis_auth 及直接宣告 crypto。
- 三個 notification 測試檔及 `test/support/memory_notification_store.dart`：測試替身不會被正式 bootstrap 載入。
- 本文件與 `firestore_notifications.rules.example`：串接與待合併規則文件。

實際執行：

- `dart pub get` 成功，只安裝依賴，沒有取得 Google 憑證或存取 Firebase 專案。
- 新增測試共 20 項：服務單元 10 項、loopback HttpServer 路由整合 4 項、MockClient Firestore REST 整合 6 項，全部通過。
- 驗證預設停用、權限與廣播權限、收件者不存在／格式、單人／多人／廣播、100 人限制、分頁、只讀自己的紀錄、併發防重、原子提交、IAM 拒絕、提交回應遺失／不完整、保留 key 重試及不洩漏上游錯誤。
- 最終 `dart test`：93 項通過，1 個既存載入失敗：空白 `test/admin_server_test.dart` 缺少 main。未更動該無關檔案；舊物資／方案 A／批次審核／Station Transfer 回歸通過。
- 最終 `dart analyze`：exit 0，無 error／warning，只有兩個既有 info（admin_server.dart 不必要字串跳脫與 healthReport.dart 檔名格式）。
- Firestore 測試全部由 Memory Store 或 http.MockClient 攔截；沒有向正式 Firestore 發出請求。HTTP 整合只用記憶體 SQLite admins 表和隨機 loopback Port。
- 沒有實際 Google IAM／Email 驗證／Rules Emulator／真實 App 收件的端到端測試，不能把 Mock 通過當成正式 Firebase 已串接成功。
