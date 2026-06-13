const SHENGHAI_FEEDBACK = {
  spreadsheetId: "REPLACE_WITH_SPREADSHEET_ID",
  sheetName: "Feedback",
  notificationEmail: "shanewn931131@gmail.com",
  sendNotification: true
};

function doGet() {
  return jsonResponse_({
    ok: true,
    service: "shenghai-feedback",
    message: "Shenghai feedback endpoint is running."
  });
}

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return jsonResponse_({ ok: false, message: "Missing POST body." });
    }

    const payload = JSON.parse(e.postData.contents);
    const validationError = validatePayload_(payload);
    if (validationError) {
      return jsonResponse_({ ok: false, message: validationError });
    }

    if (String(payload.website || "").trim() !== "") {
      return jsonResponse_({ ok: true, message: "Accepted." });
    }

    const sheet = openFeedbackSheet_();
    ensureHeaderRow_(sheet);

    const row = [
      new Date(),
      safeCell_(payload.category),
      safeCell_(payload.summary),
      safeCell_(payload.details),
      safeCell_(payload.replyEmail || ""),
      safeCell_(payload.currentScreenKey),
      safeCell_(payload.currentScreenTitle),
      safeCell_(payload.appVersion),
      safeCell_(payload.buildNumber),
      safeCell_(payload.platform),
      safeCell_(payload.osVersion),
      safeCell_(payload.displayLanguage),
      safeCell_(payload.appStage || ""),
      safeCell_(payload.source || ""),
      "new",
      ""
    ];

    sheet.appendRow(row);
    const rowNumber = sheet.getLastRow();

    if (SHENGHAI_FEEDBACK.sendNotification) {
      MailApp.sendEmail(
        SHENGHAI_FEEDBACK.notificationEmail,
        "[Shenghai Feedback] " + payload.category + " | " + payload.summary,
        buildNotificationBody_(payload, rowNumber)
      );
    }

    return jsonResponse_({
      ok: true,
      message: "Feedback saved.",
      rowNumber: rowNumber
    });
  } catch (error) {
    return jsonResponse_({
      ok: false,
      message: String(error && error.message ? error.message : error)
    });
  }
}

function openFeedbackSheet_() {
  if (SHENGHAI_FEEDBACK.spreadsheetId.indexOf("REPLACE_WITH") !== -1) {
    throw new Error("Spreadsheet ID is not configured.");
  }

  const spreadsheet = SpreadsheetApp.openById(SHENGHAI_FEEDBACK.spreadsheetId);
  const sheet = spreadsheet.getSheetByName(SHENGHAI_FEEDBACK.sheetName);
  if (sheet) {
    return sheet;
  }
  return spreadsheet.insertSheet(SHENGHAI_FEEDBACK.sheetName);
}

function ensureHeaderRow_(sheet) {
  if (sheet.getLastRow() > 0) {
    return;
  }

  sheet.appendRow([
    "Created At",
    "Category",
    "Summary",
    "Details",
    "Reply Email",
    "Current Screen Key",
    "Current Screen Title",
    "App Version",
    "Build Number",
    "Platform",
    "OS Version",
    "Display Language",
    "App Stage",
    "Source",
    "Status",
    "Internal Notes"
  ]);
}

function validatePayload_(payload) {
  if (!payload) {
    return "Missing JSON payload.";
  }

  if (!payload.summary || String(payload.summary).trim() === "") {
    return "Summary is required.";
  }

  if (!payload.details || String(payload.details).trim() === "") {
    return "Details are required.";
  }

  if (String(payload.summary).length > 160) {
    return "Summary is too long.";
  }

  if (String(payload.details).length > 4000) {
    return "Details are too long.";
  }

  return null;
}

function safeCell_(value) {
  const text = String(value == null ? "" : value);
  if (/^[=+\\-@]/.test(text)) {
    return "'" + text;
  }
  return text;
}

function buildNotificationBody_(payload, rowNumber) {
  return [
    "New Shenghai feedback",
    "",
    "Row: " + rowNumber,
    "Category: " + payload.category,
    "Summary: " + payload.summary,
    "Reply Email: " + (payload.replyEmail || ""),
    "Current Screen: " + payload.currentScreenTitle + " (" + payload.currentScreenKey + ")",
    "App Version: " + payload.appVersion + " (" + payload.buildNumber + ")",
    "Platform: " + payload.platform,
    "OS Version: " + payload.osVersion,
    "Display Language: " + payload.displayLanguage,
    "Submitted At: " + payload.submittedAt,
    "",
    "Details:",
    payload.details
  ].join("\\n");
}

function jsonResponse_(value) {
  return ContentService
    .createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}
