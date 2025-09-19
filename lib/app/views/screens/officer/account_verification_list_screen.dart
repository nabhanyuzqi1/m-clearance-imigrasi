import 'package:flutter/material.dart';
import '../../../localization/app_localizations.dart';
import '../../../repositories/user_repository.dart';
import '../../../models/user_model.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../widgets/custom_app_bar.dart';

class AccountVerificationListScreen extends StatefulWidget {
  const AccountVerificationListScreen({super.key});

  @override
  State<AccountVerificationListScreen> createState() => _AccountVerificationListScreenState();
}

class _AccountVerificationListScreenState extends State<AccountVerificationListScreen> {
  late final UserRepository repo;
  String _selectedFilter = 'all'; // 'all', 'waiting', 'reviewed'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    LoggingService().info('AccountVerificationListScreen initialized');
    repo = UserRepository();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshList() async {
    LoggingService().debug('Refreshing account verification list');
    setState(() {});
  }

  String _tr(String key) => AppLocalizations.of(context).get('accountVerificationList.$key');

  List<UserModel> _filterUsers(List<UserModel> users, String searchQuery) {
    // First filter by status
    List<UserModel> filtered = users;
    switch (_selectedFilter) {
      case 'waiting':
        filtered = users.where((user) => user.status == 'pending_approval').toList();
        break;
      case 'reviewed':
        filtered = users.where((user) => user.status != 'pending_approval').toList();
        break;
      case 'all':
      default:
        filtered = users;
        break;
    }

    // Then filter by search query
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((user) {
        return user.username.toLowerCase().contains(query) ||
               user.email.toLowerCase().contains(query) ||
               user.corporateName.toLowerCase().contains(query) ||
               user.nationality.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Widget _buildFilterButton(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => setState(() => _selectedFilter = filter),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.primaryColor.withAlpha(25) : Colors.transparent,
          foregroundColor: isSelected ? AppTheme.primaryColor : AppTheme.greyColor,
          side: BorderSide(
            color: isSelected ? AppTheme.primaryColor : AppTheme.greyShade300,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          padding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: AppTheme.fontSizeSmall,
          ),
        ),
      ),
    );
  }

  // Helper to get status properties
  Map<String, dynamic> _getStatusProperties(BuildContext context, String status) {
    switch (status) {
      case 'verified':
        return {'color': AppTheme.successColor, 'label': _tr('status_verified')};
      case 'pending_approval':
        return {'color': AppTheme.warningColor, 'label': _tr('status_pending')};
      case 'rejected':
        return {'color': AppTheme.errorColor, 'label': _tr('status_rejected')};
      case 'pending_email_verification':
        return {'color': AppTheme.infoColor, 'label': _tr('status_pending_email')};
      case 'pending_upload_documents':
        return {'color': AppTheme.infoColor, 'label': _tr('status_pending_documents')};
      default:
        return {'color': AppTheme.greyColor, 'label': status};
    }
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final statusProps = _getStatusProperties(context, status);
    final chipColor = statusProps['color'] as Color;
    final chipLabel = statusProps['label'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(25),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: chipColor, width: 1.5),
      ),
      child: Text(
        chipLabel,
        style: TextStyle(
          color: chipColor,
          fontWeight: FontWeight.bold,
          fontSize: AppTheme.fontSizeSmall,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building AccountVerificationListScreen');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        titleText: AppLocalizations.of(context).get('accountVerificationList.title'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.onSurface),
            onPressed: _refreshList,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.responsivePadding(context), vertical: AppTheme.spacing8),
            color: AppTheme.whiteColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _tr('search_hint'),
                prefixIcon: const Icon(Icons.search, color: AppTheme.greyColor),
                filled: true,
                fillColor: AppTheme.greyShade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          // Filter buttons
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.responsivePadding(context), vertical: AppTheme.spacing8),
            color: AppTheme.whiteColor,
            child: Row(
              children: [
                _buildFilterButton('all', _tr('all')),
                const SizedBox(width: 8),
                _buildFilterButton('waiting', _tr('waiting')),
                const SizedBox(width: 8),
                _buildFilterButton('reviewed', _tr('reviewed')),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshList,
              child: StreamBuilder<List<UserModel>>(
                // Stream to fetch the list of users with pending account verifications
                stream: repo.streamAllUsers(),
                builder: (context, snapshot) {
                  // Display a loading indicator while waiting for the data
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Display an error message if there's an error fetching the data
                  if (snapshot.hasError) {
                    LoggingService().error('Error fetching pending approvals: ${snapshot.error}');
                    return Center(child: Text(_tr('error_loading')));
                  }
                  // Get the list of users from the snapshot
                  final allUsers = snapshot.data ?? const [];

                  // Filter users based on selected filter and search
                  final users = _filterUsers(allUsers, _searchController.text);

                  // Display a message if there are no users with pending account verifications
                  if (users.isEmpty) {
                    return Center(child: Text(_tr('no_data')));
                  }
                  // Display the list of users
                  return ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return InkWell(
                        onTap: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            '/account-detail',
                            arguments: {'uid': user.uid},
                          );
                          if (result == true) _refreshList();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: AppTheme.whiteColor,
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.greyShade200.withAlpha(128),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withAlpha(25),
                                child: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
                              ),
                              const SizedBox(width: 16.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.username.isNotEmpty ? user.username : user.email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: AppTheme.fontSizeMedium,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      user.email,
                                      style: const TextStyle(
                                        color: AppTheme.greyColor,
                                        fontSize: AppTheme.fontSizeSmall,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16.0),
                              _buildStatusChip(context, user.status),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
