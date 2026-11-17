# Firebase 使用者唯讀 API（第二階段）

日期：2026-11-17（Asia/Taipei）。本階段新增管理員使用者查詢，不做 SQLite 同步、身分配對或通知發送，不修改 Flutter／Android／iOS、SQLite Schema／Seed、Rules／IAM／ADC。

操作人已回報第一階段真實 probe 為 live_adc、read_ok、HTTP200、documentsRead=1；這是第一階段的證據。本次新增 API 僅用 Mock／本機 HTTP／記憶體 SQLite 驗證，尚未連線正式 Firebase，不把 Mock 說成真實 API 整合成功。

## 1. 啟用與權限

預設關閉。一般 Server 未啟用時不建立使用者 ADC Client；與通知服務分開初始化，不可用唯讀服務帳號發送通知。

| 變數 | 規則 |
| --- | --- |
| FIREBASE_USERS_ENABLED | 預設 false；明確 true 才初始化使用者查詢；其他字串拒絕 |
| FIREBASE_ENABLED | 必須 true |
| FIREBASE_PROJECT_ID | 必填；目前核准目標為 bitchat-android-disaster-app，不從前端或 ADC 猜測 |
| FIREBASE_DATABASE_ID | 預設 (default)，啟動時固定 |
| FIREBASE_READ_ONLY | 必須 true |
| NOTIFICATIONS_ENABLED | 必須 false |
| FIREBASE_USERS_ADMIN_IDS | 必填正整數 SQLite 管理員 ID 清單，逗號分隔；不是 UID／username |
| FIREBASE_USERS_SCOPE | 必須明確 project，代表允許讀本 Firebase 專案的 users；不是從個人 area 推定社區成員 |

每筆請求驗證 Bearer Session、SQLite admins 帳號存在、使用者讀取允許清單。遠端讀取完成後會再驗一次 Session／帳號／權限，避免等待時帳號已被刪除仍釋出資料。既有 Session 8 小時到期、重啟失效；帳號存在不等於系統已有完整停權／RBAC。

權限／環境設定變更需重啟才套用；沒有新增可以從前端自行提權的參數。不要現在直接啟動一般 bin/admin_server.dart，既有入口仍會初始化正式資料庫與處理 Schema／Seed，正式部署需另行安排。

## 2. getFirebaseUsers

沿用原 POST endpoint（根路徑），Header：

```http
Content-Type: application/json
Authorization: Bearer <管理員登入取得的Token>
ngrok-skip-browser-warning: true
```

首筆分頁：

```json
{"type":"getFirebaseUsers","limit":25}
```

下一頁：

```json
{"type":"getFirebaseUsers","limit":25,"pageToken":"<上一頁nextPageToken>"}
```

- limit 省略時為25，必須為整數1–100；顯式 null、字串、0或超限拒絕。
- pageToken 省略表示首頁；有提供時必須為非空字串、最多8192個UTF-16碼元、不含控制字元。後端只請求一頁，不自動讀完。
- 固定 users collection、__name__ asc 排序、伺服器設定的 Project／Database，欄位遮罩只取 name、area、registeredAt。UID 從文件路徑取得。
- 未知參數拒絕；不可指定 Project／Database／collection／排序／欄位／keyword。缺少 Email 不會被過濾。
- 使用上游 nextPageToken，不是offset或姓名游標；同一串分頁應保持設定與排序不變。資料變動時不保證跨頁同一快照，UI可依UID去重；不可宣稱當頁筆數是全體人數。

成功格式示意，所有角括號內容都是欄位佔位，非真實個資：

```json
{
  "success":true,
  "source":"firestore",
  "data":{
    "users":[{
      "uid":"<Firebase文件路徑UID>",
      "name":null,
      "area":null,
      "registeredAt":null
    }],
    "nextPageToken":"<上游游標或null>"
  }
}
```

空頁是 HTTP200、users=[]、nextPageToken=null（若上游仍提供游標則保留）；失敗回 error，不能偽裝成空列表。

## 3. getFirebaseUserById

```json
{"type":"getFirebaseUserById","uid":"<Firebase文件路徑UID>"}
```

成功格式示意：

```json
{
  "success":true,
  "source":"firestore",
  "data":{
    "uid":"<Firebase文件路徑UID>",
    "name":null,
    "area":null,
    "registeredAt":null
  }
}
```

