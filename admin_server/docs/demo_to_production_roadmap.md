# 互CARES：DEMO 到正式版整合計畫

- 建立日期：2026-11-11（Asia/Taipei）。
- 範圍：目前 Repository 的 Flutter 管理端、Dart HttpServer、SQLite、通知與位置服務；另一個使用者 App Repository、實際 Firestore 文件／Rules、通訊組 Repository、正式部署設定均未取得。
- 本次方法：唯讀檢視原始碼、API 路由、依賴、既有測試及驗收文件；僅新增本文件。沒有重跑測試、啟動 Server、開啟正式 DB、連線 Firebase／Nominatim、執行 Migration 或部署 Rules。
- 文件性質：現況盤點加後續工作規劃。下文「建議」「待做」「驗收」均不是本次已完成的程式。

## 1. 後續開發共同原則

1. 每個功能分開記錄：程式實作、Mock 測試、本機 HTTP／SQLite 整合、測試雲端／真機端到端、正式發布驗收。不能以其中一項代替其他項。
2. Mock、Seed、DEMO 帳密、公開地標測試座標、臨時 DB 與開關都必須具名且隔離；禁止靜默 fallback 到假資料或把假成功當成發布／送達成功。
3. 沿用現有 POST + type、Service／Repository 與現有資料表；以相容性增補優先，不為 DEMO 再複製一套正式業務流程。
4. 業務 Service 與外部傳輸／儲存介面分離，環境設定明確；正式、staging、DEMO 使用不同憑證、資料路徑與發布授權。設定缺少應停用相關能力，不跳到正式來源。
5. 不為展示繞過 Session、管理員權限、資料範圍、位置隱私、Rules 或 IAM。隱藏按鈕不能取代後端限制。
6. 系統維持單中心 OFFICE001；inventory 是物資主檔，OFFICE001 的 station_inventory 是唯一有效的現行庫存。不自動把 S001／S002、舊 inventory 數量相加移入。
7. 目前主流程採方案 A：管理中心線下協調配送；新任務不依賴義工登入、認領或人工指派。保留歷史義工資料及 API，不因此恢復線上派工。
8. 災時位置取每筆回報的原始 GPS 與事件時間，users.area 是居住地址；地址只供閱讀，逆地理編碼不得成為回報成功的前置條件。
9. Firebase UID 才是跨系統使用者識別依據。U001 等 SQLite 示範 ID、管理員數字 ID、username、Email、Nostr pubkey、藍牙裝置 ID 均不能直接當 Firebase UID。
10. Firestore 監聽不是 FCM 系統推播，Firestore 離線快取不是藍牙 DTN；最後回報位置也不是即時位置。
11. 變更前列出資料契約、Migration、舊資料與 UI 影響；實作後附可重現驗收證據、部署與回復方案。正式資料更新須另外核准，本文件不是正式寫入授權。

## 2. 狀態用語與證據界線

| 標記 | 意義 |
| --- | --- |
| 可保留／有隔離測試 | 核心程式及本機證據可沿用，不表示已完成正式環境驗收 |
| DEMO／Mock／Seed | 僅供展示或測試，不是正式資料來源或授權依據 |
| 已實作／待外部驗證 | 有真實服務 Adapter 或 API，但沒有真實環境端到端證據 |
| 待 UI 整合 | 後端存在，UI 未找到對應呼叫或無法完成流程 |
| 未找到／無法確認 | 本 Repository 查無實作，或證據位於未提供的其他專案；不等於斷言其他組未開發 |
| 正式可使用 | 本計畫的發布 Gate 全數通過後才能標記；目前沒有足夠證據將整套系統標為正式可用 |

最近一次驗證紀錄（來自既有工作紀錄與文件，本次未重新執行）：

- 完整後端測試 130 通過，1 個既存載入失敗：空白 test/admin_server_test.dart 缺 main()。不能標為測試全綠。
- 後端 dart analyze 無 error／warning，有 2 個既存 info。
- 位置保存測試 20 項、逆地理編碼後端測試 17 項通過；後者採 Mock 外部服務及隔離 HTTP。
- 逆地理編碼 Widget／Client 測試 6 項通過；獨立 Flutter Web DEMO 實際編譯成功，新元件靜態分析通過。
- 完整 Flutter lib 最近一次分析仍有 9 個既存 error，獨立 DEMO 編譯成功不代表原管理端可編譯。
- 沒有實際 Firebase 發布／收件匣讀取、Nominatim 查詢成功或手機 DTN 多跳整合證據。

參考：[位置保存紀錄](report_location_phase1.md)、[逆地理編碼驗收](reverse_geocoding_demo.md)、[通知測試與設定](notifications_api.md)。正式發布必須對候選版本重新執行，不能只引用上述數字。

## 3. 現有功能盤點

