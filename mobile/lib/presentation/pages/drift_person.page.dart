import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/presentation/widgets/people/person_option_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/utils/people.utils.dart';
import 'package:immich_mobile/widgets/common/person_sliver_app_bar.dart';

import '../../routing/router.dart';

@RoutePage()
class DriftPersonPage extends ConsumerStatefulWidget {
  final DriftPerson person;

  const DriftPersonPage({super.key, required this.person});

  @override
  ConsumerState<DriftPersonPage> createState() => _DriftPersonPageState();
}

class _DriftPersonPageState extends ConsumerState<DriftPersonPage> {
  late DriftPerson _person;

  @override
  initState() {
    super.initState();
    _person = widget.person;
  }

  Future<void> handleEditName(BuildContext context) async {
    final newPerson = await showNameEditModal(context, _person);

    if (newPerson == null) {
      return;
    }

    if (newPerson.id != _person.id) {
      if (mounted) {
        context.replaceRoute(DriftPersonRoute(key: ValueKey(newPerson.toString()), person: newPerson));
      }

      return;
    }

    if (newPerson.name != _person.name) {
      // TODO: Use provider?
      setState(() {
        _person = _person.copyWith(name: newPerson.name);
      });
      return;
    }
  }

  Future<void> handleEditBirthday(BuildContext context) async {
    final birthday = await showBirthdayEditModal(context, _person);

    if (birthday != null) {
      setState(() {
        _person = _person.copyWith(birthDate: birthday);
      });
    }
  }

  void showOptionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colorScheme.surface,
      isScrollControlled: false,
      builder: (context) {
        return PersonOptionSheet(
          onEditName: () async {
            await handleEditName(context);
            context.pop();
          },
          onEditBirthday: () async {
            await handleEditBirthday(context);
            context.pop();
          },
          birthdayExists: _person.birthDate != null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        timelineServiceProvider.overrideWith((ref) {
          final user = ref.watch(currentUserProvider);
          if (user == null) {
            throw Exception('User must be logged in to view person timeline');
          }

          final timelineService = ref.watch(timelineFactoryProvider).person(user.id, _person.id);
          ref.onDispose(timelineService.dispose);
          return timelineService;
        }),
      ],
      child: Timeline(
        appBar: PersonSliverAppBar(
          person: _person,
          onNameTap: () => handleEditName(context),
          onBirthdayTap: () => handleEditBirthday(context),
          onShowOptions: () => showOptionSheet(context),
        ),
      ),
    );
  }
}
