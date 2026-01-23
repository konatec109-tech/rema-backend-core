class RemaTransaction {
  // --- [Doc Section 8.1] HEADER ---
  final String uuid;          // Tx_UUID (Identifiant unique)
  final int protocolVer;      // Version du protocole (Défaut: 1)

  // --- [Doc Section 4.3] SÉCURITÉ ---
  final String nonce;         // Nonce Cryptographique (Anti-Rejeu) - CRITIQUE
  final int timestamp;        // Horodatage UTC (ms)

  // --- [Doc Section 8.1] IDENTITÉ ---
  final String senderPk;      // Hash ou Clé Publique de l'émetteur
  final String? receiverPk;   // Hash ou Clé Publique du destinataire

  // --- [Doc Section 8.1] VALEUR ---
  final int amount;           // 🔥 INT OBLIGATOIRE (Unités atomiques). Pas de double.
  final int currency;         // Code ISO 4217 (952 pour XOF)

  // --- [Doc Section 4.1] PREUVE ---
  final String signature;     // Signature Ed25519
  final String? checksum;     // CRC32 pour intégrité rapide

  RemaTransaction({
    required this.uuid,
    this.protocolVer = 1,
    required this.nonce,
    required this.senderPk,
    this.receiverPk,
    required this.amount,
    this.currency = 952,
    required this.timestamp,
    required this.signature,
    this.checksum,
  });

  // Factory : Création depuis JSON (Disque ou Réseau)
  factory RemaTransaction.fromJson(Map<String, dynamic> json) {
    return RemaTransaction(
      uuid: json['uuid'] ?? json['transaction_uuid'] ?? '',
      protocolVer: json['protocol_ver'] ?? 1,
      nonce: json['nonce'] ?? '',
      senderPk: json['sender_pk'] ?? '',
      receiverPk: json['receiver_pk'],
      
      // ⚠️ Conversion forcée en entier. Si on reçoit 100.0, on garde 100.
      amount: (json['amount'] as num).toInt(),
      
      currency: json['currency'] ?? 952,
      timestamp: json['timestamp'] as int,
      signature: json['signature'] ?? '',
      checksum: json['checksum'],
    );
  }

  // Serialisation : Envoi vers le Backend Python (Doit matcher TransactionItem)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'protocol_ver': protocolVer,
      'nonce': nonce,
      'sender_pk': senderPk,
      if (receiverPk != null) 'receiver_pk': receiverPk,
      'amount': amount,       // Envoie un int pur (ex: 500), pas 500.0
      'currency': currency,
      'timestamp': timestamp,
      'signature': signature,
      if (checksum != null) 'checksum': checksum,
      'type': 'OFFLINE_PAYMENT',
    };
  }
}