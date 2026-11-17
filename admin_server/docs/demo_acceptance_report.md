# 管理端後端 DEMO 驗收報告

## 結論

指定九個展示步驟的後端 API 已在隔離 HTTP 環境實測；登入、查詢、新調度三階段及資料保存通過。
**目前整套 UI DEMO 尚不能判定可用**：Flutter lib 有 9 個編譯錯誤，UI 尚未串接 Station Transfer，SOS 操作也未寫回資料庫。
後端 API 通過不等於目前正式程序、ngrok 或 Flutter 畫面已驗收通過。

本次沒有修改正式 admin.db、正式後端業務程式、Flutter UI 或登入架構，沒有 Commit / Push。
沒有連線或停止正式後端、ngrok。只新增驗收測試與本文件。

## 實際執行與結果

| 命令／範圍 | 結果 |
|---|---|
| 新增前 `dart test`（admin_server） | 16 項通過、1 個載入失敗；空白 admin_server_test.dart 缺 main |
| `dart test test/demo_acceptance_test.dart --reporter expanded` | 5 項全部通過 |
| 新增後 `dart test --reporter expanded`（admin_server） | 21 項通過、同一個載入失敗，exit code 1；不能稱全套測試成功 |
| 最終 `dart analyze`（admin_server） | 無 error / warning；兩項既有 info：字串跳脫及 healthReport.dart 命名 |
| `dart analyze lib`（Flutter 專案根目錄） | exit code 1，138 項提示，其中 9 個編譯錯誤 |

沒有執行 Flutter widget test、瀏覽器端實際操作或正式部署端點測試。
本次新增 test/demo_acceptance_test.dart 與 test/support/demo_http_server.dart，未修復既有空白測試檔。

## 隔離方式與證據

- 每個驗收案例建立 `Directory.systemTemp/cares_demo_acceptance_*` 全新資料夾。
- 以子程序在该資料夾執行實際 DatabaseService.init() 與 seed，不使用正式 DB 複本。
- 使用實際 admin_server.dart 的 handleRequest()，只把測試 listener 綁定到 127.0.0.1 的系統分配連接埠。
- 正式 main() 的 8080 不會被測試占用。
- 測試自行啟停其建立的 worker；重開相同工作目錄的 worker，重新執行實際 init()。
- 測試前提會等待 seed 完成；正式 init() 本身仍沒有 await seedAll()，這是另一个已知限制。
- API 成功後另外以唯讀 SQLite 查詢測試 DB，確認資料真的存在；不是只看成功訊息。
- 暫存資料庫保留供檢查，未刪除任何既有資料。

全套執行中的調度驗證 DB：

```text
C:\Users\User\AppData\Local\Temp\cares_demo_acceptance_1c5f1eab\data\admin.db
```

同次全套執行的 SOS 保存驗證 DB：

```text
C:\Users\User\AppData\Local\Temp\cares_demo_acceptance_f5acad08\data\admin.db
```

## 九個展示步驟的證據分級

