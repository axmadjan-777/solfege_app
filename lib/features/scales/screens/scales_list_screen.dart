import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/scales_repository.dart';
import '../models/key_signature_category.dart';
import '../widgets/key_signature_filter_chips.dart';
import '../widgets/key_signature_group_card.dart';
import 'key_signature_detail_screen.dart';

class ScalesListScreen extends StatefulWidget {
  const ScalesListScreen({super.key});

  @override
  State<ScalesListScreen> createState() => _ScalesListScreenState();
}

class _ScalesListScreenState extends State<ScalesListScreen> {
  static const _repository = ScalesRepository();

  KeySignatureFilter _filter = KeySignatureFilter.all;

  @override
  Widget build(BuildContext context) {
    final groups = _repository.getGroups(filter: _filter);

    return Scaffold(
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          itemCount: groups.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Гаммы',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Слушай, запоминай и сравнивай звучание разных ладов',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  KeySignatureFilterChips(
                    selected: _filter,
                    onSelected: (filter) => setState(() => _filter = filter),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }

            final group = groups[index - 1];
            return KeySignatureGroupCard(
              group: group,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => KeySignatureDetailScreen(group: group),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