| 功能 | 現況、可沿用部分 | 限制／尚缺證據 | 程式依據 |
| --- | --- | --- | --- |
| 管理員登入／Session | 隨機 Token、8 小時到期、程序內 Session、新管理 API 驗證 Bearer 與帳號存在，可保留 | 重啟失效、無完整撤銷／停權／角色模型；密碼仍直接比對，未全面保護舊 API | [Session](../lib/services/admin_session_store.dart)、[路由與登入](../bin/admin_server.dart) |
| OFFICE001 庫存 | 主檔 JOIN 中心庫存、增量入庫、原子更新及測試，可保留 | 正式舊庫存未搬移／盤點；其他庫存寫入入口仍需治理 | [DatabaseService](../lib/database/database_service.dart)、[第一階段文件](office_inventory_phase1.md) |
| 物資需求／方案 A | 新需求固定 OFFICE001，pending → reserved → dispatched → completed；出庫同時減實際／預留，完成不再扣庫存，可保留 | UI 尚有舊流程；預留等舊路由授權未完整；正式歷史任務不能直接接新出庫 | [需求 Service](../lib/services/supply/supply_request_service.dart)、[方案 A](offline_supply_delivery.md) |
| 批次與人工審核 | 三支批次 API、異常欄位、審核 API、逐筆交易與部分成功回應已實作、有隔離測試 | UI 尚未串接；超量、疑似重複不是自動拒絕；仍需真實 App 契約測試 | [批次規格](supply_batch_review.md) |
| 據點與 Station Transfer | getStations、getStationInventory、調度三階段／歷史查詢可保留 | 單中心正式新流程不應用多據點調度；目前 handler 未驗證 Session，createdBy 只是傳入值，不能當授權 | [調度 Service](../lib/services/supply/station_transfer_service.dart)、[串接文件](station_transfer_ui_integration.md) |
| 舊 allocate／dispatch | 程式與歷史保留；預設 409 防護可沿用 | ALLOW_LEGACY_INVENTORY_WRITES 可恢復舊寫入，正式環境需防止誤開；UI 仍在呼叫 | [allocation Service](../lib/services/supply/allocation_service.dart)、[dispatch Service](../lib/services/supply/dispatch_service.dart)、[AllocationViewModel](../../lib/admin_APP/viewModels/allocation_viewmodel.dart) |
| 義工認領／人工指派 | 舊實作、交易與歷史資料保留 | 已非方案 A 新任務流程；UI 仍有 V001／S001 Demo 入口；不是正式義工身分系統 | [義工頁](../../lib/admin_APP/screens/volunteer_page.dart)、[指派文件](volunteer_assignment.md) |
| SOS／健康／需求寫入與位置 | address、有效 GPS、事件與接收時間保存已修正，可保留；最新位置依有效事件時間選擇 | 手機端契約未對照；Flutter HealthReport 仍非空 reportTime，SOS Model 仍會將缺座標補 0、缺時間補 now，與後端 nullable 語意不一致 | [後端 Model](../lib/core/models/)、[Flutter 健康 Model](../../lib/core/models/healthReport.dart)、[Flutter SOS Model](../../lib/core/models/emergency_request.dart) |
| SOS 狀態 UI | Repository 有 updateEmergencyStatus，可作真正寫入入口 | citizen_page 的處理操作仍呼叫 markHandled；ViewModel 使用不存在 id／handled，只改記憶體的意圖不是可靠 SQLite 寫入流程，目前亦有編譯錯誤 | [CitizenPage](../../lib/admin_APP/screens/citizen_page.dart)、[EmergencyViewModel](../../lib/admin_APP/viewModels/emergency_viewModel.dart)、[AdminRepository](../../lib/core/repositories/admin_repository.dart) |
| 通知後端 | 收件人、單／多人、廣播、本人發送紀錄；ADC／IAM REST Adapter、交易、防重、權限白名單可沿用 | 只完成 Mock／本機驗證；未取得實際 AppUser、Auth 狀態、Rules 及測試雲端資料；沒有已送達／已讀追蹤 | [通知模組](../lib/services/notifications/)、[API 文件](notifications_api.md) |
| Firebase 管理端 | 依賴與平台設定檔存在 | main.dart 沒有實際初始化呼叫；未找到 Firestore collection 讀寫／snapshots，不能視為已串接 | [main](../../lib/main.dart)、[設定](../../lib/firebase_options.dart)、[firebase.json](../../firebase.json) |
| Reverse Geocoding | 共用後端、預設停用、白名單、限流／快取／額度；UI 元件與獨立展示入口可保留 | 僅公開地標 DEMO；Mock、HTTP、Widget 與編譯證據，不是供應商真實連線／正式隱私審核證據 | [Service](../lib/services/reverse_geocoding_service.dart)、[UI 元件](../../lib/admin_APP/widgets/sos_address_details.dart) |
| Seed／假資料 | SQLite seedAll、健康假 Repository、Nostr 模擬 Repository、隔離 DEMO 啟動器可留作測試工具 | 不得成為正式回報；假資料 Repository 存在不等於每個畫面均使用，需逐入口查明 | [Seed](../lib/database/database_service.dart)、[假健康 Repository](../../lib/admin_APP/repositories/healthReport_repository.dart)、[Nostr 模擬](../../lib/admin_APP/repositories/nostr_healthReport_repository.dart) |
| DTN | 回報已有 uuid／requestId／emergencyId、hopCount、receiverAdminId 等部分可用欄位 | 查無藍牙傳輸、裝置橋接、多跳佇列、TTL 驗證、簽章驗證、去重同步或反向廣播的完整程式與真機證據 | [Android MainActivity](../../android/app/src/main/kotlin/com/example/flutter_disaster_app/MainActivity.kt) 僅 FlutterActivity；[NostrService](../../lib/admin_APP/services/nostr_service.dart) 整段註解 |

