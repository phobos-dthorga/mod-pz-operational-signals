-- Boot Sequence Definition Template
--
-- Copy this file, rename it, and customise the lines.
-- Register by adding the path to POS_BootSequence.PATHS or
-- via PhobosLib registry: getBootRegistry():register(def)
--
-- Supported tokens: %FREQ%, %BAND%, %PLAYER%, %SIGNAL%, %RADIO%

return {
    schemaVersion = 1,
    id = "my_custom_boot",
    systemName = "MY SERVER BBS",
    durationSeconds = 10,
    postBootPauseSec = 1.0,
    lines = {
        "MY SERVER NAME",
        "",
        "Connecting.............. OK",
        "",
        "Welcome, %PLAYER%.",
        ">_",
    },
}
