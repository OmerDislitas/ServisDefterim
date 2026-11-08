import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/settings_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/phone.dart';
import '../../shared/widgets/form_scaffold.dart';

/// WhatsApp bakim hatirlatma sablonu (PLAN 6.5). Degiskenler: {ad}, {marka}, {tarih}.
class WhatsappTemplateScreen extends ConsumerStatefulWidget {
  const WhatsappTemplateScreen({super.key});

  @override
  ConsumerState<WhatsappTemplateScreen> createState() => _WhatsappTemplateScreenState();
}

class _WhatsappTemplateScreenState extends ConsumerState<WhatsappTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider).settingsDao.getValue(SettingKeys.whatsappTemplate).then((v) {
      if (!mounted) return;
      _text.text = v ?? S.defaultWhatsappTemplate;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(databaseProvider).settingsDao.setValue(SettingKeys.whatsappTemplate, _text.text.trim());
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormScaffold(
      title: S.whatsappTemplate,
      formKey: _formKey,
      loading: _loading,
      onSave: _save,
      children: [
        TextFormField(
          controller: _text,
          minLines: 4,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: S.whatsappTemplate),
          validator: (v) => (v == null || v.trim().isEmpty) ? S.requiredField : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(S.whatsappTemplateVars, style: theme.textTheme.bodySmall),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _text.text = S.defaultWhatsappTemplate),
            child: const Text(S.resetToDefault),
          ),
        ),
        const SizedBox(height: 8),
        Text(S.preview, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              fillWhatsappTemplate(_text.text, name: 'Ahmet Bey', brand: 'Demirdöküm', date: formatDate(today())),
            ),
          ),
        ),
      ],
    );
  }
}