### 3.1 必須明確標為 DEMO 的項目

- U001 等 Seed 使用者、預設 Seed 管理員／示範庫存／SOS；不能假定現有正式 DB 每筆均為 Seed，本次沒有讀正式資料。
- V001／S001 義工 Demo；保留歷史，不重新納入新流程。
- HealthReportRepository._loadFakeData、NostrHealthRepository 模擬 JSON。Nostr 本身也不等於藍牙 DTN。
- bin/reverse_geocoding_demo.dart 的臨時 demo.sqlite、demo_admin、合成 SOS；lib/reverse_geocoding_demo.dart 是獨立展示入口，不是原管理端整合完成。
- taipei101／taipei_main_station 白名單只是公開測試座標；名稱不能當硬編碼解析結果。
- test/support/memory_notification_store.dart 與 MockClient 只供測試；正式設定缺少不能使用 Mock 回成功。
- 臨時 ngrok URL、localhost、API_BASE_URL 與各功能開關必須明確分環境；不能把開發網址默認當正式服務。

## 4. P0：DEMO 後立即處理

P0 的完成目標是建立可編譯、資料來源清楚且不會意外寫錯環境的整合基線；不是對真實居民開放服務。

| ID | 工作與最小方案 | 主要負責／依賴 | 驗收標準 |
| --- | --- | --- | --- |
| P0-01 | 修復完整管理端 9 個已知編譯錯誤，對照後端 nullable 座標／時間／address 與 errorMessage；不以假 getter、假時間或空 success 掩蓋問題 | UI＋後端；使用者 App 確認契約 | dart analyze lib 無 error；主入口實際編譯；null／無效時間歷史資料正常顯示未知，不能冒出 (0,0)／剛剛回報 |
| P0-02 | 將 SOS 結案操作接到 SQLite API，修正 markHandled 的畫面記憶體更新；成功後重查、失敗保留原狀 | UI＋後端，依 P0-01 | 點擊後查詢 SQLite 與重開 Server 仍一致；注入 401／500／網路失敗時不得顯示已成功結案 |
| P0-03 | 生產啟動與 Seed／DEMO 分離；保留測試工具，正式模式禁自動 seed，Schema 更新改受控版本流程；盤點路徑與啟動設定 | 後端＋部署負責 | 正式模式對空測試 DB 啟動不建立示範帳號／居民／庫存；未核准 Schema 不偷偷更改；錯誤路徑 fail closed；DEMO 啟動僅臨時 DB |
| P0-04 | 盤點全部路由與授權矩陣，先限制外部可達範圍，再逐一補保護。優先居民／健康／SOS 查詢、庫存增刪、預留、Station Transfer；區分 App 回報與管理員操作 | 後端＋UI；不能只靠 CORS | 每支管理 API 有未登入401、無權403、授權成功測試；不能偽造 adminId／receiverAdminId／createdBy 取得權限；App／DTN 回報另用可信來源機制，不能一律要求管理員 Token |
| P0-05 | UI 切至方案 A：確認／預留、管理員出庫、完成，統一 OFFICE001；停用新流程的義工入口與 A／B 調度入口；舊查詢及歷史保留 | UI＋後端；依 P0-01、04 | 真正登入後完成單筆流程；出庫只扣一次、完成不扣；舊按鈕不能偷走其他流程；ALLOW_LEGACY_INVENTORY_WRITES 在正式配置保持 false；保留 Station Transfer 程式但禁止未授權寫入 |
| P0-06 | 確認 Firebase Project 與身分資料契約。本 Repo 平台設定為 bitchat-android-disaster-app，通知後端目標為 disaster-app-b2370；請 App 組核對是否刻意分專案，不能直接全改同一值 | App＋後端＋專案負責 | 留下每個 App／環境／IAM 目標表與實際脫敏 AppUser 範例；確認正確 UID issuer／audience。管理 UI 僅走 Dart API 時不必為通知強行改其 Firebase 初始化 |
| P0-07 | 建立可重現 CI／驗收基線，處理空白測試檔，標示測試環境與未驗證能力 | 全組 | 後端與主要 UI 所需測試可重現，無載入失敗；同時保存完整主入口與獨立 DEMO 結果；報告不得把 Mock／編譯當真機整合 |
| P0-08 | 凍結並公告接口／決策：OFFICE001、方案 A、GPS／時間、UID、通知發布語意；為本文件保留維護人與版本 | 各組負責人 | UI、App、通訊組各確認欄位範例與錯誤碼；未確認部分明列，不再依口頭推測修改共用 Model |

