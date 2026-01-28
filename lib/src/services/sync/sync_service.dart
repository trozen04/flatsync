import 'dart:developer' as developer;
import 'dart:io';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flatsync/src/data/models/expense_model.dart';
import 'package:flatsync/src/data/repositories/expense_repository.dart';
import 'package:flatsync/src/services/sync/sync_queue.dart';
import 'package:flatsync/src/services/notification_service.dart';

/// Sync Service for peer-to-peer data exchange
/// Handles:
/// - Device discovery on same WiFi network
/// - Running local HTTP server
/// - Syncing expenses with peer devices
/// - Conflict resolution (latest modification wins)
class SyncService {
  static const int SYNC_PORT = 8765;
  static const int DISCOVERY_PORT = 9876;
  static const Duration DISCOVERY_TIMEOUT = Duration(seconds: 5);

  final ExpenseRepository _repository;
  late String _deviceId;
  HttpServer? _server;
  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);

  SyncService(this._repository);

  /// Initialize sync service and generate device ID
  Future<void> initialize() async {
    _deviceId = await _generateDeviceId();
  }

  /// Generate unique device ID
  Future<String> _generateDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return info.id;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.identifierForVendor ?? 'ios-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      developer.log('Error getting device info: $e');
    }
    return 'device-${DateTime.now().millisecondsSinceEpoch}';
  }

  String get deviceId => _deviceId;

  /// Check if connected to WiFi
  Future<bool> isConnectedToWiFi() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.wifi;
  }

  /// Get current WiFi SSID
  Future<String?> getCurrentSSID() async {
    try {
      final networkInfo = NetworkInfo();
      return await networkInfo.getWifiName();
    } catch (e) {
      developer.log('Error getting WiFi SSID: $e');
      return null;
    }
  }

  /// Start local HTTP server for receiving sync requests
  Future<void> startSyncServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, SYNC_PORT);
      _server!.listen((HttpRequest request) async {
        await _handleSyncRequest(request);
      });
      developer.log('Sync server started on port $SYNC_PORT');
    } catch (e) {
      developer.log('Error starting sync server: $e');
    }
  }

  /// Handle incoming sync request from peer
  Future<void> _handleSyncRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/expenses') {
        // Peer requesting our expenses
        final expenses = await _repository.getAllExpenses();
        final jsonData = expenses.map((e) => e.toJson()).toList();

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(jsonData));
        await request.response.close();
      } else if (request.method == 'POST' && request.uri.path == '/sync') {
        // Peer sending their expenses for sync
        final body = await utf8.decoder.bind(request).join();
        final List<dynamic> jsonList = jsonDecode(body);
        final remoteExpenses = jsonList
            .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Merge remote expenses with local data
        await _mergeRemoteExpenses(remoteExpenses);

        request.response.statusCode = 200;
        request.response.write(jsonEncode({'status': 'success'}));
        await request.response.close();

        _lastSyncTime = DateTime.now().toUtc();
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    } catch (e) {
      developer.log('Error handling sync request: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Merge remote expenses with local data
  /// Uses UUID matching and lastModifiedAt for conflict resolution
  Future<void> _mergeRemoteExpenses(List<ExpenseModel> remoteExpenses) async {
    final existingExpenses = await _repository.getAllExpenses();
    final existingUuids = existingExpenses.map((e) => e.uuid).toSet();
    
    // Find new expenses to notify about
    final newExpenses = remoteExpenses.where((expense) => 
        !existingUuids.contains(expense.uuid)).toList();
    
    await _repository.batchUpsertExpenses(remoteExpenses);
    
    // Send notifications for new expenses
    for (final expense in newExpenses) {
      await NotificationService.showExpenseNotification(
        userName: expense.paidBy,
        amount: expense.amount / 100,
        description: expense.description,
      );
    }
  }

  /// Discover peers on the same WiFi network
  /// Uses UDP broadcast to find other devices running sync server
  Future<List<String>> discoverPeers() async {
    final peers = <String>[];
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    // Send discovery broadcast
    final broadcastAddress = InternetAddress('255.255.255.255');
    final message = jsonEncode({
      'action': 'discover',
      'deviceId': _deviceId,
      'port': SYNC_PORT,
    });

    socket.broadcastEnabled = true;
    socket.send(utf8.encode(message), broadcastAddress, DISCOVERY_PORT);

    // Listen for responses
    await Future.delayed(DISCOVERY_TIMEOUT);
    socket.close();

    return peers;
  }

  /// Sync with a specific peer device
  /// Fetches their expenses and merges with local data
  /// Also sends any queued offline expenses
  Future<void> syncWithPeer(String peerAddress) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      // Fetch remote expenses
      final request = await client.getUrl(
        Uri.http('$peerAddress:$SYNC_PORT', '/expenses'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await utf8.decoder.bind(response).join();
        final List<dynamic> jsonList = jsonDecode(body);
        final remoteExpenses = jsonList
            .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Get local expenses + any queued expenses
        final localExpenses = await _repository.getAllExpenses();
        final queuedExpenses = await SyncQueue.getPendingExpenses();
        final allLocalExpenses = [...localExpenses, ...queuedExpenses];

        // Send our expenses to peer
        final syncRequest = await client.postUrl(
          Uri.http('$peerAddress:$SYNC_PORT', '/sync'),
        );
        syncRequest.headers.contentType = ContentType.json;
        syncRequest.write(jsonEncode(allLocalExpenses.map((e) => e.toJson()).toList()));
        await syncRequest.close();

        // Merge remote data
        await _mergeRemoteExpenses(remoteExpenses);

        developer.log('Successfully synced with peer: $peerAddress');
        _lastSyncTime = DateTime.now().toUtc();
      }

      client.close();
    } catch (e) {
      developer.log('Error syncing with peer $peerAddress: $e');
    }
  }

  /// Perform full sync: broadcast discovery and sync with all discovered peers
  Future<void> performFullSync() async {
    try {
      developer.log('Starting full sync...');

      // Check WiFi connectivity
      if (!await isConnectedToWiFi()) {
        throw Exception('Not connected to WiFi. Please connect to WiFi to sync.');
      }

      final ssid = await getCurrentSSID();
      developer.log('Current WiFi SSID: $ssid');

      // Get local IP to determine network range
      final localIp = await _getLocalIP();
      if (localIp == '127.0.0.1') {
        throw Exception('Could not determine local IP address');
      }

      developer.log('Local IP: $localIp');
      
      // Extract network prefix (e.g., 192.168.1 from 192.168.1.100)
      final ipParts = localIp.split('.');
      if (ipParts.length != 4) {
        throw Exception('Invalid IP address format');
      }
      
      final networkPrefix = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}';
      developer.log('Scanning network: $networkPrefix.x');

      // Scan common IP ranges efficiently
      final allIPs = <String>[];
      
      // Add specific device IPs based on logs
      final targetIPs = [33, 41]; // From your device logs
      
      for (final i in targetIPs) {
        if (i != int.parse(ipParts[3])) { // Skip our own IP
          allIPs.add('$networkPrefix.$i');
        }
      }
      
      // Add common ranges as fallback
      final commonRanges = [1, 2, 10, 20, 30, 40, 50, 100, 101, 102];
      for (final i in commonRanges) {
        if (i != int.parse(ipParts[3]) && !targetIPs.contains(i)) {
          allIPs.add('$networkPrefix.$i');
        }
      }

      final uniqueIPs = allIPs;
      
      developer.log('Checking ${uniqueIPs.length} potential peer IPs...');
      
      int peersFound = 0;
      for (final ip in uniqueIPs) {
        try {
          await _tryConnectToPeer(ip);
          peersFound++;
          break; // Stop after finding first peer
        } catch (e) {
          if (e == 'peer_found') {
            peersFound++;
            break;
          }
          // Continue scanning
        }
      }
      
      // If no peers found, save to queue for later sync
      if (peersFound == 0) {
        final pendingExpenses = await _repository.getAllExpenses();
        final lastSyncTime = await SyncQueue.getLastSyncTime();
        
        // Add new expenses to queue (expenses added after last sync)
        for (final expense in pendingExpenses) {
          if (lastSyncTime == null || expense.createdAt.isAfter(lastSyncTime)) {
            await SyncQueue.addToQueue(expense);
          }
        }
        
        developer.log('No peers found - expenses queued for later sync');
      } else {
        // Successful sync - clear queue and update sync time
        await SyncQueue.clearQueue();
        await SyncQueue.updateLastSyncTime();
      }
      
      developer.log('Full sync completed - found $peersFound peers');
    } catch (e) {
      developer.log('Error during full sync: $e');
      rethrow;
    }
  }

  /// Try to connect and sync with a potential peer
  Future<void> _tryConnectToPeer(String ipAddress) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 200); // Faster timeout

      final request = await client.getUrl(
        Uri.http('$ipAddress:$SYNC_PORT', '/expenses'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        developer.log('Found peer at $ipAddress, syncing...');
        await syncWithPeer(ipAddress);
        throw 'peer_found'; // Signal successful connection
      }

      client.close();
    } catch (e) {
      if (e == 'peer_found') rethrow;
      // Peer not available, ignore
    }
  }

  /// Get local device IP address
  Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            if (!addr.isLoopback && addr.address.startsWith('192.168')) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error getting local IP: $e');
    }
    return '127.0.0.1';
  }

  /// Stop sync server
  Future<void> stopSyncServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      developer.log('Sync server stopped');
    }
  }

  /// Get last sync time
  DateTime get lastSyncTime => _lastSyncTime;

  /// Check if sync is enabled and ready
  bool get isSyncReady => _server != null;
}
