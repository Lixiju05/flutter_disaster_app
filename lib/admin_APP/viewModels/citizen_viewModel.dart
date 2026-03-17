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

    _citizens=_repository.getCitizens();

    _isLoading=false;
    notifyListeners();
  }
  //搜尋民眾
  void search(String keyword){
    _citizens=_repository.getCitizens()
    .where((c) => c.name.toLowerCase().contains(keyword.toLowerCase())).toList();
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