關鍵風險依據：DatabaseService.init() 目前執行 createStationTransferSchema／ensureSupplyRequestSchema、_initDefaultAdmin()、seedAll()，後兩個未等待完成；main() await handleRequest 也會序列處理整個 Server。正式整合需驗證初始化就緒性、慢外部查詢是否阻塞 SOS 接收，不能只測隔離 DEMO 的並行 listener。

舊義工認領／取消／取貨等 API 目前仍保留可呼叫，不能因新 UI 隱藏入口就宣稱後端已全面停用。P0 應提出相容、可回復的伺服器防護，阻止它們接手新方案 A 任務，同時保留歷史查詢及經核准的歷史處理；實際行為調整需另行實作與驗收，不在本次文件工作中執行。

## 5. P1：正式整合必要

| ID | 工作與保留方案 | 主要負責／依賴 | 驗收標準 |
| --- | --- | --- | --- |
| P1-01 | 管理員密碼雜湊與舊帳密受控升級、失敗限速、Session 撤銷／停權與最小角色權限；沿用登入回應、UI 不信任傳入 adminId | 後端＋UI；依 P0-04 | DB 無可直接登入的明文正式密碼；停權／登出／到期失效；讀寫與發布／廣播權限分離；無敏感資料漏在回應／日誌 |
| P1-02 | 建立 Firebase UID 對照與資料來源權責，實作第 7 節同步方案；不改寫示範 ID 冒充 UID | App＋後端；依 P0-06 | 多裝置同 UID 正確合併、同名不同 UID 不誤合併、未知 UID／衝突內容進受控處理；中斷重試無重複資料或扣庫存 |
| P1-03 | 通知真實測試環境：沿用現有通知 API、Store、ADC／IAM；目前 Adapter 固定 disaster-app-b2370，不可把正式 Project 當 staging。先核准隔離 staging Project／資料庫與相應配置方案，或用相容測試 Adapter／Emulator 完成前置驗證 | 後端＋App＋Firebase 負責；依 P0-06、P1-01 | 真正 ADC 身分／最小 IAM 對 staging 成功與拒絕可驗；同 key 重試不重發、改 payload409；單人／多人與廣播原子發布；未確認 commit 不回成功 |
| P1-04 | 將建議通知 Rules 與 App 既有完整 Rules 合併，依實際 profile schema、email 驗證與 scope 測試；不直接整份取代 | App＋Firebase 負責；依 P1-03 | Emulator 覆蓋未登入／未驗證／A讀B／普通用戶廣播寫入／管理發送紀錄讀取均拒絕；合法本人與廣播讀取通過；沒有寬鬆 wildcard 繞過；staging 真 Auth 身分再驗 |
| P1-05 | UI 通知頁與 App 收件匣整合：管理端選 UID／多人／廣播、發送歷史；App 讀個人 notifications 與 broadcasts、過期隱藏與去重 | UI＋App；依 P1-03、04 | 兩個真實測試帳號及兩台裝置端到端，B不能讀A通知；廣播按已核准範圍可見；送出失敗不顯示已發布；published≠delivered≠read |
| P1-06 | 完成主 UI 的批次與人工審核：沿用現有批次 API，讀 results 而非只判 HTTP200；顯示異常原因、審核意見、預留／出庫／完成時間 | UI＋後端；依 P0-05 | 同批總量超庫存時逐筆結果清楚；異常不能從單筆／批次／重試繞過；只重試失敗項，不自動重送已出庫項 |
| P1-07 | 位置正式 Provider 接口與政策核准：保留共用 Service／UI，受控替換 DEMO 白名單供應設定，確認費用、隱私、快取授權、配額及故障切換 | 後端＋專案負責；依 P0-08 | 經核准非敏感測試位置真查成功；斷網／超時仍可新增 SOS／健康／需求；不改原地址／GPS／事件時間；來源與解析時間清楚；拒絕未核准供應商／隱私資料傳送 |
| P1-08 | DTN 基礎協定及手機 ↔ 中繼 ↔ 後端同步，沿用業務 INSERT 但加可驗證封包入口與收件去重帳；先上行，再下行通知 | 通訊＋App＋後端；依 P1-02、第 8 節 | 真手機在斷網條件 A→B→C→管理端；重送／循環／重啟僅一筆有效回報；無法偽造來源或讀取私人內容；離線事件時間不被接收時間覆寫；下行個人／廣播有相同 messageId |
| P1-09 | 正式 SQLite 盤點與版本 Migration、備份還原、舊庫存及歷史任務受控切換 | 後端＋資料負責；依第 9 節 | 副本 dry run、每步比對、完整性／外鍵與非負量檢查、可還原；新流程與舊配送不重複扣庫存；沒有把所有舊數字簡單累加 |
| P1-10 | 正式部署與災時可用性：HTTPS、來源限制、API大小／速率限制、日誌遮罩、DB權限、監控、離線重送與備援 | 部署＋全組 | 隔離環境壓力／慢Provider／停網測試仍接收回報；可定位失敗但日誌不洩漏位置／電話／Token；備份在新環境成功還原；符合已核准 RPO／RTO 與容量目標 |

