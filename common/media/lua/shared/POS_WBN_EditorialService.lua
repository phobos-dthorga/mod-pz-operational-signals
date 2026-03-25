--  ________________________________________________________________________
-- / Copyright (c) 2026 Phobos A. D'thorga                                \
-- |                                                                        |
-- |           /\_/\                                                         |
-- |         =/ o o \=    Phobos' PZ Modding                                |
-- |          (  V  )     All rights reserved.                              |
-- |     /\  / \   / \                                                      |
-- |    /  \/   '-'   \   This source code is part of the Phobos            |
-- |   /  /  \  ^  /\  \  mod suite for Project Zomboid (Build 42).         |
-- |  (__/    \_/ \/  \__)                                                  |
-- |     |   | |  | |     Unauthorised copying, modification, or            |
-- |     |___|_|  |_|     distribution of this file is prohibited.          |
-- |                                                                        |
-- \________________________________________________________________________/

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_WBN"

local _TAG = "WBN:Editorial"
POS_WBN_EditorialService = {}

-- Rolling history of recently emitted bulletins for dedup (array of {domain, zoneId, eventType})
local _recentBulletins = {}

--- Score a candidate using the weighted formula.
--- Combines severity, freshness, confidence, public eligibility, and domain boost
--- into a single numeric score for editorial ranking.
--- @param c table Candidate table with severity, freshness, confidence, publicEligible, domain
--- @return number Weighted editorial score
local function scoreCandidate(c)
    local publicVal = c.publicEligible and 1.0 or 0.0
    local domainBoost = 0.0
    -- Economy gets slight boost as backbone of civilian listening
    if c.domain == POS_Constants.WBN_DOMAIN_ECONOMY then domainBoost = 0.5 end
    if c.domain == POS_Constants.WBN_DOMAIN_INFRASTRUCTURE then domainBoost = 0.7 end
    if c.domain == POS_Constants.WBN_DOMAIN_POWER then domainBoost = 0.8 end
    if c.domain == POS_Constants.WBN_DOMAIN_WEATHER then domainBoost = 0.4 end
    if c.domain == POS_Constants.WBN_DOMAIN_COLOUR then domainBoost = 0.3 end

    return (c.severity  * POS_Constants.WBN_SCORE_W_SEVERITY)
         + (c.freshness * POS_Constants.WBN_SCORE_W_FRESHNESS)
         + (c.confidence * POS_Constants.WBN_SCORE_W_CONFIDENCE)
         + (publicVal   * POS_Constants.WBN_SCORE_W_PUBLIC)
         + (domainBoost * POS_Constants.WBN_SCORE_W_DOMAIN_BOOST)
end

--- Check if this candidate duplicates a recent bulletin.
--- Scans the trailing window of recent emissions for matching domain+zone+eventType.
--- @param c table Candidate to check against recent history
--- @return boolean True if a matching bulletin was recently emitted
local function isDuplicate(c)
    local window = POS_Constants.WBN_EDITORIAL_REPEAT_WINDOW
    local start = math.max(1, #_recentBulletins - window + 1)
    for i = start, #_recentBulletins do
        local r = _recentBulletins[i]
        if r and r.domain == c.domain and r.zoneId == c.zoneId
                and r.eventType == c.eventType then
            return true
        end
    end
    return false
end

--- Route candidate to appropriate station class based on domain.
--- @param c table Candidate with domain field
--- @return string Station class constant
local function resolveStationClass(c)
    if c.domain == POS_Constants.WBN_DOMAIN_INFRASTRUCTURE
        or c.domain == POS_Constants.WBN_DOMAIN_POWER then
        return POS_Constants.WBN_STATION_EMERGENCY
    end
    -- Colour candidates may specify a target station
    if c.domain == POS_Constants.WBN_DOMAIN_COLOUR and c.targetStation then
        return c.targetStation
    end
    -- Weather goes to both — default to civilian market
    return POS_Constants.WBN_STATION_CIVILIAN_MARKET
end

--- Resolve confidence band from raw 0-1 confidence value.
--- @param confidence number Raw confidence value between 0 and 1
--- @return string Confidence band constant (HIGH, MEDIUM, or LOW)
local function resolveConfidenceBand(confidence)
    if confidence >= 0.7 then return POS_Constants.WBN_CONF_HIGH end
    if confidence >= 0.4 then return POS_Constants.WBN_CONF_MEDIUM end
    return POS_Constants.WBN_CONF_LOW
end

--- Filter and score an array of candidates.
--- Applies freshness floor, public eligibility, minimum percentage change,
--- deduplication, and score floor gates. Returns approved candidates sorted
--- by score descending, each tagged with stationClass, score, and confidenceBand.
--- @param candidates table Array of raw candidate tables
--- @return table Array of approved candidates sorted by score descending
function POS_WBN_EditorialService.filter(candidates)
    if not candidates or #candidates == 0 then return {} end

    local approved = {}
    for _, c in ipairs(candidates) do
        local dominated = false
        -- Gate: freshness
        if (c.freshness or 0) < POS_Constants.WBN_EDITORIAL_FRESHNESS_FLOOR then
            dominated = true
        end
        -- Gate: public eligibility
        if not dominated and not c.publicEligible then dominated = true end
        -- Gate: minimum percentage change (economy domain only —
        -- weather, power, and colour candidates have no percentChange)
        if not dominated and c.domain == POS_Constants.WBN_DOMAIN_ECONOMY
                and (c.percentChange or 0) < POS_Constants.WBN_THRESHOLD_LIGHT then
            dominated = true
        end
        -- Gate: deduplication (economy only — weather/power/colour should repeat
        -- naturally like real radio; cadence timer already rate-limits emission)
        if not dominated and c.domain == POS_Constants.WBN_DOMAIN_ECONOMY
                and isDuplicate(c) then
            dominated = true
        end
        -- Score
        if not dominated then
            local score = scoreCandidate(c)
            if score < POS_Constants.WBN_EDITORIAL_SCORE_FLOOR then
                dominated = true
            else
                c.score = score
                c.stationClass = resolveStationClass(c)
                c.confidenceBand = resolveConfidenceBand(c.confidence or 0.5)
                approved[#approved + 1] = c
            end
        end
    end

    -- Sort by score descending
    table.sort(approved, function(a, b) return (a.score or 0) > (b.score or 0) end)

    if #approved > 0 then
        PhobosLib.debug("POS", _TAG,
            "filter: " .. tostring(#candidates) .. " candidates -> "
            .. tostring(#approved) .. " approved")
    end
    return approved
end

--- Record a bulletin as recently emitted (for dedup tracking).
--- Maintains a bounded rolling window to prevent unbounded memory growth.
--- @param bulletin table Emitted bulletin with domain, zoneId, eventType
function POS_WBN_EditorialService.recordEmitted(bulletin)
    _recentBulletins[#_recentBulletins + 1] = {
        domain    = bulletin.domain,
        zoneId    = bulletin.zoneId,
        eventType = bulletin.eventType,
    }
    -- Trim to 2x window size to prevent unbounded growth
    local maxSize = POS_Constants.WBN_EDITORIAL_REPEAT_WINDOW * 2
    while #_recentBulletins > maxSize do
        table.remove(_recentBulletins, 1)
    end
end
