extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
          .hasMatch(this);

  bool get isValidUsername =>
      RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(this);
}