P1-07 不表示解除 DEMO 白名單就算正式完成；P1-08 也不能以模擬傳輸代替藍牙真機驗收。RPO／RTO、最大離線時長、保留期限、通知地理範圍尚無產品數值，需負責人明確訂定後才能放行。

## 6. P2：進階能力

| ID | 工作 | 驗收標準 |
| --- | --- | --- |
| P2-01 | FCM 背景推播、裝置 Token 更新與登出清理、使用者通知權限 | 真機前景／背景／App 終止等平台情境逐項測試；不保證 OS 一定即時送達；收件匣仍是可查的資料來源，不把收到推播當已讀 |
| P2-02 | GPS／事件時間／管理中心服務範圍的區域通知，含位置新鮮度與未知位置政策 | 定義有效時間窗、邊界、未知位置與使用者同意；不能以 users.area 或過期最後位置當即時座標；收件人範圍由後端驗證而非前端任選 |
| P2-03 | DTN 優先級、擁塞控制、多路徑／重送優化、分片與大型封包、可觀測性 | 可重現多節點循環／掉線／容量滿測試；SOS優先且不無限複製；不把 relay ACK 當最終送達 |
| P2-04 | 更細的授權、稽核報表與配送例外流程（部分出庫、退貨、取消、歷史改派等需另行需求核准） | 受控狀態機與補償帳完整、不覆寫歷史；未經另行決策不恢復多據點或線上義工派工 |

## 7. SQLite 與 Firestore 資料來源／同步規劃

### 7.1 現況與建議權責

目前未找到完整雙向同步實作。以下是待確認與待實作的權責，不是現有功能。

| 資料 | 建議權威來源 | 另一端如何使用 | 禁止做法 |
| --- | --- | --- | --- |
| Firebase 身分／Email 驗證 | Firebase Authentication | 後端對線上 App 驗 ID Token 的 issuer／audience／subject 等；管理員 Session另行驗證 | 將 UID 字串或 Email 當登入證明 |
| AppUser name／phone／area | App 組確認的 users/{firebaseUid} | SQLite 保留 UID 對應與必要投影，更新版本／同步時間；災時回報姓名電話可保留當次快照並標示 | 用姓名／電話自動合併或讓兩端任意互相覆蓋 |
| inventory 物資主檔 | 目前單中心管理後端 SQLite | 若 App 需顯示，發佈只讀版本化投影至核准 Firestore 路徑；App 組既有物資 collection 需先對照 | 未確認 Firestore 既有物資格式就另建同名權威主檔 |
| OFFICE001 庫存、預留、出庫、配送狀態 | SQLite Service 的交易結果 | Firestore 只讀投影；App／DTN 傳需求不直接更動庫存 | 兩邊都能改總庫存、App自行扣庫存、同步再扣一次 |
| SOS／健康／需求原始事件 | 建立事件的來源封包；SQLite是管理端接收後的業務處理帳 | Firestore 若亦收原始事件，與直接 HTTP／DTN 共用同一 eventId，保存來源與接收帳 | 同一事件從兩路進來變兩筆需求，或用伺服器現在時間替代原事件時間 |
| 管理員審核／出庫／完成 | SQLite 狀態機與操作紀錄 | 結果透過 outbox 投影／通知；App不能覆寫 | 離線客戶端回傳 completed 就直接改狀態 |
| 通知內容、發布紀錄 | 現有 Firestore notification_sends + broadcasts／個人 notifications | DTN 包攜帶相同 messageId 與授權來源；SQLite如需快取只作投影／重試帳 | 把另一路重送當新發布、把 published 改稱已送達 |
| 送達／已讀 ACK | 經驗證的收件裝置／使用者事件 | 獨立 receipt，必要時依裝置與使用者彙總 | 中繼收到包就標記使用者已讀 |
| 地理編碼結果 | 經批准 Provider 的衍生資料 | 獨立快取／provenance，不覆寫原事件地址與GPS | 把解析結果當使用者原始陳述或目前位置 |

