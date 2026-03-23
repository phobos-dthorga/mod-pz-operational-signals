---------------------------------------------------------------
-- Quartermaster voice pack — community-focused, practical,
-- measured. Overrides "situation" section when a quartermaster
-- archetype sponsors a mission or contract.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_quartermaster_situations",
    description = "Quartermaster-voiced situation descriptions",
    entries = {
        { id = "qm_sit_01", text = "Our {category} reserves in {zoneName} are running low. We have enough for maybe another week if we ration carefully. Fresh supply data would help us plan.", weight = 10 },
        { id = "qm_sit_02", text = "The settlement needs accurate {category} numbers for {zoneName}. We are making allocation decisions based on stale information and people are starting to notice.", weight = 10 },
        { id = "qm_sit_03", text = "We have a surplus of {category} right now but I am not sure it will last. The {zoneName} supply picture is unclear and I would rather plan than hope.", weight = 8 },
        { id = "qm_sit_04", text = "Three families are depending on our {category} stockpile in {zoneName}. I need to know what is actually available out there before I make promises.", weight = 8 },
        { id = "qm_sit_05", text = "The community voted to prioritise {category} distribution this week. I need ground truth from {zoneName} to set fair rations.", weight = 8 },
    },
}
