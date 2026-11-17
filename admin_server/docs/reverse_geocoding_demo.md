# 互CARES：Reverse Geocoding DEMO

## 今日建議使用獨立展示入口

既有管理端完整 `dart analyze lib` 在修改前已有 9 個 error（健康 Model 缺 address、EmergencyViewModel 缺 errorMessage、仍使用 id/handled）。本次不修改這些業務邏輯。新元件已接至 citizen_page 的 SOS 詳情，但原管理端仍被這些既存錯誤擋住，不能宣稱整個管理端已可編譯。

另提供 `lib/reverse_geocoding_demo.dart`：使用同一 SOS 地址元件、真實後端登入及查詢 API，僅用公開地標測試座標。這個入口不匯入原管理端 Dashboard 或 Firebase，供今天直接展示。

## 終端機一：啟動隔離後端

在專案根目錄用 PowerShell：

```powershell
cd admin_server
$env:REVERSE_GEOCODING_DEMO = 'true'
$env:REVERSE_GEOCODING_DEMO_SITES = 'taipei101'
$env:REVERSE_GEOCODING_USER_AGENT = 'HuCARES-Demo/1.0 (mailto:請換成你們可聯絡的Email)'
$env:REVERSE_GEOCODING_DAILY_LIMIT = '20'
$env:DEMO_PORT = '8081'
dart run bin/reverse_geocoding_demo.dart
```

**先把 User-Agent 的聯絡 Email 換成真實可聯絡的專題聯絡方式，再啟動。不要原樣複製佔位文字。** 也可使用 `HuCARES-Demo/1.0 (https://你們的公開專題聯絡網址)`。不需要 Google API Key、Firebase 授權或服務帳號。

此入口只監聽 loopback，建立新的臨時 `demo.sqlite`，只含假管理員與合成 SOS，不使用 `DatabaseService.init()`、既有 Seed、正式 admin.db 或正式 Migration。終端機印出臨時檔案位置。

隔離帳密為 `demo_admin` / `DemoOnly123!`，只適用此 DEMO Server，不是正式管理員憑證。重啟後須重新登入。不要把這個測試帳號建立到正式 DB。

若 8081 已被占用，改 DEMO_PORT 與下一步 API_BASE_URL 為同一個其他未使用的 Port，不要停止既有 Server/ngrok。

## 終端機二：啟動獨立 Flutter 畫面

在專案根目錄：

```powershell
flutter run -d chrome -t lib/reverse_geocoding_demo.dart --dart-define=API_BASE_URL=http://127.0.0.1:8081
```

1. 點「登入獨立 DEMO 管理員」。
2. 點「開啟無地址 SOS 詳情（自動查詢）」。只有這時才呼叫後端；若服務、網路及設定正常，顯示服務實際回傳的地址。
3. 畫面保留 `25.033964, 121.564468`、顯示來源、地址僅供參考及 OSM attribution。
4. 關閉重開同一詳情，後端使用快取，不新增對外查詢。
5. 點「開啟已有 App 地址的 SOS（不查詢）」：只顯示測試的 App 位置描述，不對外解析。
6. 失敗時顯示 GPS、「地址無法取得」及手動重試；不自動輪詢。後端冷卻期間不得反覆對外呼叫。
7. 想展示未啟用：關閉**自己啟動的隔離 DEMO Server**，將 REVERSE_GEOCODING_DEMO 改 false 後重啟並重新登入。查詢回 503，絕不產生假地址。

瀏覽器刷新會清除記憶體中的 Token，需重新登入。不要用正式 SOS、居民位置或其他未列入白名單的座標測試。此入口的「App 已提供地址」是清楚標示的測試文字，不是假裝查詢成功。

## 設定

