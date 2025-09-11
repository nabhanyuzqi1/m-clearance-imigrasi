import 'package:flutter/material.dart';

class AdminNotification {
  final String titleKey;
  final String bodyKey;
  final IconData icon;
  final Color color;

  AdminNotification({required this.titleKey, required this.bodyKey, required this.icon, required this.color});
}

class OfficerNotificationScreen extends StatefulWidget {
  final String initialLanguage;
  const OfficerNotificationScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<OfficerNotificationScreen> createState() => _OfficerNotificationScreenState();
}

class _OfficerNotificationScreenState extends State<OfficerNotificationScreen> {
  late String _selectedLanguage;

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Notifications',
      'mark_all_read_tooltip': 'Mark all as read',
      'mark_all_read_message': 'All notifications marked as read (simulation).',
      'empty_title': 'Nothing here. For now.',
      'empty_subtitle': "This is where you'll find what is\ngoing on",
      // Notification content
      'new_agent_reg_title': 'New Agent Registration',
      'new_agent_reg_body': 'PT. Bintang Samudera has submitted a registration. Please check their documents.',
      'submission_needs_review_title': 'Submission Needs Review',
      'submission_needs_review_body': 'KM. Egon has sent an arrival submission that needs your review.',
      'system_notice_title': 'System Notice',
      'system_notice_body': 'A scheduled system update will be performed tonight at 02:00 WIB.',
    },
    'ID': {
      'title': 'Notifikasi',
      'mark_all_read_tooltip': 'Tandai semua terbaca',
      'mark_all_read_message': 'Semua notifikasi ditandai terbaca (simulasi).',
      'empty_title': 'Tidak ada apa-apa. Untuk saat ini.',
      'empty_subtitle': 'Di sinilah Anda akan menemukan apa\nyang sedang terjadi',
      // Notification content
      'new_agent_reg_title': 'Pendaftaran Agen Baru',
      'new_agent_reg_body': 'PT. Bintang Samudera telah mengajukan pendaftaran. Mohon periksa dokumennya.',
      'submission_needs_review_title': 'Pengajuan Perlu Diperiksa',
      'submission_needs_review_body': 'KM. Egon telah mengirimkan pengajuan kedatangan yang perlu Anda periksa.',
      'system_notice_title': 'Pemberitahuan Sistem',
      'system_notice_body': 'Pembaruan sistem terjadwal akan dilakukan malam ini pukul 02:00 WIB.',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;
  
  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }
  
  final List<AdminNotification> _notifications = [
    AdminNotification(
      titleKey: "new_agent_reg_title",
      bodyKey: "new_agent_reg_body",
      icon: Icons.person_add_alt_1_outlined,
      color: Colors.blue,
    ),
    AdminNotification(
      titleKey: "submission_needs_review_title",
      bodyKey: "submission_needs_review_body",
      icon: Icons.anchor_outlined,
      color: Colors.orange,
    ),
    AdminNotification(
      titleKey: "system_notice_title",
      bodyKey: "system_notice_body",
      icon: Icons.settings_outlined,
      color: Colors.grey,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            pinned: true,
            expandedHeight: 120.0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_tr('title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: _tr('mark_all_read_tooltip'),
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_tr('mark_all_read_message'))),
                  );
                },
              ),
            ],
          ),
          _notifications.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.all(8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final notification = _notifications[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildNotificationItem(notification),
                        );
                      },
                      childCount: _notifications.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(AdminNotification notification) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.color.withAlpha(25),
          child: Icon(notification.icon, color: notification.color),
        ),
        title: Text(
          _tr(notification.titleKey),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _tr(notification.bodyKey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200.withAlpha(128),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            _tr('empty_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            _tr('empty_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
