# Disaster App - 管理端 Flutter 專案

## 專案說明
這是管理端的 Flutter App，包含民眾資料管理、物資分配、救援狀態更新等功能。

## 更新紀錄 (Changelog)

### 2026-03-13
- 修正 Citizen model
  - 將 `isRescued` 改成 `needsRescue`
  - `needsRescue` 欄位可修改 (非 final)
- ViewModel 更新
  - getter 改名為 `citizens`
  - 修正 `loadCitizens() / search() / updateNeedsRescue()` 使用方式
  - 修正 notifyListeners() 使用
- Repository 更新
  - `getCitizens()` 改成 instance 方法 (非 static) 或 static 方法
- 檔案搬移
  - 將 `viewModels` 從 `test/admin_APP/viewModels/` 移到 `lib/admin_APP/viewModels/`  
  - 讓 UI 組可以直接 import 使用，而不需要放在 test/ 
- 更新 import 路徑
  - 所有 ViewModel import Core Models 或 Repository 都改為：
    ```dart
    import 'package:flutter_disaster_app/admin_APP/viewModels/xxx_viewModel.dart';
    ```
  - 例如：
    ```dart
    import 'package:flutter_disaster_app/admin_APP/viewModels/citizen_viewModel.dart';
    ```
- 修正 EmergencyRequest model
  - 新增 `handled` 欄位 (bool) 可修改，用於追蹤求救是否已處理
  - 原本全為 final，UI 組無法直接更新


- UI 組注意事項
  - 所有 `isRescued` 改為 `needsRescue`
  - ViewModel getter 改為 `viewModel.citizens`
  - Repository 使用方式需對應新的 instance / static 設計
  - pull 最新 GitHub 後，更新 import 路徑：
     ```bash
     git pull origin main
     ```
  - 任何原本在 test/ 使用的 ViewModel，要改成從 lib/ import  
  - ViewModel 方法與欄位不變，UI 可直接使用
  - 現在可以使用 `emergency.handled = true` 或透過 ViewModel 的方法更新

### 2026-03-14 第一版
- **Supply_viewModel**
  - 新增 `supply_viewModel`，可管理物資分配、剩餘量計算及搜尋功能
  - 使用假資料初始化，方便 UI 組先做畫面
- **supply model**
  - 已存在的 model，欄位可修改，支援分配功能
- **說明**
  - UI 組可直接用 `Consumer<supply_viewModel>` 監聽資料
  - 支援載入、分配、搜尋功能