| 環境變數 | 說明 |
| --- | --- |
| REVERSE_GEOCODING_DEMO | 必須精確為 true 才能啟用，預設停用 |
| REVERSE_GEOCODING_DEMO_SITES | 明確選擇公開測試地標，逗號分隔；沒有設定則停用 |
| REVERSE_GEOCODING_USER_AGENT | 必填 HuCARES-Demo/ 版本及可聯絡 Email 或 https 網址 |
| REVERSE_GEOCODING_DAILY_LIMIT | 預設 20，每日 1–100 次，按 UTC 日期計算；失敗嘗試也計入 |
| REVERSE_GEOCODING_ENDPOINT | 選填；預設 https://nominatim.openstreetmap.org/reverse；只允許 https，無 query、fragment、userInfo。只有明確獲准的 Nominatim 相容服務才可設定，不自動 fallback |
| DEMO_PORT | 僅隔離啟動器使用，預設 8081 |

固定測試地標：

- taipei101：latitude 25.033964、longitude 121.564468。
- taipei_main_station：latitude 25.0478、longitude 121.5170。

以上名稱只用來選擇白名單，**絕不作為查詢地址輸出**。座標採精確數值匹配，不接受附近座標或用四捨五入繞過限制；可啟用其中一個或兩個。

正式 `bin/admin_server.dart` 也已註冊相同 API 及環境設定，但本次不要為了 DEMO 啟動它，因為其既有 init() 會處理正式 DB Schema。本次不曾啟動正式入口或修改其 DB。

## API

POST 既有 endpoint，JSON body，先呼叫 login 取得 Session：

```http
Authorization: Bearer <login 回傳的 token>
Content-Type: application/json
```

```json
{"type":"reverseGeocode","latitude":25.033964,"longitude":121.564468}
```

成功回應格式（`address` 下列為欄位佔位說明，**不是實際查詢結果**）：

```json
{
  "success": true,
  "data": {
    "latitude": 25.033964,
    "longitude": 121.564468,
    "address": "服務當次實際回傳的 display_name",
    "source": "OpenStreetMap Nominatim",
    "status": "resolved",
    "cached": false,
    "attribution": "© OpenStreetMap contributors (ODbL)",
    "attributionUrl": "https://www.openstreetmap.org/copyright",
    "notice": "地址僅供參考",
    "demo": true
  }
}
```

未啟用：

```json
{"success":false,"status":"unavailable","code":"GEOCODING_DEMO_DISABLED","message":"尚未啟用測試座標限定的 DEMO 地址服務"}
```

冷卻／限流回應包含 `retryAfterSeconds` 與 Retry-After header；前端只能稍後手動重試，不能自動批次補查。

| HTTP | code | 意義 |
| --- | --- | --- |
| 400 | INVALID_GPS | 缺少、字串、布林、無效數值、越界或 (0,0) |
| 401 | ADMIN_SESSION_REQUIRED | 未登入、Token 錯誤或已到期 |
| 403 | ADMIN_DISABLED | 已驗證 Session 的管理員帳號不再存在 |
| 403 | DEMO_COORDINATES_ONLY | 不在啟用的公開地標白名單，未送到第三方 |
| 429 | RATE_LIMITED | 全域每秒限制或服務冷卻 |
| 429 | DAILY_QUOTA_EXCEEDED | UTC 當日額度已滿 |
| 502 | UPSTREAM_ERROR / UPSTREAM_RATE_LIMITED / ADDRESS_NOT_FOUND | 服務非 200 或無地址，不接受自動 redirect |
| 503 | GEOCODING_DEMO_DISABLED / GEOCODING_UNAVAILABLE | 未啟用、設定錯誤、無網路或其他服務失敗 |
| 504 | GEOCODING_TIMEOUT | 對外查詢逾時 |

管理員驗證重用既有隨機 Session Bearer Token，並查詢 admins 確認帳號存在；現有資料表沒有更細的角色／停權欄位，沒有憑空宣稱有額外 RBAC。請求內的 adminId 不作授權依據。

## 控管及隱私

