// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'CrazyReal';

  @override
  String get home => 'Accueil';

  @override
  String get friends => 'Amis';

  @override
  String get newPost => 'Nouveau Post';

  @override
  String get settings => 'Paramètres';

  @override
  String get account => 'Compte';

  @override
  String get currentChallenge => 'Challenge Actuel';

  @override
  String get takePhoto => 'Prendre une Photo';

  @override
  String get uploadPhoto => 'Télécharger une Photo';

  @override
  String get loading => 'Chargement...';

  @override
  String get error => 'Une erreur s\'est produite';

  @override
  String get success => 'Succès !';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get profile => 'Profil';

  @override
  String get profileUpdated => 'Profil mis à jour';

  @override
  String get profilePhoto => 'Photo de profil';

  @override
  String get changePhoto => 'Changer la photo';

  @override
  String get chooseAvatar => 'Choisir un avatar';

  @override
  String get baseAvatars => 'Avatars de base';

  @override
  String get chooseFromGallery => 'Choisir depuis la galerie';

  @override
  String get removePhoto => 'Supprimer la photo';

  @override
  String get logout => 'Déconnexion';

  @override
  String get login => 'Connexion';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mot de passe';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get welcomeMessage => 'Bienvenue sur CrazyReal !';

  @override
  String get noPostsYet => 'Aucun post pour le moment';

  @override
  String get photoUploadSuccess => 'Photo téléchargée avec succès !';

  @override
  String get photoUploadError => 'Échec du téléchargement de la photo';

  @override
  String get cameraPermissionRequired =>
      'La permission de la caméra est requise';

  @override
  String get retryUpload => 'Réessayer';

  @override
  String get selectLanguage => 'Sélectionner la langue';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get friendPage => 'Page Amis';

  @override
  String get thisFriendPage => 'Ceci est la page des amis';

  @override
  String get settingPage => 'Page Paramètres';

  @override
  String get thisSettingPage => 'Ceci est la page des paramètres';

  @override
  String get accountPage => 'Page Compte';

  @override
  String get thisAccountPage => 'Ceci est la page du compte';

  @override
  String get loadingChallenge => 'Chargement du défi...';

  @override
  String get onlyOneCamera => 'Une seule caméra disponible';

  @override
  String get cameraNotAvailable => 'Caméra non disponible !';

  @override
  String get photoSentToFeed => 'Photo envoyée dans ton Feed !';

  @override
  String get errorSendingPhoto => '❌ Erreur lors de l\'envoi de la photo';

  @override
  String get pleaseLoginFirst => '🔒 Veuillez vous connecter d\'abord';

  @override
  String get cameraOnlyMobile =>
      '📱 Caméra disponible uniquement sur iOS/Android';

  @override
  String serverError(String code) {
    return 'Erreur serveur: $code';
  }

  @override
  String connectionError(String error) {
    return 'Erreur connexion: $error';
  }

  @override
  String get loadingImagesError => 'Erreur lors du chargement des images';

  @override
  String get register => 'S\'inscrire';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get pleaseEnterUsername => 'Veuillez entrer un nom d\'utilisateur';

  @override
  String get usernameTooShort =>
      'Le nom d\'utilisateur doit contenir au moins 3 caractères';

  @override
  String get pleaseEnterEmail => 'Veuillez entrer votre email';

  @override
  String get pleaseEnterValidEmail => 'Veuillez entrer un email valide';

  @override
  String get pleaseEnterPassword => 'Veuillez entrer un mot de passe';

  @override
  String get passwordTooShort =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get pleaseConfirmPassword => 'Veuillez confirmer votre mot de passe';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ? Connexion';

  @override
  String get dontHaveAccount => 'Vous n\'avez pas de compte ? S\'inscrire';

  @override
  String get usernameLabel => 'Nom d\'utilisateur : ';

  @override
  String get emailLabel => 'Email : ';

  @override
  String get pleaseLoginOrRegister =>
      'Veuillez vous connecter ou vous inscrire pour continuer';

  @override
  String get friendRequestAccepted => 'Demande acceptée !';

  @override
  String get addFriend => 'Ajouter un ami';

  @override
  String get friendUsernameLabel => 'Pseudo de l\'utilisateur';

  @override
  String get friendUsernameHint => 'Ex: johndoe';

  @override
  String get send => 'Envoyer';

  @override
  String friendRequestSent(String username) {
    return 'Demande envoyée à $username !';
  }

  @override
  String get friendRequestError =>
      'Erreur : Utilisateur introuvable ou demande existante.';

  @override
  String get searchUsersHint => 'Rechercher un pseudo';

  @override
  String get accountPublic => 'Public';

  @override
  String get accountPrivate => 'Privé';

  @override
  String get noUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get requestSentShort => 'Envoyée';

  @override
  String get myFriends => 'Mes Amis';

  @override
  String get requests => 'Demandes';

  @override
  String get noFriendsYet => 'Tu n\'as pas encore d\'amis.';

  @override
  String get noPendingRequests => 'Aucune demande en attente.';

  @override
  String get wantsToBeYourFriend => 'Veut être ton ami(e)';

  @override
  String get rejectRequest => 'Refuser';

  @override
  String get friendRequestRejected => 'Demande refusée.';

  @override
  String get group => 'Groupe';

  @override
  String get unknownUser => 'Utilisateur inconnu';

  @override
  String get feedLoadError => 'Impossible de charger le feed.';

  @override
  String get feedRetry => 'Réessayer';

  @override
  String get feedRefresh => 'Actualiser';

  @override
  String get publishFirstPost => 'Publier une photo';

  @override
  String get publishFirstPostHint =>
      'Réponds au challenge du moment pour remplir ton feed.';

  @override
  String get feedJustNow => 'À l\'instant';

  @override
  String timeAgoMinutes(int minutes) {
    return 'Il y a $minutes min';
  }

  @override
  String timeAgoHours(int hours) {
    return 'Il y a $hours h';
  }

  @override
  String timeAgoDays(int days) {
    return 'Il y a $days j';
  }
}
