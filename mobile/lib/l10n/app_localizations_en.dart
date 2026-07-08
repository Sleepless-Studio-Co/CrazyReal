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
  String get profileUpdated => 'Profile updated';

  @override
  String get profilePhoto => 'Profile photo';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get chooseAvatar => 'Choose an avatar';

  @override
  String get baseAvatars => 'Base avatars';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get removePhoto => 'Remove photo';

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
  String get pleaseLoginFirst => '🔒 Please login first';

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

  @override
  String get register => 'Register';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get pleaseEnterUsername => 'Please enter a username';

  @override
  String get usernameTooShort => 'Username must be at least 3 characters';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get pleaseEnterPassword => 'Please enter a password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get pleaseConfirmPassword => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get alreadyHaveAccount => 'Already have an account? Login';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Register';

  @override
  String get usernameLabel => 'Username: ';

  @override
  String get emailLabel => 'Email: ';

  @override
  String get pleaseLoginOrRegister => 'Please login or register to continue';

  @override
  String get friendRequestAccepted => 'Request accepted!';

  @override
  String get addFriend => 'Add a friend';

  @override
  String get friendUsernameLabel => 'Username';

  @override
  String get friendUsernameHint => 'e.g. johndoe';

  @override
  String get send => 'Send';

  @override
  String friendRequestSent(String username) {
    return 'Request sent to $username!';
  }

  @override
  String get friendRequestError =>
      'Error: User not found or request already exists.';

  @override
  String get searchUsersHint => 'Search by username';

  @override
  String get accountPublic => 'Public';

  @override
  String get accountPrivate => 'Private';

  @override
  String get noUsersFound => 'No user found';

  @override
  String get requestSentShort => 'Sent';

  @override
  String get myFriends => 'My Friends';

  @override
  String get requests => 'Requests';

  @override
  String get noFriendsYet => 'You don\'t have any friends yet.';

  @override
  String get noPendingRequests => 'No pending requests.';

  @override
  String get wantsToBeYourFriend => 'Wants to be your friend';

  @override
  String get rejectRequest => 'Reject';

  @override
  String get friendRequestRejected => 'Request rejected.';

  @override
  String get group => 'Group';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get feedLoadError => 'Could not load the feed.';

  @override
  String get feedRetry => 'Try again';

  @override
  String get feedRefresh => 'Refresh';

  @override
  String get publishFirstPost => 'Publish a photo';

  @override
  String get publishFirstPostHint =>
      'Answer the current challenge to fill your feed.';

  @override
  String get feedJustNow => 'Just now';

  @override
  String timeAgoMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeAgoHours(int hours) {
    return '$hours h ago';
  }

  @override
  String timeAgoDays(int days) {
    return '$days d ago';
  }
}
