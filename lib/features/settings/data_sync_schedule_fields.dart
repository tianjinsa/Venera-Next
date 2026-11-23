import 'package:flutter/material.dart';
import 'package:venera_next/components/mobile_choice.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/foundation/sync_configuration.dart';
import 'package:venera_next/foundation/translations.dart';

class DataSyncScheduleFields extends StatelessWidget {
  const DataSyncScheduleFields({
    super.key,
    required this.mode,
    required this.minutes,
    required this.onModeChanged,
    required this.onIntervalChanged,
  });

  final DataSyncMode mode;
  final int minutes;
  final ValueChanged<DataSyncMode> onModeChanged;
  final ValueChanged<int> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field<DataSyncMode>(
          context,
          label: 'Sync mode'.tl,
          value: mode,
          options: [
            MobileChoiceOption(DataSyncMode.manual, 'Manual sync'.tl),
            MobileChoiceOption(DataSyncMode.realtime, 'Real-time sync'.tl),
            MobileChoiceOption(DataSyncMode.scheduled, 'Scheduled sync'.tl),
          ],
          onChanged: onModeChanged,
        ),
        if (mode == DataSyncMode.scheduled) ...[
          const SizedBox(height: 16),
          _field<int>(
            context,
            label: 'Sync interval'.tl,
            value: minutes,
            options: [
              for (final interval in SyncConfiguration.intervalOptions)
                MobileChoiceOption(
                  interval,
                  '@minutes min'.tlParams({'minutes': '$interval'}),
                ),
            ],
            onChanged: onIntervalChanged,
          ),
          const SizedBox(height: 12),
          Text(
            'Syncs at the selected interval while the app is running. Overdue syncs run when the app reopens. Local changes are uploaded; otherwise, the server is checked for updates.'
                .tl,
          ),
        ],
      ],
    );
  }

  Widget _field<T extends Object>(
    BuildContext context, {
    required String label,
    required T value,
    required List<MobileChoiceOption<T>> options,
    required ValueChanged<T> onChanged,
  }) {
    if (MobileUi.enabledOf(context)) {
      return MobileChoiceFormField<T>(
        label: label,
        initialValue: value,
        options: options,
        onChanged: onChanged,
      );
    }
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: [
            for (final option in options)
              DropdownMenuItem(value: option.value, child: Text(option.label)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
