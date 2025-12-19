import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  final String userName;
  final String? userId;
  final VoidCallback onLogout;
  final String activeTab;
  final Function(String) onTabChange;

  const ProfileScreen({
    super.key,
    required this.role,
    required this.userName,
    this.userId,
    required this.onLogout,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.userId != null) {
        // Fetch from Supabase
        final userData = await SupabaseService.getUserById(widget.userId!);
        if (userData != null) {
          setState(() {
            _userData = userData;
            _profileImageUrl = userData['profile_picture_url'] as String?;
            _isLoading = false;
          });
          debugPrint('✅ Loaded user data from Supabase');
        } else {
          // Fallback to local data
          setState(() {
            _userData = {
              'name': widget.userName,
              'email': '${widget.userName.toLowerCase().replaceAll(' ', '.')}@biosyn.com',
              'phone': '+20 XXX XXX XXXX',
              'role': widget.role,
            };
            _isLoading = false;
          });
          debugPrint('⚠️ User not found in Supabase, using local data');
        }
      } else {
        // No userId, use local data
        setState(() {
          _userData = {
            'name': widget.userName,
            'email': '${widget.userName.toLowerCase().replaceAll(' ', '.')}@biosyn.com',
            'phone': '+20 XXX XXX XXXX',
            'role': widget.role,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      setState(() {
        _errorMessage = 'Failed to load profile data';
        _isLoading = false;
        // Fallback to local data
        _userData = {
          'name': widget.userName,
          'email': '${widget.userName.toLowerCase().replaceAll(' ', '.')}@biosyn.com',
          'phone': '+20 XXX XXX XXXX',
          'role': widget.role,
        };
      });
    }
  }

  String get _roleTitle {
    final role = _userData?['role'] as String? ?? widget.role;
    switch (role.toLowerCase()) {
      case 'dm':
        return 'District Manager';
      case 'ft':
        return 'Field Trainer';
      case 'pm':
        return 'Product Manager';
      case 'msl':
        return 'Medical Science Liaison';
      case 'gm':
        return 'General Manager';
      default:
        return 'User';
    }
  }

  String get _userName {
    return _userData?['name'] as String? ?? widget.userName;
  }

  String get _userEmail {
    return _userData?['email'] as String? ?? 
           '${widget.userName.toLowerCase().replaceAll(' ', '.')}@biosyn.com';
  }

  String get _userPhone {
    return _userData?['phone'] as String? ?? '+20 XXX XXX XXXX';
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        // Upload immediately
        await _uploadProfilePicture();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_profileImage == null || widget.userId == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      debugPrint('📤 Uploading profile picture...');
      final imageUrl = await SupabaseService.uploadProfilePicture(
        _profileImage!,
        widget.userId!,
      );

      // Update profile picture URL in database
      await SupabaseService.updateUserProfilePicture(widget.userId!, imageUrl);

      setState(() {
        _profileImageUrl = imageUrl;
        _profileImage = null; // Clear local file after upload
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload user data to get updated info
      await _loadUserData();
    } catch (e) {
      debugPrint('❌ Error uploading profile picture: $e');
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog() async {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);
    final phoneController = TextEditingController(text: _userPhone);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (widget.userId == null) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot update profile: User ID not available'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await SupabaseService.updateUser(
                  id: widget.userId!,
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                  phone: phoneController.text.trim(),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );

                // Reload user data
                await _loadUserData();
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update profile: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const AppHeader(
              title: 'Profile',
              subtitle: 'Account settings and information',
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && _userData == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadUserData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Profile Card
                          Container(
                            padding: const EdgeInsets.all(24),
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
                                // Profile Picture with Edit Button
                                Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: widget.userId != null ? _pickImage : null,
                                      child: Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          gradient: _profileImage != null || _profileImageUrl != null
                                              ? null
                                              : AppColors.primaryGradient,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primaryBlue,
                                              blurRadius: 20,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: _isUploadingImage
                                            ? const Center(
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                ),
                                              )
                                            : _profileImage != null
                                                ? ClipOval(
                                                    child: Image.file(
                                                      _profileImage!,
                                                      width: 96,
                                                      height: 96,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                                    ? ClipOval(
                                                        child: Image.network(
                                                          _profileImageUrl!,
                                                          width: 96,
                                                          height: 96,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return Container(
                                                              decoration: const BoxDecoration(
                                                                gradient: AppColors.primaryGradient,
                                                                shape: BoxShape.circle,
                                                              ),
                                                              child: const Icon(
                                                                Icons.person,
                                                                color: Colors.white,
                                                                size: 48,
                                                              ),
                                                            );
                                                          },
                                                          loadingBuilder: (context, child, loadingProgress) {
                                                            if (loadingProgress == null) return child;
                                                            return const Center(
                                                              child: CircularProgressIndicator(
                                                                color: Colors.white,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.person,
                                                        color: Colors.white,
                                                        size: 48,
                                                      ),
                                      ),
                                    ),
                                    if (widget.userId != null)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryBlue,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _userName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gray900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _roleTitle,
                                    style: const TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildInfoItem(Icons.business, 'Role', _roleTitle),
                                const SizedBox(height: 12),
                                _buildInfoItem(Icons.email, 'Email', _userEmail),
                                const SizedBox(height: 12),
                                _buildInfoItem(Icons.phone, 'Phone', _userPhone),
                                const SizedBox(height: 12),
                                _buildInfoItem(Icons.verified, 'Account Status', 'Active'),
                                const SizedBox(height: 16),
                                // Edit Profile Button
                                if (widget.userId != null)
                                  ElevatedButton.icon(
                                    onPressed: _showEditDialog,
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Edit Profile'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Settings Options
                          Container(
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
                                _buildSettingItem('Change Password', Icons.lock_outline),
                                const Divider(height: 1),
                                _buildSettingItem('Notification Settings', Icons.notifications_outlined),
                                const Divider(height: 1),
                                _buildSettingItem('Help & Support', Icons.help_outline),
                                const Divider(height: 1),
                                _buildSettingItem('About Biosyn', Icons.info_outline),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // App Info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryCyan.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Biosyn Coaching App',
                                  style: TextStyle(
                                    color: AppColors.gray700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Version 1.0.0',
                                  style: TextStyle(
                                    color: AppColors.gray600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Logout Button
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Logout'),
                                      content: const Text('Are you sure you want to logout?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            widget.onLogout();
                                          },
                                          child: const Text('Logout'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Logout',
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
                        ],
                      ),
                    ),
            ),
            // Bottom Navigation
            BottomNav(
              role: widget.role,
              activeTab: widget.activeTab,
              onTabChange: widget.onTabChange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.gray600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.gray900,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, IconData icon) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.gray700,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: AppColors.gray300, size: 16),
          ],
        ),
      ),
    );
  }
}
