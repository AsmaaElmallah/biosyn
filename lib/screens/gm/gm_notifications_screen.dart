import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/theme/text_styles.dart';
import 'package:biosyn_report_flutter/theme/spacing.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/widgets/app_card.dart';
import 'package:biosyn_report_flutter/widgets/loading_states.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:biosyn_report_flutter/utils/responsive.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class GMNotificationsScreen extends StatefulWidget {
  final String gmId;
  final String activeTab;
  final Function(String) onTabChange;

  const GMNotificationsScreen({
    super.key,
    required this.gmId,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  State<GMNotificationsScreen> createState() => _GMNotificationsScreenState();
}

class _GMNotificationsScreenState extends State<GMNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('📱 GMNotificationsScreen: Loading notifications for GM ID: ${widget.gmId}');
      final notifications = await SupabaseService.getNotifications(widget.gmId);
      debugPrint('📱 GMNotificationsScreen: Received ${notifications.length} notifications');
      
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
      
      if (notifications.isEmpty) {
        debugPrint('⚠️ GMNotificationsScreen: No notifications found');
      }
    } catch (e) {
      debugPrint('❌ GMNotificationsScreen: Error loading notifications: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await SupabaseService.markNotificationAsRead(notificationId);
      // Reload notifications
      await _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await SupabaseService.markAllNotificationsAsRead(widget.gmId);
      // Reload notifications
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }

  String _getRoleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case 'dm':
        return 'District Manager';
      case 'ft':
        return 'Field Trainer';
      case 'pm':
        return 'Product Manager';
      case 'msl':
        return 'Medical Science Liaison';
      default:
        return 'Coach';
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'time_change':
        return AppColors.warning;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'time_change':
        return Icons.access_time;
      default:
        return Icons.notifications;
    }
  }

  /// Build message with clickable links
  Widget _buildMessageWithLinks(String message, {required bool isRead}) {
    // Regular expression to match URLs
    final urlRegex = RegExp(r'https?://[^\s]+');
    final matches = urlRegex.allMatches(message);
    
    if (matches.isEmpty) {
      // No URLs found, return regular text
      return Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.gray700,
          fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
        ),
        maxLines: 10,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    // Build TextSpans with clickable links
    final spans = <TextSpan>[];
    int currentPosition = 0;
    
    for (final match in matches) {
      // Add text before the URL
      if (match.start > currentPosition) {
        spans.add(TextSpan(
          text: message.substring(currentPosition, match.start),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.gray700,
            fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
          ),
        ));
      }
      
      // Add clickable URL
      final url = message.substring(match.start, match.end);
      spans.add(TextSpan(
        text: url,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            try {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot open this link')),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error opening link: $e')),
                );
              }
            }
          },
      ));
      
      currentPosition = match.end;
    }
    
    // Add remaining text after the last URL
    if (currentPosition < message.length) {
      spans.add(TextSpan(
        text: message.substring(currentPosition),
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.gray700,
          fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
      maxLines: 10,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] == false).length;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and mark all as read
            AppHeader(
              title: 'Notifications',
              subtitle: unreadCount > 0 
                  ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
                  : 'All caught up!',
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const AppLoadingIndicator(message: 'Loading notifications...')
                  : _error != null
                      ? AppErrorState(
                          message: 'Failed to load notifications',
                          onRetry: _loadNotifications,
                        )
                      : _notifications.isEmpty
                          ? AppEmptyState(
                              message: 'No notifications yet',
                              icon: Icons.notifications_none,
                            )
                          : RefreshIndicator(
                              onRefresh: _loadNotifications,
                              child: Column(
                                children: [
                                  // Mark all as read button
                                  if (unreadCount > 0)
                                    Padding(
                                      padding: Responsive.responsivePadding(context),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: _markAllAsRead,
                                          icon: const Icon(Icons.done_all, size: 18),
                                          label: const Text('Mark all as read'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Notifications list
                                  Expanded(
                                    child: ListView.builder(
                                      padding: Responsive.responsivePadding(context),
                                      itemCount: _notifications.length,
                                      itemBuilder: (context, index) {
                                        final notification = _notifications[index];
                                        final isRead = notification['read'] == true;
                                        final type = notification['notification_type'] as String?;
                                        final senderName = notification['sender_name'] as String? ?? 'Unknown';
                                        final senderRole = notification['sender_role'] as String?;
                                        final message = notification['message'] as String? ?? '';
                                        final createdAt = notification['created_at'] as String?;
                                        final notificationId = notification['id'] as String?;

                                        // Parse date
                                        String dateText = 'Just now';
                                        if (createdAt != null) {
                                          try {
                                            final date = DateTime.parse(createdAt);
                                            final now = DateTime.now();
                                            final difference = now.difference(date);

                                            if (difference.inMinutes < 1) {
                                              dateText = 'Just now';
                                            } else if (difference.inHours < 1) {
                                              dateText = '${difference.inMinutes}m ago';
                                            } else if (difference.inDays < 1) {
                                              dateText = '${difference.inHours}h ago';
                                            } else if (difference.inDays < 7) {
                                              dateText = '${difference.inDays}d ago';
                                            } else {
                                              dateText = DateFormat('MMM d, y').format(date);
                                            }
                                          } catch (e) {
                                            dateText = 'Unknown';
                                          }
                                        }

                                        return AppCard(
                                          padding: AppSpacing.cardPadding,
                                          backgroundColor: isRead 
                                              ? Colors.white 
                                              : AppColors.primaryBlue.withOpacity(0.05),
                                          onTap: () {
                                            if (!isRead && notificationId != null) {
                                              _markAsRead(notificationId);
                                            }
                                          },
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Icon
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: _getNotificationColor(type)
                                                      .withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  _getNotificationIcon(type),
                                                  color: _getNotificationColor(type),
                                                  size: 24,
                                                ),
                                              ),
                                              AppSpacing.horizontal(AppSpacing.lg),
                                              // Content
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Title
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            notification['title'] as String? ?? 'Time/Date Change Detected',
                                                            style: AppTextStyles.h4.copyWith(
                                                              fontWeight: isRead 
                                                                  ? FontWeight.w600 
                                                                  : FontWeight.bold,
                                                              color: isRead 
                                                                  ? AppColors.gray900 
                                                                  : AppColors.primaryBlue,
                                                            ),
                                                          ),
                                                        ),
                                                        if (!isRead)
                                                          Container(
                                                            width: 8,
                                                            height: 8,
                                                            decoration: const BoxDecoration(
                                                              color: AppColors.primaryBlue,
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    AppSpacing.vertical(AppSpacing.xs),
                                                    // Message - Show the full message with clickable links
                                                    _buildMessageWithLinks(
                                                      message.isNotEmpty 
                                                          ? message 
                                                          : '${senderName} (${_getRoleLabel(senderRole)}) changed the device time/date while submitting a coaching session',
                                                      isRead: isRead,
                                                    ),
                                                    AppSpacing.vertical(AppSpacing.sm),
                                                    // Footer
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.person_outline,
                                                          size: 14,
                                                          color: AppColors.gray400,
                                                        ),
                                                        AppSpacing.horizontal(AppSpacing.xs),
                                                        // اسم الكوتش + الرول - ياخد المساحة المرنة
                                                        Expanded(
                                                          child: Text(
                                                            '$senderName (${_getRoleLabel(senderRole)})',
                                                            style: AppTextStyles.caption.copyWith(
                                                              color: AppColors.gray600,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        AppSpacing.horizontal(AppSpacing.sm),
                                                        Icon(
                                                          Icons.access_time,
                                                          size: 14,
                                                          color: AppColors.gray400,
                                                        ),
                                                        AppSpacing.horizontal(AppSpacing.xs),
                                                        Text(
                                                          dateText,
                                                          style: AppTextStyles.caption.copyWith(
                                                            color: AppColors.gray600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

