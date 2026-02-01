/*const List<String> allowedUserIds = [
  "ZtwSlrXFTKY0OR90G1ZXPlITWtB2",
  "pcGfYPzwLsfErmW3UJnjRCEs8TU2",
  // Add more allowed user IDs here
];*/

enum UserType { All, PreVenteOnly, VenteReglementOnly, AllExceptEdit }

// Map of allowed user IDs and their types.
const Map<String, UserType> allowedUsers = {
  "ZtwSlrXFTKY0OR90G1ZXPlITWtB2": UserType.All,
  "LkvAFKw9maasq1GOW2ADSBSzFDa2": UserType.All,
  "B66rKL1jumVHpHyCGjZc5Axnqll1": UserType.All,
  "P59Md1vDKbMBTvW2PuAkZcc2SNj2":
      UserType.AllExceptEdit, // Can click all three buttons
  "ckCk7sedUPWag0aVRWECb7iQtTo2":
      UserType.PreVenteOnly, // Can only click "Pré vente"
  "pcGfYPzwLsfErmW3UJnjRCEs8TU2":
      UserType.VenteReglementOnly, // Can click "Vente" and "Règlement"
};

/// Offline fallback: any user ID (or username) not present in [allowedUsers]
/// should have full permissions so the app remains usable without Firebase IDs.
UserType resolveUserType(String? userKey) {
  return allowedUsers[userKey] ?? UserType.All;
}