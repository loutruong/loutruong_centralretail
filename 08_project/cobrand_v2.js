/**
 * Cobrand QR automation, v2: tabs "Cobrand - QR Generic Management (v2)" and
 * "Cobrand - QR Store Management (v2)". No short links: each QR encodes full_link directly.
 * v1 (Short.io short links) is kept in "Cobrand v1.gs" for reference but no longer runs.
 * Tabs and folders are found by ID, so they can be renamed or moved freely.
 *
 * Both tabs have the same columns:
 * A create-time_link, B modify-time_link, C landing-page_link (trigger point), D full_link,
 * E short_link (not used), F qr_link, G qr-folder_link, H utm_campaign, I utm_source, J utm_term,
 * K PartnerId.
 * Header colors follow the sheet's rule: blue = typed in by people (C, I, J), black = filled in by
 * the script (A, B, D, F, G, H, K), grey with strikethrough = not used (E).
 *
 * For each row:
 * - utm_campaign and PartnerId are fixed to "central": filled in once C has a link, and put back if
 *   someone changes them, so a typo there can't change full_link or make a QR outdated.
 * - D (full_link) = C + the parameters, filled in as soon as the row is edited. A = first time,
 *   B = every change.
 * - Once C and every parameter are filled in (Store: and the row matches the Dictionary), the row
 *   gets a QR file that encodes D (link in F), in its folder (link in G). The columns can be filled
 *   in any order. QRs are made one at a time, about 5 seconds each: F shows "Making QR..." until
 *   the row's turn (links appear in groups every ~20 seconds), and the backup sweep finishes what
 *   a run couldn't do in its 4.5 minutes.
 * - QR files are never changed or replaced, because they may already be printed or sent out. If D
 *   changes after the QR was made, F gets a note; clearing F makes a new QR for the current link.
 *
 * Generic: QRs go in "Co-brand generic (v2)", named "<utm_source> <utm_term> QR".
 * Store: utm_source is GOH, MNG or TPS (utm_term = one of that BU's store ids in the Dictionary)
 * or CBS (utm_term = a CBS BU code or brand name from the Dictionary: CRS or Crocs). QRs go in
 * "Co-brand store (v2)":
 * - GOH: folder "GO!", named "GO! <Store Name> QR"
 * - MNG: folder "go!", named "go! <Store Name> QR"
 * - TPS: folder "TOP", named "TOP <Store Name> QR"
 *   Exceptions in STORE_FILED_AS keep their own BU in the row but are filed and named as another
 *   BU: Dan Phuong is entered as TPS 157 and gets "GO! Dan Phuong QR" in "GO!".
 * - CBS: folder "CBS", named "<Brand> QR"; brands in CBS_BRAND_FOLDERS (Kubo) get their own folder
 * Store names get a capital first letter on each word (DONG NAI -> Dong Nai). A Store row that
 * doesn't match the Dictionary gets no QR until it's fixed; the note on F says why.
 *
 * Entry points (same names v1 used, so the existing triggers now run v2):
 * - cobrandOnEdit: called from onEdit in Code.gs (simple trigger) on every edit by anyone. Sets
 *   the fixed values, full_link and the timestamps right away. Needs no permissions.
 * - onEditCobrand: installable On-edit trigger. Makes the QR files.
 * - cobrandSweep: time-driven backup every minute. Catches up on anything the edit triggers missed,
 *   such as values written by the Sheets API or other tools, which never fire edit triggers.
 *
 * Keep this file free of top-level service calls (DriveApp, UrlFetchApp, ...): the simple onEdit
 * in Code.gs loads this file too, and such a call would make it fail.
 */

const QR2_TABS = [
	{ name: "Generic", sheetId: 548054734, qrPlace: qr2GenericPlace_ }, // Cobrand - QR Generic Management (v2)
	{ name: "Store", sheetId: 1895142664, qrPlace: qr2StorePlace_ }, // Cobrand - QR Store Management (v2)
]

// Columns, the same on both tabs.
const QR2_COL = {
	CREATE_TIME: 1, // A create-time_link
	MODIFY_TIME: 2, // B modify-time_link
	URL: 3, // C landing-page_link (trigger point)
	FULL: 4, // D full_link
	// E short_link: not used in v2
	QR: 6, // F qr_link
	FOLDER: 7, // G qr-folder_link
	SOURCE: 9, // I utm_source
	TERM: 10, // J utm_term
}

