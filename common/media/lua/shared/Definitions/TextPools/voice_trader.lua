---------------------------------------------------------------
-- Trader voice pack — mercantile, profit-focused language.
-- Overrides "situation" and "submission" sections when the
-- mission sponsor is a baseline_trader archetype.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "voice_trader_situations",
    description = "Trader-voiced situation descriptions",
    entries = {
        { id = "trd_sit_01", text = "The {category} market in {zoneName} is moving. Prices have shifted and my models need fresh data to stay competitive.", weight = 10 },
        { id = "trd_sit_02", text = "I have been tracking {category} trends in {zoneName} and something does not add up. The numbers on paper do not match the reality on the ground.", weight = 8 },
        { id = "trd_sit_03", text = "A profitable {category} trade window is opening in {zoneName}. I need ground truth before committing capital.", weight = 8 },
        { id = "trd_sit_04", text = "My suppliers in {zoneName} have gone quiet on {category}. That either means trouble or opportunity. Either way, I need eyes out there.", weight = 8 },
        { id = "trd_sit_05", text = "The {category} spread between {zoneName} and neighbouring zones is widening. Arbitrage opportunity — but only with confirmed data.", weight = 6, conditions = { minDifficulty = 3 } },
    },
}
