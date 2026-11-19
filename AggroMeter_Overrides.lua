-- AggroMeter per-NPC pull-radius overrides.
--
-- Keys must be numeric NPC IDs (extracted from unit GUIDs) so overrides remain
-- consistent across client locales and duplicate mob names.
--
-- Supported fields:
--   radius = number   -- overrides the level-scaled radius completely (yards)
--   offset = number   -- adds/subtracts yards relative to the level formula
--   note   = string   -- optional note displayed by /am debug
--
-- Examples:
-- AggroMeterOverrides[12345] = { radius = 30, note = "Extended detection aura" }
-- AggroMeterOverrides[67890] = { offset = 5, note = "+5 yd detection bonus" }

AggroMeterOverrides = AggroMeterOverrides or {}
