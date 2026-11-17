# 第二階段：物資需求與義工配送統一 OFFICE001

## 範圍

新需求以 OFFICE001 為唯一據點，實際庫存／預留量使用 station_inventory。
inventory 只提供物資主檔。沒有正式 DB Migration，也沒有修改 Flutter UI 或 Station Transfer。

新需求與庫存邏輯使用同步 BEGIN IMMEDIATE 交易；預留／狀態寫入、取貨／扣量一併提交或回滾。
沒有在資料庫交易內 await，因此同連線不會因 await 交錯而重複開始交易。

## 新需求

```json
{"type":"addSupplyRequest","requestId":"REQ_OFFICE_001","userId":"U001","itemId":1,"qty":3}
```

成功回應沿用：

```json
{"success":true,"message":"request saved"}
```

- SQLite 新增列的 stationId 固定 OFFICE001；傳入 S001／S002 不會改變來源。
- itemId / qty 必須是正整數；requestId / userId 不可空白。
- 新需求狀態仍是 pending，不會在建立時自動預留。
- 不需要 GPS 才能選擇管理中心；lat/lng 仍可保留給最後一段配送定位。
- getSupplyRequestDetails 回應欄位保留，stationId / stationName 能顯示 OFFICE001。
- seedSupplyRequests 僅為未來新插入的示範需求加入 OFFICE001，原有非空資料與歷史需求不覆寫。

## 指派／預留

```json
{"type":"autoAssignSupplyRequest","requestId":"REQ_OFFICE_001"}
```

成功回應範例：

```json
{
  "success":true,
  "message":"supply request automatically assigned",
  "data":{
    "requestId":"REQ_OFFICE_001",
    "stationId":"OFFICE001",
    "stationName":"物資中心",
    "distanceKm":null,
    "availableQtyBeforeReserve":10,
    "status":"reserved"
  }
}
```

stationName 取 stations 實際名稱。保留 distanceKm 欄位，但不再計算距離，因此是 null；前端不要把它顯示成實際 0 公里。
也可呼叫原 reserveSupplyRequest（只需 requestId）；兩支都執行同一套 OFFICE001 預留，不要各呼叫一次。
只有 pending 可預留，重複呼叫拒絕且不再增加 reservedQty。
舊 pending 且 stationId 為 null 的需求，只有明確呼叫此操作才指派 OFFICE001，不做批次改寫。
舊 pending 已指定 S001／S002 則拒絕重新預留，需先人工核對，不能偷偷搬移據點。

## 義工動作

新任務共用請求欄位：

```json
{"type":"claimSupplyRequest","requestId":"REQ_OFFICE_001","volunteerId":"V001","stationId":"OFFICE001"}
```

依操作替換 type：

| type | 允許狀態轉換 | 庫存變動 |
|---|---|---|
| claimSupplyRequest | reserved → claimed | 無 |
| cancelSupplyRequestClaim | claimed → reserved | 無；物資仍保留給該需求 |
| dispatchSupplyRequest | claimed → dispatched | 實際庫存與預留量各減 qty |
| completeSupplyRequest | dispatched → completed | 無；寫入 completedAt |

請勿用舊 type=dispatch 作為義工取貨。
認領回應仍為 success / message / requestId / volunteerId。
取貨回應仍為 success / message / data，data 含 requestId / stationId / itemId / itemName / unit / qty / status。
完成回應的 data 仍為 requestId / status；完成時間可從 getVolunteerHistory 查詢。
重複取貨、重複完成、跳過階段、錯誤義工／據點、庫存不足均回 success=false，不扣第二次。
既有 handler 的 HTTP 錯誤碼保持原行為：義工與 reserve 通常為 400，autoAssign 的例外仍為 500；UI 必須解析 success / message，不能只看訊息文字。

## 任務查詢

```json
{"type":"getPendingSupplyRequests","stationId":"OFFICE001"}
```

回傳 reserved 的需求，欄位及 success/data 格式維持。

```json
{"type":"getVolunteerClaims","volunteerId":"V001","stationId":"OFFICE001"}
```

保留原有欄位，查詢擴大為 claimed / dispatched / completed，避免取貨後任務從「我的配送」消失。
UI 可依 status 分組或過濾；getVolunteerHistory 仍專門回 completed 與 completedAt。

## 庫存例子

