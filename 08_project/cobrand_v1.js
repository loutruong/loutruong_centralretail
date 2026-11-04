/**
 * v1 - INACTIVE, kept for reference. v2 (Cobrand v2.gs) replaced it: no short links, new tabs and
 * folders. The entry points below end in V1 so no trigger calls them any more; to run v1 again,
 * swap the names of its entry points with the v2 ones.
 *
 * Cobrand QR automation for the Generic and Store tabs (COBRAND_TABS); Link master is handled by
 * Code.gs. Tabs are found by sheet ID, so they can be renamed freely.
 *
 * For each row:
 * - utm_campaign and PartnerId are always "central": filled in automatically once C has a link.
 * - D (link_full) = C + the parameters, filled in as soon as the row is edited.
 * - Once C and every parameter are filled in, the row gets a Short.io short link in E that
 *   redirects to D, and a QR file (link in F) that encodes the short link.
 * - When D changes later, the short link is pointed at the new D. The QR image never changes, so
 *   printed QRs keep working and follow the sheet. The note on E shows where the short link
 *   currently redirects.
 *
 * Generic tab: QRs go in the "Co-brand generic" folder, named <utm_source>_<utm_term>.png.
 *
 * QR files are never changed or replaced. Rows whose QR was made before short links existed
 * (E empty, F filled) keep that fixed QR; their F cell gets a note when the link moves on.
 * Clearing F makes a new QR for the row's short link; clearing E and F makes a new short link and QR.
 * A short link that appears in more than one row (a copied row) is not updated until only one
 * row has it.
 *
 * Store tab: utm_source is a Food BU code from the Dictionary (GOH, MNG, TPS) or CBS.
 * - Food: utm_term = a store id of that BU in the Dictionary; the QR goes in the BU's folder and
 *   is named after the store.
 * - CBS: utm_term = a CBS brand name from the Dictionary; the QR goes in the CBS folder and is
 *   named after the brand.
 * qr_link_folder gets the folder's link. A row that doesn't match the Dictionary gets no short link
 * or QR (and its short link isn't updated) until it's fixed; the note on E says why.
 *
 * Setup: put the Short.io secret API key in Project Settings > Script properties as
 * SHORTIO_API_KEY. Short links go on COBRAND_SHORTIO.DOMAIN (a SHORTIO_DOMAIN script property
 * overrides it). Printed QRs depend on that domain, so keep it once QRs are out.
 *
 * Entry points:
 * - cobrandOnEdit: called from onEdit in Code.gs (simple trigger), which runs on every edit by
 *   anyone. Fills link_full and the timestamps right away. Needs no permissions.
 * - onEditCobrand: installable On-edit trigger (created by cobrandSetup). Short links and QR files.
 * - cobrandSweep: time-driven backup every minute (created automatically). Catches up on anything
 *   the edit triggers missed, such as values written by the Sheets API or other tools, which
 *   never fire edit triggers.
 *
 * Keep this file free of top-level service calls (DriveApp, UrlFetchApp, ...): the simple onEdit
 * in Code.gs loads this file too, and such a call would make it fail.
 */

