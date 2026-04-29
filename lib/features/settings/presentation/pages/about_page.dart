/// About page showing app info, open source licenses, and source code link.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/design_tokens.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  Future<void> _openGitHub() async {
    final uri = Uri.parse('https://github.com/RebornQ/fl_api_hub');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Fl API HUB',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Image.asset(
          'icons/icon-hub-1024-play-512.png',
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        ),
      ),
      applicationVersion: _packageInfo?.version ?? '1.0.0',
      applicationLegalese:
          "一站式 New-API/Sub2API 等中转站账号管理：快速签到、余额看板、密钥一键使用\n基于 Flutter & MD3",
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('关于'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.lg),
          _buildAppIcon(),
          const SizedBox(height: AppSpacing.md),
          _buildAppName(textTheme, colorScheme),
          const SizedBox(height: AppSpacing.xs),
          _buildVersion(textTheme, colorScheme),
          const SizedBox(height: AppSpacing.xl),
          _buildInfoSection(colorScheme),
        ],
      ),
    );
  }

  Widget _buildAppIcon() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Image.asset(
          'icons/icon-hub-1024-play-512.png',
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAppName(TextTheme textTheme, ColorScheme colorScheme) {
    return Text(
      'Fl API HUB',
      style: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildVersion(TextTheme textTheme, ColorScheme colorScheme) {
    final version = _packageInfo != null
        ? 'v${_packageInfo!.version}'
        : 'v1.0.0';
    return Text(
      version,
      style: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildInfoSection(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('开源许可'),
            subtitle: const Text('查看第三方库许可证'),
            trailing: const Icon(Icons.chevron_right),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            onTap: _showLicenses,
          ),
          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: const Text('GitHub 源码'),
            subtitle: const Text('github.com/RebornQ/fl_api_hub'),
            trailing: const Icon(Icons.open_in_new),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
              ),
            ),
            onTap: _openGitHub,
          ),
        ],
      ),
    );
  }
}