// Query parameters, in the order they are added to full_link.
const QR2_PARAMS = [
	{ name: "utm_campaign", col: 8, fixed: "central" }, // H, filled in automatically
	{ name: "utm_source", col: 9 }, // I
	{ name: "utm_term", col: 10 }, // J
	{ name: "PartnerId", col: 11, fixed: "central" }, // K, filled in automatically
]

const QR2 = {
	FIRST_DATA_ROW: 2, // row 1 = headers
	LAST_COL: 11, // column K
	INPUT_COLS: [3, 8, 9, 10, 11], // edits here update the row: C, I, J typed in; H, K fixed (restored)
	GENERIC_FOLDER_ID: "1gfJ42m262x7b3R0ntrlkUq_0ps_b1s4c", // "Co-brand generic (v2)"
	// Folders inside "Co-brand store (v2)", and the start of each Food BU's file names.
	STORE: {
		GOH: { folderId: "1loogTRYqO2SGNOBc0Vv2uIcFjrytF_y-", prefix: "GO!" }, // folder "GO!"
		MNG: { folderId: "1Q2mhFTCRFfTJS4-S927a8uoeD8dd3LcD", prefix: "go!" }, // folder "go!"
		TPS: { folderId: "1g0Urav-7TSoiolB-mLbfWZsgrGZDqI-y", prefix: "TOP" }, // folder "TOP"
		CBS: { folderId: "1Wa0XEQiorVGvzFokfwEVIgjeqZCCIOyG" }, // folder "CBS"
	},
	// CBS brands whose QRs go in a folder of their own in "Co-brand store (v2)" instead of "CBS".
	// Key: brand name as in the Dictionary (column R), lower case.
	CBS_BRAND_FOLDERS: {
		kubo: "1aX1bffhgTpcma1PMj5owsvSu7i6DZUBw", // folder "Kubo"
	},
	// Stores entered under their own BU (utm_source, utm_term and full_link stay as entered) whose QR
	// is filed and named as another BU. Key: "<bu code>|<store id>"; value: the BU to file it under.
	STORE_FILED_AS: {
		"TPS|157": "GOH", // Dan Phuong (Tops): "GO! Dan Phuong QR" in folder "GO!"
	},
	DICTIONARY_SHEET_ID: 227913922, // tab "Cobrand - QR Dictionary"
	QR_SIZE: 1000, // pixels
	SWEEP_MINUTES: 1, // backup sweep interval: 1, 5, 10, 15 or 30
	TIME_BUDGET_MS: 270 * 1000, // no new rows after 4.5 minutes; Apps Script stops a run at 6
	PROGRESS_MS: 20 * 1000, // during a batch, new QR links are written to the sheet this often
	TIME_ZONE: "Asia/Ho_Chi_Minh",
}

const QR2_OUTDATED_NOTE =
	"This QR was made for an earlier version of the link and was left unchanged. " +
	"To make a QR for the current link, clear this cell."

const QR2_PENDING = "Making QR..." // shown in F while a row waits for its QR

let qr2DictionaryCache_ = null // read once per run by qr2Dictionary_
const qr2FolderCache_ = {} // folders looked up once per run by qr2Folder_
let qr2Unflushed_ = false // F/G changes this run hasn't sent to the sheet yet (see qr2Flush_)

/**
 * Run once from the editor if the triggers are ever missing: Google asks for the permissions the QR
 * feature needs, then this creates the On-edit and backup triggers and checks the folders and the
 * QR service.
 */
function cobrandSetup() {
	const ids = [QR2.GENERIC_FOLDER_ID]
		.concat(Object.keys(QR2.STORE).map((k) => QR2.STORE[k].folderId))
		.concat(
			Object.keys(QR2.CBS_BRAND_FOLDERS).map((k) => QR2.CBS_BRAND_FOLDERS[k]),
		)
	ids.forEach((id) =>
		Logger.log("QR folder OK: " + DriveApp.getFolderById(id).getName()),
	)
	qr2EnsureTriggers_()
	const blob = qr2FetchQrBlob_("https://example.com", "setup-check.png")
	Logger.log("QR service OK (" + blob.getBytes().length + " bytes).")
}

/** Simple-trigger part, called from onEdit in Code.gs: fixed values, full_link and timestamps. */
function cobrandOnEdit(e) {
	const edit = qr2EditedRows_(e, QR2.INPUT_COLS)
	if (!edit) return
	const rows = edit.sheet
		.getRange(edit.startRow, 1, edit.endRow - edit.startRow + 1, QR2.LAST_COL)
		.getValues()
	const now = qr2Now_()
	rows.forEach((values, i) =>
		qr2UpdateLink_(edit.sheet, edit.startRow + i, values, now, true),
	)
}