const COBRAND_TABS = [
	{
		name: "Generic", // tab "Cobrand - QR Generic Management"
		sheetId: 352011348,
		firstDataRow: 2, // row 1 = headers and notes
		lastCol: 10, // column J
		col: {
			CREATE_TIME: 1, // A link_create_time
			MODIFY_TIME: 2, // B link_modify_time
			URL: 3, // C link_original (trigger point)
			FULL: 4, // D link_full
			SHORT: 5, // E short_url
			QR: 6, // F qr_link
			SOURCE: 8, // H utm_source = source name
			TERM: 9, // I utm_term = channel name
		},
		// Query parameters, in the order they are added to link_full.
		params: [
			{ name: "utm_campaign", col: 7, fixed: "central" }, // G, filled in automatically
			{ name: "utm_source", col: 8 }, // H
			{ name: "utm_term", col: 9 }, // I
			{ name: "PartnerId", col: 10, fixed: "central" }, // J, filled in automatically
		],
		inputCols: [3, 7, 8, 9, 10], // the blue input area: C and G-J
		qrFolderId: "1GLOC-1BlgF49Br45PmwwmDgZluVZ2EX2", // Drive folder "Co-brand generic" (found by ID, so renaming or moving it is fine)
		qrPlace: cobrandGenericQrPlace_, // QR file named <utm_source>_<utm_term>
	},
	{
		name: "Store", // tab "Cobrand - QR Store Management"
		sheetId: 214027546,
		firstDataRow: 2, // row 1 = headers
		lastCol: 11, // column K
		col: {
			CREATE_TIME: 1, // A link_create_time
			MODIFY_TIME: 2, // B link_modify_time
			URL: 3, // C link_original (trigger point)
			FULL: 4, // D link_full
			SHORT: 5, // E short_url
			QR: 6, // F qr_link
			QR_FOLDER: 7, // G qr_link_folder
			BU: 9, // I utm_source = GOH, MNG, TPS or CBS
			TERM: 10, // J utm_term = store id (Food) or brand name (CBS)
		},
		params: [
			{ name: "utm_campaign", col: 8, fixed: "central" }, // H, filled in automatically
			{ name: "utm_source", col: 9 }, // I
			{ name: "utm_term", col: 10 }, // J
			{ name: "PartnerId", col: 11, fixed: "central" }, // K, filled in automatically
		],
		inputCols: [3, 8, 9, 10, 11], // the blue input area: C and H-K
		qrPlace: cobrandStoreQrPlace_, // folder and file name come from the Dictionary
	},
]

const COBRAND_STORE = {
	DICTIONARY_SHEET_ID: 227913922, // tab "Cobrand - QR Dictionary"
	// QR folders inside "Co-brand store": one per Food BU, one for all CBS brands.
	FOLDERS: {
		GOH: "1gsOqbFNBezDJBEWjGSNGZA0pj49Elk_o", // GO!
		MNG: "16W6aWqwQAAyaZLz5ZbO0HTC-rb7ynyk6", // mini GO!
		TPS: "1NzW2m5IAMrhwiqnR_xVklwqfEAv8q7hG", // Tops Market
		CBS: "1fcsFr1vlpol2fgyAjKAkATCgIU3ujmmL", // CBS
	},
}

let cobrandDictionaryCache_ = null // read once per run by cobrandDictionary_

const COBRAND = {
	QR_SIZE: 1000, // pixels
	SWEEP_MINUTES: 1, // backup sweep interval: 1, 5, 10, 15 or 30
	TIME_BUDGET_MS: 270 * 1000, // no new rows after 4.5 minutes; Apps Script stops a run at 6
	TIME_ZONE: "Asia/Ho_Chi_Minh",
}

const COBRAND_SHORTIO = {
	API: "https://api.short.io",
	KEY_PROPERTY: "SHORTIO_API_KEY",
	DOMAIN: "crv.loutruong.com", // domain of the short links (and so of every printed QR)
	DOMAIN_PROPERTY: "SHORTIO_DOMAIN", // optional script property that overrides DOMAIN
	REDIRECT_TYPE: 302, // temporary redirect: phones don't cache it, so a new destination works at once
}

const COBRAND_NOTE = {
	STATIC_OUTDATED:
		"This QR was made for an earlier version of the link and was left unchanged. " +
		"To make a QR for the current link, clear this cell.",
	QR_MISMATCH:
		"This QR doesn't encode the short link in E and was left unchanged. " +
		"To make a QR for the short link, clear this cell.",
	NOT_SHORT:
		"This isn't a short link, so it can't be kept up to date. Clear this cell to create one.",
}

/**
 * Run once from the editor. Google asks for the permissions the QR feature needs, then this
 * creates the On-edit trigger and the backup trigger (only if they don't exist yet) and checks
 * the folders, the QR service and Short.io.
 */
function cobrandSetupV1() {
	const folderIds = COBRAND_TABS.filter((t) => t.qrFolderId).map(
		(t) => t.qrFolderId,
	)
	Object.keys(COBRAND_STORE.FOLDERS).forEach((k) =>
		folderIds.push(COBRAND_STORE.FOLDERS[k]),
	)
	folderIds.forEach((id) =>
		Logger.log("QR folder OK: " + DriveApp.getFolderById(id).getName()),
	)

	cobrandEnsureTriggers_()

	const blob = cobrandFetchQrBlob_("https://example.com", "setup-check.png")
	Logger.log("QR service OK (" + blob.getBytes().length + " bytes).")

	try {
		Logger.log("Short.io OK, links go on " + cobrandShortio_().domain())
	} catch (err) {
		Logger.log("Short.io problem: " + err.message)
	}
}

