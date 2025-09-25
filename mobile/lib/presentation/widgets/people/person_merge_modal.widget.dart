import 'package:flutter/material.dart';

import 'package:immich_mobile/domain/models/person.model.dart';

class DriftPersonMergeForm extends StatelessWidget {
  final DriftPerson person;
  final DriftPerson mergeTarget;

  const DriftPersonMergeForm({super.key, required this.person, required this.mergeTarget});

  @override
  Widget build(BuildContext context) {
    return AlertDialog();
  }
}
