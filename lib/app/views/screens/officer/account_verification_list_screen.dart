import 'package:flutter/material.dart';
import '../../../localization/app_localizations.dart';
import '../../../localization/app_strings.dart';
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

  Widget _buildStatusChip(BuildContext context, String status) {
    Color chipColor;
    String chipLabel;

    switch (status) {
      case 'pending_approval':
        chipColor = Colors.orange;
        chipLabel = _tr('status_pending');
        break;
      case 'verified':
        chipColor = Colors.green;
        chipLabel = _tr('status_verified');
        break;
      case 'rejected':
        chipColor = Colors.red;
        chipLabel = _tr('status_rejected');
        break;
      default:
        chipColor = Colors.grey;
        chipLabel = status;
    }

    return Chip(
      label: Text(
        chipLabel,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
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
                hintText: AppLocalizations.of(context).get('userHistory.search_hint'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {});
              },
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
                      return Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16.0),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
                          ),
                          title: Text(
                            user.username.isNotEmpty ? user.username : user.email,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email),
                              const SizedBox(height: 4),
                              _buildStatusChip(context, user.status),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16.0),
                          onTap: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/account-detail',
                              arguments: {
                                'uid': user.uid,
                              },
                            );
                            if (result == true) {
                              _refreshList();
                            }
                          },
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
