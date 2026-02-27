// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CrazyReal';

  @override
  String get home => 'Home';

  @override
  String get friends => 'Friends';

  @override
  String get newPost => 'New Post';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get currentChallenge => 'Current Challenge';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get uploadPhoto => 'Upload Photo';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'An error occurred';

  @override
  String get success => 'Success!';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get profile => 'Profile';

  @override
  String get logout => 'Logout';

  @override
  String get login => 'Login';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get username => 'Username';

  @override
  String get welcomeMessage => 'Welcome to CrazyReal!';

  @override
  String get noPostsYet => 'No posts yet';

  @override
  String get photoUploadSuccess => 'Photo uploaded successfully!';

  @override
  String get photoUploadError => 'Failed to upload photo';

  @override
  String get cameraPermissionRequired => 'Camera permission is required';

  @override
  String get retryUpload => 'Retry Upload';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get french => 'French';

  @override
  String get friendPage => 'Friend Page';

  @override
  String get thisFriendPage => 'This is the friend page';

  @override
  String get settingPage => 'Setting Page';

  @override
  String get thisSettingPage => 'This is the setting page';

  @override
  String get accountPage => 'Account Page';

  @override
  String get thisAccountPage => 'This is the account page';

  @override
  String get loadingChallenge => 'Loading challenge...';

  @override
  String get onlyOneCamera => 'Only one camera available';

  @override
  String get cameraNotAvailable => 'Camera not available!';

  @override
  String get photoSentToFeed => 'Photo sent to your Feed!';

  @override
  String get errorSendingPhoto => '❌ Error sending photo';

  @override
  String get cameraOnlyMobile => '📱 Camera available only on iOS/Android';

  @override
  String serverError(String code) {
    return 'Server error: $code';
  }

  @override
  String connectionError(String error) {
    return 'Connection error: $error';
  }

  @override
  String get loadingImagesError => 'Error loading images';
}