App profile 權威由 App 組確認；如果管理端也要更改個資，必須改走單一受控寫入 API／權責流程，不允許 profile 兩端互為主檔。Firestore 物資 collection 的實際名稱與欄位本次無證據，保持「待 App 組提供」，不自行猜測。

### 7.2 UID 與舊資料

- 建議以增補欄位或映射表保存 localUserId、firebaseUid、projectId、對應來源與核對狀態，具體 Schema 另提 Migration。不能整批把 U010 改字串就算已綁定。
- 先保留現有外鍵與歷史；由可靠帳號／受控人工確認建立對照。非唯一姓名、同電話、多專案 UID 都要人工處理。
- users/{uid} 路徑為通知收件 UID；文件 id 欄位只作核對，兩者不一致時不得改用文件 id 發送。
- 新線上回報須驗 Firebase 身分，不信任自由傳入 userId。DTN 來源採另行核准的簽章與裝置註冊關聯；轉送者身分不是原始回報者。
- 未能確認 UID 的歷史事件仍可查，但不可直接用來選個人通知收件者。

### 7.3 最小可靠同步流程

1. 定義 envelope schemaVersion、eventId、eventType、originSystem、originUid／keyId、eventAt、payload、payloadHash；現有 uuid／emergencyId／requestId 優先沿用為事件唯一識別，不因換傳輸途徑重生 ID。
2. 增設受控 inbox 去重帳（具體 Schema待提案）：依來源命名空間／事件類型／ID 唯一。寫業務資料與標記已接收在同一 SQLite 交易內完成；庫存與狀態仍交現有 Service。
3. 同 key、同內容重送回可識別 replay／已接收；同 key、不同內容列衝突、不得 silently IGNORE。現有三種 INSERT OR IGNORE 能阻止同表重複插入，但不能證明來源或辨識內容衝突，正式同步仍需補齊。
4. SQLite 業務交易與待發布 outbox 同筆提交；同步 worker 交易外呼叫 Firestore，使用決定性事件／投影 ID，成功後標記 ack。不能聲稱 SQLite + Firestore 有跨庫原子交易。
5. 中斷於遠端寫入成功但本地未 ack 時，用同 ID 重試，不再次執行預留／出庫。退避、重試上限、人工死信佇列、斷線重啟必須測試。
6. 已有 Firestore 通知發布使用自己的交易與 clientRequestId 去重；直接沿用，不另造平行發送流程。日後 DTN 投遞列隊需先讀已發布記錄並以 messageId 去重；跨來源投遞狀態獨立保存。
7. 可變資料用權威來源的 revision／expectedVersion 條件更新；庫存／狀態不採裝置時間的 last-write-wins。不可變回報衝突留存供核對，不擅自覆蓋。
8. 同步游標／revision 只處理權威變更，帶 origin／operationId 防止鏡像回寫形成循環；中斷可從檢查點續傳。保留刪除 tombstone／停用事件與合理保留期，避免舊裝置把已刪資料復活。
9. eventAt、receivedAt、syncedAt 分開；全部新增傳輸契約建議含時區 UTC。未知／不可信時鐘需標記，不補成當下；過期、未來時間與最大偏移政策由組間核准。
10. 對帳至少比對唯一事件數、版本、payloadHash、庫存及出庫紀錄，不以「畫面有資料」作同步成功證據。

Outbox／inbox、版本與 identity mapping 尚未實作。本次不建表或進行正式資料切換。

## 8. 各組配合與 DTN 契約

### 8.1 使用者 App 組交付

| 交付項 | 必須包含 | 完成證據 |
| --- | --- | --- |
| 身分與 profile 契約 | Firebase Project／App 環境、AppUser 原始 Model、脫敏 users/{uid} 範例、emailVerified／disabled處理、profile 寫入 Rules | 真測試帳號登入、驗證、profile建立；無 Email 驗證／錯 UID等反例 |
| 三種回報契約 | ID 產生／重送策略、GPS nullable、address 可缺、sentAt／reportTime／reportedAt、離線事件時間、欄位型別與狀態 | 各一組有／無位置、有／無時間與延遲同步 JSON，手機到SQLite核對 |
| 通知收件匣 | users/{uid}/notifications 與 broadcasts 的讀取／監聽、schemaVersion、expiresAt、同messageId去重、登出換帳號清理 | A／B帳號互不越權，過期處理，斷線恢復無重複顯示 |
| 手機權限與離線行為 | GPS、藍牙、背景限制、使用者同意、取消／停權／刪除帳號處理 | 目標 Android／iOS 真機與版本清單及實測紀錄 |
| Rules／索引協作 | 現有完整規則、查詢條件／排序／所需索引 | 合併後Emulator規則測試與staging查詢成功 |

