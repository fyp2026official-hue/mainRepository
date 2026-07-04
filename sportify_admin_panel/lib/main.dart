import 'package:flutter/material.dart';

import 'services/admin_api_service.dart';

void main() {
  runApp(const SportifyAdminApp());
}

enum AdminPage { dashboard, users, tournaments, matches, notifications }

class SportifyAdminApp extends StatefulWidget {
  const SportifyAdminApp({super.key});

  @override
  State<SportifyAdminApp> createState() => _SportifyAdminAppState();
}

class _SportifyAdminAppState extends State<SportifyAdminApp> {
  final api = AdminApiService();
  Map<String, dynamic>? admin;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sportify Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF166534),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
      home: api.isLoggedIn
          ? AdminShell(
              api: api,
              admin: admin,
              onLogout: _logout,
            )
          : LoginPage(
              api: api,
              onLogin: (value) {
                setState(() => admin = value);
              },
            ),
    );
  }

  void _logout() {
    api.clearToken();
    setState(() => admin = null);
  }
}

class LoginPage extends StatefulWidget {
  final AdminApiService api;
  final ValueChanged<Map<String, dynamic>> onLogin;

  const LoginPage({
    super.key,
    required this.api,
    required this.onLogin,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await widget.api.login(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
      );
      widget.onLogin(Map<String, dynamic>.from(data['admin'] ?? {}));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sportify Admin',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in with your admin credentials.',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => login(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => login(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: loading ? null : login,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  final AdminApiService api;
  final Map<String, dynamic>? admin;
  final VoidCallback onLogout;

  const AdminShell({
    super.key,
    required this.api,
    required this.admin,
    required this.onLogout,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  AdminPage selected = AdminPage.dashboard;

  String get title {
    switch (selected) {
      case AdminPage.dashboard:
        return 'Dashboard';
      case AdminPage.users:
        return 'Users';
      case AdminPage.tournaments:
        return 'Tournaments';
      case AdminPage.matches:
        return 'Matches';
      case AdminPage.notifications:
        return 'Notifications';
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    final body = Row(
      children: [
        if (wide) _Sidebar(selected: selected, onSelect: _selectPage),
        Expanded(
          child: Column(
            children: [
              _TopBar(
                title: title,
                admin: widget.admin,
                showMenu: !wide,
                onMenu: () => scaffoldKey.currentState?.openDrawer(),
                onLogout: widget.onLogout,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildPage(),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      key: scaffoldKey,
      drawer: wide
          ? null
          : Drawer(child: _Sidebar(selected: selected, onSelect: _selectPage)),
      body: Builder(builder: (_) => body),
    );
  }

  void _selectPage(AdminPage page) {
    setState(() => selected = page);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildPage() {
    switch (selected) {
      case AdminPage.dashboard:
        return DashboardPage(api: widget.api);
      case AdminPage.users:
        return UsersPage(api: widget.api);
      case AdminPage.tournaments:
        return TournamentsPage(api: widget.api);
      case AdminPage.matches:
        return MatchesPage(api: widget.api);
      case AdminPage.notifications:
        return PlaceholderPage(api: widget.api);
    }
  }
}

class _Sidebar extends StatelessWidget {
  final AdminPage selected;
  final ValueChanged<AdminPage> onSelect;

  const _Sidebar({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF111827),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Text(
                'Sportify',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _NavItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              selected: selected == AdminPage.dashboard,
              onTap: () => onSelect(AdminPage.dashboard),
            ),
            _NavItem(
              icon: Icons.people_alt_outlined,
              label: 'Users',
              selected: selected == AdminPage.users,
              onTap: () => onSelect(AdminPage.users),
            ),
            _NavItem(
              icon: Icons.emoji_events_outlined,
              label: 'Tournaments',
              selected: selected == AdminPage.tournaments,
              onTap: () => onSelect(AdminPage.tournaments),
            ),
            _NavItem(
              icon: Icons.sports_cricket_outlined,
              label: 'Matches',
              selected: selected == AdminPage.matches,
              onTap: () => onSelect(AdminPage.matches),
            ),
            _NavItem(
              icon: Icons.notifications_none,
              label: 'Notifications',
              selected: selected == AdminPage.notifications,
              onTap: () => onSelect(AdminPage.notifications),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        selected: selected,
        selectedTileColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: onTap,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final Map<String, dynamic>? admin;
  final bool showMenu;
  final VoidCallback onMenu;
  final VoidCallback onLogout;

  const _TopBar({
    required this.title,
    required this.admin,
    required this.showMenu,
    required this.onMenu,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              tooltip: 'Menu',
              onPressed: onMenu,
              icon: const Icon(Icons.menu),
            ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            admin?['email']?.toString() ?? 'Admin',
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final AdminApiService api;

  const DashboardPage({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return FuturePanel(
      future: api.dashboard(),
      builder: (data) {
        final stats = Map<String, dynamic>.from(data['stats'] ?? {});
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 3
                : constraints.maxWidth >= 720
                    ? 2
                    : 1;

            return GridView.count(
              crossAxisCount: columns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 2.8,
              children: [
                StatCard('Total Users', stats['totalUsers'], Icons.people_alt_outlined),
                StatCard('Completed Profiles', stats['completedProfilesCount'], Icons.verified_user_outlined),
                StatCard('Incomplete Profiles', stats['incompleteProfilesCount'], Icons.person_off_outlined),
                StatCard('Total Tournaments', stats['totalTournaments'], Icons.emoji_events_outlined),
                StatCard('Match Histories', stats['totalMatchHistories'], Icons.sports_cricket_outlined),
                StatCard('Notification Logs', stats['totalNotificationLogs'], Icons.notifications_none),
              ],
            );
          },
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final dynamic value;
  final IconData icon;

  const StatCard(this.label, this.value, this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  Text(
                    '${value ?? 0}',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UsersPage extends StatefulWidget {
  final AdminApiService api;

  const UsersPage({super.key, required this.api});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  int refresh = 0;

  @override
  Widget build(BuildContext context) {
    return FuturePanel(
      key: ValueKey(refresh),
      future: widget.api.users(),
      builder: (data) {
        final users = List<dynamic>.from(data['users'] ?? []);
        return AdminTable(
          emptyText: 'No users found',
          columns: const ['Name', 'Email', 'City', 'Profile', 'Role', 'Active', 'Actions'],
          rows: users.map((item) {
            final user = Map<String, dynamic>.from(item);
            final profile = Map<String, dynamic>.from(user['profile'] ?? {});
            return [
              profile['name'] ?? user['nameFromGoogle'] ?? '-',
              user['email'] ?? '-',
              profile['city'] ?? '-',
              user['profileCompleted'] == true ? 'Completed' : 'Incomplete',
              user['role'] ?? 'user',
              user['isActive'] == false ? 'Disabled' : 'Enabled',
              AdminActions(
                actions: [
                  AdminAction(
                    icon: Icons.visibility_outlined,
                    label: 'View',
                    onPressed: () => _showUserDetails(user),
                  ),
                  AdminAction(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Manage',
                    onPressed: () => _editUser(user),
                  ),
                ],
              ),
            ];
          }).toList(),
        );
      },
    );
  }

  Future<void> _showUserDetails(Map<String, dynamic> listUser) async {
    await _runDialogFuture(
      context,
      widget.api.userDetails(listUser['_id'].toString()),
      (data) {
        final user = Map<String, dynamic>.from(data['user'] ?? {});
        final profile = Map<String, dynamic>.from(user['profile'] ?? {});
        return DetailsDialog(
          title: 'User Details',
          fields: {
            'Name': profile['name'] ?? user['nameFromGoogle'] ?? '-',
            'Email': user['email'] ?? '-',
            'Phone': profile['phoneNumber'] ?? '-',
            'City': profile['city'] ?? '-',
            'Country': profile['country'] ?? '-',
            'Role': user['role'] ?? 'user',
            'Status': user['isActive'] == false ? 'Disabled' : 'Enabled',
            'Profile': user['profileCompleted'] == true ? 'Completed' : 'Incomplete',
          },
        );
      },
    );
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    String role = (user['role'] ?? 'user').toString();
    bool isActive = user['isActive'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Manage User'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('user')),
                      DropdownMenuItem(value: 'admin', child: Text('admin')),
                    ],
                    onChanged: (value) => setDialogState(() => role = value ?? role),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Account enabled'),
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  try {
                    await widget.api.updateUser(user['_id'].toString(), role: role, isActive: isActive);
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) _snack(context, e.toString(), error: true);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && mounted) {
      _snack(context, 'User updated');
      setState(() => refresh++);
    }
  }
}

class TournamentsPage extends StatefulWidget {
  final AdminApiService api;

  const TournamentsPage({super.key, required this.api});

  @override
  State<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends State<TournamentsPage> {
  int refresh = 0;

  @override
  Widget build(BuildContext context) {
    return FuturePanel(
      key: ValueKey(refresh),
      future: widget.api.tournaments(),
      builder: (data) {
        final tournaments = List<dynamic>.from(data['tournaments'] ?? []);
        return AdminTable(
          emptyText: 'No tournaments found',
          columns: const ['Organizer', 'City', 'Venue', 'Entry Fee', 'Prize', 'Status', 'Actions'],
          rows: tournaments.map((item) {
            final tournament = Map<String, dynamic>.from(item);
            return [
              tournament['organizerName'] ?? '-',
              tournament['city'] ?? '-',
              tournament['venue'] ?? '-',
              tournament['entryFee'] ?? '-',
              tournament['winningPrize'] ?? '-',
              tournament['status'] ?? '-',
              AdminActions(
                actions: [
                  AdminAction(
                    icon: Icons.visibility_outlined,
                    label: 'View',
                    onPressed: () => _showTournamentDetails(tournament),
                  ),
                  AdminAction(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onPressed: () => _editTournament(tournament),
                  ),
                  AdminAction(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    onPressed: () => _deleteTournament(tournament),
                  ),
                ],
              ),
            ];
          }).toList(),
        );
      },
    );
  }

  Future<void> _showTournamentDetails(Map<String, dynamic> listItem) async {
    await _runDialogFuture(
      context,
      widget.api.tournamentDetails(listItem['_id'].toString()),
      (data) {
        final t = Map<String, dynamic>.from(data['tournament'] ?? {});
        return DetailsDialog(
          title: 'Tournament Details',
          fields: {
            'Organizer': t['organizerName'] ?? '-',
            'Contact': t['contactNo'] ?? '-',
            'City': t['city'] ?? '-',
            'Venue': t['venue'] ?? '-',
            'Entry Fee': t['entryFee'] ?? '-',
            'Winning Prize': t['winningPrize'] ?? '-',
            'Status': t['status'] ?? '-',
            'Created By': t['createdByName'] ?? t['createdByUid'] ?? '-',
          },
        );
      },
    );
  }

  Future<void> _editTournament(Map<String, dynamic> t) async {
    final organizer = TextEditingController(text: '${t['organizerName'] ?? ''}');
    final contact = TextEditingController(text: '${t['contactNo'] ?? ''}');
    final city = TextEditingController(text: '${t['city'] ?? ''}');
    final venue = TextEditingController(text: '${t['venue'] ?? ''}');
    final fee = TextEditingController(text: '${t['entryFee'] ?? ''}');
    final prize = TextEditingController(text: '${t['winningPrize'] ?? ''}');
    String status = (t['status'] ?? 'active').toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Tournament'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField('Organizer', organizer),
                    _dialogField('Contact', contact),
                    _dialogField('City', city),
                    _dialogField('Venue', venue),
                    _dialogField('Entry Fee', fee),
                    _dialogField('Winning Prize', prize),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('active')),
                        DropdownMenuItem(value: 'closed', child: Text('closed')),
                        DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
                      ],
                      onChanged: (value) => setDialogState(() => status = value ?? status),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  try {
                    await widget.api.updateTournament(t['_id'].toString(), {
                      'organizerName': organizer.text.trim(),
                      'contactNo': contact.text.trim(),
                      'city': city.text.trim(),
                      'venue': venue.text.trim(),
                      'entryFee': double.tryParse(fee.text.trim()) ?? fee.text.trim(),
                      'winningPrize': double.tryParse(prize.text.trim()) ?? prize.text.trim(),
                      'status': status,
                    });
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) _snack(context, e.toString(), error: true);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    organizer.dispose();
    contact.dispose();
    city.dispose();
    venue.dispose();
    fee.dispose();
    prize.dispose();

    if (saved == true && mounted) {
      _snack(context, 'Tournament updated');
      setState(() => refresh++);
    }
  }

  Future<void> _deleteTournament(Map<String, dynamic> t) async {
    final confirmed = await confirmDialog(
      context,
      'Delete Tournament',
      'Delete tournament by ${t['organizerName'] ?? 'this organizer'}? This cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await widget.api.deleteTournament(t['_id'].toString());
      if (!mounted) return;
      _snack(context, 'Tournament deleted');
      setState(() => refresh++);
    } catch (e) {
      if (mounted) _snack(context, e.toString(), error: true);
    }
  }
}

class MatchesPage extends StatefulWidget {
  final AdminApiService api;

  const MatchesPage({super.key, required this.api});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  int refresh = 0;
  late Future<Map<String, dynamic>> matchesFuture;
  final Set<String> selectedMatchIds = {};

  @override
  void initState() {
    super.initState();
    matchesFuture = widget.api.matches();
  }

  void _reloadMatches() {
    setState(() {
      refresh++;
      selectedMatchIds.clear();
      matchesFuture = widget.api.matches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FuturePanel(
      key: ValueKey(refresh),
      future: matchesFuture,
      builder: (data) {
        final matches = List<dynamic>.from(data['matches'] ?? []);
        final selectedMatches = matches
            .map((item) => Map<String, dynamic>.from(item))
            .where((match) => selectedMatchIds.contains(match['_id']?.toString()))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MatchCompareToolbar(
              selectedCount: selectedMatches.length,
              onCompare: selectedMatches.length < 2
                  ? null
                  : () => _openComparison(selectedMatches),
              onClear: selectedMatchIds.isEmpty
                  ? null
                  : () => setState(selectedMatchIds.clear),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AdminTable(
                emptyText: 'No matches found',
                columns: const ['Select', 'Teams', 'Winner', 'Venue', 'Score', 'User Email', 'Actions'],
                rows: matches.map((item) {
                  final match = Map<String, dynamic>.from(item);
                  final id = match['_id']?.toString() ?? '';
                  return [
                    Checkbox(
                      value: selectedMatchIds.contains(id),
                      onChanged: id.isEmpty
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  selectedMatchIds.add(id);
                                } else {
                                  selectedMatchIds.remove(id);
                                }
                              });
                            },
                    ),
                    '${match['teamA'] ?? '-'} vs ${match['teamB'] ?? '-'}',
                    match['winner'] ?? '-',
                    match['venue'] ?? '-',
                    '${match['firstInningScore'] ?? 0} - ${match['secondInningScore'] ?? 0}',
                    match['userEmail'] ?? '-',
                    AdminActions(
                      actions: [
                        AdminAction(
                          icon: Icons.visibility_outlined,
                          label: 'View',
                          onPressed: () => _showMatchDetails(match),
                        ),
                        AdminAction(
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          onPressed: () => _deleteMatch(match),
                        ),
                      ],
                    ),
                  ];
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openComparison(List<Map<String, dynamic>> selectedMatches) async {
    await showDialog<void>(
      context: context,
      builder: (_) => MatchComparisonDialog(matches: selectedMatches),
    );
  }

  Future<void> _showMatchDetails(Map<String, dynamic> item) async {
    await _runDialogFuture(
      context,
      widget.api.matchDetails(item['_id'].toString()),
      (data) {
        final m = Map<String, dynamic>.from(data['match'] ?? {});
        return DetailsDialog(
          title: 'Match Details',
          fields: {
            'Teams': '${m['teamA'] ?? '-'} vs ${m['teamB'] ?? '-'}',
            'Winner': m['winner'] ?? '-',
            'Venue': m['venue'] ?? '-',
            'Overs': m['oversLimit'] ?? '-',
            'Toss': '${m['tossWinner'] ?? '-'} chose ${m['tossDecision'] ?? '-'}',
            'Scores': '${m['firstInningScore'] ?? 0} - ${m['secondInningScore'] ?? 0}',
            'Target': m['target'] ?? '-',
            'User Email': m['userEmail'] ?? '-',
            'Innings Count': (m['innings'] as List?)?.length ?? 0,
          },
        );
      },
    );
  }

  Future<void> _deleteMatch(Map<String, dynamic> match) async {
    final confirmed = await confirmDialog(
      context,
      'Delete Match History',
      'Delete ${match['teamA'] ?? 'Team A'} vs ${match['teamB'] ?? 'Team B'}? This should only be used for invalid records.',
    );
    if (!confirmed) return;

    try {
      await widget.api.deleteMatch(match['_id'].toString());
      if (!mounted) return;
      _snack(context, 'Match history deleted');
      _reloadMatches();
    } catch (e) {
      if (mounted) _snack(context, e.toString(), error: true);
    }
  }
}

class _MatchCompareToolbar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onCompare;
  final VoidCallback? onClear;

  const _MatchCompareToolbar({
    required this.selectedCount,
    required this.onCompare,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onCompare,
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Compare Selected Matches'),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Selection'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                '$selectedCount selected',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MatchComparisonDialog extends StatelessWidget {
  final List<Map<String, dynamic>> matches;

  const MatchComparisonDialog({
    super.key,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final wide = screen.width >= 900;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screen.width * 0.92,
          maxHeight: screen.height * 0.86,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Match Comparison (${matches.length})',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: wide
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: matches
                              .map(
                                (match) => Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: SizedBox(
                                    width: 340,
                                    child: MatchComparisonCard(match: match),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                    : ListView.separated(
                        itemCount: matches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return MatchComparisonCard(match: matches[index]);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MatchComparisonCard extends StatelessWidget {
  final Map<String, dynamic> match;

  const MatchComparisonCard({
    super.key,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    final innings = (match['innings'] as List?) ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _teams(match),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _ComparisonField(label: 'Winner', value: _text(match['winner'])),
              _ComparisonField(label: 'Venue', value: _text(match['venue'])),
              _ComparisonField(label: 'Score', value: _score(match)),
              _ComparisonField(label: 'Overs', value: _text(match['oversLimit'])),
              _ComparisonField(label: 'User Email', value: _text(match['userEmail'])),
              _ComparisonField(label: 'Date', value: _formatDate(match['createdAt'])),
              _ComparisonField(label: 'Toss Winner', value: _text(match['tossWinner'])),
              _ComparisonField(label: 'Toss Decision', value: _text(match['tossDecision'])),
              const SizedBox(height: 10),
              const Text(
                'Innings Summary',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (innings.isEmpty)
                const Text('-', style: TextStyle(color: Color(0xFF6B7280)))
              else
                ...innings.map((inning) {
                  final item = inning is Map ? Map<String, dynamic>.from(inning) : <String, dynamic>{};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _inningSummary(item),
                      style: const TextStyle(color: Color(0xFF374151)),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  static String _teams(Map<String, dynamic> match) {
    return '${_text(match['teamA'])} vs ${_text(match['teamB'])}';
  }

  static String _score(Map<String, dynamic> match) {
    return '${match['firstInningScore'] ?? 0} - ${match['secondInningScore'] ?? 0}';
  }

  static String _formatDate(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return '-';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return raw.toString();
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  static String _inningSummary(Map<String, dynamic> inning) {
    final number = inning['inning'] ?? '-';
    final battingTeam = _text(inning['battingTeam']);
    final score = inning['scoreText'] ?? '${inning['runs'] ?? '-'}';
    final overs = inning['oversText'] ?? inning['overs'] ?? '-';
    return 'Inning $number: $battingTeam scored $score in $overs overs';
  }

  static String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }
}

class _ComparisonField extends StatelessWidget {
  final String label;
  final String value;

  const _ComparisonField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatefulWidget {
  final AdminApiService? api;

  const PlaceholderPage({super.key, this.api});

  @override
  State<PlaceholderPage> createState() => _PlaceholderPageState();
}

class _PlaceholderPageState extends State<PlaceholderPage> {
  int refresh = 0;

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    if (api == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _sendNotification(api),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send Notification'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: FuturePanel(
            key: ValueKey(refresh),
            future: api.notificationLogs(),
            builder: (data) {
              final logs = List<dynamic>.from(data['logs'] ?? []);
              return AdminTable(
                emptyText: 'No notification logs found',
                columns: const ['Event', 'Item', 'League', 'Sport', 'Sent At'],
                rows: logs.map((item) {
                  final log = Map<String, dynamic>.from(item);
                  return [
                    log['eventType'] ?? '-',
                    log['itemId'] ?? '-',
                    log['league'] ?? '-',
                    log['sport'] ?? '-',
                    log['sentAt'] ?? log['createdAt'] ?? '-',
                  ];
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _sendNotification(AdminApiService api) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final city = TextEditingController();

    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Notification'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('Title', title),
              _dialogField('Body', body, maxLines: 3),
              _dialogField('City filter (optional)', city),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await api.sendNotification(
                  title: title.text.trim(),
                  body: body.text.trim(),
                  city: city.text.trim(),
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) _snack(context, e.toString(), error: true);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    title.dispose();
    body.dispose();
    city.dispose();

    if (sent == true && mounted) {
      _snack(context, 'Notification send requested');
      setState(() => refresh++);
    }
  }
}

class FuturePanel extends StatelessWidget {
  final Future<Map<String, dynamic>> future;
  final Widget Function(Map<String, dynamic> data) builder;

  const FuturePanel({
    super.key,
    required this.future,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Card(
            child: Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          );
        }
        return builder(snapshot.data ?? {});
      },
    );
  }
}

class AdminTable extends StatelessWidget {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final String emptyText;

  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Card(child: Center(child: Text(emptyText)));
    }

    return Card(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
            dataRowMinHeight: 64,
            dataRowMaxHeight: 128,
            horizontalMargin: 18,
            columnSpacing: 28,
            columns: columns.map((column) {
              final isActions = column.toLowerCase() == 'actions';
              return DataColumn(
                label: SizedBox(
                  width: isActions ? 330 : null,
                  child: Text(column),
                ),
              );
            }).toList(),
            rows: rows.map((row) {
              return DataRow(
                cells: row.map((cell) {
                  return DataCell(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: cell is AdminActions
                          ? cell
                          : cell is Widget
                              ? cell
                              : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              '$cell',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class AdminAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const AdminAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

class AdminActions extends StatelessWidget {
  final List<AdminAction> actions;

  const AdminActions({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetWidth = screenWidth >= 900 ? 330.0 : 240.0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: targetWidth,
        maxWidth: targetWidth,
        minHeight: 44,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions
              .map(
                (action) => AdminActionButton(
                  icon: action.icon,
                  label: action.label,
                  onPressed: action.onPressed,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class AdminActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const AdminActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class DetailsDialog extends StatelessWidget {
  final String title;
  final Map<String, dynamic> fields;

  const DetailsDialog({
    super.key,
    required this.title,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(child: Text('${entry.value}')),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

Widget _dialogField(String label, TextEditingController controller, {int maxLines = 1}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  return result == true;
}

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFB91C1C) : null,
    ),
  );
}

Future<void> _runDialogFuture(
  BuildContext context,
  Future<Map<String, dynamic>> future,
  Widget Function(Map<String, dynamic> data) builder,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final data = await future;
    if (!context.mounted) return;
    Navigator.pop(context);
    await showDialog<void>(context: context, builder: (_) => builder(data));
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    _snack(context, e.toString(), error: true);
  }
}
