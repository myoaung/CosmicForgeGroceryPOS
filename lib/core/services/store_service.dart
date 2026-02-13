import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/store.dart';
// Note: In a real app complexity, we'd inject a Repository here. 
// For this phase, we'll simulate the DB calls or use a placeholder if Supabase isn't fully linked yet in Dart.
// Assuming we need to define the service class structure first.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store.dart';
import 'location_service.dart';
import '../security/security_guard.dart';

class StoreService {
  final LocationService _locationService;
  Store? _activeStore;
  
  StoreService({LocationService? locationService}) 
      : _locationService = locationService ?? LocationService();

  Store? get activeStore => _activeStore;

  // Mocking list of stores for development until Supabase client is fully wired
  List<Store> _mockStores = [
    Store(
      id: 'store_1', 
      tenantId: 'tenant_1', 
      storeName: 'Yangon Main Branch (Mock)', 
      currencyCode: 'MMK', 
      taxRate: 5.0, 
      isGeofenceEnabled: true,
      latitude: 16.8409, 
      longitude: 96.1735,
      authorizedBssid: 'aa:bb:cc:dd:ee:ff',
      createdAt: DateTime.now()
    ),
  ];

  /// Fetch stores from Supabase or fallback to Mock
  Future<List<Store>> fetchStores() async {
    try {
      final client = Supabase.instance.client;
      final response = await client.from('stores').select();
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Store.fromJson(json)).toList();
    } catch (e) {
      print('Supabase Fetch Error (or not init): $e. Using Mock Data.');
      return _mockStores;
    }
  }

  /// Sets the active store after verifying security constraints
  Future<bool> setActiveStore(Store store) async {
    if (!store.isGeofenceEnabled) {
      _activeStore = store;
      return true;
    }

    if (store.latitude == null || store.longitude == null) {
      print('Security Warning: Geフェnce enabled but no coordinates set. Blocking switch.');
      return false;
    }

    try {
      final position = await _locationService.getCurrentPosition();
      final isWithinRange = SecurityGuard.isWithinRange(
        store.latitude!, 
        store.longitude!, 
        position.latitude, 
        position.longitude
      );

      if (isWithinRange) {
        _activeStore = store;
        return true;
      } else {
        print('Security Alert: Device outside 100m radius of ${store.storeName}');
        return false;
      }
    } catch (e) {
      print('Location Service Error: $e');
      return false; // Fail safe
    }
  }

  Future<void> updateStoreTaxRate(String storeId, double newRate) async {
    try {
       final client = Supabase.instance.client;
       await client.from('stores').update({'tax_rate': newRate}).eq('id', storeId);
       
       // Update local active store if it matches
       if (_activeStore?.id == storeId) {
         _activeStore = _activeStore!.copyWith(taxRate: newRate);
       }
       print('Supabase: Tax Rate updated to $newRate.');
    } catch (e) {
      print('Supabase Update Error: $e. Using local mock fallback.');
       // Mock update:
      final index = _mockStores.indexWhere((s) => s.id == storeId);
      if (index != -1) {
        _mockStores[index] = _mockStores[index].copyWith(taxRate: newRate);
        if (_activeStore?.id == storeId) {
          _activeStore = _mockStores[index];
        }
      }
    }
  }

  Future<void> logAudit({required String actionType, required String description}) async {
    try {
       final client = Supabase.instance.client;
       await client.from('audit_trail').insert({
         'tenant_id': _activeStore?.tenantId ?? 'unknown',
         'action_type': actionType,
         'description': description,
         'timestamp': DateTime.now().toIso8601String(),
       });
       print('Audit Logged: $actionType');
    } catch (e) {
      print('Audit Log Error: $e');
    }
  }

  /// Verifies if the current transaction is allowed based on security rules
  Future<bool> validateSecurity() async {
    if (_activeStore == null) return false;
    // Re-use logic from setActiveStore or just check current position vs active store
    // For transactions, we might want a fresh check
    return setActiveStore(_activeStore!); 
  }
}
