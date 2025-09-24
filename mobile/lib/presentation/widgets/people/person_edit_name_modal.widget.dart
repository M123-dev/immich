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

class DriftPersonNameEditForm extends ConsumerStatefulWidget {
  final DriftPerson person;

  const DriftPersonNameEditForm({super.key, required this.person});

  @override
  ConsumerState<DriftPersonNameEditForm> createState() => _DriftPersonNameEditFormState();
}

class _DriftPersonNameEditFormState extends ConsumerState<DriftPersonNameEditForm> {
  late TextEditingController _formController;
  List<DriftPerson> _filteredPeople = [];

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

  void _filterPeople(List<DriftPerson> people, String query) {
    if (!mounted) return;
    setState(() {
      _filteredPeople = query.isEmpty
          ? []
          : people.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).take(3).toList();
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
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _filteredPeople.map((person) {
                        return ListTile(
                          title: Text(person.name),
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
