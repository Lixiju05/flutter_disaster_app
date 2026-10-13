# 物資中心 → 收容中心調度 API

所有操作沿用 POST + JSON `type`，例如 `http://localhost:8080`。
Header：`Content-Type: application/json`。

## 範圍與身分驗證限制

來源固定 OFFICE001（可省略 fromStationId），目的允許 S001 或 S002。
只更新 `station_inventory`；不更新舊 `inventory` 總量、`allocations`、災民需求或義工配送。
目前登入沒有後端 Token 驗證或據點權限機制，本次依要求不修改登入。
`createdBy` 是呼叫者提供的稽核文字，**不是已驗證的管理員身分**。
本批 API 與現有 API 一樣尚未受後端身分驗證保護，不能宣稱已具管理員授權。

## 資料表與遷移

`DatabaseService.init()` 以 CREATE TABLE IF NOT EXISTS 新增 `station_transfers`，
包含 transferId（伺服器 UUID）、fromStationId、toStationId、itemId、qty、status、
createdBy、createdAt、shippedAt、receivedAt，及來源／目的與狀態查詢索引。
時間使用 UTC ISO 8601（Z）；前端顯示時可轉為臺灣時間。
不刪除或重建任何既有表，不手動修改現有 DB。
注意：原本 init() 仍會執行既有 seedAll()，本次未修改該初始化行為。

## 1. 建立調度

```json
{"type":"createStationTransfer","fromStationId":"OFFICE001","toStationId":"S001","itemId":1,"qty":10,"createdBy":"admin_ncnu"}
```

itemId、qty 必須是正整數 JSON number，不能是字串或小數。
成功 HTTP 200：

```json
{"success":true,"message":"調度已建立，來源庫存已預留","data":{"transferId":"<UUID>","fromStationId":"OFFICE001","toStationId":"S001","itemId":1,"qty":10,"status":"reserved","createdBy":"admin_ncnu","createdAt":"2026-10-13T00:00:00.000Z","shippedAt":null,"receivedAt":null}}
```

只增加來源 reservedQty，目的庫存不動。

## 2. 出貨

```json
{"type":"shipStationTransfer","transferId":"<UUID>"}
```

成功 HTTP 200：`{"success":true,"message":"已確認出貨，目的據點尚未入庫","data":{...}}`。
data 包含上述完整單據欄位，status 改為 shipped、shippedAt 寫入實際時間。
來源 stockQty、reservedQty 各減 qty；目的不動。

## 3. 收貨

```json
{"type":"receiveStationTransfer","transferId":"<UUID>"}
```

成功 HTTP 200：`{"success":true,"message":"已確認收貨，目的據點庫存已增加","data":{...}}`。
data 包含完整單據欄位，status 改為 received、receivedAt 寫入實際時間。
只增加目的 stockQty，保留其原有 reservedQty。
若目的尚無此品項庫存列，收貨時新增該列（reservedQty = 0）。

## 4. 查詢

```json
{"type":"getStationTransfers","stationId":"S001","status":"shipped"}
```

stationId、status 都可省略。stationId 同時匹配來源或目的；status 只能是
reserved、shipped、received。傳入不存在據點回 404。
成功 HTTP 200：

```json
{"success":true,"message":"查詢成功","data":[{"transferId":"<UUID>","fromStationId":"OFFICE001","toStationId":"S001","itemId":1,"qty":10,"status":"shipped","createdBy":"admin_ncnu","createdAt":"2026-10-13T00:00:00.000Z","shippedAt":"2026-10-13T00:10:00.000Z","receivedAt":null,"fromStationName":"物資中心","toStationName":"A收容中心","itemName":"泡麵","unit":"箱"}]}
```

新到舊排列，無紀錄 data = []。紀錄不被刪除。

## 錯誤

統一 `{"success":false,"message":"原因"}`：

- 400：缺少必填、數量不是正整數、相同據點、不允許的來源／目的、非法狀態篩選。
- 404：調度單、允許的據點或物資不存在。
- 409：庫存不足或異常、重複出貨／收貨、未出貨直接收貨。
- 500：未預期的資料庫錯誤；交易回滾，詳細錯誤在伺服器記錄。

建立、出貨、收貨均在 BEGIN IMMEDIATE Transaction 內執行。
重試相同出貨／收貨回 409，庫存不再次變動。
建立請求每次成功都產生新單據：網路回應遺失時先查紀錄，避免盲目重送建立。

## Postman 完整流程

1. 在 admin_server 目錄啟動 `dart run bin/admin_server.dart`（沿用既有初始化流程）。
2. 用唯讀 SQL 先確認現有 itemId 及 OFFICE001 可用數量，勿假設 itemId 1 一定是泡麵。
3. POST 建立範例，記下 data.transferId；Postman Tests 可使用：
   `pm.environment.set('transferId', pm.response.json().data.transferId);`
4. 出貨與收貨請求使用 `"transferId":"{{transferId}}"`。
5. 每個階段執行下列唯讀 SQL 驗證；出貨前直接收貨、重複出貨與收貨都應為 409。
6. 查詢 `getStationTransfers` 的 S001 / received 應看見完成紀錄。

```sql
SELECT si.stationId, si.itemId, i.name,
       si.stockQty, si.reservedQty,
       si.stockQty - si.reservedQty AS availableQty
FROM station_inventory si JOIN inventory i ON i.id = si.itemId
WHERE si.stationId IN ('OFFICE001', 'S001') AND si.itemId = 1;

SELECT * FROM station_transfers ORDER BY createdAt DESC;
```

在來源 50/0、目的 20/5，調度 10 的前提下：

| 階段 | OFFICE001 實際/預留/可用 | S001 實際/預留/可用 |
|---|---|---|
| 建立 | 50/10/40 | 20/5/15 |
| 出貨 | 40/0/40 | 20/5/15 |
| 收貨 | 40/0/40 | 30/5/25 |

不為了測試改寫現有庫存；自動測試在記憶體中準備上述數值。
UI 組員應以 station_inventory 作為據點庫存來源，不能使用 getInventory 當作據點庫存。

## 5. 指定據點庫存查詢

```json
{"type":"getStationInventory","stationId":"S001"}
```

stationId 必填且必須為非空字串。成功 HTTP 200，data 是物資清單：

```json
{"success":true,"message":"據點庫存查詢成功","data":[{"stationId":"S001","itemId":1,"itemName":"泡麵","unit":"箱","stockQty":30,"reservedQty":5,"availableQty":25,"updatedAt":"2026-10-13T00:20:00.000Z"}]}
```

直接讀取 station_inventory 並與 inventory 連接取得名称／單位。
availableQty = stockQty - reservedQty；僅列出該據點已有的品項。
有效據點沒有品項回 data = []；不存在的據點回 404；缺少、空白或非字串 ID 回 400。
收貨後重新查詢即反映增加的庫存；運送中不提前增加。
尚未收貨及已收貨的調度紀錄用 getStationTransfers 的 stationId / status 篩選。
本次仍未修改 UI 或登入架構；此查詢沿用既有 API 的身分驗證限制。

## 自動測試

在 admin_server 執行 `dart test test/station_transfer_test.dart`、`dart analyze`。
測試使用 sqlite3.openInMemory()，不呼叫 DatabaseService.init()，不碰現有資料庫或 seed。