/** Simple-trigger part, called from onEdit in Code.gs: link_full and timestamps. */
function cobrandOnEditV1(e) {
	const edit = cobrandEditedRows_(e, (tab) => tab.inputCols)
	if (!edit) return
	const tab = edit.tab
	const rows = edit.sheet
		.getRange(edit.startRow, 1, edit.endRow - edit.startRow + 1, tab.lastCol)
		.getValues()
	const now = cobrandNow_()
	rows.forEach((values, i) =>
		cobrandUpdateLink_(tab, edit.sheet, edit.startRow + i, values, now, true),
	)
}

/** Installable On-edit trigger: short links and QR files for the rows an edit touched. */
function onEditCobrandV1(e) {
	const edit = cobrandEditedRows_(e, (tab) =>
		tab.inputCols.concat([tab.col.SHORT, tab.col.QR]),
	)
	if (!edit) return

	// One run at a time, so quick edits on the same row can't create two short links or QR files.
	const lock = LockService.getScriptLock()
	lock.waitLock(60 * 1000)
	try {
		cobrandEnsureTriggers_()
		const deadline = Date.now() + COBRAND.TIME_BUDGET_MS
		cobrandUpdateRows_(
			edit.tab,
			edit.sheet,
			edit.startRow,
			edit.endRow,
			true,
			deadline,
		)
	} finally {
		lock.releaseLock()
	}
}

/** Time-driven backup: link_full, short links and QRs for every row of every tab. */
function cobrandSweepV1() {
	const lock = LockService.getScriptLock()
	if (!lock.tryLock(10 * 1000)) return // another run is busy; the next sweep catches up
	try {
		cobrandEnsureTriggers_() // also moves the backup trigger to a new SWEEP_MINUTES
		const deadline = Date.now() + COBRAND.TIME_BUDGET_MS
		const now = cobrandNow_()
		COBRAND_TABS.forEach((tab) => {
			const sheet = cobrandSheet_(tab)
			if (!sheet) return
			const first = tab.firstDataRow
			const lastRow = sheet.getLastRow()
			if (lastRow < first) return
			const rows = sheet
				.getRange(first, 1, lastRow - first + 1, tab.lastCol)
				.getValues()
			rows.forEach((values, i) =>
				cobrandUpdateLink_(tab, sheet, first + i, values, now, false),
			)
			cobrandUpdateRows_(tab, sheet, first, lastRow, false, deadline)
		})
	} finally {
		lock.releaseLock()
	}
}

/** The tab, sheet and data rows an edit touched in the columns colsOf(tab) lists, or null. */
function cobrandEditedRows_(e, colsOf) {
	if (!e || !e.range) return null
	const range = e.range
	const sheet = range.getSheet()
	const tab = COBRAND_TABS.filter((t) => t.sheetId === sheet.getSheetId())[0]
	if (!tab) return null

	const firstCol = range.getColumn()
	const lastCol = range.getLastColumn()
	if (!colsOf(tab).some((c) => c >= firstCol && c <= lastCol)) return null

	const startRow = Math.max(range.getRow(), tab.firstDataRow)
	const endRow = Math.min(range.getLastRow(), sheet.getLastRow())
	if (endRow < startRow) return null
	return { tab: tab, sheet: sheet, startRow: startRow, endRow: endRow }
}

/**
 * Fills link_full (D) from C + the parameters. On an edit (touch = true) it also stamps A (first
 * time) and B (every change); the sweep (touch = false) only stamps when it actually fixes D.
 * Updates `values` in place.
 */
