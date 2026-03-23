---------------------------------------------------------------
-- Contract submission/fulfilment text pools — common + per-kind.
-- How to deliver and get paid.
-- Tokens: {quantity}, {targetName}, {rewardCash}, {deadlineDay}, {zoneName}
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "contract_submissions_common",
    description = "Common contract fulfilment instructions",
    entries = {
        { id = "csub_01", text = "Deliver {quantity}x {targetName} via the POSnet terminal. Payment of ${rewardCash} on confirmed receipt. Deadline: day {deadlineDay}.", weight = 10 },
        { id = "csub_02", text = "Submit the requested {quantity} units through your terminal interface. Funds will be credited automatically upon verification.", weight = 10 },
        { id = "csub_03", text = "Place the goods in your inventory and use the Fulfil action on the contract screen. ${rewardCash} credited on completion.", weight = 8 },
        { id = "csub_04", text = "The network will verify delivery automatically. Ensure you have {quantity}x {targetName} in your possession before submitting. Late delivery receives no payment.", weight = 8 },
        { id = "csub_05", text = "Standard settlement terms. Deliver by day {deadlineDay}. Payment: ${rewardCash}. Your reputation depends on reliability.", weight = 6 },
    },
}
