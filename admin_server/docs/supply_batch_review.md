# 方案 A：批次處理與異常需求人工審核

適用 OFFICE001。業務狀態維持 pending → reserved → dispatched → completed，不新增 rejected 或 claimed 階段。所有本文件新增的 API 都是 POST 根路徑，使用 JSON type，需帶有效管理員 Session。

```http
Content-Type: application/json
Authorization: Bearer <login 回傳的 token>
```

操作人一律從 Session 取得，前端 adminId 不參與授權／稽核。Session 過期回 401，帳號已不存在回 403，參數錯誤回 400。stationId 可省略，若提供僅接受 OFFICE001。

## 交易選擇

採逐筆交易，以 requestIds 傳入順序處理。整批交易可保證全部成功或全部失敗，但一筆異常會撤銷其他正常項目；逐筆交易則可沿用既有單筆流程，清楚回傳部分成功。已成功的項目不因另一筆失敗而撤銷。

每筆使用 BEGIN IMMEDIATE、重新檢查狀態與最新庫存。前筆預留後，後筆必須使用剩餘可用量；不是預先用同一份庫存快照各自判斷。出庫同樣使用原子減法。單筆 API、批次 API、人工核准都共享同一 SQLite 寫入鎖與條件更新。

並行操作若遭 SQLite busy/lock，該筆回失敗且不留下部分庫存變更；UI 應重新查狀態，只重試未成功項目。沒有額外批次 idempotency key，重送由逐筆狀態保護拒絕重複操作。

## 三支批次 API

```json
{"type":"batchReserveSupplyRequests","requestIds":["REQ001","REQ002"]}
```

```json
{"type":"batchDispatchSupplyRequests","requestIds":["REQ001","REQ002"]}
```

```json
{"type":"batchCompleteSupplyRequests","requestIds":["REQ001","REQ002"]}
```

requestIds 必須是 1～100 個非空字串；無效輸入整個請求回 400，尚未開始處理。相同 ID 的第二次出現回該筆 DUPLICATE_REQUEST_ID，第一筆仍照常處理，不會再次扣量。

以下為預留部分成功範例：OFFICE001 初始 stockQty=10、reservedQty=0，兩位不同使用者各需 7。

```json
{
  "success":false,
  "message":"批次處理完成，請逐筆確認 results",
  "data":{
    "transactionMode":"per_request",
    "total":2,
    "succeeded":1,
    "failed":1,
    "results":[
      {
        "requestId":"REQ001",
        "success":true,
        "message":"處理成功",
        "data":{
          "requestId":"REQ001",
          "stationId":"OFFICE001",
          "stationName":"管理中心",
          "distanceKm":null,
          "availableQtyBeforeReserve":10,
          "status":"reserved"
        }
      },
      {
        "requestId":"REQ002",
        "success":false,
        "code":"REVIEW_REQUIRED",
        "message":"需求須人工審核：OFFICE001 可用庫存不足",
        "anomalyReasons":[{
          "code":"INSUFFICIENT_STOCK",
          "message":"OFFICE001 可用庫存不足",
          "availableQty":3,
          "requestedQty":7
        }]
      }
    ]
  }
}
```

處理完成回 HTTP 200，即使全數或部分失敗。外層 success 代表是否每筆都成功，不能將 success=false 當成整批完全沒變更！每筆結果依輸入順序對應；code 為 REVIEW_REQUIRED、DUPLICATE_REQUEST_ID 或 OPERATION_REJECTED，message 說明原因。成功 data 沿用單筆結果；批次完成與出庫不再要求 volunteerId。

## 異常規則

| code | 規則 | 人工核准能否例外放行 |
|---|---|---|
| INSUFFICIENT_STOCK | OFFICE001 的 stockQty-reservedQty 不足 | 否，補足後重新審核 |
| DUPLICATE_OPEN_REQUEST | 同一 userId、itemId 有其他 pending/reserved/claimed/dispatched 需求 | 可以，需管理員確認及備註 |
| QTY_LIMIT_EXCEEDED | qty 超過設定上限 | 可以，仍須庫存足夠 |
| INCOMPLETE_DATA | requestId/userId 非空字串、有效 itemId、正整數 qty 任一不符合 | 否，先修復再審核 |
| INVENTORY_INVALID | OFFICE001 庫存不存在、數值不是整數、預留為負或大於實際 | 否，先核對庫存 |

