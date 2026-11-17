# 義工自主認領與管理員人工指派

本文件描述後端格式；Flutter UI 本次未修改。新任務固定 OFFICE001。

## Session 與相容性

沿用 POST 根路徑及 JSON type。login 仍以既有 admins 帳號密碼驗證，保留 success、token、username、zoneId 欄位。Token 改由 Random.secure 產生 32 bytes，保存於後端記憶體，綁定 admins.id，有效 8 小時；重啟需重新登入。多個 Server 程序不共用 Session，須固定同一程序或日後採集中 Session。人工指派每次也確認管理員帳號仍存在。

只有本次新增的人工指派 API 要求 Bearer Token。其他既有 API 未新增授權，義工仍為 Demo ID，不能將此描述成全系統已完成權限保護。部署時需使用 HTTPS 保護帳密及 Token。

## 登入

```json
{"type":"login","username":"管理員帳號","password":"管理員密碼"}
```

成功 HTTP 200（token 為示意，zoneId 保留既有帳號內容）：

```json
{"success":true,"token":"<64字元Token>","username":"管理員帳號","zoneId":"OFFICE001"}
```

帳密錯誤維持 HTTP 403。UI 需保存登入回傳的 token，用於人工指派 Header，不要從 adminId 推定權限。

## 人工指派

```http
POST /
Content-Type: application/json
Authorization: Bearer <login 回傳的 token>
```

```json
{"type":"assignSupplyRequestVolunteer","requestId":"REQ001","volunteerId":"V002","stationId":"OFFICE001"}
```

requestId、volunteerId 必須為非空字串。stationId 可省略，若提供只接受 OFFICE001。前端傳入的 adminId 不參與授權或稽核。

成功 HTTP 200：

```json
{
  "success":true,
  "message":"義工指派成功",
  "data":{
    "requestId":"REQ001",
    "volunteerId":"V002",
    "stationId":"OFFICE001",
    "status":"claimed",
    "claimedAt":"2026-10-20T08:00:00.000Z",
    "assignmentType":"admin_assigned",
    "assignedBy":7
  }
}
```

assignedBy 是 Session 驗證後的 admins.id。claimedAt 由後端產生 UTC 時間。

| HTTP | 情況 |
|---|---|
| 401 | 缺少、無效或過期 Token |
| 403 | Session 對應的管理員已不存在 |
| 400 | 必要參數缺少、型別錯誤或 stationId 非 OFFICE001 |
| 409 | 任務不存在、不是 reserved、已有認領者或不是 OFFICE001 |

失敗使用既有格式，例如：

```json
{"success":false,"message":"需要有效的管理員 Bearer Token，請重新登入"}
```

只允許已預留且未被認領的任務；不提供直接覆蓋或改派 API。自主認領與人工指派使用同一交易及條件更新，因此競爭同一任務時只能一方成功。管理員指派不增加預留、不扣實際庫存。既有 reserved 狀態及預留量仍由原需求預留流程負責。

## 自主認領與後續流程

原自主認領格式及回應保留：

```json
{"type":"claimSupplyRequest","requestId":"REQ001","volunteerId":"V001","stationId":"OFFICE001"}
```

成功回應仍包含 success、message、requestId、volunteerId；SQLite 另記錄 assignmentType=self_claimed、assignedBy=NULL。

兩種模式都由既有 getVolunteerClaims（volunteerId + stationId）取得我的任務，使用同一 dispatchSupplyRequest 確認取貨、completeSupplyRequest 完成配送；兩支動作都傳 requestId、volunteerId、stationId。取貨 stockQty 與 reservedQty 各扣 qty，一張任務只扣一次；完成只更新狀態與 completedAt。

不要使用舊 dispatch/allocate，這些舊寫入在單中心模式預設回 409。

