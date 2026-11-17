# 第一階段：OFFICE001 單一庫存入庫與查詢

本階段只改 getInventory / addInventory / updateStock。
不修改 supply_request_service、Station Transfer、義工流程、Flutter UI 或正式資料庫。
既有 Schema 已支援此方案，不需要 Migration，也不搬移或加總既有數量。

## 唯一有效數量

- inventory 保留主檔 id（itemId）、name、category、unit、neededQty 等。
- 這三支 API 的實際庫存與預留量只取 station_inventory 的 OFFICE001。
- 既有 inventory.stockQty / reservedQty 不被新增或補貨更新。
- 新主檔的舊 stockQty / reservedQty 欄位寫 0，入庫量只寫 OFFICE001。
- 主檔存在但 OFFICE001 庫存列不存在時，查詢數量明確為 0；其他據點或舊總庫存都不作 fallback。

## getInventory

POST 至原本 API 根網址，Header `Content-Type: application/json`：

```json
{"type":"getInventory"}
```

HTTP 200 範例（測試數值）：

```json
{
  "success":true,
  "data":[{
    "id":1,
    "name":"泡麵",
    "category":"食品飲水",
    "unit":"箱",
    "stockQty":5,
    "reservedQty":1,
    "availableQty":4,
    "neededQty":4,
    "updatedAt":"2026-10-20T00:00:00.000Z"
  }]
}
```

保留原有 id / name / category / unit / stockQty / reservedQty / neededQty / updatedAt，新增 availableQty。
現有 SupplyItem.fromJson 支援 id，Repository 仍讀 success / data，不需變更回應解析方式。
availableQty = OFFICE001.stockQty - OFFICE001.reservedQty，不用舊總量或前端夾制後的數量替代。
stock/reserved/available 缺據點列時都是 0，updatedAt 此時使用主檔時間。
排序為主檔 id。

## addInventory

```json
{"type":"addInventory","name":"泡麵","category":"食品飲水","unit":"箱","stockQty":3,"neededQty":0}
```

`stockQty` 雖沿用舊名稱，語意是「本次入庫量」，不是設定總庫存。
name / category / unit 必須是非空字串（去除頭尾空白），stockQty 必須是正整數 JSON number。
neededQty 可省略或 null，預設 0；提供時必須為非負整數。

- 三個主檔欄位 name / category / unit 完全相同：增加該 itemId 的 OFFICE001 庫存。
- 同名不同單位或分類：建立獨立 itemId，不換算也不合併。
- 完全相同主檔已有多筆：409，要求先核對，不任選 itemId。
- 保留舊 neededQty 的累加語意，未提供則加 0；這不是第二套實際庫存。
- 主檔建立／更新與 OFFICE001 入庫在同一個 BEGIN IMMEDIATE 交易；失敗整筆回滾。
- 來源據點 OFFICE001 不存在則拒絕，不自行建立據點或示範資料。

成功格式維持 HTTP 200：

```json
{"success":true,"message":"Inventory added"}
```

此回應沒有 itemId 或新總量，成功後重新 getInventory 取得後端結果。

## updateStock

```json
{"type":"updateStock","itemId":1,"qty":3}
```

itemId / qty 必須為正整數 JSON number。qty 是本次入庫量。
以原子加法增加 OFFICE001；不存在該品項據點列時，從本次量建立，不帶入舊 inventory 數量。
不變更 reservedQty，不變更 S001 / S002。

成功格式維持 HTTP 200：

```json
{"success":true,"message":"Stock updated"}
```

handler 等待交易完成才回成功。成功後重新 getInventory；不在前端自行覆蓋總庫存。
getStationInventory(OFFICE001) 的數量與這支查詢一致，但後者包含 category / neededQty 等舊 UI 欄位。

## 錯誤

統一 `{"success":false,"message":"原因"}`：

- 400：缺必填、空字串、數量為 0／負數／小數／字串／布林、neededQty 不合法。
- 404：updateStock 的 itemId 不存在。
- 409：缺 OFFICE001、完全重複主檔、庫存／需求量異常或整數溢位。
- 500：未預期的資料庫錯誤；交易回滾，不能回報成功。

## 測試與後續限制

新增 `test/office_inventory_test.dart`，涵蓋 12 項案例：
2+3=5、連續入庫、新主檔、同名不同單位／分類、缺庫存列為 0、完全重複主檔、錯誤數量、
缺主檔／據點、溢位／異常量、SQL 失敗回滾、4 連線共 100 次並行入庫、HTTP 格式與失敗回應。
獨立記憶體／暫存 DB，未開啟正式 admin.db。

第一階段尚未解決以下項目，不能宣稱整套單中心流程完成：

1. 舊 allocate / dispatch 仍寫 inventory 舊數量，getInventory 已不再顯示這些欄位。
   在第二階段切換前不要將舊分配按鈕當成 OFFICE001 的出庫入口。
2. 自動分配仍找 shelter；義工預設仍是 S001。下一階段須將新需求與義工站點統一 OFFICE001。
3. 現有 Station Transfer 保留且仍可移出 OFFICE001，本階段未停用或改其邏輯。
4. seedStationInventory 仍為舊三據點拆分示範邏輯；本階段不改 Seed、不遷移正式數量。
5. 舊 deleteInventory 及其他未切換的查詢／Service 需另行盤點，避免不完整關聯檢查。
6. UI 同名提示目前只按名稱找物資，若「包」被使用者選成舊「箱」itemId 的 updateStock，
   後端只收到 itemId + qty，無法知道原本想輸入的單位。UI 第二階段須按 itemId／名稱+分類+單位選取。
7. 入庫沒有冪等鍵；相同請求重送仍會再入庫一次，請勿盲目重試逾時的寫入。
8. 最終正式切換前需另行備份與盤點現有三據點數量、預留與未完成單據；不能把兩套帳直接相加。
