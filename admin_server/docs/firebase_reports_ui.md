# 管理端 Firestore 健康回報／SOS UI

## 目前範圍

在 `integration/firestore-health-sos-readonly-20261117` 工作樹接入既有新 API，不修改 Firebase、正式 SQLite、居民 App 或組員其他分支，不 Commit／Push／Merge。

原健康頁直接 http.post getAllReports，SOS 頁透過 AdminRepository／EmergencyViewModel 查 getEmergencyRequestsByAdmin，災民總地圖與指揮中心計數也採 SQLite。登入頁已有 AdminApiSession.token；新 Client 沿用這個記憶體 Token，不另存密碼或把 Firebase 憑證放進 Flutter。

目前新入口：Dashboard 健康回報／SOS 頁預設為「Firestore 居民回報（唯讀）」。原頁面保留為 SqliteHealthReportPage／SqliteEmergencyPage，在明確切換來源時才掛載。未重寫原列表設計或既有 SQLite 操作，Firestore 畫面沿用共同 PageHeader、白底卡片、搜尋及健康狀態篩選樣式。

**後續 8085 整合已加入指揮中心 Firestore SOS 計數／清單／地圖及來源切換**；災民總地圖、使用者、物資及已處理事件仍是 SQLite，不能將兩邊人數或 ID 相加。指揮中心與 SOS 頁共用快照，詳見 [8085 整合驗收](integration_8085_acceptance.md)。未合入 main 的 UI 整合分支仍需組員審查，未合併或覆蓋其他分支。

## 分層與檔案

| 檔案（相對 Repository） | 功能 |
|---|---|
| lib/core/models/firebase_report.dart | 獨立 nullable DTO，不轉成 SQLite Model；保留 UID、來源事件、健康狀態、SOS、時間、原始座標、品質標記 |
| lib/admin_APP/services/firebase_reports_client.dart | POST 新 API、附 Bearer、驗證來源及回應、逾時與安全錯誤，不回傳上游原始錯誤或記錄個資 |
| lib/core/repositories/firebase_reports_repository.dart | 自動走完整來源分頁，以 UID 合併同來源最新資料；無 SQLite fallback |
| lib/admin_APP/viewModels/firebase_reports_view_model.dart | 更新、保留上次成功快照、權限失效清除快取、避免重疊刷新與 dispose 後更新 |
| lib/admin_APP/widgets/firebase_reports_panel.dart | 來源切換、唯讀列表、搜尋／篩選、顯示分頁、狀態、詳情、更新及地圖確認 |
| lib/admin_APP/screens/emergency_page.dart | 入口加入 Firestore／SQLite 切換，原操作只留在 SQLite 模式 |
| lib/admin_APP/screens/health_report_page.dart | 同上，舊健康列表及電話／血型補值邏輯只屬 SQLite 模式 |
| lib/admin_APP/screens/full_map_page.dart | 新增預設 true 的參考圈開關；Firestore 不顯示無依據的 300m 圈，舊畫面預設不變 |
| test/firebase_reports_ui_test.dart | Mock Service／Repository／ViewModel／Widget 驗證 |

後端 API 詳見 [firebase_health_reports_api.md](firebase_health_reports_api.md)。本次沒有變更 API 契約，也未再改後端業務程式。

## 查詢、更新與來源安全

- Client 使用 ApiConfig.baseUrl，也就是登入使用的 API_BASE_URL。getFirebaseHealthReports／getFirebaseSosReports 都附 AdminApiSession.token。Token 不寫 SharedPreferences 或日誌。
- 驗證 success、source=firestore、collection=health_reports、semantics=latest_per_uid。來源錯誤直接報錯，不能把 SQLite 回應偽裝成 Firestore。
- SOS 僅接受 sos=true，重傷但 sos=false 仍是健康回報，不能自動升成 SOS；未宣告不當安全。
- 每輪每頁 limit=25，自動繼續 nextPageToken，SOS 空頁仍繼續。最多 20 個來源頁（500 個來源文件），重複游標或超限回錯誤，不發布部分成功快照；後續大規模資料需設計伺服器篩選／更合適的查詢。
- 完整來源頁成功後才替換 UID→最新狀態快照，再以每畫面 10 筆作顯示分頁。重讀不追加歷史，不把 eventId 當人或列表主鍵，沒有任何姓名／電話／Email 對 SQLite 的配對。
- 同輪分頁必須保持同一 Session。401／403 或 Session 變更會清除快取與個資；網路錯誤、503／504、分頁未完成則保留上次完整資料並顯示「保留上次成功資料」。未取得資料時不顯示為已確認零筆。
- 頁面掛載且 App 在前景時每 30 秒重新查詢；手動刷新可立刻查詢。進行中不疊加下一輪；切換離開來源頁時 dispose 會停止 timer 並關閉 HTTP client。
- 這是**輪詢**，不是 Firestore listener、FCM 或瞬時推播。最近更新時間是管理端完成讀取的時間，不是居民事件時間。跨頁讀取也不是雲端原子快照。
- SOS 解除後下一輪完整成功查詢會移除列表項目；開著的詳情也會顯示狀態已更新。刷新失敗則不假稱 SOS 已解除。
- Firestore 模式沒有完成、刪除、認領或指派按鈕。舊 updateEmergencyStatus 僅作用 SQLite，絕不拿 Firebase UID／eventId 呼叫它。

