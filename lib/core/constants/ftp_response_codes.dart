/// Standard FTP reply codes as defined by RFC 959 and related RFCs.
///
/// Each constant maps a symbolic name to the numeric code so the rest of
/// the codebase never has to hard-code "magic numbers" when building
/// responses. Grouped by category for readability.
class FtpResponseCodes {
  FtpResponseCodes._();

  // ---- 1xx : Positive Preliminary reply -----------------------------
  static const int fileStatusOk = 150; // File status okay, opening data conn

  // ---- 2xx : Positive Completion reply -------------------------------
  static const int commandOkay = 200;
  static const int commandNotImplementedSuperfluous = 202;
  static const int systemStatus = 211;
  static const int directoryStatus = 212;
  static const int fileStatus = 213;
  static const int helpMessage = 214;
  static const int systemType = 215;
  static const int serviceReady = 220;
  static const int closingControlConnection = 221;
  static const int dataConnectionOpen = 225;
  static const int closingDataConnection = 226;
  static const int enteringPassiveMode = 227;
  static const int enteringPortMode = 200;
  static const int loginSuccessful = 230;
  static const int requestedFileActionOkay = 250;
  static const int pathnameCreated = 257;

  // ---- 3xx : Positive Intermediate reply -----------------------------
  static const int usernameOkNeedPassword = 331;
  static const int needAccountForLogin = 332;
  static const int requestedFileActionPendingFurtherInfo = 350;

  // ---- 4xx : Transient Negative Completion reply ----------------------
  static const int serviceNotAvailable = 421;
  static const int cantOpenDataConnection = 425;
  static const int connectionClosedTransferAborted = 426;
  static const int fileActionNotTaken = 450;
  static const int actionAbortedLocalError = 451;
  static const int insufficientStorage = 452;

  // ---- 5xx : Permanent Negative Completion reply -----------------------
  static const int syntaxErrorUnrecognizedCommand = 500;
  static const int syntaxErrorInParameters = 501;
  static const int commandNotImplemented = 502;
  static const int badSequenceOfCommands = 503;
  static const int commandNotImplementedForParameter = 504;
  static const int notLoggedIn = 530;
  static const int needAccountForStoringFiles = 532;
  static const int fileActionNotTakenNoAccess = 550;
  static const int actionAbortedPageTypeUnknown = 551;
  static const int actionAbortedExceededStorage = 552;
  static const int fileNameNotAllowed = 553;
}
