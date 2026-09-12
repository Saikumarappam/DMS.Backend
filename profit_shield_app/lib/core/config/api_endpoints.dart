/// Central API endpoint map for ProfitShield mobile app.
/// Base: https://profitshield.profygen.com
/// Swagger: https://profitshield.profygen.com/swagger/index.html
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authChangePassword = '/auth/change-password';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authResetPassword = '/auth/reset-password';

  // ── Categories ──────────────────────────────────────────────────────────────
  static const String categories = '/categories';
  static String categoryById(int id) => '/categories/$id';

  // ── Documents ───────────────────────────────────────────────────────────────
  static const String documentsUpload = '/documents/upload';
  static const String documentsHistory = '/documents/history';
  static const String documentsDashboard = '/documents/dashboard';
  static String documentDownload(int id) => '/documents/$id/download';
  static String documentDelete(int id) => '/documents/$id';
  static String documentDeletePost(int id) => '/documents/$id/delete';

  // ── Reports (Admin) ─────────────────────────────────────────────────────────
  static const String reportsDaily = '/reports/daily';
  static const String reportsMonthly = '/reports/monthly';
  static const String reportsUserWise = '/reports/user-wise';
  static const String reportsCategoryWise = '/reports/category-wise';
  static const String reportsAuditLogs = '/reports/audit-logs';

  // ── Users ───────────────────────────────────────────────────────────────────
  static const String users = '/users';
  static const String usersProfile = '/users/profile';
  static String userById(int id) => '/users/$id';
  static String userApproval(int id) => '/users/$id/approval';
  static String userStatus(int id) => '/users/$id/status';
}
