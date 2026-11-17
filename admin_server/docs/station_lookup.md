# 據點清單與物資需求明細：UI 串接格式

沿用 POST 至後端根網址（本機例：http://localhost:8080），
Header `Content-Type: application/json`。

## getStations

```json
{"type":"getStations"}
```

HTTP 200 回應範例（數值為示意）：

```json
{
  "success": true,
  "data": [
    {"stationId":"OFFICE001","name":"物資中心","type":"office","lat":23.95,"lng":120.93,"address":"Demo 物資中心"},
    {"stationId":"S001","name":"A 收容中心","type":"shelter","lat":23.951,"lng":120.927,"address":"Demo A 收容中心"},
    {"stationId":"S002","name":"B 收容中心","type":"shelter","lat":23.96,"lng":120.94,"address":"Demo B 收容中心"}
  ]
}
```

回傳 stations 原有欄位，依 stationId 排序；空表回 `data: []`。
UI 下拉選单顯示 name，傳給其他 API 的識別值使用 stationId。
資料庫錯誤回 HTTP 500：
`{"success":false,"message":"據點查詢失敗，請檢查伺服器記錄"}`。

## getSupplyRequestDetails

```json
{"type":"getSupplyRequestDetails"}
```

HTTP 200 回應範例（示意已指派需求）：

```json
{
  "success": true,
  "data": [{
    "requestId":"EXAMPLE001",
    "userId":"U001",
    "itemId":1,
    "itemName":"泡麵",
    "unit":"箱",
    "qty":10,
    "lat":23.95,
    "lng":120.93,
    "receiverAdminId":"admin_ncnu",
    "hopCount":0,
    "status":"reserved",
    "createdAt":"2026-10-13T00:00:00.000Z",
    "receivedAt":"2026-10-13T00:00:00.000Z",
    "address":null,
    "volunteerId":null,
    "claimedAt":null,
    "stationId":"S001",
    "stationName":"A 收容中心"
  }]
}
```

原有 16 個欄位、inventory JOIN 及建立時間排序保持不變。
只新增 `sr.stationId` 和 `st.name AS stationName`，使用 LEFT JOIN stations。
尚未指派：stationId / stationName 都是 null；UI 應顯示「尚未指派」。
有 stationId 但對應 stations 不存在：保留 stationId，stationName 為 null，需求不因據點 JOIN 消失。
此查詢不執行自動指派，也不更改庫存或需求狀態。

## 正式資料唯讀檢查結果

本次以 SQLite URI `mode=ro` 並設定 `PRAGMA query_only=ON` 查詢；沒有寫入正式 DB。

| requestId | status | stationId |
|---|---|---|
| UI_STATION003 | pending | NULL |
| UI_STATION004 | pending | NULL |

上述識別值是 requestId，不應拿來當 stationId。
正式資料目前尚未指派據點；新增回傳欄位不會自動補上 S001 / S002。

## 本次驗證

`dart test test/station_lookup_test.dart test/station_transfer_test.dart`：15 項通過。
包含舊欄位／值、未指派需求、遺失據點、空清單、HTTP 路由及錯誤處理。
全部使用 sqlite3.openInMemory()，不呼叫 DatabaseService.init() 或 seed。
`dart analyze`：無 error / warning，兩項既有 info（字串跳脫及 healthReport.dart 命名）。
本次未重跑完整 `dart test`；既有空白 admin_server_test.dart 缺少 main 的問題未修改。
未修改 Flutter UI、登入、調度或義工配送；沒有新增或修改資料表。
