import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'CrazyReal'**
  String get appTitle;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Friends tab label
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// New post tab label
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get newPost;

  /// Settings tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Account tab label
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Title for current challenge section
  ///
  /// In en, this message translates to:
  /// **'Current Challenge'**
  String get currentChallenge;

  /// Button to take a photo
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// Button to upload a photo
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// Loading message
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get error;

  /// Success message
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get success;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Profile label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Message shown after profile update
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// Profile photo section title
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// Button to change profile photo
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// Title for avatar picker
  ///
  /// In en, this message translates to:
  /// **'Choose an avatar'**
  String get chooseAvatar;

  /// Label for base avatar options
  ///
  /// In en, this message translates to:
  /// **'Base avatars'**
  String get baseAvatars;

  /// Action to pick a custom photo
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// Action to remove a custom photo
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// Logout button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Login button
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Username field label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Welcome message on home screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to CrazyReal!'**
  String get welcomeMessage;

  /// Message when there are no posts
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// Success message after photo upload
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded successfully!'**
  String get photoUploadSuccess;

  /// Error message when photo upload fails
  ///
  /// In en, this message translates to:
  /// **'Failed to upload photo'**
  String get photoUploadError;

  /// Message when camera permission is needed
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required'**
  String get cameraPermissionRequired;

  /// Button to retry upload
  ///
  /// In en, this message translates to:
  /// **'Retry Upload'**
  String get retryUpload;

  /// Label for language selection
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// French language option
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// Friend page title
  ///
  /// In en, this message translates to:
  /// **'Friend Page'**
  String get friendPage;

  /// Friend page content
  ///
  /// In en, this message translates to:
  /// **'This is the friend page'**
  String get thisFriendPage;

  /// Setting page title
  ///
  /// In en, this message translates to:
  /// **'Setting Page'**
  String get settingPage;

  /// Setting page content
  ///
  /// In en, this message translates to:
  /// **'This is the setting page'**
  String get thisSettingPage;

  /// Account page title
  ///
  /// In en, this message translates to:
  /// **'Account Page'**
  String get accountPage;

  /// Account page content
  ///
  /// In en, this message translates to:
  /// **'This is the account page'**
  String get thisAccountPage;

  /// Loading challenge message
  ///
  /// In en, this message translates to:
  /// **'Loading challenge...'**
  String get loadingChallenge;

  /// Message when only one camera is available
  ///
  /// In en, this message translates to:
  /// **'Only one camera available'**
  String get onlyOneCamera;

  /// Camera not available message
  ///
  /// In en, this message translates to:
  /// **'Camera not available!'**
  String get cameraNotAvailable;

  /// Success message when photo is sent
  ///
  /// In en, this message translates to:
  /// **'Photo sent to your Feed!'**
  String get photoSentToFeed;

  /// Error message when photo send fails
  ///
  /// In en, this message translates to:
  /// **'❌ Error sending photo'**
  String get errorSendingPhoto;

  /// Message asking to login
  ///
  /// In en, this message translates to:
  /// **'🔒 Please login first'**
  String get pleaseLoginFirst;

  /// Message when camera is not available on platform
  ///
  /// In en, this message translates to:
  /// **'📱 Camera available only on iOS/Android'**
  String get cameraOnlyMobile;

  /// Server error message
  ///
  /// In en, this message translates to:
  /// **'Server error: {code}'**
  String serverError(String code);

  /// Connection error message
  ///
  /// In en, this message translates to:
  /// **'Connection error: {error}'**
  String connectionError(String error);

  /// Error loading images message
  ///
  /// In en, this message translates to:
  /// **'Error loading images'**
  String get loadingImagesError;

  /// Register button
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Validation message for username
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get pleaseEnterUsername;

  /// Validation message for short username
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get usernameTooShort;

  /// Validation message for email
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// Validation message for invalid email
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// Validation message for password
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get pleaseEnterPassword;

  /// Validation message for short password
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// Validation message for confirm password
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmPassword;

  /// Validation message for mismatched passwords
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// Link to login from register page
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get alreadyHaveAccount;

  /// Link to register from login page
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get dontHaveAccount;

  /// Label for username in profile
  ///
  /// In en, this message translates to:
  /// **'Username: '**
  String get usernameLabel;

  /// Label for email in profile
  ///
  /// In en, this message translates to:
  /// **'Email: '**
  String get emailLabel;

  /// Message to prompt login or register
  ///
  /// In en, this message translates to:
  /// **'Please login or register to continue'**
  String get pleaseLoginOrRegister;

  /// Message shown when a friend request is accepted
  ///
  /// In en, this message translates to:
  /// **'Request accepted!'**
  String get friendRequestAccepted;

  /// Dialog title to add a friend
  ///
  /// In en, this message translates to:
  /// **'Add a friend'**
  String get addFriend;

  /// Username field label in add friend dialog
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get friendUsernameLabel;

  /// Username field hint in add friend dialog
  ///
  /// In en, this message translates to:
  /// **'e.g. johndoe'**
  String get friendUsernameHint;

  /// Button to send an action
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Message shown when a friend request is sent
  ///
  /// In en, this message translates to:
  /// **'Request sent to {username}!'**
  String friendRequestSent(String username);

  /// Error message for an invalid friend request
  ///
  /// In en, this message translates to:
  /// **'Error: User not found or request already exists.'**
  String get friendRequestError;

  /// Hint in the add-friend search field
  ///
  /// In en, this message translates to:
  /// **'Search by username'**
  String get searchUsersHint;

  /// Badge for a public account
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get accountPublic;

  /// Badge for a private account
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get accountPrivate;

  /// Shown when a username search returns nothing
  ///
  /// In en, this message translates to:
  /// **'No user found'**
  String get noUsersFound;

  /// Short label shown after a friend request was sent
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get requestSentShort;

  /// Title and tab label for friend list
  ///
  /// In en, this message translates to:
  /// **'My Friends'**
  String get myFriends;

  /// Tab label for friend requests
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// Message shown when friend list is empty
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any friends yet.'**
  String get noFriendsYet;

  /// Message shown when there are no pending requests
  ///
  /// In en, this message translates to:
  /// **'No pending requests.'**
  String get noPendingRequests;

  /// Subtitle displayed for incoming friend requests
  ///
  /// In en, this message translates to:
  /// **'Wants to be your friend'**
  String get wantsToBeYourFriend;

  /// Button to reject an incoming friend request
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectRequest;

  /// Message shown when a friend request is rejected
  ///
  /// In en, this message translates to:
  /// **'Request rejected.'**
  String get friendRequestRejected;

  /// Label for the floating action button to create a group
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// Displayed when username is missing
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get unknownUser;

  /// Feed error message
  ///
  /// In en, this message translates to:
  /// **'Could not load the feed.'**
  String get feedLoadError;

  /// Button to reload the feed
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get feedRetry;

  /// Feed refresh button tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get feedRefresh;

  /// CTA button when feed is empty
  ///
  /// In en, this message translates to:
  /// **'Publish a photo'**
  String get publishFirstPost;

  /// Subtitle when feed is empty
  ///
  /// In en, this message translates to:
  /// **'Answer the current challenge to fill your feed.'**
  String get publishFirstPostHint;

  /// Relative time for a very recent post
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get feedJustNow;

  /// Relative time in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String timeAgoMinutes(int minutes);

  /// Relative time in hours
  ///
  /// In en, this message translates to:
  /// **'{hours} h ago'**
  String timeAgoHours(int hours);

  /// Relative time in days
  ///
  /// In en, this message translates to:
  /// **'{days} d ago'**
  String timeAgoDays(int days);

  /// Delete account button
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// Confirm delete account dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmTitle;

  /// Confirm delete account dialog body
  ///
  /// In en, this message translates to:
  /// **'All your data will be permanently deleted. This cannot be undone.'**
  String get deleteAccountConfirmBody;

  /// Privacy settings section header
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// Blocked users setting tile
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// Permissions settings section header
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// Info shown when user taps a permission tile
  ///
  /// In en, this message translates to:
  /// **'To manage microphone, camera and location access for CrazyReal, go to your phone Settings > CrazyReal.'**
  String get permissionsInfo;

  /// Accessibility settings section header
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// Language setting tile
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Help section header and tile
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpCenter;

  /// Help dialog body
  ///
  /// In en, this message translates to:
  /// **'For any help or feedback, contact us at support@crazyreal.app'**
  String get helpInfo;

  /// Private account label
  ///
  /// In en, this message translates to:
  /// **'Private account'**
  String get privateAccount;

  /// Public account label
  ///
  /// In en, this message translates to:
  /// **'Public account'**
  String get publicAccount;

  /// Private account description
  ///
  /// In en, this message translates to:
  /// **'Only accepted friends see your profile and challenges.'**
  String get privateAccountDesc;

  /// Public account description
  ///
  /// In en, this message translates to:
  /// **'Everyone can see your profile and challenges.'**
  String get publicAccountDesc;

  /// Coming soon message for unimplemented features
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