| 動作 | stockQty | reservedQty | availableQty |
|---|---|---|---|
| 初始 | 10 | 0 | 10 |
| 預留 3 | 10 | 3 | 7 |
| 認領 | 10 | 3 | 7 |
| 確認取貨 | 7 | 0 | 7 |
| 配送完成 | 7 | 0 | 7 |

完成後或重啟後再次呼叫取貨／完成，不會再扣庫存。入庫繼續沿用第一階段 addInventory / updateStock。

## 舊寫入防護（已先列出 UI 影響並取得使用者同意）

預設封鎖 allocate / dispatch / cancelAllocation，回 HTTP 409：

```json
{"success":false,"message":"單中心模式已停用舊 allocate/dispatch 寫入，請使用物資需求與義工取貨流程"}
```

沒有刪除程式或歷史資料；getAllocations / getDispatches 仍可查詢。
DatabaseService 的 allocate / dispatch，以及舊 AllocationService / DispatchService 寫入也受同一個開關保護。

恢復舊寫入僅供明確回復／維護需求，在 admin_server 工作目錄使用 Dart define 並重新啟動：

```powershell
dart -DALLOW_LEGACY_INVENTORY_WRITES=true run bin/admin_server.dart
```

這是 Dart 編譯／執行定義，不是 HTTP 參數，也不是單純設定作業系統環境變數。
不帶此定義即預設封鎖。開啟只恢復舊寫入，**不會**將新需求改回多據點，也不會同步兩套庫存。
測試已驗證開關生效，沒有為此重啟正式服務。

## 歷史資料界線

- 不改寫既有 S001／S002 任務的 stationId、狀態或預留。
- 已預留／已認領的舊任務可按其原據點繼續；這是維持既有任務的相容路徑，不是新任務的據點選擇。
- 舊任務不允許由 OFFICE001 義工參數冒用，也不會改扣 OFFICE001 庫存。
- Station Transfer 完整保留；若繼續建立移出 OFFICE001 的單據，仍會占用／扣除其庫存，需由產品流程另行停用入口。

## 尚未整合的 UI

1. VolunteerPage / VolunteerViewModel 的預設 stationId 仍為 S001，需由 UI 組員改 OFFICE001。
2. 管理頁的 S001/S002 寫死選單、據點篩選與庫存快取要改為單一管理中心。
3. SupplyPage.allocate() 仍是舊 allocate 後自動 dispatch；現在會得到預期的 409，不會改舊庫存。
4. 管理頁舊 dispatchRequest() 只送 requestId，必須補 volunteerId / stationId 才能取貨；本次不代改 UI。
5. 新需求建立 pending 後，要明確呼叫一次 autoAssignSupplyRequest 或 reserveSupplyRequest，才能進入義工待認領清單。
6. 狀態按後端結果刷新；不要再在 UI 端額外扣量，也不要混用 allocationId 與 requestId。

## 正式切換前

先唯讀盤點歷史 pending／reserved／claimed／dispatched 任務、據點預留與未完成 Station Transfer。
不能把舊 inventory 數量與三據點數量直接相加，不能清零預留或批次改 stationId 來假裝完成遷移。
先建立一致性備份，再另行批准資料切換；本次沒有執行正式 Migration。
目前身分驗證／據點權限及任務取消等既有缺口沒有在這階段擴大修改。

## 驗證方式

- 新增 office_supply_request_test.dart：新需求、無 GPS 預留、完整流程、防重複、不足／跳階、SQL 回滾、歷史任務及 HTTP 相容性。
- 跨 isolate 各自開啟獨立 SQLite 連線，同張需求的預留／取貨／完成各只能成功一次。
- demo_acceptance_test.dart 增加預留／取貨／完成分階段重新啟動隔離服務，驗證狀態、completedAt 與庫存保存。
- 第一階段 office_inventory_test.dart 12 項持續驗證。
- 全部測試使用記憶體或全新暫存 SQLite，未開啟正式 admin.db。

實際執行結果：

- `dart test test/office_supply_request_test.dart test/office_inventory_test.dart --reporter expanded`：22 項全部通過（10 項需求／配送，12 項第一階段）。
- `dart test --reporter expanded`：44 項通過、1 個既有載入失敗；空白 test/admin_server_test.dart 缺 main()，整體 exit code 1。
- `dart analyze`：無 error / warning，兩項既有 info（伺服器字串跳脫、healthReport.dart 命名）。
- 初次跨 isolate 測試因 closure 捕捉 native SQLite 連線失敗；測試改成只傳字串並由各 isolate 開連線後已通過，沒有為此放寬交易檢查。
