class LegalDocument {
  final String content;
  final DateTime? updatedAt;

  const LegalDocument({required this.content, this.updatedAt});

  bool get hasContent => content.trim().isNotEmpty;

  LegalDocument copyWith({String? content, DateTime? updatedAt}) {
    return LegalDocument(
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const empty = LegalDocument(content: '');
}

enum LegalDocumentType { terms, privacy }

extension LegalDocumentTypeX on LegalDocumentType {
  String get databaseKey {
    switch (this) {
      case LegalDocumentType.terms:
        return 'terms';
      case LegalDocumentType.privacy:
        return 'privacy';
    }
  }

  String localizationKey() {
    switch (this) {
      case LegalDocumentType.terms:
        return 'legal.terms_title';
      case LegalDocumentType.privacy:
        return 'legal.privacy_title';
    }
  }
}
