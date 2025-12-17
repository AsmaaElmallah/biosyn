import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';

class User {
  final String id;
  final String name;
  final String username;
  final String role;
  final String status;

  User({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.status,
  });
}

class UserManagementScreen extends StatefulWidget {
  final String activeTab;
  final Function(String) onTabChange;

  const UserManagementScreen({
    super.key,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _activeTab = 'dm';
  final List<User> _dms = [];
  final List<User> _mrs = [];
  final _searchController = TextEditingController();
  bool _showModal = false;
  User? _editingUser;
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  List<User> get _currentUsers => _activeTab == 'dm' ? _dms : _mrs;

  List<User> get _filteredUsers {
    final query = _searchController.text.toLowerCase();
    return _currentUsers.where((user) {
      return user.name.toLowerCase().contains(query) ||
          user.id.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dmsData = await SupabaseService.getAllDMs();
      final mrsData = await SupabaseService.getAllMRs();

      setState(() {
        _dms
          ..clear()
          ..addAll(dmsData.map((u) => User(
                id: (u['id'] ?? '').toString(),
                name: (u['name'] ?? '').toString(),
                username: (u['username'] ?? '').toString(),
                role: (u['role'] ?? '').toString(),
                status: (u['status'] ?? '').toString(),
              )));

        _mrs
          ..clear()
          ..addAll(mrsData.map((u) => User(
                id: (u['id'] ?? '').toString(),
                name: (u['name'] ?? '').toString(),
                username: (u['username'] ?? '').toString(),
                role: (u['role'] ?? '').toString(),
                status: (u['status'] ?? '').toString(),
              )));
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load users. Please check Supabase connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleAdd() {
    setState(() {
      _editingUser = null;
      _idController.clear();
      _nameController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _showModal = true;
    });
  }

  void _handleEdit(User user) {
    setState(() {
      _editingUser = user;
      _idController.text = user.id;
      _nameController.text = user.name;
      _usernameController.text = user.username;
      _passwordController.clear();
      _showModal = true;
    });
  }

  void _handleDelete(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await SupabaseService.deleteUser(userId);
                await _loadUsers();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete user.')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      if (_editingUser != null) {
        // Update existing user in Supabase
        await SupabaseService.updateUser(
          id: _editingUser!.id,
          name: _nameController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
          role: _activeTab,
        );
      } else {
        // Create new user in Supabase
        final response = await SupabaseService.signUp(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          role: _activeTab,
        );

        // Use Supabase-generated ID
        _idController.text = (response['id'] ?? '').toString();
      }

      await _loadUsers();

      setState(() {
        _showModal = false;
        _editingUser = null;
        _idController.clear();
        _nameController.clear();
        _usernameController.clear();
        _passwordController.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save user: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _idController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.gray50,
          body: SafeArea(
            child: Column(
              children: [
              // Header
              const AppHeader(
                title: 'User Management',
                subtitle: 'Manage District Managers and Medical Reps',
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Role Tabs
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _activeTab = 'dm';
                                    _searchController.clear();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: _activeTab == 'dm'
                                        ? AppColors.primaryGradientHorizontal
                                        : null,
                                    color: _activeTab == 'dm' ? null : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'District Managers (${_dms.length})',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _activeTab == 'dm' ? Colors.white : AppColors.gray600,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _activeTab = 'mr';
                                    _searchController.clear();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: _activeTab == 'mr'
                                        ? AppColors.primaryGradientHorizontal
                                        : null,
                                    color: _activeTab == 'mr' ? null : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Medical Reps (${_mrs.length})',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _activeTab == 'mr' ? Colors.white : AppColors.gray600,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null)
                        _buildCard(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (_errorMessage != null) const SizedBox(height: 16),
                      // Search Bar
                      _buildCard(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search by name or ID...',
                            prefixIcon: const Icon(Icons.search, color: AppColors.gray400),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else ...[
                      // Add Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradientHorizontal,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _handleAdd,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add New',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // User List
                      _filteredUsers.isEmpty
                          ? _buildCard(
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.gray100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.people_outline, size: 40, color: AppColors.gray400),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No users found',
                                    style: TextStyle(
                                      color: AppColors.gray700,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _activeTab == 'dm' 
                                        ? 'Add your first District Manager'
                                        : 'Add your first Medical Rep',
                                    style: const TextStyle(
                                      color: AppColors.gray400,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: _filteredUsers.map((user) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // User Info Section
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            // Avatar
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                gradient: _activeTab == 'dm' 
                                                    ? AppColors.primaryGradient
                                                    : const LinearGradient(
                                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                                      ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  user.name.isNotEmpty 
                                                      ? user.name.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join()
                                                      : 'U',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // User Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user.name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.gray900,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.person_outline,
                                                        size: 14,
                                                        color: AppColors.gray400,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          '@${user.username}',
                                                          style: const TextStyle(
                                                            color: AppColors.gray600,
                                                            fontSize: 13,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Status Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: user.status == 'active'
                                                    ? AppColors.success.withOpacity(0.1)
                                                    : AppColors.gray200,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: user.status == 'active'
                                                          ? AppColors.success
                                                          : AppColors.gray400,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    user.status == 'active' ? 'Active' : 'Inactive',
                                                    style: TextStyle(
                                                      color: user.status == 'active'
                                                          ? AppColors.success
                                                          : AppColors.gray600,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Action Buttons
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.gray50,
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => _handleEdit(user),
                                                  borderRadius: const BorderRadius.only(
                                                    bottomLeft: Radius.circular(16),
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    child: const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.edit_outlined, color: AppColors.primaryBlue, size: 18),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Edit',
                                                          style: TextStyle(
                                                            color: AppColors.primaryBlue,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 24,
                                              color: AppColors.gray200,
                                            ),
                                            Expanded(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => _handleDelete(user.id),
                                                  borderRadius: const BorderRadius.only(
                                                    bottomRight: Radius.circular(16),
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    child: const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: AppColors.error,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                      // Bottom padding for navigation
                      const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
              // Bottom Navigation
              BottomNav(
                role: 'gm',
                activeTab: widget.activeTab,
                onTabChange: widget.onTabChange,
              ),
              ],
            ),
          ),
        ),
        // Add/Edit Modal
        if (_showModal) _buildModal(context),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildModal(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Modal Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.gray200),
                    ),
                  ),
                  child: Text(
                    _editingUser != null ? 'Edit User' : 'Add New User',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Modal Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _idController,
                          enabled: _editingUser == null,
                          decoration: InputDecoration(
                            labelText: 'Employee ID *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter employee ID';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter username';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: _editingUser != null
                                ? 'Password (leave blank to keep current)'
                                : 'Password *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (_editingUser == null && (value == null || value.isEmpty)) {
                              return 'Please enter password';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Modal Footer
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.gray200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _showModal = false;
                                _editingUser = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.gray100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: AppColors.gray700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradientHorizontal,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _handleSave,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  _editingUser != null ? 'Update' : 'Create',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}
