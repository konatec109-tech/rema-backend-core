class RemaTransaction {
  // --- [Doc Section 8.1] HEADER ---
  final String uuid;          
  final int protocolVer;      

  // --- [Doc Section 4.3] SÉCURITÉ ---
  final String nonce;         
  final int timestamp;        

  // --- [Doc Section 8.1] IDENTITÉ ---
  final String senderPk;      
  final String? receiverPk;   

  // --- [Doc Section 8.1] VALEUR ---
  final int amount;           // 🔥 INT OBLIGATOIRE
  final int currency;         

  // --- [Doc Section 4.1] PREUVE ---
  final String signature;     
  final String? checksum;     
  
  // 🔥 AJOUT B2B (VISA / FEDAPAY)
  final String metadata;

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
    this.metadata = "{}" // Par défaut vide
  });

  // Factory : Création depuis JSON (Disque ou Réseau)
  factory RemaTransaction.fromJson(Map<String, dynamic> json) {
    return RemaTransaction(
      uuid: json['uuid'] ?? json['transaction_uuid'] ?? '',
      protocolVer: json['protocol_ver'] ?? 1,
      nonce: json['nonce'] ?? '',
      senderPk: json['sender_pk'] ?? '',
      receiverPk: json['receiver_pk'],
      
      amount: (json['amount'] as num).toInt(),
      
      currency: json['currency'] ?? 952,
      timestamp: json['timestamp'] as int,
      signature: json['signature'] ?? '',
      checksum: json['checksum'],
      metadata: json['metadata'] ?? "{}" // ✅ On récupère la métadonnée
    );
  }

  // Serialisation : Envoi vers le Backend Python
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'protocol_ver': protocolVer,
      'nonce': nonce,
      'sender_pk': senderPk,
      'receiver_pk': receiverPk,
      'amount': amount,
      'currency': currency,
      'signature': signature,
      'timestamp': timestamp,
      'type': 'OFFLINE_PAYMENT',
      'metadata': metadata // ✅ On l'envoie
    };
  }
}