| 步驟 | 後端實測結果 | UI／部署限制 |
|---|---|---|
| 1. 管理員登入 | 正確 seed 帳密 admin_ncnu / 1234 回 200、success=true、username、token；錯誤密碼回 403 | zoneId 回 null，沒有造成登入失敗；正式帳密與 ngrok 未測 |
| 2. 災民、健康、SOS 查詢 | getAllUsers 回 14 位；getAllReports 回 5 筆；getEmergencyRequestsByAdmin 回 4 筆；SOS005 綁定 U014 | UI 編譯錯誤仍阻擋從原始碼重建；HTTP API 成功不代表畫面已能操作 |
| 3. 物資需求與據點 | getSupplyRequestDetails 含 stationId / stationName；seed 四筆初始 null；autoAssignSupplyRequest(REQ001) 後回 S001 / A收容中心 / reserved | 未指派時須顯示「尚未指派」，不能把 null 當 S001；SupplyRequest model 本身未保存這兩個欄位，SupplyPage 用原始 Map 可讀 |
| 4. getStations | OFFICE001 / S001 / S002 与名称正常回傳 | UI 據點選單仍寫死，未找到调用 getStations |
| 5. getStationInventory | 名稱、單位、stockQty / reservedQty / availableQty 正確，與 SQLite 一致 | SupplyPage 已调用；其快取刷新與顯示只有程式碼檢查，未做畫面驗證 |
| 6. createStationTransfer | 回 UUID 與 reserved，來源增加預留量；不足回 409，未產生額外單據 | UI 尚無新 API 调用，仍走舊 allocate 自動 dispatch |
| 7. shipStationTransfer | 回 shipped，來源 stock/reserved 各減 10，目的不變；重複出貨 409 | 必須以 transferId 呼叫，不能拿 allocationId 代替 |
| 8. receiveStationTransfer | 回 received，目的 stock 加 10，原有 reserved 不變；提前／重複收貨 409 | UI 尚無確認收貨串接 |
| 9. getStationTransfers | 依 S001 和 reserved / received 查詢，含名稱、單位及三個時間欄位，重開後同張單仍存在 | 尚無專屬單張詳情 API，列表可供詳情顯示；UI 尚未載入此列表 |

以上是隔離 API 實測；正式部署目前是否載入最新原始碼，未確認。

## 調度實測數字

真實 seed 產生的 itemId=1 在 OFFICE001 為 60，S001 為 36；本次沒有為了測試改寫這些初始庫存。
調度 10 個的 HTTP 與 SQLite 結果：

| 階段 | OFFICE001 實際 / 預留 / 可用 | S001 實際 / 預留 / 可用 |
|---|---|---|
| 初始 | 60 / 0 / 60 | 36 / 0 / 36 |
| 建立 | 60 / 10 / 50 | 36 / 0 / 36 |
| 出貨 | 50 / 0 / 50 | 36 / 0 / 36 |
| 收貨 | 50 / 0 / 50 | 46 / 0 / 46 |
| 隔離 Server 重開後 | 50 / 0 / 50 | 46 / 0 / 46 |

同張 transferId 的 status=received、createdAt / shippedAt / receivedAt 均保留。
重開前後比對整份 station_inventory 與 station_transfers 的全部列及欄位，結果相同。
新調度執行前後 inventory 與 allocations 全部資料也相同，沒有自動呼叫舊流程。
原本記憶體測試另涵蓋目的已有預留 5 的情況，收貨不重設該預留量。

## 重啟與資料保存

已實測：

1. updateEmergencyStatus(SOS005,resolved) 寫進 SQLite，重開隔離 Server 后查詢仍是 resolved。
2. 新調度與據點庫存重開後完全保留。
3. seed 的 INSERT OR IGNORE / 非空表跳過，在上述非空 DB 不覆蓋這些已修改值。

限制：正式 DB 路徑是相對工作目錄的 `data/admin.db`。正式部署應從 admin_server 啟動。
若從 Flutter 專案根目錄啟動，可能開到另一個 data/admin.db，看起來像資料消失。
測試沒有執行正式 main() 的 bind(8080)，也沒有證明正式 Server 的啟動／載入配置正確。

## API 與 UI Repository 格式問題

### 已對得上的格式

- AdminRepository.getEmergencies()：type=getEmergencyRequestsByAdmin，帶 receiverAdminId，讀 data；模型解析 emergencyId / latitude / longitude，與隔離回應一致。
- getAllUsers / getAllReports 與相關頁面：讀 success / data，HTTP 回應符合。
- getSupplyRequestDetails：回 data，額外 stationId / stationName，不刪除舊欄位；SupplyPage._stationOf() 能讀原始 Map。
- getPendingSupplyRequests：Repository 現已帶 stationId，讀 data，先前的缺參數問題不再出現在該方法。
- getStationInventory：SupplyPage 已讀 data / itemName / unit / stockQty / reservedQty，HTTP 有对应欄位。

