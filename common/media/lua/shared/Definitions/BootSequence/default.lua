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
--

---------------------------------------------------------------
-- Default boot sequence definition.
--
-- MP servers and addon mods can override this by registering
-- their own boot sequence with the same id ("default") or by
-- providing a higher-priority definition.
--
-- Supported tokens (resolved at runtime):
--   %FREQ%    — connected frequency in MHz (e.g. "91.5")
--   %BAND%    — band name ("Operations" or "Tactical")
--   %PLAYER%  — player display name
--   %SIGNAL%  — signal strength percentage (e.g. "64%")
--   %RADIO%   — connected radio display name
---------------------------------------------------------------

return {
    schemaVersion = 1,
    id = "default",
    systemName = "POSNET BBS",
    durationSeconds = 15,
    postBootPauseSec = 1.0,

    lines = {
        "POSNET BULLETIN BOARD SYSTEM v2.1.4",
        "(c) 1993 Knox Telephone & Telegraph Co.",
        "",
        "Initialising modem............... OK",
        "Dialling %FREQ% MHz............. CONNECTED",
        "Band: %BAND%",
        "Authenticating session........... GUEST",
        "Signal strength.................. %SIGNAL%",
        "",
        "Loading network services......... OK",
        "Mounting file systems............ OK",
        "Synchronising market data........ OK",
        "",
        "Welcome, %PLAYER%.",
        "",
        "Type HELP for a list of commands.",
        "Connected via %RADIO%.",
        "",
        ">_",
    },
}