### 8.2 通訊組交付

- 可取得的 Repository／版本、目標手機平台、藍牙 discover／connect／傳輸及 Flutter bridge API；不是只提供模擬 JSON。
- 封包版本、messageId／eventId、messageType、origin／keyId、recipientScope、createdAt／eventAt、expiresAt／TTL、hopLimit／hopCount、payloadHash、簽章及加密格式。
- 身分生命週期：在線註冊裝置公鑰與 Firebase UID 的可信關聯、離線驗簽、換機／撤銷／金鑰遺失／最大離線時長；離線不應依賴立即向 Firebase 驗證可用性。過期 ID Token 不能直接當長效 DTN 簽章。
- 明確規範 TTL 是起源端期限、時鐘偏差或累計停留時間，不能每跳重設；區分不可改的簽署內容與可更新 hop header，不能讓中繼任意竄改原事件。
- 持久佇列、去重窗口、儲存容量、重送退避、分片完整性、防循環、ACK 類型與重啟續傳。
- 上行接收與下行通知／廣播接口；橋接有網路手機只能轉送，不能用自己的 Firebase UID 改寫原回報者。
- 端到端加密讓中繼不能讀私人 SOS／健康／個人通知；廣播仍須管理中心簽章、服務範圍與期限驗證。公鑰分發與裝置撤銷策略需共同設計，不以「有AES」當完整安全證據。
- 未驗證來源的緊急訊息如何顯示／人工核對必須另有操作政策；不能偽裝成已驗證居民，也不能因外部地理編碼／雲端不通而使原訊息無法保存於隔離待核對佇列。

### 8.3 DTN 驗收矩陣

| 情境 | 期望結果 |
| --- | --- |
| A離線→B離線→C有網路→後端 | 保存原事件ID／GPS／eventAt，後端receivedAt另記；能對照手機與SQLite資料 |
| HTTP、Firestore與DTN同事件同時到達 | 業務事件一筆、需求預留最多一次，回覆可辨識 replay |
| A→B→A循環、同包重送、節點重啟 | 有限轉送，去重帳／待同步佇列在重啟後保留 |
| 過期、超hopLimit、破損分片、偽造簽章 | 不進入已驗證業務流程；留下最少必要診斷，不洩漏原內容 |
| 原本離線、連網後同步途中斷線 | 同ID續傳，已出庫資料不再次扣庫存，不能只靠記憶體去重 |
| 管理端廣播→有網路手機→離線手機 | 原messageId、來源簽章、期限與範圍保持，非收件人不得讀個人內容 |
| 中繼ACK／伺服器保存ACK／收件裝置收到／使用者已讀 | 四種語意分開，不能一個ACK全部算送達或已讀 |
| GPS／Firebase／地址服務不可用 | 不硬補位置／時間、不假稱身分驗證成功；依可用通道保存或排隊回報，不丟失事件 |

## 9. 正式部署前的 Gate

### 9.1 授權與安全 Gate

- 全路由授權矩陣含管理員、App、DTN、服務帳號；依用途分開讀／寫／發布／廣播與管理中心範圍。舊 API 可保留但不能是繞過入口。
- 現有 receiverAdminId／username 不是服務範圍的授權證明；不得讓客戶端自由指定範圍後直接讀取全體個資。
- 伺服器 ADC／IAM 只保留所需權限、分環境、可輪替，優先管理身分；私鑰／Token不進Flutter或Repository。Firebase平台設定與伺服器私鑰不是同一種資料，不能誤用。
- IAM 寫入不受客戶端 Firestore Rules 當作權限邊界；後端驗證和Rules都要測。現有 profile存在／email非空檢查不等於查過 Firebase Auth 的 emailVerified／disabled。
- Rules例子尚未部署，禁止直接覆蓋既有App規則；檢查重疊 allow 的OR效果、管理紀錄隔離、使用者不能發布全體廣播。
- TLS、正式來源清單與適當CORS、登入／寫入／外部查詢限流、request body大小、欄位驗證、錯誤遮罩、SQL參數化、日誌權限／保留期與稽核事件。
- 日誌不得留下身份、電話、精確位置、憑證或完整SQLite exception parameters；現在有直接 print(e) 等路徑，正式前需遮罩。
- 確認服務帳號失效、資料庫鎖定、外部provider無網路時明確失敗，不 fallback Mock，不影響其他回報入口。

### 9.2 Migration／資料切換 Gate