/** Installable On-edit trigger: QR files for the rows an edit touched. */
function onEditCobrand(e) {
	const edit = qr2EditedRows_(e, QR2.INPUT_COLS.concat([QR2_COL.QR]))
	if (!edit) return

	// One run at a time, so quick edits on the same row can't create two QR files. If another run
	// stays busy (a big batch), this edit is left to the backup sweep, which goes through every row.
	const lock = LockService.getScriptLock()
	if (!lock.tryLock(60 * 1000)) return
	try {
		qr2EnsureTriggers_()
		const deadline = Date.now() + QR2.TIME_BUDGET_MS
		qr2UpdateQrs_(
			edit.tab,
			edit.sheet,
			edit.startRow,
			edit.endRow,
			true,
			deadline,
		)
	} finally {
		qr2Flush_() // QR links written before the next run can start
		lock.releaseLock()
	}
}

/** Time-driven backup: fixed values, full_link and QRs for every row of both tabs. */
function cobrandSweep() {
	const lock = LockService.getScriptLock()
	if (!lock.tryLock(10 * 1000)) return // another run is busy; the next sweep catches up
	try {
		qr2EnsureTriggers_()
		const deadline = Date.now() + QR2.TIME_BUDGET_MS
		const now = qr2Now_()
		QR2_TABS.forEach((tab) => {
			const sheet = qr2Sheet_(tab.sheetId)
			if (!sheet) return
			const first = QR2.FIRST_DATA_ROW
			const lastRow = sheet.getLastRow()
			if (lastRow < first) return
			const rows = sheet
				.getRange(first, 1, lastRow - first + 1, QR2.LAST_COL)
				.getValues()
			rows.forEach((values, i) =>
				qr2UpdateLink_(sheet, first + i, values, now, false),
			)
			qr2UpdateQrs_(tab, sheet, first, lastRow, false, deadline)
		})
	} finally {
		qr2Flush_() // QR links written before the next run can start
		lock.releaseLock()
	}
}

/** The tab, sheet and data rows an edit touched in the given columns, or null. */
function qr2EditedRows_(e, cols) {
	if (!e || !e.range) return null
	const range = e.range
	const sheet = range.getSheet()
	const tab = QR2_TABS.filter((t) => t.sheetId === sheet.getSheetId())[0]
	if (!tab) return null

	const firstCol = range.getColumn()
	const lastCol = range.getLastColumn()
	if (!cols.some((c) => c >= firstCol && c <= lastCol)) return null

	const startRow = Math.max(range.getRow(), QR2.FIRST_DATA_ROW)
	const endRow = Math.min(range.getLastRow(), sheet.getLastRow())
	if (endRow < startRow) return null
	return { tab: tab, sheet: sheet, startRow: startRow, endRow: endRow }
}

/**
 * Fills the fixed values and full_link (D) from C + the parameters. On an edit (touch = true) it
 * also stamps A (first time) and B (every change); the sweep (touch = false) only stamps when it
 * actually fixes D. Updates `values` in place.
 */
function qr2UpdateLink_(sheet, row, values, now, touch) {
	const baseUrl = String(values[QR2_COL.URL - 1]).trim()
	const oldFull = String(values[QR2_COL.FULL - 1]).trim()

	// No landing page: clear full_link. The QR link and file are left as they are.
	if (!baseUrl) {
		if (oldFull) {
			sheet.getRange(row, QR2_COL.FULL).setValue("")
			values[QR2_COL.FULL - 1] = ""
		}
		return
	}

	qr2FillFixed_(sheet, row, values)
	const fullUrl = qr2BuildUrl_(baseUrl, values)
	const changed = fullUrl !== oldFull
	if (!touch && !changed) return

	if (values[QR2_COL.CREATE_TIME - 1] === "") {
		sheet.getRange(row, QR2_COL.CREATE_TIME).setValue(now)
		values[QR2_COL.CREATE_TIME - 1] = now
	}
	sheet.getRange(row, QR2_COL.MODIFY_TIME).setValue(now)
	if (changed) {
		sheet.getRange(row, QR2_COL.FULL).setValue(fullUrl)
		values[QR2_COL.FULL - 1] = fullUrl
	}
}

/**
 * Sets the fixed parameters (utm_campaign, PartnerId = central) wherever they're empty or were
 * changed. Updates `values` in place.
 */