UID 必須為非空字串、最多128個Unicode碼點、無前後空白、斜線／反斜線、控制字元，不能是 . 或 ..。使用 URI 編碼保持單一文件路徑段，不能以百分比編碼繞過到其他collection。實際回應的文件路徑也會核對 Project／Database／users／指定UID。

文件內 id 不作識別，不拿來配對或回傳。404 時以額外 metadata GET 確認資料庫可達，避免把資料庫設定錯誤誤報為使用者不存在；不存在的文件不改查 SQLite。這條分支最多兩個 GET，不使用交易。

## 4. 欄位與隱私

- DTO 為 FirebaseUser，與 SQLite AppUser 分開；列表及詳情均只有 uid、name、area、registeredAt 四欄。
- 本版不提供 email／phone 選項；雖需求允許必要時擴充，目前未核准額外用途，不接受 includeContact 或任意 fields 參數。
- 血型、醫療資訊、緊急聯絡人、文件 id、位置與其他原始欄位一律不回傳。上游遮罩與 DTO toJson 各自限制，即使 Mock／上游意外提供其他欄位也不外洩。
- 缺少或型別錯誤的文字欄位為 null，不轉字串補假資料。registeredAt 支援 Timestamp 或含明確時區的 ISO 字串，輸出 UTC ISO8601；無效、缺漏或無時區則null，不補現在時間。
- area 是註冊居住地址，不是GPS／目前位置或資料授權證明。
- 新回應使用 Cache-Control:no-store。不記錄完整 UID、Token、姓名、Email、電話、游標或原始 Firebase response。通用入口也不再記錄 URI／任意 type值／原始 JSON 解析錯誤。
- SQLite users.id 與 Firebase UID 無自動對照；本版完全不寫 users，也不依姓名／電話／Email合併。

## 5. 錯誤契約

```json
{"success":false,"source":"firestore","code":"<固定錯誤碼>","message":"<安全訊息>"}
```

| HTTP | code | 意義 |
| --- | --- | --- |
| 400 | INVALID_ARGUMENT / INVALID_UID / INVALID_PAGE_TOKEN | 參數／UID／游標不合法；不回顯輸入內容 |
| 401 | ADMIN_SESSION_REQUIRED | 管理員未登入、Token無效或過期，須重新登入 |
| 403 | ADMIN_DISABLED / FIREBASE_USERS_FORBIDDEN | 管理員已不存在或不在明確允許名單 |
| 404 | FIREBASE_USER_NOT_FOUND | 目標資料庫已確認可達，但文件不存在 |
| 429 | FIREBASE_USERS_BUSY | 新查詢處理器已滿；只可稍後重試，不影響其他路由 |
| 503 | FIREBASE_USERS_DISABLED / FIREBASE_USERS_SHUTTING_DOWN | 未啟用、設定失敗或關閉中 |
| 503 | FIRESTORE_ADC_REJECTED / FIRESTORE_PERMISSION_DENIED / FIRESTORE_API_NOT_ENABLED | 上游ADC／IAM／API問題，不代表管理員Token錯誤，勿反覆要求UI登入 |
| 503 | FIRESTORE_DATABASE_NOT_FOUND_OR_INACCESSIBLE / FIRESTORE_DATABASE_TARGET_MISMATCH | 目標資料庫不可達或不符，不當成空列表／缺少使用者 |
| 503 | FIRESTORE_QUOTA_EXCEEDED / FIRESTORE_NETWORK_ERROR / FIRESTORE_FIRESTORE_HTTP_ERROR | 上游額度、網路或其他HTTP錯誤 |
| 503 | FIRESTORE_INVALID_FIRESTORE_RESPONSE / FIREBASE_USERS_UNAVAILABLE | 回應結構不合法或未確認錯誤 |
| 504 | FIRESTORE_NETWORK_TIMEOUT | 遠端讀取逾時 |

其他 ADC／安全例外沿用安全的 FIRESTORE_ 前綴分類，不輸出上游訊息、Token、堆疊或個資。通知 API 原錯誤格式與交易行為未變更。

## 6. 慢讀與 SOS 的請求隔離

已先用隔離測試重現原逐筆 await 的排隊：Mock Firestore未完成時SOS不能進SQLite。

