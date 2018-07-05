--SD_Description=Rai TV
--[[
 Copyright © 2010-2011 AUTHORS

 Authors: ale5000

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
--]]

--[[
	How to install and use:
	1) Install VLC 1.1.0 - 2010-05-24 (see Know issues)
	2) Place the script in:
		- Windows (all users):		%ProgramFiles%\VideoLAN\VLC\lua\sd\
		- Windows (current user):	%APPDATA%\VLC\lua\sd\
		- Linux (all users):			/usr/share/vlc/lua/sd/
		- Linux (current user):		~/.local/share/vlc/lua/sd/
		- Mac OS X (all users):		VLC.app/Contents/MacOS/share/lua/sd/
	3) Open VLC, then go on Media Browser => Internet => Rai TV

	Notes
	- It doesn't require any external program

	Know issues
	- Unfortunately this script doesn't work with the latest version of VLC, you must use the branch nightly build of VLC with date 2010-05-24; Windows users can find it here: http://nightlies.videolan.org/build/win32/backup/branch-20100524-0202/
	- The first four channels aren't working
	- If you wait too much time to open the streaming after the script is loaded it might not work, just close and reopen VLC

	PS: I don't take responsibility for the way this script is used
]]

-- The proxy should be in the format "http://ip:port", example: "http://127.0.0.1:8080"
-- If you don't want to use it, just leave as is
proxy = ""

function descriptor()
	return {
				title = "Rai TV";
				version = "0.04";
				author = "ale5000";
				url = "http://addons.videolan.org/usermanager/search.php?username=ale5000&action=contents";
				description = "It allow to see the Rai TV channels directly in VLC."
			}
end


function show_error(error_msg)
	error_msg = "[Rai TV] "..error_msg

	vlc.msg.err(error_msg)
	vlc.sd.add_item( {title=error_msg, path="vlc://nop", textcolor="red"} )	-- textcolor isn't not yet supported :-D
	return false
end

function log_message(message, type)
	message = "[Rai TV] "..message

	if type == "error" then
		vlc.msg.err(message)
		return false
	elseif type == "info" then
		vlc.msg.info(message)
	elseif type == "warning" then
		vlc.msg.warn(message)
	elseif type == "debug" then
		vlc.msg.dbg(message)
	else
		vlc.msg.err(message.." (Invalid message type)")
		return false
	end

	return true
end


--[[function bin_xor_slow(a,b)		-- Bitwise XOR by Reuben Thomas
	if a == nil or b == nil then vlc.msg.err("You cannot pass a nil value") return nil end
	local r = 0
	for i = 0, 31 do
		local x = a / 2 + b / 2
		if x ~= floor(x) then
			r = r + 2^i
		end
		a = floor(a / 2)
		b = floor(b / 2)
	end
	return r
end]]

function bin_xor(x, y)			-- Bitwise XOR by Arno Wagner <arno AT wagner.name>
	if x == nil or y == nil then vlc.msg.err("You cannot pass a nil value") return nil end
	local z = 0
	for i = 0, 31 do
		if x % 2 == 0 then			-- x had a '0' in bit i
			if y % 2 == 1 then		-- y had a '1' in bit i
				y = y - 1
				z = z + 2 ^ i		-- set bit i of z to '1'
			end
		else						-- x had a '1' in bit i
			x = x - 1
			if y % 2 == 0 then		-- y had a '0' in bit i
				z = z + 2 ^ i		-- set bit i of z to '1'
			else
				y = y - 1
			end
		end
		y = y / 2
		x = x / 2
	end
	return z
end

