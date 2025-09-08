enum AccountStatus { pending, verified, rejected }

class UserAccount {
  String name;
  final String username;
  String email;
  final String password;
  final String nibFileName;
  final String ktpFileName;
  AccountStatus status;

  UserAccount({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    required this.nibFileName,
    required this.ktpFileName,
    this.status = AccountStatus.pending,
  });
}