修正維持原主迴圈的順序分派，僅在辨識到 getFirebaseUsers／getFirebaseUserById 後交由 IsolatedRequestPool 追蹤其 Future。不是移除所有 await，也沒有改 SQLite 庫存／配送交易為任意並行。

- 同一程序最多8筆新查詢處理中，超出即429；不建立無上限背景佇列。
- 每個遠端 GET 10秒 timeout，使用 AbortableRequest 結束／逾時時送出取消訊號；ADC token刷新本身仍受既有 transport timeout控管。Mock可觀察取消訊號，但不等於真網路已完成壓測。
- 脫離主迴圈的例外全部攔截，失敗回安全錯誤；Client已斷線則安全關閉，不留下未觀察Future。
- service讀取只使用SQLite admins SELECT，不開啟或提交SQLite交易；舊寫入路由仍順序執行。
- 關閉監聽後等待已接收的讀取完成／逾時，再關ADC Client；驗收入口最後才dispose記憶體SQLite。
- 只有新使用者查詢被隔離。既有逆地理編碼、舊通知或其他慢路由仍可能沿用原序列行為；不宣稱整個Server全部非阻塞。
- 原有慢上傳body／舊API授權與正式密碼雜湊等風險仍需依roadmap處理。本次沒有大幅重構或宣稱正式部署已全面驗收。

## 7. UI 組最小串接

1. 在現有登入保存token後，新增兩個Repository方法並帶Bearer Header；不直接從Flutter用服務帳號查Firestore。
2. 列表讀 data.users 與 data.nextPageToken，新增下一頁／載入更多，不將已載入當頁的搜尋宣稱為全體搜尋。
3. 詳情開啟時用 uid 呼叫 getFirebaseUserById，不拿SQLite id或文件內id替代。
4. UI可用自己的view adapter將uid顯示為識別，但需保存 source，不能把Firebase UID自動寫回SQLite或混入舊災民關聯。
5. 缺少資料顯示未知；未授權的聯絡／醫療欄位不顯示為「沒有」；area不得當即時位置，registeredAt不得當災時回報時間。
6. 401重新登入、403無權提示、429稍後手動重試、503/504保留原畫面並顯示錯誤；不能以空列表假裝成功。

本次沒有修改任何 Flutter 檔案。

## 8. 不碰正式資料的真實 API 驗收

已新增獨立 `bin/firebase_users_readonly_server.dart`，預設拒絕啟動。只監聽loopback、SQLite僅記憶體、只開放login與兩支讀API；其他路由404。它不執行DatabaseService.init／Seed／Migration，也不建立通知服務。測試管理員username固定 firebase_readonly_test、記憶體ID固定1，密碼由操作人自行提供且不記錄。

**本次未執行啟用的入口，不曾連線正式Firebase。以下須由你另外核准、在既有唯讀ADC已就緒後手動執行。** 不要改跑一般 bin/admin_server.dart。

終端機一，專案根目錄：

```powershell
cd admin_server
$env:FIREBASE_ENABLED='true'
$env:FIREBASE_PROJECT_ID='bitchat-android-disaster-app'
$env:FIREBASE_DATABASE_ID='(default)'
$env:FIREBASE_READ_ONLY='true'
$env:NOTIFICATIONS_ENABLED='false'
$env:FIREBASE_USERS_ENABLED='true'
$env:FIREBASE_USERS_SCOPE='project'
$env:FIREBASE_USERS_ADMIN_IDS='1'
$env:FIREBASE_USERS_READONLY_TEST_SERVER='true'
$env:FIREBASE_USERS_TEST_PORT='8082'
if (Test-Path Env:NOTIFICATION_FIREBASE_PROJECT) {
  $env:NOTIFICATION_FIREBASE_PROJECT=$env:FIREBASE_PROJECT_ID
}
$testSecret=Read-Host '設定本次記憶體測試密碼，至少12字，不要使用正式密碼' -AsSecureString
$env:FIREBASE_USERS_TEST_PASSWORD=([pscredential]::new('firebase_readonly_test',$testSecret)).GetNetworkCredential().Password
dart run bin/firebase_users_readonly_server.dart
```

保留原唯讀ADC、IAM、Rules，不改為可寫角色，不需要私鑰。若8082占用，手動改為其他空閒Port，不停止原Server／ngrok。此處ID1只代表隔離記憶體測試帳號，不能照抄到正式允許清單。