function cobrandUpdateLink_(tab, sheet, row, values, now, touch) {
	const col = tab.col
	const baseUrl = String(values[col.URL - 1]).trim()
	const oldFull = String(values[col.FULL - 1]).trim()

	// No original link: clear link_full. The short link, QR link and file are left as they are.
	if (!baseUrl) {
		if (oldFull) {
			sheet.getRange(row, col.FULL).setValue("")
			values[col.FULL - 1] = ""
		}
		return
	}

	cobrandFillFixed_(tab, sheet, row, values)
	const fullUrl = cobrandBuildUrl_(tab, baseUrl, values)
	const changed = fullUrl !== oldFull
	if (!touch && !changed) return

	if (values[col.CREATE_TIME - 1] === "") {
		sheet.getRange(row, col.CREATE_TIME).setValue(now)
		values[col.CREATE_TIME - 1] = now
	}
	sheet.getRange(row, col.MODIFY_TIME).setValue(now)
	if (changed) {
		sheet.getRange(row, col.FULL).setValue(fullUrl)
		values[col.FULL - 1] = fullUrl
	}
}

/** Fills empty fixed parameters (utm_campaign, PartnerId = central). Updates `values` in place. */
function cobrandFillFixed_(tab, sheet, row, values) {
	tab.params.forEach((p) => {
		if (p.fixed && String(values[p.col - 1]).trim() === "") {
			sheet.getRange(row, p.col).setValue(p.fixed)
			values[p.col - 1] = p.fixed
		}
	})
}

/**
 * Short link (E) and QR (F) for each row in startRow..endRow; see the header comment. With
 * checkExisting (edits only), an existing QR is also checked against the row, and its cell gets a
 * note when it no longer fits.
 */
function cobrandUpdateRows_(
	tab,
	sheet,
	startRow,
	endRow,
	checkExisting,
	deadline,
) {
	const col = tab.col
	const count = endRow - startRow + 1
	const rows = sheet.getRange(startRow, 1, count, tab.lastCol).getValues()
	const shortNotes = sheet.getRange(startRow, col.SHORT, count, 1).getNotes()
	const shortRows = cobrandShortLinkRows_()
	const shortio = cobrandShortio_()

	for (let i = 0; i < count; i++) {
		if (Date.now() > deadline) return // out of time; the next sweep carries on
		const row = startRow + i
		const values = rows[i]
		const note = shortNotes[i][0]
		const shortCell = sheet.getRange(row, col.SHORT)
		const qrCell = sheet.getRange(row, col.QR)
		const setShortNote = (text) => {
			if (text !== note) shortCell.setNote(text)
		}

		const baseUrl = String(values[col.URL - 1]).trim()
		if (baseUrl) cobrandFillFixed_(tab, sheet, row, values)
		// Built from the inputs, not read from D, so this never depends on D being updated first.
		const fullUrl = baseUrl ? cobrandBuildUrl_(tab, baseUrl, values) : ""
		const complete =
			baseUrl !== "" &&
			tab.params.every((p) => String(values[p.col - 1]).trim() !== "")
		let shortUrl = String(values[col.SHORT - 1]).trim()
		const qrText = String(values[col.QR - 1]).trim()
		const hasQr = cobrandDriveFileId_(qrText) !== ""

		// A fixed QR from before short links (E empty, F filled) stays as it is.
		if (!shortUrl && hasQr) {
			if (checkExisting)
				cobrandFlagQr_(qrCell, qrText, fullUrl, COBRAND_NOTE.STATIC_OUTDATED)
			continue
		}
		// Short links and QRs wait until C and every parameter are filled in.
		if (!complete) continue

		// Where the QR goes and what it's called. A Store row that doesn't match the Dictionary is
		// left alone (no new link, no update) until it's fixed.
		const place = tab.qrPlace
			? tab.qrPlace(tab, values)
			: { folderId: tab.qrFolderId, name: "" }
		if (place.error) {
			const state = shortUrl ? cobrandParseShortNote_(note, shortUrl) : null
			setShortNote(
				(state
					? cobrandShortNote_(shortUrl, state.id, state.url, state.updated) +
						"\n"
					: "") +
					(shortUrl ? "Not updated: " : "No short link yet: ") +
					place.error +
					".",
			)
			continue
		}

		if (!shortUrl) {
			// New row: its own short link, redirecting to the current link.
			const title =
				"Cobrand " +
				tab.name +
				": " +
				tab.params.map((p) => String(values[p.col - 1]).trim()).join(" / ") +
				(place.name ? " (" + place.name + ")" : "")
			try {
				const link = shortio.create(fullUrl, title)
				shortUrl = link.shortUrl
				shortCell.setValue(shortUrl)
				shortCell.setNote(cobrandShortNote_(shortUrl, link.id, fullUrl))
			} catch (err) {
				setShortNote(
					"No short link yet (" +
						cobrandNow_() +
						"): " +
						err.message +
						"\nThe next edit or sweep tries again.",
				)
				continue // the QR waits for the short link
			}
		} else {
			// The note records where this short link redirects; it only counts for the link now in E.
			const state = cobrandParseShortNote_(note, shortUrl)
			const stateNote = state
				? cobrandShortNote_(shortUrl, state.id, state.url, state.updated)
				: ""
			const withState = (message) =>
				(stateNote ? stateNote + "\n" : "") + message

			if (!cobrandParseShortUrl_(shortUrl)) {
				setShortNote(COBRAND_NOTE.NOT_SHORT)
				continue
			}
			const here = tab.name + " row " + row
			const others = (shortRows[cobrandShortKey_(shortUrl)] || []).filter(
				(w) => w !== here,
			)
			if (others.length) {
				setShortNote(
					withState(
						"The same short link is also in " +
							others.join(", ") +
							", so it is not updated. " +
							"If this row is a copy, clear E and F here to give it its own short link and QR.",
					),
				)
				continue
			}

			if (state && state.url === fullUrl) {
				setShortNote(stateNote) // already redirects to the current link; clears any old message
			} else {
				try {
					const id = state ? state.id : shortio.find(shortUrl)
					shortio.update(id, fullUrl)
					shortCell.setNote(cobrandShortNote_(shortUrl, id, fullUrl))
				} catch (err) {
					setShortNote(
						withState(
							"Could not point it at the current link (" +
								cobrandNow_() +
								"): " +
								err.message +
								"\nThe next edit or sweep tries again.",
						),
					)
				}
			}
		}

		if (!hasQr) {
			cobrandCreateQr_(tab, sheet, row, shortUrl, place)
		} else if (checkExisting) {
			cobrandFlagQr_(qrCell, qrText, shortUrl, COBRAND_NOTE.QR_MISMATCH)
		}
	}
}