### 現有確定缺口

1. Flutter HealthReport model 沒有 address，citizen_page / health_report_page 卻引用，造成四個編譯錯誤。
2. EmergencyViewModel 沒有 errorMessage，emergency_page 引用，造成兩個編譯錯誤。
3. EmergencyViewModel.markHandled() 引用 EmergencyRequest.id / handled，但模型只有 emergencyId / status，造成兩個 getter 與一個 setter 編譯錯誤。
4. SupplyRequest model 未保存 stationId / stationName；若某個新畫面只使用該 model，需要組員補欄位，不能期待 Repository 能還原已被丟掉的資料。
5. SupplyPage.dispatchRequest() 只傳 requestId，後端 dispatchSupplyRequest 必填 requestId / volunteerId / stationId，因此此舊管理端配送按鈕不應在 DEMO 使用。
6. Station Transfer 回應使用 String transferId，不兼容 AllocationItem 的 int allocationId；目前 lib 未找到新調度串接。

## 只更新 UI、不保存的操作

- EmergencyViewModel.markHandled() 沒有呼叫 AdminRepository.updateEmergencyStatus()，原意只改記憶體；且目前字段不匹配造成編譯失敗。
  emergency_page._confirmHandle() 與 citizen_page 的相應操作呼叫此方法。
  不能將該畫面的「已處理」當成 SQLite 狀態更新。
- CitizenViewmodel.updateNeedsRescue() 只改清單並 notifyListeners，未调用後端保存。
- 舊 HealthReportViewModel 的 add/delete/update 方法只改記憶體，舊 Repository 使用假資料。
  現有健康列表頁另有真實 HTTP 查詢，不應把這個舊 ViewModel 當成持久化編輯功能。
- 確認與上述區別：updateEmergencyStatus API 本身已測試會寫入與保留；新 Station Transfer 同樣已確認寫入。

## 新舊 allocate / dispatch 是否重複扣庫存

隔離 HTTP 實測舊 allocate(itemId=1,zoneId=S001,qty=10) → dispatch：
inventory.stockQty 從 seed 120 降至 110；OFFICE001 station_inventory 全部欄位沒有改變。

因此：

- 新、舊 API 不會自動互呼，也不是同一張 SQLite 庫存列被兩套邏輯自動扣兩次。
- 同一批實體物資同时走新旧流程，會在兩套帳各扣一次，造成重複計帳與不同畫面數量不一致。
- 舊出貨不会增加 S001 station_inventory，不能用來展示總倉→據點收貨。
- 新單據重複 ship/receive 會拒絕；重複 create 会建立不同 UUID，後續各自收貨仍會入庫兩次。
- SupplyPage.allocate() 目前自動呼叫舊 dispatch；不能只替換一支 API 名稱。

## 明天必須修正

| 問題 | 必要處理／判定 |
|---|---|
| Flutter lib 9 個編譯錯誤 | UI 組員修正上述 model / ViewModel 字段不一致並重新編譯；本次按限制未改 UI |
| 若承諾在管理畫面展示新調度三階段，UI 尚未接上 | 組員依 station_transfer_ui_integration.md 串 create / ship / receive / list，保存 UUID；否則明確改為 Postman 後端展示，不稱完整 UI 已完成 |
| 新調度仍使用舊總量當 OFFICE001 可用量 | 调度選單與上限要讀 getStationInventory(OFFICE001)，不可用 getInventory；否則容易明明畫面有庫存卻被後端拒絕 |
| 必須確認展示用 app / Server 實際載入版本與 API_BASE_URL | 本次未碰正式程序；由展示者確認版本與 ngrok／localhost設定，不能直接把隔離結果當正式環境成功 |

## 可暫時避開