取消沿用 cancelSupplyRequestClaim：只允許目前認領者在 claimed 狀態取消，回到 reserved，清空 volunteerId、claimedAt、assignmentType、assignedBy，預留量不變。取消後可重新自主認領或指派；不保留被清除的歷程。本次未實作歷史事件表或受控改派。

## 管理端任務追蹤

getSupplyRequestDetails 與 getRequestsByAdmin（receiverAdminId）保留原欄位，補齊以下認領資訊。getVolunteerClaims、getVolunteerHistory 也回傳相同相關欄位。

```json
{
  "volunteerId":"V002",
  "claimedAt":"2026-10-20T08:00:00.000Z",
  "assignmentType":"admin_assigned",
  "assignedBy":7,
  "status":"completed",
  "completedAt":"2026-10-20T09:00:00.000Z"
}
```

列表外層維持 `{"success":true,"data":[...]}`。上述只是相關欄位示意，不是完整需求物件。未完成時 completedAt 為 null。舊紀錄 assignmentType=null 必須顯示「歷史資料／方式未記錄」，不能推定是人工指派或自主認領。

目前沒有義工主檔或已驗證的義工登入，volunteerId 僅檢查非空，不能保證指定 ID 對應真人；本次沒有把 users 強行當作義工資料表，也沒有義工姓名／選單 API。UI 可暫以既有 Demo ID 選擇或輸入，後續需另行決定義工身分來源。

## UI 組員待串接

1. 保留自主認領入口，VolunteerPage / VolunteerViewModel 的新任務據點改 OFFICE001、名稱改社區管理中心；舊任務維持原據點。
2. 登入後保存 token，人工指派帶 Authorization Header。401 時要求重新登入；不使用硬編碼 Token。
3. 管理端只在 reserved 且 volunteerId=null 的 OFFICE001 任務提供「指派義工」；仍以後端是否成功為準。
4. 成功後重新查需求列表及我的任務。409 時重新載入，不能在 UI 強制覆寫。
5. 補 assignmentType、assignedBy、completedAt 欄位與顯示，將 UTC 時間轉當地時間。
6. 義工頁必須使用與被指派 ID 相同的 volunteerId；目前預設 V001 不會看到 V002 的任務。

## Schema 相容方案

DatabaseService.ensureSupplyRequestSchema 在現有初始化流程以 ALTER TABLE ADD COLUMN 加入：

- assignmentType TEXT 可空；新欄位約束僅允許 NULL、self_claimed、admin_assigned。
- assignedBy INTEGER 可空；保存指派時的管理員 ID，無刪除連動。

不回填舊資料、不刪表、不搬移庫存。Migration 可重跑。本次開發不執行正式 init 或 Migration；部署啟動新程式前應先備份並安排切換。原先未具備 metadata 欄位的資料庫需先執行此初始化，不能直接略過 Migration 後呼叫新 service。

Session 不新增 SQLite 表；伺服器重啟後任務資料仍在 SQLite，Session 失效與任務資料保留是不同的行為。

## 實際驗證（2026-10-20）

- `dart test test/volunteer_assignment_test.dart test/office_supply_request_test.dart test/office_inventory_test.dart test/station_lookup_test.dart`：35 項全通過，包含本次新增 9 項測試、第一階段 12 項與第二階段 10 項。
- 新增驗證包含記憶體／臨時檔案 SQLite、真實 HTTP 請求、獨立連線競爭、重開資料庫、Session 期限與拒絕偽造管理員 ID。Session 重啟失效以新建 SessionStore 驗證。
- `dart test`：53 項通過，1 個既有載入失敗；空白 `test/admin_server_test.dart` 缺少 main，未更動該檔。Station Transfer 與獨立測試 Server 重啟持久化情境通過。
- `dart analyze`：exit 0，無 error／warning，2 個既有 info：bin/admin_server.dart 字串不必要跳脫、healthReport.dart 檔名格式。
- 正式 admin.db 未執行初始化、Migration 或資料寫入；正式 Server 未重啟。
