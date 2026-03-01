import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/presentation/widgets/people/person_edit_birthday_modal.widget.dart';
import 'package:immich_mobile/presentation/widgets/people/person_edit_name_modal.widget.dart';
import 'package:immich_mobile/presentation/widgets/people/person_merge_modal.widget.dart';

String formatAge(DateTime birthDate, DateTime referenceDate) {
  int ageInYears = _calculateAge(birthDate, referenceDate);
  int ageInMonths = _calculateAgeInMonths(birthDate, referenceDate);

  if (ageInMonths <= 11) {
    return "person_age_months".t(args: {'months': ageInMonths.toString()});
  } else if (ageInMonths > 12 && ageInMonths <= 23) {
    return "person_age_year_months".t(args: {'months': (ageInMonths - 12).toString()});
  } else {
    return "person_age_years".t(args: {'years': ageInYears.toString()});
  }
}

int _calculateAge(DateTime birthDate, DateTime referenceDate) {
  int age = referenceDate.year - birthDate.year;
  if (referenceDate.month < birthDate.month ||
      (referenceDate.month == birthDate.month && referenceDate.day < birthDate.day)) {
    age--;
  }
  return age;
}

int _calculateAgeInMonths(DateTime birthDate, DateTime referenceDate) {
  return (referenceDate.year - birthDate.year) * 12 +
      referenceDate.month -
      birthDate.month -
      (referenceDate.day < birthDate.day ? 1 : 0);
}

Future<void> showNameEditModal(BuildContext context, DriftPerson person) async {
  await showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (BuildContext context) {
      return DriftPersonNameEditForm(person: person);
    },
  );
}

Future<void> showBirthdayEditModal(BuildContext context, DriftPerson person) async {
  await showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (BuildContext context) {
      return DriftPersonBirthdayEditForm(person: person);
    },
  );
}

/// Return true or false, depending on whether the merge was successful or not.
/// This allows the caller to decide whether to pop the person page or not
/// May return false even when the merge was successful, because in certain cenarios (e.g. the person person page with the merged person is in the stack)
/// The poping will be handled by a popuntil.
Future<bool?> showMergeModal(BuildContext context, DriftPerson person, DriftPerson mergeTarget) async {
  return showDialog<bool?>(
    context: context,
    useRootNavigator: false,
    builder: (BuildContext context) {
      return DriftPersonMergeForm(person: person, mergeTarget: mergeTarget);
    },
  );
}