## 地圖與時間

時間缺少／無時區／無效時顯示未知，不補現在時間。座標不四捨五入存進 DTO，缺值、超界、非有限值、(0,0) sentinel 不當有效位置。詳情顯示原始有效 GPS，並標示「精度與擷取時間未知，可能是舊位置」。

新畫面不自動呼叫逆地理編碼，也不拿居住 area 補位置。只有有效 GPS 才能選「查看地圖」；會先告知圖資與導航的外部傳輸並要求管理員確認，再沿用 FullMapPage。Firestore 地圖不顯示硬編碼的 300m 參考圈。

## 如何顯示已讀到的 1 筆 SOS

以下是操作文件，本次沒有啟動 Flutter 查詢真實資料，也沒有讀取使用者原 PowerShell 的 Token／密碼。

### 本機 8084 安全驗收

保持原本的獨立唯讀 Server，不重啟、不從程式擷取其密碼。另開 PowerShell：

```powershell
Set-Location 'C:\Users\User\AppData\Local\Temp\hucares-firestore-reports-20261117'
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8084
```

1. 用 `firebase_reports_test` 及操作者知道的本次測試密碼在 Flutter 登入，取得新的 UI Session；不沿用 PowerShell Token。
2. 進入側欄 SOS 頁，確認來源是 Firestore。列表會走 getFirebaseSosReports 並讀完來源分頁。
3. 若資料仍維持手動驗收狀態（1 筆、sos=true），完整讀取後應顯示 **SOS 1 筆**，以及該筆姓名／狀況／時間。不能在 Client 硬編碼一筆替代雲端資料；若其間已撤回或變動，應顯示實際最新結果。
4. 詳情可看來源、縮短 UID／事件 ID、狀況、SOS 標記、時間、有效 GPS 與品質提醒。沒有有效 GPS 就沒有開圖按鈕。
5. 健康頁同樣預設 Firestore，讀 getFirebaseHealthReports；健康總數不一定與 SOS 數一致。

**8084 只開放登入與兩支新讀取 API**。因此此啟動方式只驗收這兩頁，其他舊模組可能因路由未提供而讀不到資料；不是完整管理系統的展示設定。不要在 8084 模式切到 SQLite 並以空資料推定正式資料消失。

### 完整管理端的後續展示

登入 Token 是程序內 Session，不能在 8080 登入後改用同一 Token 查另一個 8084 程序。完整展示需在另行核准的完整測試後端啟用 Firebase reports、核准實際 admins.id，再讓 Flutter 的 API_BASE_URL 指向同一後端。正式 admin_server.main 會初始化 SQLite，不能在本階段為展示而未經核准啟動或搬移正式資料。

其他電腦的 127.0.0.1 指向各自電腦；8084 是本機入口，不應自行改成公開監聽或對外開放。跨機展示需另行核准受保護的完整 API 部署，不把獨立驗收入口當正式公開服務。

## 教授如何看到更新

開啟 Firestore SOS 頁，先確認最近更新時間與資料來源。由 App 組在**另行核准的測試環境／帳號**產生或解除 SOS（本次沒有執行任何 App／Firestore 寫入），管理端按「重新整理」即可主動讀取；若保持頁面前景開啟，約下一個 30 秒輪詢加查詢時間後看到更新。

撤回後必須等完整刷新成功才顯示零筆；錯誤時會保留舊資料並標示失敗。教授看到的是居民自己 sos 標記的更新，不是管理員按「完成」把居民改為安全。展示中要把 App 寫入時間、API 讀取結果與 UI 更新串成去識別化證據，不能只用一張有資料的畫面宣稱端到端完成。

## 尚待驗收

- 新 UI 與目前真實 8084 的手動連線；這次只有 Mock／Widget 測試，沒有真實居民查詢。
- 實際 APK 的 commit／執行時 Project、測試 UID 與更新／撤回證據；先前手動 API 成功仍不證明來源 APK 專案。
- Dashboard／災民總地圖的 Firestore 整合、管理員獨立處理進度、mesh_reports、FCM，均未納入本次。
- 大型資料集的查詢成本與頁數上限、正式授權與測試部署，需後續規劃。輪詢會產生 Firestore 讀取費用；本次沒有做實際流量或費用測量。

## 實際驗證（2026-11-18）

- 新增 Flutter 測試 19 項全部通過，另有既有地址／逆地理編碼相關 9 項通過。未執行全專案 Flutter 測試（仍有既存的預設 Counter 測試）。
- flutter analyze --no-pub：0 error、6 個既存 warning、103 個 info；因 warning/info exit 1，新串接檔案無新增 lint。
- 後端 dart analyze：exit 0，只有 2 個既存 info；完整後端 231 項測試全部通過。
- 測試以 MockClient／合成回報與隔離 SQLite 執行，不查真實居民、不載入外部圖磚、不讀取操作人 Token／密碼、不修改正式資料。
- 工作區與新增檔案 whitespace 檢查通過。SDK 產生檔只有換行／狀態差異，已確認無內容變更並清除假性 Git 變更，沒有把它們或業務修改留在暫存區。
- 真實 UI 對 8084 的手動驗收仍待操作人完成；不能把 Mock 顯示的 1 筆當成目前雲端那 1 筆的 UI 證據。
