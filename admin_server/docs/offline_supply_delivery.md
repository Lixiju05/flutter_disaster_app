# 方案 A：管理中心線下協調配送

新流程為 pending → reserved → dispatched → completed。不經 claimed、不需要 volunteerId、不使用義工指派。OFFICE001 的 station_inventory 仍是唯一新流程庫存來源，inventory 保留物資主檔。Station Transfer 與歷史資料保留。

## 現況與最小修改

原供應需求已有 requestId、qty、stationId、status、volunteerId、claimedAt、completedAt 等欄位。原義工取貨要求 claimed 與 volunteerId，無法直接作為管理員出庫入口。新的管理員入口獨立加入，不更改歷史任務狀態。

supply_requests 只增加四個 nullable 欄位：reservedAt TEXT、dispatchedAt TEXT、dispatchedBy INTEGER、completedBy INTEGER。completedAt 沿用；既有欄位及資料不刪除、不回填。dispatchedBy 記錄 Session 中的 admins.id，也作為新出庫流程的識別。出庫與完成可以由不同的有效管理員操作。

DatabaseService.ensureSupplyRequestSchema 的相容性 Migration 可重跑。生產 init 會呼叫它，但本次開發未啟動正式 init、未更新正式資料庫。

## API 呼叫

沿用 POST 根路徑、Content-Type: application/json 與 type 路由。管理員先呼叫既有 login，以回傳 token 作為下列兩支 API 的 Header：

```http
Authorization: Bearer <login 的 token>
```

Session 是既有記憶體 Session，有效 8 小時，Server 重啟後需重新登入。Token 對應的 admins 帳號必須仍存在；不信任請求中的 adminId。其他原有 API 的授權方式不在本次修改範圍。

### 需求與預留

原 addSupplyRequest 格式不變，新需求固定 OFFICE001。確認需求／預留沿用：

```json
{"type":"reserveSupplyRequest","requestId":"REQ001"}
```

原 autoAssignSupplyRequest 也仍可用，現行實作固定 OFFICE001，不再依 GPS 尋找收容所。預留成功會寫 reservedAt，不修改實際庫存；重複預留拒絕。不需要先認領。

### 確認出庫

```json
{"type":"adminDispatchSupplyRequest","requestId":"REQ001"}
```

stationId 可省略；若提供，僅接受 OFFICE001。不要傳 volunteerId。adminId、dispatchedBy 等操作人欄位不從請求採用。

成功 HTTP 200 範例（ID、時間為示意）：

```json
{
  "success":true,
  "message":"出庫成功",
  "data":{
    "requestId":"REQ001",
    "stationId":"OFFICE001",
    "itemId":1,
    "qty":3,
    "status":"dispatched",
    "dispatchedAt":"2026-11-08T06:00:00.000Z",
    "dispatchedBy":7
  }
}
```

僅接受 OFFICE001、reserved、沒有任何義工認領／指派或出庫／完成紀錄的任務。交易內使用條件式原子減法：stockQty -= qty、reservedQty -= qty，再更新狀態與操作紀錄。數量必須是正整數；庫存及預留須為整數、足夠且一致。任一步失敗全部 ROLLBACK。

### 登記配送完成

```json
{"type":"adminCompleteSupplyRequest","requestId":"REQ001"}
```

成功 HTTP 200 範例：

```json
{
  "success":true,
  "message":"配送完成",
  "data":{
    "requestId":"REQ001",
    "stationId":"OFFICE001",
    "status":"completed",
    "completedAt":"2026-11-08T07:00:00.000Z",
    "completedBy":8
  }
}
```

只接受新管理員 API 已出庫的任務，必須有 dispatchedAt、dispatchedBy，且沒有義工資料或既有完成紀錄。交易只改狀態、completedAt、completedBy，不改庫存。不能跳過出庫或重複完成。

### 錯誤格式

```json
{"success":false,"message":"需要有效的管理員 Bearer Token，請重新登入"}
```

| HTTP | 情況 |
|---|---|
| 401 | 沒有、無效或過期的 Token |
| 403 | Session 所屬管理員已不存在 |
| 400 | requestId 缺少／型別不符，或提供非 OFFICE001 的 stationId |
| 409 | 任務不存在、狀態不符、歷史義工任務、重複操作、庫存／預留不足或寫入失敗 |

遇到失敗須重新讀取後端結果；不得只在 UI 改狀態或補扣數量。

## 狀態與庫存

以初始 stockQty=10、reservedQty=0，需求 qty=3 為例：

| 階段 | status | stockQty | reservedQty | availableQty |
|---|---|---:|---:|---:|
| 新需求 | pending | 10 | 0 | 10 |
| 確認／預留 | reserved | 10 | 3 | 7 |
| 線下安排配送人員 | reserved | 10 | 3 | 7 |
| 確認出庫 | dispatched | 7 | 0 | 7 |
| 配送完成 | completed | 7 | 0 | 7 |