function qr2FillFixed_(sheet, row, values) {
	QR2_PARAMS.forEach((p) => {
		if (p.fixed && String(values[p.col - 1]).trim() !== p.fixed) {
			sheet.getRange(row, p.col).setValue(p.fixed)
			values[p.col - 1] = p.fixed
		}
	})
}

/**
 * QR (F) and folder link (G) for each row in startRow..endRow; see the header comment. With
 * checkExisting (edits only), an existing QR is also checked against the row, and its cell gets a
 * note when the link has moved on.
 */
function qr2UpdateQrs_(tab, sheet, startRow, endRow, checkExisting, deadline) {
	const count = endRow - startRow + 1
	const rows = sheet.getRange(startRow, 1, count, QR2.LAST_COL).getValues()
	const notes = sheet.getRange(startRow, QR2_COL.QR, count, 1).getNotes()
	const jobs = [] // rows that get a new QR

	for (let i = 0; i < count; i++) {
		if (Date.now() > deadline) break // out of time; the next sweep carries on
		const row = startRow + i
		const values = rows[i]
		const note = notes[i][0]
		const qrCell = sheet.getRange(row, QR2_COL.QR)
		const setNote = (text) => {
			if (text !== note) qrCell.setNote(text)
		}

		const baseUrl = String(values[QR2_COL.URL - 1]).trim()
		if (baseUrl) qr2FillFixed_(sheet, row, values)
		// Built from the inputs, not read from D, so this never depends on D being updated first.
		const fullUrl = baseUrl ? qr2BuildUrl_(baseUrl, values) : ""
		const qrText = String(values[QR2_COL.QR - 1])
		const fileId = qr2DriveFileId_(qrText)

		// A QR that already exists is never changed; it only gets a note when the link moves on.
		if (fileId) {
			if (checkExisting) qr2FlagQr_(fileId, fullUrl, setNote)
			continue
		}

		// A new QR waits until C and every parameter are filled in (and, on Store, the row matches the
		// Dictionary). A row that stopped qualifying while it waited loses its "Making QR" mark.
		const complete =
			baseUrl !== "" &&
			QR2_PARAMS.every((p) => String(values[p.col - 1]).trim() !== "")
		const place = complete ? tab.qrPlace(values) : null
		if (!place || place.error) {
			if (qrText === QR2_PENDING) {
				qrCell.setValue("")
				qr2Unflushed_ = true
			}
			if (place) setNote("No QR yet: " + place.error + ".")
			continue
		}
		if (qrText !== QR2_PENDING) {
			qrCell.setValue(QR2_PENDING)
			qr2Unflushed_ = true
		}
		jobs.push({ row: row, fullUrl: fullUrl, place: place, setNote: setNote })
	}
	if (!jobs.length) return

	// Show the marks right away, then make the QRs one by one; new links are written out every
	// PROGRESS_MS (each write-out takes a few seconds on this spreadsheet, so not after every QR).
	// Rows still waiting when time runs out keep the mark until the next sweep.
	qr2Flush_()
	let lastFlush = Date.now()
	for (let j = 0; j < jobs.length; j++) {
		if (Date.now() > deadline) return
		const job = jobs[j]
		qr2CreateQr_(sheet, job.row, job.fullUrl, job.place, job.setNote)
		if (Date.now() - lastFlush >= QR2.PROGRESS_MS) {
			qr2Flush_()
			lastFlush = Date.now()
		}
	}
}

/** Makes the QR file for `fullUrl` in place.folderId, named place.name; links in F and G. */
function qr2CreateQr_(sheet, row, fullUrl, place, setNote) {
	const qrCell = sheet.getRange(row, QR2_COL.QR)
	qr2Unflushed_ = true
	try {
		const blob = qr2FetchQrBlob_(fullUrl, place.name + ".png")
		const folder = qr2Folder_(place.folderId)
		const file = folder.createFile(blob)
		qrCell.setValue(file.getUrl())
		setNote("")
		sheet.getRange(row, QR2_COL.FOLDER).setValue(folder.getUrl())
		try {
			file.setDescription(fullUrl) // record of what the QR encodes
		} catch (err) {
			// not essential
		}
	} catch (err) {
		qrCell.setValue("QR error (" + qr2Now_() + "): " + err.message) // the next edit or sweep retries
	}
}

/**
 * Sends pending F/G changes to the sheet, so people see them and a run that starts next reads them.
 * Skipped when there are none: a flush takes a few seconds on this spreadsheet.
 */
