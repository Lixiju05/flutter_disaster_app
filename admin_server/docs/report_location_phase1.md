# 回報位置與時間保存：第一階段

本階段不執行逆地理編碼，沒有外部位置服務呼叫，不改 users.area、物資預留／配送或 Flutter UI。

## 寫入 API 相容性

沿用原 POST endpoint、Content-Type: application/json 與 type，不新增路由。原本成功／失敗回應格式不變。

| type | GPS 欄位 | 使用者事件時間 | 後端時間 |
| --- | --- | --- | --- |
| addEmergencyRequest | latitude、longitude | sentAt（nullable） | receivedAt |
| healthReport | lat、lng | reportTime（nullable） | receivedAt |
| addSupplyRequest | lat、lng | reportedAt（新增、nullable） | createdAt、receivedAt |

三種均接受 address（可省略或 null），原樣保存 App 提供的字串，不拿居住地址補值。地址不代表已經過驗證或轉換。

SOS 範例（ID 僅為示意，不可直接寫入正式環境測試）：

```json
{
  "type": "addEmergencyRequest",
  "emergencyId": "TEST_SOS_LOCATION_001",
  "userId": "TEST_USER",
  "userName": "測試使用者",
  "phone": "test",
  "latitude": 23.9876543210123,
  "longitude": 120.1234567890123,
  "address": "使用者提供的災時位置描述",
  "sentAt": "2026-11-10T12:00:00+08:00",
  "receiverAdminId": "admin_ncnu"
}
```

健康回報範例：

```json
{
  "type": "healthReport",
  "uuid": "TEST_HEALTH_LOCATION_001",
  "reporterId": "TEST_USER",
  "name": "測試使用者",
  "phone": "test",
  "status": "safe",
  "lat": 23.9876543210123,
  "lng": 120.1234567890123,
  "address": "使用者提供的災時位置描述",
  "reportTime": "2026-11-10T12:00:00+08:00",
  "receiverAdminId": "admin_ncnu"
}
```

物資需求範例（itemId 必須是測試資料庫內的品項）：

```json
{
  "type": "addSupplyRequest",
  "requestId": "TEST_SUPPLY_LOCATION_001",
  "userId": "TEST_USER",
  "itemId": 1,
  "qty": 1,
  "lat": 23.9876543210123,
  "lng": 120.1234567890123,
  "address": "使用者提供的災時位置描述",
  "reportedAt": "2026-11-10T12:00:00+08:00",
  "receiverAdminId": "admin_ncnu"
}
```

對應成功回應仍為：

```json
{"success":true,"message":"emergency request saved"}
```
```json
{"success":true,"message":"Saved"}
```
```json
{"success":true,"message":"request saved"}
```

新增欄位只用於位置與時間保存，不會自動核准、預留或扣庫存。重複 ID 維持既有 INSERT OR IGNORE 相容行為：仍回成功，但不覆寫原回報地址／座標／時間。

## 資料解析規則

- 有效 GPS 不四捨五入、不轉換網格；維持 JSON/Dart double 與 SQLite REAL 的浮點精度（不是任意精度小數）。
- 接受數字或可解析數字字串。緯度須介於 -90 至 90，經度介於 -180 至 180，且必須為有限值。
- 缺少、錯誤型別、NaN、Infinity、越界值分別保存為 null；單邊有效的座標仍保存，但不能用於彙整地圖位置。
- 明確傳入合法 (0,0) 會保留；不再把缺少 GPS 補成 (0,0)。歷史 (0,0) 無法可靠區分是否為舊預設值，不自動更改。
- 事件時間採 ISO 日期時間；不合法日期、錯誤型別或缺漏保存為 null，不用 DateTime.now() 代替。
- 建議 App 傳 ISO 8601 含 Z 或 +08:00。為相容舊資料，無時區 ISO 日期時間仍按現有 Dart 本地時間解讀；跨裝置可靠比較應提供時區。
- 後端強制生成 receivedAt，不信任 App 傳入的 receivedAt。離線延遲送達仍保留原 sentAt/reportTime/reportedAt。
- addSupplyRequest 的 createdAt 維持原本後端建立需求的時間；reportedAt 才是 App 提供的事件時間，不從 createdAt 或 reportTime 自動推測。
- SQLite 原有 SOS sentAt、健康 reportTime、三種 GPS/address 均無 NOT NULL 限制；不需重建資料表。

## 查詢與 UI 注意事項