/**
 * Makes the QR file for `text` in place.folderId, named place.name (or after `text`), and puts its
 * link in the QR cell (and the folder's link in qr_link_folder), or an error the next run retries.
 */
function cobrandCreateQr_(tab, sheet, row, text, place) {
	const qrCell = sheet.getRange(row, tab.col.QR)
	try {
		const fileName = place.name ? place.name + ".png" : cobrandQrFileName_(text)
		const blob = cobrandFetchQrBlob_(text, fileName)
		const folder = DriveApp.getFolderById(place.folderId)
		const file = folder.createFile(blob)
		qrCell.setValue(file.getUrl())
		qrCell.setNote("")
		if (tab.col.QR_FOLDER)
			sheet.getRange(row, tab.col.QR_FOLDER).setValue(folder.getUrl())
		try {
			file.setDescription(text) // record of what the QR encodes, for names that don't show it
		} catch (err) {
			// not essential
		}
	} catch (err) {
		qrCell.setValue("QR error (" + cobrandNow_() + "): " + err.message)
	}
}

/** Adds or clears `message` on the QR cell, depending on whether its file encodes `text`. Never touches the file. */
function cobrandFlagQr_(qrCell, qrText, text, message) {
	let file
	try {
		file = DriveApp.getFileById(cobrandDriveFileId_(qrText))
	} catch (err) {
		return // the file can't be read; leave the cell as it is
	}
	const matches =
		text !== "" &&
		(file.getName() === cobrandQrFileName_(text) ||
			file.getDescription() === text)
	qrCell.setNote(matches ? "" : message)
}

/** Generic tab: QRs go in the Co-brand generic folder, named <utm_source>_<utm_term>. */
function cobrandGenericQrPlace_(tab, values) {
	const source = String(values[tab.col.SOURCE - 1]).trim()
	const term = String(values[tab.col.TERM - 1]).trim()
	return { folderId: tab.qrFolderId, name: source + "_" + term }
}

