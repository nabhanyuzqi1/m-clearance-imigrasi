// ignore_for_file: unused_element, unused_local_variable

import 'package:flutter/material.dart';
import 'arrival_detail_screen.dart';
import 'departure_detail_screen.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';
import '../../../models/user_account.dart';
import '../../../services/user_service.dart';
import '../../../services/logging_service.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/custom_app_bar.dart';
import 'clearance_form_screen.dart';
import 'clearance_result_screen.dart';

enum HistoryFilter { all, arrival, departure }

class UserHistoryScreen extends StatefulWidget {
  final UserAccount userAccount;
  final String initialLanguage;

  const UserHistoryScreen({
    super.key,
    required this.userAccount,
    required this.initialLanguage,
  });

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  HistoryFilter _currentFilter = HistoryFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _tr(String key) => AppStrings.tr(
        context: context,
        screenKey: 'userHistory',
        stringKey: key,
        langCode: widget.initialLanguage,
      );

  @override
  void initState() {
    super.initState();
    LoggingService().info('UserHistoryScreen initialized for user: ${widget.userAccount.name}');
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing UserHistoryScreen');
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter(HistoryFilter filter) {
    setState(() {
      _currentFilter = filter;
    });
  }

  Widget _buildFilterButton(String text, HistoryFilter filter) {
    final isSelected = _currentFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() { _currentFilter = filter; }); },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacing12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.whiteColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
            boxShadow: isSelected ? [BoxShadow(color: AppTheme.blackColor.withAlpha(25), blurRadius: 5, spreadRadius: 1)] : [],
          ),
          child: Center(child: Text(text, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppTheme.onSurface, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily))),
        ),
      ),
    );
  }

  List<ClearanceApplication> _filterApplications(List<ClearanceApplication> applications) {
    List<ClearanceApplication> filteredList;
    switch (_currentFilter) {
      case HistoryFilter.arrival:
        filteredList = applications.where((app) => app.type == ApplicationType.kedatangan).toList();
        break;
      case HistoryFilter.departure:
        filteredList = applications.where((app) => app.type == ApplicationType.keberangkatan).toList();
        break;
      case HistoryFilter.all:
      filteredList = applications;
    }

    if (_searchQuery.isNotEmpty) {
      filteredList = filteredList.where((app) {
        final query = _searchQuery.toLowerCase();
        return app.shipName.toLowerCase().contains(query) ||
            (app.port?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filteredList;
  }

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return _tr('waiting');
      case ApplicationStatus.revision:
        return _tr('revision');
      case ApplicationStatus.approved:
        return _tr('approved');
      case ApplicationStatus.declined:
        return _tr('declined');
    }
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return AppTheme.primaryColor;
      case ApplicationStatus.revision:
        return AppTheme.warningColor;
      case ApplicationStatus.approved:
        return AppTheme.successColor;
      case ApplicationStatus.declined:
        return AppTheme.errorColor;
    }
  }

  Widget _buildStatusChip(ApplicationStatus status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing12, vertical: AppTheme.spacing8),
      decoration: BoxDecoration(color: _getStatusColor(status).withAlpha(25), borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: _getStatusColor(status), size: 10),
          SizedBox(width: AppTheme.spacing8),
          Text(_getStatusText(status), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily)),
        ],
      ),
    );
  }

  void _showApplicationDetail(ClearanceApplication app) {
    if (app.type == ApplicationType.kedatangan) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArrivalDetailScreen(
            application: app,
            initialLanguage: widget.initialLanguage,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DepartureDetailScreen(
            application: app,
            initialLanguage: widget.initialLanguage,
          ),
        ),
      );
    }
  }

  Widget _buildDialogTitle(ClearanceApplication app) {
    final title = app.type == ApplicationType.kedatangan ? _tr('arrival_detail') : _tr('departure_detail');
    return Center(child: Column(children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppTheme.onSurface)), Text(app.shipName, style: TextStyle(fontSize: AppTheme.fontSizeBody2, color: AppTheme.subtitleColor, fontFamily: 'Poppins')), const Divider()]));
  }

  Widget _buildAboutSection(ClearanceApplication app) {
    final isArrival = app.type == ApplicationType.kedatangan;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr('about'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.fontSizeBody1, fontFamily: 'Poppins', color: AppTheme.onSurface)), SizedBox(height: AppTheme.spacing8), Text("${isArrival ? _tr('last_port') : _tr('next_port')}: ${app.port ?? 'N/A'}, ${app.flag}", style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface)), Text("${_tr('crewlist')}: ${app.wniCrew ?? '0'} WNI - ${app.wnaCrew ?? '0'} WNA", style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface))]);
  }

  Widget _buildAgentSection(ClearanceApplication app) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr('agent'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.fontSizeBody1, fontFamily: 'Poppins', color: AppTheme.onSurface)), SizedBox(height: AppTheme.spacing8), Row(children: [const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)), SizedBox(width: AppTheme.spacing8), Text(app.agentName, style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface))])]);
  }

  Widget _buildNoteSection(ClearanceApplication app) {
    if (app.status == ApplicationStatus.waiting || app.status == ApplicationStatus.approved) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr('note_by_officer'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.fontSizeBody1, fontFamily: 'Poppins', color: AppTheme.onSurface)), SizedBox(height: AppTheme.spacing8), Text(app.status == ApplicationStatus.revision ? "${_tr('need_fix')} - ${app.notes ?? _tr('no_notes')}" : app.status == ApplicationStatus.declined ? "${_tr('declined')} - ${app.notes ?? _tr('no_notes')}" : "", style: TextStyle(color: AppTheme.errorColor, fontFamily: 'Poppins'))]);
  }

  Widget _buildDialogActions(ClearanceApplication app) {
    switch (app.status) {
      case ApplicationStatus.revision:
        return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ClearanceFormScreen(type: app.type, agentName: widget.userAccount.name, existingApplication: app, initialLanguage: widget.initialLanguage))); }, child: Text(_tr('fix_button')));
      case ApplicationStatus.declined:
        return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor), onPressed: () => Navigator.pop(context), child: Text(_tr('done_button')));
      case ApplicationStatus.approved:
        return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ClearanceResultScreen(application: app, initialLanguage: widget.initialLanguage))); }, child: Text(_tr('reports_button')));
      case ApplicationStatus.waiting:
      return TextButton(onPressed: () => Navigator.pop(context), child: Text("OK", style: TextStyle(fontFamily: 'Poppins', color: AppTheme.primaryColor)));
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth * 0.04;
    final verticalPadding = screenHeight * 0.02;

    return Scaffold(
      appBar: CustomAppBar(
        titleText: _tr('history'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppTheme.spacing16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _tr('search_hint'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.greyShade100,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing8, horizontal: AppTheme.spacing16),
            child: Container(
              decoration: BoxDecoration(color: AppTheme.greyShade100, borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterButton(_tr('all'), HistoryFilter.all),
                  _buildFilterButton(_tr('arrival'), HistoryFilter.arrival),
                  _buildFilterButton(_tr('departure'), HistoryFilter.departure),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ClearanceApplication>>(
              stream: UserService().getUserApplications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonListLoader(itemCount: 6);
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('${_tr('error_loading')}: ${snapshot.error}', style: TextStyle(fontSize: AppTheme.responsiveFontSize(context, mobile: 14, tablet: 16, desktop: 18), fontFamily: 'Poppins', color: AppTheme.onSurface)),
                  );
                }

                final applications = snapshot.data ?? [];
                final filteredApplications = _filterApplications(applications);

                if (filteredApplications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppTheme.spacing24),
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withAlpha(12), shape: BoxShape.circle),
                          child: Icon(Icons.image_outlined, size: 60, color: AppTheme.primaryColor.withAlpha(51)),
                        ),
                        SizedBox(height: AppTheme.spacing24),
                        Text(_tr('empty_title'), style: TextStyle(fontSize: AppTheme.fontSizeH5, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppTheme.onSurface)),
                        SizedBox(height: AppTheme.spacing8),
                        Text(_tr('empty_subtitle'), textAlign: TextAlign.center, style: TextStyle(color: AppTheme.subtitleColor, fontSize: AppTheme.fontSizeBody1, fontFamily: 'Poppins')),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(AppTheme.spacing8),
                  itemCount: filteredApplications.length,
                  itemBuilder: (context, index) {
                    final app = filteredApplications[index];
                    return GestureDetector(
                      onTap: () => _showApplicationDetail(app),
                      child: Card(
                        elevation: 2, margin: EdgeInsets.only(bottom: AppTheme.spacing12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                        child: Padding(
                          padding: EdgeInsets.all(AppTheme.spacing16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(app.type == ApplicationType.kedatangan ? Icons.anchor : Icons.directions_boat, color: AppTheme.greyShade600),
                                  SizedBox(width: AppTheme.spacing8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(app.type == ApplicationType.kedatangan ? _tr('arrival') : _tr('departure'), style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppTheme.onSurface)),
                                      Text("${app.shipName} - ${app.port ?? 'N/A'}", style: TextStyle(color: AppTheme.subtitleColor, fontFamily: 'Poppins')),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: AppTheme.spacing8),
                              Text(app.date ?? 'No Date', style: TextStyle(color: AppTheme.subtitleColor, fontFamily: 'Poppins')),
                              SizedBox(height: AppTheme.spacing12),
                              _buildStatusChip(app.status),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}