線下安排沒有額外 API 或狀態。出庫與完成不得再呼叫舊義工取貨／完成來處理同一任務。

## 查詢及 UI 需要調整

getSupplyRequestDetails、getRequestsByAdmin 保留原回應外層與欄位，補回 reservedAt、dispatchedAt、dispatchedBy、completedBy，completedAt 原樣保留。新欄位在歷史資料可能為 null，不可填入目前時間假裝是舊事件時間。

- 需求確認：pending 時顯示「確認需求並預留」。
- reserved：顯示「已預留／待出庫」、「確認出庫」按鈕，無須義工 ID。任務的預留數量依 qty 及狀態顯示；station_inventory.reservedQty 是該物資全部任務及其他預留的總量，不是單筆需求的數量。
- dispatched：顯示「已出庫／配送中」、出庫時間與「登記配送完成」按鈕。
- completed：顯示完成時間，停用重複操作。
- 新流程不顯示義工 ID、認領時間、指派方式。移除義工 Demo 入口及新任務的認領／指派操作。
- 兩個新按鈕都帶登入 Token；401 要求重新登入，409 重新載入任務。
- 庫存顯示使用 getStationInventory，stationId=OFFICE001；UI 不自行覆蓋庫存。
- 舊 claimed、舊 dispatched 等歷史任務應顯示「舊流程／待人工核對」，不提供本次新出庫／完成按鈕。

本次未修改 Flutter UI，因此現有畫面尚不會自動變成上述按鈕。

## 歷史資料與切換前注意事項

1. 不自動把 claimed 改 reserved，也不清空 volunteerId、claimedAt、assignmentType 或 assignedBy。新 API 遇到這些資料會拒絕。
2. 舊 dispatched 可能已扣過庫存，嚴禁再次出庫。即使沒有 volunteerId，只要沒有本次新出庫的 dispatchedBy／dispatchedAt，新的完成 API 也拒絕。
3. 先核對舊任務、實際庫存及預留，再決定是否沿用受控的舊流程完成，或另行設計帶稽核的結案／取消工具。本次沒有實作改派、轉換或管理員強制結案。
4. 原義工 API 保留且仍可呼叫，沒有宣稱已全面停用。它們不再是新流程必要步驟；若仍使用舊入口，可能搶先認領 reserved 任務，新管理員出庫會安全拒絕，不會雙重扣量。正式切換時須移除舊 UI 入口；若要從伺服器全面封鎖舊寫入，需另行規劃歷史任務的收尾與可回復開關。
5. 舊 reserved 且無義工／出庫痕跡的 OFFICE001 任務，新 API 可在管理員明確操作後出庫，並不會自動出庫。操作前須人工核對既有預留；目前系統沒有獨立逐筆預留帳本，僅有需求 qty/status 與 station_inventory 彙總預留量。
6. 正式切換前確認正確 admin.db 路徑、停止寫入並建立 SQLite 一致性備份；在副本先驗證相容性 Migration。Migration 僅 ADD COLUMN，不回填時間、不遷移庫存。不要將本次測試資料搬入正式資料庫。
7. 部署後需重新登入取得新程序的 Token。正式 Server 本次未重啟，正式 Migration 未執行。

## 實際驗證（2026-11-08）

- 定向測試指令：`dart test test/offline_delivery_test.dart test/station_lookup_test.dart test/office_supply_request_test.dart test/volunteer_assignment_test.dart test/office_inventory_test.dart`；44 項全部通過，其中本次新增 9 項。
- 使用記憶體 SQLite、系統臨時資料夾內獨立 SQLite、loopback 隨機 Port 的 HTTP Server；不使用正式 admin.db。
- 驗證完整 HTTP 新流程不傳 volunteerId、無效 Token 拒絕、偽造 adminId 不採用、已刪除管理員拒絕；Session 過期另由既有 SessionStore 單元測試驗證。
- 驗證重複預留／出庫／完成、跳過出庫、庫存／預留不足與異常數量拒絕；以 SQLite Trigger 強制狀態寫入失敗，確認出庫庫存及狀態全部回滾，完成失敗不留下部分紀錄。
- 驗證獨立連線競爭出庫／完成各僅一次成功，舊認領與新出庫競爭只有一方成功，重開 SQLite 後新操作人、時間及庫存保留。新線下流程的持久化驗證是重開 SQLite，並非額外重啟新流程 HTTP Server；完整回歸中原有隔離 Server 重啟情境也通過。
- `dart test`：62 項通過，1 個既存載入失敗；空白 `test/admin_server_test.dart` 缺少 main，未修改該檔。Station Transfer 與舊配送回歸情境通過。
- `dart analyze`：exit 0，沒有 error／warning；兩個既有 info 為 admin_server.dart 字串不必要跳脫、healthReport.dart 檔名格式。