終端機二，PowerShell：

```powershell
$api='http://127.0.0.1:8082'
$secret=Read-Host '輸入剛才的測試密碼' -AsSecureString
$password=([pscredential]::new('firebase_readonly_test',$secret)).GetNetworkCredential().Password
$login=Invoke-RestMethod -Method Post -Uri $api -ContentType 'application/json' -Body (@{
  type='login'; username='firebase_readonly_test'; password=$password
} | ConvertTo-Json)
$headers=@{Authorization="Bearer $($login.token)"}
$page=Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json' -Body (@{
  type='getFirebaseUsers'; limit=1
} | ConvertTo-Json)
[pscustomobject]@{Success=$page.success;Source=$page.source;Count=@($page.data.users).Count;HasNext=($null -ne $page.data.nextPageToken)}

if (@($page.data.users).Count -gt 0) {
  $uid=$page.data.users[0].uid
  $detail=Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json' -Body (@{
    type='getFirebaseUserById';uid=$uid
  } | ConvertTo-Json)
  [pscustomobject]@{Success=$detail.success;Source=$detail.source;Fields=($detail.data.PSObject.Properties.Name -join ',')}
}
```

不要直接印 $login、$page、$detail、$uid、$headers 或原始JSON，也不要在Postman截圖露出個資。上例所有實際資料只留在本機記憶體，輸出只有成功、來源、筆數及欄位名稱；不使用姓名／電話／Email找對應。

在終端機一輸入 STOP，會停止監聽、等待已進行查詢、關閉Client並釋放記憶體DB。強制終止程序不保證能執行所有finally；不應用終止正式Server來測試。

退出後可手動清除測試密碼環境變數、關閉後續Firebase讀取；不刪ADC檔或正式資料：

```powershell
Remove-Item Env:FIREBASE_USERS_TEST_PASSWORD -ErrorAction SilentlyContinue
$env:FIREBASE_USERS_READONLY_TEST_SERVER='false'
$env:FIREBASE_USERS_ENABLED='false'
```

## 9. 檔案與測試

新增：FirebaseUser DTO、GET-only共用Reader、FirebaseUsersService／bootstrap、IsolatedRequestPool、隔離真實驗收入口、Service／HTTP／排隊重現／資源關閉測試、本文件。

修改：一般Server路由／使用者服務初始化／受控隔離與安全日誌，以及第一階段probe改用共用GET reader。原SQLite users API與資料來源、通知Service／發送交易、Schema及Seed未修改。

驗證指令（Mock／隔離資料）：

```powershell
dart analyze
dart test test/firebase_users_service_test.dart test/firebase_users_http_test.dart test/firebase_users_queue_test.dart test/isolated_request_pool_test.dart test/firebase_config_test.dart test/firebase_readonly_probe_test.dart
```

實際完整測試數與結果於本次最終驗收紀錄補列。Mock／本機HTTP成功不等於本次已完成兩支API的真實雲端驗收。

### 本次最終驗收結果

- 新增41項測試：Service／bootstrap 20、HTTP與SQLite相容性17、排隊重現1、隔離處理器關閉／錯誤3；全部通過。
- Firebase相關回歸71項全部通過（含第一階段30項）。
- 完整後端 dart test：201項通過、1項既存載入失敗。失敗為空白 test/admin_server_test.dart 缺 main()，未修改該檔，不能宣稱全套全綠。
- 最終 dart analyze：exit0，無error／warning；2項既存info（主入口字串跳脫、healthReport.dart檔名）。
- git diff --check：本次一般Server修改無空白格式問題。
- 已測出原序列迴圈的SOS排隊，並以同一 production serveRequests 分派函式驗證修正後SOS先於慢查詢完成；另驗證回滾、帳號刪除、容量限制、逾時釋放與安全關閉。
- 真實ADC、正式Firestore與本次新增API的真實讀取未執行。本次Mock測試不代表雲端端到端完成；先前probe的真實成功依操作人提供資訊記錄。
- 沒有修改正式SQLite、Schema／Seed、Flutter／Android／iOS、通知發送流程、Rules／IAM／ADC；沒有執行Git暫存／提交／推送或啟動正式Server。
