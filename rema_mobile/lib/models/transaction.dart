class RemaTransaction {
  final String id;          // Correspond à transaction_uuid côté Python
  final String senderPk;    // sender_pk
  final String? receiverPk; // receiver_pk
  final double amount;      // amount
  final int timestamp;      // timestamp (BigInteger)
  final String signature;   // signature

  RemaTransaction({
    required this.id,
    required this.senderPk,
    this.receiverPk, 
    required this.amount,
    required this.timestamp,
    required this.signature,
  });

  // Pour lire ce qui vient du disque ou du réseau
  factory RemaTransaction.fromJson(Map<String, dynamic> json) {
    return RemaTransaction(
      id: json['transaction_uuid'] ?? json['id'] ?? '',
      senderPk: json['sender_pk'] ?? '', 
      receiverPk: json['receiver_pk'],
      amount: (json['amount'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      signature: json['signature'] ?? '',
    );
  }

  // Pour envoyer au Backend Python (Format SQLAlchemy strict)
  Map<String, dynamic> toJson() {
    return {
      'transaction_uuid': id,   // ✅ Match exact avec transaction.py
      'sender_pk': senderPk,    // ✅ Match exact
      if (receiverPk != null) 'receiver_pk': receiverPk,
      'amount': amount,
      'timestamp': timestamp,
      'signature': signature,
      'type': 'OFFLINE_PAYMENT', // Valeur par défaut utile
      'status': 'COMPLETED',
      'is_offline_synced': true
    };
  }

  // Pour la signature crypto (Le contenu exact à signer)
  String toSignableString() {
    return "$id|$senderPk|$amount|$timestamp";
  }
}