- 單一共用 Service；所有管理員與所有座標共用每秒最多一次。不同座標過快直接回 429，不排隊批次查。
- 每座標成功快取 24 小時，最多 256 筆；相同座標同時查詢合併成一個 Future。
- 地址及失敗快取只在記憶體，**地址不寫回任何 SQLite**。重啟後地址快取清空。
- 失敗冷卻 30 秒，適用所有座標；每次網路嘗試都計入每日額度。沒有自動重試或背景排程。
- 對外 timeout 6 秒；UI 等後端最多 9 秒。HTTP redirect 不跟隨。
- `%TEMP%/hucares_geocoding_demo/state.sqlite` 只保存每日次數及限流／冷卻時間，沒有居民資訊、座標、地址或 Token。交易確保共享此檔的本機 Server 不會重複消耗同一限流時段；重啟不會重設額度。不要為了突破限額刪除此檔。
- 同座標合併與地址快取以程序為範圍。此 DEMO 請只啟動一個查詢 Server，不支援分散到多台電腦各自計額度。
- 對外只發送 lat、lon、format、語系及 addressdetails，不轉送 Bearer Token、使用者 ID、姓名、電話、需求內容或 SOS 描述。
- 不修改 report address、GPS、事件時間、庫存或 users.area。查詢故障不參與三種回報 INSERT。
- 原 `_fetchAddress` 與未使用 `_AddressWidget` 已移除，避免 Flutter 直接繞過後端控管；Google Maps 按鈕保留。

公共服務政策：https://operations.osmfoundation.org/policies/nominatim/ 。每秒上限是整個應用總量；需識別、快取、attribution，不可傳送個資或做批次、網格、背景週期查詢。若服務要求停止使用，將 DEMO 關閉或切到經批准的替代 endpoint，不需改 UI。

## 修改檔案

後端：bin/admin_server.dart（註冊／初始化／handleReverseGeocode）、lib/services/reverse_geocoding_service.dart、bin/reverse_geocoding_demo.dart、test/reverse_geocoding_test.dart。

Flutter：lib/admin_APP/screens/citizen_page.dart（單筆 SOS 詳情接入，移除直連原型）、lib/admin_APP/screens/login_page.dart（保存 Token 到記憶體）、lib/admin_APP/services/reverse_geocoding_client.dart、lib/admin_APP/widgets/sos_address_details.dart、lib/reverse_geocoding_demo.dart、test/reverse_geocoding_widget_test.dart。

既有 SOS／健康／需求寫入程式、Model、正式 DB Schema 及 Firebase 不在本次修改範圍。未 Commit／Push。

## 本次實測結果

- 新增後端逆地理編碼測試 17 項通過，含 Mock 外部回應與真正啟動隔離 DEMO Server、登入、未啟用回 503 的整合測試。
- 原位置保存測試 20 項持續通過；新服務不參與 SOS、健康或需求寫入。
- 完整後端 dart test：130 通過、1 個既存載入失敗（空白 test/admin_server_test.dart 缺 main()）。不是整套全綠。
- 後端 dart analyze：exit 0，僅 2 個既存 info，無 error/warning。
- flutter test --no-pub test/reverse_geocoding_widget_test.dart：6 項全部通過（App 地址優先、開詳情才查、loading／成功／歸因、錯誤重試、未知 GPS 不查、冷卻不自動重試、Bearer Client）。
- 新 Flutter Client、Widget 與獨立 DEMO 入口 dart analyze：No issues found。
- flutter build web --no-pub --target lib/reverse_geocoding_demo.dart --dart-define=API_BASE_URL=http://127.0.0.1:8081：實際編譯成功，輸出 build/web。
- 原完整 Flutter lib 在本次修改前的分析為 9 個 error；這些既有 Model/ViewModel 問題未在本功能中修復。不能用獨立入口成功推論原管理端全體可編譯。
- git diff --check：相關既有檔案無空白錯誤。
- 本次沒有真的呼叫 Nominatim，沒有使用真實居民資料，所有地址測試回應清楚標示 MOCK。尚未驗證外部服務當下連線狀況。正式展示須使用正確 User-Agent 設定、啟用 DEMO、有網路並取得當次實際服務回應；若無法取得，畫面誠實顯示失敗。
- 未修改正式 admin.db、未執行正式 Migration、未連接 Firebase，未中斷任何原本 Server/ngrok，未 Commit/Push。
