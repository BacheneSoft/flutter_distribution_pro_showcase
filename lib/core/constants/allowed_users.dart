/*const List<String> allowedUserIds = [
  "ZtwSlrXFTKY0OR90G1ZXPlITWtB2",
  "pcGfYPzwLsfErmW3UJnjRCEs8TU2",
  // Add more allowed user IDs here
];*/

enum UserType { All, PreVenteOnly, VenteReglementOnly, AllExceptEdit }

// Mock of allowed user IDs for the public showcase.
// In the original private app, these were real Firebase User IDs.
const Map<String, UserType> allowedUsers = {
  "MOCK_USER_ADMIN_1": UserType.All,
  "MOCK_USER_SALES_1": UserType.AllExceptEdit,
  "MOCK_USER_PREV_1": UserType.PreVenteOnly,
  "MOCK_USER_VRT_1": UserType.VenteReglementOnly,
};


/// Offline fallback: any user ID (or username) not present in [allowedUsers]
/// should have full permissions so the app remains usable without Firebase IDs.
UserType resolveUserType(String? userKey) {
  return allowedUsers[userKey] ?? UserType.All;
}