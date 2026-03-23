---------------------------------------------------------------
-- Military requisition situation text pools.
-- Formal. Terse. Procedural. These are orders, not requests.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "contract_situations_military",
    description = "Military requisition situations",
    entries = {
        { id = "cs_mil_01", text = "CLASSIFIED. Requisition order from {zoneName} garrison command. {category} supplies required for ongoing operations. Standard protocols apply. Authorisation verified.", weight = 10 },
        { id = "cs_mil_02", text = "Military relay {zoneName}. Standing requisition for {category}, Class V priority. Civilian suppliers with verified credentials may submit. Payment upon confirmed receipt.", weight = 10 },
        { id = "cs_mil_03", text = "Forward operating base near {zoneName} reports {category} stockpile below operational minimum. Command has authorised emergency procurement from network-verified suppliers.", weight = 8 },
        { id = "cs_mil_04", text = "Quartermaster dispatch, {zoneName} sector. Routine resupply of {category} required. Suppliers must meet specification standards. Non-conforming goods will be rejected.", weight = 8 },
        { id = "cs_mil_05", text = "OPERATIONAL: {zoneName} convoy support requires {category} within {deadlineDay} days. This is a time-critical military requisition. Priority clearance granted.", weight = 6 },
    },
}
