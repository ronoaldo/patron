-- Player metadata key to track last claimed reward.
local LAST_DAILY_CLAIM = "patron_last_daily_claim"

-- Privilege definition for `patron` priv.
local PATRON_PRIV = "patron"
local PATRON_PRIV_DEF = {
	description = "Players with this privilege are server patrons"..
		" and receive a daily reward",
	give_to_singleplayer = true,
	give_to_admin = true,
}

-- Helper functions
local function dbg(text)
	minetest.log("info", "[patron] "..text)
end

local S = minetest.get_translator("patron")

-- Namespace for the mod API
dailyreward = {}

-- Default items. Other mods can replace the items for
-- supporters on a daily basis
dailyreward.items = {
	ItemStack("default:diamondblock 1"),
	ItemStack("default:mese 1"),
}

-- Claims the rewards for the player. Items that can't fit
-- in the inventory will be dropped at player position.
function dailyreward.claim(player)
	local player_name = player:get_player_name()
	local inv = player:get_inventory()
	local meta = player:get_meta()
	local rewarded = ""
	local msg
	local now = os.time()

	-- TODO(ronoaldo): place in player inbox/reward detached inventory
	-- and provide a command to fetch the leftovers.

	dbg("Claiming rewards for player "..player_name)
	-- Deliver items to player inventory, or drop at their feet
	for _, itemstack in ipairs(dailyreward.items) do
		dbg("Giving "..itemstack:to_string())
		rewarded = rewarded..itemstack:get_description()..", "
		leftovers = inv:add_item("main", itemstack)
		if not leftovers:is_empty() then
			dbg("> We got leftovers: "..leftovers:to_string())
			-- We have leftovers, player inventory is full;
			-- Drop items and notify player
			minetest.item_drop(leftovers, player, player:get_pos())
			msg = S("Ops! Your daily reward could not fit in you inventory!").."\n"..
				S("It's dropped right next to you, free some space and pick it up!")
			minetest.chat_send_player(player_name, msg)
		end
	end
	rewarded = rewarded..S("a Hug")
	dbg("Saving daily reward claim time as player meta as "..now)
	meta:set_int(LAST_DAILY_CLAIM, now)

	-- Display message to player at the end
	msg = S("@1 thanks for supporting us! You got: @2", player_name, rewarded)
	minetest.chat_send_player(player_name, msg)
end

-- Check if the player can claim the rewards. It must have
-- the 'supporter' privilege and must not have collected a
-- reward in the past 24 hours.
function dailyreward.can_claim(player)
	local meta = player:get_meta()
	local last_claim = meta:get_int(LAST_DAILY_CLAIM)
	local now = os.time()
	local ok = false
	local _ = nil

	-- Check last time reward was claimed
	if now - last_claim < 24*60*60 then
		dbg(player:get_player_name() .. " can't claim rewards! Last claim is "..last_claim)
		return false 
	end

	-- Check if is a patron
	ok, _ = minetest.check_player_privs(player, PATRON_PRIV)
	if not ok then dbg(player:get_player_name() .. " can't claim rewards! Not a patron")
		return false
	end

	-- If not rewarded yet and has priv, can claim the reward
	return true
end

-- Callback helper to run on player join.
function dailyreward.on_join_callback(player, last_time)
	if dailyreward.can_claim(player) then
		dailyreward.claim(player)
	end
end

-- Minetest event registration
minetest.register_on_joinplayer(dailyreward.on_join_callback)
minetest.register_privilege(PATRON_PRIV, PATRON_PRIV_DEF)