function qr2Flush_() {
	if (!qr2Unflushed_) return
	SpreadsheetApp.flush()
	qr2Unflushed_ = false
}

/** A QR folder, looked up once per run. */
function qr2Folder_(folderId) {
	if (!qr2FolderCache_[folderId])
		qr2FolderCache_[folderId] = DriveApp.getFolderById(folderId)
	return qr2FolderCache_[folderId]
}

/** Adds or clears the "QR is for an earlier link" note. Never touches the QR file itself. */
function qr2FlagQr_(fileId, fullUrl, setNote) {
	let encoded
	try {
		encoded = DriveApp.getFileById(fileId).getDescription()
	} catch (err) {
		return // the file can't be read; leave the cell as it is
	}
	if (!encoded) return // not made by this script, so there's nothing to compare with
	setNote(fullUrl !== "" && encoded === fullUrl ? "" : QR2_OUTDATED_NOTE)
}

/** Generic: the Co-brand generic (v2) folder, named "<utm_source> <utm_term> QR". */
function qr2GenericPlace_(values) {
	const source = String(values[QR2_COL.SOURCE - 1]).trim()
	const term = String(values[QR2_COL.TERM - 1]).trim()
	return { folderId: QR2.GENERIC_FOLDER_ID, name: source + " " + term + " QR" }
}

/**
 * Store: folder and file name from the Dictionary. Returns { folderId, name } or { error }.
 * - GOH, MNG, TPS + a store id of that BU: the BU's folder, "<prefix> <Store Name> QR" (or the
 *   folder and prefix of the BU in STORE_FILED_AS for that store).
 * - CBS + a CBS BU code or brand name (CRS or Crocs): the CBS folder (or the brand's own folder
 *   from CBS_BRAND_FOLDERS), "<Brand> QR".
 */
function qr2StorePlace_(values) {
	const dict = qr2Dictionary_()
	const source = String(values[QR2_COL.SOURCE - 1])
		.trim()
		.toUpperCase()
	const term = String(values[QR2_COL.TERM - 1]).trim()

	if (source === "CBS") {
		const brand = dict.cbsBrands[term.toLowerCase()]
		if (!brand) {
			return {
				error:
					'utm_term "' +
					term +
					'" is not a CBS BU code or brand in the Dictionary (' +
					dict.cbsCodes.join(", ") +
					")",
			}
		}
		const folderId =
			QR2.CBS_BRAND_FOLDERS[brand.toLowerCase()] || QR2.STORE.CBS.folderId
		return { folderId: folderId, name: brand + " QR" }
	}

	const bu = QR2.STORE[source]
	if (!bu || !bu.prefix) {
		return {
			error: 'utm_source "' + source + '" must be one of GOH, MNG, TPS, CBS',
		}
	}
	const key = source + "|" + term.toUpperCase()
	const store = dict.stores[key]
	if (!store)
		return {
			error:
				'utm_term "' +
				term +
				'" is not a ' +
				source +
				" store id in the Dictionary",
		}
	const filedAs = QR2.STORE[QR2.STORE_FILED_AS[key]] || bu
	return {
		folderId: filedAs.folderId,
		name: filedAs.prefix + " " + qr2StoreName_(store) + " QR",
	}
}

/** "DONG NAI" -> "Dong Nai". A leading "go!" (mini GO! names) is dropped; the prefix adds it back. */
function qr2StoreName_(name) {
	return name
		.replace(/^\s*go!\s*/i, "")
		.trim()
		.toLowerCase()
		.replace(/(^|\s)(\S)/g, (m, space, letter) => space + letter.toUpperCase())
}

/**
 * Stores (K bu code, L store id, N name) and CBS brands (P BU group, Q BU code, R Brand) from the
 * Dictionary.
 */
function qr2Dictionary_() {
	if (qr2DictionaryCache_) return qr2DictionaryCache_
	const sheet = qr2Sheet_(QR2.DICTIONARY_SHEET_ID)
	const stores = {}
	const cbsBrands = {} // lower-case BU code or brand -> brand as written in the Dictionary
	const cbsCodes = []
	const lastRow = sheet ? sheet.getLastRow() : 0
	if (lastRow >= 2) {
		// Columns J..R as shown, so store ids stay text.
		sheet
			.getRange(2, 10, lastRow - 1, 9)
			.getDisplayValues()
			.forEach((r) => {
				const bu = r[1].trim().toUpperCase() // K
				const storeId = r[2].trim().toUpperCase() // L
				const storeName = r[4].trim() // N
				if (bu && storeId && storeName) stores[bu + "|" + storeId] = storeName
				const group = r[6].trim().toLowerCase() // P
				const code = r[7].trim() // Q
				const brand = r[8].trim() // R
				if (brand && group === "cbs") {
					cbsBrands[brand.toLowerCase()] = brand
					if (code) cbsBrands[code.toLowerCase()] = brand
					cbsCodes.push(code || brand)
				}
			})
	}
	qr2DictionaryCache_ = {
		stores: stores,
		cbsBrands: cbsBrands,
		cbsCodes: cbsCodes,
	}
	return qr2DictionaryCache_
}

