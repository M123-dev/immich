import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';

import '../../../routing/router.dart';

class DriftPersonMergeForm extends ConsumerStatefulWidget {
  final DriftPerson person;
  final DriftPerson mergeTarget;

  const DriftPersonMergeForm({super.key, required this.person, required this.mergeTarget});

  @override
  ConsumerState<DriftPersonMergeForm> createState() => _DriftPersonMergeFormState();
}

class _DriftPersonMergeFormState extends ConsumerState<DriftPersonMergeForm> {
  bool _isMerging = false;

  Future<void> _mergePeople(BuildContext context) async {
    setState(() => _isMerging = true);
    try {
      final peopleService = ref.read(driftPeopleServiceProvider);

      // Get asset IDs of both persons before merge to invalidate their providers
      final mergedPersonAssetIds = await peopleService.getPersonAssetIds(widget.person.id);
      final targetPersonAssetIds = await peopleService.getPersonAssetIds(widget.mergeTarget.id);

      await peopleService.mergePeople(targetPersonId: widget.mergeTarget.id, mergePersonIds: [widget.person.id]);
      print('M123: We are trying to merge person ${widget.person.id} into ${widget.mergeTarget.id}');
      if (mounted) {
        // Close the merge dialog first
        Navigator.of(context).pop(widget.mergeTarget);

        // Update the route stack by navigating: find the DriftPersonRoute with the merged person
        // pop back to it, and then navigate to the target person
        final router = context.router;

        // Check if there's a DriftPersonRoute in the stack with the merged person ID
        bool foundPersonRoute = false;
        for (final page in router.stack) {
          if (page.name == DriftPersonRoute.name) {
            final routeArgs = page.routeData.route.args;
            if (routeArgs is DriftPersonRouteArgs) {
              if (routeArgs.initialPerson.id == widget.person.id) {
                foundPersonRoute = true;
                break;
              }
            }
          }
        }

        print('M123: Found person route with merged person ID: $foundPersonRoute');

        if (foundPersonRoute) {
          print('M123: Router stack before popUntil: ${router.stack.length} routes');
          // Pop back to the old person route
          router.popUntil((route) {
            print('M123: Checking route ${route.settings.name} for popUntil, looking for ${DriftPersonRoute.name}');

            if (route.settings.name == DriftPersonRoute.name) {
              print('M123: Found a DriftPersonRoute, arguments: ${route.settings.arguments}');
              if (route.settings.arguments is DriftPersonRouteArgs) {
                print(
                  'M123: Route arguments is of type DriftPersonRouteArgs, initial person ID: ${(route.settings.arguments as DriftPersonRouteArgs).initialPerson.id}',
                );
                final routePersonId = (route.settings.arguments as DriftPersonRouteArgs).initialPerson.id;
                if (routePersonId == widget.person.id) {
                  print('M123: This route matches the merged person ID, we will pop back to it');
                  return true;
                }
              }
            }
            print('M123: This route is not a DriftPersonRoute, we will keep looking');
            return false;
          });

          print('M123: Router stack after popUntil: ${router.stack.length} routes');
          print('M123: Current route on stack: ${router.stack.last.name}');
          print('M123: Popped back to person route, now replacing with merge target ${widget.mergeTarget.id}');
          // Use popAndPush to close the old person route and all routes above it (like AssetViewer)
          // and open the new person route with the merged target
          await router.popAndPush(DriftPersonRoute(initialPerson: widget.mergeTarget));
          print('M123: Navigation complete');
        }

        print(
          'M123: Navigation logic complete, now invalidating providers for asset IDs: merged=${mergedPersonAssetIds.length}, target=${targetPersonAssetIds.length}',
        );

        for (final assetId in mergedPersonAssetIds) {
          ref.invalidate(driftPeopleAssetProvider(assetId));
        }
        for (final assetId in targetPersonAssetIds) {
          ref.invalidate(driftPeopleAssetProvider(assetId));
        }
        ref.invalidate(driftGetAllPeopleProvider);
        print('M123: Provider invalidation complete');

        ImmichToast.show(
          context: context,
          msg: "merge_people_successfully".tr(),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMerging = false);
        ImmichToast.show(
          context: context,
          msg: "error_title".tr(),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final headers = ApiService.getRequestHeaders();

    return AlertDialog(
      title: const Text("merge_people", style: TextStyle(fontWeight: FontWeight.bold)).tr(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: NetworkImage(getFaceThumbnailUrl(widget.person.id), headers: headers),
              ),
              const SizedBox(width: 16),
              const RotatedBox(quarterTurns: 1, child: Icon(Icons.merge_type, size: 32)),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 32,
                backgroundImage: NetworkImage(getFaceThumbnailUrl(widget.mergeTarget.id), headers: headers),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "are_these_the_same_person",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            textAlign: TextAlign.center,
          ).tr(),
          const SizedBox(height: 8),
          const Text(
            "they_will_be_merged_together",
            style: TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ).tr(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.onSurface,
                    foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
                    elevation: 0,
                  ),
                  onPressed: _isMerging ? null : () => Navigator.of(context).pop(),
                  child: const Text("no", style: TextStyle(fontWeight: FontWeight.bold)).tr(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: _isMerging ? null : () => _mergePeople(context),
                  child: _isMerging
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text("yes", style: TextStyle(fontWeight: FontWeight.bold)).tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
