/// Plan Model - يمثل خطة شهرية للـ DM
class Plan {
  final String id;
  final String dmId;
  final String dmName;
  final String date; // Format: YYYY-MM-DD
  final String mrId;
  final String mrName;
  final String status; // 'pending', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  Plan({
    required this.id,
    required this.dmId,
    required this.dmName,
    required this.date,
    required this.mrId,
    required this.mrName,
    this.status = 'pending',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dmId': dmId,
      'dmName': dmName,
      'date': date,
      'mrId': mrId,
      'mrName': mrName,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] ?? '',
      dmId: json['dmId'] ?? '',
      dmName: json['dmName'] ?? '',
      date: json['date'] ?? '',
      mrId: json['mrId'] ?? '',
      mrName: json['mrName'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  /// Create from Supabase JSON (snake_case)
  factory Plan.fromSupabaseJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id']?.toString() ?? '',
      dmId: json['dm_id']?.toString() ?? '',
      dmName: json['dm_name']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      mrId: json['mr_id']?.toString() ?? '',
      mrName: json['mr_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  /// Create a copy with updated fields
  Plan copyWith({
    String? id,
    String? dmId,
    String? dmName,
    String? date,
    String? mrId,
    String? mrName,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Plan(
      id: id ?? this.id,
      dmId: dmId ?? this.dmId,
      dmName: dmName ?? this.dmName,
      date: date ?? this.date,
      mrId: mrId ?? this.mrId,
      mrName: mrName ?? this.mrName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if plan is for today
  bool get isToday {
    final now = DateTime.now();
    final planDate = DateTime.parse(date);
    return planDate.year == now.year &&
        planDate.month == now.month &&
        planDate.day == now.day;
  }

  /// Check if plan is in the past
  bool get isPast {
    final now = DateTime.now();
    final planDate = DateTime.parse(date);
    return planDate.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Check if plan is in the future
  bool get isFuture {
    final now = DateTime.now();
    final planDate = DateTime.parse(date);
    return planDate.isAfter(DateTime(now.year, now.month, now.day));
  }
}