- 原查詢欄位保留；getSupplyRequestDetails、getRequestsByAdmin 另帶 reportedAt，後者也帶 address。全欄位需求查詢亦取得新欄位。
- SOS latitude/longitude/sentAt、健康 reportTime 現在可能為 null。UI 不可直接強制轉成非空值，也不可顯示為「剛剛回報」或自行補 (0,0)。
- 健康查詢 getAllReports 與 getHealthReportsByAdmin 共用相同解析方式，包含 address、receivedAt；歷史無效 reportTime 在 Model 回應中為 null。
- 原始 Map 型查詢對歷史資料維持原值（包括曾保存的錯誤時間字串）；UI 仍需使用可失敗的時間解析。此次不清洗或回填歷史資料。
- getVictimDashboard 的 lat/lng/lastUpdatedAt 選取三種回報中「成對有效 GPS 且事件時間有效」的最新一筆，以實際時間先後比較（含時區），不再讓資料表順序覆蓋。
- dashboard 新增 address，必須與所選座標來自同一筆回報。相同事件時間保留先選取的有效位置，不以接收時間打破平手。
- 無有效可比較事件時，dashboard 位置、address、lastUpdatedAt 為 null；各回報原始有效 GPS 仍留在來源表，未刪除。
- 舊物資需求 reportedAt 為 null，不拿 createdAt/receivedAt 假裝 GPS 採樣時間，因此可能不再出現在「最新已知位置」；仍可從需求明細讀取原座標。
- users.area 只代表居住地址，本功能不讀它來推定災時位置。
- 現有健康/SOS UI Model 若有非空時間／座標假設，需由 UI 組另行調整。本次未修改 Flutter、也未宣稱 Flutter analyze 通過。

## Migration 與正式更新前注意

只有一個增補欄位：

```sql
ALTER TABLE supply_requests ADD COLUMN reportedAt TEXT;
```

此段只供說明，未對正式資料庫執行。沿用 ensureSupplyRequestSchema 的 PRAGMA 檢查，欄位存在則略過，可重複執行；歷史值保持 NULL，不搬移、推測或覆寫 createdAt/receivedAt，不重建表。

注意：未來啟動新版正式 Server 時，既有 init() 會呼叫 ensureSupplyRequestSchema，自動加入欄位。本次沒有啟動正式 Server。正式部署前應先停寫、建立 SQLite 一致性備份、確認實際 Schema 並安排受控更新；不要將這次獨立測試視為正式 Migration 已完成。

既有已經遺失的 address、被補成當下的歷史時間或預設 (0,0)，無法從現有資料可靠還原，本次不修寫歷史資料。

## 修改位置與測試

- bin/admin_server.dart：handleHealthReport、handleAddSupplyRequest；SOS handler 原本已接收 address 並生成 receivedAt，沿用不重寫。
- lib/core/models/emergency_request.dart：nullable GPS/sentAt、共享解析與 JSON。
- lib/core/models/healthReport.dart：nullable reportTime、GPS/時間解析與 SQLite row 解析。
- lib/core/models/supply_request.dart：nullable reportedAt 與 GPS 解析。
- lib/core/models/report_location.dart：新增純本機座標／事件時間解析工具，無外部網路呼叫。
- lib/database/database_service.dart：三種 INSERT、ensureSupplyRequestSchema、getRequestsByAdmin、getSupplyRequestDetails、getVictimDashboard、_rowToHealthReport。
- test/report_location_test.dart：獨立 SQLite、本機 HTTP、失敗注入與檔案重開測試。
- test/station_lookup_test.dart：保留舊欄位斷言，增列 nullable reportedAt。

每種回報使用單一 SQLite INSERT，地址、GPS、事件／接收時間同一 statement 原子保存，沒有額外副作用或多步庫存寫入。測試涵蓋 statement ABORT 回滾 trigger 副作用、外層交易整體回滾、HTTP 失敗不回成功；沒有新增批次回報 API。

測試結果以最終執行摘要為準。

最終實測結果：

- 新增位置保存測試 20 項全部通過（包含三種回報各自的 HTTP 寫入、缺漏／錯誤值、部分與零座標、重複 ID）。
- 完整 `dart test`：113 項通過、1 項既存載入失敗；失敗檔案為空白 `test/admin_server_test.dart`，缺少 main()。未修改該既存檔案，不將整體測試宣稱為全綠。
- `dart analyze`：exit 0，無 error/warning，仍有兩項既存 info（bin 的多餘字串跳脫、healthReport.dart 檔名格式）。
- `git diff --check`：本次相關 tracked 後端檔案無空白格式問題。
- 正式 admin.db 被其他程序占用，嘗試唯讀取得 SHA256 未成功，無法提供前後雜湊一致證明；未停止該程序、未對正式資料庫寫入或執行 Migration。所有寫入測試均在記憶體／臨時資料庫。
- 未呼叫正式 Firebase、任何地理編碼服務，未修改 Flutter UI，未 Commit/Push。