第一版必填沿用既有核心資料：requestId、userId、itemId、qty；地址與 GPS 不新增必填限制，以免破壞原流程。userId 目前只驗證非空，不宣稱已驗證使用者真實身分。不同單位按既有 itemId 判斷，沒有跨單位合併。

預設單筆上限 100，可於啟動時設定 Dart define：

```powershell
dart -DMAX_SUPPLY_REQUEST_QTY=50 run bin/admin_server.dart
```

設定必須為正整數。這是全域「數量」上限，第一版不是每種物資或每個單位的個別上限；正式採用前應由管理中心選定合理值。

偵測在查詢審核清單或任何預留嘗試時執行，並非背景工作或新增需求時即時寫入。需求建立後仍為 pending。所有預留入口（包含原 reserveSupplyRequest、autoAssignSupplyRequest）都會重新偵測，因此不會因尚未開啟審核清單就自動放行。

## 查詢異常／待審核清單

```json
{"type":"getSupplyRequestReviews"}
```

可加 requestId 篩單筆。僅查 OFFICE001 的 pending 需求，無符合項目回空陣列。這支 POST 查詢會將發現的異常持久標記為 needs_review，不修改庫存或業務狀態。

```json
{
  "success":true,
  "data":[{
    "requestId":"REQ002",
    "userId":"U002",
    "itemId":1,
    "qty":7,
    "stationId":"OFFICE001",
    "status":"pending",
    "reviewStatus":"needs_review",
    "requiresReview":true,
    "anomalyReasons":[{
      "code":"INSUFFICIENT_STOCK",
      "message":"OFFICE001 可用庫存不足",
      "availableQty":3,
      "requestedQty":7
    }],
    "flaggedReasons":[{
      "code":"INSUFFICIENT_STOCK",
      "message":"OFFICE001 可用庫存不足",
      "availableQty":3,
      "requestedQty":7
    }],
    "maxRequestQty":100,
    "reviewedBy":null,
    "reviewedAt":null,
    "reviewNote":null
  }]
}
```

anomalyReasons 是目前重新計算的異常；flaggedReasons 是目前或上次標記原因。疑似重複的原因另有 relatedRequestIds 陣列，超量原因有 limit。先前標記後，即使補貨或其他需求結案使目前異常消失，requiresReview 仍為 true，必須人工核准，不能回頭用一般批次預留繞過。

無異常且未標記者回 reviewStatus=not_required、requiresReview=false；not_required 是此 API 的計算結果，不會回填所有歷史資料。一般需求查詢的 reviewStatus=null 代表沒有持久審核標記，不能直接當作已檢查通過，UI 須搭配本 API 取得即時判斷。

## 人工審核 API

```json
{
  "type":"reviewSupplyRequest",
  "requestId":"REQ002",
  "decision":"approve",
  "note":"已電話確認為追加需求，核准例外數量"
}
```

僅有效管理員可用，note 必須非空。只接受 OFFICE001、pending、沒有義工認領痕跡的需求。

approve 會在同一交易內重新計算異常、重新檢查庫存與狀態、預留數量並寫入審核紀錄。成功後直接是 reserved，不是「approved 的 pending 等待再次預留」。若仍有硬性異常回 409，標記 needs_review，不變更庫存，也不記成已核准。

```json
{
  "success":true,
  "message":"審核處理完成",
  "data":{
    "requestId":"REQ002",
    "stationId":"OFFICE001",
    "stationName":"管理中心",
    "distanceKm":null,
    "availableQtyBeforeReserve":10,
    "status":"reserved",
    "reviewStatus":"approved",
    "reviewedBy":7,
    "reviewedAt":"2026-11-10T06:00:00.000Z",
    "reviewNote":"已電話確認為追加需求，核准例外數量",
    "reviewReasons":[{
      "code":"DUPLICATE_OPEN_REQUEST",
      "message":"同一使用者對同一物資有其他未結案需求",
      "relatedRequestIds":["REQ001"]
    }]
  }
}
```

