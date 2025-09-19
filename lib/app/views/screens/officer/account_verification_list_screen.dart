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
        filtered = users.where((user) => user.status.startsWith('pending')).toList();
        break;
      case 'reviewed':
        filtered = users.where((user) => !user.status.startsWith('pending')).toList();
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
      child: ElevatedButton(
        onPressed: () {
          setState(() => _selectedFilter = filter);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.primaryColor : AppTheme.greyShade200,
          foregroundColor: isSelected ? AppTheme.whiteColor : AppTheme.blackColor87,
          elevation: isSelected ? 2 : 0,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontSizeSmall,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Helper to get status properties
  Map<String, dynamic> _getStatusProperties(BuildContext context, String status) {
    switch (status) {
      case 'approved':
        return {'color': AppTheme.successColor, 'label': _tr('status_approved')};
      case 'pending':
        return {'color': AppTheme.warningColor, 'label': _tr('status_pending')};
      case 'pending_email':
        return {'color': AppTheme.infoColor, 'label': _tr('status_pending_email')};
      case 'pending_upload_docs':
        return {'color': AppTheme.infoColor, 'label': _tr('status_pending_documents')};
      case 'pending_verification_officer':
        return {'color': AppTheme.accentColor, 'label': _tr('status_pending_officer')};
      case 'rejected':
        return {'color': AppTheme.errorColor, 'label': _tr('status_rejected')};
      default:
        return {'color': AppTheme.greyColor, 'label': status};
    }
  }


  Widget _buildUserCard(UserModel user) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final statusProps = _getStatusProperties(context, user.status);
    final statusColor = statusProps['color'] as Color;
    final statusLabel = statusProps['label'] as String;

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: screenWidth * 0.015),
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: AppTheme.whiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.greyShade200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.greyColor.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            '/account-detail',
            arguments: {'uid': user.uid},
          );
          if (result == true) _refreshList();
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(
              Icons.person_outline,
              color: AppTheme.primaryColor,
              size: screenWidth * 0.08,
            ),
            SizedBox(width: horizontalPadding * 0.5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username.isNotEmpty ? user.username : user.email,
                    style: AppTheme.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.blackColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.corporateName.isNotEmpty
                        ? user.corporateName
                        : user.email,
                    style: AppTheme.bodySmall(context)
                        .copyWith(color: AppTheme.greyColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: screenWidth * 0.01,
              ),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusLabel,
                style: AppTheme.labelSmall(context).copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
        titleText:
            AppLocalizations.of(context).get('accountVerificationList.title'),
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
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.whiteColor,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: _tr('search_hint'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.greyShade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.greyShade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.greyShade50,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
          // Filter buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                stream: repo.streamAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    LoggingService()
                        .error('Error fetching users: ${snapshot.error}');
                    return Center(child: Text(_tr('error_loading')));
                  }
                  final allUsers = snapshot.data ?? const [];
                  final users =
                      _filterUsers(allUsers, _searchController.text);

                  if (users.isEmpty) {
                    return Center(child: Text(_tr('no_data')));
                  }
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(users[index]);
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
