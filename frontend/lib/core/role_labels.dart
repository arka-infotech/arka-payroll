/// Human-readable role labels for UI (API still uses HR_ADMIN / SUPER_ADMIN / EMPLOYEE).
class RoleLabels {
  static String display(String? role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return 'Root access';
      case 'HR_ADMIN':
        return 'Admin access';
      case 'EMPLOYEE':
        return 'Employee';
      default:
        return role ?? '—';
    }
  }
}
