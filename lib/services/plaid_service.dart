import 'dart:async';
import 'package:plaid_flutter/plaid_flutter.dart';
import '../models/transaction.dart';
import 'supabase_service.dart';

class PlaidService {
  static Future<void> disconnect() async {
    await SupabaseService.client.functions.invoke('plaid-disconnect');
  }

  static Future<String> _getLinkToken() async {
    final res = await SupabaseService.client.functions.invoke(
      'plaid-link-token',
    );
    final data = res.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
    return data['link_token'] as String;
  }

  /// Opens Plaid Link and exchanges the token on success.
  /// Returns true if the user connected a bank, false if they cancelled or errored.
  static Future<bool> connect() async {
    final linkToken = await _getLinkToken();
    final completer = Completer<bool>();

    StreamSubscription<LinkSuccess>? successSub;
    StreamSubscription<LinkExit>? exitSub;

    void cleanup() {
      successSub?.cancel();
      exitSub?.cancel();
    }

    successSub = PlaidLink.onSuccess.listen((event) async {
      cleanup();
      try {
        await SupabaseService.client.functions.invoke(
          'plaid-exchange-token',
          body: {
            'public_token': event.publicToken,
            'institution_name': event.metadata.institution?.name,
          },
        );
        if (!completer.isCompleted) completer.complete(true);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });

    exitSub = PlaidLink.onExit.listen((event) {
      cleanup();
      if (!completer.isCompleted) completer.complete(false);
    });

    await PlaidLink.create(
      configuration: LinkTokenConfiguration(token: linkToken),
    );
    await PlaidLink.open();

    return completer.future;
  }

  /// Fetches this month's transactions and account list via Edge Function.
  static Future<
    ({
      bool connected,
      String? institutionName,
      List<Transaction> transactions,
      List<PlaidAccount> accounts,
    })
  >
  fetchTransactions() async {
    final res = await SupabaseService.client.functions.invoke(
      'plaid-transactions',
    );
    final data = res.data as Map<String, dynamic>;

    if (data['connected'] == false) {
      return (
        connected: false,
        institutionName: null,
        transactions: <Transaction>[],
        accounts: <PlaidAccount>[],
      );
    }

    final txns = (data['transactions'] as List<dynamic>)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();

    final accounts = (data['accounts'] as List<dynamic>? ?? [])
        .map((e) => PlaidAccount.fromJson(e as Map<String, dynamic>))
        .toList();

    return (
      connected: true,
      institutionName: data['institution_name'] as String?,
      transactions: txns,
      accounts: accounts,
    );
  }
}