1. 唯讀核對實際DB絕對路徑、Schema版本、使用中的程序、正式／測試資料清單；本次沒有做正式DB核對。
2. 停寫並建立新的SQLite一致性備份，不直接複製活躍db主檔忽略WAL；驗證備份可獨立還原。
3. 在副本演練增補欄位／索引／identity mapping／同步帳，使用版本化、可重跑且受控的Migration。正式啟動不再無條件seed或隱式改Schema。
4. OFFICE001 開帳：核對實際盤點、現有 station_inventory、舊 inventory、各未結案預留與歷史調度；由資料負責人決定基準並留下對帳記錄。不能把舊表與各站數量直接相加。
5. 方案A與舊義工任務分清：claimed／舊dispatched／沒有新出庫標記的歷史資料不自動轉換、不清空義工欄位、不重新出庫。需要人工處理時另走核准的補償／結案方案。
6. 核對保留數與任務帳；沒有逐筆庫存異動帳的歷史區段不能僅靠status／qty推測已扣量。必要的異動稽核Schema另提，不倒造歷史事件。
7. 全步驟記錄預期／實際影響筆數；庫存非負、外鍵完整、唯一ID、狀態與時間一致，執行 integrity_check／foreign_key_check 並驗證部署時 foreign_keys 設定。
8. 上線後最小查詢／受控測試、重啟與對帳；有新寫入後回復備份需先處理新增事件，不能盲目還原造成居民回報遺失。保留回復點、停寫條件與責任人。

### 9.3 測試／發布 Gate

| 範圍 | 必測證據 |
| --- | --- |
| 編譯與契約 | 後端與完整管理端正式入口可編譯；跨App Model／JSON契約測試；nullable舊資料與錯誤碼 |
| SQLite核心流程 | 入庫2+3=5；同單位增量、不同單位不合併；預留／出庫／完成；批次總量不足；交易回滾／併發／重啟持久化 |
| UI真寫入 | SOS結案、入庫、預留、出庫、完成操作後查DB並重啟驗證；失敗不得只更新UI |
| 安全 | 每個路由401／403／範圍越權、偽造ID、過期Session、停權、來源偽造、Rules拒絕案例 |
| 通知與Firebase | Mock／Emulator／stagingADC真服務分層；跨帳號讀取、clientRequestId衝突、未確認提交、發布紀錄、過期與App展示 |
| 位置 | 有／無address、GPS、時間；保持精度、時間語意；單筆開詳情才查、限流快取；Provider失敗不影響回報；正式政策核准 |
| DTN與手機 | 真多跳、斷網續傳、TTL、簽章加密、重複與重啟；上行保存與下行通知分開驗收 |
| 災時營運 | 慢外部查詢不阻塞SOS、尖峰／鎖競爭、服務重啟、備份還原、告警與人工操作手冊 |

最終「正式可使用」需附候選版本或工作樹快照、環境、測試帳號分類、重現步驟、預期／實際結果、未解風險與負責人簽認。尚有重大缺口時只能標為限定測試或DEMO，不降低資料安全條件來過關。

## 10. 建議執行順序與交付里程碑

1. **M0：P0基線**。修編譯、真寫入、Seed／環境隔離與路由防護；核准Firebase專案／UID契約。保留今天可用的獨立DEMO，但清楚標示。
2. **M1：管理端完整流程**。主UI完成OFFICE001單筆、批次／審核，Session與權限覆蓋，舊流程入口停用但歷史可查。
3. **M2：Firebase測試環境閉環**。App profile／UID核對、通知ADC／IAM、合併Rules、兩帳號收件匣；同時完成SQLite／Firestore權責與同步契約。
4. **M3：DTN最小閉環**。先定封包／身分／inbox去重，再做真機上行多跳；其後加入管理通知下行。每階段保留Mock及真機證據的區別。
5. **M4：正式候選驗收**。核准位置Provider、正式Migration副本演練、資安與容量測試、備份還原、運維手冊與組間簽認，再另行申請正式切換。
6. **M5：P2**。FCM、區域通知與DTN優化；不阻礙前面基本資料正確性與權限完成。

本計畫沒有承諾未經各組確認的日期。建議各組在M0先填負責人與目標日期；跨組依賴未交付時，狀態應標「待契約／待外部驗證」，不能寫「已完成」。

## 11. 待確認事項清單

- 使用者App實際Repository／版本、Firebase Auth Project、AppUser與原始回報JSON、Firestore物資collections、既有Rules與索引。
- 兩個不同Firebase Project是否刻意分工；staging專案／預算／IAM責任人。
- 管理中心服務範圍與管理員角色，正式帳密／停權／Session撤銷需求。
- 物資盤點基準、未結案預留、舊義工／調度歷史的人工結案責任人。
- 通訊組實際藍牙封包、手機平台、Flutter bridge、金鑰管理、TTL／ACK及最大離線時長。
- 位置Provider的政策／隱私／費用核准、位置保留與新鮮度門檻。
- 醫療／位置資料最少保留、刪除與使用者同意規則，備份保留及RPO／RTO目標。

上述均需交付證據後更新本文件；本次不猜測另一個App或通訊組已實作，也不將尚未執行的測試列為成功。