/**
 * Store tab: where a row's QR goes and its file name, from the Dictionary.
 * - utm_source = a Food BU (GOH, MNG, TPS), utm_term = one of its store ids: the BU's folder,
 *   named after the store.
 * - utm_source = CBS, utm_term = a CBS brand name: the CBS folder, named after the brand.
 * Returns { folderId, name } or { error }.
 */
function cobrandStoreQrPlace_(tab, values) {
	const dict = cobrandDictionary_()
	const source = String(values[tab.col.BU - 1])
		.trim()
		.toUpperCase()
	const term = String(values[tab.col.TERM - 1]).trim()

	if (source === "CBS") {
		const brand = dict.cbsBrands[term.toLowerCase()]
		if (!brand) {
			return {
				error:
					'utm_term "' +
					term +
					'" is not a CBS brand in the Dictionary (' +
					dict.cbsBrandList.join(", ") +
					")",
			}
		}
		return { folderId: COBRAND_STORE.FOLDERS.CBS, name: brand }
	}

	const info = dict.bus[source]
	if (!info || info.group !== "food") {
		return {
			error:
				'utm_source "' +
				source +
				'" must be one of ' +
				dict.foodBus.concat(["CBS"]).join(", "),
		}
	}
	const store = dict.stores[source + "|" + term.toUpperCase()]
	if (!store)
		return {
			error:
				'utm_term "' +
				term +
				'" is not a ' +
				source +
				" store id in the Dictionary",
		}
	const folderId = COBRAND_STORE.FOLDERS[source]
	if (!folderId)
		return {
			error: "no QR folder is set for " + source + " in COBRAND_STORE.FOLDERS",
		}
	return { folderId: folderId, name: store }
}

/**
 * BU codes and CBS brands (P-R: BU group, BU, Brand) and stores (K bu code, L store id, N name)
 * from the Dictionary tab, read once per run.
 */
function cobrandDictionary_() {
	if (cobrandDictionaryCache_) return cobrandDictionaryCache_
	const sheet = SpreadsheetApp.getActive()
		.getSheets()
		.filter((s) => s.getSheetId() === COBRAND_STORE.DICTIONARY_SHEET_ID)[0]
	const bus = {}
	const stores = {}
	const foodBus = []
	const cbsBrands = {} // lower-case brand -> brand as written in the Dictionary
	const cbsBrandList = []
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
				const code = r[7].trim().toUpperCase() // Q
				const brand = r[8].trim() // R
				if (code) bus[code] = { group: group, brand: brand }
				if (code && group === "food") foodBus.push(code)
				if (brand && group === "cbs") {
					cbsBrands[brand.toLowerCase()] = brand
					cbsBrandList.push(brand)
				}
			})
	}
	cobrandDictionaryCache_ = {
		bus: bus,
		stores: stores,
		foodBus: foodBus,
		cbsBrands: cbsBrands,
		cbsBrandList: cbsBrandList,
	}
	return cobrandDictionaryCache_
}

/** Every short link in the tabs, as key -> ['Generic row 5', ...], to catch copied rows. */
function cobrandShortLinkRows_() {
	const map = {}
	COBRAND_TABS.forEach((tab) => {
		const sheet = cobrandSheet_(tab)
		if (!sheet) return
		const first = tab.firstDataRow
		const lastRow = sheet.getLastRow()
		if (lastRow < first) return
		sheet
			.getRange(first, tab.col.SHORT, lastRow - first + 1, 1)
			.getValues()
			.forEach((r, i) => {
				const text = String(r[0]).trim()
				if (!text) return
				const key = cobrandShortKey_(text)
				;(map[key] = map[key] || []).push(tab.name + " row " + (first + i))
			})
	})
	return map
}

