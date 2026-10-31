// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zaine';

  @override
  String get signInButtonCheckedIn => 'Checked in today';

  @override
  String get signInButtonTapToCheckIn => 'Tap to check in';

  @override
  String continuousDays(int count) {
    return '$count-day streak';
  }

  @override
  String get s003 =>
      'Please allow notification permission in system settings to receive check-in reminders';

  @override
  String get s004 => 'Missed check-in alerts';

  @override
  String get s005 => 'Escalating reminders for consecutive missed check-ins';

  @override
  String get s006 => 'You haven\'t checked in today';

  @override
  String get s007 =>
      'Take 3 seconds to open Zaine and check in, so your guardian knows you\'re safe 💙';

  @override
  String get s008 => 'You\'ve missed 2 days in a row';

  @override
  String get s009 =>
      'Your guardian might be a little worried—let them know you\'re safe 🏠';

  @override
  String get s011 =>
      'Take 3 seconds to open Zaine and check in today—give yourself peace of mind ❤️';

  @override
  String get s012 =>
      'System reminders are on. An extra reminder will be sent if you miss your check-in for the day';

  @override
  String get s013 => 'Unknown';

  @override
  String get s014 => 'Sign out';

  @override
  String get s015 =>
      'After signing out, local data will be cleared and you\'ll return to the sign-in page. Next time you\'ll need to sign in again with your phone number.\n\nAre you sure you want to sign out?';

  @override
  String get s016 => 'Cancel';

  @override
  String get s017 => 'Sign out';

  @override
  String get s018 => 'Signed out';

  @override
  String get s019 => 'Choose theme';

  @override
  String get s020 => 'Light mode';

  @override
  String get s021 => 'Fresh and bright, soft warm white';

  @override
  String get s022 => 'Dark mode';

  @override
  String get s023 => 'Eye-friendly for night use, deep and calm';

  @override
  String get s024 => 'Soft light mode';

  @override
  String get s025 => 'Warm off-white, cozy and soft';

  @override
  String get s026 => 'Unable to open the privacy policy page';

  @override
  String get s027 => 'Delete account';

  @override
  String get s028 =>
      'This action will permanently delete your account and all data:';

  @override
  String get s029 => '• Profile and health records';

  @override
  String get s030 => '• Check-in records and guardian cards';

  @override
  String get s031 => '• Emergency contact list';

  @override
  String get s032 => '• Membership subscription records';

  @override
  String get s033 => 'This action cannot be undone!';

  @override
  String get s034 => 'Confirm deletion';

  @override
  String get s035 => 'Final confirmation';

  @override
  String get s036 => 'Please type \"删除\" to confirm account deletion:';

  @override
  String get s037 => 'Enter \"删除\"';

  @override
  String get s038 => 'Delete';

  @override
  String get s039 => 'Permanently delete';

  @override
  String get s040 => 'Account deleted';

  @override
  String get s041 =>
      'Your account and all data have been permanently deleted. The app will exit; please reopen it.';

  @override
  String get s042 => 'OK';

  @override
  String get s043 => 'Deletion failed';

  @override
  String get s045 => 'Watch over every check-in, every loved one who cares.';

  @override
  String get s046 =>
      'Zaine is a guardian app designed for young people living alone in the city. Check in daily to let others know you\'re safe, and call for help with one tap in an emergency—so the people who care about you can feel at ease.';

  @override
  String get s047 => 'Check for updates';

  @override
  String get s048 => 'Close';

  @override
  String get s050 => 'You\'re on the latest version!';

  @override
  String get s051 => 'Thank you for using Zaine ❤️';

  @override
  String get s052 => 'OK';

  @override
  String get s053 => 'Dark';

  @override
  String get s054 => 'Soft light';

  @override
  String get s055 => 'Light';

  @override
  String get s056 => 'Settings';

  @override
  String get s057 => 'Zaine user';

  @override
  String get s058 => 'Health profile complete';

  @override
  String get s059 => 'Please complete your health profile';

  @override
  String get s060 =>
      'Unlock the full help feature after completing your profile';

  @override
  String get s061 => 'Fill in';

  @override
  String get s062 => 'Appearance';

  @override
  String get s063 => 'Theme mode';

  @override
  String get s065 => 'Check-in reminder';

  @override
  String get s066 => 'Daily reminder';

  @override
  String get s067 => 'Reminds you to check in daily';

  @override
  String get s068 => 'Reminder time';

  @override
  String get s069 => 'System reminder';

  @override
  String get s070 =>
      'If you miss your check-in for the day, the system will send an extra reminder';

  @override
  String get s071 => 'Help settings';

  @override
  String s072(Object num) {
    return 'Emergency call $num';
  }

  @override
  String get s073 => 'Please go to the help page to use this feature';

  @override
  String get s074 => 'Membership';

  @override
  String get s075 => 'Zaine Smart';

  @override
  String get s076 => 'Unlock more guardian features';

  @override
  String get s077 => 'Subscribed';

  @override
  String get s078 => 'Upgrade';

  @override
  String get s079 => 'Account';

  @override
  String get s080 => 'Permanently delete all data, cannot be undone';

  @override
  String get s081 => 'Privacy & data';

  @override
  String get s082 => 'Privacy policy';

  @override
  String get s083 => 'Data security';

  @override
  String get s084 => 'Cloud-synced storage—never lost when switching devices';

  @override
  String get s085 => 'Data security assurance';

  @override
  String get s086 =>
      'Your health profile, emergency contacts, and check-in records are all encrypted and synced to cloud servers. After signing in on a new device, your data is automatically restored.\n\nWe promise:\n• Industry-standard encryption protects data transmission and storage\n• Your information will never be used for commercial purposes\n• We will never disclose your privacy to third parties\n• You can delete all data anytime in the health profile page or settings';

  @override
  String get s087 => 'Got it';

  @override
  String get s088 => 'Storage management';

  @override
  String get s089 => 'Clear cache';

  @override
  String get s090 => 'Clean up temporary files and image cache';

  @override
  String get s091 => 'Reset all data';

  @override
  String get s092 => 'Clear all local data (check-ins, profiles, contacts)';

  @override
  String get s093 => 'About';

  @override
  String get s094 => 'About Zaine';

  @override
  String get s095 => 'Version';

  @override
  String get s096 => 'Developer mode ✅';

  @override
  String get s098 => 'Give peace of mind to those who care about you';

  @override
  String get s099 =>
      'This will clear image cache and temporary files, and won\'t affect your check-in data or health profile.';

  @override
  String get s100 => 'Clear';

  @override
  String get s101 => 'Cache cleared ✓';

  @override
  String get s102 => '⚠️ Dangerous operation';

  @override
  String get s103 =>
      'This action will permanently delete all of the following data:';

  @override
  String get s104 => '• Check-in records and streak days';

  @override
  String get s105 => '• Health profile information';

  @override
  String get s106 => '• Sign-in status';

  @override
  String get s107 => '• Theme preferences';

  @override
  String get s108 =>
      'Note: Only local data is cleared. Cloud account and server data are unaffected.';

  @override
  String get s109 =>
      'To permanently delete your cloud account and all data, use \"Delete account\" below.';

  @override
  String get s110 => 'Confirm reset';

  @override
  String get s111 => 'All data has been reset ✓ The app will restart...';

  @override
  String get s113 => '🔒 Final confirmation';

  @override
  String get s114 => 'Please type \"重置\" to confirm deleting all data:';

  @override
  String get s115 => 'Enter \"重置\"';

  @override
  String get s116 => 'Reset';

  @override
  String s125(Object? p1) {
    return 'Daily check-in reminder set for $p1';
  }

  @override
  String s126(Object? p1) {
    return 'Check-in reminder is on, every day at $p1';
  }

  @override
  String s127(Object? daysSinceLastCheckIn) {
    return '[Reminder] You\'ve missed $daysSinceLastCheckIn days of check-ins';
  }

  @override
  String s128(Object? e) {
    return 'Deletion failed: $e';
  }

  @override
  String s129(Object? p1, Object? p2) {
    return 'Current version v$p1 (Build $p2)';
  }

  @override
  String s130(Object? p1) {
    return 'Current: $p1';
  }

  @override
  String s131(Object? p1) {
    return 'Tap $p1 more times to activate';
  }

  @override
  String s132(Object? e) {
    return 'Reset failed: $e';
  }

  @override
  String get s133 => '💓 Your watch detected you and checked you in';

  @override
  String get s134 => '⌚ Apple Watch check-in successful';

  @override
  String get s135 => 'Check-in successful';

  @override
  String s136(Object? streak) {
    return 'Peace of mind · $streak-day streak';
  }

  @override
  String s137(Object? streak, Object? total) {
    return '🔥 $streak-day streak · $total days total';
  }

  @override
  String get s138 => 'Your friend';

  @override
  String get s139 => 'Wants to set up a guardian relationship with you';

  @override
  String get s140 => 'Safe confirmed ❤️';

  @override
  String s141(Object? _entryTag, Object? _isLoggedIn, Object? _checkedInToday) {
    return '$_entryTag entry _isLoggedIn=$_isLoggedIn _checkedInToday=$_checkedInToday';
  }

  @override
  String s142(Object? _isLoggedIn, Object? _checkedInToday) {
    return 'Entry _isLoggedIn=$_isLoggedIn _checkedInToday=$_checkedInToday';
  }

  @override
  String get s143 => 'Please sign in before checking in';

  @override
  String get s144 => 'No user_id';

  @override
  String get s145 => 'No token';

  @override
  String s146(Object? e) {
    return 'Decoding error: $e';
  }

  @override
  String s147(Object? p1, Object? _tokenUid) {
    return 'Before check-in uid(local)=$p1 tokenUid(backend will recognize)=$_tokenUid';
  }

  @override
  String s148(Object? today, Object? uid) {
    return 'Calling do_checkin date=$today uid=$uid';
  }

  @override
  String s149(Object? res) {
    return 'do_checkin response: $res';
  }

  @override
  String s150(Object? res) {
    return 'do_checkin success res=$res';
  }

  @override
  String get s151 => '☀️ Check-in synced';

  @override
  String s152(Object? errorMsg) {
    return 'Business error: $errorMsg';
  }

  @override
  String get s153 => '☀️ Checked in today';

  @override
  String s154(Object? errorMsg) {
    return 'Check-in recorded, cloud sync failed: $errorMsg';
  }

  @override
  String s155(Object? e) {
    return 'Exception: $e';
  }

  @override
  String get s156 =>
      'Check-in recorded and saved to offline queue; will auto-sync when connected ☁️';

  @override
  String get s157 => 'Please complete your information first';

  @override
  String get s158 =>
      'Before using the emergency help feature, please fill in your health profile and emergency contact information.\n\nThis ensures rescuers can access your key health information in an emergency.';

  @override
  String get s159 => 'Later';

  @override
  String get s160 => 'Upgrade to Smart';

  @override
  String get s161 => 'Unlock all features';

  @override
  String s162(Object? p1, Object? p2) {
    return '$p1/$p2';
  }

  @override
  String s163(Object? monthCheckInCount, Object? daysInMonth) {
    return '$monthCheckInCount/$daysInMonth days checked in';
  }

  @override
  String get s164 => 'Today';

  @override
  String get s165 => 'This month';

  @override
  String get s166 => 'Mon';

  @override
  String get s167 => 'Tue';

  @override
  String get s168 => 'Wed';

  @override
  String get s169 => 'Thu';

  @override
  String get s170 => 'Fri';

  @override
  String get s171 => 'Sat';

  @override
  String get s172 => 'Sun';

  @override
  String get s173 => 'Less';

  @override
  String get s174 => '  More';

  @override
  String s175(Object? dateStr, Object? p1) {
    return '$dateStr $p1';
  }

  @override
  String get s176 => 'Select month';

  @override
  String s177(Object? selectedYear) {
    return '$selectedYear';
  }

  @override
  String s178(Object? month) {
    return '$month';
  }

  @override
  String get s179 => 'Male';

  @override
  String get s180 => 'Type A';

  @override
  String get s181 => 'Type B';

  @override
  String get s182 => 'Type O';

  @override
  String get s183 => 'Type AB';

  @override
  String get s184 => 'Other';

  @override
  String get s185 => 'Avatar save failed, please try again';

  @override
  String get s186 => 'Avatar synced to cloud ✓';

  @override
  String get s187 => 'Avatar sync failed, please try again later';

  @override
  String s188(Object? e) {
    return 'Avatar save failed: $e';
  }

  @override
  String get s189 => 'Health profile saved successfully!';

  @override
  String get s190 =>
      'Saved locally, cloud sync failed. Please check your network';

  @override
  String get s191 => 'Theme settings';

  @override
  String get s192 => 'Feedback';

  @override
  String get s193 =>
      'Your feedback is very important to us, and we\'ll handle it as soon as possible.';

  @override
  String get s194 =>
      'Please describe the issue or suggestion you encountered...';

  @override
  String get s195 => 'Thank you for your feedback, we\'ll handle it soon! ✓';

  @override
  String get s196 => 'Submit feedback';

  @override
  String get s197 => 'No feedback records yet';

  @override
  String s198(Object? p1) {
    return 'User feedback ($p1)';
  }

  @override
  String get s199 => 'Confirm clearing';

  @override
  String get s200 =>
      'Are you sure you want to delete all feedback records? This action cannot be undone.';

  @override
  String get s201 => 'Feedback records cleared';

  @override
  String get s202 => 'Clear all';

  @override
  String get s203 => 'Unknown time';

  @override
  String get s204 => 'Guardian relationship';

  @override
  String get s205 => 'Enter guardian code';

  @override
  String get s206 =>
      'Manually enter a safety code to accept someone\'s guardian card';

  @override
  String get s207 => 'Developer mode';

  @override
  String get s208 => 'Not signed in';

  @override
  String get s209 => 'USER-ID copied to clipboard';

  @override
  String get s210 => 'Copy';

  @override
  String get s211 => 'None';

  @override
  String get s212 => 'Check-in simulator';

  @override
  String get s213 =>
      'Set consecutive check-in days to test badges and milestone pop-ups';

  @override
  String get s214 => 'Reset guardian cards';

  @override
  String get s215 =>
      'Restore to the initial 3-card state for testing the full card-issuing flow';

  @override
  String get s216 => 'Show onboarding again';

  @override
  String get s217 => 'Show the startup guide again on next app launch';

  @override
  String get s218 => 'Set. The guide will show on next launch ✓';

  @override
  String get s219 => 'Reset onboarding tasks';

  @override
  String get s220 =>
      'Clear onboarding task completion status to re-experience the 5-step guide';

  @override
  String get s221 =>
      'Onboarding tasks reset. Return to home to re-experience ✓';

  @override
  String get s222 => 'Switch membership level';

  @override
  String get s223 => 'Trial ↔ Smart—test membership benefit differences';

  @override
  String get s224 => 'Simulate membership expiration downgrade';

  @override
  String get s225 => 'Smart → Trial: contacts retained but locked';

  @override
  String get s226 => 'View user feedback';

  @override
  String get s227 => 'View all submitted feedback';

  @override
  String get s228 => 'Health profile';

  @override
  String get s229 => 'Tap avatar to set';

  @override
  String get s230 => 'Tap avatar to change photo';

  @override
  String get s231 => 'Profile complete';

  @override
  String get s232 => 'Please complete your health profile';

  @override
  String get s233 => 'Help feature unlocked. Protect yourself starting now';

  @override
  String get s234 => 'Emergency help needs your health information';

  @override
  String get s235 => 'Safety center';

  @override
  String get s236 =>
      'Scheduled safety check · Location sharing · Fall detection';

  @override
  String get s237 => 'Statistics';

  @override
  String get s238 => 'Check-in calendar · Health trends · Menstrual cycle';

  @override
  String get s239 => 'My achievements';

  @override
  String get s240 => 'Check-in streak · Care · Milestones';

  @override
  String get s241 => 'Medical ID ✓ Set';

  @override
  String get s242 => 'Medical ID';

  @override
  String get s243 => 'iOS native';

  @override
  String get s244 => 'Viewable from lock screen · No need to unlock phone';

  @override
  String get s245 => 'Medical ID setup guide';

  @override
  String get s246 => 'What is a Medical ID?';

  @override
  String get s247 =>
      'Medical ID is an iPhone system-level feature. From the lock screen, anyone can view your emergency medical information without unlocking your phone.';

  @override
  String get s248 => 'Setup steps (4 total)';

  @override
  String get s249 => 'Open the Health app';

  @override
  String get s250 =>
      'Find and open the Health app on your iPhone (green heart icon)';

  @override
  String get s251 => 'Tap the avatar in the top-right corner';

  @override
  String get s252 =>
      'On the Summary page, tap the top-right avatar to enter your profile';

  @override
  String get s253 => 'Select \"Medical ID\"';

  @override
  String get s254 =>
      'Scroll down, find the \"Medical ID\" option, and tap to enter';

  @override
  String get s255 => 'Fill in and save';

  @override
  String get s256 =>
      'Fill in name, blood type, allergy info, emergency contacts, etc. Then tap \"Done\"';

  @override
  String get s257 =>
      'Tip: After setup, on the lock screen tap \"Emergency\" → \"Medical ID\" to view';

  @override
  String get s258 => 'I\'ve completed the setup';

  @override
  String get s259 =>
      'Please manually open the Health app on your iPhone to set up';

  @override
  String s260(Object? e) {
    return 'Unable to open the Health app; please search manually: $e';
  }

  @override
  String get s261 => 'Set up in Health app';

  @override
  String get s262 =>
      'Please manually open the Health app on your iPhone to edit';

  @override
  String s263(Object? e) {
    return 'Unable to open the Health app: $e';
  }

  @override
  String get s264 => 'Edit in Health app';

  @override
  String get s265 => 'Confirm setup complete';

  @override
  String get s266 =>
      'Are you sure you\'ve completed filling in and saving your Medical ID in the iPhone Health app?';

  @override
  String get s267 =>
      'After setup, your info can be viewed from the lock screen via \"Emergency\" → \"Medical ID\"';

  @override
  String get s268 => 'Check again';

  @override
  String get s269 => '✅ Medical ID marked as complete!';

  @override
  String get s270 => '✅ Confirm completed';

  @override
  String get s271 => 'Theme color';

  @override
  String get s272 => 'Safety code';

  @override
  String get s273 => 'Bind guardian card';

  @override
  String get s274 => 'Tell us';

  @override
  String get s275 => 'Basic info';

  @override
  String get s276 => 'Required';

  @override
  String get s277 => 'Name';

  @override
  String get s278 => 'Please enter your name';

  @override
  String get s279 => 'Please enter name';

  @override
  String get s280 => 'Age';

  @override
  String get s281 => 'Please enter age';

  @override
  String get s282 => 'Please enter a valid age';

  @override
  String get s283 => 'Gender';

  @override
  String get s284 => 'Female';

  @override
  String get s285 => 'Allergy history';

  @override
  String get s286 =>
      'e.g., penicillin, mango, seafood (enter \"None\" if none)';

  @override
  String get s287 => 'Please fill in your allergies';

  @override
  String get s288 => 'Health Information';

  @override
  String get s289 => 'Optional';

  @override
  String get s290 => 'Medical History';

  @override
  String get s291 => 'e.g., hypertension, diabetes, etc.';

  @override
  String get s292 => 'Medications in Use';

  @override
  String get s293 => 'e.g., antihypertensive drugs, insulin, etc.';

  @override
  String get s294 => 'Emergency Notes';

  @override
  String get s295 => 'Information rescuers need to know';

  @override
  String get s296 => 'Update Profile';

  @override
  String get s297 => 'Save and Enable SOS';

  @override
  String get s298 =>
      'Your health profile and emergency contact information is encrypted and synced to the cloud, so your data won\'t be lost when you switch devices. We strictly protect your privacy and security.';

  @override
  String get s299 => 'Family';

  @override
  String get s300 => 'Friends';

  @override
  String get s301 => 'Colleagues';

  @override
  String get s302 => 'Parents';

  @override
  String get s303 => 'Spouse';

  @override
  String get s304 => 'Children';

  @override
  String get s305 => 'Guardian';

  @override
  String get s306 => 'Custom...';

  @override
  String get s307 => 'Siblings';

  @override
  String s308(Object? maxContacts) {
    return 'Smart plan allows up to $maxContacts contacts';
  }

  @override
  String get s309 => 'Contact limit reached';

  @override
  String s310(Object? maxContacts) {
    return 'Free plan allows up to $maxContacts emergency contacts.';
  }

  @override
  String get s311 => 'Upgrade to Smart plan, you\'ll get:';

  @override
  String s312(Object? p1) {
    return 'Emergency contacts 5 → $p1';
  }

  @override
  String s313(Object? p1) {
    return 'Quick emergency call 1 → $p1';
  }

  @override
  String s314(Object? p1) {
    return 'Quick emergency SMS 1 → $p1';
  }

  @override
  String get s315 => 'Maybe Later';

  @override
  String get s316 => 'Upgrade Now';

  @override
  String s317(Object? contactName) {
    return '$contactName added as your guardian';
  }

  @override
  String get s318 => 'Upgrade to Smart plan to add more contacts';

  @override
  String get s319 => 'Upgrade';

  @override
  String get s320 => 'Me';

  @override
  String s321(Object? p1, Object? senderName, Object? p2) {
    return '【在呢】Hi $p1! I\'m $senderName, and I\'ve just added you as my emergency contact 🛡️\n\nI use the \"在呢\" app to keep myself safe—checking in daily to report I\'m safe, and with one tap for help in an emergency, so I can share my real-time location with you after you confirm.\n\nIf you download \"在呢\" too, we can watch over each other and both feel more at ease. ❤️\n\nTap the link to accept the invitation: $p2';
  }

  @override
  String get s322 => 'Send Invitation SMS';

  @override
  String s323(Object? name) {
    return 'Set $name as your emergency contact.';
  }

  @override
  String get s324 => 'Edit SMS content (nicknames optional)';

  @override
  String get s325 => 'Your Nickname';

  @override
  String get s326 => 'Who you appear as when sending SMS';

  @override
  String get s327 => 'Recipient\'s Name';

  @override
  String get s328 => 'What you\'d like to call them';

  @override
  String get s329 => 'SMS preview:';

  @override
  String s330(Object? recipientDisplayName, Object? finalSender,
      Object? inviteShortUrl) {
    return '【在呢】Hi $recipientDisplayName! I\'m $finalSender, and I\'ve just added you as my emergency contact 🛡️\n\nKnowing you\'re there gives me peace of mind. I check in safely every day on \"在呢\", and I\'ll notify you in an emergency.\n\nWant to see the guardian app I use? Tap here:\n$inviteShortUrl';
  }

  @override
  String get s331 => 'Send SMS';

  @override
  String s332(Object? p1) {
    return 'Invitation to $p1 is ready in your SMS app';
  }

  @override
  String get s333 => 'Cannot open SMS app. Please check your system settings';

  @override
  String s334(Object? e) {
    return 'Failed to send SMS: $e';
  }

  @override
  String get s335 => 'Temporary';

  @override
  String s336(Object? p1) {
    return 'Save failed: $p1';
  }

  @override
  String get s337 => 'View Logs';

  @override
  String s338(Object? e) {
    return 'Save error: $e';
  }

  @override
  String get s339 => 'Delete Contact';

  @override
  String s340(Object? p1) {
    return 'Are you sure you want to delete $p1?';
  }

  @override
  String get s341 => '👑 Priority';

  @override
  String get s342 => 'Seven';

  @override
  String get s343 => 'Eight';

  @override
  String get s344 => 'Nine';

  @override
  String get s345 => 'Ten';

  @override
  String get s346 => 'Emergency Contact';

  @override
  String get s347 => 'Add Contact';

  @override
  String get s348 =>
      'Calls go in priority order during an SOS. Drag the ☰ on the left to reorder';

  @override
  String get s349 =>
      'First contact = primary emergency contact (highest priority)';

  @override
  String get s350 => 'Edit Emergency Contact';

  @override
  String get s351 => 'Add Emergency Contact';

  @override
  String get s352 =>
      'Changes are saved automatically and update the priority order';

  @override
  String get s353 => 'Calls go in priority order during an SOS';

  @override
  String get s354 => 'Please enter the contact\'s name';

  @override
  String get s355 => 'Phone Number';

  @override
  String get s356 => 'Please enter an 11-digit phone number';

  @override
  String get s357 => 'Please enter a phone number';

  @override
  String get s358 => 'Please enter a valid phone number';

  @override
  String get s359 => 'Relationship';

  @override
  String get s360 => 'Please select a relationship';

  @override
  String get s361 => 'Please enter a custom relationship';

  @override
  String get s362 => 'e.g., senior, neighbor, roommate';

  @override
  String get s363 => 'Save Changes';

  @override
  String get s364 => 'Edit Nickname';

  @override
  String get s365 => 'Enter the name shown in \"People I Guard\"';

  @override
  String get s366 => 'Save';

  @override
  String get s367 => 'People I Guard';

  @override
  String get s369 => 'Pending Activation';

  @override
  String get s370 => 'No check-in today';

  @override
  String get s371 => 'Re-invite';

  @override
  String get s372 => 'Not Detected Yet';

  @override
  String get s373 => 'Unnamed';

  @override
  String get s374 => 'Guardian';

  @override
  String get s379 => 'Network Error';

  @override
  String get s380 => 'Query Failed';

  @override
  String get s384 => 'Not Registered';

  @override
  String get s386 => 'Failed to create free guardian card';

  @override
  String get s387 => 'Network error. Please try again later';

  @override
  String get s388 => 'Unable to generate your exclusive invitation link';

  @override
  String get s390 =>
      'SMS is open and the full link has been copied. If they don\'t receive it, long-press to paste and resend';

  @override
  String get s392 => 'Reminder Failed';

  @override
  String get s394 => 'My Guardian Circle';

  @override
  String get s396 => 'No Guardians Yet';

  @override
  String get s399 => 'Syncing guardian circle status…';

  @override
  String get s400 => 'Emergency contacts automatically become your guardians';

  @override
  String get s401 => 'Add emergency contacts so they can guard you';

  @override
  String get s402 => 'Messages';

  @override
  String get s403 => 'Emoji';

  @override
  String get s404 => 'Achievements';

  @override
  String get s405 => '💌 Send Guardian Card';

  @override
  String get s406 => 'Invite someone you care about so they\'re protected too';

  @override
  String get s408 => 'Guardian Streak';

  @override
  String get s409 => 'Checked In';

  @override
  String get s410 => 'Not Checked In';

  @override
  String get s411 => 'Today\'s Status';

  @override
  String get s413 => 'Total Check-ins';

  @override
  String get s414 => 'No Guardians Yet';

  @override
  String get s415 =>
      'Add emergency contacts\nso they can become your guardians';

  @override
  String get s416 => 'Add Guardian';

  @override
  String get s417 => 'Quick Actions';

  @override
  String get s418 => 'Emergency Contact Management';

  @override
  String get s419 => 'Add, edit, and reorder your guardians (up to 10)';

  @override
  String get s420 => 'View and edit the guardian cards you\'ve sent';

  @override
  String get s422 => 'Safety Confirmation';

  @override
  String get s423 => 'Let your guardians know you\'re safe';

  @override
  String get s424 => 'What is a Guardian Circle';

  @override
  String get s425 => 'Learn how the guardian circle works';

  @override
  String get s426 => 'You · Today\'s check-in';

  @override
  String get s427 => 'You\'ve completed today\'s check-in. All is well';

  @override
  String get s429 => 'Your guardian has reported safe';

  @override
  String get s430 => 'Just now';

  @override
  String get s432 => 'Circle Activity';

  @override
  String get s433 => 'It\'s quiet in the circle today';

  @override
  String get s434 =>
      'Check in or report safe so your guardian circle can see you';

  @override
  String get s435 => 'Enable Vital Signs Guard';

  @override
  String get s436 => 'Sync Apple Watch heart rate, blood oxygen, and sleep';

  @override
  String get s438 => 'Guard ready · Collecting data';

  @override
  String get s439 => 'Vital signs guard enabled, syncing Apple Watch data';

  @override
  String get s440 => 'Heart Rate';

  @override
  String get s441 => 'Blood Oxygen';

  @override
  String get s442 => 'Sleep';

  @override
  String get s443 => 'Tap to view full vital signs';

  @override
  String get s444 => 'Auto-guarding · Tap to view full vital signs';

  @override
  String get s445 => 'Auto-guard off · Tap to view full vital signs';

  @override
  String get s446 => 'Synced just now';

  @override
  String get s449 => 'Guarding';

  @override
  String get s450 => 'Guardian cards I sent · Mutual guardians (no limit)';

  @override
  String get s451 => 'No one guarded yet';

  @override
  String get s452 =>
      'Send a guardian card, and they\'ll appear in the list once they sign up';

  @override
  String get s454 => 'Mutual Guardians';

  @override
  String get s455 => 'Call';

  @override
  String get s456 => 'Safe';

  @override
  String get s457 => 'Reminder';

  @override
  String get s458 => 'Invite';

  @override
  String get s459 => 'Request Safety Confirmation';

  @override
  String get s460 => 'Remind to Download';

  @override
  String get s461 => 'Invite to Sign Up';

  @override
  String get s462 => 'This guardian hasn\'t set a phone number';

  @override
  String get s465 => 'Call';

  @override
  String get s466 => 'Cannot open the dialer. Please call manually';

  @override
  String get s470 => 'Send Request';

  @override
  String get s471 =>
      'This guardian hasn\'t linked a phone number, so a safety confirmation can\'t be sent';

  @override
  String get s473 =>
      'Network request failed. Please check your connection and retry';

  @override
  String get s476 => 'End Guardianship';

  @override
  String get s479 => 'End Guardianship';

  @override
  String get s480 => 'No record found for this contact';

  @override
  String get s482 => 'Failed to End';

  @override
  String get s484 => 'Your guardian circle is your personal safety network.';

  @override
  String get s485 => '🛡️ Add trusted family and friends as guardians';

  @override
  String get s486 =>
      '🔔 Your daily check-in status is visible to your guardians';

  @override
  String get s487 =>
      '🆘 Guardians are notified immediately when an SOS is triggered';

  @override
  String get s488 => '❤️ Give peace of mind to those who care about you';

  @override
  String get s489 => 'Got it';

  @override
  String get s490 =>
      'Send a safety message to your guardians so they know you\'re doing well.\n\n\"I\'m fine, don\'t worry ❤️\"';

  @override
  String get s491 => 'Send Confirmation';

  @override
  String get s492 =>
      'No guardians added yet. Please add an emergency contact first';

  @override
  String get s493 => 'Guardian info is invalid. Please re-add the contact';

  @override
  String get s495 => 'You · Report safe';

  @override
  String get s498 => 'Cannot open SMS. Please send the safety message manually';

  @override
  String s540(Object? p1) {
    return '$p1';
  }

  @override
  String s541(Object? ph, Object? ci, Object? av, Object? p1, Object? p2) {
    return '$ph:check-in=$ci,avatar=$av,lastSignin=$p1,isActive=$p2; ';
  }

  @override
  String s542(Object? p1, Object? sb) {
    return 'batchLookup RAW_RESULTS_KEYS=$p1 | guardian: $sb';
  }

  @override
  String s543(Object? e) {
    return 'dump error: $e';
  }

  @override
  String s544(Object? e) {
    return 'batchLookup exception (fallback): $e';
  }

  @override
  String s545(Object? ts) {
    return 'Not connected (tap to enable Vital Signs Guard · $ts)';
  }

  @override
  String s546(Object? hr, Object? bo, Object? ts) {
    return 'Connected (HR $hr/SpO₂ $bo · $ts)';
  }

  @override
  String s547(Object? ts) {
    return 'Connected · Syncing data ($ts)';
  }

  @override
  String s548(Object? p1) {
    return 'Checked in today $p1';
  }

  @override
  String s549(Object? safeName, Object? landingUrl) {
    return '【在呢】$safeName invites you to guard together 🛡️ I use the \"在呢\" app to check in safely every day, so I feel safe even when alone.\nTap the link to sign up, and we can guard each other:\n$landingUrl';
  }

  @override
  String s550(Object? name) {
    return 'Reminded $name to download and check in ✅';
  }

  @override
  String s551(Object? e) {
    return 'Failed to send reminder: $e';
  }

  @override
  String s552(Object? p1) {
    return '$p1 guardians';
  }

  @override
  String s553(Object? p1) {
    return 'Guarding $p1 friends';
  }

  @override
  String s554(Object? p1) {
    return '$p1 mutual guardians';
  }

  @override
  String s555(Object? p1) {
    return '$p1 days';
  }

  @override
  String s556(Object? p1) {
    return '$p1 days';
  }

  @override
  String s557(Object? p1) {
    return 'Manage $p1 people you guard';
  }

  @override
  String s558(Object? name) {
    return '$name checked in today';
  }

  @override
  String s559(Object? p1) {
    return '$p1 min ago';
  }

  @override
  String s560(Object? _healthAuthDiag) {
    return 'Diagnosis: $_healthAuthDiag';
  }

  @override
  String s561(Object? diffMin) {
    return 'Synced $diffMin min ago';
  }

  @override
  String s562(Object? diffH) {
    return 'Synced $diffH hr ago';
  }

  @override
  String s563(Object? boundAt) {
    return '· Bound $boundAt';
  }

  @override
  String s564(Object? name) {
    return 'Call $name';
  }

  @override
  String s565(Object? p1) {
    return 'Calling: $p1\n\nThe dialer will open after you tap confirm.';
  }

  @override
  String s566(Object? e) {
    return 'Call failed: $e';
  }

  @override
  String s567(Object? name) {
    return 'Send a safety confirmation request to $name';
  }

  @override
  String s568(Object? name) {
    return 'A safety confirmation request will be sent to $name.\nOnce they open the 在呢 app, they can tap \"Safe\" to confirm.\n\nContinue?';
  }

  @override
  String s569(Object? name) {
    return '$name hasn\'t signed up for 在呢 yet, so a safety confirmation can\'t be sent';
  }

  @override
  String s570(Object? name) {
    return 'Safety confirmation request sent to $name';
  }

  @override
  String s571(Object? p1) {
    return 'Send failed: $p1';
  }

  @override
  String s572(Object? name, Object? phone) {
    return 'End your guardianship with $name ($phone)?\n\nAfter ending it, they\'ll no longer receive your SOS notifications, and you won\'t see their check-in status either.';
  }

  @override
  String s573(Object? name, Object? phone) {
    return 'Remove $name ($phone) from your guardian circle?';
  }

  @override
  String s574(Object? p1) {
    return 'Ended guardianship with $p1';
  }

  @override
  String s575(Object? e) {
    return 'Operation failed: $e';
  }

  @override
  String s576(Object? senderName) {
    return '【在呢】$senderName is safe. No need to worry ❤️';
  }

  @override
  String s577(Object? p1) {
    return 'Safety message sent to $p1 guardians';
  }

  @override
  String s578(Object? p1) {
    return 'SMS prepared for $p1 guardians. Please send it in your SMS app';
  }

  @override
  String s579(Object? e) {
    return 'SMS unavailable: $e';
  }

  @override
  String get s580 => 'Period Settings';

  @override
  String get s581 => 'Menstrual Cycle Length';

  @override
  String get s582 => 'Period Length';

  @override
  String get s583 => 'Reminder Settings';

  @override
  String get s584 => 'Save Settings';

  @override
  String s585(Object? p1) {
    return '$p1 days';
  }

  @override
  String get s586 =>
      'Average menstrual cycle length (from the first day of this period to the first day of the next)';

  @override
  String s587(Object? p1) {
    return '$p1 days';
  }

  @override
  String get s588 => 'Average Period Length';

  @override
  String get s589 => 'Enable Period Reminder';

  @override
  String get s590 => 'Remind you before your period starts';

  @override
  String s591(Object? p1) {
    return 'Remind $p1 days in advance';
  }

  @override
  String s592(Object? p1) {
    return '$p1 days';
  }

  @override
  String get s593 => 'Enable Ovulation Reminder';

  @override
  String get s594 => 'Remind you when ovulation begins';

  @override
  String get s595 => 'Settings saved';

  @override
  String get s596 => 'Save failed. Please retry';

  @override
  String s597(Object? e) {
    return 'Analysis failed: $e';
  }

  @override
  String get s598 => 'AI Health Analysis';

  @override
  String get s599 => 'No analysis data yet';

  @override
  String get s600 => 'Start Analysis';

  @override
  String get s601 => '📝 Today\'s To-Do';

  @override
  String get s602 => '⚠️ Needs Attention';

  @override
  String get s603 => '💡 Health Insights';

  @override
  String get s604 => '🎯 Personalized Tips';

  @override
  String s605(Object? p1) {
    return 'Analysis time: $p1';
  }

  @override
  String get s606 => 'Excellent';

  @override
  String get s607 => 'Good';

  @override
  String get s608 => 'Needs Improvement';

  @override
  String get s609 => 'Health Score';

  @override
  String get s610 => 'Based on your health data analysis';

  @override
  String s611(Object? p1) {
    return 'Current: $p1';
  }

  @override
  String s612(Object? p1) {
    return 'Suggested: $p1';
  }

  @override
  String get s613 => 'Urgent';

  @override
  String get s614 => 'Important';

  @override
  String get s615 => 'Suggested';

  @override
  String get s616 => 'Tip';

  @override
  String get s617 => 'Severe';

  @override
  String get s618 => 'Moderate';

  @override
  String get s619 => 'Mild';

  @override
  String s620(Object? p1) {
    return '$p1 min ago';
  }

  @override
  String s621(Object? p1) {
    return '$p1 hr ago';
  }

  @override
  String get s622 => 'Fall Event Records';

  @override
  String get s623 => 'Feature Info';

  @override
  String get s624 => 'Precision detection enabled';

  @override
  String get s625 => 'Paired · guarding';

  @override
  String get s626 => 'Not Paired';

  @override
  String get s627 => 'Phone';

  @override
  String get s628 => 'Assistive detection ready';

  @override
  String s629(Object? p1) {
    return '$p1 records';
  }

  @override
  String get s630 => 'No fall events yet';

  @override
  String get s631 =>
      'The system is continuously monitoring.\nApple Watch provides precision fall detection,\nand your phone provides assistive motion detection.';

  @override
  String get s632 => 'Location';

  @override
  String get s633 => 'Confidence';

  @override
  String get s634 => 'Confirmed at';

  @override
  String get s635 => 'Confirmed as false alarm';

  @override
  String get s636 => 'Guardians notified';

  @override
  String get s637 => 'Not notified';

  @override
  String get s638 => 'About Fall Detection';

  @override
  String get s639 => 'Apple Watch Precision Detection';

  @override
  String get s640 =>
      'Uses the Watch\'s high-precision accelerometer to accurately detect fall motions.\nRequires Apple Watch Series 4 or later.';

  @override
  String get s641 => 'Phone-assisted detection';

  @override
  String get s642 =>
      'Uses iPhone accelerometer for simplified fall detection.\nAccuracy is lower than Watch, but as a backup it still provides basic protection.';

  @override
  String get s643 => 'Notify guardian';

  @override
  String get s644 =>
      'When a fall is detected and you don\'t respond within 60 seconds, you can confirm to notify your guardian.';

  @override
  String get s645 => 'Disclaimer';

  @override
  String get s646 =>
      'This feature is only a safety reference aid and cannot replace professional medical diagnosis or emergency services.';

  @override
  String get s647 => 'Location permission required to set up a safe zone';

  @override
  String get s648 => 'Delete safe zone';

  @override
  String s649(Object? p1) {
    return 'Are you sure you want to delete the \"$p1\" safe zone?';
  }

  @override
  String get s650 => 'Clear all safe zones';

  @override
  String get s651 =>
      'Are you sure you want to delete all safe zones? This action cannot be undone.';

  @override
  String get s652 => 'Clear all';

  @override
  String get s653 => 'Safe zone';

  @override
  String get s654 => 'Clear all';

  @override
  String get s655 => 'Add safe zone';

  @override
  String get s656 => 'No safe zones yet';

  @override
  String get s657 =>
      'Set your home or frequent places as safe zones\nYou can choose to notify your guardian when leaving';

  @override
  String get s658 => 'Add your first safe zone';

  @override
  String s659(Object? p1, Object? p2) {
    return '$p1 · ${p2}m radius';
  }

  @override
  String get s660 => 'Enabled';

  @override
  String get s661 => 'Disabled';

  @override
  String get s662 => 'Add safe zone';

  @override
  String get s663 => 'Safe zone name';

  @override
  String get s664 => 'e.g. Home, Office, Gym';

  @override
  String get s665 => 'Type';

  @override
  String get s666 => 'Home';

  @override
  String get s667 => 'Office';

  @override
  String get s668 => 'Radius (m)';

  @override
  String get s669 => 'e.g. 200';

  @override
  String get s670 => 'm';

  @override
  String get s671 => 'Set coordinates manually (optional)';

  @override
  String get s672 => 'Latitude';

  @override
  String get s673 => 'Longitude';

  @override
  String get s674 => 'Leave blank to use current location';

  @override
  String get s675 => 'Enter a safe zone name';

  @override
  String get s676 => 'Add';

  @override
  String get s677 => 'Wishing you safe and happy every day 💙';

  @override
  String get s678 => 'No matter how far, I care about you 🌟';

  @override
  String get s679 => 'Take good care of yourself, reach out anytime 🤗';

  @override
  String get s680 => 'You are the one I care about most 💕';

  @override
  String get s681 => 'Safety is the best news—check in every day 🏠';

  @override
  String get s682 => 'Whenever it is, you\'re not alone ✨';

  @override
  String s683(Object? p1) {
    return 'card/list success=false: $p1';
  }

  @override
  String s684(Object? e) {
    return 'card/list error: $e';
  }

  @override
  String s685(Object? p1) {
    return 'invite/stats success=false: $p1';
  }

  @override
  String s686(Object? e) {
    return 'invite/stats error: $e';
  }

  @override
  String get s687 => 'Both card/list and invite/stats returned 0';

  @override
  String get s688 => 'Please sign in before sending a guardian card';

  @override
  String get s689 => 'Edit nickname';

  @override
  String get s690 => 'Recipient\'s nickname (required)';

  @override
  String get s691 => 'e.g. Xiao Zhao';

  @override
  String get s692 =>
      'So the recipient knows at a glance it\'s a gift from you 💌';

  @override
  String get s693 => 'Enter the recipient\'s nickname';

  @override
  String get s694 => 'Generate guardian card';

  @override
  String get s695 =>
      'Network connection failed, saved to retry queue\nIt will retry automatically once the network is restored';

  @override
  String get s696 => 'Session expired, please sign out and sign in again';

  @override
  String get s697 =>
      'No guardian cards available (may have expired)\nWait for the invitee to sign up to get new cards';

  @override
  String get s698 =>
      'Failed to send card, saved to retry queue\nTap the \"Retry\" button to send again';

  @override
  String get s699 => 'Retry';

  @override
  String get s700 => 'Card generation failed, please retry';

  @override
  String get s701 => 'Guardian Card · 在呢';

  @override
  String s702(Object? e) {
    return 'Guardian card generated, but sharing failed: $e';
  }

  @override
  String get s703 => 'Guardian card sent 💌';

  @override
  String get s704 => 'Sharing failed, please retry';

  @override
  String get s705 => 'Saved to album 📷';

  @override
  String get s706 => 'Save failed';

  @override
  String get s707 =>
      'Unable to sync guardian card quota, please check your network and retry';

  @override
  String s708(Object? _syncError) {
    return 'Diagnosis: $_syncError';
  }

  @override
  String get s709 => 'Both card/list and invite/stats returned 0 or failed';

  @override
  String s710(Object? _availableCards) {
    return 'Sync successful, $_availableCards guardian cards remaining';
  }

  @override
  String get s711 => 'Sync failed, please retry later';

  @override
  String get s712 => 'Some guardian cards failed to send, can retry';

  @override
  String get s713 =>
      'You are not signed in; sending guardian cards requires an account';

  @override
  String get s714 => 'Sign in';

  @override
  String get s715 => 'Send guardian card';

  @override
  String get s716 => 'Guardian cards coming soon';

  @override
  String get s717 =>
      'Send a guardian card to someone you care about\nLet them feel your care across the distance';

  @override
  String get s718 => 'Beautiful guardian cards';

  @override
  String get s719 => 'Multiple warmly designed card templates';

  @override
  String get s720 => '3D ceremony';

  @override
  String get s721 => 'Immersive envelope-opening animation';

  @override
  String get s722 => 'Emotional sharing';

  @override
  String get s723 => 'Build real connections through guardian cards';

  @override
  String get s724 => 'Android coming soon';

  @override
  String get s725 =>
      'The Android version is in full development\nWe hope to bring you the ultimate guardian experience';

  @override
  String s726(Object? _availableCards) {
    return 'Guardian cards left: $_availableCards';
  }

  @override
  String get s727 => 'Waiting for recipient to sign up...';

  @override
  String get s728 => 'Guardian card expired — check in to unlock a new card';

  @override
  String get s729 =>
      'Guardian cards used up — invite friends to sign up to unlock';

  @override
  String get s730 => 'Guardian cards used up';

  @override
  String s731(Object? _availableCards) {
    return '$_availableCards cards';
  }

  @override
  String get s732 => 'Sign up within 24h';

  @override
  String s733(Object? remainingDays) {
    return 'Check in $remainingDays more days';
  }

  @override
  String get s734 => 'Unlock';

  @override
  String get s735 => 'Loading';

  @override
  String get s736 => 'Locked';

  @override
  String s737(Object? _availableCards) {
    return '$_availableCards available';
  }

  @override
  String s738(Object? _initialRemainingDays) {
    return 'Starter card valid for: $_initialRemainingDays days';
  }

  @override
  String get s739 =>
      'If not registered within 24 hours, it will be returned automatically';

  @override
  String s740(Object? totalDays, Object? targetDays) {
    return 'Checked in $totalDays days total — check in $targetDays days to unlock 1 guardian card';
  }

  @override
  String get s741 => '📖 Check-in unlock rules';

  @override
  String get s742 => '• Cumulative check-ins (not consecutive!)';

  @override
  String get s743 => '• Missing a check-in won\'t reset your cumulative days';

  @override
  String get s744 => '• Unlock tiers: 3/7/14/30 days';

  @override
  String get s745 => '💡 Check in with peace of mind—missing days is okay!';

  @override
  String s746(Object? _totalRegistered) {
    return 'Guarded $_totalRegistered people — invite more for cards';
  }

  @override
  String s747(Object? p1) {
    return 'Sent $p1 cards';
  }

  @override
  String get s748 => 'Collapse';

  @override
  String get s749 => 'Expand';

  @override
  String s750(Object? p1) {
    return 'They haven\'t joined yet ($p1)';
  }

  @override
  String get s751 => 'Expired';

  @override
  String s752(Object? h, Object? m) {
    return '${h}h ${m}m left';
  }

  @override
  String s753(Object? m, Object? s) {
    return '${m}m ${s}s left';
  }

  @override
  String get s754 => 'Card returned automatically';

  @override
  String get s755 => 'Expiring soon';

  @override
  String get s756 => 'Security code copied';

  @override
  String get s757 => 'Remind them';

  @override
  String get s758 =>
      'Tap \"Remind them\" to pick a caring message, then copy and paste it in WeChat to send';

  @override
  String s759(Object? shareUrl) {
    return 'I sent you a guardian card, did you get it?\n👇 Tap the link to accept my care\n$shareUrl';
  }

  @override
  String s760(Object? shareUrl) {
    return 'The guardian card I sent you is about to expire~\nTap the link to let me know you\'re okay 💛\n$shareUrl';
  }

  @override
  String s761(Object? shareUrl) {
    return 'Your guardian card is expiring, where are you? 😂\nTap the link quick so I can keep guarding you!\n$shareUrl';
  }

  @override
  String s762(Object? shareUrl) {
    return 'I sent you a guardian card 👇\nTap the link to claim it\n$shareUrl';
  }

  @override
  String get s763 => 'Send your care to them';

  @override
  String get s764 => 'Change message';

  @override
  String get s765 => 'Copy and open WeChat';

  @override
  String s766(Object? succeeded, Object? retried, Object? p1) {
    return 'Retry complete: $succeeded/$retried successful$p1';
  }

  @override
  String get s767 => 'Retry failed, please retry later';

  @override
  String s768(Object? e) {
    return 'Retry error: $e';
  }

  @override
  String s769(Object? _invitedCount) {
    return 'Invited $_invitedCount people to join';
  }

  @override
  String s770(Object? _invitedCount) {
    return 'Received $_invitedCount cards';
  }

  @override
  String get s771 => 'Recipient\'s nickname (optional), e.g. \"Mom\"';

  @override
  String get s772 => 'Choose a message';

  @override
  String get s773 => 'Custom message';

  @override
  String get s774 => 'Write what you want to say...';

  @override
  String get s775 => 'Save to album';

  @override
  String get s776 => 'Vital signs guard';

  @override
  String get s777 => 'Vital metrics';

  @override
  String get s778 => 'Record today\'s vitals and share them anytime';

  @override
  String get s779 =>
      'When abnormal, it reminds you to check in safely with your guardian circle';

  @override
  String get s780 => 'Please authorize health data on iPhone';

  @override
  String get s781 =>
      'iOS: Settings → Health → Data Sources & Access → 在呢+ → Turn on all. After authorization, this page\'s data syncs immediately.';

  @override
  String get s782 => 'Re-check';

  @override
  String get s783 => 'Reading…';

  @override
  String get s784 => 'Syncing…';

  @override
  String get s785 => 'Sync and check in safely with your guardian circle';

  @override
  String s786(Object? _lastUpdated) {
    return 'Data synced at $_lastUpdated';
  }

  @override
  String get s787 => 'Health data not synced yet';

  @override
  String get s788 =>
      'Sync successful, checked in safely with your guardian circle ❤️';

  @override
  String get s789 => 'Auto-notify guardian circle on abnormalities';

  @override
  String get s790 =>
      'If abnormalities like prolonged inactivity are detected, it notifies on your behalf automatically';

  @override
  String get s791 => 'Off—abnormalities only alert you within the app';

  @override
  String get s792 => 'On: guardian circle is auto-notified on abnormalities';

  @override
  String get s793 => 'Off: abnormalities are only alerted within the app';

  @override
  String get s794 => 'Blood oxygen level';

  @override
  String get s795 => 'Walking stability';

  @override
  String get s796 => 'Blood pressure';

  @override
  String get s797 => 'Unit: mmHg';

  @override
  String get s798 => 'Today\'s activity';

  @override
  String s799(Object? steps) {
    return '$steps steps';
  }

  @override
  String s800(Object? exercise, Object? stand) {
    return 'Exercise $exercise min · Stand $stand hr';
  }

  @override
  String get s801 => 'Apple Watch required';

  @override
  String s802(Object? min, Object? max) {
    return 'Today $min–$max bpm';
  }

  @override
  String get s803 => 'Past 24 hours';

  @override
  String get s804 => 'Fall risk assessment';

  @override
  String get s805 => 'Stable · low fall risk';

  @override
  String get s806 => 'Fair · keep an eye out';

  @override
  String get s807 => 'Low · high fall risk';

  @override
  String get s808 => 'Data abnormal';

  @override
  String get s809 => 'Last night\'s sleep';

  @override
  String s810(Object? hours, Object? minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get s811 => 'No data yet';

  @override
  String get s812 => 'Deep sleep';

  @override
  String get s813 => 'Core sleep';

  @override
  String get s814 =>
      'Data source: HealthKit (may include iPhone and Apple Watch)';

  @override
  String get s815 => 'On period';

  @override
  String get s816 => 'Not on period';

  @override
  String get s817 => 'Tracking off';

  @override
  String get s818 => 'Menstrual cycle tracking';

  @override
  String s819(Object? cycleDay) {
    return 'Day $cycleDay';
  }

  @override
  String get s820 => 'Average cycle';

  @override
  String s821(Object? avgCycle) {
    return '$avgCycle days';
  }

  @override
  String get s822 => 'Predict next';

  @override
  String get s823 => 'Not enough data';

  @override
  String get s824 =>
      'You can manually log period dates; the system will auto-calculate your cycle and predict the next period';

  @override
  String get s825 => 'Log period';

  @override
  String get s826 => 'Start logging';

  @override
  String get s827 => 'Tomorrow';

  @override
  String s828(Object? diff) {
    return 'In $diff days';
  }

  @override
  String get s829 => 'More body data';

  @override
  String get s830 => 'Resting heart rate';

  @override
  String get s831 => 'Heart rate variability HRV';

  @override
  String get s832 => 'Respiratory rate';

  @override
  String get s833 => 'per min';

  @override
  String get s834 => 'Wrist temperature';

  @override
  String get s835 => 'Overnight wear required';

  @override
  String get s836 => 'Walking distance';

  @override
  String get s837 => 'Active energy';

  @override
  String get s838 => 'kcal';

  @override
  String get s839 => 'ECG · Hearing · Fitness and other complete data';

  @override
  String get s840 =>
      'Apple only makes this data available in the system Health app';

  @override
  String get s841 => 'Open the system Health app on iPhone to view';

  @override
  String get s842 =>
      'Health data provided by Apple HealthKit\nFor reference only, not for medical diagnosis';

  @override
  String get s843 => '✅ Location permission enabled!';

  @override
  String get s844 => 'Location permission required';

  @override
  String get s845 =>
      'You previously denied location permission; please enable it in system settings.\n\nPath:\nPrivacy → Location Services → 在呢 → \"While Using the App\"';

  @override
  String get s846 => 'Go to settings';

  @override
  String get s847 =>
      'Location permission not enabled. Emergency SOS needs your location to send a distress message';

  @override
  String get s848 =>
      'Location permission still not enabled; please make sure it\'s set to \"Allow While Using\"';

  @override
  String s849(Object? p1) {
    return 'N $p1°';
  }

  @override
  String s850(Object? p1) {
    return 'E $p1°';
  }

  @override
  String get s851 => 'Emergency SOS';

  @override
  String get s852 => 'Emergency SOS page failed to load';

  @override
  String s853(Object? e) {
    return 'Error message: $e';
  }

  @override
  String get s854 => 'Profile';

  @override
  String get s855 => 'Contacts';

  @override
  String get s856 => 'Location';

  @override
  String get s857 => '📱 Set phone number';

  @override
  String get s858 =>
      'Once set, your emergency SOS text will include your phone number';

  @override
  String get s859 => 'Phone number';

  @override
  String get s860 => 'Please enter a valid 11-digit phone number';

  @override
  String s861(Object? normalizedPhone) {
    return 'Phone number set to $normalizedPhone';
  }

  @override
  String get s862 => 'N ';

  @override
  String get s863 => 'E ';

  @override
  String s864(Object? p1) {
    return 'N $p1°';
  }

  @override
  String s865(Object? p1) {
    return 'E $p1°';
  }

  @override
  String get s866 => 'Unknown address';

  @override
  String get s867 => '【在呢 Emergency SOS】';

  @override
  String s868(Object? p1) {
    return 'Person in need: $p1';
  }

  @override
  String s869(Object? p1) {
    return 'Phone number: $p1';
  }

  @override
  String s870(Object? p1) {
    return 'Age: $p1';
  }

  @override
  String s871(Object? _bloodType) {
    return 'Blood type: $_bloodType';
  }

  @override
  String s872(Object? _disease) {
    return 'Medical history: $_disease';
  }

  @override
  String s873(Object? _medicine) {
    return 'Medication: $_medicine';
  }

  @override
  String s874(Object? _allergy) {
    return 'Allergies: $_allergy';
  }

  @override
  String s875(Object? _emergencyNote) {
    return 'Notes: $_emergencyNote';
  }

  @override
  String get s876 => 'District';

  @override
  String get s877 => 'District ';

  @override
  String get s878 => 'County';

  @override
  String get s879 => 'County ';

  @override
  String get s880 => 'City';

  @override
  String get s881 => 'City ';

  @override
  String s882(Object? addrBroken) {
    return 'Address: $addrBroken';
  }

  @override
  String get s883 => '🍎 Apple Maps navigation';

  @override
  String get s884 => '📍 Google Maps navigation';

  @override
  String get s885 =>
      '⚠️ Location retrieval failed, please call back immediately to confirm location!';

  @override
  String get s886 =>
      'If convenient, please describe your current location (e.g. XX intersection, XX neighborhood, near XX mall)';

  @override
  String s887(Object num) {
    return 'Please contact me immediately or call $num!';
  }

  @override
  String get s888 => '在呢 - Solo Living Guardian App';

  @override
  String get s889 => 'You';

  @override
  String s890(Object? r, Object? s, Object? shortUrl, Object num) {
    return '【在呢·Emergency SOS】$r, I\'m $s. I may be in danger and have already sent my real-time location and SOS info via 在呢. Please open the link below right away to see my location and call $num emergency for me! $shortUrl';
  }

  @override
  String get s891 => 'Location history';

  @override
  String get s892 => 'Select date';

  @override
  String get s893 => 'yyyy/MM/dd';

  @override
  String get s894 => 'Switch';

  @override
  String get s895 => 'No location history yet';

  @override
  String get s896 =>
      'Once location tracking is on, your location is recorded every 5 minutes';

  @override
  String s897(Object? p1) {
    return 'Location history $p1';
  }

  @override
  String s898(Object? p1) {
    return 'Accuracy ±${p1}m';
  }

  @override
  String s899(Object? p1) {
    return 'Latitude: $p1';
  }

  @override
  String s900(Object? p1) {
    return 'Longitude: $p1';
  }

  @override
  String s901(Object? p1) {
    return 'Location accuracy about $p1 m (smaller value = more precise)';
  }

  @override
  String get s902 => 'Stationary';

  @override
  String get s903 => 'Walking';

  @override
  String get s904 => 'Running';

  @override
  String get s905 => 'Cycling';

  @override
  String get s906 => 'Driving';

  @override
  String get s907 => 'Today\'s route';

  @override
  String get s908 => 'Route list';

  @override
  String get s909 => 'No track recorded today';

  @override
  String get s910 =>
      'After enabling location sharing, your activity map shows here';

  @override
  String get s911 => 'Today\'s movement';

  @override
  String get s912 => 'Activity range';

  @override
  String get s913 => '0 min';

  @override
  String get s914 => 'Time in safe zone';

  @override
  String s915(Object? h, Object? p1) {
    return '${h}h ${p1}m';
  }

  @override
  String s916(Object? min) {
    return '${min}m';
  }

  @override
  String get s917 => 'Record saved';

  @override
  String get s918 => 'Period tracking';

  @override
  String get s919 => 'Start date';

  @override
  String get s920 => 'Select start date';

  @override
  String get s921 => 'End date (optional)';

  @override
  String get s922 => 'Select end date';

  @override
  String get s923 => 'Flow level';

  @override
  String get s924 => 'Symptoms (optional)';

  @override
  String get s925 => 'Notes (optional)';

  @override
  String get s926 => 'Record your feelings...';

  @override
  String get s927 => 'Save record';

  @override
  String get s928 => 'Get started';

  @override
  String get s929 => 'Enter your phone number to start your safety guard';

  @override
  String get s930 => 'Sign in with phone number to get started';

  @override
  String get s931 => 'Please enter your phone number';

  @override
  String get s932 => 'Someone sent you a guardian card?';

  @override
  String get s933 => 'Enter the security code to bind in one tap →';

  @override
  String get s934 => 'Zaine — your guardian for solo living';

  @override
  String get s935 => 'Enter your guardian security code';

  @override
  String get s936 =>
      'The security code is provided by the issuer. Once entered, you\'ll establish a guardian relationship with them.';

  @override
  String get s937 => 'Example: TFABT4';

  @override
  String get s938 => 'Please enter the security code';

  @override
  String get s939 => 'Security code must be at least 4 characters';

  @override
  String get s940 => 'Invalid security code';

  @override
  String get s941 => 'Verification failed. Please check your network';

  @override
  String get s942 =>
      '✅ Security code saved. It will bind automatically after sign-in';

  @override
  String get s943 => 'Confirm';

  @override
  String s944(Object? p1) {
    return 'Apple sign-in failed: $p1';
  }

  @override
  String s945(Object? e) {
    return 'Apple sign-in failed: $e';
  }

  @override
  String get s946 => 'A caring guardian for solo living';

  @override
  String get s947 => 'Every night on your own\nyou are not alone';

  @override
  String get s948 => 'Guarding every night of yours';

  @override
  String get s949 => 'Send a help request when you need it';

  @override
  String get s950 => 'Real-time location, your guardian responds instantly';

  @override
  String get s951 => 'Let those who love you stop worrying';

  @override
  String get s952 => 'Zaine — let those who care know you\'re doing well';

  @override
  String get s953 => 'Complete your health profile';

  @override
  String get s954 => 'Let rescuers know your situation immediately';

  @override
  String get s955 => 'Key info, precise protection';

  @override
  String get s956 => 'Blood type — key reference for transfusions';

  @override
  String get s957 => 'Drug allergies — avoid secondary harm';

  @override
  String get s958 => 'Medical history notes — help doctors assess';

  @override
  String get s959 => 'This info is only sent when you trigger an SOS';

  @override
  String get s960 => 'Add your guardians';

  @override
  String get s961 => 'Emergency contacts = your safety net';

  @override
  String get s962 => 'Add at least 1 family member or friend';

  @override
  String get s963 => 'Notified by priority order when you call for help';

  @override
  String get s964 => 'Quickly send emergency SMS + location';

  @override
  String get s965 => 'Drag to adjust priority';

  @override
  String get s966 => 'They will receive your message when you need it most';

  @override
  String get s967 => 'Enable location permission';

  @override
  String get s968 => 'Our promise: we never monitor your daily location';

  @override
  String get s969 => 'We only fetch your location once when you call for help';

  @override
  String get s970 => 'No tracking, monitoring, or uploading in normal times';

  @override
  String get s971 => 'We only locate you when you actively trigger an SOS';

  @override
  String get s972 => 'Accurate to the meter, with a map link';

  @override
  String get s973 => 'Your privacy, we defend with our lives';

  @override
  String get s974 => 'Emergency SOS texts will include your phone number';

  @override
  String get s975 =>
      'Your info is only used for safety protection and help among friends and family';

  @override
  String get s976 => 'An unregistered phone number will auto-create an account';

  @override
  String get s977 =>
      'To let your guardian know your exact location immediately when you trigger an SOS, we need location permission.';

  @override
  String get s978 => 'Our promise:';

  @override
  String get s979 =>
      '• No tracking, monitoring, or uploading of your location in normal times';

  @override
  String get s980 =>
      '• We only fetch your location once when you actively trigger an SOS';

  @override
  String get s981 => '• Your privacy, we defend with our lives';

  @override
  String get s982 => 'Continue';

  @override
  String get s983 => 'Signing in...';

  @override
  String get s984 => 'Sign in / Sign up';

  @override
  String get s985 => 'Please enter a valid phone number';

  @override
  String get s986 =>
      'Network connection timed out. Please check your network and retry';

  @override
  String get s987 =>
      'Network connection failed. Please check your network and retry';

  @override
  String get s988 =>
      'Network request timed out. Please check your network and retry';

  @override
  String get s989 =>
      'Secure connection failed. Please check your network environment';

  @override
  String get s990 => 'Server busy';

  @override
  String get s991 => 'Server returned an empty response';

  @override
  String get s992 => 'Server response error';

  @override
  String get s993 => 'Server response format error';

  @override
  String get s994 => 'Sign-in failed. Please try again later';

  @override
  String get s995 => 'Guardian invitation';

  @override
  String s996(Object? inviterPhone) {
    return 'The user with phone number $inviterPhone has set you as their emergency contact';
  }

  @override
  String get s997 => 'Would you also like them to guard you?';

  @override
  String get s998 => 'Guard each other';

  @override
  String get s999 =>
      '  You can view each other\'s status and help each other in emergencies';

  @override
  String get s1000 =>
      'You can also choose \"No thanks\" to only be their emergency contact';

  @override
  String get s1001 => 'No thanks';

  @override
  String get s1002 => 'Warmth across the distance';

  @override
  String get s1003 => 'Mr. Mei';

  @override
  String get s1004 =>
      'Seeing this letter is like seeing you. May you be safe and happy.';

  @override
  String get s1005 => 'Dear';

  @override
  String get s1006 => 'Round-the-clock vital signs monitoring';

  @override
  String get s1007 =>
      'Heart rate, blood pressure, sleep — all at your fingertips';

  @override
  String get s1008 => 'Your personal safety network';

  @override
  String get s1009 => 'When needed, one tap notifies all your guardians';

  @override
  String get s1010 => 'Please enter your guardian security code';

  @override
  String get s1011 => 'Redemption failed';

  @override
  String get s1012 => 'Guardian relationship established';

  @override
  String s1013(Object? senderName) {
    return 'You are now $senderName\'s guardian\nYou can guard each other\'s safety';
  }

  @override
  String get s1014 =>
      'If someone sends you a guardian card but you can\'t scan the QR code or open the link, you can enter the security code here to complete binding';

  @override
  String get s1015 => 'Guardian security code';

  @override
  String get s1016 => 'Example: ABC123';

  @override
  String get s1017 =>
      'The security code is provided by the issuer and usually shown on the guardian card';

  @override
  String get s1018 => 'Confirm binding';

  @override
  String get s1019 =>
      'Fall detected with no response. Confirm whether to notify your guardian';

  @override
  String get s1020 => '✅ Safety check confirmed!';

  @override
  String get s1021 => '📱 Fall detection on phone enabled (simplified)';

  @override
  String get s1022 => '📱 Fall detection on phone disabled';

  @override
  String get s1023 => 'Please enable location permission';

  @override
  String get s1024 => 'Safe';

  @override
  String get s1025 => 'Normal';

  @override
  String get s1026 => 'Needs attention';

  @override
  String get s1027 => 'Safety status';

  @override
  String get s1028 => 'Scheduled check-in';

  @override
  String get s1029 => 'Location tracking';

  @override
  String get s1030 => 'Unconfirmed events pending';

  @override
  String get s1031 =>
      'Your safety protection is fully enabled. Let\'s guard your peace together.';

  @override
  String get s1032 =>
      'Scheduled check-in is on. We recommend enabling location tracking for more comprehensive protection.';

  @override
  String get s1033 =>
      'We recommend enabling scheduled check-in and location tracking to build a more complete protection system.';

  @override
  String get s1034 => 'Safety tips';

  @override
  String get s1035 => 'We recommend confirming your safety at least once a day';

  @override
  String get s1036 =>
      'Enabling location tracking allows quick positioning in emergencies';

  @override
  String get s1037 => 'Pairing an Apple Watch syncs health data';

  @override
  String get s1038 =>
      'Remember to periodically check your emergency contacts are correct';

  @override
  String get s1039 => 'Social';

  @override
  String get s1040 => 'Mom';

  @override
  String get s1041 => 'Dad';

  @override
  String get s1042 => 'Bestie Xiaomei';

  @override
  String get s1043 => 'No messages yet';

  @override
  String get s1044 => 'Start interacting with your guardians~';

  @override
  String get s1045 => 'Sent an emoji';

  @override
  String get s1046 => 'Checked in safe';

  @override
  String get s1047 => 'Sent an emergency SOS';

  @override
  String get s1048 => 'Unlocked a new achievement';

  @override
  String get s1049 => 'No stickers received yet';

  @override
  String get s1050 => 'Your guardians will send you stickers~';

  @override
  String get s1051 => 'Yesterday';

  @override
  String get s1052 => 'This week';

  @override
  String s1053(Object? p1, Object? p2) {
    return '$p1/$p2';
  }

  @override
  String get s1054 => 'Health';

  @override
  String get s1055 => 'Check in';

  @override
  String get s1056 => 'Period';

  @override
  String get s1057 => 'Heart rate trend';

  @override
  String get s1058 => 'Blood oxygen trend';

  @override
  String get s1059 => 'Sleep duration';

  @override
  String get s1060 => 'min';

  @override
  String get s1061 =>
      'Smart analysis of your health data with personalized suggestions';

  @override
  String get s1062 =>
      'Settings → Health → Data Sources & Access → Zaine → Enable all';

  @override
  String get s1063 =>
      'Please open iPhone Settings → Health to authorize manually';

  @override
  String get s1064 =>
      'Subscription product not ready yet. Please try again later';

  @override
  String get s1065 =>
      '⏰ Subscription product is being prepared\nTakes 2–24 hours to take effect after Apple approval';

  @override
  String get s1066 =>
      'App Store purchase service unavailable. Please try again later';

  @override
  String s1067(Object? productId) {
    return 'Subscription product not found ($productId). Please retry later or contact support';
  }

  @override
  String get s1068 => 'Network';

  @override
  String get s1069 =>
      'Purchase failed: unstable network. Please check and retry\n(Sandbox testing recommends turning off VPN)';

  @override
  String get s1070 => 'Verification failed. Please restart the app and retry';

  @override
  String get s1071 =>
      '⚠️ Payment verification failed\nPlease restart the app to auto-retry, or contact support';

  @override
  String s1072(Object? e) {
    return 'Verification failed: $e';
  }

  @override
  String get s1073 => '⚠️ Network error. Please restart the app to auto-retry';

  @override
  String get s1074 => 'Purchase canceled';

  @override
  String get s1075 => 'Purchase record restored';

  @override
  String get s1076 => 'No recoverable purchase record found';

  @override
  String get s1077 => 'yyyy/M/d';

  @override
  String get s1078 => 'Zaine';

  @override
  String get s1079 => 'Your guardian circle is now lit';

  @override
  String get s1080 => 'Light up your guardian circle';

  @override
  String get s1081 => 'Those who care about you feel more at ease now';

  @override
  String get s1082 => 'Let those who care always know you\'re there';

  @override
  String s1083(Object? p1) {
    return 'Guardian valid until $p1';
  }

  @override
  String get s1084 => 'Quick call to 3 people';

  @override
  String get s1085 => 'Quick text to 3 people';

  @override
  String get s1086 => '10 guardians';

  @override
  String get s1087 =>
      'A simple \"I\'m here\" is worth more than a thousand words';

  @override
  String get s1088 => 'In an emergency, quickly notify 3 contacts';

  @override
  String get s1089 =>
      'One-tap SOS: quick call and text the first 3 contacts — every second counts';

  @override
  String get s1090 => 'Up to 10 guardians — peace of mind for the whole family';

  @override
  String get s1091 =>
      'Parents, partner, close friends… no one important gets left out';

  @override
  String get s1092 => 'Guardian cards — pass care on to more people';

  @override
  String get s1093 =>
      'Start with 3 guardian cards. Invite family and friends into your guardian circle and let love flow';

  @override
  String get s1094 => 'Guardian plan comparison';

  @override
  String get s1095 => 'Guardian features';

  @override
  String get s1096 => 'Basic';

  @override
  String get s1097 => 'Smart';

  @override
  String get s1098 => 'Emergency contact limit';

  @override
  String get s1099 => '5';

  @override
  String get s1100 => '10';

  @override
  String get s1101 => 'Emergency quick call';

  @override
  String get s1102 => '1';

  @override
  String get s1103 => '3';

  @override
  String get s1104 => 'Emergency quick text';

  @override
  String get s1105 => 'Smart protection';

  @override
  String get s1106 => 'A small subscription, a great peace of mind';

  @override
  String s1107(Object? p1) {
    return 'Just $p1 per day';
  }

  @override
  String get s1108 => 'Auto-renews via Apple subscription management';

  @override
  String get s1109 =>
      'Loading subscription product. Tapping purchase will auto-refresh';

  @override
  String get s1110 =>
      '⚠ App Store temporarily unavailable. Please try again later';

  @override
  String get s1111 => 'Loading...';

  @override
  String get s1112 => '/month';

  @override
  String get s1113 => '/year';

  @override
  String get s1114 => 'Monthly';

  @override
  String get s1115 => 'Yearly';

  @override
  String s1116(Object? p1) {
    return '$p1/year';
  }

  @override
  String get s1117 => 'Save 28%';

  @override
  String get s1118 => 'Start protection now';

  @override
  String get s1119 => 'Start protection · Yearly saves more';

  @override
  String get s1120 => 'Your protection is now active';

  @override
  String get s1121 => 'In an emergency, quickly guard 3 contacts';

  @override
  String get s1122 => 'One-tap SOS: quick call and text the first 3 contacts';

  @override
  String get s1123 => 'Up to 10 guardians';

  @override
  String get s1124 =>
      'Parents, partner, close friends — no important person gets left out';

  @override
  String get s1125 => 'Guardian cards pass on care';

  @override
  String get s1126 =>
      'Invite family and friends into your guardian circle and let love flow';

  @override
  String get s1127 => 'Manage guardian subscription';

  @override
  String get s1128 =>
      'Manage your guardian subscription via your Apple ID. Adjust anytime';

  @override
  String get s1129 => 'Go to Apple ID management';

  @override
  String get s1130 => 'Your trust, we guard with care';

  @override
  String get s1131 => 'Official Apple payment';

  @override
  String get s1132 => 'Cancel anytime';

  @override
  String get s1133 => 'Privacy & security';

  @override
  String get s1134 => 'Restore purchase';

  @override
  String s1135(Object? p1, Object? p2) {
    return '≈$p1 $p2/month';
  }

  @override
  String get s1136 => '≈\$5.00/month';

  @override
  String get s1192 => 'Auto-renews monthly';

  @override
  String get s1193 => 'Auto-renews yearly';

  @override
  String s1194(Object? p1, Object? p2) {
    return '$p1/month (approx. $p2/day)';
  }

  @override
  String s1195(Object? p1, Object? p2) {
    return '$p1/year (approx. $p2/day)';
  }

  @override
  String s1137(Object? p1) {
    return ' · Monthly $p1';
  }

  @override
  String s1138(Object? p1) {
    return ' · Yearly $p1';
  }

  @override
  String get s1139 => 'View privacy policy';

  @override
  String get s1140 => 'View terms of service (user agreement)';

  @override
  String s1141(Object? url) {
    return 'Cannot open page: $url';
  }

  @override
  String get s1142 => 'Light';

  @override
  String get s1143 => 'Low';

  @override
  String get s1144 => 'Normal';

  @override
  String get s1145 => 'Heavy';

  @override
  String get s1146 => 'Very heavy';

  @override
  String get s1147 => 'Stomachache';

  @override
  String get s1148 => 'Lower back pain';

  @override
  String get s1149 => 'Headache';

  @override
  String get s1150 => 'Breast tenderness';

  @override
  String get s1151 => 'Fatigue';

  @override
  String get s1152 => 'Mood swings';

  @override
  String get s1153 => 'Increased appetite';

  @override
  String get s1154 => 'Insomnia';

  @override
  String get s1155 => 'Acne';

  @override
  String get s1156 => 'Constipation';

  @override
  String s1157(Object? p1) {
    return 'Server returned empty response (HTTP $p1)';
  }

  @override
  String get s1158 => 'Server busy. Please try again later';

  @override
  String get s1159 => 'Too many requests. Please try again later';

  @override
  String s1160(Object? p1) {
    return 'Server response error (HTTP $p1)';
  }

  @override
  String s1161(Object? p1) {
    return 'Server response format error (HTTP $p1)';
  }

  @override
  String get s1162 => 'Daily check-in reminder';

  @override
  String get s1163 =>
      'Reminds you to complete your daily check-in so your guardian knows you\'re safe';

  @override
  String get s1164 => 'Time to check in 🏠';

  @override
  String get s1165 =>
      'Tap to open Zaine, complete today\'s check-in, and ease your guardian\'s mind ❤️';

  @override
  String get s1166 => 'Extra reminder if you haven\'t checked in that day';

  @override
  String get s1167 => 'Don\'t forget to check in 💙';

  @override
  String get s1168 =>
      'You haven\'t checked in today. Take 3 seconds to report you\'re safe and ease your guardian\'s mind';

  @override
  String get s1169 => 'StoreKit unavailable. Please try again later';

  @override
  String get s1170 => 'Failed to initiate purchase request';

  @override
  String s1171(Object? lastError) {
    return 'Purchase failed: $lastError';
  }

  @override
  String get s1172 =>
      'Network connection unstable\nPlease check your network and retry\n(Sandbox testing environment may require turning off VPN)';

  @override
  String get s1173 =>
      'Sandbox service temporarily unavailable\nPlease retry later or restart the app';

  @override
  String s1174(Object? p1) {
    return 'Purchase issue ($p1...)';
  }

  @override
  String s1175(Object? errStr) {
    return 'Purchase error: $errStr';
  }

  @override
  String s1176(Object? productId) {
    return 'Product not found: $productId';
  }

  @override
  String get s1177 => 'Purchase failed';

  @override
  String get s1180 => 'Got a guardian code from a friend? Tap to connect';

  @override
  String get languageSettings => 'Language';

  @override
  String get languageHint => 'Switch app display language';

  @override
  String get langSystem => 'Follow system';

  @override
  String get langZhCn => 'Simplified Chinese';

  @override
  String get langZhTw => 'Traditional Chinese (Taiwan)';

  @override
  String get langZhHk => 'Traditional Chinese (Hong Kong)';

  @override
  String get langEn => 'English';

  @override
  String get splashSlogan => 'Let those who care always know you\'re there';

  @override
  String get s1181 => 'I have a guardian code';

  @override
  String get s1182 => 'Guardian code saved';

  @override
  String get s1183 => 'Enter their guardian code';

  @override
  String get s1184 =>
      'Add it now - we will connect you right after you sign in';

  @override
  String s1185(Object? senderName) {
    return '$senderName\'s code confirmed - we will connect you after you sign in';
  }

  @override
  String get s1186 => 'Please enter the guardian code';

  @override
  String get s1187 => 'This guardian code is invalid or has expired';

  @override
  String get s1188 => 'Network error, please try again later';

  @override
  String get s1189 => 'Share with a friend';

  @override
  String get s1190 => 'My guardian code';

  @override
  String get s1191 =>
      'Scan the QR code above, or enter this code in Zaine\nto connect with me';

  @override
  String z0607(Object? p1) {
    return '$p1 has left';
  }

  @override
  String z0003(Object? p1) {
    return '$p1 days ago';
  }

  @override
  String z0002(Object? p1) {
    return '$p1 hours ago';
  }

  @override
  String z0001(Object? p1) {
    return '$p1 minutes ago';
  }

  @override
  String z0606(Object? p1, Object? p2) {
    return '$p1 fences · $p2 inside';
  }

  @override
  String z0611(Object? p1, Object? p2) {
    return '$p1 (${p2}m)';
  }

  @override
  String z0562(Object? p1) {
    return '$p1 location records';
  }

  @override
  String z0579(Object? p1) {
    return '$p1 location points · tap for details';
  }

  @override
  String get z0595 => 'Watch paired · guarding';

  @override
  String get z0594 => 'Apple Watch precise detection';

  @override
  String get z0582 => 'Apple Watch fall detection';

  @override
  String get z0601 => 'Apple Watch fall detection (precise)';

  @override
  String get z0599 => '⚠ Awaiting confirmation';

  @override
  String get z0598 => '✓ Confirmed';

  @override
  String z0551(Object? p1) {
    return '$p1 AM';
  }

  @override
  String get z0543 => '9 AM';

  @override
  String z0530(Object? p1) {
    return 'Last confirmed: $p1';
  }

  @override
  String get z0564 => 'Last record';

  @override
  String z0552(Object? p1) {
    return '$p1 PM';
  }

  @override
  String get z0544 => '6 PM';

  @override
  String get z0025 => '12 PM';

  @override
  String get z0554 => 'Location sharing';

  @override
  String get z0603 =>
      'Uses your phone\'s accelerometer to detect falls. Less accurate than Apple Watch, but \"better than nothing\". For users without an Apple Watch.';

  @override
  String get z0555 => 'Protect your whereabouts';

  @override
  String get z0565 => 'Stop tracking';

  @override
  String get z0592 => 'Turn off phone detection';

  @override
  String z0550(Object? p1) {
    return '$p1 AM';
  }

  @override
  String get z0549 => '12 AM';

  @override
  String z0557(Object? p1) {
    return 'Guardians can see your live location · $p1';
  }

  @override
  String get z0525 => 'Scheduled safety check-in';

  @override
  String get z0573 => 'Live';

  @override
  String get z0567 => 'Live tracking · ⚡high battery use';

  @override
  String get z0585 => 'Enabled';

  @override
  String get z0583 => 'Connected · precise detection';

  @override
  String get z0556 => 'Enable';

  @override
  String get z0593 => 'Enable phone detection';

  @override
  String get z0566 => 'Start tracking';

  @override
  String get z0561 => 'Optional before tracking';

  @override
  String get z0596 => 'Phone detection · simplified';

  @override
  String get z0026 => 'Phone fall detection (simplified)';

  @override
  String get z0541 => 'Watch heartbeat';

  @override
  String get z0534 => 'Auto-confirm via watch heartbeat';

  @override
  String get z0529 => 'Confirmed when watch detects you — peace of mind';

  @override
  String get z0526 => 'Reminder frequency';

  @override
  String get z0542 => '7 AM';

  @override
  String get z0024 => 'Time schedule';

  @override
  String get z0546 => '10 PM';

  @override
  String get z0545 => '9 PM';

  @override
  String z0553(Object? p1) {
    return '$p1 PM';
  }

  @override
  String get z0575 => 'Normal';

  @override
  String get z0568 => 'Normal tracking · recommended';

  @override
  String get z0563 => 'No track recorded today';

  @override
  String get z0588 => 'No fall records yet; detection running';

  @override
  String z0586(Object? p1) {
    return 'Recent falls ($p1 to confirm)';
  }

  @override
  String get z0587 => 'Recent fall records';

  @override
  String get z0581 => 'Not enabled';

  @override
  String get z0023 => 'Not enabled';

  @override
  String get z0605 => 'No safe zone set';

  @override
  String get z0584 => 'Not connected';

  @override
  String get z0600 => 'This feature offers two fall-detection methods:';

  @override
  String get z0591 => 'View history';

  @override
  String z0590(Object? p1) {
    return 'View history ($p1)';
  }

  @override
  String get z0022 => 'View details';

  @override
  String get z0580 => 'Gait stability & fall detection';

  @override
  String get z0578 => '15 min';

  @override
  String get z0572 => 'Update every 15 min';

  @override
  String get z0574 => '30 sec';

  @override
  String get z0570 => 'Update every 30 sec';

  @override
  String get z0576 => '5 min';

  @override
  String get z0571 => 'Update every 5 min';

  @override
  String get z0539 => 'Weekly';

  @override
  String z0536(Object? p1) {
    return 'Weekly reminder · $p1';
  }

  @override
  String get z0538 => 'Daily';

  @override
  String z0535(Object? p1) {
    return 'Daily reminder · $p1';
  }

  @override
  String get z0547 => 'Add time';

  @override
  String get z0577 => 'Power save';

  @override
  String get z0569 => 'Power-saving tracking · 🔋saves battery';

  @override
  String get z0540 => 'Leave safe zone';

  @override
  String get z0608 =>
      'When leaving the safe zone, you can choose to notify guardians';

  @override
  String get z0528 => 'Auto-confirm on leaving safe zone, no fixed time needed';

  @override
  String get z0533 => 'Auto-confirm on leaving safe zone';

  @override
  String get z0532 => 'Confirm safety now';

  @override
  String get z0610 => 'Manage fences';

  @override
  String get z0015 => 'Custom';

  @override
  String z0537(Object? p1) {
    return 'Custom time · $p1';
  }

  @override
  String get z0527 => 'Trigger method';

  @override
  String get z0609 => 'Set up safe fence';

  @override
  String get z0589 =>
      'Fall-detection data is for safety reference only, not a medical diagnosis';

  @override
  String get z0604 =>
      'Fall-detection data is for safety reference only, not a medical diagnosis.';

  @override
  String get z0558 => 'Collecting track data...';

  @override
  String get z0560 => 'Running';

  @override
  String z0531(Object? p1) {
    return '$p1 consecutive unconfirmed';
  }

  @override
  String get z0559 => 'Tracking mode';

  @override
  String get z0548 => 'Choose reminder time';

  @override
  String get z0602 =>
      'Requires Apple Watch Series 4 or later. Uses the watch\'s accelerometer and gyroscope for precise fall detection. When a fall is detected, you can notify your guardians after confirming.';

  @override
  String get z0597 => 'Requires Apple Watch or phone detection enabled';

  @override
  String z0890(Object? p1, Object? p2) {
    return '$p1 $p2 · checked in';
  }

  @override
  String z0891(Object? p1, Object? p2) {
    return '$p1 $p2 · not checked in';
  }

  @override
  String z0889(Object? p1) {
    return '$p1 mo';
  }

  @override
  String get z0886 => '1 year';

  @override
  String get z0884 => '30 days';

  @override
  String get z0883 => '7 days';

  @override
  String get z0885 => '90 days';

  @override
  String get z0892 => 'Multi';

  @override
  String get z0004 => 'days';

  @override
  String get z0896 => 'Current streak';

  @override
  String z0888(Object? p1, Object? p2, Object? p3) {
    return 'Total check-ins $p1 days · streak $p2 days · longest $p3 days';
  }

  @override
  String z0893(Object? p1) {
    return 'No check-in in the last $p1 days';
  }

  @override
  String get z0897 => 'This week';

  @override
  String get z0894 => 'Check in daily, light up your safety calendar';

  @override
  String get z0887 => 'Check-in heatmap';

  @override
  String get z0895 => 'Check-in stats';

  @override
  String z0663(Object? p1) {
    return '$p1 days';
  }

  @override
  String z0654(Object? p1) {
    return '$p1 days';
  }

  @override
  String z0655(Object? p1) {
    return '$p1 days';
  }

  @override
  String get z0659 => 'Next period';

  @override
  String get z0662 => 'Cycle length';

  @override
  String get z0646 =>
      'Record period data on the health overview to see cycle analysis';

  @override
  String get z0651 => 'Safe period';

  @override
  String z0648(Object? p1) {
    return 'Average cycle $p1 days';
  }

  @override
  String get z0652 => 'Fertile window';

  @override
  String get z0660 => 'Fertility window';

  @override
  String get z0645 => 'No period records yet';

  @override
  String z0656(Object? p1) {
    return 'Day $p1';
  }

  @override
  String z0661(Object? p1, Object? p2) {
    return 'Day $p1-$p2';
  }

  @override
  String get z0647 => 'Menstrual cycle';

  @override
  String z0649(Object? p1) {
    return 'Period day $p1';
  }

  @override
  String get z0658 => 'Period prediction';

  @override
  String get z0653 => 'Recent records';

  @override
  String get z0657 => 'Prediction';

  @override
  String z0650(Object? p1) {
    return 'In $p1 days';
  }

  @override
  String get z0666 => 'Name · age · blood type';

  @override
  String get z0029 => 'Complete health profile';

  @override
  String get z0668 => 'Tap the button below → system dialog → tap “Allow”';

  @override
  String z0671(Object? p1) {
    return 'Just $p1 steps — set once, works forever';
  }

  @override
  String get z0667 => 'Bind at least one family member or friend';

  @override
  String get z0669 => 'Enable emergency help';

  @override
  String get z0672 => 'One last step to finish!';

  @override
  String get z0670 => 'Available anytime';

  @override
  String get z0635 =>
      'Location permission enabled — accurate location sent when you call for help';

  @override
  String get z0634 => 'Send';

  @override
  String get z0028 => 'Enable';

  @override
  String get z0632 => 'Add';

  @override
  String get z0633 => 'Send 1 guardian card';

  @override
  String get z0629 => 'Fill in key health info — it helps at critical moments';

  @override
  String get z0644 => 'Guardian Pioneer · all newbie tasks done';

  @override
  String get z0643 => 'Completed';

  @override
  String get z0638 => 'Done! Keep checking in to unlock more badges 🏆';

  @override
  String z0639(Object? p1, Object? p2) {
    return 'Checked in $p1 days straight, $p2 more to go 💪';
  }

  @override
  String get z0627 => 'All newbie tasks complete!';

  @override
  String get z0628 => 'Newbie guardian tasks';

  @override
  String get z0640 => 'Check in daily so guardians know you\'re safe';

  @override
  String get z0636 =>
      'Only when calling for help can accurate location be sent to guardians';

  @override
  String get z0630 => 'Add 1 guardian';

  @override
  String get z0631 => 'Emergency contacts automatically become your guardians';

  @override
  String get z0641 => 'Unlock badge: Guardian Pioneer';

  @override
  String get z0642 => 'In progress';

  @override
  String get z0637 => 'Check in 3 days in a row';

  @override
  String get z0772 => 'Good morning';

  @override
  String get z0774 => 'Good afternoon';

  @override
  String get z0773 => 'Good noon';

  @override
  String get z0010 => 'Late at night';

  @override
  String get z0771 => 'Good morning';

  @override
  String get z0775 => 'Good evening';

  @override
  String z0722(Object? p1) {
    return '$p1 yrs';
  }

  @override
  String z0732(Object? p1, Object? p2) {
    return '$p1, $p2';
  }

  @override
  String z0734(Object? p1, Object? p2, Object? p3) {
    return 'https://maps.apple.com/?daddr=$p1,$p2&q=$p3';
  }

  @override
  String get z0727 => '━━━━━━━━ Helper\'s location ━━━━━━━━';

  @override
  String z0709(Object? p1) {
    return '✅ Sent to all $p1 guardians';
  }

  @override
  String get z0741 => 'Location info';

  @override
  String get z0712 => 'Upgrade to Smart for all notifications';

  @override
  String z0713(Object? p1) {
    return 'Send SMS to $p1';
  }

  @override
  String get z0728 => 'Address';

  @override
  String get z0733 => 'Coordinates:';

  @override
  String get z0030 => 'Sent';

  @override
  String get z0719 => 'Copied to clipboard';

  @override
  String get z0716 => 'All contacts called';

  @override
  String get z0737 => 'Called';

  @override
  String get z0742 => 'Acquired';

  @override
  String get z0740 => 'Pending send';

  @override
  String get z0738 => 'Pending call';

  @override
  String get z0708 => 'I\'m okay now';

  @override
  String get z0711 => 'More guardians';

  @override
  String get z0721 => 'Not set';

  @override
  String get z0735 => 'Taking the following actions:';

  @override
  String get z0720 => 'Person calling for help';

  @override
  String get z0718 => 'SOS message preview (tap to expand)';

  @override
  String get z0717 => 'SOS message (tap to collapse)';

  @override
  String get z0724 => 'Medical history';

  @override
  String get z0739 => 'SMS notification';

  @override
  String get z0707 => 'Emergency SOS triggered';

  @override
  String get z0736 => 'Emergency contact phone';

  @override
  String get z0729 => 'Apple Maps';

  @override
  String get z0725 => 'Medication';

  @override
  String get z0743 => 'Acquiring...';

  @override
  String get z0723 => 'Blood type';

  @override
  String z0731(Object num) {
    return 'Please contact me immediately or dial $num!\nZaine - solo safety app';
  }

  @override
  String get z0726 => 'Allergies';

  @override
  String get z0730 => 'Google Maps';

  @override
  String get z0031 => '(location unknown)';

  @override
  String get z0715 => '(done)';

  @override
  String z0714(Object? p1) {
    return '📞 Call $p1';
  }

  @override
  String z0710(Object? p1, Object? p2, Object? p3) {
    return '📨 Sending SOS SMS to guardian $p1/$p2: $p3';
  }

  @override
  String z0744(Object num) {
    return '🚑 Call $num emergency';
  }

  @override
  String get z0675 => 'Sit-less reminder';

  @override
  String get z0696 =>
      'Keep your phone charged — in an emergency it\'s your lifeline';

  @override
  String get z0687 => 'Stay in touch';

  @override
  String get z0695 => 'Charge backup';

  @override
  String get z0679 => 'Care for your heart';

  @override
  String get z0682 => 'Takeout is convenient, but remember veggies and protein';

  @override
  String get z0681 => 'Eat well';

  @override
  String get z0690 =>
      'If you take medication, set an alarm so you don\'t miss a dose';

  @override
  String get z0700 =>
      'Keep indoor temperature 22-26°C; too cold or hot affects your body';

  @override
  String get z0678 => 'Try to sleep before 23:30, get 7-8 hours';

  @override
  String get z0685 => 'Open windows for fresh air';

  @override
  String get z0691 => 'Mood logging';

  @override
  String get z0697 => 'First-aid knowledge';

  @override
  String get z0692 =>
      'When feeling low, try writing it down — sharing is the first step to healing';

  @override
  String z0680(Object num) {
    return 'If you feel palpitations or chest tightness, don\'t tough it out — call $num';
  }

  @override
  String get z0689 => 'Take meds on time';

  @override
  String get z0683 => 'Digital detox';

  @override
  String get z0686 => 'Ventilate 15 min morning and evening for fresh air';

  @override
  String get z0693 => 'Check doors and windows';

  @override
  String get z0676 =>
      'Get up and walk 5 min every 45 min — protect neck and back';

  @override
  String get z0688 =>
      'Call family or friends at least once a week — don\'t isolate';

  @override
  String get z0699 => 'Temperature control';

  @override
  String get z0674 =>
      'Living solo it\'s easy to forget water — drink a cup of warm water hourly';

  @override
  String get z0684 =>
      'Put the phone down 1 hour before bed, let brain and eyes rest';

  @override
  String get z0694 =>
      'Before bed, confirm doors and windows are locked — never slack on safety';

  @override
  String get z0698 =>
      'Spend 10 min learning CPR — it can save a life when it counts';

  @override
  String get z0677 => 'Regular routine';

  @override
  String get z0673 => 'Drink more water';

  @override
  String z0875(Object? p1, Object? p2, Object? p3, Object? p4) {
    return '$p1$p2 · $p3 yrs · $p4';
  }

  @override
  String get z0879 => 'Demo experience';

  @override
  String get z0876 => 'Phone not set — tap here to add →';

  @override
  String get z0874 => 'Profile · contacts · location ready';

  @override
  String get z0877 => 'Sending SOS...';

  @override
  String get z0005 => 'Help';

  @override
  String get z0878 => 'Tap to trigger emergency SOS';

  @override
  String get z0873 =>
      'Use only in emergencies — contacts guardians and sends location';

  @override
  String z0505(Object? p1) {
    return 'Emergency SOS auto-triggers in ${p1}s';
  }

  @override
  String get z0506 => 'I\'m okay';

  @override
  String get z0503 => 'Possible fall detected';

  @override
  String get z0504 =>
      'The system detected a possible fall.\nIf you\'re okay, tap \"I\'m okay\".\nIf you need help, tap \"Need help\".';

  @override
  String get z0511 =>
      'The system detected a possible fall. Please confirm your safety status';

  @override
  String get z0508 => 'Fall detection';

  @override
  String get z0510 => 'Fall detection reminder';

  @override
  String get z0509 => 'Fall detection reminder notification';

  @override
  String get z0507 => 'Need help';

  @override
  String get z0470 => 'GPS locating';

  @override
  String get z0491 => 'GPS locating...';

  @override
  String z0477(Object num) {
    return '✅ $num dialer opened';
  }

  @override
  String get z0471 => '✅ Location acquired';

  @override
  String get z0481 => '✅ All contacts notified';

  @override
  String get z0474 => '✅ SOS SMS sent';

  @override
  String get z0500 => 'Demo only above';

  @override
  String get z0484 => 'Demo only — no real info sent';

  @override
  String get z0465 => 'Preparing demo...';

  @override
  String get z0466 => '88 Jianguo Rd, Chaoyang, Beijing SOHO Modern City';

  @override
  String get z0492 => 'Send SOS SMS';

  @override
  String get z0499 => 'Share live location with guardian circle';

  @override
  String get z0480 => 'Send live location to guardian circle members';

  @override
  String get z0482 => 'Mom is on the way';

  @override
  String get z0487 => 'Done';

  @override
  String get z0496 => 'Dialer opened';

  @override
  String get z0493 => 'Notified 3 contacts';

  @override
  String get z0475 => 'Notified: Mom, Dad, Dr. Li';

  @override
  String get z0502 => 'Got it, back to help page';

  @override
  String get z0498 => 'All members notified';

  @override
  String z0495(Object num) {
    return 'Call $num';
  }

  @override
  String get z0467 => 'Initiating SOS...';

  @override
  String get z0472 => 'Sending SOS SMS...';

  @override
  String z0476(Object num) {
    return 'Calling $num emergency...';
  }

  @override
  String get z0469 => 'Acquiring location...';

  @override
  String get z0479 => 'Notifying emergency contacts...';

  @override
  String get z0501 =>
      'No real SMS or calls were made during the demo.\nA real SOS will contact your guardians and get your precise location after you confirm.';

  @override
  String get z0478 => 'User can manually call emergency';

  @override
  String get z0489 => 'User manually taps help button to trigger SOS';

  @override
  String get z0468 => 'User manually triggered help';

  @override
  String get z0485 =>
      'A real SOS will contact guardians and send location after you confirm';

  @override
  String get z0490 => 'Get location';

  @override
  String get z0488 => 'Trigger help';

  @override
  String get z0021 => 'Jump to system dialer';

  @override
  String get z0473 => 'Notify 3 emergency contacts';

  @override
  String get z0497 => 'Notify guardian circle';

  @override
  String get z0494 => 'Notify emergency contacts';

  @override
  String get z0483 => '🎉 Demo complete';

  @override
  String get z0486 => '🎬 Demo mode';

  @override
  String get z0303 => 'iOS HealthKit 隐私模型下永远 false，请使用 checkRealAuthStatus()';

  @override
  String get z0014 => 'Vital sign anomaly alert';

  @override
  String z0304(Object? p1) {
    return 'Heart rate too high ($p1 bpm)';
  }

  @override
  String z0305(Object? p1) {
    return 'Heart rate too low ($p1 bpm)';
  }

  @override
  String z0306(Object? p1) {
    return 'Low blood oxygen saturation ($p1%)';
  }

  @override
  String z0307(Object? p1, Object? p2) {
    return 'High blood pressure detected ($p1/$p2 mmHg)';
  }

  @override
  String z0308(Object? p1) {
    return 'Low blood pressure detected ($p1 mmHg)';
  }

  @override
  String z0309(Object? p1) {
    return 'Respiration rate abnormally high ($p1/min)';
  }

  @override
  String z0310(Object? p1) {
    return 'Respiration rate abnormally low ($p1/min)';
  }

  @override
  String z0311(Object? p1) {
    return 'Elevated body temperature detected ($p1°C)';
  }

  @override
  String z0312(Object? p1) {
    return 'Elevated temperature during menstruation ($p1°C), get some rest';
  }

  @override
  String z0313(Object? p1) {
    return 'Your period may be coming soon (cycle day $p1)';
  }

  @override
  String z0314(Object? p1, Object? p2) {
    return 'Menstrual cycle longer than usual (day $p1, average $p2)';
  }

  @override
  String z0315(Object? p1, Object? p2) {
    return '今日已签到，跳过自动签到(仍同步健康数据到手表) fromHeartbeat=$p1 hasWatchSignal=$p2';
  }

  @override
  String z0316(Object? p1) {
    return '执行 Watch 心跳自动签到 clientId=$p1';
  }

  @override
  String z0317(Object? p1) {
    return '签到超时(10s) source=$p1';
  }

  @override
  String z0318(Object? p1, Object? p2) {
    return '签到异常 source=$p1: $p2';
  }

  @override
  String z0319(Object? p1, Object? p2) {
    return '签到成功 source=$p1 uid=$p2';
  }

  @override
  String z0320(Object? p1, Object? p2) {
    return '签到未成功(服务端) source=$p1: $p2';
  }

  @override
  String z0333(Object? p1, Object? p2, Object? p3, Object? p4) {
    return '定时判断已签到: 全局=$p1 uid($p2)=$p3 today=$p4 => true(本地命中)';
  }

  @override
  String z0334(Object? p1, Object? p2) {
    return '定时判断已签到: 本地未命中，用服务端缓存 => $p1 (today=$p2)';
  }

  @override
  String z0335(Object? p1, Object? p2, Object? p3) {
    return '定时判断已签到: 本地未命中，查服务端 checked_in_today=$p1 (today=$p2) res=$p3';
  }

  @override
  String z0336(Object? p1) {
    return '定时判断已签到: 服务端查询异常($p1)，回退本地=false';
  }

  @override
  String get z0337 => 'Your watch detected you 💓';

  @override
  String get z0338 => 'Are you safe? Open the App to confirm with one tap';

  @override
  String z0339(Object? p1) {
    return 'Missed safety confirmation $p1 times in a row';
  }

  @override
  String get z0340 =>
      'If you want your guardians to know, open the App and notify them manually';

  @override
  String z0341(Object? p1) {
    return '$p1 times';
  }

  @override
  String get z0006 => 'Scheduled check-in reminder';

  @override
  String get z0007 => 'Reminding you to confirm your safety';

  @override
  String get z0342 => 'Safety check-in reminder 💚';

  @override
  String get z0343 =>
      'You haven\'t confirmed your safety today. Tap here to check in';

  @override
  String z0344(Object? p1) {
    return 'Left $p1';
  }

  @override
  String get z0345 => 'Your watch detected you';

  @override
  String z0346(Object? p1) {
    return 'You have left \"$p1\". Please open the App to confirm you are safe';
  }

  @override
  String get z0347 =>
      'Your heartbeat detected, please open the App to confirm safety';

  @override
  String get z0348 => 'Left safe zone, automatically confirmed safe 🛡️';

  @override
  String z0349(Object? p1) {
    return 'Left \"$p1\", automatically checked you in safe';
  }

  @override
  String get z0350 => 'Your watch detected you, safety auto-confirmed 💓';

  @override
  String get z0351 =>
      'Your heartbeat detected, automatically checked you in safe';

  @override
  String z0352(Object? p1) {
    return '$p1';
  }

  @override
  String z0353(Object? p1) {
    return 'Almost no activity recorded today ($p1 steps)';
  }

  @override
  String z0354(Object? p1) {
    return 'Low activity today, inactive for about $p1 hours';
  }

  @override
  String z0355(Object? p1) {
    return 'Heart rate $p1 bpm, out of normal range';
  }

  @override
  String z0356(Object? p1, Object? p2) {
    return 'Large heart-rate fluctuation today ($p1–$p2 bpm)';
  }

  @override
  String z0357(Object? p1) {
    return 'Apple Watch recorded $p1 heart-rate notifications in the last 30 days';
  }

  @override
  String z0358(Object? p1) {
    return 'Blood oxygen $p1%, significantly low';
  }

  @override
  String z0359(Object? p1) {
    return 'Blood oxygen $p1%, slightly below normal';
  }

  @override
  String z0360(Object? p1) {
    return 'Walking stability $p1%, higher fall risk';
  }

  @override
  String z0361(Object? p1) {
    return 'Slept only $p1 hours last night';
  }

  @override
  String z0362(Object? p1) {
    return 'Slept $p1 hours last night, abnormally long';
  }

  @override
  String get z0008 => 'No health data yet';

  @override
  String get z0009 =>
      'After wearing Apple Watch and enabling health permission, your today\'s status will show here';

  @override
  String get z0016 => 'Good morning status';

  @override
  String get z0017 => 'Stable condition today';

  @override
  String get z0018 => 'Everything is fine today';

  @override
  String get z0019 => 'A few things worth noting';

  @override
  String get z0363 => 'Good condition today, you can proactively tell family';

  @override
  String get z0364 => 'Suggested to report safety to your guardian circle';

  @override
  String z0365(Object? p1) {
    return 'Today $p1 steps, all vitals normal, feel free to let family know anytime';
  }

  @override
  String get z0366 => 'All vitals normal, feel free to tell family anytime';

  @override
  String z0367(Object? p1) {
    return 'Total $p1 reminders, not necessarily a problem, suggested to keep an eye';
  }

  @override
  String get z0368 =>
      'Some notable signals detected, proactively tell family to ease their worry';

  @override
  String z0369(Object? p1) {
    return 'Today $p1 steps, all vitals normal, your family can rest easy';
  }

  @override
  String get z0370 => 'All vitals normal, your family can rest easy';

  @override
  String z0371(Object? p1) {
    return 'Total $p1 reminders, not necessarily a problem, but worth noting';
  }

  @override
  String get z0372 =>
      'Abnormal signal detected, proactively report safety to ease family\'s worry';

  @override
  String get z0373 => 'Love';

  @override
  String get z0374 => 'Happy';

  @override
  String get z0375 => 'Flower';

  @override
  String get z0376 => 'Sunshine';

  @override
  String get z0377 => 'Moon';

  @override
  String get z0378 => 'Lucky clover';

  @override
  String get z0379 => 'Cheer up';

  @override
  String get z0380 => 'Blessing';

  @override
  String get z0381 => 'Celebrate';

  @override
  String get z0382 => 'Hug';

  @override
  String get z0383 => 'Like';

  @override
  String get z0384 => 'Victory';

  @override
  String get z0385 => 'Rainbow';

  @override
  String get z0386 => 'Butterfly';

  @override
  String get z0387 => 'Music';

  @override
  String get z0388 => 'Coffee';

  @override
  String get z0389 => 'Checked in 7 days in a row';

  @override
  String get z0390 => 'Checked in 7 days straight, showing your persistence';

  @override
  String get z0391 => 'Checked in 30 days in a row';

  @override
  String get z0392 => 'Checked in for a month, guardian heart unchanged';

  @override
  String get z0393 => 'Check-in master';

  @override
  String get z0394 => 'Checked in 100 days, became a guardian pro';

  @override
  String get z0395 => 'First care';

  @override
  String get z0396 => 'First emoji sent to a guardian';

  @override
  String get z0397 => 'Warmth delivered';

  @override
  String get z0398 => 'Sent 10 emoji cares in total';

  @override
  String get z0399 => 'Love ambassador';

  @override
  String get z0400 => 'Sent 50 emoji cares in total';

  @override
  String get z0401 => 'Prevent problems before they occur';

  @override
  String get z0402 => 'Set up emergency contact info';

  @override
  String get z0403 => 'Prepare for a rainy day';

  @override
  String get z0404 => 'Test the emergency help feature once';

  @override
  String get z0405 => 'Three guardians';

  @override
  String get z0406 => 'Have 3 guardians';

  @override
  String get z0407 => 'Guardian alliance';

  @override
  String get z0408 => 'Have 5 guardians';

  @override
  String get z0409 => 'Guard 10 people';

  @override
  String get z0410 => 'Guard 10 friends & family';

  @override
  String get z0411 => '请改用 refreshAllAchievements，一次性刷新全部 11 个成就';

  @override
  String get z0412 => 'High heart rate';

  @override
  String z0413(Object? p1) {
    return 'Current heart rate $p1 bpm, above normal resting range';
  }

  @override
  String get z0414 => 'Relax body and mind';

  @override
  String get z0415 => 'Try deep breathing or meditation to lower heart rate';

  @override
  String get z0020 => 'Start meditating';

  @override
  String get z0416 => 'Low heart rate';

  @override
  String z0417(Object? p1) {
    return 'Current heart rate $p1 bpm, below normal range';
  }

  @override
  String get z0418 => 'Normal heart rate';

  @override
  String z0419(Object? p1) {
    return 'Your heart rate $p1 bpm is within healthy range';
  }

  @override
  String get z0420 => 'Excellent cardio-pulmonary function';

  @override
  String get z0421 =>
      'Your resting heart rate is low, indicating good cardio-pulmonary function';

  @override
  String get z0422 => 'Insufficient sleep';

  @override
  String z0423(Object? p1) {
    return 'Slept only $p1 hours last night, aim for 7-9 hours';
  }

  @override
  String z0424(Object? p1) {
    return '$p1 hours';
  }

  @override
  String get z0425 => '7-9 hours';

  @override
  String get z0426 => 'Improve sleep';

  @override
  String get z0427 =>
      'Try going to bed 30 minutes earlier to build a regular routine';

  @override
  String get z0428 => 'Set sleep reminder';

  @override
  String get z0429 => 'Sufficient sleep';

  @override
  String get z0430 => 'Slept well last night, helps recovery';

  @override
  String get z0431 => 'Insufficient deep sleep';

  @override
  String z0432(Object? p1) {
    return 'Deep sleep only $p1%, affecting recovery quality';
  }

  @override
  String get z0433 => 'Low blood oxygen';

  @override
  String z0434(Object? p1) {
    return 'Current blood oxygen $p1%, suggested to watch respiratory health';
  }

  @override
  String get z0435 => 'Watch your respiratory health';

  @override
  String get z0436 => 'Blood oxygen too low, suggested to see a doctor';

  @override
  String get z0437 => 'Normal blood oxygen';

  @override
  String get z0438 => 'Good blood oxygen level, healthy respiratory system';

  @override
  String get z0439 => 'High stress';

  @override
  String get z0440 =>
      'Low heart rate variability, suggesting high stress state';

  @override
  String get z0441 => 'De-stress and relax';

  @override
  String get z0442 =>
      'Try deep breathing, yoga or meditation to relieve stress';

  @override
  String get z0443 => 'Good stress management';

  @override
  String get z0444 =>
      'Good heart rate variability, indicating good stress management';

  @override
  String get z0445 => 'Long menstruation';

  @override
  String z0446(Object? p1) {
    return 'Currently day $p1 of menstruation, consult a doctor if it lasts too long';
  }

  @override
  String get z0447 => 'Menstrual care';

  @override
  String get z0448 => 'Keep warm, avoid strenuous exercise, drink warm water';

  @override
  String get z0449 => 'Irregular cycle';

  @override
  String z0450(Object? p1) {
    return 'Current cycle $p1 days, outside normal range (21-35 days)';
  }

  @override
  String z0451(Object? p1) {
    return '$p1 days';
  }

  @override
  String get z0452 => '21-35 days';

  @override
  String get z0453 => 'Today\'s check-in';

  @override
  String get z0454 =>
      'You haven\'t confirmed safety today, tap to check in and ease your guardians';

  @override
  String get z0455 => 'Check in now';

  @override
  String get z0456 => 'Insufficient data, need at least 2 cycle records';

  @override
  String get z0457 => 'Cycle data abnormal';

  @override
  String z0458(Object? p1) {
    return 'Prediction based on $p1 cycles';
  }

  @override
  String get z0027 => 'Image generation failed';

  @override
  String get z0612 => 'Image decode failed';

  @override
  String get z0613 => 'Badge image saved to album';

  @override
  String z0614(Object? p1) {
    return 'Save failed: $p1';
  }

  @override
  String get z0615 => 'Check-in successful ✓';

  @override
  String z0616(Object? p1) {
    return 'You have guarded yourself for $p1 days in a row';
  }

  @override
  String get z0617 => 'Stay';

  @override
  String get z0618 => 'tuned';

  @override
  String get z0619 => 'Scan to download \"Zaine\"';

  @override
  String get z0620 =>
      'Solo-safety guardian App\nLet those who care know you\'re well';

  @override
  String get z0621 => 'Android version coming soon\nStay tuned';

  @override
  String z0622(Object? p1) {
    return 'Guarded for $p1 days';
  }

  @override
  String get z0623 => 'Save badge';

  @override
  String z0624(Object? p1) {
    return '$p1 days';
  }

  @override
  String get z0512 => 'No messages yet';

  @override
  String get z0513 => 'Send your first message~';

  @override
  String get z0514 => 'Sending message...';

  @override
  String z0515(Object? p1) {
    return '$p1 sent an emoji';
  }

  @override
  String get z0516 => 'Achievement unlocked';

  @override
  String get z0517 => 'Tap to view details';

  @override
  String get z0518 => 'Guardee has checked in';

  @override
  String get z0519 => 'Congratulations!';

  @override
  String get z0859 => 'Guardian achievements';

  @override
  String get z0860 => 'All';

  @override
  String get z0861 => 'Care';

  @override
  String get z0862 => 'Milestone';

  @override
  String z0863(Object? p1, Object? p2) {
    return 'Unlocked $p1 / $p2';
  }

  @override
  String get z0864 => 'Start your guardian journey!';

  @override
  String get z0865 => 'Keep it up!';

  @override
  String get z0866 => 'Nice work!';

  @override
  String get z0867 => 'Close to the goal!';

  @override
  String get z0868 => 'Awesome! All unlocked!';

  @override
  String get z0869 => 'Unlocked';

  @override
  String z0870(Object? p1) {
    return 'Unlocked on $p1';
  }

  @override
  String get z0871 => 'Achievement unlocked!';

  @override
  String get z0872 => 'Awesome!';

  @override
  String get z0052 => 'Lifetime Guardian King';

  @override
  String get z0053 => '5+ years, guarding has become a habit';

  @override
  String get z0054 => '1400 Legend';

  @override
  String get z0055 => 'Nearly 4 years, the legend never ends';

  @override
  String get z0056 => 'Triple Crown King';

  @override
  String get z0057 => '3+ years, a kingly bearing';

  @override
  String get z0058 => 'Double Crown Legend';

  @override
  String get z0059 => 'Nearly 3 years, the legend continues';

  @override
  String get z0060 => 'Guardian Diamond';

  @override
  String get z0061 => '2+ years, you are the most reliable guardian';

  @override
  String get z0062 => 'Double Crown King';

  @override
  String get z0063 => 'Nearly 2 years, double the glory';

  @override
  String get z0064 => 'Double Diamond Guardian';

  @override
  String get z0065 => 'Nearly 2 years, diamonds shine';

  @override
  String get z0066 => 'Annual Champion';

  @override
  String get z0067 => 'Nearly 1.5 years, a champion heart';

  @override
  String get z0068 => 'Annual Flame';

  @override
  String get z0069 => '1+ year, your perseverance is admirable';

  @override
  String get z0070 => '300 King';

  @override
  String get z0071 => 'Nearly 1 year, the path of a king';

  @override
  String get z0072 => 'Golden Guardian';

  @override
  String get z0073 => '250+ days, golden quality';

  @override
  String get z0074 => 'Guardian Gem';

  @override
  String get z0075 => '200+ days, gems shine bright';

  @override
  String get z0076 => 'Silver Guardian';

  @override
  String get z0077 => 'Half year+, silver shining';

  @override
  String get z0078 => 'Bronze Guardian';

  @override
  String get z0079 => 'Nearly half a year, bronze resilience';

  @override
  String get z0080 => 'Bronze Medal';

  @override
  String get z0081 => '140+ days, medal glory';

  @override
  String get z0082 => 'Guardian Medal';

  @override
  String get z0083 => '120+ days, medals upon you';

  @override
  String get z0011 => '100-Day Guardian';

  @override
  String get z0084 => '100+ days, the habit is formed';

  @override
  String get z0085 => 'Art Master';

  @override
  String get z0086 => '95+ days, a master bearing';

  @override
  String get z0087 => 'Quarterly Shine';

  @override
  String get z0088 => 'One quarter, shining bright';

  @override
  String get z0089 => 'Stage Star';

  @override
  String get z0090 => '85+ days, a protagonist halo';

  @override
  String get z0091 => 'Circus Star';

  @override
  String get z0092 => '80+ days, a star grace';

  @override
  String get z0093 => 'Camping Expert';

  @override
  String get z0094 => '75+ days, the path of an expert';

  @override
  String get z0095 => 'Lofty Snow Mountain';

  @override
  String get z0096 => '70+ days, lofty as a mountain';

  @override
  String get z0097 => 'Volcanic Eruption';

  @override
  String get z0098 => '65+ days, passionate as fire';

  @override
  String get z0099 => 'Two-Month Flame';

  @override
  String get z0100 => 'Two months, flames blazing';

  @override
  String get z0101 => 'Surging Waves';

  @override
  String get z0102 => '55+ days, surging on';

  @override
  String get z0103 => 'Fifty Thunder';

  @override
  String get z0104 => '50+ days, thunderous power';

  @override
  String get z0105 => 'Cloud Stroll';

  @override
  String get z0106 => '45+ days, strolling the clouds';

  @override
  String get z0107 => 'First Rainbow';

  @override
  String get z0108 => '40+ days, a brilliant rainbow';

  @override
  String get z0109 => 'Half-Month Guardian';

  @override
  String get z0110 => '35+ days, half-moon fulfilled';

  @override
  String get z0012 => 'Monthly Star';

  @override
  String get z0111 => 'One month, you are a true guardian';

  @override
  String get z0112 => 'Abundant Fruit';

  @override
  String get z0113 => '28+ days, abundant harvest';

  @override
  String get z0114 => 'Tranquil Autumn Leaves';

  @override
  String get z0115 => '26+ days, tranquil as ever';

  @override
  String get z0116 => 'Red Maple Leaves';

  @override
  String get z0117 => '24+ days, maple at its reddest';

  @override
  String get z0118 => 'Shaded Green Trees';

  @override
  String get z0119 => '22+ days, green trees in shade';

  @override
  String get z0120 => 'Upright Pine';

  @override
  String get z0121 => '20+ days, upright as a pine';

  @override
  String get z0122 => 'Cactus';

  @override
  String get z0123 => '18+ days, unyielding resilience';

  @override
  String get z0124 => 'Standing Palm';

  @override
  String get z0125 => '16+ days, standing tall as a pine';

  @override
  String get z0126 => 'Two-Week Bloom';

  @override
  String get z0127 => 'Two weeks, blooming with glory';

  @override
  String get z0128 => 'First Rose Bloom';

  @override
  String get z0129 => '12+ days, first rose bloom';

  @override
  String get z0130 => 'Toward the Sun';

  @override
  String get z0131 => '10+ days, growing toward the sun';

  @override
  String get z0132 => 'Daisy Bloom';

  @override
  String get z0133 => '9+ days, daisy in bloom';

  @override
  String get z0134 => 'First Cherry Blossom';

  @override
  String get z0135 => '8+ days, cherry blossom opens';

  @override
  String get z0136 => 'Shining New Star';

  @override
  String get z0137 => 'One week, a good start is half the success';

  @override
  String get z0138 => 'First Show of Skill';

  @override
  String get z0139 => '6+ days, first show of skill';

  @override
  String get z0140 => 'Budding';

  @override
  String get z0141 => '5+ days, budding';

  @override
  String get z0142 => 'Growing Sprout';

  @override
  String get z0143 => '4+ days, growing sprout';

  @override
  String get z0144 => 'Clover';

  @override
  String get z0145 => '3 days, lucky triple';

  @override
  String get z0146 => 'First Tender Sprout';

  @override
  String get z0147 => '2 days, first tender sprout';

  @override
  String get z0148 => 'Guardian Seed';

  @override
  String get z0013 => 'Every greatness begins with the first step';

  @override
  String get z0149 => 'Persistence matters more than perfection';

  @override
  String get z0150 => 'Guarding yourself is the best gift you give the world';

  @override
  String get z0151 => 'Today you are stronger than yesterday';

  @override
  String get z0152 =>
      'Living alone, never alone at heart; someone is quietly watching over you';

  @override
  String get z0153 => 'You are stronger than you imagine';

  @override
  String get z0154 => 'Every day is a new beginning';

  @override
  String get z0155 => 'Do not fear going slow; fear stopping';

  @override
  String get z0156 => 'You deserve to be treated well';

  @override
  String get z0157 => 'Take good care of yourself, and the world gets better';

  @override
  String get z0158 => 'Your persistence is changing everything';

  @override
  String get z0159 => 'Do not underestimate today you';

  @override
  String get z0160 => 'Safety is the best news';

  @override
  String get z0161 => 'Be gentle with yourself; you have worked hard too';

  @override
  String get z0162 =>
      'Check-in takes a second, but peace of mind lasts all day';

  @override
  String get z0163 => 'Your existence itself matters';

  @override
  String get z0164 => 'Take care of yourself first, then the world';

  @override
  String get z0165 => 'Today is another day of being cared for';

  @override
  String get z0166 => 'The way you live seriously is truly beautiful';

  @override
  String get z0167 => 'Small habits, great power';

  @override
  String get z0168 => 'Today, be proud of yourself too';

  @override
  String get z0169 => 'The warmest word in the world is \"I am here\"';

  @override
  String get z0170 => 'You are never alone';

  @override
  String get z0171 => 'Every today is the foundation of tomorrow';

  @override
  String get z0172 => 'Say to yourself: good job today';

  @override
  String get z0173 => 'Live well today, and that\'s the best tomorrow';

  @override
  String get z0174 => 'You deserve peace and happiness';

  @override
  String get z0175 => 'Remember to smile today';

  @override
  String get z0176 => 'Protecting yourself is protecting those who love you';

  @override
  String get z0177 => 'You get through every hard pass; you\'re truly amazing';

  @override
  String get z0178 =>
      'Slacked off yesterday? No worries, just keep going today.';

  @override
  String get z0179 =>
      'Haven\'t seen you for a few days. Are you okay? Glad you\'re back, let\'s continue.';

  @override
  String get z0180 =>
      'A week apart. What have you been busy with? Remember, someone is waiting for you.';

  @override
  String get z0181 =>
      'Almost half a month since we last met. Welcome back—someone here has been thinking of you.';

  @override
  String get z0182 =>
      'Long time no see. How was this past month? Either way, welcome home.';

  @override
  String get z0183 =>
      'You\'re finally back! Where have you been? We all missed you.';

  @override
  String get z0184 =>
      'It\'s been so long. Thank you for still remembering this place. No matter how long you\'ve been away, home is always open to you.';

  @override
  String get z0185 => 'One week!';

  @override
  String get z0186 =>
      'One week! A new habit is forming. You\'re greater than you think.';

  @override
  String get z0187 => 'Double digits';

  @override
  String get z0188 => 'Double-digit check-in reached! Keep moving forward.';

  @override
  String get z0189 => '20 days';

  @override
  String get z0190 =>
      '20 days of persistence—you\'re quietly growing stronger.';

  @override
  String get z0191 =>
      '🎉 One month! Congrats on becoming the \'Monthly Star\'—protection has become part of your daily life.';

  @override
  String get z0192 => 'One and a half months';

  @override
  String get z0193 =>
      'One and a half months. You\'ve proven with action that persistence isn\'t hard.';

  @override
  String get z0194 => 'Two months';

  @override
  String get z0195 => '🔥 Two months! Your fire of protection is burning.';

  @override
  String get z0196 => 'One quarter';

  @override
  String get z0197 =>
      'One quarter. You\'ve weathered a slice of the seasons. Remarkable.';

  @override
  String get z0198 =>
      '⭐ 100 Days of Protection! You are your own hero. Today is worth celebrating.';

  @override
  String get z0199 => 'Half a year';

  @override
  String get z0200 =>
      'Half a year now. These 180 days of dedication are the best gift you gave yourself.';

  @override
  String get z0201 => 'First anniversary';

  @override
  String get z0202 =>
      '👑 One year! You did it. Protection has become your instinct.';

  @override
  String z0203(Object? p1) {
    return '$p1-Day Milestone';
  }

  @override
  String z0204(Object? p1) {
    return 'Day $p1! Every step of your persistence is creating a miracle.';
  }

  @override
  String get z0205 => 'New Year\'s Day';

  @override
  String get z0206 =>
      'First day of the new year; begin with this check-in. This year, take good care of yourself too.';

  @override
  String get z0207 => 'Qingming (Tomb-Sweeping Day)';

  @override
  String get z0208 =>
      'Honor the past and cherish the present. Living well is the best tribute.';

  @override
  String get z0209 => 'Labor Day';

  @override
  String get z0210 => 'Salute to you who live earnestly. Take a rest today.';

  @override
  String get z0211 => 'Dragon Boat Festival';

  @override
  String get z0212 =>
      'Wishing you well on the Dragon Boat Festival. Tie a colorful cord, and tie up the care for yourself too.';

  @override
  String get z0213 => 'Mid-Autumn Festival';

  @override
  String get z0214 =>
      'The moon rises above the sea; we share this moment though far apart. You are not alone.';

  @override
  String get z0215 => 'National Day';

  @override
  String get z0216 =>
      'A joyous celebration across the land, vast mountains and rivers. Don\'t forget to be kind to yourself.';

  @override
  String get z0217 => 'Spring Festival';

  @override
  String get z0218 =>
      'Happy New Year! No matter where you celebrate, remember someone is always thinking of you.';

  @override
  String get z0219 => 'New Year\'s Eve';

  @override
  String get z0220 =>
      'The last check-in of the year. You\'ve worked hard this year.';

  @override
  String get z0221 => 'Lantern Festival';

  @override
  String get z0222 =>
      'Lanterns bright as day, moon and people round. May every day of yours be warm and bright.';

  @override
  String get z0223 => 'Longtaitou (Dragon Head-Raising Festival)';

  @override
  String get z0224 =>
      'The second day of the second month, the dragon raises its head. Spring has come, and your good fortune begins to rise too.';

  @override
  String get z0225 => 'Qixi (Chinese Valentine\'s Day)';

  @override
  String get z0226 =>
      'Tonight the galaxy shines bright. Love yourself first, then others.';

  @override
  String get z0227 => 'Chongyang (Double Ninth Festival)';

  @override
  String get z0228 =>
      'Climb high to see far, sky high and clouds light. Life fears not being late, but never climbing the mountain.';

  @override
  String get z0229 => 'Minor Cold';

  @override
  String get z0230 =>
      'Cold weather and frozen ground; taking care of yourself is the greatest warmth.';

  @override
  String get z0231 => 'Major Cold';

  @override
  String get z0232 =>
      'The coldest moment of the year, and also the closest to spring.';

  @override
  String get z0233 => 'Beginning of Spring';

  @override
  String get z0234 =>
      'Spring returns to the earth. The seed in your heart is about to sprout.';

  @override
  String get z0235 => 'Rain Water';

  @override
  String get z0236 =>
      'Good rain knows its season. Remember to bring an umbrella today, and to eat too.';

  @override
  String get z0237 => 'Awakening of Insects';

  @override
  String get z0238 =>
      'Spring thunder rumbles, all things revive. The energy in your body should wake up too.';

  @override
  String get z0239 => 'Spring Equinox';

  @override
  String get z0240 =>
      'Day and night equal, yin and yang balanced. Today, make peace with yourself.';

  @override
  String get z0241 => 'Qingming (solar term)';

  @override
  String get z0242 =>
      'Spring is gentle and bright, all things grow. A good day to go out for a walk.';

  @override
  String get z0243 => 'Grain Rain';

  @override
  String get z0244 =>
      'Rain breeds hundreds of grains. Sow hope and wait for the harvest.';

  @override
  String get z0245 => 'Beginning of Summer';

  @override
  String get z0246 => 'Summer is here; live with full, steaming vitality.';

  @override
  String get z0247 => 'Grain Buds';

  @override
  String get z0248 =>
      'Grain Buds beats perfection. Nothing needs to be too full; just right is best.';

  @override
  String get z0249 => 'Grain in Ear';

  @override
  String get z0250 =>
      'Grain in Ear, busy planting. All effort will eventually be rewarded.';

  @override
  String get z0251 => 'Summer Solstice';

  @override
  String get z0252 =>
      'The longest day of the year. Love yourself a little more today.';

  @override
  String get z0253 => 'Minor Heat';

  @override
  String get z0254 => 'The heat grows. A calm mind brings natural coolness.';

  @override
  String get z0255 => 'Major Heat';

  @override
  String get z0256 =>
      'Scorching summer; remember to give yourself a cup of plain cold water.';

  @override
  String get z0257 => 'Beginning of Autumn';

  @override
  String get z0258 =>
      'A leaf tells the coming of autumn. Some things, let go when it\'s time.';

  @override
  String get z0259 => 'End of Heat';

  @override
  String get z0260 =>
      'The heat fades, autumn deepens. Everything is slowly getting better.';

  @override
  String get z0261 => 'White Dew';

  @override
  String get z0262 =>
      'White dew turns to frost. It\'s getting cold; remember to add clothes.';

  @override
  String get z0263 => 'Autumn Equinox';

  @override
  String get z0264 =>
      'Equal share of autumn. Life is half bright, half composed.';

  @override
  String get z0265 => 'Cold Dew';

  @override
  String get z0266 =>
      'Dew grows cold. No matter how busy, don\'t forget to check in.';

  @override
  String get z0267 => 'Frost\'s Descent';

  @override
  String get z0268 =>
      'Frost descends upon the world. The last solar term of autumn; wrap it up well.';

  @override
  String get z0269 => 'Beginning of Winter';

  @override
  String get z0270 =>
      'Winter is here. Remember to keep a share of warmth for yourself.';

  @override
  String get z0271 => 'Minor Snow';

  @override
  String get z0272 =>
      'Minor snow falls. May there be light in your heart, unafraid of the cold.';

  @override
  String get z0273 => 'Major Snow';

  @override
  String get z0274 =>
      'Heavy snow flies. On the coldest days, be your own warm sun.';

  @override
  String get z0275 => 'Winter Solstice';

  @override
  String get z0276 =>
      'Winter Solstice is as grand as New Year. Remember to eat dumplings/tangyuan today, and to check in too.';

  @override
  String get z0277 => 'Welcome back';

  @override
  String get z0776 => '开发者模式 v2.0';

  @override
  String get z0777 => '3D 宣传录制模式';

  @override
  String get z0778 => '进入电影感动画秀，用于录制宣传视频';

  @override
  String get z0779 => '重置今日签到';

  @override
  String get z0780 => '清除今天的签到记录，可重新签到';

  @override
  String get z0781 => '恢复为初始3张卡状态';

  @override
  String get z0782 => '体验版 ↔ 智能版';

  @override
  String get z0783 => '测试智能版过期后自动降级为体验版';

  @override
  String get z0032 => '逆地理诊断';

  @override
  String get z0784 => '查看本次地址来源（高德/系统）及错误码';

  @override
  String get z0033 => 'Apple Watch 测试';

  @override
  String get z0785 => '查看 Watch 信号 & 触发一次静默签到';

  @override
  String get z0034 => 'HealthKit 诊断';

  @override
  String get z0786 => '查看授权/错误/最近一次拉取，并可一键触发读取';

  @override
  String get z0787 => '导出工作记忆 / 切换账号';

  @override
  String get z0788 => '导出本机调试数据（不含token）并退出登录';

  @override
  String z0789(Object? p1) {
    return '来源：$p1';
  }

  @override
  String z0790(Object? p1) {
    return '时间：$p1';
  }

  @override
  String z0791(Object? p1) {
    return '地址：$p1';
  }

  @override
  String z0792(Object? p1) {
    return '高德 info：$p1';
  }

  @override
  String z0793(Object? p1) {
    return '高德 infocode：$p1';
  }

  @override
  String get z0794 => '诊断信息已复制';

  @override
  String z0795(Object? p1) {
    return '最后一次 Watch action：$p1';
  }

  @override
  String z0796(Object? p1) {
    return '最后一次 Watch 时间：$p1';
  }

  @override
  String get z0797 => '提示：健康数据读取不依赖 Watch App，Apple Watch 佩戴数据会自动写入 iPhone 健康。';

  @override
  String get z0798 => '已写入 Watch 签到信号（pending_watch_checkin=true）';

  @override
  String get z0799 => '模拟信号';

  @override
  String get z0800 => '触发静默签到';

  @override
  String z0801(Object? p1) {
    return '最近授权：$p1';
  }

  @override
  String z0802(Object? p1) {
    return '授权时间：$p1';
  }

  @override
  String z0803(Object? p1) {
    return '授权错误：$p1';
  }

  @override
  String z0804(Object? p1) {
    return '最近拉取条数：$p1';
  }

  @override
  String z0805(Object? p1) {
    return '拉取时间：$p1';
  }

  @override
  String z0806(Object? p1) {
    return '拉取错误：$p1';
  }

  @override
  String z0807(Object? p1) {
    return '按类型条数：$p1';
  }

  @override
  String z0808(Object? p1) {
    return '按类型错误：$p1';
  }

  @override
  String get z0809 => '重新授权';

  @override
  String get z0810 => '触发读取';

  @override
  String get z0811 => '导出工作记忆';

  @override
  String get z0812 => '已复制工作记忆（不含token）';

  @override
  String get z0813 => 'Day 1';

  @override
  String get z0814 => 'Day 6';

  @override
  String get z0815 => 'Day 7';

  @override
  String get z0816 => 'Day 29';

  @override
  String get z0817 => 'Day 30';

  @override
  String get z0818 => 'Day 99';

  @override
  String get z0819 => 'Day 100';

  @override
  String get z0820 => 'Day 364';

  @override
  String get z0821 => 'Day 365';

  @override
  String get z0822 => 'Day 1825';

  @override
  String get z0823 => '设置连续签到天数，然后点击\"模拟签到\"。';

  @override
  String get z0824 => '连续签到天数';

  @override
  String get z0825 => '输入 1-1825 之间的天数';

  @override
  String get z0826 => '快捷选择：';

  @override
  String get z0827 => '请输入 1-1825 之间的有效天数';

  @override
  String get z0828 => '模拟签到';

  @override
  String z0829(Object? p1) {
    return '已模拟连续签到 $p1 天 ✓';
  }

  @override
  String z0830(Object? p1) {
    return '弹窗显示失败: $p1';
  }

  @override
  String get z0831 => '重置签到';

  @override
  String get z0832 => '这将清除今天的签到记录，你可以重新签到。';

  @override
  String get z0833 => '连续天数不会受影响。';

  @override
  String get z0834 => '今日签到已重置 ✓';

  @override
  String get z0835 => '这将重置守护卡为初始状态：';

  @override
  String get z0836 => '• 后端配额重置为 3 张（30天有效期）';

  @override
  String get z0837 => '• 清除本地所有守护卡缓存数据';

  @override
  String get z0838 => '• 重置首次发卡日期';

  @override
  String get z0839 => '后端已发出的卡片不受影响，仍可被注册';

  @override
  String get z0840 => '守护卡已重置为初始状态 ✓（3张，30天有效）';

  @override
  String get z0841 => '本地守护卡已重置 ✓（后端未登录未重置）';

  @override
  String get z0842 => '请先切换为智能版，再测试过期降级';

  @override
  String get z0843 => '模拟会员过期';

  @override
  String get z0844 => '模拟智能版过期后自动降级为体验版：';

  @override
  String get z0845 => '• 紧急求助快捷拨打上限：3位 → 1位';

  @override
  String get z0846 => '• 联系人上限：10位 → 5位';

  @override
  String get z0847 => '• 超出限制的联系人显示锁定图标';

  @override
  String get z0848 => '• 已添加的联系人数据保留';

  @override
  String get z0035 => '⚠️ 仅开发测试用，不影响后端数据';

  @override
  String get z0849 => '已模拟会员过期降级 → 体验版 ✓';

  @override
  String get z0850 => '模拟过期';

  @override
  String get z0851 => 'Starter Plan (Free)';

  @override
  String get z0852 => 'Smart Plan (¥9/month)';

  @override
  String get z0853 => 'Emergency SOS quick dial: 1 contact · up to 5 contacts';

  @override
  String get z0854 =>
      'Emergency SOS quick dial: 3 contacts · up to 10 contacts';

  @override
  String z0855(Object? p1) {
    return '当前：$p1';
  }

  @override
  String z0856(Object? p1) {
    return '切换为：$p1';
  }

  @override
  String z0857(Object? p1) {
    return '已切换为 $p1 ✓';
  }

  @override
  String get z0858 => '确认切换';

  @override
  String get z0326 => 'In the safe zone';

  @override
  String get z0327 => 'Left';

  @override
  String get z0328 => 'Not checked';

  @override
  String get z0329 => 'Safety Fence Alert';

  @override
  String get z0330 => 'Alert when leaving the safe area';

  @override
  String z0331(Object? p1) {
    return 'Left $p1 safe zone';
  }

  @override
  String z0332(Object? p1) {
    return 'You have left the \"$p1\" safe area';
  }

  @override
  String get z0279 =>
      'Your parents wait late into the night for your safe check-in; your partner worries when you travel alone; your child hopes you come home early.';

  @override
  String get z0280 =>
      'Zaine is more than an app—it\'s an always-on line of protection between you and the people you care about.';

  @override
  String get z0281 => '• Subscription name: Zaine Smart\n';

  @override
  String z0282(Object? p1) {
    return '• Subscription period: $p1\n';
  }

  @override
  String z0283(Object? p1) {
    return '• Subscription price: $p1\n';
  }

  @override
  String get z0284 =>
      '• Auto-renewal: Automatically charged 24 hours before the current billing cycle ends\n';

  @override
  String get z0285 =>
      '• Cancellation: You can cancel anytime in Apple ID settings; the current period remains available after cancellation.';

  @override
  String z0765(Object? p1) {
    return 'No $p1 data yet';
  }

  @override
  String get z0766 =>
      'Viewable after wearing Apple Watch and enabling health permissions';

  @override
  String z0767(Object? p1) {
    return 'Trend of last $p1 days';
  }

  @override
  String get z0768 => 'Current';

  @override
  String get z0769 => 'Average';

  @override
  String get z0770 => 'Maximum';

  @override
  String get z0295 =>
      'CREATE TABLE checkin_records (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        checkin_date TEXT NOT NULL,      -- 签到日期 (YYYY-MM-DD)\n        checkin_time TEXT NOT NULL,      -- 签到时间 (HH:MM:SS)\n        timestamp INTEGER NOT NULL,       -- Unix 时间戳（毫秒）\n        created_at TEXT DEFAULT CURRENT_TIMESTAMP\n      )';

  @override
  String get z0296 =>
      'CREATE TABLE contacts (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        server_id TEXT,                   -- 服务器返回的 ID（可为空，本地联系人）\n        name TEXT NOT NULL,\n        phone TEXT NOT NULL,\n        relation TEXT,                    -- 关系：家人/朋友/同事等\n        avatar_path TEXT,                 -- 头像本地路径\n        is_local INTEGER DEFAULT 0,       -- 1=本地联系人，0=服务器同步\n        is_emergency INTEGER DEFAULT 0,   -- 1=紧急联系人\n        sort_order INTEGER DEFAULT 0,     -- 排序权重\n        created_at TEXT DEFAULT CURRENT_TIMESTAMP,\n        updated_at TEXT DEFAULT CURRENT_TIMESTAMP\n      )';

  @override
  String get z0297 =>
      'CREATE TABLE health_cache (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        data_type TEXT NOT NULL,          -- 数据类型：steps/heart_rate/distance\n        value REAL NOT NULL,              -- 数值\n        unit TEXT,                        -- 单位\n        date TEXT NOT NULL,               -- 日期 (YYYY-MM-DD)\n        timestamp INTEGER NOT NULL,       -- 记录时间戳\n        source TEXT,                      -- 数据来源：HealthKit/手动\n        UNIQUE(data_type, date) ON CONFLICT REPLACE\n      )';

  @override
  String get z0298 =>
      'CREATE TABLE notification_history (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        type TEXT NOT NULL,               -- 类型：sos/checkin/reminder\n        recipient TEXT,                   -- 接收者\n        content TEXT,                     -- 内容摘要\n        status TEXT,                      -- 状态：sent/failed/pending\n        sent_at TEXT DEFAULT CURRENT_TIMESTAMP\n      )';

  @override
  String get z0299 =>
      'CREATE TABLE location_history (\n        id INTEGER PRIMARY KEY AUTOINCREMENT,\n        latitude REAL NOT NULL,\n        longitude REAL NOT NULL,\n        address TEXT,                     -- 逆地理编码地址\n        accuracy REAL,                    -- 精度（米）\n        trigger_reason TEXT,              -- 触发原因：sos/checkin/manual\n        created_at TEXT DEFAULT CURRENT_TIMESTAMP\n      )';

  @override
  String get z0036 => 'Home';

  @override
  String get z0037 => 'Guardian Circle';

  @override
  String get z0038 => 'Me';

  @override
  String get z0461 => 'Getting location...';

  @override
  String get z0462 => 'Current Location';

  @override
  String get z0463 => 'Failed to get location';

  @override
  String get z0464 => 'Tap to refresh and retry';

  @override
  String get z0745 => 'Check-in Streak';

  @override
  String z0746(Object? p1) {
    return '$p1 days';
  }

  @override
  String z0747(Object? p1) {
    return '$p1 days';
  }

  @override
  String get z0748 => 'This Week\'s Progress';

  @override
  String z0898(Object? p1) {
    return 'Guard ready · $p1 days of continuous guarding';
  }

  @override
  String get z0899 => 'Complete your health profile to start guarding';

  @override
  String z0900(Object? p1) {
    return '· $p1 guardian members';
  }

  @override
  String z0901(Object? p1) {
    return '· $p1 guardians';
  }

  @override
  String get z0625 => 'Completed ✓';

  @override
  String get z0626 => '🔒 Please complete the previous step first';

  @override
  String get z0286 => 'Truly awaiting unlock';

  @override
  String z0287(
      Object? p1, Object? p2, Object? p3, Object? p4, Object? p5, Object? p6) {
    return '卡片[$p1] id=$p2 status=$p3 (type:$p4) receiver=$p5 code=$p6...';
  }

  @override
  String z0288(Object? p1, Object? p2) {
    return '⚠️ 发卡后被过滤器丢弃: status=$p1 is_free=$p2';
  }

  @override
  String z0289(Object? p1) {
    return '$p1, I sent you a protection card on Zaine; it\'s not activated yet~\n\n';
  }

  @override
  String get z0290 =>
      'After downloading the app and logging in, we can check in with each other and reach each other right away when something happens.\n\n';

  @override
  String z0291(Object? p1) {
    return 'Tap the link below to activate the protection bond immediately:\n$p1';
  }

  @override
  String get z0300 =>
      'Location permission is not enabled. Please enable location permission on the help page first.';

  @override
  String get z0301 =>
      'Location services are not enabled. Please turn them on in system settings.';

  @override
  String get z0302 =>
      'Failed to get location. Please share your location manually.';

  @override
  String get z0323 => 'Auto-confirmed on timeout — guardian notified';

  @override
  String get z0324 => 'User confirmed it was a false alarm';

  @override
  String get z0325 => 'User confirmed needing help — guardian notified';

  @override
  String get z0522 => 'Guard Successful 🎉';

  @override
  String get z0523 => 'Open your guardian gift';

  @override
  String get z0524 => 'Has become your guardian';

  @override
  String z0762(Object? p1) {
    return '$p1 wants to confirm you\'re safe';
  }

  @override
  String get z0763 => 'Tap the button below to reassure them';

  @override
  String get z0764 => 'I\'m Safe';

  @override
  String get z0880 => 'No emergency contacts yet';

  @override
  String get z0881 =>
      'Add at least one emergency contact\nEnsure the SOS feature works properly';

  @override
  String get z0882 =>
      'Emergency contacts will receive your location and health info when you call for help\nDrag to adjust priority order';

  @override
  String get z0039 => 'Copied, go to WeChat and paste to send 💬';

  @override
  String get z0040 => 'Open WeChat';

  @override
  String z0321(Object? p1) {
    return '($p1)';
  }

  @override
  String get z0322 => 'Not recorded';

  @override
  String get z0520 => 'Tap to send emergency SOS';

  @override
  String get z0521 => 'Please complete your health profile first';

  @override
  String get z0664 => 'Family & Friends';

  @override
  String get z0665 => 'Edit';

  @override
  String get z0760 => 'Smart Plan Activated!';

  @override
  String get z0761 => 'You can now notify 3 guardians at once';

  @override
  String get z0278 => '在呢+';

  @override
  String z0292(Object? p1, Object? p2) {
    return '旧关系=$p1, 新关系=$p2';
  }

  @override
  String get z0293 => 'Tapped but no response';

  @override
  String z0294(Object? p1, Object? p2, Object? p3) {
    return '$p1 @ $p2:$p3';
  }

  @override
  String z0459(Object? p1) {
    return 'Apple 登录失败: $p1';
  }

  @override
  String get z0460 => 'Safe Zone';

  @override
  String get z0749 => '· Zaine · Guardian Card ·';

  @override
  String z0750(Object? p1) {
    return 'To $p1';
  }

  @override
  String get z0751 => 'As if meeting you in person';

  @override
  String get z0752 => 'Scan to claim your guardian';

  @override
  String get z0753 => 'Zaine · Received a warm care message';

  @override
  String get z0754 => 'Scan failed? Enter this code in the App to bind';

  @override
  String z0755(Object? p1) {
    return '$p1 people have joined the guardian circle';
  }

  @override
  String get z0756 => '· Zaine · Guard Established ·';

  @override
  String z0757(Object? p1) {
    return '$p1 wants to guard you';
  }

  @override
  String get z0758 =>
      'From today, you\'ll receive daily check-in reminders from each other';

  @override
  String get z0759 => 'Let those who care know you\'re doing well 💌';

  @override
  String z0701(Object? p1) {
    return 'Send to $p1';
  }

  @override
  String get z0702 => 'Emotion';

  @override
  String get z0703 => 'Nature';

  @override
  String get z0704 => 'Action';

  @override
  String get z0705 => 'Social';

  @override
  String z0706(Object? p1) {
    return '$p1 sent you a gift';
  }

  @override
  String get z0041 => 'Spring';

  @override
  String get z0042 => 'Summer';

  @override
  String get z0043 => 'Autumn';

  @override
  String get z0044 => 'Winter';

  @override
  String get z0045 => 'Good morning';

  @override
  String get z0046 => 'Good afternoon';

  @override
  String get z0047 => 'Good night';

  @override
  String z0048(Object? p1) {
    return '$p1, spring is in full bloom';
  }

  @override
  String z0049(Object? p1) {
    return '$p1, cool summer days';
  }

  @override
  String z0050(Object? p1) {
    return '$p1, crisp autumn air';
  }

  @override
  String z0051(Object? p1) {
    return '$p1, warm winter days';
  }

  @override
  String get z0902 => 'I\'m OK';

  @override
  String get z0903 => 'Check in now';

  @override
  String get z0904 => 'Need help';

  @override
  String get z0905 =>
      'Confirm sending a help alert to your guardians? They will reach out as soon as possible.';

  @override
  String get z0906 => 'Notify guardians';

  @override
  String get z0907 => 'Guardians have been notified';

  @override
  String get z0908 => 'Awaiting confirmation';

  @override
  String get z0909 => 'Confirmed safe';

  @override
  String get z0910 => 'Contacted';

  @override
  String get z0911 => 'No request to handle';

  @override
  String get z0912 => 'Marked as handled';

  @override
  String get z0913 => 'Failed to mark, please retry';

  @override
  String get z0914 => 'Your guardian will see your reply right away';

  @override
  String get z0915 => 'Say something… (optional, up to 100 chars)';

  @override
  String get z0916 => 'Your message is shared only with your guardians';

  @override
  String get z0925 => 'Add a note (10 chars max)';

  @override
  String z0926(Object? p1, Object? p2) {
    return '$p1 ($p2)';
  }

  @override
  String get z0917 => 'Message';

  @override
  String get z0918 => 'Report I\'m safe';

  @override
  String get z0919 => 'Just got home';

  @override
  String get z0920 => 'Just off work';

  @override
  String get z0921 => 'Just had a meal';

  @override
  String get z0922 => 'Heading to bed';

  @override
  String get z0923 => 'Pick a status (optional)';

  @override
  String get z0924 => 'Status';

  @override
  String get homeArrivalTitle => 'Home Arrival Reminder';

  @override
  String get homeArrivalDesc =>
      'The moment you get home, let your loved ones feel at ease';

  @override
  String get homeArrivalEnable => 'Enable home arrival alerts';

  @override
  String get homeArrivalModeBNotify => 'Also notify guardians';

  @override
  String get homeArrivalModeBDetail =>
      'On: guardians get a \"safe at home\" notification when you arrive; Off: only a local reminder for yourself.';

  @override
  String get homeArrivalSetHome => 'Set home location';

  @override
  String get homeArrivalUseCurrent => 'Use current location';

  @override
  String get homeArrivalHomeSet => 'Home set';

  @override
  String get homeArrivalHomeNotSet => 'Home location not set';

  @override
  String get homeArrivalNeedLocationPerm =>
      'Home arrival needs \"Always\" location access to detect arrival in background';

  @override
  String get homeArrivalSetHomeHint =>
      'Set your home location first (one tap with current location)';

  @override
  String get homeArrivalSetHomeFailed => 'Failed to set home location';

  @override
  String get homeArrivalLocalTitle => 'You\'re home 🏠';

  @override
  String get homeArrivalLocalBody =>
      'Remember to check in so your guardians know you\'re safe.';

  @override
  String get homeArrivalNewUserTitle => 'Enable home arrival alerts?';

  @override
  String get homeArrivalNewUserBody =>
      'Automatically remind you to check in, or let guardians know you\'re home safe.';

  @override
  String get homeArrivalNewUserEnable => 'Enable';

  @override
  String get homeArrivalNewUserLater => 'Later';

  @override
  String get homeArrivalLocationFailed =>
      'Failed to get location, check permission and retry';

  @override
  String get homeArrivalPickOnMap => 'Pick on map';

  @override
  String get homeArrivalNeedAlways =>
      'Home Arrival needs \"Always\" location access to trigger when the app is closed. Go to iPhone Settings → 在呢+ → Location and choose \"Always\".';

  @override
  String get homeArrivalGoSettings => 'Open Settings';

  @override
  String get homeArrivalAlwaysPrompt =>
      'Choose \"Always\" in the popup so Home Arrival works when the app is closed.';

  @override
  String get homeArrivalAlwaysGranted =>
      'Always location enabled — Home Arrival is active 🏠';
}
