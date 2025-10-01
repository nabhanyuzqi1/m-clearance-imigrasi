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
  State<AccountVerificationListScreen> createState() =>
      _AccountVerificationListScreenState();
}

class _AccountVerificationListScreenState
    extends State<AccountVerificationListScreen> {
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

  String _tr(String key) =>
      AppLocalizations.of(context).get('accountVerificationList.$key');

  List<UserModel> _filterUsers(List<UserModel> users, String searchQuery) {
    // First filter by status
    List<UserModel> filtered = users;
    switch (_selectedFilter) {
      case 'waiting':
        filtered = users
            .where((user) => user.status.startsWith('pending'))
            .toList();
        break;
      case 'reviewed':
        filtered = users
            .where((user) => !user.status.startsWith('pending'))
            .toList();
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

  Widget _buildFilterButton(
    String filter,
    String label,
    ColorScheme colorScheme,
  ) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() => _selectedFilter = filter);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          foregroundColor: isSelected
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant,
          elevation: isSelected ? 2 : 0,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  Map<String, dynamic> _getStatusProperties(
    String status,
    ColorScheme colorScheme,
  ) {
    switch (status) {
      case 'approved':
        return {'color': colorScheme.tertiary, 'label': _tr('status_approved')};
      case 'rejected':
        return {'color': colorScheme.error, 'label': _tr('status_rejected')};
      case 'pending_documents':
      case 'pending_upload_docs':
        return {
          'color': colorScheme.primary,
          'label': _tr('status_pending_documents'),
        };
      case 'pending_email_verification':
      case 'pending_email':
        return {
          'color': colorScheme.primary,
          'label': _tr('status_pending_email_verification'),
        };
      case 'pending_verification_officer':
      case 'pending_approval':
        return {
          'color': colorScheme.secondary,
          'label': _tr('status_pending_approval'),
        };
      default:
        return {'color': colorScheme.secondary, 'label': _tr('status_pending')};
    }
  }

  Widget _buildUserCard(UserModel user, ColorScheme colorScheme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusProps = _getStatusProperties(user.status, colorScheme);
    final statusColor = statusProps['color'] as Color;
    final statusLabel = statusProps['label'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(13),
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
              color: colorScheme.primary,
              size: screenWidth * 0.08,
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username.isNotEmpty ? user.username : user.email,
                    style: AppTheme.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.corporateName.isNotEmpty
                        ? user.corporateName
                        : user.email,
                    style: AppTheme.bodySmall(
                      context,
                    ).copyWith(color: colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.alternate_email,
                        size: screenWidth * 0.04,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          user.email,
                          style: AppTheme.bodySmall(
                            context,
                          ).copyWith(color: colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing12,
                vertical: AppTheme.spacing8,
              ),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusLabel,
                style: AppTheme.labelSmall(
                  context,
                ).copyWith(color: statusColor, fontWeight: FontWeight.bold),
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
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalInset = AppTheme.responsivePadding(context);
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        titleText: AppLocalizations.of(
          context,
        ).get('accountVerificationList.title'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: _refreshList,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: horizontalInset,
              vertical: 12,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalInset * 0.75,
              vertical: 12,
            ),
            color: colorScheme.surface,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: _tr('search_hint'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
          ),
          // Filter buttons
          Container(
            margin: EdgeInsets.only(
              left: horizontalInset,
              right: horizontalInset,
              bottom: 8,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalInset * 0.75,
              vertical: 8,
            ),
            color: colorScheme.surface,
            child: Row(
              children: [
                _buildFilterButton('all', _tr('all'), colorScheme),
                const SizedBox(width: 8),
                _buildFilterButton('waiting', _tr('waiting'), colorScheme),
                const SizedBox(width: 8),
                _buildFilterButton('reviewed', _tr('reviewed'), colorScheme),
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
                    LoggingService().error(
                      'Error fetching users: ${snapshot.error}',
                    );
                    return Center(child: Text(_tr('error_loading')));
                  }
                  final allUsers = snapshot.data ?? const [];
                  final users = _filterUsers(allUsers, _searchController.text);

                  if (users.isEmpty) {
                    return Center(child: Text(_tr('no_data')));
                  }
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalInset,
                      vertical: AppTheme.spacing16,
                    ),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(users[index], colorScheme);
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
