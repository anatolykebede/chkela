import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/app_remote_config.dart';
import '../../data/feedback_api.dart';
import '../auth/auth_provider.dart';

Future<bool> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<bool> openSupportEmail({
  String? email,
  String subject = 'Chkela support',
  String body = '',
}) async {
  final to = email ?? AppRemoteConfig.defaults.supportEmail;
  final query = StringBuffer('subject=${Uri.encodeComponent(subject)}');
  if (body.isNotEmpty) {
    query.write('&body=${Uri.encodeComponent(body)}');
  }
  final uri = Uri(
    scheme: 'mailto',
    path: to,
    query: query.toString(),
  );
  return openExternalUrl(uri.toString());
}

Future<bool> openSupportPhone({String? tel}) {
  final number = tel ?? AppRemoteConfig.defaults.supportPhoneTel;
  return openExternalUrl('tel:$number');
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(
            body.trim(),
            style: HomeTextStyles.bodySmall.copyWith(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a bit more feedback')),
      );
      return;
    }
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    final phone = ref.read(authProvider).phoneE164;
    final ok = await FeedbackApi().submit(message: text, phone: phone);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — feedback sent to Chkela admin')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not send feedback. Check your connection and try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Feedback',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'Tell us what to improve',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bugs, ideas, or anything that would make studying easier. '
            'Your note goes to the Chkela admin dashboard.',
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            maxLines: 8,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Write your feedback…',
              hintStyle: TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.bgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sending ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_sending ? 'Sending to admin…' : 'Send to admin'),
            ),
          ),
        ],
      ),
    );
  }
}

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appRemoteConfigProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appRemoteConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Support',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'We’re here to help',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reach the Chkela team by Telegram, email, or phone.',
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 20),
          _SupportAction(
            icon: Icons.telegram,
            title: 'Telegram',
            subtitle: config.telegramHandle,
            onTap: () async {
              final ok = await openExternalUrl(config.telegramDeepLink) ||
                  await openExternalUrl(config.telegramUrl);
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open Telegram')),
                );
              }
            },
          ),
          _SupportAction(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: config.supportEmail,
            onTap: () => openSupportEmail(email: config.supportEmail),
          ),
          _SupportAction(
            icon: Icons.phone_outlined,
            title: 'Call',
            subtitle: config.supportPhoneDisplay,
            onTap: () => openSupportPhone(tel: config.supportPhoneTel),
          ),
        ],
      ),
    );
  }
}

class SocialMediaScreen extends ConsumerStatefulWidget {
  const SocialMediaScreen({super.key});

  @override
  ConsumerState<SocialMediaScreen> createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends ConsumerState<SocialMediaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appRemoteConfigProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appRemoteConfigProvider);
    final links = [
      (Icons.camera_alt_outlined, 'Instagram', config.instagramUrl),
      (Icons.music_note_outlined, 'TikTok', config.tiktokUrl),
      (Icons.play_circle_outline, 'YouTube', config.youtubeUrl),
      (Icons.facebook, 'Facebook', config.facebookUrl),
      (Icons.alternate_email, 'X', config.xUrl),
      (Icons.telegram, 'Telegram', config.telegramUrl),
      (Icons.language, 'Website', config.website),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Social media',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'Follow Chkela',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tips, updates, and community highlights.',
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 20),
          for (final link in links)
            _SupportAction(
              icon: link.$1,
              title: link.$2,
              subtitle: link.$3.replaceFirst(RegExp(r'^https?://'), ''),
              onTap: () => openExternalUrl(link.$3),
            ),
        ],
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.accentText, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
