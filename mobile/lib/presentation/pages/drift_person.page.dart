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

import '../../providers/infrastructure/people.provider.dart';
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
  }

  Future<void> handleEditBirthday(BuildContext context) async {
    await showBirthdayEditModal(context, _person);
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
    final personAsync = ref.watch(driftGetPersonByIdProvider(_person.id));
    final mergeTracker = ref.watch(personMergeTrackerProvider);

    return personAsync.when(
      data: (person) {
        // Check if the person was merged and redirect if necessary
        if (person == null) {
          final targetPersonId = mergeTracker.getTargetPersonId(_person.id);
          if (targetPersonId != null) {
            // Person was merged, redirect to the target person
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Use the service directly to get the target person
                ref.read(driftPeopleServiceProvider).watchPersonById(targetPersonId).first.then((targetPerson) {
                  if (targetPerson != null && mounted) {
                    context.replaceRoute(DriftPersonRoute(
                      key: ValueKey(targetPerson.toString()),
                      person: targetPerson,
                    ));
                  }
                }).catchError((error) {
                  // If we can't load the target person, go back
                  if (mounted) {
                    context.maybePop();
                  }
                });
              }
            });
            return const Center(child: CircularProgressIndicator());
          }
          // Person not found and no merge record, show empty state
          return const SizedBox.shrink();
        }
        
        _person = person;
        return ProviderScope(
          overrides: [
            timelineServiceProvider.overrideWith((ref) {
              final user = ref.watch(currentUserProvider);
              if (user == null) {
                throw Exception('User must be logged in to view person timeline');
              }

              final timelineService = ref.watch(timelineFactoryProvider).person(user.id, person.id);
              ref.onDispose(timelineService.dispose);
              return timelineService;
            }),
          ],
          child: Timeline(
            appBar: PersonSliverAppBar(
              person: person,
              onNameTap: () => handleEditName(context),
              onBirthdayTap: () => handleEditBirthday(context),
              onShowOptions: () => showOptionSheet(context),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