- SOS 展示以查詢為主，不點現有 UI「已處理」。若展示持久更新，在隔離 Postman 呼叫已驗證的 updateEmergencyStatus。
- 避開 SupplyPage.dispatchRequest() 及舊 allocate/dispatch 的總倉搬運操作。
- 避開取消新調度、批次移轉歷史 allocations；目前沒有支援新調度取消 API。
- 未指派需求顯示 null / 尚未指派；可在隔離 DB 使用已實測 autoAssignSupplyRequest 準備一筆有據點的資料。
- 不依賴 zoneId 做帳號權限展示；本次 seed 登入回 null，前端可使用其現有 fallback，不能聲稱後端權限驗證完成。
- 不在正式資料庫做重複寫入練習；新調度、SOS 更新及 Server 重開都用隔離展示環境。

## DEMO 後再處理

- 補後端 token 驗證、角色／據點權限、密碼儲存與安全規則。
- 建立調度的冪等鍵、取消／釋放預留量、單張詳情與分頁。
- 統一 inventory 與 station_inventory 的管理語意，補 OFFICE001 入庫流程；舊 updateStock 不增加據點庫存。
- 修復空白 admin_server_test.dart，使全套測試 exit code 回 0；其他既有 lints 可按優先度清理。
- init() 等待 seedAll 完成，加入明確健康檢查；目前測試 worker 的等待是測試措施，不是正式後端修正。
- 完整驗證 UI 發送動作、模型解析、錯誤呈現及刷新；本次只能說明讀碼與靜態分析證據。

## 安全展示順序

整套 UI 需先解除編譯錯誤；時間不足時可用隔離 API 展示，清楚標註是後端展示。

1. 準備隔離 worker，新工作目錄為 cares_demo_acceptance_*，使用其 DEMO_READY 行所列臨時埠，不占用正式 8080。
2. Postman 對隔離 localhost POST login，用 seed 帳密展示成功與錯誤密碼拒絕。
3. 查 getAllUsers → getAllReports → getEmergencyRequestsByAdmin(receiverAdminId=admin_ncnu)。
4. 查 getSupplyRequestDetails；先說明 seed 的站點為 null，再 autoAssignSupplyRequest(REQ001)，重新查明細展示 S001 / stationName。
5. getStations 展示三个據點；getStationInventory 分別查 OFFICE001、S001、S002，記下初始量。
6. createStationTransfer（itemId=1、qty=10、toStationId=S001、createdBy=admin_ncnu），保存 data.transferId，查 reserved 清單與兩邊庫存。
7. shipStationTransfer（同一 transferId），查 shipped；確認 OFFICE001 實際減 10、S001 尚未增加。
8. receiveStationTransfer（同一 transferId），查 received；確認 S001 加 10。
9. 重複出貨／收貨展示 409，數量不變；查看 getStationTransfers 的時間與名稱。
10. 若展示重開，用驗收測試重跑或只重開自己建立的隔離 worker，查相同 temp DB；不要停止正式 Server/ngrok。

PowerShell 手動啟動隔離 worker（從 Flutter 專案根目錄執行，這是供展示者使用的指令，本次未額外啟動常駐服務）：

```powershell
$taskBackendRoot = Join-Path (Get-Location).Path 'admin_server'
$taskDemoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cares_demo_acceptance_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskDemoRoot | Out-Null
$taskWorkerPath = Join-Path $taskBackendRoot 'test/support/demo_http_server.dart'
$taskPackagesPath = Join-Path $taskBackendRoot '.dart_tool/package_config.json'
Push-Location $taskDemoRoot
try {
  dart --packages="$taskPackagesPath" "$taskWorkerPath"
} finally {
  Pop-Location
}
```

保持該終端開啟，看到 DEMO_READY:12345 就用 http://127.0.0.1:12345。
只在這個 worker 終端輸入 STOP 才會停止該隔離服務；不要對正式服務終端操作。
若需重開相同資料，重用原本 taskDemoRoot，不建立新目錄。
這個環境沒有改 ngrok 指向；使用目前 ngrok 會打到正式服務，不要拿它來做寫入驗收。

完整 Station Transfer 請求與回應範例見 [UI 串接規格](station_transfer_ui_integration.md)。
