import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/presentation/widgets/people/person_option_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/utils/people.utils.dart';
import 'package:immich_mobile/widgets/common/person_sliver_app_bar.dart';

@RoutePage()
class DriftPersonPage extends ConsumerStatefulWidget {
  final DriftPerson initialPerson;

  const DriftPersonPage(this.initialPerson, {super.key});

  @override
  ConsumerState<DriftPersonPage> createState() => _DriftPersonPageState();
}

class _DriftPersonPageState extends ConsumerState<DriftPersonPage> {
  late DriftPerson _person;

  @override
  initState() {
    super.initState();
    _person = widget.initialPerson;
  }

  Future<void> handleEditName(BuildContext context) async {
    await showNameEditModal(context, _person);
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
    // Check if the route is still in the stack before watching the provider
    // This prevents the page from triggering pop operations if it's already been removed
    final isRouteActive = ModalRoute.of(context)?.isCurrent ?? false;

    final personAsync = ref.watch(driftPersonProvider(_person.id));

    return personAsync.when(
      data: (personByIdProvider) {
        if (personByIdProvider == null) {
          print('!!! M123: Person with ID ${_person.id} not found, route active: $isRouteActive');
          // Only pop if the route is still active to prevent double-popping
          if (isRouteActive) {
            print('!!! M123: Route is still active, popping back');
            // Person was deleted or not found, pop back
            /* WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.maybePop();
              }
            });*/
          } else {
            print('!!! M123: Route is not active, not popping');
          }
          return const Center(child: CircularProgressIndicator());
        }
        _person = personByIdProvider;
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }
}
