import 'package:flutter/foundation.dart';
import '../../core/models/citizen.dart';
import '../../core/repositories/admin_repository.dart';

class CitizenViewmodel extends ChangeNotifier{
  List<Citizen> _citizens=[];
  List<Citizen> get Citizen => _citizens;

  bool _isLoading=false;  //是否載入資料 UI根據狀態顯示loading spinner
  bool get isLoading => _isLoading; 

  CitizenViewmodel(){
    loadCitizens();
  }
  //載入民眾資料
  Future<void> loadCitizens() async{
    _isLoading=true;
    ChangeNotifier();

    _citizens=AdminRepository.getCitizens();

    _isLoading=false;
    ChangeNotifier();
  }
  //搜尋民眾
  void search(String keyword){
    _citizens=AdminRepository.getCitizens();
    .where((c) => c.name.toLowerCase().contains(keyword.toLowerCase())).toList();
    ChangeNotifier();
  }
  //更新民眾是否需要救援
  void updateNeedsRescue(Citizen citizen, bool needsRescue){
    final index= _citizens.indexWhere((c) => c.id == citizen.id);
    if (index != -1){
      _citizens[index].needsRescue=needsRescue;
      ChangeNotifier();
    }
  }

}