時間、管理員、庫存及需求 ID 皆為範例。可用 decision=defer 暫緩；狀態仍 pending、reviewStatus=needs_review，記錄管理員、時間、備註，不預留、不拒絕。其他 decision 不接受。沒有新增拒絕、刪除、修正需求資料或強制忽略庫存的 API。

## Schema 與原 API 相容性

supply_requests 僅新增 nullable 欄位：reviewStatus（needs_review/approved）、reviewReasons（JSON TEXT）、reviewedBy INTEGER、reviewedAt TEXT、reviewNote TEXT。不回填歷史紀錄，不新增業務狀態，不改 Station Transfer。

getSupplyRequestDetails、getRequestsByAdmin 保留原有欄位，額外回傳這五欄。上述兩支的 reviewReasons 是資料庫原始 JSON 字串或 null；本文件的審核 API 回傳結構化陣列。reviewReasons 是最近一次標記／審核快照，欄位不是完整稽核事件表，暫緩後再核准會保存最後一次審核資訊。

一般單筆預留正常成功的回應格式不變；異常則拒絕並持久標記，這是防止繞過審核的必要行為變更。既有單筆出庫／完成格式、庫存及歷史義工保護沿用方案 A。

## UI 組員待串接

1. 在需求清單呼叫 getSupplyRequestReviews，依 requestId 合併判斷資訊。增加「需人工審核」「無需審核」篩選；已預留清單可依持久 reviewStatus 篩人工核准紀錄。
2. 增加全選／多選，按狀態提供批次預留、批次出庫、批次完成，最多 100 筆；needs_review 不應提供一般預留快捷操作。
3. 顯示異常原因、相關重複需求編號、目前可用量、上限；使用「疑似／待核對」，不得顯示為自動拒絕。
4. 增加「人工核准並預留」「暫緩」與必填備註。核准成功後立即重新查需求與庫存，不要再呼叫預留一次。
5. 批次完成顯示成功／失敗數與逐筆原因，保留失敗項供核對；不可因外層 success=false 就假設所有成功項都未變更。
6. 所有新 API 帶 Bearer Token；401 要求重新登入。重試前刷新資料，只重試失敗項。UI 不自行加減庫存或覆寫 SQLite 狀態。

## 正式資料庫切換前

本次不啟動正式 init 或 Migration，不重啟正式 Server。新程式仍需先在獨立副本驗證 additive Migration；正式更新前先停止寫入並建立一致性備份，再部署新版本。舊 pending 資料可能因新規則被要求審核，這是刻意保護，不應大量回填 approved。舊 claimed/dispatched/completed 不由本次審核 API 轉換。

## 實際驗證（2026-11-10）

- `dart test test/supply_batch_review_test.dart`：新增 11 項全通過，包含實際 loopback HTTP、獨立 SQLite 連線競爭、重新開啟 SQLite 持久化及 Trigger 注入寫入失敗。
- 較早執行的定向回歸 `dart test test/supply_batch_review_test.dart test/office_supply_request_test.dart test/offline_delivery_test.dart test/station_lookup_test.dart`：當時 33 項全通過；之後新增第 11 個並行審核測試，已由完整回歸與上述單檔驗證。
- `dart test`：73 項通過，1 個既有載入失敗：空白 test/admin_server_test.dart 缺 main。未修改該無關檔案。方案 A、舊 API、第一階段庫存、Station Transfer 及隔離 Server 重啟情境通過。
- `dart analyze`：exit 0，無 error／warning，2 個既有 info（admin_server.dart 不必要字串跳脫、healthReport.dart 檔名格式）。本次新增的提示已修正。
- 兩個原庫存測試使用的多筆需求改為不同測試使用者，避免新重複偵測規則干擾原本庫存競爭目的；疑似重複需求的拒絕／人工核准另有專門測試，未停用規則。
- 所有資料庫均為記憶體或臨時目錄測試資料，未在正式 admin.db 執行任何寫入或 Migration，未改 Flutter UI，未 Commit／Push。
