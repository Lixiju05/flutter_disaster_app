import 'package:flutter/material.dart';
import 'package:flutter_disaster_app/core/models/citizen.dart';
import 'package:flutter_disaster_app/core/repositories/admin_repository.dart';
class CitizenViewmodel extends ChangeNotifier{
  List<Citizen> _citizens=[];
  List<Citizen> get citizens => _citizens;

  bool _isLoading=false;  //是否載入資料 UI根據狀態顯示loading spinner
  bool get isLoading => _isLoading; 

  CitizenViewmodel(){
    loadCitizens();
  }
  final _repository=AdminRepository() ;
  //載入民眾資料
  Future<void> loadCitizens() async{
    _isLoading=true;
    notifyListeners();

    _citizens=await _repository.getCitizens();

    _isLoading=false;
    notifyListeners();
  }
  //搜尋民眾
  void search(String keyword) async {
    // 如果你要重新從伺服器搜尋，要加上 await
    // 如果只是在本地篩選，請確保 _citizens 已經被 await 過了
    if (keyword.isEmpty) {
      await loadCitizens();
      return;
    }
    _citizens = _citizens
        .where((c) => c.name.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
    notifyListeners();
  }
  //更新民眾是否需要救援
  void updateNeedsRescue(Citizen citizen, bool needsRescue){
    final index= _citizens.indexWhere((c) => c.id == citizen.id);
    if (index != -1){
      _citizens[index].needsRescue=needsRescue;
      notifyListeners();
    }
  }
}