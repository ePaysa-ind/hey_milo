/*
File path: lib/config/strings.dart
 Copyright Milo
 This file contains all user-facing strings used throughout the app.
 Centralizing strings here facilitates future localization efforts.
 Author: Milo App Development Team
 Last Updated: May 4, 2025
 */

// String constants class
class AppStrings {
  // Private constructor to prevent instantiation
  AppStrings._();

  // App general
  static const String appName = 'Milo';
  static const String appTagline = 'Your voice memory journal';

  // Navigation & screens
  static const String homeScreenTitle = 'My Journal';
  static const String recordScreenTitle = 'Record Memory';
  static const String caregiverMessagesScreenTitle = 'Messages';
  static const String medicationListScreenTitle = 'Medications';
  static const String medicationEntryScreenTitle = 'Add Medication';
  static const String medicationEditScreenTitle = 'Edit Medication';

  // Record Memory Screen
  static const String startRecordingButtonLabel = 'Start Recording';
  static const String stopRecordingButtonLabel = 'Stop Recording';
  static const String recordingInProgressLabel = 'Recording...';
  static const String recordingTimerLabel = 'Time: ';
  static const String saveRecordingButtonLabel = 'Save Memory';
  static const String discardRecordingButtonLabel = 'Discard';
  static const String recordingLimitReachedMessage =
      'Recording limit reached. Max recording time is 45 seconds.';

  // Journal List
  static const String emptyJournalMessage =
      'No memories recorded yet. Tap the microphone button to create your first voice memory.';
  static const String deleteEntryConfirmation =
      'Are you sure you want to delete this memory?';
  static const String entryAgePrefix = 'Recorded ';
  static const String confirmDeletionTitle = 'Confirm Deletion';
  static const String yesDeleteButton = 'Yes, Delete';
  static const String cancelButton = 'Cancel';
  static const String cleanupReminderMessage =
      'Some of your memories are older than 10 days. They will be automatically deleted after 21 days.';
  static const String reviewOldMemoriesButtonLabel = 'Review Old Memories';

  // Caregiver Messages
  static const String emptyCaregiverMessagesMessage =
      'No messages from caregivers yet.';
  static const String addCaregiverButtonLabel = 'Add Caregiver';
  static const String caregiverNameLabel = 'Caregiver Name';
  static const String saveCaregiverButtonLabel = 'Save Caregiver';
  static const String deleteCaregiverConfirmation =
      'Are you sure you want to remove this caregiver?';

  // Medication Reminders
  static const String emptyMedicationListMessage =
      'No medications added yet. Tap the plus button to add a medication.';
  static const String addMedicationButtonLabel = 'Add Medication';
  static const String medicationNameLabel = 'Medication Name';
  static const String medicationTimeLabel = 'Medication Time';
  static const String addTimeButtonLabel = 'Add Time';
  static const String removeTimeButtonLabel = 'Remove';
  static const String activateReminderLabel = 'Activate Reminder';
  static const String saveMedicationButtonLabel = 'Save Medication';
  static const String deleteMedicationConfirmation =
      'Are you sure you want to delete this medication?';
  static const String medicationReminderTitle = 'Time for your medication';
  static const String medicationReminderBody = 'It\'s time to take: ';

  // Permissions
  static const String microphonePermissionTitle = 'Microphone Access';
  static const String microphonePermissionMessage =
      'Milo needs microphone access to record your voice memories. This permission is used only when you choose to record a memory.';
  static const String notificationPermissionTitle = 'Notification Access';
  static const String notificationPermissionMessage =
      'Milo needs notification access to remind you about your medications. This is used only for your scheduled medication reminders.';
  static const String storagePermissionTitle = 'Storage Access';
  static const String storagePermissionMessage =
      'Milo needs storage access to save your memories on your device. Your voice memories are stored only on your device and are never shared without your permission.';
  static const String permissionRequiredTitle = 'Permission Required';
  static const String permissionRequiredMessage =
      'This feature requires permission to use your ';
  static const String permissionSettingsDirections =
      'Please enable this permission in your device settings.';
  static const String openSettingsButtonLabel = 'Open Settings';

  // Cloud Storage
  static const String backupToCloudButtonLabel = 'Back Up to Cloud';
  static const String selectCloudProviderTitle = 'Select Cloud Provider';
  static const String googleDriveOption = 'Google Drive';
  static const String oneDriveOption = 'OneDrive';
  static const String iCloudDriveOption = 'iCloud Drive';
  static const String backupInProgressMessage = 'Backing up your memory...';
  static const String backupSuccessMessage = 'Memory backed up successfully';
  static const String backupFailureMessage = 'Failed to back up memory';

  // Error messages
  static const String genericErrorTitle = 'Something went wrong';
  static const String genericErrorMessage =
      'We encountered an issue. Please try again.';
  static const String audioRecordingErrorMessage =
      'Error recording audio. Please check your microphone permission and try again.';
  static const String audioPlaybackErrorMessage =
      'Error playing audio. The file may be corrupted.';
  static const String storageErrorMessage =
      'Error accessing storage. Please check your storage permission.';
  static const String cloudAuthErrorMessage =
      'Error authenticating with cloud provider. Please try again.';
  static const String cloudUploadErrorMessage =
      'Error uploading to cloud. Please check your internet connection and try again.';
  static const String permissionDeniedErrorMessage =
      'Permission denied. Some features may not work properly.';
  static const String notificationErrorMessage =
      'Error scheduling notification. Please check your notification permission.';

  // Buttons & Actions
  static const String retryButtonLabel = 'Retry';
  static const String okButtonLabel = 'OK';
  static const String doneButtonLabel = 'Done';
  static const String backButtonLabel = 'Back';
  static const String nextButtonLabel = 'Next';
  static const String saveButtonLabel = 'Save';
  static const String deleteButtonLabel = 'Delete';
  static const String editButtonLabel = 'Edit';
  static const String closeButtonLabel = 'Close';

  // Accessibility labels
  static const String microphoneButtonA11yLabel = 'Record a new memory';
  static const String playButtonA11yLabel = 'Play recording';
  static const String pauseButtonA11yLabel = 'Pause recording';
  static const String deleteButtonA11yLabel = 'Delete recording';
  static const String addMedicationButtonA11yLabel = 'Add a new medication';
  static const String messageListA11yLabel = 'List of caregiver messages';
  static const String medicationListA11yLabel = 'List of medications';
  static const String journalListA11yLabel = 'List of recorded memories';
}