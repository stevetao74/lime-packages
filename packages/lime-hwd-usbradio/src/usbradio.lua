#!/usr/bin/lua

local utils = require("lime.utils")
local config = require("lime.config")

local libuci = require("uci")
local fs = require("nixio.fs")

usbradio = {}

function usbradio.clean()
	local uci = libuci:cursor()

	local function test_and_clean_device(s)
		if s["path"]:match("usb") then
			local radioName = s[".name"]
			if config.get_bool(radioName, "autogenerated") then
				local phyIndex = radioName:match("%d$")
				local _, numberOfMatches = fs.glob("/sys/devices/"..s["path"].."/ieee80211/phy"..phyIndex)
				if numberOfMatches < 1 then
					uci:delete("wireless", radioName)
					config.delete(radioName)
				end
			end
		end
	end

	uci:foreach("wireless", "wifi-device", test_and_clean_device)
	uci:save("wireless")
end

function usbradio.detect_hardware()
	local stdOutput = io.popen("find /sys/devices | grep usb | grep ieee80211 | grep 'phy[0-9]*$'")

	for _,path in pairs(utils.split(stdOutput:read("*a"), "\n")) do
		local endBasePath, phyEnd = string.find(path, "/ieee80211/phy")
		local phyPath = string.sub(path, 14, endBasePath-1)
		local phyIndex = string.sub(path, phyEnd+1)
		local radioName = "radio"..phyIndex

		if ( (not config.get(radioName)) or config.get_bool(radioName, "autogenerated") ) then

			local uci = libuci:cursor()

			uci:delete("wireless", radioName)
			uci:set("wireless", radioName, "wifi-device")
			uci:set("wireless", radioName, "type", "mac80211")
			uci:set("wireless", radioName, "channel", "11") --TODO: working on all 802.11bgn devices; find a general way for working in different devices
			uci:set("wireless", radioName, "hwmode", "11ng") --TODO: working on all 802.11gn devices; find a general way for working in different devices
			uci:set("wireless", radioName, "path", phyPath)
			uci:set("wireless", radioName, "htmode", "HT20")
			uci:set("wireless", radioName, "disabled", "0")

			uci:save("wireless")
			
			config.init_batch()
			config.set(radioName, "wifi")
			config.set(radioName, "autogenerated", "true")
			for option_name, value in pairs(config.get_all("wifi")) do
				config.set(radioName, option_name, value)
			end
			config.end_batch()
		end
	end
end


return usbradio
