import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/section_title.dart';

/// Full settings screen for configuring the FTP server: network (port),
/// authentication (username/password/anonymous), permissions (read-only,
/// hidden files), lifecycle (auto-start), and app appearance (theme).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _rootDirectoryController;
  bool _initializedFromConfig = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootDirectoryController.dispose();
    super.dispose();
  }

  void _initControllersOnce(SettingsController controller) {
    if (_initializedFromConfig) return;
    _portController = TextEditingController(text: controller.config.port.toString());
    _usernameController = TextEditingController(text: controller.config.username);
    _passwordController = TextEditingController(text: controller.config.password);
    _rootDirectoryController = TextEditingController(text: controller.config.rootDirectory);
    _initializedFromConfig = true;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final serverProvider = context.watch<ServerProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final controller = SettingsController(settingsProvider, serverProvider);
    _initControllersOnce(controller);

    if (!settingsProvider.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = settingsProvider.config;
    final serverIsRunning = serverProvider.isRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (serverIsRunning)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Stop the server to change network or credential settings.',
                  ),
                ),
              ),
            const SectionTitle(title: 'NETWORK', icon: Icons.wifi),
            TextFormField(
              controller: _portController,
              enabled: !serverIsRunning,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
              validator: controller.validatePort,
              onFieldSubmitted: (value) {
                if (controller.validatePort(value) == null) {
                  controller.savePort(value);
                }
              },
            ),

            const SectionTitle(title: 'AUTHENTICATION', icon: Icons.lock_outline),
            SwitchListTile(
              title: const Text('Allow anonymous login'),
              subtitle: const Text('Clients can connect without a username/password'),
              value: config.anonymousAllowed,
              onChanged: serverIsRunning ? null : controller.toggleAnonymous,
            ),
            TextFormField(
              controller: _usernameController,
              enabled: !serverIsRunning && !config.anonymousAllowed,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: controller.validateUsername,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              enabled: !serverIsRunning && !config.anonymousAllowed,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: controller.validatePassword,
              onFieldSubmitted: (_) => _saveCredentials(controller),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: serverIsRunning ? null : () => _saveCredentials(controller),
                child: const Text('Save credentials'),
              ),
            ),

            const SectionTitle(title: 'PERMISSIONS', icon: Icons.rule_folder_outlined),
            SwitchListTile(
              title: const Text('Read-only mode'),
              subtitle: const Text('Disable uploads, deletes, renames, and folder creation'),
              value: config.readOnly,
              onChanged: controller.toggleReadOnly,
            ),
            SwitchListTile(
              title: const Text('Show hidden files'),
              subtitle: const Text('Include files/folders starting with "."'),
              value: config.showHiddenFiles,
              onChanged: controller.toggleShowHidden,
            ),

            const SectionTitle(title: 'STARTUP', icon: Icons.power_settings_new),
            SwitchListTile(
              title: const Text('Auto-start on app launch'),
              value: config.autoStart,
              onChanged: controller.toggleAutoStart,
            ),

            const SectionTitle(title: 'STORAGE', icon: Icons.folder_outlined),
            TextFormField(
              controller: _rootDirectoryController,
              enabled: !serverIsRunning,
              decoration: const InputDecoration(
                labelText: 'Root directory',
                helperText: 'The folder clients will see as "/". Must already exist.',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: serverIsRunning
                        ? null
                        : () => _saveRootDirectory(controller, _rootDirectoryController.text.trim()),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save path'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: serverIsRunning
                        ? null
                        : () {
                            const sharedStorage = '/storage/emulated/0';
                            _rootDirectoryController.text = sharedStorage;
                            _saveRootDirectory(controller, sharedStorage);
                          },
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Use full storage'),
                  ),
                ),
              ],
            ),

            const SectionTitle(title: 'APPEARANCE', icon: Icons.palette_outlined),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
              ],
              selected: {themeProvider.themeMode},
              onSelectionChanged: (selection) => themeProvider.setThemeMode(selection.first),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _saveCredentials(SettingsController controller) {
    if (_formKey.currentState?.validate() ?? false) {
      controller.saveCredentials(_usernameController.text.trim(), _passwordController.text);
      if (controller.validatePort(_portController.text) == null) {
        controller.savePort(_portController.text);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _saveRootDirectory(SettingsController controller, String path) async {
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Root directory cannot be empty')),
      );
      return;
    }
    // Creates the folder if it doesn't exist yet, then persists it as
    // the new FTP root — matches SettingsController.changeRootDirectory,
    // which delegates to StorageService.ensureDirectoryExists.
    await controller.changeRootDirectory(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Root directory set to $path')),
    );
  }
}
