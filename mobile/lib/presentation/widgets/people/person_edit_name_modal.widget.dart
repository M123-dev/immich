import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/utils/debug_print.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';

import '../../../pages/common/large_leading_tile.dart';
import '../../../services/api.service.dart';
import '../../../utils/image_url_builder.dart';

class DriftPersonNameEditForm extends ConsumerStatefulWidget {
  final DriftPerson person;

  const DriftPersonNameEditForm({super.key, required this.person});

  @override
  ConsumerState<DriftPersonNameEditForm> createState() => _DriftPersonNameEditFormState();
}

class _DriftPersonNameEditFormState extends ConsumerState<DriftPersonNameEditForm> {
  late TextEditingController _formController;
  List<DriftPerson> _filteredPeople = [];

  final imageSize = 60.0;
  final headers = ApiService.getRequestHeaders();

  @override
  void initState() {
    super.initState();
    _formController = TextEditingController(text: widget.person.name);
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  void onEdit(String personId, String newName) async {
    try {
      final result = await ref.read(driftPeopleServiceProvider).updateName(personId, newName);
      if (result != 0) {
        ref.invalidate(driftGetAllPeopleProvider);
        if (mounted) {
          context.pop<String>(newName);
        }
      }
    } catch (error) {
      dPrint(() => 'Error updating name: $error');

      if (!context.mounted) {
        return;
      }

      ImmichToast.show(
        context: context,
        msg: 'scaffold_body_error_occurred'.t(context: context),
        gravity: ToastGravity.BOTTOM,
        toastType: ToastType.error,
      );
    }
  }

  // TODO: Add diacritic filtering? We would need to add a package
  void _filterPeople(List<DriftPerson> people, String query) {
    final queryParts = query.toLowerCase().split(' ').where((e) => e.isNotEmpty).toList();

    List<DriftPerson> startsWithMatches = [];
    List<DriftPerson> containsMatches = [];

    for (final p in people) {
      final nameParts = p.name.toLowerCase().split(' ').where((e) => e.isNotEmpty).toList();
      final allStart = queryParts.every((q) => nameParts.any((n) => n.startsWith(q)));
      final allContain = queryParts.every((q) => nameParts.any((n) => n.contains(q)));

      if (allStart) {
        // Prioritize names that start with the query
        startsWithMatches.add(p);
      } else if (allContain) {
        containsMatches.add(p);
      }
    }

    if (!mounted) return;
    setState(() {
      _filteredPeople = query.isEmpty ? [] : (startsWithMatches + containsMatches).take(3).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final curatedPeople = ref.watch(driftGetAllPeopleProvider);

    return AlertDialog(
      title: const Text("edit_name", style: TextStyle(fontWeight: FontWeight.bold)).tr(),
      content: curatedPeople.when(
        data: (people) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _formController,
                  decoration: const InputDecoration(
                    hintText: 'Name eingeben',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                  onChanged: (value) => _filterPeople(people, value),
                  onTapOutside: (event) => FocusScope.of(context).unfocus(),
                ),
                if (_filteredPeople.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _filteredPeople.map((person) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: LargeLeadingTile(
                            title: Text(
                              person.name,
                              style: context.textTheme.bodyLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                            leading: SizedBox(
                              height: imageSize,
                              child: Material(
                                shape: const CircleBorder(side: BorderSide.none),
                                elevation: 3,
                                child: CircleAvatar(
                                  maxRadius: imageSize / 2,
                                  backgroundImage: NetworkImage(getFaceThumbnailUrl(person.id), headers: headers),
                                ),
                              ),
                            ),
                            onTap: () {
                              if (!mounted) return;
                              setState(() {
                                _formController.text = person.name;
                                _filteredPeople = [];
                              });
                              _formController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _formController.text.length),
                              );
                            },

                            tileColor: context.primaryColor.withAlpha(25),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Text('Error: $err'),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(null),
          child: Text(
            "cancel",
            style: TextStyle(color: Colors.red[300], fontWeight: FontWeight.bold),
          ).tr(),
        ),
        TextButton(
          onPressed: () => onEdit(widget.person.id, _formController.text),
          child: Text(
            "save",
            style: TextStyle(color: context.primaryColor, fontWeight: FontWeight.bold),
          ).tr(),
        ),
      ],
    );
  }
}
