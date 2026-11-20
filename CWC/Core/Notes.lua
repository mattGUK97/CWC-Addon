local ADDON, CWC = ...

-- Release notes shown in the What's New window, newest first. Each item is a line of text, or a table
-- { text, sub = { ... } } for a line with indented details underneath.

CWC.RELEASE_NOTES = {
  {
    version = "0.9.6",
    intro = "Adding someone to Kill on Sight now takes a couple of clicks, and the roster can be laid out the way you like.",
    sections = {
      {
        title = "Highlights",
        items = {
          { text = "Add to Kill on Sight from the right-click menu:", sub = {
            "Target a Horde player, right-click their target frame (or focus frame) and choose Add to Kill on Sight.",
            "They're added as a request for the Guild Master or an Officer to approve, with where you spotted them as the reason.",
            "Only shows for Horde players, and won't add someone who's already on the list.",
          } },
          "New Role column on the roster: Guild Master, Officer or Member.",
        },
      },
      {
        title = "New",
        items = {
          { text = "Choose your roster columns with the new Columns button on the Roster page:", sub = {
            "Untick a column to hide it.",
            "Use - and + to change a column's width, or drag the edge of a column heading.",
            "Reset to default puts everything back.",
            "Your choices are saved for you only and don't change anyone else's roster.",
          } },
        },
      },
      {
        title = "Heads up",
        items = {
          "The CWC window opens a little wider by default to fit the new column. If a column doesn't fit, the roster tells you, so you can hide or narrow one.",
          "This update adds a new file, so restart the game fully rather than using /reload.",
        },
      },
    },
  },
  {
    version = "0.9.5",
    intro = "Everyone now sees the latest details for every guild mate, even people you haven't been online with. This update also adds the What's New window you're reading now.",
    sections = {
      {
        title = "Highlights",
        items = {
          { text = "Catch-up when you log in: an online guild mate passes on everything you missed while you were away.", sub = {
            "Other guild mates' latest levels, professions and details, not just the characters of the people online.",
            "Kill on Sight and Blacklist entries, approvals and removals.",
          } },
          "Newest data wins: an older copy of a character's details can never replace a newer one.",
          "Quieter guild channel: one guild mate handles your catch-up instead of everyone at once, and only sends what changed since you last synced.",
          "The character card shows how fresh each character's details are, for example \"Updated 2 hours ago\".",
        },
      },
      {
        title = "New",
        items = {
          { text = "What's New: this window opens once after each update.", sub = {
            "Tick Don't Show on Login to stop it opening by itself.",
            "Open it any time from Settings > Tools > What's New, the What's new button in the CWC header, or /cwc whatsnew.",
          } },
          "Refresh guild data (Settings > Tools) now asks for a full catch-up, not just recent changes.",
        },
      },
      {
        title = "Heads up",
        items = {
          "Catch-up only reaches people on 0.9.5 or later, so guild mates on older versions still need to update. CWC prompts them automatically.",
        },
      },
    },
  },
  {
    version = "0.9.4",
    intro = "More reliable Kill on Sight alerts, with ideas from the Kill on Sight addon by Milestorme.",
    sections = {
      {
        title = "Highlights",
        items = {
          "Visible nameplates are re-checked every few seconds and when you zone in, so a target already on screen is caught.",
          "Each Kill on Sight target alerts once per visit, and again only after 20 seconds out of sight.",
          "A chat reminder, once per session, if enemy nameplates are switched off.",
        },
      },
      {
        title = "Changes",
        items = {
          "Kill on Sight alerts are off in dungeons, raids, battlegrounds and sanctuaries, and only fire for hostile players.",
          "New setting: mute Kill on Sight alerts in neutral goblin towns.",
        },
      },
      {
        title = "Fixes",
        items = {
          "WoW: Forever names written as First-Last are now matched as First Last everywhere: alerts, guild sync and the character scan.",
        },
      },
    },
  },
  {
    version = "0.9.3",
    sections = {
      {
        title = "Highlights",
        items = {
          "The Guild Master and Officers can remove approved Kill on Sight and Blacklist entries.",
          { text = "Blacklist alerts when a blacklisted player contacts you directly:", sub = {
            "a whisper, a group invite, being in your group, a trade window, or mail.",
          } },
          "A tidier, narrower character card that wraps long details instead of cutting them off.",
        },
      },
    },
  },
}
