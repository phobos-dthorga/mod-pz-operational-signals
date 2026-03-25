return {
    schemaVersion = 1,
    id = "voice_quartermaster",
    archetypeId = "quartermaster",
    description = "Methodical, logistics-focused, supply-chain language",
    overrides = {
        situation  = "voice_quartermaster_situations",
        submission = "voice_quartermaster_submissions",
        investment = "voice_quartermaster_investments",
        wbn_opener             = "voice_wbn_quartermaster_openers",
        wbn_closer             = "voice_wbn_quartermaster_closers",
        wbn_weather            = "voice_wbn_quartermaster_weather",
        wbn_power              = "voice_wbn_quartermaster_power",
        wbn_flavour_market     = "voice_wbn_quartermaster_flavour_market",
        wbn_flavour_emergency  = "voice_wbn_quartermaster_flavour_emergency",
    },
}