/**
 * Creates the On-edit trigger and the backup trigger for this account if they're missing, and
 * keeps the backup trigger on SWEEP_MINUTES.
 */
function qr2EnsureTriggers_() {
	const triggers = ScriptApp.getProjectTriggers()
	if (!triggers.some((t) => t.getHandlerFunction() === "onEditCobrand")) {
		ScriptApp.newTrigger("onEditCobrand")
			.forSpreadsheet(SpreadsheetApp.getActive())
			.onEdit()
			.create()
		Logger.log("Created the On-edit trigger for onEditCobrand.")
	}

	// A trigger's interval can't be read back, so the one set up here is noted in a script property.
	const props = PropertiesService.getScriptProperties()
	const minutes = String(QR2.SWEEP_MINUTES)
	const sweeps = triggers.filter(
		(t) => t.getHandlerFunction() === "cobrandSweep",
	)
	if (sweeps.length && props.getProperty("COBRAND_SWEEP_MINUTES") === minutes)
		return

	// Missing, or on another interval: add the new trigger first, then remove the old ones.
	ScriptApp.newTrigger("cobrandSweep")
		.timeBased()
		.everyMinutes(QR2.SWEEP_MINUTES)
		.create()
	sweeps.forEach((t) => ScriptApp.deleteTrigger(t))
	props.setProperty("COBRAND_SWEEP_MINUTES", minutes)
	Logger.log(
		"Backup trigger for cobrandSweep: every " + minutes + " minute(s).",
	)
}

/** The tab with this sheet ID, or null. */
function qr2Sheet_(sheetId) {
	const ss = SpreadsheetApp.getActive()
	if (!ss) return null
	return ss.getSheets().filter((s) => s.getSheetId() === sheetId)[0] || null
}

function qr2Now_() {
	return Utilities.formatDate(new Date(), QR2.TIME_ZONE, "yyyy-MM-dd HH:mm:ss")
}

/** landing-page_link + the filled-in parameters, in column order (same rule as Link master). */
function qr2BuildUrl_(baseUrl, values) {
	let url = baseUrl
	let hash = ""
	const hashAt = url.indexOf("#")
	if (hashAt !== -1) {
		hash = url.slice(hashAt)
		url = url.slice(0, hashAt)
	}
	// A bare domain gets a trailing slash: https://cards.vpbank.com.vn/?...
	if (/^https?:\/\/[^\/?]+$/i.test(url)) url += "/"

	const parts = []
	QR2_PARAMS.forEach((p) => {
		const value = String(values[p.col - 1]).trim()
		if (value) parts.push(p.name + "=" + encodeURIComponent(value))
	})
	if (parts.length) {
		const sep = url.indexOf("?") === -1 ? "?" : /[?&]$/.test(url) ? "" : "&"
		url += sep + parts.join("&")
	}
	return url + hash
}

/** PNG QR code for `text`, made by the QuickChart QR service. */
function qr2FetchQrBlob_(text, fileName) {
	const url =
		"https://quickchart.io/qr?text=" +
		encodeURIComponent(text) +
		"&size=" +
		QR2.QR_SIZE +
		"&margin=4&ecLevel=M&format=png"
	const res = UrlFetchApp.fetch(url, { muteHttpExceptions: true })
	if (res.getResponseCode() !== 200) {
		throw new Error("QR service returned HTTP " + res.getResponseCode())
	}
	return res.getBlob().setName(fileName).setContentType("image/png")
}

/** The Drive file ID inside a link such as https://drive.google.com/file/d/<id>/view, or ''. */
function qr2DriveFileId_(text) {
	const m =
		text.match(/\/d\/([A-Za-z0-9_-]{20,})/) ||
		text.match(/[?&]id=([A-Za-z0-9_-]{20,})/)
	return m ? m[1] : ""
}
