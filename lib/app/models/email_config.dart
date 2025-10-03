class EmailConfig {
  final String smtpHost;
  final int smtpPort;
  final String smtpUsername;
  final String smtpPassword;
  final bool smtpUseTls;
  final String fromEmail;
  final String fromName;
  final String verificationSubject;
  final String verificationBody;
  final String verificationTemplateId;
  final String passwordResetSubject;
  final String passwordResetBody;
  final String passwordResetTemplateId;
  final String approvalSubject;
  final String approvalBody;
  final String approvalTemplateId;
  final String rejectionSubject;
  final String rejectionBody;
  final String rejectionTemplateId;
  final DateTime updatedAt;

  EmailConfig({
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpPassword,
    required this.smtpUseTls,
    required this.fromEmail,
    required this.fromName,
    required this.verificationSubject,
    required this.verificationBody,
    required this.verificationTemplateId,
    required this.passwordResetSubject,
    required this.passwordResetBody,
    required this.passwordResetTemplateId,
    required this.approvalSubject,
    required this.approvalBody,
    required this.approvalTemplateId,
    required this.rejectionSubject,
    required this.rejectionBody,
    required this.rejectionTemplateId,
    required this.updatedAt,
  });

  factory EmailConfig.fromJson(Map<String, dynamic> json) {
    return EmailConfig(
      smtpHost: json['smtpHost'] ?? '',
      smtpPort: json['smtpPort'] ?? 587,
      smtpUsername: json['smtpUsername'] ?? '',
      smtpPassword: json['smtpPassword'] ?? '',
      smtpUseTls: json['smtpUseTls'] ?? true,
      fromEmail: json['fromEmail'] ?? '',
      fromName: json['fromName'] ?? '',
      verificationSubject: json['verificationSubject'] ?? 'Email Verification',
      verificationBody: json['verificationBody'] ?? 'Please verify your email',
      verificationTemplateId: json['verificationTemplateId'] ?? '',
      passwordResetSubject: json['passwordResetSubject'] ?? 'Password Reset',
      passwordResetBody: json['passwordResetBody'] ?? 'Reset your password',
      passwordResetTemplateId: json['passwordResetTemplateId'] ?? '',
      approvalSubject: json['approvalSubject'] ?? 'Application Approved',
      approvalBody: json['approvalBody'] ?? 'Your application has been approved',
      approvalTemplateId: json['approvalTemplateId'] ?? '',
      rejectionSubject: json['rejectionSubject'] ?? 'Application Rejected',
      rejectionBody: json['rejectionBody'] ?? 'Your application has been rejected',
      rejectionTemplateId: json['rejectionTemplateId'] ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'smtpHost': smtpHost,
      'smtpPort': smtpPort,
      'smtpUsername': smtpUsername,
      'smtpPassword': smtpPassword,
      'smtpUseTls': smtpUseTls,
      'fromEmail': fromEmail,
      'fromName': fromName,
      'verificationSubject': verificationSubject,
      'verificationBody': verificationBody,
      'verificationTemplateId': verificationTemplateId,
      'passwordResetSubject': passwordResetSubject,
      'passwordResetBody': passwordResetBody,
      'passwordResetTemplateId': passwordResetTemplateId,
      'approvalSubject': approvalSubject,
      'approvalBody': approvalBody,
      'approvalTemplateId': approvalTemplateId,
      'rejectionSubject': rejectionSubject,
      'rejectionBody': rejectionBody,
      'rejectionTemplateId': rejectionTemplateId,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  EmailConfig copyWith({
    String? smtpHost,
    int? smtpPort,
    String? smtpUsername,
    String? smtpPassword,
    bool? smtpUseTls,
    String? fromEmail,
    String? fromName,
    String? verificationSubject,
    String? verificationBody,
    String? verificationTemplateId,
    String? passwordResetSubject,
    String? passwordResetBody,
    String? passwordResetTemplateId,
    String? approvalSubject,
    String? approvalBody,
    String? approvalTemplateId,
    String? rejectionSubject,
    String? rejectionBody,
    String? rejectionTemplateId,
    DateTime? updatedAt,
  }) {
    return EmailConfig(
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpUsername: smtpUsername ?? this.smtpUsername,
      smtpPassword: smtpPassword ?? this.smtpPassword,
      smtpUseTls: smtpUseTls ?? this.smtpUseTls,
      fromEmail: fromEmail ?? this.fromEmail,
      fromName: fromName ?? this.fromName,
      verificationSubject: verificationSubject ?? this.verificationSubject,
      verificationBody: verificationBody ?? this.verificationBody,
      verificationTemplateId: verificationTemplateId ?? this.verificationTemplateId,
      passwordResetSubject: passwordResetSubject ?? this.passwordResetSubject,
      passwordResetBody: passwordResetBody ?? this.passwordResetBody,
      passwordResetTemplateId: passwordResetTemplateId ?? this.passwordResetTemplateId,
      approvalSubject: approvalSubject ?? this.approvalSubject,
      approvalBody: approvalBody ?? this.approvalBody,
      approvalTemplateId: approvalTemplateId ?? this.approvalTemplateId,
      rejectionSubject: rejectionSubject ?? this.rejectionSubject,
      rejectionBody: rejectionBody ?? this.rejectionBody,
      rejectionTemplateId: rejectionTemplateId ?? this.rejectionTemplateId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}