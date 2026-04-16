import re

with open("lib/widgets/app_card.dart", "r") as f:
    text = f.read()

# Replace in bottom sheet
bs_start = text.find("void _showInstallBottomSheet(BuildContext context) {")
bs_end = text.find("Widget _buildDetailView(BuildContext context, {bool showBackButton = false}) {", bs_start)

if bs_start != -1 and bs_end != -1:
    bs_block = text[bs_start:bs_end]
    # Replace the install action
    action_old = """                                    : () async {
                                        final String appId =
                                            widget.app['id']?.toString() ?? '';"""
    
    action_new = """                                    : () async {
                                        if (_isInstalled) {
                                            for (var value in widget.app.values) {
                                                if (value != null && value.toString().contains('.')) {
                                                    try                                                           final installed = await InstalledAp                  val                                                                              try               
                                                                                                                                                                            await Future.delayed(const Duration(seconds: 1));
                                                                     ns                                                                                                                                  ns                      break;
                                                        }                                                        } ch (_) {}
                                                }
                                            }
                                            return;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     =                                                                                                                                                                                                                                       lo                                                                                                                                                 t(
                                                isInstallingLocal
                                                         tallProgressLocal >
                                                                0.0 &&
                                                            installProgressLocal <
                                                                1.0
                                                        ? '${(installProgressLocal * 100).toInt()}%'
                                                        : installStatusLocal
                                                    : tr('Install'),"""
    text_new = """                                              Text(
                                                isInstallingLocal
                                                    ? installProgressLocal >
                                                                0.0 &&
                                                            installProgressLocal <
                                                                1.0
                                                        ? '${(installProgressLocal * 100).toInt()}%'
                                                                                                                                                            all') : tr('In                                                               
                                                                                                       in                                                                           se                                                                      hange color
    dv_color_old = """                                decora    dv_color_old = """                                decora    sInstalling
                                      ? Colors.grey.shade800
                                                      xt).colorScheme.primary,"""
    dv_color_new = """                                decoration: BoxDecoration(
                                  color: _isInstalling
                                                                                                             al                                                                                                             al                                                                                                             al       ing
                                                                                                                                                                                                                                                                                                              ?.toString() ??
                                                    '';"""
    dv_action_new = """     dv_action_new = """     dv_action_new = """     dv_aing
                                                                                                                                                                  sI                                                                                                                                                                                                                         sI                                                                                                                                                                                  value.toString());
                                                                if (installed == true) {
                                                                    await InstalledApps.uninstallApp(value.toString());
                                                                    await Future.delayed(con                                                                                              _checkIsInstalled();
                                                                    break;
                                                                }
                                                            } catch (_) {}
                                                        }
                                                    }
                                                    return;
                                                }
                                                final String appId =
                                                    widget.app['id']
                                                        ?.toString() ??
                                                                                                                                                                                                                                                                                                                                                                                                                                          0.0 &&
                                                                                 <
                                                                      0
                                                            ?                                                                                                         stallStatu                                                           : tr('Install'),"""
    dv_text_new = """                                                child: Text(
                                                  _isInstalling
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  :                                                                                  al                                                                      ace(dv_text_old, dv_text_new)
    
    text = text[:dv_start] + dv_block

with open("lib/widgets/app_card.dart", "w") as f:
    f.write(text)