/** { host, path } of a link such as https://abc.short.gy/x1Y2, or null. */
function cobrandParseShortUrl_(text) {
	const m = String(text)
		.trim()
		.match(/^https?:\/\/([^\/?#\s]+)\/([^?#\s]+)$/i)
	return m ? { host: m[1].toLowerCase(), path: m[2] } : null
}

function cobrandShortKey_(text) {
	const p = cobrandParseShortUrl_(text)
	return p ? p.host + "/" + p.path : String(text).trim()
}

/** The note on E: which Short.io link this is and where it redirects. */
function cobrandShortNote_(shortUrl, id, url, updated) {
	return (
		"Short link: " +
		shortUrl +
		"\nShort.io link ID: " +
		id +
		"\nRedirects to: " +
		url +
		"\nUpdated: " +
		(updated || cobrandNow_())
	)
}

/** { id, url, updated } from a note made by cobrandShortNote_ for this short link, or null. */
function cobrandParseShortNote_(note, shortUrl) {
	const text = String(note || "")
	const link = text.match(/^Short link: (\S+)$/m)
	const id = text.match(/^Short\.io link ID: (\S+)$/m)
	const url = text.match(/^Redirects to: (.+)$/m)
	const updated = text.match(/^Updated: (.+)$/m)
	if (
		!link ||
		!id ||
		!url ||
		cobrandShortKey_(link[1]) !== cobrandShortKey_(shortUrl)
	)
		return null
	return {
		id: id[1],
		url: url[1].trim(),
		updated: updated ? updated[1].trim() : "",
	}
}

/** Small Short.io API client. The API key is read from Script properties when it's first needed. */
function cobrandShortio_() {
	const props = PropertiesService.getScriptProperties()
	let domain = ""

	function call(method, path, body) {
		const key = String(
			props.getProperty(COBRAND_SHORTIO.KEY_PROPERTY) || "",
		).trim()
		if (!key) {
			throw new Error(
				"Short.io is not set up: add " +
					COBRAND_SHORTIO.KEY_PROPERTY +
					" in Project Settings > Script properties",
			)
		}
		const options = {
			method: method,
			headers: { authorization: key, accept: "application/json" },
			muteHttpExceptions: true,
		}
		if (body) {
			options.contentType = "application/json"
			options.payload = JSON.stringify(body)
		}
		const res = UrlFetchApp.fetch(COBRAND_SHORTIO.API + path, options)
		const code = res.getResponseCode()
		const text = res.getContentText()
		if (code < 200 || code > 299)
			throw new Error("Short.io HTTP " + code + ": " + text.slice(0, 200))
		return text ? JSON.parse(text) : {}
	}

	function getDomain() {
		if (domain) return domain
		domain = String(
			props.getProperty(COBRAND_SHORTIO.DOMAIN_PROPERTY) ||
				COBRAND_SHORTIO.DOMAIN ||
				"",
		).trim()
		if (domain) return domain
		const hosts = []
			.concat(call("get", "/api/domains"))
			.map((d) => d && d.hostname)
			.filter(Boolean)
		if (hosts.length === 0)
			throw new Error("Short.io has no domain yet: add one in Short.io first")
		if (hosts.length > 1) {
			throw new Error(
				"Short.io has several domains (" +
					hosts.join(", ") +
					"): add " +
					COBRAND_SHORTIO.DOMAIN_PROPERTY +
					" in Script properties with the one to use",
			)
		}
		domain = hosts[0]
		return domain
	}

	/** A new short link (never reuses another row's link) -> { id, shortUrl }. */
	function create(originalUrl, title) {
		const body = {
			domain: getDomain(),
			originalURL: originalUrl,
			title: title,
			allowDuplicates: true,
		}
		let link
		try {
			link = call(
				"post",
				"/links",
				Object.assign({ redirectType: COBRAND_SHORTIO.REDIRECT_TYPE }, body),
			)
		} catch (err) {
			if (!/^Short\.io HTTP 40[023]:/.test(err.message)) throw err
			link = call("post", "/links", body) // the plan may not let us choose the redirect type
		}
		const shortUrl = link.secureShortURL || link.shortURL
		if (!link.idString || !shortUrl)
			throw new Error("Short.io did not return the new link")
		return { id: link.idString, shortUrl: shortUrl }
	}

	/** Points an existing short link at a new destination. */
	function update(id, originalUrl) {
		call("post", "/links/" + encodeURIComponent(id), {
			originalURL: originalUrl,
		})
	}

	/** The Short.io link ID of a short link in the account. */
	function find(shortUrl) {
		const p = cobrandParseShortUrl_(shortUrl)
		const link = call(
			"get",
			"/links/expand?domain=" +
				encodeURIComponent(p.host) +
				"&path=" +
				encodeURIComponent(p.path),
		)
		if (!link.idString) throw new Error("Short.io has no link " + shortUrl)
		return link.idString
	}

	return { domain: getDomain, create: create, update: update, find: find }
}

/**
 * Creates the On-edit trigger and the backup trigger for this account if they're missing, and
 * keeps the backup trigger on SWEEP_MINUTES.
 */
function cobrandEnsureTriggers_() {
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
	const minutes = String(COBRAND.SWEEP_MINUTES)
	const sweeps = triggers.filter(
		(t) => t.getHandlerFunction() === "cobrandSweep",
	)
	if (sweeps.length && props.getProperty("COBRAND_SWEEP_MINUTES") === minutes)
		return

	// Missing, or on another interval: add the new trigger first, then remove the old ones.
	ScriptApp.newTrigger("cobrandSweep")
		.timeBased()
		.everyMinutes(COBRAND.SWEEP_MINUTES)
		.create()
	sweeps.forEach((t) => ScriptApp.deleteTrigger(t))
	props.setProperty("COBRAND_SWEEP_MINUTES", minutes)
	Logger.log(
		"Backup trigger for cobrandSweep: every " + minutes + " minute(s).",
	)
}

/** The tab's sheet, or null. */
function cobrandSheet_(tab) {
	const ss = SpreadsheetApp.getActive()
	if (!ss) return null
	return ss.getSheets().filter((s) => s.getSheetId() === tab.sheetId)[0] || null
}

function cobrandNow_() {
	return Utilities.formatDate(
		new Date(),
		COBRAND.TIME_ZONE,
		"yyyy-MM-dd HH:mm:ss",
	)
}

/** link_original + the filled-in parameters, in column order (same rule as Link master). */
function cobrandBuildUrl_(tab, baseUrl, values) {
	let url = baseUrl
	let hash = ""
	const hashAt = url.indexOf("#")
	if (hashAt !== -1) {
		hash = url.slice(hashAt)
		url = url.slice(0, hashAt)
	}
	// A bare domain gets a trailing slash, like the existing rows: https://cards.vpbank.com.vn/?...
	if (/^https?:\/\/[^\/?]+$/i.test(url)) url += "/"

	const parts = []
	tab.params.forEach((p) => {
		const value = String(values[p.col - 1]).trim()
		if (value) parts.push(p.name + "=" + encodeURIComponent(value))
	})
	if (parts.length) {
		const sep = url.indexOf("?") === -1 ? "?" : /[?&]$/.test(url) ? "" : "&"
		url += sep + parts.join("&")
	}
	return url + hash
}

/**
 * File name in the same style as the QR files already in the folder: the encoded link without
 * https:// and without / ? #, e.g.
 * cards.vpbank.com.vnutm_campaign=central&utm_source=food&utm_term=catalog&PartnerId=central.png
 * It doubles as the record of what a QR file encodes.
 */
function cobrandQrFileName_(text) {
	return text.replace(/^https?:\/\//i, "").replace(/[\/?#]/g, "") + ".png"
}

/** PNG QR code for `text`, made by the QuickChart QR service. */
function cobrandFetchQrBlob_(text, fileName) {
	const url =
		"https://quickchart.io/qr?text=" +
		encodeURIComponent(text) +
		"&size=" +
		COBRAND.QR_SIZE +
		"&margin=4&ecLevel=M&format=png"
	const res = UrlFetchApp.fetch(url, { muteHttpExceptions: true })
	if (res.getResponseCode() !== 200) {
		throw new Error("QR service returned HTTP " + res.getResponseCode())
	}
	return res.getBlob().setName(fileName).setContentType("image/png")
}

/** The Drive file ID inside a link such as https://drive.google.com/file/d/<id>/view, or ''. */
function cobrandDriveFileId_(text) {
	const m =
		text.match(/\/d\/([A-Za-z0-9_-]{20,})/) ||
		text.match(/[?&]id=([A-Za-z0-9_-]{20,})/)
	return m ? m[1] : ""
}
