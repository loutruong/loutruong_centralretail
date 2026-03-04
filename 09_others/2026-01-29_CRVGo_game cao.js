// // // Global variable declaration and store information to reuse
// const spreadSheetID = "1l5RAe0NTodgA_wKbo3zzHXVBfd9vM084cGSVf4WXLMg"; // Controller
// const sheetName_1 = "Link master"; // Controller
// const ss_1 = SpreadsheetApp.openById(spreadSheetID).getSheetByName(sheetName_1); // Fixed
// // const sheetId_1 = 0; // Controller
// // Feature to get sheet id
// function checkSheetId() {
//   const ss_1 =
//     SpreadsheetApp.openById(spreadSheetID).getSheetByName(sheetName_1); // Fixed
//   try {
//     if (ss_1) {
//       console.log(`The actual ID for ${sheetName_1} is: ${ss_1.getSheetId()}`);
//     } else {
//       console.log(`The actual ID for ${sheetName_1} is not found`);
//     }
//   } catch (error) {
//     console.error("Error message:", error.message);
//   }
// }

// Feature callback onEdit
function onEdit(e) {
    try {
        if (e) {
            // linkbuildId(e);
            addTimeStamp(e);
            adjustTimeStamp(e);
            webLinkBuildTool(e);
            // affiliateShopeeLinkBuildTool(e); // Handles edits in Column D
            // updateShopeeLinkOnSubIdEdit(e); // Handles edits in Columns K-O
            // affiliateLazadaLinkBuildTool(e); // Handles edits in Column D
            // updateLazadaLinkOnSubIdEdit(e); // Handles edits in Columns J-P
            // shortLinkbuild(e);
        } else {
            console.error("onEdit triggered without event object 'e'.");
            Logger.log("onEdit triggered without event object 'e'.");
        }
    } catch (error) {
        console.error(
            `Error in onEdit handler: ${error.message}\nStack: ${error.stack}`
        );
        Logger.log(
            `Error in onEdit handler: ${error.message}\nStack: ${error.stack}`
        );
    }
}
// Feature add timestamp
function addTimeStamp(e) {
    const sheetIdList = [0]; // Controller
    try {
        if (
            e &&
            e.range.getRow() > 1 &&
            e.range.getColumn() === 3 &&
            sheetIdList.includes(e.source.getSheetId()) &&
            e.source.getActiveSheet().getRange(e.range.getRow(), 2).getValue() === "" // Controller
        ) {
            e.source
                .getActiveSheet()
                .getRange(e.range.getRow(), 1) // Controller
                .setValue(
                    Utilities.formatDate(
                        new Date(),
                        "Asia/Ho_Chi_Minh",
                        "yyyy-MM-dd HH:mm:ss"
                    )
                );
        } else {
            console.error("addTimeStamp error");
        }
    } catch (error) {
        console.error(
            `Error in onEdit handler: ${error.message}\nStack: ${error.stack}`
        );
    }
}

// Feature adjust timestamp
function adjustTimeStamp(e) {
    const sheetIdList = [0]; // Controller
    try {
        if (
            e &&
            e.range.getRow() > 1 &&
            e.range.getColumn() === 3 &&
            sheetIdList.includes(e.source.getSheetId())
        ) {
            e.source
                .getActiveSheet()
                .getRange(e.range.getRow(), 2) // Controller
                .setValue(
                    Utilities.formatDate(
                        new Date(),
                        "Asia/Ho_Chi_Minh",
                        "yyyy-MM-dd HH:mm:ss"
                    )
                );
        } else {
            console.error("addTimeStamp error");
        }
    } catch (error) {
        console.error(
            `Error in onEdit handler: ${error.message}\nStack: ${error.stack}`
        );
    }
}

// Feature website link builder
function webLinkBuildTool(e) {
    // --- Start Configuration ---
    const targetSheetId = 0; // Controller
    const firstDataRow = 2; // Row number where your data starts (assuming Row 1 has headers)
    const urlCol = 3; // Column C: link_original (Base URL)
    const outputCol = 4; // Column E: link_full (Generated URL Output)
    const sourceCol = 5; // Column G: utm_source
    const mediumCol = 6; // Column H: utm_medium
    const campaignCol = 7; // Column I: utm_campaign
    const utmIdCol = 8; // Column J: utm_id
    const termCol = 9; // Column K: utm_term
    const contentCol = 10; // Column L: utm_content

    // Define which columns trigger the script when edited: We trigger on changes to the base URL or any UTM parameter
    const triggerColumns = [
        urlCol,
        sourceCol,
        mediumCol,
        campaignCol,
        utmIdCol,
        termCol,
        contentCol,
    ];
    // --- End Configuration ---
    const sheet = e.source.getActiveSheet();
    const range = e.range;
    const editedRow = range.getRow();
    const editedCol = range.getColumn();

    // Exit if the edit is not on the specified sheet, is in the header row, or is not in one of the trigger columns.
    if (
        sheet.getSheetId() != targetSheetId ||
        editedRow < firstDataRow ||
        !triggerColumns.includes(editedCol)
    ) {
        return;
    }

    // Get the base URL ('link_original') from the edited row
    let baseUrl = sheet.getRange(editedRow, urlCol).getValue().toString().trim();
    // Get the cell where the output ('link_full') will be written
    const outputCell = sheet.getRange(editedRow, outputCol);

    // If the base URL ('link_original') is empty, clear the output cell and stop
    if (!baseUrl) {
        outputCell.setValue("");
        return;
    }

    // Define the parameters and their corresponding columns
    const paramsConfig = [
        { name: "utm_source", col: sourceCol },
        { name: "utm_medium", col: mediumCol },
        { name: "utm_campaign", col: campaignCol },
        { name: "utm_id", col: utmIdCol }, // Note: 'utm_id' is the standard parameter name
        { name: "utm_term", col: termCol },
        { name: "utm_content", col: contentCol },
    ];

    let queryStringParts = []; // Array to hold "key=value" strings

    // Loop through each parameter configuration
    paramsConfig.forEach((paramInfo) => {
        const value = sheet
            .getRange(editedRow, paramInfo.col)
            .getValue()
            .toString()
            .trim(); // Only add the parameter if its value is not empty

        if (value) {
            queryStringParts.push(`${paramInfo.name}=${encodeURIComponent(value)}`); // Encode the value to make it URL-safe (handles spaces, special characters, etc.)
        }
    });

    // Assemble the final URL
    let finalUrl = baseUrl;
    if (queryStringParts.length > 0) {
        // Check if the base URL already contains a query string (a '?')
        if (baseUrl.includes("?")) {
            // If yes, append parameters with '&'
            finalUrl += "&" + queryStringParts.join("&");
        } else {
            // If no, start the query string with '?'
            finalUrl += "?" + queryStringParts.join("&");
        }
    }

    // Write the generated URL ('link_full') to the output column (Column C)
    outputCell.setValue(finalUrl);
}
