import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/presentation/widgets/people/person_option_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/routes.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/people.utils.dart';
import 'package:immich_mobile/widgets/common/person_sliver_app_bar.dart';
import 'package:logging/logging.dart';

@RoutePage()
class DriftPersonPage extends ConsumerStatefulWidget {
  final DriftPerson initialPerson;

  const DriftPersonPage(this.initialPerson, {super.key});

  @override
  ConsumerState<DriftPersonPage> createState() => _DriftPersonPageState();
}

class _DriftPersonPageState extends ConsumerState<DriftPersonPage> {
  late DriftPerson _person;

  final Logger mergeLogger = Logger("PersonMerge");

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
    final personAsync = ref.watch(driftGetPersonByIdProvider(_person.id));
    final currentRouteName = ref.watch(currentRouteNameProvider.select((name) => name ?? DriftPersonRoute.name));
    final mergeTracker = ref.read(personMergeTrackerProvider);

    return personAsync.when(
      data: (personByProvider) {
        if (personByProvider == null) {
          // Check if the person was merged and redirect if necessary
          final shouldRedirect = mergeTracker.shouldRedirectForPerson(_person.id);
          final targetPersonId = mergeTracker.getTargetPersonId(_person.id);

          if (shouldRedirect && targetPersonId != null) {
            bool isOnPersonDetailPage = ModalRoute.of(context)?.isCurrent ?? false;

            print('m123: We are on route: $currentRouteName, isOnPersonDetailPage: $isOnPersonDetailPage');

            // Only redirect if we're currently on the person detail page, not in a nested view, e.g. image viewer
            if (isOnPersonDetailPage) {
              // Person was merged, redirect to the target person
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  print('m123: Redirecting to target person $targetPersonId');
                  // Use the service directly to get the target person
                  ref
                      .read(driftPeopleServiceProvider)
                      .watchPersonById(targetPersonId)
                      .first
                      .then((targetPerson) {
                        if (targetPerson != null && mounted) {
                          // Mark the merge record as handled
                          print('m123: Found target person, rebuilding');
                          mergeTracker.markMergeRecordHandled(_person.id);
                          _person = targetPerson;
                          setState(() {});
                        } else {
                          // Target person not found, go back
                          context.maybePop();
                        }
                      })
                      .catchError((error) {
                        // If we can't load the target person, go back
                        mergeLogger.severe("Error during read of targetPerson", error);
                        if (mounted) {
                          context.maybePop();
                        }
                      });
                }
              });
              print('m123: Showing loading spinner while redirecting');
              return const Center(child: CircularProgressIndicator());
            } else {
              // We're in an image viewer or other nested view, don't redirect yet
              // Just show loading spinner to indicate something is happening
              print('m123: Not on person detail page, not redirecting yet');
              return const Center(child: CircularProgressIndicator());
            }
          }

          // Person not found and no merge record
          print('m123: Person not found and no merge record, showing empty state');
          mergeLogger.info(
            'Person ${_person.name} (${_person.id}) not found and no merge records exist, it was probably deleted',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.maybePop();
            }
          });
          return const Center(child: CircularProgressIndicator());
        }

        _person = personByProvider;
        return ProviderScope(
          overrides: [
            timelineServiceProvider.overrideWith((ref) {
              final user = ref.watch(currentUserProvider);
              if (user == null) {
                throw Exception('User must be logged in to view person timeline');
              }

              final timelineService = ref.read(timelineFactoryProvider).person(user.id, _person.id);
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
      // TODO(m123): Show initialPerson data while loading new data (optimistic ui update, but we need to handle scroll state etc)
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }
}