base64 = {}
function base64.encode(data)	-- base64.encode by Alex Kloss <alexthkloss AT web.de>
	local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	return ((data:gsub('.', function(x)
		local r, b = '', x:byte()
		for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
		return r;
	end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
		if #x < 6 then return '' end
		local c=0
		for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
		return b:sub(c+1,c+1)
	end)..({ '', '==', '=' })[#data%3+1])
end


-- The encode functions are based on a python script at http://flavio.tordini.org/dirette-raitv-senza-silverlight-o-moonlight
function encode1(token, rnd3)
	local i, token_length, encoded = 1, token:len(), ""
	local character

	while i <= token_length do
		character = token:sub(i, i)
		encoded = encoded..byte_to_char(bin_xor(character:byte(), rnd3))
		i = i+1
	end

	return encoded
end

function encode2(token, key)
	local i, j = token:len(), 1
	local key_length, encoded = key:len(), ""
	local character, key_character

	while i>=1 do
		if j > key_length then j = 1 end
		character = token:sub(i, i)
		key_character = key:sub(j, j)
		encoded = byte_to_char(bin_xor(character:byte(), key_character:byte()))..encoded
		i, j = i-1, j+1
	end

	return encoded
end

function encode3(token)
	return base64.encode(token)
end


function get_server_date()
	local rnd, dataBuffer = random(100000, 999999), ""

	--[[local user_agent = "http-user-agent=Mozilla/5.0 (Windows NT 6.1; rv:2.0.1) Gecko/20100101 Firefox/4.0.1"
	local headers = "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"..
	"Accept-Language: it-it,it;q=0.8,en-us;q=0.5,en;q=0.3\r\n"..
	"Accept-Encoding: gzip,deflate\r\n"..
	"Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7\r\n"..
	"Keep-Alive: 115\r\n"..
	"Connection: keep-alive\r\n"
	local useragent_headers = user_agent.."\r\n"..headers

	default_options = { useragent_headers, "no-http-forward-cookies" }
	if proxy ~= "" then default_options[3] = "http-proxy="..proxy.."/" end]]

	--local stream = vlc.stream("http://videowall.rai.it/cgi-bin/date?"..rnd.." :http-proxy=http://127.0.0.1:8080/")	-- It doesn't work
	local stream = vlc.stream("http://videowall.rai.it/cgi-bin/date?"..rnd)
	if stream == nil then return show_error("Error while retrieving the date") end

	local data
	while true do
		data = stream:read(2048)
		if data == nil or data == "" then break end
		dataBuffer = dataBuffer..data
	end
	log_message("Date (original): "..dataBuffer, "debug")

	local _, _, day, month, year, hours, minutes, seconds = dataBuffer:find("(%d%d?)\-(%d%d?)\-(%d%d%d%d)%s(%d%d?):(%d%d?):(%d%d?)")
	if seconds == nil then return show_error("Error while parsing the date, first time") end
	-- This convert the string to number, remove the leading zero and it take half of the time compared to "month = tonumber(month)"
	month = month + 0
	day = day + 0
	hours = hours + 0
	minutes = minutes + 0
	seconds = seconds + 0

	-- Global
	server_time = day.."-"..month.."-"..year.." "..hours..":"..minutes..":"..(seconds + 1)
	local_time = os.time()
	log_message("Date: "..server_time, "info")

	return true
end

function get_auth(chan_id)
	local _, _, day, month, year, hours, minutes, seconds = server_time:find("(%d%d?)\-(%d%d?)\-(%d%d%d%d)%s(%d%d?):(%d%d?):(%d%d?)")
	if seconds == nil then log_message("Error while parsing the date", "error") return nil end
	--log_message("Date: "..day.."/"..month.."/"..year.." "..hours..":"..minutes..":"..seconds, "debug")

	local key="hMrxuE2T8V0WRW0VmHaKMoFwy1XRc+hK7eBX2tTLVTw="
	--log_message("Key: "..key, "debug")
	local rnd1 = random(13, 1192)
	local rnd2 = random(40, 1222)
	local rnd3 = random(0, 28)
	local token = year..";"..chan_id..";"..day.."-"..month.."-"..rnd1.."-"..hours.."-"..minutes.."-"..seconds.."-"..rnd2
	log_message("Token: "..token, "debug")
	local ttAuth = encode3(encode2(encode1(token, rnd3)..";"..rnd3, key))
	log_message("ttAuth: "..ttAuth, "debug")

	return ttAuth
end

function add_channels()
	local current_title, i, j
	local channels_length = #channels

	local user_agent = "http-user-agent=Mozilla/5.0 (Windows NT 6.1; rv:2.0.1) Gecko/20100101 Firefox/4.0.1"
	-- Proxomitron
	local headers = "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"..
	"Accept-Language: it-it,it;q=0.8,en-us;q=0.5,en;q=0.3\r\n"..
	"Accept-Encoding: gzip,deflate\r\n"..
	"Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7\r\n"..
	"Keep-Alive: 115\r\n"..
	"Connection: keep-alive\r\n"..
	"Content-Length: 0\r\n"..
	"viaurl: www.rai.tv"
	-- Thanks to dionoea for the help with the headers
	local useragent_headers = user_agent.."\r\n"..headers

	default_options = { "", "no-http-forward-cookies", "mms-caching=6500", "mms-timeout=10000" }
	if proxy ~= "" then default_options[5] = "http-proxy="..proxy.."/" end

	local last_node_added_title
	i, j = 2, 1
	while i <= channels_length do
		current_title = channels[i].title
		if current_title == channels[i-1].title and current_title ~= last_node_added_title then
			nodes_list[j] = { title=current_title, ref=vlc.sd.add_node( {title=current_title, arturl=channels[i-1].arturl} ) }
			j = j + 1
			last_node_added_title = current_title
		end
		i = i + 1
	end

	local node, element, chan_id, ttAuth
	local nodes_length = #nodes_list - 1	-- I use nodes_length - 1 to use "j <= nodes_length" instead of "j + 1 <= nodes_length"
	i, j = 1, 1
	while i <= channels_length do
		current_title = channels[i].title
		if current_title == nodes_list[j].title then
			node = nodes_list[j].ref
		elseif j <= nodes_length and current_title == nodes_list[j+1].title then
			node = nodes_list[j+1].ref
			j = j + 1
		else
			node = nil
		end

		if channels[i].bitrate ~= "" then current_title = current_title.." - "..channels[i].bitrate.." Kbps" end
		log_message("Channel name: "..current_title, "debug")
		element = { title=current_title, path=channels[i].path, arturl=channels[i].arturl }

		_, _, chan_id = element.path:find("http://mediapolis.rai.it/relinker/relinkerServlet.%w+\?cont=(%w+)")
		if chan_id ~= nil then
			log_message("Channel id: "..chan_id, "debug")
			ttAuth = get_auth(chan_id)
			if ttAuth == nil then return show_error("Creating ttAuth failed") end
			element.options = default_options
			element.options[1] = useragent_headers.."\r\nttAuth: "..ttAuth
		else
			element.options = { user_agent }
		end

		if node ~= nil then
			items_list[i] = node:add_subitem(element)
		else
			items_list[i] = vlc.sd.add_item(element)
		end
		i = i + 1
	end
end

--[[function remove_channels()
	local items_length, i = #items_list, 1

	while i <= items_length do
		vlc.sd.remove_item(items_list[i])
		i = i + 1
	end
end]]

function main()
	local loading = vlc.sd.add_item( {path="vlc://nop", title="Loading...", textcolor="blue"} )	-- textcolor isn't not yet supported :-D
	math.randomseed( os.time() )

	if get_server_date() then
		add_channels()
	end

	vlc.sd.remove_item(loading)
end

-- Global variables
random = math.random
floor = math.floor
byte_to_char = string.char

server_time = ""
local_time = ""

nodes_list = {}
items_list = {}

-- Elements with the same title must be near
channels =
{ -- http://www.direttaraiuno.rai.it/dl/RaiTV/diretta.html
	-- http://www.rai.it/dl/portale/html/palinsesti/static/RaiUno.html
	---- http://wwitv.com/tv_stream/b5149.asx
	{ title="Rai Uno", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=983", arturl="http://it.kingofsat.net/jpg/raiuno.jpg", palinsesti="" },
	{ title="Rai Uno", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=4154", arturl="http://it.kingofsat.net/jpg/raiuno.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/RaiDue.html
	{ title="Rai Due", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=984", arturl="http://www.seeklogo.com/images/R/Rai_Due-logo-D29ADEF95C-seeklogo.com.gif", palinsesti="" },
	{ title="Rai Due", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=4155", arturl="http://www.seeklogo.com/images/R/Rai_Due-logo-D29ADEF95C-seeklogo.com.gif", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/RaiTre.html
	---- http://wwitv.com/tv_stream/b5207.asx
	{ title="Rai Tre", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=986", arturl="http://it.kingofsat.net/jpg/raitre.jpg", palinsesti="" },
	{ title="Rai Tre", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=4137", arturl="http://it.kingofsat.net/jpg/raitre.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/Rai4.html
	{ title="Rai 4", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=75708", arturl="http://it.kingofsat.net/jpg/rai4.jpg", palinsesti="" },
	{ title="Rai 4", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=72386", arturl="http://it.kingofsat.net/jpg/rai4.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/RaiGulp.html
	{ title="Rai Gulp", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=4119", arturl="http://it.kingofsat.net/jpg/raigulp.jpg", palinsesti="" },
	{ title="Rai Gulp", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=4120", arturl="http://it.kingofsat.net/jpg/raigulp.jpg", palinsesti="" },
	{ title="Rai Gulp", bitrate="15", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=681", arturl="http://it.kingofsat.net/jpg/raigulp.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/RaiSportSatellite.html
	{ title="RaiSport+", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=4145", arturl="http://it.kingofsat.net/jpg/raisportpiu.jpg", palinsesti="" },
	{ title="RaiSport+", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=17190", arturl="http://it.kingofsat.net/jpg/raisportpiu.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/RaiNews24.html
	{ title="RaiNews24", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=1", arturl="http://it.kingofsat.net/jpg/raiallnews.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/RaiEducational.html
	{ title="Rai Scuola", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=24268", arturl="http://it.kingofsat.net/jpg/raiscuola.jpg", palinsesti="" },
	{ title="Rai Scuola", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=4152", arturl="http://it.kingofsat.net/jpg/raiscuola.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/RaiEDU2.html
	{ title="Rai Storia", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=24269", arturl="http://it.kingofsat.net/jpg/raistoria.jpg", palinsesti="" },
	{ title="Rai Storia", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=4153", arturl="http://it.kingofsat.net/jpg/raistoria.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/Extra.html
	{ title="RaiSat Extra", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=72382", arturl="http://it.kingofsat.net/jpg/raisat-show.jpg", palinsesti="" },
	{ title="RaiSat Extra", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=72926", arturl="http://it.kingofsat.net/jpg/raisat-show.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/Premium.html
	{ title="RaiSat Premium", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=72383", arturl="http://it.kingofsat.net/jpg/raisat-premium.jpg", palinsesti="" },
	{ title="RaiSat Premium", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=72916", arturl="http://it.kingofsat.net/jpg/raisat-premium.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/Yoyo.html
	{ title="RaiSat YoYo", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=72384", arturl="http://it.kingofsat.net/jpg/raisat-yoyo.jpg", palinsesti="" },
	{ title="RaiSat YoYo", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=72918", arturl="http://it.kingofsat.net/jpg/raisat-yoyo.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/CinemaWorld.html
	{ title="RaiSat Cinema", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=72381", arturl="http://it.kingofsat.net/jpg/raisat-cinema.jpg", palinsesti="" },
	{ title="RaiSat Cinema", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=72920", arturl="http://it.kingofsat.net/jpg/raisat-cinema.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/RaiMed.html
	{ title="Rai Med", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=87127", arturl="http://it.kingofsat.net/jpg/raimed.jpg", palinsesti="" },

	-- http://www.rai.it/dl/portale/html/palinsesti/static/EuroNews.html
	{ title="EuroNews", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=113784", arturl="http://it.kingofsat.net/jpg/euronews.jpg", palinsesti="" },

	{ title="Miss Italia", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=61021", arturl="", palinsesti="" },

	--{ title="Rai Italia", bitrate="512", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=87578", arturl="", palinsesti="" },


	{ title="Rai Tween", bitrate="", path="http://www.rai.tv/dl/RaiTV/diretta.html?cid=PublishingBlock-ff9755c1-5cf3-4d87-86a8-a8057573ac67", arturl="http://www.objects.rai.it/dl/images/1268822907497trebi090310_tband105.jpg", palinsesti="" }
}

tg_channels =
{
	{ title="Rai Uno - TG economia", bitrate="300", path="http://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=987", arturl="", palinsesti="" },
	{ title="TG1", bitrate="", path="http://link.rai.it/x/vod/ue/wmx/ultimo_tg1.asx", arturl="", palinsesti="" },
	{ title="TG2", bitrate="", path="http://link.rai.it/x/vod/ue/wmx/ultimo_tg2.asx", arturl="", palinsesti="" },
	{ title="TG3", bitrate="", path="http://link.rai.it/x/vod/ue/wmx/ultimo_tg3.asx", arturl="", palinsesti="" }
}

radio_channels =
{
	-- http://www.radio.rai.it/player/radio1.rpm
	-- http://www.radio.rai.it/live/radio1.ram
	{ title="Radio Uno", bitrate="512", path="rtsp://live.media.rai.it/broadcast/radiouno.rm", arturl="", palinsesti="" },
	-- http://www.radio.rai.it/player/radio2.rpm
	-- http://www.radio.rai.it/live/radio2.ram
	{ title="Radio Due", bitrate="300", path="rtsp://live.media.rai.it/broadcast/radiodue.rm", arturl="", palinsesti="" },
	-- http://www.radio.rai.it/player/radio3.rpm
	-- http://www.radio.rai.it/live/radio3.ram
	{ title="Radio Tre", bitrate="300", path="rtsp://live.media.rai.it/broadcast/radiotre.rm", arturl="", palinsesti="" },
	-- http://www.radio.rai.it/live/fd4.ram
	{ title="Radio 4", bitrate="300", path="rtsp://live.media.rai.it/broadcast/fd4.rm", arturl="", palinsesti="" },
	-- http://www.radio.rai.it/live/fd5.ram
	{ title="Radio 5", bitrate="300", path="rtsp://live.media.rai.it/broadcast/fd5.rm", arturl="", palinsesti="" },
	-- http://www.radio.rai.it/live/isoradio.ram
	----{ title="Iso Radio", bitrate="300", path="rtsp://live.media.rai.it/broadcast/isoradio.rm", arturl="", palinsesti="" },
	-- http://www.radio.rai.it/live/parlamento.ram
	{ title="Radio GR Parlamento", bitrate="300", path="rtsp://live.media.rai.it/broadcast/grparlamento.rm", arturl="", palinsesti="" }
}
