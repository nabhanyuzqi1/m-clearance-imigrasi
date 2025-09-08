import '../models/clearance_application.dart';
import '../models/user_account.dart';

class UserService {
  // Path gambar profil untuk pengguna (agen)
  static String? currentProfileImagePath;
  // Path gambar profil untuk petugas (officer/admin)
  static String? officerProfileImagePath;

  static final List<UserAccount> agentAccounts = [
    UserAccount(name: "PT. Tester Beta", username: "test", email: "test@email.com", password: "test", nibFileName: "nib_test.pdf", ktpFileName: "ktp_test.pdf", status: AccountStatus.verified),
    UserAccount(name: "PT. AGEN KAPAL SENTOSA", username: "agen_budi", email: "budi@email.com", password: "agen123", nibFileName: "nib_budi.pdf", ktpFileName: "ktp_budi.pdf", status: AccountStatus.verified),
    UserAccount(name: "Agen Citra", username: "agen_citra", email: "citra@email.com", password: "agen456", nibFileName: "nib_citra.pdf", ktpFileName: "ktp_citra.pdf", status: AccountStatus.pending),
  ];

  // PERBAIKAN: Menambahkan parameter nibFileName dan ktpFileName
  static void addAgent({
    required String name,
    required String username,
    required String email,
    required String password,
    required String nibFileName,
    required String ktpFileName,
  }) {
    agentAccounts.insert(
        0,
        UserAccount(
          name: name,
          username: username,
          email: email,
          password: password,
          // PERBAIKAN: Menggunakan nilai dari parameter
          nibFileName: nibFileName,
          ktpFileName: ktpFileName,
          status: AccountStatus.pending,
        ));
  }

  static void updateAgentProfile(String username, String newName, String newEmail) {
    try {
      final account = agentAccounts.firstWhere((acc) => acc.username == username);
      account.name = newName;
      account.email = newEmail;
    } catch (e) {
      // Sebaiknya gunakan logger di aplikasi nyata
      // print("Gagal memperbarui profil: Pengguna tidak ditemukan.");
    }
  }

  static List<ClearanceApplication> agentHistory = [
     ClearanceApplication(shipName: "KM. Sinar Jaya", agentName: "PT. AGEN KAPAL SENTOSA", flag: "Indonesia", type: ApplicationType.kedatangan, status: ApplicationStatus.approved, date: "15-10-2025", port: "Sampit", wniCrew: "10", wnaCrew: "2", officerName: "Maulana Akbar"),
     ClearanceApplication(shipName: "MV. Ocean Queen", agentName: "PT. AGEN KAPAL SENTOSA", flag: "Panama", type: ApplicationType.kedatangan, status: ApplicationStatus.revision, notes: "Data kru tidak lengkap."),
     ClearanceApplication(shipName: "TB. Perkasa", agentName: "Agen Citra", flag: "Indonesia", type: ApplicationType.keberangkatan, status: ApplicationStatus.waiting),
     ClearanceApplication(shipName: "KM. Samudera", agentName: "PT. AGEN KAPAL SENTOSA", flag: "Malaysia", type: ApplicationType.kedatangan, status: ApplicationStatus.declined, notes: "Izin berlayar sudah kedaluwarsa."),
  ];

  static void addApplicationToHistory(ClearanceApplication app) {
    int existingIndex = agentHistory.indexWhere((historyApp) =>
        historyApp.shipName == app.shipName &&
        historyApp.agentName == app.agentName &&
        historyApp.type == app.type &&
        historyApp.status == ApplicationStatus.waiting // Hanya replace jika statusnya masih menunggu
    );

    if (existingIndex != -1) {
      agentHistory[existingIndex] = app;
    } else {
      agentHistory.insert(0, app);
    }
  }
}
