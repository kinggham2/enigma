package.path = package.path ..';.luarocks/share/lua/5.2/?.lua' .. ';./bot/?.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

-------- IMPORTS --------------------
Config = loadfile("./data/config.lua")()
GeneralSudoId = Config.GeneralSudoId
GeneralSudoUsername = Config.SudoUsername
BotId = tonumber(Config.AntiSpamBotId)
ApiBotId = tonumber(Config.ApiBotId)
SupportBotUsername = Config.SupportBot
RedisIndex = Config.RedisIndex

require 'help'
tdcli = dofile("./tg/tdcli.lua")
URL = require("socket.url")
http = require("socket.http")
http.TIMEOUT = 10
https = require("ssl.https")
socket = require("socket")
ltn12 = require("ltn12")
serpent = loadfile("./bot/serpent.lua")()
utf8 = loadfile("./bot/utf8.lua")()
feedparser = loadfile("./bot/feedparser.lua")()
json = loadfile("./bot/JSON.lua")()
mimetype = loadfile("./bot/mimetype.lua")()
JSON = loadfile("./bot/dkjson.lua")()

-- Redis And it's Hashs
redis = loadfile("./bot/redis.lua")()
if tonumber(RedisIndex) ~= 0 then
	if tonumber(RedisIndex) < 0 then
		print("        => ERROR ! : Redis Index is Not True in Config.lua , Check it Again")
		return false
	end
	redis:select(RedisIndex)
end
ClerkMessageHash = "enigma:cli:clerk_msg"
ClerkStatusHash = "enigma:cli:clerk_status"

MarkreadStatusHash = "enigma:cli:markread"

WelcomeMessageHash = "enigma:cli:wlc:"

GBanHash = "enigma:cli:global_ban_users"
BanHash = "enigma:cli:ban_users:"

SilentHash = "enigma:cli:silent_users:"

ChargeHash = "enigma:cli:charge:"

ShowEditHash = "enigma:cli:show_edit_msg_id"
-------------------------------------

-- Time Variables ...
MinInSec = 60
HourInSec = 3600
DayInSec = 86400
-------

-- Colors for Print
Color = {}
Color.Red = "\027[31m"
Color.Green = "\027[32m"
Color.Yellow = "\027[33m"
Color.Blue = "\027[34m"
Color.Reset = "\027[39m"

Color.pRed = "\027[91m"
Color.pGreen = "\027[92m"
Color.pYellow = "\027[93m"
Color.pBlue = "\027[96m"
Color.pReset = "\027[97m"
-------------------

-- VarDump Function
function vardump(value)
	print(Color.pYellow.."=================== START Vardump ==================="..Color.pReset)
	print(serpent.block(value, {comment=false}))
	print(Color.pYellow.."=================== END Vardump ==================="..Color.pReset)
	Res = serpent.block(value, {comment=false})
	sendText(GeneralSudoId, "```\n"..Res.."\n```", 0, 'md')
	return "```\n"..Res.."\n```"
end

-- Sleep Function
function sleep(sec)
    socket.sleep(sec)
end

-- Dl_Cb Function
function dl_cb(arg, data)
	--vardump(arg)
end

-- Load File in JSON Format Function
function loadJson(FilePath)
	local File = io.open(FilePath)
	if not File then
		return {}
	end
	local ReadedDatas = File:read("*all")
	File:close()
	local Data = json:decode(ReadedDatas)
	return Data
end

function saveJson(FilePath, Data)
	local JsonEncodedDatas = json:encode(Data)
	local File = io.open(FilePath, "w")
	File:write(JsonEncodedDatas)
	File:close()
end

-- Returns true if String starts with Start
function string:starts(text)
	return text == string.sub(self,1,string.len(text))
end

function string:split(sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

function downloadToFile(url, file_name, file_path)
  print("    Url to Download => "..url)

  local respbody = {}
  local options = {
    url = url,
    sink = ltn12.sink.table(respbody),
    redirect = true
  }

  -- nil, code, headers, status
  local response = nil

  if url:starts('https') then
    options.redirect = false
    response = {https.request(options)}
  else
    response = {http.request(options)}
  end

  local code = response[2]
  local headers = response[3]
  local status = response[4]

  if code ~= 200 then return nil end

  file_path = file_path.."/"..file_name
  
  print("    File Saved to => "..file_path)

  file = io.open(file_path, "w+")
  file:write(table.concat(respbody))
  file:close()

  return file_path
end

-- TdCli functions---------------------------------------------------------------------------
function noHtml(String)
	String = String:gsub("<code>", "")
	String = String:gsub("</code>", "")
	String = String:gsub("<b>", "")
	String = String:gsub("</b>", "")
	String = String:gsub("<i>", "")
	String = String:gsub("</i>", "")
	String = String:gsub("<pre>", "")
	String = String:gsub("</pre>", "")
	String = String:gsub("<user>", "")
	String = String:gsub("</user>", "")
 return String
end

function getParseMode(parse_mode)
	if parse_mode then
		local mode = parse_mode:lower()
		
		if mode == "html" or mode == "ht" then
			P = {ID = "TextParseModeHTML"}
		else
			P = {ID = "TextParseModeMarkdown"}
		end
	end
  return P
end

function getChatId(ChatId)
    local chat = {}
    local ChatId = tostring(ChatId)

    if ChatId:match('^-100') then
        local channel_id = ChatId:gsub('-100', '')
        chat = {ID = channel_id, type = 'channel'}
    else
        local group_id = ChatId:gsub('-', '')
        chat = {ID = group_id, type = 'group'}
    end

    return chat
end

function getUser(UserId, Cb, Extra)
	tdcli_function ({
		ID = "GetUserFull",
		user_id_ = UserId
	}, Cb or dl_cb, Extra or nil)
end

function getChat(ChatId, Cb, Extra)
	tdcli_function ({
		ID = "GetChat",
		chat_id_ = ChatId
	}, Cb or dl_cb, Extra or nil)
end

function importLink(Link, Cb, Extra)
	tdcli_function ({
		ID = "ImportChatInviteLink",
		invite_link_ = Link
	}, Cb or dl_cb, Extra or nil)
end

-- filter = Recent|Administrators|Kicked|Bots
function getChannelMembers(channel_id, offset, filter, limit, cb, cmd)
	if not limit or limit > 200 then
		limit = 200
	end

	tdcli_function ({
		ID = "GetChannelMembers",
		channel_id_ = getChatId(channel_id).ID,
		filter_ = {
			ID = "ChannelMembers" .. filter
		},
		offset_ = offset,
		limit_ = limit
	}, cb or dl_cb, cmd or nil)
end

function addUser(ChatId, UserId, Cb, Extra)
  	tdcli_function ({
    	ID = "AddChatMember",
    	chat_id_ = ChatId,
    	user_id_ = UserId,
    	forward_limit_ = 0
  	}, Cb or dl_cb, Extra or nil)
end

function resolveUsername(Username, Cb, Extra)
    tdcli_function ({
        ID = "SearchPublicChat",
        username_ = Username
    }, Cb or dl_cb, Extra or nil)
end

function convertTime(Sec)
	if (tonumber(Sec) == nil) or (tonumber(Sec) == 0) then
		return {Day = 0, Hour = 0, Min = 0, Sec = 0}
	else
		Seconds = math.floor(tonumber(Sec))
		Day = math.floor(Seconds / 86400)
		Hour = math.floor( (Seconds - (Day*86400))/3600 )
		Min = math.floor( ((Seconds) - ( (Day*86400) + (Hour*3600) )) / 60)
		Sec = math.floor(Seconds - ((Day*86400) + (Hour*3600) + (Min*60)))
	  return {Day = Day, Hour = Hour, Min = Min, Sec = Sec}
	end
end

local function getInputMessageContent(file, filetype, caption)
	if file:match('/') then
		infile = {ID = "InputFileLocal", path_ = file}
	elseif file:match('^%d+$') then
		infile = {ID = "InputFileId", id_ = file}
	else
		infile = {ID = "InputFilePersistentId", persistent_id_ = file}
	end

	local inmsg = {}
	local filetype = filetype:lower()

	if filetype == 'animation' or filetype == "gif" then
		inmsg = {ID = "InputMessageAnimation", animation_ = infile, caption_ = caption}
	elseif filetype == 'audio' then
		inmsg = {ID = "InputMessageAudio", audio_ = infile, caption_ = caption}
	elseif filetype == 'document' then
		inmsg = {ID = "InputMessageDocument", document_ = infile, caption_ = caption}
	elseif filetype == 'photo' then
		inmsg = {ID = "InputMessagePhoto", photo_ = infile, caption_ = caption}
	elseif filetype == 'sticker' then
		inmsg = {ID = "InputMessageSticker", sticker_ = infile, caption_ = caption}
	elseif filetype == 'video' then
		inmsg = {ID = "InputMessageVideo", video_ = infile, caption_ = caption}
	elseif filetype == 'voice' then
		inmsg = {ID = "InputMessageVoice", voice_ = infile, caption_ = caption}
	end

 return inmsg
end

function sendFile(ChatId, FileType, File, Caption, ReplyToMessageId)
	tdcli_function ({
		ID = "SendMessage",
		chat_id_ = ChatId,
		reply_to_message_id_ = ReplyToMessageId or 0,
		disable_notification_ = 0,
		from_background_ = 1,
		reply_markup_ = nil,
		input_message_content_ = getInputMessageContent(File, FileType, Caption or ""),
	}, dl_cb, nil)
end

function sendText(ChatId, Text, ReplyToMessageId, ParseMode, UserId, DisableWebPagePreview, Cb, Extra)
	if ParseMode and ParseMode ~= nil and ParseMode ~= false and ParseMode ~= "" then
		ParseMode = getParseMode(ParseMode)
	else
		ParseMode = nil
	end
	
	Entities = {}
	if UserId then
		if Text:match('<user>') and Text:match('</user>') then
			local A = {Text:match("<user>(.*)</user>")}
			Length = utf8.len(A[1])
			local B = {Text:match("^(.*)<user>")}
			Offset = utf8.len(B[1])
			Text = Text:gsub('<user>','')
			Text = Text:gsub('</user>','')
			table.insert(Entities,{ID = "MessageEntityMentionName", offset_ = Offset, length_ = Length, user_id_ = UserId})
		end
		Entities[0] = {ID='MessageEntityBold', offset_=0, length_=0}
	end
	
	tdcli_function ({
		ID = "SendMessage",
		chat_id_ = ChatId,
		reply_to_message_id_ = ReplyToMessageId or 0,
		disable_notification_ = 0,
		from_background_ = 1,
		reply_markup_ = nil,
		input_message_content_ = {
			ID = "InputMessageText",
			text_ = Text,
			disable_web_page_preview_ = DisableWebPagePreview or 0,
			clear_draft_ = 0,
			entities_ = Entities,
			parse_mode_ = ParseMode,
		},
	}, Cb or dl_cb, Extra or nil)
end

function editText(ChatId, MessageId, Text, ParseMode, Cb, Extra)
	if ParseMode and ParseMode ~= nil and ParseMode ~= false and ParseMode ~= "" then
		ParseMode = getParseMode(ParseMode)
	else
		ParseMode = nil
	end
	
	tdcli_function ({
		ID = "EditMessageText",
		chat_id_ = ChatId,
		message_id_ = MessageId,
		reply_markup_ = nil,
		input_message_content_ = {
			ID = "InputMessageText",
			text_ = Text,
			disable_web_page_preview_ = 0,
			clear_draft_ = 0,
			entities_ = {},
			parse_mode_ = ParseMode,
		},
	}, Cb or dl_cb, Extra or nil)
end

function forwardMessage(ChatId, FromChatId, MessageId, Cb, Extra)
	tdcli_function ({
		ID = "ForwardMessages",
		chat_id_ = ChatId,
		from_chat_id_ = FromChatId,
		message_ids_ = {[0] = MessageId},
		disable_notification_ = 0,
		from_background_ = 1
	}, Cb or dl_cb, Extra or nil)
end

function getMessage(ChatId, MessageId, Cb, Extra)
	tdcli_function ({
		ID = "GetMessage",
		chat_id_ = ChatId,
		message_id_ = MessageId
	}, Cb or dl_cb, Extra or nil)
end

function openChat(ChatId, Cb, Extra)
	tdcli_function ({
		ID = "OpenChat",
		chat_id_ = ChatId
	}, cb or dl_cb, Extra or nil)
end

function getUserProfilePhotos(UserId, Cb, Extra)
	tdcli_function ({
		ID = "GetUserProfilePhotos",
		user_id_ = UserId,
		offset_ = 0,
		limit_ = 100
  }, Cb or dl_cb, Extra or nil)
end

function pinMessage(ChannelId, MessageId)
  	tdcli_function ({
    	ID = "PinChannelMessage",
    	channel_id_ = getChatId(ChannelId).ID,
    	message_id_ = MessageId,
    	disable_notification_ = 0
  	}, dl_cb, nil)
end
function unpinMessage(ChannelId)
  	tdcli_function ({
		ID = "UnpinChannelMessage",
		channel_id_ = getChatId(ChannelId).ID
	}, dl_cb, nil)
end

function kickUser(ChatId, UserId, Cb, Extra)
  	tdcli_function ({
		ID = "ChangeChatMemberStatus",
		chat_id_ = ChatId,
		user_id_ = UserId,
		status_ = {
      		ID = "ChatMemberStatusKicked"
    	},
  	}, Cb or dl_cb, Extra or nil)
end

function viewMessage(ChatId, MessageId, Cb, Extra)
	tdcli_function ({
		ID = "ViewMessages",
		chat_id_ = ChatId,
		message_ids_ = {[0] = MessageId} -- vector
	}, Cb or dl_cb, Extra or nil)
end

function deleteMessage(ChatId, MsgId, Cb, Extra)
    tdcli_function ({
    	ID = "DeleteMessages",
    	chat_id_ = ChatId,
    	message_ids_ = {[0] = MsgId}
    }, Cb or dl_cb, Extra or nil)
end

function deleteMessagesFromUser(ChatId, UserId, Cb, Extra)
	tdcli_function({
		ID = "DeleteMessagesFromUser",
		chat_id_ = ChatId,
		user_id_ = UserId
	}, Cb or dl_cb, Extra or nil)
end

function getMe(Cb, Extra)
	tdcli_function ({
		ID = "GetMe",
	}, Cb or dl_cb, Extra or nil)
end

function getChatType(ChatId)
	local ChatType = "private"
	local Id = tostring(ChatId)
	if Id:match("-") then
		if Id:match("^-100") then
			ChatType = "supergroup"
		else
			ChatType = "group"
        end
	end
  return ChatType
end
--------------------------------------------------------------------------
function makeSimpleDataToMsg(data)
	local msg = {}
	msg.chat = {}
	msg.from = {}
	if data.ID == "UpdateMessageContent" then
		msg.edit = true
		msg.chat.id = data.chat_id_
		msg.chat.type = getChatType(data.chat_id_)
		msg.from.id = data.user_info.user_id
		msg.id = data.message_id_
		msg.date = data.message_info.date
		msg.edit_date = data.message_info.edit_date
		msg.new_content = data.message_info.new_content
		msg.old_content = redis:hget(ShowEditHash, data.chat_id_..":"..data.message_id_) or false
	end
  return msg
end

function messageValid(data)
	if data.ID == "UpdateMessageContent" then --> MESSAGE EDIT ValidCheck
		if not data.chat_id_ then
			print(Color.Red..'    ERROR => Not valid: Chat id not provided'..Color.Reset)
			return false
		end
		
		if not data.message_id_ then
			print(Color.Red..'    ERROR => Not valid: Message id not provided'..Color.Reset)
			return false
		end
	end
  return true
end

-------------------------------------------------------------------------------------------------------------
								-- START WRITING MAIN BOT CODE --
-------------------------------------------------------------------------------------------------------------

--> NORMAL Functions
function notMod(msg)
	local Text = [[`>` این قابلیت مخصوص مدیران فرعی و اصلی ربات در گروه میباشد.
» _شما دسترسی ندارید !_]]
	sendText(msg.chat_id_, Text, msg.id_, 'md')
end
function notOwner(msg)
	local Text = [[`>` این قابلیت تنها مخصوص مدیر اصلی ربات در گروه میباشد.
» _شما دسترسی ندارید !_]]
	sendText(msg.chat_id_, Text, msg.id_, 'md')
end
function notSudo(msg)
	local Text = [[`>` این قابلیت تنها مخصوص مدیر کل ربات میباشد.
» _شما دسترسی ندارید !_]]
	sendText(msg.chat_id_, Text, msg.id_, 'md')
end
function notReply(msg)
	local Text = [[» این عملیات بدون ریپلای(*Reply*) صورت میگیرد.]]
	sendText(msg.chat_id_, Text, msg.id_, 'md')
end
function isSudo(UserId) --> Is Sudo Or Not Function.
	local UserId = tonumber(UserId)
	if UserId == tonumber(GeneralSudoId) then
		return true
	end
	for i=1, #Config.SudoUsers do
		if tonumber(Config.SudoUsers[i]) == UserId then
			return true
		end
	end
 return false
end

function isOwner(ChatId, UserId) --> Is Owner Or Not Function.
	local UserId = tonumber(UserId)
	local ChatId = tostring(ChatId)
	local Data = loadJson(Config.ModFile)
	
	if isSudo(UserId) then
		return true
	end
	if Data[tostring(ChatId)] then
		if Data[tostring(ChatId)]["set_owner"] then
			if tonumber(Data[tostring(ChatId)]["set_owner"]) == UserId then
				return true
			end
		end
	end

 return false
end

function isMod(ChatId, UserId) --> Is Moderator Or Not Function.
	local UserId = tonumber(UserId)
	local ChatId = tostring(ChatId)
	local Data = loadJson(Config.ModFile)
	
	if isSudo(UserId) then
		return true
	end
	if isOwner(ChatId, UserId) then
		return true
	end
	if Data[tostring(ChatId)] then
		if Data[tostring(ChatId)]["moderators"] then
			if Data[tostring(ChatId)]["moderators"][tostring(UserId)] then
				return true
			end
		end
	end

 return false
end

function isApiBot(UserId)
	UserId = tonumber(UserId)
	if ApiBotId == UserId then
		return true
	end
 return false
end

function isBot(UserId)
	local UserId = tonumber(UserId)
	if tonumber(BotId) == UserId then
		return true
	end
 return false
end

function isSilentUser(ChatId, UserId)
	UserId = tonumber(UserId)
	SilentUsersHash = SilentHash..ChatId
	if redis:sismember(SilentUsersHash, UserId) then
		return true
	end
  return false
end

function isGBannedUser(UserId)
	UserId = tonumber(UserId)
	if redis:sismember(GBanHash, UserId) then
		return true
	end
 return false
end

function isBannedUser(ChatId, UserId)
	UserId = tonumber(UserId)
	BanUsersHash = BanHash..ChatId
	if redis:sismember(BanUsersHash, UserId) then
		return true
	end
 return false
end


function botModPlugin(msg) --> BOT_MOD.LUA !

	Data = loadJson(Config.ModFile)
		
	if msg.content_.text_ then
		
		Cmd = msg.content_.text_
		CmdLower = msg.content_.text_:lower()
		
		--> CMD => //[Text] | Echo a message By Bot ...
		if Cmd:match("^(//)(.*)$") and isSudo(msg.sender_user_id_) then
			MatchesEN = {Cmd:match("^(//)(.*)$")}
			Text = MatchesEN[2]
			if msg.reply_to_message_id_ then
				sendText(msg.chat_id_, Text, msg.reply_to_message_id_)
				if msg.chat_type_ ~= "private" then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			else
				sendText(msg.chat_id_, Text)
				if msg.chat_type_ ~= "private" then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
		--> CMD => /backup | Backup from different parts of bot ...
		if (CmdLower:match("^[/!#](backup) (.*)$") or Cmd:match("^(بکاپ) (.*)")) and isSudo(msg.sender_user_id_) then
			MatchesEN = {CmdLower:match("^[/!#](backup) (.*)$")}; MatchesFA = {Cmd:match("^(بکاپ) (.*)$")}
			ChizToBackup = MatchesEN[2] or MatchesFA[2]
			if ChizToBackup == "redis" or ChizToBackup == "ردیس" then
				io.popen("redis-cli save"):read("*all")
				RedisBackupFilePath = "/var/lib/redis/dump.rdb"
				Cap = "#Backup"
				.."\n> #Redis Backup 🔃"
				sendFile(msg.sender_user_id_, "document", RedisBackupFilePath, Cap)
				Text = "`>` فایل پشتیبان #ردیس به خصوصی شما ارسال شد."
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			elseif ChizToBackup == "مدیریت" or ChizToBackup == "mod" or ChizToBackup == "moderation" then
				ModerationFilePath = "./data/moderation.json"
				Cap = "#Backup"
				.."\n> #Moderation File Backup 🔃"
				sendFile(msg.sender_user_id_, "document", ModerationFilePath, Cap)
				Text = "`>` فایل پشتیبان #مدیریت گروه ها به خصوصی شما ارسال شد."
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			elseif ChizToBackup  == "کانفیگ" or ChizToBackup == "config" then
				ConfigFilePath = "./data/config.lua"
				Cap = "#Backup"
				.."\n> #Config File Backup 🔃"
				sendFile(msg.sender_user_id_, "document", ConfigFilePath, Cap)
				Text = "`>` فایل پشتیبان #کانفیگ به خصوصی شما ارسال شد."
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
		--------------------------------------------------------->
		
		--> CMD => /edit | Edit a text message by reply ...
		if (Cmd:match("^[/!#]([Ee][Dd][Ii][Tt]) (.*)$") or Cmd:match("^(ویرایش) (.*)")) and isSudo(msg.sender_user_id_) then
			MatchesEN = {Cmd:match("^[/!#](edit) (.*)$")}; MatchesFA = {Cmd:match("^(ویرایش) (.*)$")}
			NewText = MatchesEN[2] or MatchesFA[2]
			if msg.reply_to_message_id_ then
				editText(msg.chat_id_, msg.reply_to_message_id_, NewText)
			end
		end
		--------------------------------->
		
		--> CMD => /exit | Exit bot from a group ...
		if (CmdLower:match("^[/!#](exit)$") or Cmd:match("^(خروج)$")) and isSudo(msg.sender_user_id_) then
			if msg.chat_type_ == "private" then
				Text = "> اینجا چت خصوصی است، نمیتوان از آن خارج شد."
				sendText(msg.chat_id_, Text, msg.id_)
				return
			end
			Text = "× ربات از این گروه خارج خواهد شد. ×"
			sendText(msg.chat_id_, Text, msg.id_, false, msg.sender_user_id_)
			kickUser(msg.chat_id_, BotId)
		end
		
		if (CmdLower:match("^[/!#](exit) (-%d+)$") or Cmd:match("^(خروج) (-%d+)$")) and isSudo(msg.sender_user_id_) then
			MatchesEN = {CmdLower:match("^[/!#](exit) (-%d+)$")}; MatchesFA = {Cmd:match("^(خروج) (-%d+)$")}
			GroupIdToLeave = MatchesEN[2] or MatchesFA[2]
			Text = "ربات به دستور <user>USER</user> از این گروه خارج خواهد شد."
			sendText(GroupIdToLeave, Text, 0, false, msg.sender_user_id_)
			kickUser(GroupIdToLeave, BotId)
			TextForSudo = "`>` ربات از این گروه با شناسه `"..GroupIdToLeave.."` خارج شد."
			sendText(msg.chat_id_, TextForSudo, msg.id_, 'md')
		end
		--------------------------------->
		
		--> CMD => /fbc | ForwardBroadcast a Message to All Moderated Groups of Bot ...
		if (CmdLower:match("^[/!#](fbc)$") or Cmd:match("^(فروارد همگانی)$")) and isSudo(msg.sender_user_id_) then
			if not msg.reply_to_message_id_ then sendText(msg.chat_id_, "`>` برای فروارد یک پیام به تمامی گروه های ربات ابتدا باید روی آن ریپلای(*Reply*) کنید و سپس دستور فروارد همگانی را تایپ کنید.", msg.id_, 'md') return end
			Data = loadJson(Config.ModFile)
			local i = 0
			Text = "`>` در حال فروارد پیام به گروه های مدیریت شده ..."
			sendText(msg.chat_id_, Text, msg.id_, 'md')
			for k,v in pairs(Data['groups']) do
				forwardMessage(v, msg.chat_id_, msg.reply_to_message_id_)
				i = i + 1
				sleep(0.5)
			end
			Text = "فروارد همگانی اتمام یافت ✅"
			.."\nاین پیام برای *"..i.."* گروه فروارد شد."
			sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'md')
		end
		
		--> CMD => /bc | Broadcast a Message to All Moderated Groups of Bot ...
		if (Cmd:match("^[/!#]([Bb][Cc]) (.*)$") or Cmd:match("^(ارسال همگانی) (.*)$")) and isSudo(msg.sender_user_id_) then
			Data = loadJson(Config.ModFile)
			MatchesEN = {Cmd:match("^[/!#]([Bb][Cc]) (.*)$")}; MatchesFA = {Cmd:match("^(ارسال همگانی) (.*)$")}
			TextToSend = MatchesEN[2] or MatchesFA[2]
			Text = "`>` در حال فروارد پیام به گروه های مدیریت شده ربات ..."
			local i = 0
			for k,v in pairs(Data['groups']) do
				sendText(v, TextToSend)
				i = i + 1
				sleep(0.5)
			end
			Text = "ارسال همگانی اتمام یافت ✅"
			.."\nاین پیام برای "..i.." گروه ارسال شد."
			.."\n————————"
			.."\nمتن پیام ارسالی به گروه ها :"
			.."\n"..TextToSend
			sendText(msg.chat_id_, Text, msg.reply_to_message_id_)
		end
		--------------------------------->
		
		--> CMD = /rem | Removing Group From Moderated Groups' list ...
		if (CmdLower:match("^[/!#](rem) (-%d+)$") or Cmd:match("^(لغو نصب) (-%d+)$")) and isSudo(msg.sender_user_id_) then
			MatchesEN = {CmdLower:match("^[/!#](rem) (-%d+)$")}; MatchesFA = {Cmd:match("^(لغو نصب) (-%d+)$")}
			ChatId = MatchesEN[2] or MatchesFA[2]
			Data = loadJson(Config.ModFile)
			if Data[tostring(ChatId)] then
				SilentHash = 'enigma:cli:silent_users:'..ChatId
				BanUsersHash = "enigma:cli:ban_users:"..ChatId
				FilteredWordsHash = "enigma:cli:filtered_words:"..ChatId
				RmsgUsersHash = "enigma:cli:rmsg_users:"..ChatId
				RulesHash = "enigma:cli:set_rules:"..ChatId
				ChargeHash = "enigma:cli:charge:"..ChatId
				BeautyHash = "enigma:cli:beauty_text:"..ChatId
				redis:del(SilentHash)
				redis:del(BanUsersHash)
				redis:del(FilteredWordsHash)
				redis:del(RmsgUsersHash)
				redis:del(RulesHash)
				redis:del(ChargeHash)
				redis:del(BeautyHash)
				Data[tostring(ChatId)] = nil
				saveJson(Config.ModFile, Data)
				if Data["groups"] then
					if Data["groups"][tostring(ChatId)] then
						Data["groups"][tostring(ChatId)] = nil
						saveJson(Config.ModFile, Data)
					end
				end
				kickUser(ChatId, BotId)
				Text = "❌ این گروه با شناسه `"..ChatId.."` از لیست گروه های مدیریت شده ربات حذف شد."
				.."\nهمچنین ربات از آن گروه خارج گردید ..."
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			else
				if Data["groups"] then
					if Data["groups"][tostring(ChatId)] then
						Data["groups"][tostring(ChatId)] = nil
						saveJson(Config.ModFile, Data)
					end
				end
				Text = "`>` این گروه با شناسه `"..ChatId.."` در لیست گروه های مدیریت شده ربات قرار ندارد!"
				..'\n_نیازی به حذف آن نیست._'
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
		------------------------------------------->
		
		--> CMD = /reset | Removing Junk Redis Hashs ...
		if (CmdLower:match("^[/!#](reset)$") or Cmd:match("^(ریست)$")) and isSudo(msg.sender_user_id_) then
			redis:del(ShowEditHash)
			Text = "ردیس های کم اهمیت و جاگیر پاک شدند!\nردیس های پاک شده:\n   `1- ردیس نمایش ادیت`"
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		end
		------------------------------------------->
		
		--> CMD = /gplist | Get Groups list of Bot ...
		if (CmdLower:match("^[/!#](gplist)$") or Cmd:match("^(لیست گروه ها)$")) and isSudo(msg.sender_user_id_) then
			Data = loadJson(Config.ModFile)
			Text = "<code>></code> لیست گروه های مدیریت شده ربات :\n\n"
			F = 0
			for k,v in pairs(Data['groups']) do
				if redis:get(ChargeHash..v) then
					A = tostring(redis:get(ChargeHash..v)):lower()
					if A == "unlimit" then
						GroupCharge = "نامحدود 🔃"
					elseif A == "true" then
						GroupCharge = '<b>'..math.floor(redis:ttl(ChargeHash..v)/86400).."</b>روز ✅"
					else
						GroupCharge = "نامعلوم ❌"
					end
				else
					GroupCharge = "تمام شده ⛔️"
				end
				F = F+1
				Text = Text..F.."— شناسه گروه : <code>"..v.."</code>"
				.."\nمقدار شارژ : "..GroupCharge
				.."\nا——————————"
				.."\n"
			end
			local file = io.open("./data/gplist.txt", "w")
			file:write(noHtml(Text))
			file:close()
			Cap = "لیست گروه های ربات"
			.."\n#GroupList"
			sendFile(msg.chat_id_, "document", "./data/gplist.txt", Cap)
			sendText(msg.chat_id_, Text, msg.id_, 'html')
		end
		------------------------------------------->
		
		-- CMD => /setclerk | Working With Clerk.
		if (Cmd:match("^[/!#]([Ss][Ee][Tt][Cc][Ll][Ee][Rr][Kk][Mm][Ss][Gg]) (.*)$") or Cmd:match("^(تنظیم پیام منشی) (.*)$")) and isSudo(msg.sender_user_id_) then
			Data = loadJson(Config.ModFile)
			MatchesEN = {Cmd:match("^[/!#]([Ss][Ee][Tt][Cc][Ll][Ee][Rr][Kk][Mm][Ss][Gg]) (.*)$")}; MatchesFA = {Cmd:match("^(تنظیم پیام منشی) (.*)$")}
			TextToSet = MatchesEN[2] or MatchesFA[2]
			redis:set(ClerkMessageHash, TextToSet)
			Text = "این متن به عنوان متن پاسخگویی ربات در خصوصی تنظیم شد!"
			.."\n———————"
			.."\n"..TextToSet
			sendText(msg.chat_id_, Text, msg.id_)
		end
		if (Cmd:match("^[/!#]([Cc][Ll][Ee][Rr][Kk]) (.*)$") or Cmd:match("^(منشی) (.*)$")) and isSudo(msg.sender_user_id_) then
			Data = loadJson(Config.ModFile)
			MatchesEN = {Cmd:match("^[/!#]([Cc][Ll][Ee][Rr][Kk]) (.*)$")}; MatchesFA = {Cmd:match("^(منشی) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn == "فعال" or Ptrn:lower() == "on" then
				if redis:get(ClerkStatusHash) then
					sendText(msg.chat_id_, "> منشی از قبل فعال بوده است.", msg.id_)
					return
				end
				redis:set(ClerkStatusHash, true)
				sendText(msg.chat_id_, "> منشی فعال شد!\nهم اکنون ربات در خصوصی پاسخگو میباشد.", msg.id_)
			end
			if Ptrn == "غیر فعال" or Ptrn == "غیرفعال" or Ptrn:lower() == "off" then
				if redis:get(ClerkStatusHash) then
					redis:del(ClerkStatusHash)
					sendText(msg.chat_id_, "> منشی غیرفعال شد.", msg.id_)
					return
				end
				sendText(msg.chat_id_, "> منشی از قبل غیرفعال بوده است.", msg.id_)
			end
		end
		------------------------------------------->
		
		-- CMD => /markread [on|off] | Working With MARKREAD ...
		if (CmdLower:match("^[/!#](markread) (.*)$") or CmdLower:match("^(خواندن پیام) (.*)$")) and isSudo(msg.sender_user_id_) then
			Data = loadJson(Config.ModFile)
			MatchesEN = {CmdLower:match("^[/!#](markread) (.*)$")}; MatchesFA = {CmdLower:match("^(خواندن پیام) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn == "فعال" or Ptrn:lower() == "on" then
				if redis:get(MarkreadStatusHash) then
					sendText(msg.chat_id_, "> خواندن پیام ها توسط ربات از قبل فعال بوده است.", msg.id_)
					return
				end
				redis:set(MarkreadStatusHash, true)
				sendText(msg.chat_id_, "> خواندن پیام های ربات فعال شد!\nهم اکنون پیام هایی که برای ربات ارسال میشود تیک دوم (تیک خوانده شدن پیام) را دریافت خواهند کرد.", msg.id_)
			end
			if Ptrn == "غیر فعال" or Ptrn == "غیرفعال" or Ptrn:lower() == "off" then
				if redis:get(MarkreadStatusHash) then
					redis:del(MarkreadStatusHash)
					sendText(msg.chat_id_, "> خواندن پیام ها توسط ربات غیرفعال شد.", msg.id_)
					return
				end
				sendText(msg.chat_id_, "> خواندن پیام ها توسط ربات از قبل غیرفعال بوده است.", msg.id_)
			end
		end
		--------------------------------------------------------
		
		-- CMD => /join [link] | Join a Link ...
		if (Cmd:match("^[/!#]([Jj][Oo][Ii][Nn]) (.*)$") or Cmd:match("^(وارد شو) (.*)$")) and isSudo(msg.sender_user_id_) then
			Data = loadJson(Config.ModFile)
			MatchesEN = {Cmd:match("^[/!#]([Jj][Oo][Ii][Nn]) (.*)$")}; MatchesFA = {Cmd:match("^(وارد شو) (.*)$")}
			LinkToJoin = MatchesEN[2] or MatchesFA[2]
			if LinkToJoin:match("t.me/joinchat") then
				LinkToJoin = LinkToJoin:gsub("t.me/", "telegram.me/")
			end
			importLink(LinkToJoin)
			Text = "ربات وارد این لینک شد :"
			.."\n> "..LinkToJoin
			sendText(msg.chat_id_, Text, msg.id_)
		end
		---------------------------------------------------------
		
		--> CMD => /botpanel | get the panel of Robot ...
		if (CmdLower:match("^[/!#](botpanel)$") or Cmd:match("^(پنل ربات)$")) and isSudo(msg.sender_user_id_) then
			-- Monshi
			ClerkStatus = "غیرفعال 🚫"
			ClerkMessage = "این اکانت ربات است"
			if redis:get(ClerkStatusHash) then
				ClerkStatus = "فعال ✅"
			end
			if redis:get(ClerkMessageHash) then
				ClerkMessage = redis:get(ClerkMessageHash)
			end
			---------
			Text = "⚙️ به پنل ربات خوش آمدید !"
			.."\n\n"
			.."— منشی :"
			.."\nوضعیت منشی : "..ClerkStatus
			.."\nپیام منشی : "..ClerkMessage
			.."\n"
			.."\n— دستورات مرتبط :"
			.."\nدریافت لیست گروه های ربات :\n/gplist"
			.."\nفعال/غیرفعال کردن منشی :\n/clerk [on/off]"
			.."\nتنظیم متن منشی :\n/setclerkmsg [متن-پیام-منشی]"
			sendText(msg.chat_id_, Text, msg.id_)
		end
		------------------------------------------->
		
		--> CMD => /panel [GroupId] | Get Panel of a Group ...
		if (CmdLower:match("^[/!#](panel) (-%d+)$") or Cmd:match("^(پنل) (-%d+)$")) and isSudo(msg.sender_user_id_) then
			MatchesEN = {CmdLower:match("^[/!#](panel) (-%d+)$")}; MatchesFA = {Cmd:match("^(پنل) (-%d+)$")}
			ChatId = MatchesEN[2] or MatchesFA[2]
			tdcli_function({
				  ID = "GetInlineQueryResults",
				  bot_user_id_ = tonumber(ApiBotId),
				  chat_id_ = msg.chat_id_,
				  user_location_ = {
					ID = "Location",
					latitude_ = 0,
					longitude_ = 0
				  },
				  query_ = tostring(ChatId),
				  offset_ = 0
				}, 
				function (Ex, Res)
					local msg = Ex.msg
					tdcli_function({
						ID = "SendInlineQueryResultMessage",
						chat_id_ = msg.chat_id_,
						reply_to_message_id_ = msg.id_,
						disable_notification_ = 0,
						from_background_ = 1,
						query_id_ = Res.inline_query_id_,
						result_id_ = Res.results_[0].id_
					  }, dl_cb, nil)
				end
			, {msg = msg})
			sleep(0.5)
			tdcli.getChat(tostring(ChatId),
				function (Ex, Res)
					local msg = Ex.msg
					ChatTitle = Res.title_
					Text = "نام گروه: "..ChatTitle
					.."\nشناسه گروه : "..ChatId
					sendText(msg.chat_id_, Text, msg.id_)
				end
			, {msg = msg})
		end
		------------------------------------------->
		
		--> CMD => /charge [GroupId] [Charge] | Charge a Group Out of That ...
		if (CmdLower:match("^[/!#](charge) (-%d+) (.*)$") or Cmd:match("^(شارژ) (-%d+) (.*)$")) and isSudo(msg.sender_user_id_) then
			MatchesEN = {CmdLower:match("^[/!#](charge) (-%d+) (.*)$")}; MatchesFA = {Cmd:match("^(شارژ) (-%d+) (.*)$")}
			ChatId = tostring(MatchesEN[2]) or tostring(MatchesFA[2])
			Ptrn = MatchesEN[3] or MatchesFA[3]
			if not Data[tostring(ChatId)] then
				Text = "`>` این گروه در لیست گروه های مدیریت شده ربات وجود ندارد !"
				.."\n"..ChatId
				sendText(msg.chat_id_, Text, msg.id_, 'md')
				return
			end
			
			if Ptrn == "unlimit" or Ptrn == "نامحدود" then --> Unlimit Charge
				Hash = ChargeHash..ChatId
				if tostring(redis:get(Hash)):lower() == "unlimit" then
					Text = "`>` شارژ این گروه با شناسه `"..ChatId.."` از قبل نامحدود بوده است."
					sendText(msg.chat_id_, Text, msg.id_, 'md')
					return
				end
				redis:set(Hash, "unlimit")
				Text = "`>` این گروه با شناسه `"..ChatId.."` بصورت نامحدود شارژ شد. ✅"
				sendText(msg.chat_id_, Text, msg.id_, 'md')
				return
			end
			
			if Ptrn:match("^(%d+)(.*)$") then
				Hash = ChargeHash..ChatId
				MatCh = {Ptrn:match("^(%d+)(.*)$")}
				ChargeNum = tonumber(MatCh[1])
				ChargeType = tostring(MatCh[2])
				if (ChargeType:lower() == "m" or ChargeType == "دقیقه") then
					TimeInSec = ChargeNum * MinInSec
				elseif (ChargeType:lower() == "h" or ChargeType == "ساعت") then
					TimeInSec = ChargeNum * HourInSec
				elseif (ChargeType:lower() == "d" or ChargeType == "روز") then
					TimeInSec = ChargeNum * DayInSec
				elseif (ChargeType:lower() == "s" or ChargeType == "ثانیه") then
					TimeInSec = ChargeNum
				else
					Text = "`>` نوع شارژ باید یکی از عبارت های [روز،ساعت،دقیقه،ثانیه] باشه."
					.."\n`>` Charge type must be one of [*d*,*h*,*m*,*s*]"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
					return
				end
				
				A = convertTime(TimeInSec)
				StrDay = A.Day
				StrHour = A.Hour
				StrMin = A.Min
				StrSec = A.Sec
				redis:setex(Hash, TimeInSec, "true")
				Text = "شناسه گروه : "..ChatId
				.."\n\n> شارژ این گروه برای مدت"
				.."\n"..StrDay.."روز"
				.."\n"..StrHour.."ساعت"
				.."\n"..StrMin.."دقیقه"
				.."\nو "..StrSec.."ثانیه"
				.."\nتنظیم شد ✅"
				sendText(msg.chat_id_, Text, msg.id_)
			end
		end
		------------------------------------------->
		
		if (CmdLower:match("^[/!#](expire) (-%d+)$") or Cmd:match("^(انقضا) (-%d+)$")) and isSudo(msg.sender_user_id_) then
			MatchesEN = {CmdLower:match("^[/!#](expire) (-%d+)$")}; MatchesFA = {Cmd:match("^(انقضا) (-%d+)$")}
			ChatId = tostring(MatchesEN[2] or MatchesFA[2])
			Hash = "enigma:cli:charge:"..ChatId
			Data = loadJson(Config.ModFile)
			
			if not Data[tostring(ChatId)] then
				Text = "`>` این گروه با شناسه `"..ChatId.."` در لیست گروه های مدیریت شده ربات قرار ندارد!"
				sendText(msg.chat_id_, Text, msg.id_, 'md')
				return
			end
			
 			if tostring(redis:get(Hash)):lower() == "unlimit" then
				ExpireText = "`>` شارژ این گروه نامحدود میباشد !"
			elseif tostring(redis:ttl(Hash)):lower() ~= "-2" then
				ExpireTime = redis:ttl(Hash)
				A = convertTime(ExpireTime)
				StrDay = A.Day
				StrHour = A.Hour
				StrMin = A.Min
				StrSec = A.Sec
				ExpireText = "🔂 از شارژ این گروه"
				.."\n*"..StrDay.."*روز"
				.."\n*"..StrHour.."*ساعت"
				.."\n*"..StrMin.."*دقیقه"
				.."\nو *"..StrSec.."*ثانیه"
				.."\nباقی مانده است."
			else
				ExpireText = "~> شارژ این گروه به اتمام رسیده است !"
			end
			sendText(msg.chat_id_, ExpireText, msg.id_, 'md')
		end
		
	end -- end msg.content_.text_
	
end -- END BOT_MOD.LUA

function helpPlugin(msg) --> HELP.LUA !
	
	if msg.content_.text_ then
	
		Cmd = msg.content_.text_
		CmdLower = msg.content_.text_:lower()
		Data = loadJson(Config.ModFile)
		-- LOCK CMD -----------
		if Data[tostring(msg.chat_id_)] then
			if Data[tostring(msg.chat_id_)]["settings"] then
				if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] then
					if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] == "yes" and not isMod(msg.chat_id_, msg.sender_user_id_) then
						return
					end
				end
			end
		end
		-----------------------
		
		if CmdLower:match("^[/!#](help)$") or CmdLower:match("^[/!#](helps)$") or CmdLower:match("^(راهنما)$") then
			sendText(msg.chat_id_, getHelp("HelpList"), msg.id_, 'md')
		elseif CmdLower:match("^[/!#](help) (.*)$") or CmdLower:match("^(راهنمای) (.*)$") then
			MatchesEN = {CmdLower:match("^[/!#](help) (.*)$")}; MatchesFA = {CmdLower:match("^(راهنمای) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn == "locks" or Prtn == "lock" or Ptrn == "قفل" or Ptrn == "قفل ها" then
				sendText(msg.chat_id_, getHelp("LocksHelp"), msg.id_, 'md')
			elseif Ptrn == "ban" or Ptrn == "bans" or Ptrn == "مسدود" then
				sendText(msg.chat_id_, getHelp("BanHelp"), msg.id_, 'md')
			elseif Ptrn == "fun" or Ptrn == "funs" or Ptrn == "فان" or Ptrn == "سرگرمی" then
				sendText(msg.chat_id_, getHelp("FunHelp"), msg.id_, 'md')
			elseif Ptrn == "moderation" or Ptrn == "mod" or Ptrn == "مدیریت" or Ptrn == "مدیریتی" then
				sendText(msg.chat_id_, getHelp("ModerationHelp"), msg.id_, 'md')
			else
				Text = [[
راهنمای درخواستی شما یافت نشد!
———————————
لیست راهنمای ربات:

1- راهنمای قفل
2- راهنمای مدیریتی
3- راهنمای مسدود
4- راهنمای فان
> جهت دریافت هر راهنما تنها کافیست نام آن را تایپ کنید.
]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
		
	end -- END msg.content_.text_

end --> END HELP.LUA !

--[[

	Powered By :
		 _____       _  ____
		| ____|_ __ (_)/ ___|_ __ ___   __ _ TM
		|  _| | '_ \| | |  _| '_ ` _ \ / _` |
		| |___| | | | | |_| | | | | | | (_| |
		|_____|_| |_|_|\____|_| |_| |_|\__,_|
	
	****************************
	*  >> By : Reza Mehdipour  *
	*  > Channel : @EnigmaTM   *
	****************************
	
]]

--> FUNCTIONS PLACED WHITH PLUGINS .
KickTable = {}
function antiFloodPlugin(msg) --> ANTI_FLOOD.LUA
	Data = loadJson(Config.ModFile)
	
	if not Data[tostring(msg.chat_id_)] then
		return
	end
	if isMod(msg.chat_id_, msg.sender_user_id_) then
		return
	end
	if msg.service_ then
		return
	end
	
	if Data[tostring(msg.chat_id_)]['settings']['flood_num'] then
		local FloodMax = tonumber(Data[tostring(msg.chat_id_)]['settings']['flood_num']) or 5
		local FloodTime = 2 -- in Sec
		if Data[tostring(msg.chat_id_)]['settings']['lock_flood'] then
			local FloodReaction = redis:get("enigma:cli:flood_stats:"..msg.chat_id_) or "none"
			if Data[tostring(msg.chat_id_)]['settings']['lock_flood'] == "yes" then
				local Hash = 'enigma:cli:flood:'..msg.sender_user_id_..':'..msg.chat_id_
				UserMsgs = tonumber(redis:get(Hash)) or 0
				if UserMsgs > (FloodMax - 1) then
					deleteMessagesFromUser(msg.chat_id_, msg.sender_user_id_)
					if FloodReaction == "kick_user" then
						kickUser(msg.chat_id_, msg.sender_user_id_)
						Text = "⛔️ کاربر <user>"..msg.sender_user_id_.."</user> در گروه پیام رگباری فرستاد!\n> او به دلیل تنظیم بودن عملکرد رگباری روی اخراج کاربر، از گروه اخراج شد."
					else
						Text = "⛔️ کاربر <user>"..msg.sender_user_id_.."</user> در گروه پیام رگباری فرستاد!\nکلیه پیام های ارسالی او در گروه حذف گردیدند."
					end
					if KickTable[msg.sender_user_id_] == true then
						return
					end
					sendText(msg.chat_id_, Text, msg.id_, false, msg.sender_user_id_)
					KickTable[msg.sender_user_id_] = true
				end
				redis:setex(Hash, FloodTime, UserMsgs+1)
			end
		end
	end
end -- END ANTI_FLOOD.LUA

function secPlugin(msg, data) --> SEC.LUA
	
	local function isLink(text) --> Finding Link in a Message Function
		if text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Mm][Ee]/")
		or text:match("[Tt][Ll][Gg][Rr][Mm].[Mm][Ee]/")
		or text:match("[Tt].[Mm][Ee]/")
		or text:match("[Hh][Tt][Tt][Pp][Ss]://") 
		or text:match("[Hh][Tt][Tt][Pp]://")
		or text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Oo][Rr][Gg]")
		or text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Dd][Oo][Gg]")
		or text:match("[Ww][Ww][Ww].")
		or text:match(".[Cc][Oo][Mm]")
		or text:match(".[Ii][Rr]")
		or text:match(".[Oo][Rr][Gg]")
		or text:match(".[Nn][Ee][Tt]") then
			return true
		end
	 return false
	end
	
	local function isAbuse(text) --> Finding Abuse in a Message Function
		if text:match("کیر")
		or text:match("کون")
		or text:match("فاک") 
		or text:lower():match("fuck")
		or text:lower():match("pussy")
		or text:lower():match("sex")
		or text:match("عوضی")
		or text:match("آشغال")
		or text:match("جنده")
		or text:match("سیکتیر")
		or text:match("سکس")
		or text:lower():match("siktir")
		or text:match("دیوث") then
			return true
		end
	  return false
	end
	
	Data = loadJson(Config.ModFile)
	--> OnService Plugin ...
	if msg.service_ and msg.content_.ID == "MessageChatAddMembers" then
		for i=0, #msg.content_.members_ do
			if msg.content_.members_[i].id_ == BotId then
				if not isSudo(msg.sender_user_id_) and not Data[tostring(msg.chat_id_)] then
					sendText(msg.chat_id_, 'شما نمیتوانید مرا به گروهتان اضافه کنید!\nجهت خریداری ربات  پیام دهید:\n> '..SupportBotUsername, 'html')
					kickUser(msg.chat_id_, BotId)
					break
				end
			end
		end
	end
	
	--> If Group Wasn't Moderated The Do Nothing ...
	if not Data[tostring(msg.chat_id_)] then
		return
	end
	
	if Data[tostring(msg.chat_id_)]['settings'] then
		
		lock_strict = 'no' --> Lock Strict
		if Data[tostring(msg.chat_id_)]['settings']['lock_strict'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_strict'] == 'yes' then
				lock_strict = 'yes'
			end
		end
		
		if Data[tostring(msg.chat_id_)]['settings']['show_edit'] then
			if Data[tostring(msg.chat_id_)]['settings']['show_edit'] == "yes" then
				if msg.content_.text_ or msg.content_.caption_ then
					ContentToSave = msg.content_.text_ or msg.content_.caption_
					redis:hset(ShowEditHash, msg.chat_id_..":"..msg.id_, ContentToSave)
				end
			end
		end
		
		--> Lock Bot
		if Data[tostring(msg.chat_id_)]['settings']['lock_bot'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_bot'] == "yes" then
				
				getUser(msg.sender_user_id_, 
					function (Ex, Res)
						local msg = Ex.msg
						if Res.user_ then
							if Res.user_.type_ then
								if Res.user_.type_.ID == "UserTypeBot" then
									if not isMod(msg.chat_id_, msg.sender_user_id_) then
										kickUser(msg.chat_id_, msg.sender_user_id_)
									end
								end
							end
						end
					end
				, {msg = msg})
				
				if msg.service_ and msg.content_.ID == "MessageChatAddMembers" then
					for i=1, #msg.content_.members_ do
						if msg.content_.members_[i].type_.ID == "UserTypeBot" then
							if not isMod(msg.chat_id_, msg.content_.members_[i].id_) then
								kickUser(msg.chat_id_, msg.content_.members_[i].id_)
							end
						end
					end
				end
			end
		end
		-- End Lock Bot
		
		--> lock all (lock chat)
		if Data[tostring(msg.chat_id_)]['settings']['lock_all'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_all'] == 'yes' and not msg.service_ then
				if not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end		
		if redis:get("enigma:cli:lock_chat_time:"..msg.chat_id_) then -- lock all (time)
			if tostring(redis:get("enigma:cli:lock_chat_time:"..msg.chat_id_)) == "true" then
				if not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		-- End Lock All
		
		--> Delete Silented Users's Message
		if isSilentUser(msg.chat_id_, msg.sender_user_id_) and not isMod(msg.chat_id_, msg.sender_user_id_) then
			deleteMessage(msg.chat_id_, msg.id_)
		end
		
		-- Kick Banned User
		if isBannedUser(msg.chat_id_, msg.sender_user_id_) and not isMod(msg.chat_id_, msg.sender_user_id_) then
			kickUser(msg.chat_id_, msg.sender_user_id_)
		end
		
		-- lock link (On msg.content_.text_ AND msg.media.caption)
		if Data[tostring(msg.chat_id_)]['settings']['lock_link'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_link'] == 'yes' then
				if msg.content_.text_ or msg.content_.caption_ then
					TextToFindLink = msg.content_.text_ or msg.content_.caption_
					if isLink(TextToFindLink) or (data.message_.content_.entities_ and data.message_.content_.entities_[0] and data.message_.content_.entities_[0].ID == 'MessageEntityTextUrl') or (msg.content_.text_ and msg.content_.web_page_) then
						if not isMod(msg.chat_id_, msg.sender_user_id_) then
							deleteMessage(msg.chat_id_, msg.id_)
							if lock_strict == 'yes' then
								kickUser(msg.chat_id_, msg.sender_user_id_)
							end
						end
					end
				end
			end
		end
		-- End Lock Link
		
		--> Lock Spam
		if Data[tostring(msg.chat_id_)]['settings']['lock_spam'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_spam'] == 'yes' then
				if msg.content_.text_ then
					if (utf8.len(msg.content_.text_) > 2500) and not isMod(msg.chat_id_, msg.sender_user_id_) then
						deleteMessage(msg.chat_id_, msg.id_)
						Text = "✖️ کاربر <user>"..(msg.from.first_name or "---").."</user>، پیام شما به دلیل طولانی بودن حذف شد."
						sendText(msg.chat_id_, Text, false, false, msg.sender_user_id_)
					end
				end
			end
		end
		-- End Lock Spam
		
		-- Rem msg with filtered word !
		if tonumber(redis:scard("enigma:cli:filtered_words:"..msg.chat_id_)) > 0 then
			FilteredWords = redis:smembers("enigma:cli:filtered_words:"..msg.chat_id_)
			if msg.content_.text_ then
				for i=1, #FilteredWords do
					if string.match(msg.content_.text_:lower(), FilteredWords[i]) then
						if not isMod(msg.chat_id_, msg.sender_user_id_) then
							deleteMessage(msg.chat_id_, msg.id_)
						end
					end
				end
			end
		end
		-- End Filtered Words
		
		-- Lock abuse (fosh)
		if Data[tostring(msg.chat_id_)]['settings']['lock_abuse'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_abuse'] == 'yes' then
				if msg.content_.text_ or msg.content_.caption_ then
					if not isMod(msg.chat_id_, msg.sender_user_id_) then
						TextToCheckForAbuse = msg.content_.text_ or msg.content_.caption_
						if isAbuse(TextToCheckForAbuse) then
							deleteMessage(msg.chat_id_, msg.id_)
						end
					end
				end
			end
		end
		-- End Lock Fosh
		
		-- Lock forward
		if Data[tostring(msg.chat_id_)]['settings']['lock_forward'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_forward'] == 'yes' then
				if msg.forward and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		-- End Lock Forward
		
		-- Lock inline
		if Data[tostring(msg.chat_id_)]['settings']['lock_inline'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_inline'] == 'yes' then
				if msg.inline and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		-- End Lock Inline
		
		-- Lock Bot (Using in Inline Mode)
		if Data[tostring(msg.chat_id_)]['settings']['lock_bot'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_bot'] == 'yes' then
				if msg.via_bot_user_id_ and msg.via_bot_user_id_ ~= 0 then
					if not isMod(msg.chat_id_, msg.sender_user_id_) then
						deleteMessage(msg.chat_id_, msg.id_)
					end
				end
			end
		end
		-- End Lock Bot
		
		-- Lock TgService
		if Data[tostring(msg.chat_id_)]['settings']['lock_tgservice'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_tgservice'] == 'yes' then
				if msg.service_ then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		-- End Lock TgService
		
		-- lock_wlc and lock_bye
		if msg.service_ then
			if msg.content_.ID == "MessageChatJoinByLink" then
				if Data[tostring(msg.chat_id_)]['settings']['lock_wlc'] then
					if Data[tostring(msg.chat_id_)]['settings']['lock_wlc'] == 'yes' then
						Text = "سلام 🌹\nبه گروه خوش اومدی !"
						if redis:get(WelcomeMessageHash..msg.chat_id_) then
							Text = redis:get(WelcomeMessageHash..msg.chat_id_)
							Text = Text:gsub("ID",(msg.sender_user_id_ or ''))
						end
						sendText(msg.chat_id_, Text, msg.id_)
					end
				end
			elseif msg.content_.ID == "MessageChatDeleteMember" then
				if Data[tostring(msg.chat_id_)]['settings']['lock_bye'] then
					if Data[tostring(msg.chat_id_)]['settings']['lock_bye'] == 'yes' then
						UserFirst = msg.content_.user_.first_name_
						Text = "بدرود "..UserFirst.."\nشما از گروه رفتی!"
						sendText(msg.chat_id_, Text, msg.id_)
					end
				end
			end
			
			if msg.content_.ID == "MessageChatAddMembers" then
				if Data[tostring(msg.chat_id_)]['settings']['lock_wlc'] then
					if Data[tostring(msg.chat_id_)]['settings']['lock_wlc'] == 'yes' then
						if #msg.content_.members_ == 1 then
							Text = "سلام "..msg.content_.members_[0].first_name_.." 🌹\nبه گروه خوش اومدی !"
							if redis:get(WelcomeMessageHash..msg.chat_id_) then
								Text = redis:get(WelcomeMessageHash..msg.chat_id_)
								Text = Text:gsub("FIRSTNAME",(msg.content_.members_[0].first_name_ or ''))
								Text = Text:gsub("LASTNAME",(msg.content_.members_[0].last_name_ or ''))
								Text = Text:gsub("USERNAME",(msg.content_.members_[0].username_ or ''))
								Text = Text:gsub("ID",(msg.content_.members_[0].id_ or ''))
							end
							sendText(msg.chat_id_, Text, msg.id_)
						elseif #msg.content_.members_ > 1 then
							Text = "سلام ، به گروه خوش اومدید 🌹"
							sendText(msg.chat_id_, Text, msg.id_)
						end
					end
				end
			end
		end
		-- End lock_wlc and lock_bye
		
		-- lock text
		if Data[tostring(msg.chat_id_)]['settings']['lock_text'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_text'] == "yes" then
				if msg.content_.text_ and not msg.media_ and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
		-- lock english
		if Data[tostring(msg.chat_id_)]['settings']['lock_english'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_english'] == "yes" then
				if msg.content_.text_ and (msg.content_.text_:match("[A-Z]") or msg.content_.text_:match("[a-z]")) then
					if not isMod(msg.chat_id_, msg.sender_user_id_) then
						deleteMessage(msg.chat_id_, msg.id_)
					end
				end
			end
		end
		
		-- lock persian/arabic
		if Data[tostring(msg.chat_id_)]['settings']['lock_arabic'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_arabic'] == "yes" then
				if msg.content_.text_ and msg.content_.text_:match("[\216-\219][\128-\191]") then
					if not isMod(msg.chat_id_, msg.sender_user_id_) then
						deleteMessage(msg.chat_id_, msg.id_)
					end
				end
			end
		end
		
		-- lock username (@)
		if Data[tostring(msg.chat_id_)]['settings']['lock_username'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_username'] == "yes" then
				if msg.content_.text_ or msg.content_.caption_ then
					TextToCheck = msg.content_.text_ or msg.content_.caption_
					if TextToCheck:match("@") then
						if not isMod(msg.chat_id_, msg.sender_user_id_) then
							deleteMessage(msg.chat_id_, msg.id_)
						end
					end
				end
			end
		end
		
		-- lock tag (#)
		if Data[tostring(msg.chat_id_)]['settings']['lock_tag'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_tag'] == "yes" then
				if msg.content_.text_ or msg.content_.caption_ then
					TextToCheck = msg.content_.text_ or msg.content_.caption_
					if TextToCheck:match("#") then
						if not isMod(msg.chat_id_, msg.sender_user_id_) then
							deleteMessage(msg.chat_id_, msg.id_)
						end
					end
				end
			end
		end
		
		-- lock photo
		if Data[tostring(msg.chat_id_)]['settings']['lock_photo'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_photo'] == 'yes' then
				if msg.content_.photo_ and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
		-- lock sticker
		if Data[tostring(msg.chat_id_)]['settings']['lock_sticker'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_sticker'] == 'yes' then
				if msg.content_.sticker_ and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
		-- lock audio and voice
		if Data[tostring(msg.chat_id_)]['settings']['lock_audio'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_audio'] == 'yes' then
				if (msg.content_.audio_ or msg.content_.voice_) and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
		-- lock video
		if Data[tostring(msg.chat_id_)]['settings']['lock_video'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_video'] == 'yes' then
				if msg.content_.video_ and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
		-- lock document
		if Data[tostring(msg.chat_id_)]['settings']['lock_document'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_document'] == 'yes' then
				if msg.content_.document_ and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
		-- lock inline keyboard
		if Data[tostring(msg.chat_id_)]['settings']['lock_inline'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_inline'] == 'yes' then
				if (data.message_.reply_markup_ and data.message_.reply_markup_.ID == "ReplyMarkupInlineKeyboard") and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
		-- lock gif
		if Data[tostring(msg.chat_id_)]['settings']['lock_gif'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_gif'] == 'yes' then 
				if msg.content_.animation_ and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
		-- lock contact
		if Data[tostring(msg.chat_id_)]['settings']['lock_contact'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_contact'] == 'yes' then
				if msg.content_.contact_ and not isMod(msg.chat_id_, msg.sender_user_id_) then
					deleteMessage(msg.chat_id_, msg.id_)
				end
			end
		end
		
	end -- End Of < if Data[tostring(msg.chat_id_)]['settings'] then >
	
end -- End SEC.LUA

function chargePlugin(msg) --> CHARGE.LUA !
	
	Data = loadJson(Config.ModFile)
	if not Data[tostring(msg.chat_id_)] then
		return
	end
	
	Hash = "enigma:cli:charge:"..msg.chat_id_
	
	if tostring(redis:ttl(Hash)) == "-2" and tostring(redis:get(Hash)):lower() ~= "unlimit" then
		TextForGroup =  "🚫 شارژ این گروه به پایان رسید."
		.."\nجهت شارژ مجدد این گروه به ما پیام دهید :"
		.."\n"..SupportBotUsername
		--
		if Data[tostring(msg.chat_id_)]['set_owner'] and tostring(Data[tostring(msg.chat_id_)]['set_owner']) ~= "0" then
			GroupOwner = tonumber(Data[tostring(msg.chat_id_)]['set_owner'])
			Text = "شارژ گروه شما با شناسه"
			.."\n"..msg.chat_id_
			.."\nبه پایان رسیده است !"
			.."\n> جهت شارژ به ما پیام دهید :"
			.."\n"..SupportBotUsername
			sendText(GroupOwner, Text)
		else
			GroupOwner = 'تنظیم نشده!'
		end
		if Data[tostring(msg.chat_id_)]['settings']['set_link'] then
			GroupLink = Data[tostring(msg.chat_id_)]['settings']['set_link']
		else
			GroupLink = "تنظیم نشده!"
		end
		TextForSudo = "🚫 شارژ یک گروه تمام شد !"
		..'\n'
		.."\n— مشخصات گروه :"
		.."\nشناسه گروه : <code>"..msg.chat_id_.."</code>"
		.."\nشناسه مدیر اصلی : "..GroupOwner
		.."\nلینک ثبت شده : "..GroupLink
		.."\n"
		.."\n— دستورات پیشفرض :"
		..'\n<code>></code> دستور خروج ربات از آنجا :'
		..'\n<code>/exit '..msg.chat_id_..'</code>'
		..'\n<code>></code> حذف گروه از لیست گروه ها :'
		..'\n<code>/rem '..msg.chat_id_..'</code>'
		..'\n<code>></code> شارژ آن گروه برای 30روز :'
		..'\n<code>/charge '..msg.chat_id_..' 30d</code>'
		sendText(msg.chat_id_, TextForGroup)
		sendText(GeneralSudoId, TextForSudo, 0, 'html')
		kickUser(msg.chat_id_, BotId)
	end
	
	if msg.content_.text_ then
		Cmd = msg.content_.text_
		CmdLower = msg.content_.text_:lower()
		
		-- Charge Unlimit [in Group]
		if (CmdLower:match("^[/!#](charge) (.*)$") or Cmd:match("^(شارژ) (.*)$")) and isSudo(msg.sender_user_id_) then
			MatchesEN = {CmdLower:match("^[/!#](charge) (.*)$")}; MatchesFA = {Cmd:match("^(شارژ) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn == "unlimit" or Ptrn == "نامحدود" then
				if tostring(redis:get(Hash)):lower() == "unlimit" then
					Text = "`>` شارژ این گروه از قبل نامحدود بوده است."
					sendText(msg.chat_id_, Text, msg.id_, 'md')
					return
				end
				redis:set(Hash,"unlimit")
				Text = "`>` این گروه بصورت نامحدود شارژ شد. ✅"
				sendText(msg.chat_id_, Text, msg.id_, 'md')
				return
			end
		end
		
		if (CmdLower:match("^[/!#](charge) (%d+)(.*)$") or Cmd:match("^(شارژ) (%d+)(.*)$")) and isSudo(msg.sender_user_id_) then -- lock options
			MatchesEN = {CmdLower:match("^[/!#](charge) (%d+)(.*)$")}; MatchesFA = {Cmd:match("^(شارژ) (%d+)(.*)$")}
			ChargeNum = tonumber(MatchesEN[2]) or tonumber(MatchesFA[2])
			ChargeType = MatchesEN[3] or MatchesFA[3]
			if (ChargeType:lower() == "m" or ChargeType == "دقیقه") then
				TimeInSec = ChargeNum * MinInSec
			elseif (ChargeType:lower() == "h" or ChargeType == "ساعت") then
				TimeInSec = ChargeNum * HourInSec
			elseif (ChargeType:lower() == "d" or ChargeType == "روز") then
				TimeInSec = ChargeNum * DayInSec
			elseif (ChargeType:lower() == "s" or ChargeType == "ثانیه") then
				TimeInSec = ChargeNum
			else
				Text = "`>` نوع شارژ باید یکی از عبارت های [روز،ساعت،دقیقه،ثانیه] باشه."
				.."\n`>` Charge type must be one of [*d*,*h*,*m*,*s*]"
				sendText(msg.chat_id_, Text, msg.id_, 'md')
				return
			end
			
			A = convertTime(TimeInSec)
			StrDay = A.Day
			StrHour = A.Hour
			StrMin = A.Min
			StrSec = A.Sec
			redis:setex(Hash, TimeInSec, "true")
			Text = "`>` شارژ این گروه با شناسه `"..msg.chat_id_.."` برای مدت"
			.."\n*"..StrDay.."*روز"
			.."\n*"..StrHour.."*ساعت"
			.."\n*"..StrMin.."*دقیقه"
			.."\nو *"..StrSec.."*ثانیه"
			.."\nتنظیم شد ✅"
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		end
		
		if (CmdLower:match("^[/!#](expire)$") or Cmd:match("^(انقضا)$")) and isMod(msg.chat_id_, msg.sender_user_id_) then
			if tostring(redis:get(Hash)):lower() == "unlimit" then
				ExpireText = "`>` شارژ این گروه نامحدود میباشد !"
			elseif tostring(redis:ttl(Hash)):lower() ~= "-2" then
				ExpireTime = redis:ttl(Hash)
				A = convertTime(ExpireTime)
				StrDay = A.Day
				StrHour = A.Hour
				StrMin = A.Min
				StrSec = A.Sec
				ExpireText = "🔂 از شارژ این گروه"
				.."\n*"..StrDay.."*روز"
				.."\n*"..StrHour.."*ساعت"
				.."\n*"..StrMin.."*دقیقه"
				.."\nو *"..StrSec.."*ثانیه"
				.."\nباقی مانده است."
			else
				ExpireText = "~> شارژ این گروه به پایان رسیده است !"
			end
			sendText(msg.chat_id_, ExpireText, msg.id_, 'md')
		end
		
	end -- end msg.content_.text_

end -- End CHARGE.LUA


function locksPlugin(msg) --> LOCKS.LUA !
	
	Cmd = msg.content_.text_
	CmdLower = msg.content_.text_:lower()
	Data = loadJson(Config.ModFile)
	
	--> CMD = /add | Adding a Group to Moderated Groups' list
	if (CmdLower:match("^[/!#](add)$") or Cmd:match("^(نصب)$")) and isSudo(msg.sender_user_id_) then
		if not Data[tostring(msg.chat_id_)] then
			Data[tostring(msg.chat_id_)] = {
				moderators = {},
				set_owner = "0",
				settings = {
					
					-- Orginal Locks
					lock_link = "yes",
					lock_edit = "no",
					show_edit = "no",
					lock_forward = "yes",
					lock_inline = "no",
					lock_cmd = "no",
					lock_english = "no",
					lock_arabic = "no",
					lock_username = "no",
					lock_tag = "no",
					lock_spam = "yes",
					lock_bot = "no",
					lock_flood = "yes",
					flood_num = "5",
					lock_tgservice = "yes",
					
					-- Media Locks
					lock_abuse = "no",
					lock_sticker = "no",
					lock_audio = "no",
					lock_photo = "no",
					lock_video = "no",
					lock_text = "no",
					lock_document = "no",
					lock_gif = "no",
					lock_contact = "no",
					
					-- Important Locks
					lock_strict = "no",
					lock_all = "no",
					
					-- Fun Locks
					lock_wlc = "no",
					lock_bye = "no"
				}
			}
			saveJson(Config.ModFile, Data)
			if not Data["groups"] then
				Data["groups"] = {}
				saveJson(Config.ModFile, Data)
			end
			Data["groups"][tostring(msg.chat_id_)] = msg.chat_id_
			saveJson(Config.ModFile, Data)
			redis:setex("enigma:cli:charge:"..msg.chat_id_, 3600, true) --> Adding Charge to Group For 1Hour
			Text = "`>` این گروه به لیست گروه های تحت مدیریت ربات اضافه شد. ✅"
			..'\n_همچنین بصورت پیشفرض برای 1 ساعت شارژ اتوماتیک دریافت کرد._'
			..'\n شناسه گروه : `'..msg.chat_id_..'`'
			sendText(msg.chat_id_, Text, msg.id_, 'md')
			
			TextForSudo = "➕ گروهی به لیست گروه های مدیریتی ربات اضافه شد."
			..'\n'
			..'\n— مشخصات گروه اضافه شده :'
			..'\nشناسه گروه : <code>'..msg.chat_id_..'</code>'
			..'\n'
			..'\n— مشخصات اضافه کننده :'
			..'\nشناسه کاربری : <code>'..msg.sender_user_id_..'</code>'
			..'\n'
			..'\n— دستور های پیشفرض برای گروه :'
			..'\n<code>></code> شارژ گروه برای 30 روز :'
			..'\n<code>/charge '..msg.chat_id_..' 30d</code>'
			..'\n<code>></code> حذف گروه از لیست گروه های مدیریت شده :'
			..'\n<code>/rem '..msg.chat_id_..'</code>'
			..'\n<code>></code> خارج شدن ربات از آن گروه :'
			..'\n<code>/exit '..msg.chat_id_..'</code>'
			sendText(GeneralSudoId, TextForSudo, 0, 'html')
		else
			Text = "`>` این گروه با شناسه `"..msg.chat_id_.."` از قبل در لیست گروه های مدیریت شده ربات قرار داشت."
			..'\n_نیازی به اضافه کردن آن نیست._'
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		end
	end
	
	--> CMD = /rem | Removing Group From Moderated Groups' list ...
	if (CmdLower:match("^[/!#](rem)$") or Cmd:match("^(لغو نصب)$")) and isSudo(msg.sender_user_id_) then
		Data = loadJson(Config.ModFile)
		if Data[tostring(msg.chat_id_)] then
			Data[tostring(msg.chat_id_)] = nil
			saveJson(Config.ModFile, Data)
			if Data["groups"] then
				if Data["groups"][tostring(msg.chat_id_)] then
					Data["groups"][tostring(msg.chat_id_)] = nil
					saveJson(Config.ModFile, Data)
				end
			end
			SilentHash = 'enigma:cli:silent_users:'..msg.chat_id_
			BanUsersHash = "enigma:cli:ban_users:"..msg.chat_id_
			FilteredWordsHash = "enigma:cli:filtered_words:"..msg.chat_id_
			RmsgUsersHash = "enigma:cli:rmsg_users:"..msg.chat_id_
			RulesHash = "enigma:cli:set_rules:"..msg.chat_id_
			ChargeHash = "enigma:cli:charge:"..msg.chat_id_
			BeautyHash = "enigma:cli:beauty_text:"..msg.chat_id_
			redis:del(SilentHash)
			redis:del(BanUsersHash)
			redis:del(FilteredWordsHash)
			redis:del(RmsgUsersHash)
			redis:del(RulesHash)
			redis:del(ChargeHash)
			redis:del(BeautyHash)
			Text = "❌ این گروه با شناسه `"..msg.chat_id_.."` از لیست گروه های مدیریت شده ربات حذف شد."
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		else
			if Data["groups"] then
				if Data["groups"][tostring(msg.chat_id_)] then
					Data["groups"][tostring(msg.chat_id_)] = nil
					saveJson(Config.ModFile, Data)
				end
			end
			Text = "`>` این گروه در لیست گروه های مدیریت شده ربات قرار ندارد!"
			..'\n_نیازی به حذف آن نیست._'
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		end
	end
	------------------------------------------->
	
	-- if Group Wasn't in Moderated Groups' list then Don't do anything ...
	if not Data[tostring(msg.chat_id_)] then
		return
	end
	
	-- Functions For Lock and Unlock ...
	local function lock(msg, LockName, LockedText, AlreadyLockedText)
		Data = loadJson(Config.ModFile)
		if not Data[tostring(msg.chat_id_)] then
			sendText(msg.chat_id_, "`>` این گروه در لیست گروه های مدیریت شده ربات قرار ندارد.", msg.id_, 'md')
			return
		end
		if Data[tostring(msg.chat_id_)]['settings'] then
			if Data[tostring(msg.chat_id_)]['settings'][tostring(LockName)] then
				if Data[tostring(msg.chat_id_)]['settings'][tostring(LockName)] ~= 'yes' then
					Data[tostring(msg.chat_id_)]['settings'][tostring(LockName)] = 'yes'
					saveJson(Config.ModFile, Data)
					sendText(msg.chat_id_, LockedText, msg.id_, 'md')
				else
					sendText(msg.chat_id_, AlreadyLockedText, msg.id_, 'md')
				end
			else
				Data[tostring(msg.chat_id_)]['settings'][tostring(LockName)] = 'yes'
				saveJson(Config.ModFile, Data)
				sendText(msg.chat_id_, LockedText, msg.id_, 'md')
			end
		else
			sendText(msg.chat_id_, "`>` تنظیمات این گروه بدرستی ثبت نشده است!", msg.id_, 'md')
		end
	end
	
	local function unlock(msg, LockName, UnLockedText, AlreadyUnLockedText)
		Data = loadJson(Config.ModFile)
		if not Data[tostring(msg.chat_id_)] then
			sendText(msg.chat_id_, "`>` این گروه در لیست گروه های مدیریت شده ربات قرار ندارد.", msg.id_, 'md')
			return
		end
		if Data[tostring(msg.chat_id_)]['settings'] then
			if Data[tostring(msg.chat_id_)]['settings'][tostring(LockName)] then
				if Data[tostring(msg.chat_id_)]['settings'][tostring(LockName)] ~= 'no' then
					Data[tostring(msg.chat_id_)]['settings'][tostring(LockName)] = 'no'
					saveJson(Config.ModFile, Data)
					sendText(msg.chat_id_, UnLockedText, msg.id_, 'md')
				else
					sendText(msg.chat_id_, AlreadyUnLockedText, msg.id_, 'md')
				end
			else
				Data[tostring(msg.chat_id_)]['settings'][tostring(LockName)] = 'no'
				saveJson(Config.ModFile, Data)
				sendText(msg.chat_id_, AlreadyUnLockedText, msg.id_, 'md')
			end
		else
			sendText(msg.chat_id_, "`>` تنظیمات این گروه بدرستی ثبت نشده است!", msg.id_, 'md')
		end
	end
	
	local function unlock_group_all(msg)
		Data = loadJson(Config.ModFile)
		if not Data[tostring(msg.chat_id_)] or not Data[tostring(msg.chat_id_)]['settings'] then
			sendText(msg.chat_id_, "`>` این گروه در لیست گروه های مدیریت شده ربات قرار ندارد.", msg.id_, 'md')
			return
		end
		if Data[tostring(msg.chat_id_)]['settings']['lock_all'] then
			if Data[tostring(msg.chat_id_)]['settings']['lock_all'] == 'yes' then
				Data[tostring(msg.chat_id_)]['settings']['lock_all'] = 'no'
				saveJson(Config.ModFile, Data)
				Text = [[❌فیلتر همگانی(قفل چت) بصورت عادی فعال بود که غیرفعال شد.]]
				sendText(msg.chat_id_, Text, msg.id_)
				if not redis:get("enigma:cli:lock_chat_time:"..msg.chat_id_) then
					return
				end
			end
		end
		if redis:get("enigma:cli:lock_chat_time:"..msg.chat_id_) then
			redis:del("enigma:cli:lock_chat_time:"..msg.chat_id_)
			Text = [[❌فیلتر همگانی(قفل چت) بصورت زماندار فعال بود که غیرفعال شد.]]
			sendText(msg.chat_id_, Text, msg.id_)
			return
		end
		sendText(msg.chat_id_, "`>` فیلتر همگانی(قفل چت) از قبل غیرفعال بوده است.", msg.id_, 'md')
	end
	------------------------------------------->
	
	if (CmdLower:match("^[/!#](lock) (.*)$") or Cmd:match("^(قفل) (.*)$")) and isMod(msg.chat_id_, msg.sender_user_id_) then -- lock options
		MatchesEN = {CmdLower:match("^[/!#](lock) (.*)$")}; MatchesFA = {Cmd:match("^(قفل) (.*)$")}
		LockName = MatchesEN[2] or MatchesFA[2]	
		
		-- lock link
		if LockName == 'لینک' or LockName:lower() == 'link' or LockName:lower() == 'links' then
			a = [[✅ قفل لینک در گروه فعال شد!
↩️ از هم اکنون ، هر گونه لینک ارسالی توسط کاربران عادی حذف خواهد شد.]]
			b = [[⏺ قفل لینک در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock link*]]
			return lock(msg, 'lock_link', a, b)
		end
		
		-- lock edit
		if LockName == 'ادیت' or LockName == 'ویرایش' or LockName:lower() == 'edit' then
			a = [[✅ قفل اِدیت(ویرایش پیام) در گروه فعال شد!
↩️ از هم اکنون ، هر پیامی که توسط کاربران عادی اِدیت شود پاک خواهد شد.]]
			b = [[⏺ قفل اِدیت(ویرایش پیام) در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock edit*]]
			return lock(msg, 'lock_edit', a, b)
		end
		
		-- lock fwd
		if LockName == 'فروارد' or LockName == 'فوروارد' or LockName:lower() == 'fwd' or LockName:lower() == 'forward' then
			a = [[✅ قفل فروارد(*Forward*) در گروه فعال شد!
↩️ از هم اکنون ، هر پیامی که توسط کاربران عادی از جایی فروارد شود پاک خواهد شد.]]
			b = [[⏺ قفل فروارد(*Forward*) در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock forward*]]
			return lock(msg, 'lock_forward', a, b)
		end
		
		-- lock inline
		if LockName == 'کیبورد' or LockName == 'کیبورد شیشه ای' or LockName:lower() == 'inline' or LockName:lower() == 'keyboard' then
			a = [[✅ قفل کیبورد شیشه ای در گروه فعال شد!
↩️ از هم اکنون ، کیبورد های شیشه ای ارسالی در گروه حذف خواهند شد.]]
			b = [[⏺ قفل کیبورد شیشه ای در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock inline*]]
			return lock(msg, 'lock_inline', a, b)
		end
		
		-- lock cmd
		if LockName == 'دستورات' or LockName == 'دستورات ربات' or LockName:lower() == 'cmd' or LockName:lower() == 'commands' then
			a = [[✅ قفل دستورات در گروه فعال شد!
↩️ از هم اکنون ، ربات هیچگونه پاسخی به کاربران عادی در گروه نمیدهد.]]
			b = [[⏺ قفل دستورات در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock cmd*]]
			return lock(msg, 'lock_cmd', a, b)
		end
		
		-- lock english
		if LockName == 'متن انگلیسی' or LockName == 'انگلیسی' or LockName:lower() == 'english' or LockName:lower() == 'english text' then
			a = [[✅ قفل انگلیسی نویسی در گروه فعال شد!
↩️ از هم اکنون ، هر گونه متنی که در آن حتی یکی از حروف الفبای انگلیسی پیدا شود پاک خواهد شد.]]
			b = [[⏺ قفل انگلیسی نویسی در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock english*]]
			return lock(msg, 'lock_english', a, b)
		end
		
		-- lock arabic
		if LockName == 'فارسی' or LockName == 'پارسی' or LockName == 'عربی' or LockName:lower() == 'arabic' or LockName:lower() == 'persian' then
			a = [[✅ قفل عربی/پارسی نویسی در گروه فعال شد!
↩️ از هم اکنون ، هر گونه متنی که در آن حتی یکی از حروف الفبای فارسی/عربی یافت شود پاک خواهد شد.]]
			b = [[⏺ قفل عربی/پارسی نویسی در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock arabic*]]
			return lock(msg, 'lock_arabic', a, b)
		end
		
		-- lock username (@)
		if LockName == 'یوزرنیم' or LockName == 'نام کاربری' or LockName:lower() == 'username' or LockName:lower() == '@' then
			a = [[✅ قفل نام کاربری(@) در گروه فعال شد!
↩️ از هم اکنون ، هر گونه متنی که در آن علامت @ یافت شود پاک خواهد شد.]]
			b = [[⏺ قفل نام کاربری(@) در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock username*]]
			return lock(msg, 'lock_username', a, b)
		end
		
		-- lock tag (#)
		if LockName == 'تگ' or LockName == 'هشتگ' or LockName:lower() == 'tag' or LockName:lower() == '#' then
			a = [[✅ قفل تگ(#) در گروه فعال شد!
↩️ از هم اکنون ، هر گونه متنی که در آن علامت # یافت شود پاک خواهد شد.]]
			b = [[⏺ قفل تگ(#) در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock tag*]]
			return lock(msg, 'lock_tag', a, b)
		end
		
		-- lock spam
		if LockName == 'اسپم' or LockName == 'پیام طولانی' or LockName:lower() == 'spam' then
			a = [[✅ قفل پیام های طولانی در گروه فعال شد!
↩️ از هم اکنون ، ربات پیام های طولانی ارسالی توسط کاربران را حذف خواهد کرد.]]
			b = [[⏺ قفل پیام های طولانی در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock spam*]]
			return lock(msg, 'lock_spam', a, b)
		end
		
		-- lock bot
		if LockName == 'ربات' or LockName == 'بات' or LockName:lower() == 'bot' or LockName:lower() == 'bots' then
			a = [[✅ قفل ربات ها در گروه فعال شد!
↩️ از هم اکنون ، ربات های معمولی -که آخر یوزرنیم آنها *bot* دارد- به محض شناسایی از گروه اخراج میگردند.]]
			b = [[⏺ قفل ربات ها در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock bot*]]
			return lock(msg, 'lock_bot', a, b)
		end
		
		-- lock flood
		if LockName == 'رگباری' or LockName == 'مکرر' or LockName:lower() == 'flood' or LockName:lower() == 'floods' then
			a = [[✅ قفل پیام های رگباری در گروه فعال شد!
↩️ از هم اکنون ، اگر کاربری پیام هایش را بصورت رگباری(پشت سر هم) در گروه ارسال کند ، اخراج خواهد شد.]]
			b = [[⏺ قفل پیام های رگباری در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock flood*]]
			return lock(msg, 'lock_flood', a, b)
		end
		
		-- lock tgservice
		if LockName == 'خدمات' or LockName:lower() == 'service' or LockName:lower() == 'tg' or LockName:lower() == 'tgservice' then
			a = [[✅حذف پیام های ورود و خروج در گروه فعال شد!
↩️ از هم اکنون ، پیام های ورود و خروج کاربران در گروه حذف خواهند شد.]]
			b = [[⏺ حذف پیام های ورود و خروج در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock tg*]]
			return lock(msg, 'lock_tgservice', a, b)
		end
		
		-- lock abuse (fosh)
		if LockName == 'فحش' or LockName == 'ناسزا' or LockName:lower() == 'abuse' then
			a = [[✅ قفل فحش در گروه فعال شد!
↩️ از هم اکنون ، اگر کسی در پیام خود از ناسزا و حرف های رکیک استفاده کند پیامش پاک خواهد شد.]]
			b = [[⏺ قفل فحش در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock abuse*]]
			return lock(msg, 'lock_abuse', a, b)
		end
		
		-- lock sticker
		if LockName == 'استیکر' or LockName:lower() == 'sticker' or LockName:lower() == 'stick' then
			a = [[✅ قفل استیکر در گروه فعال شد!
↩️ از هم اکنون ، استیکر های ارسالی کاربران در گروه حذف خواهد شد.]]
			b = [[⏺ قفل استیکر در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock sticker*]]
			return lock(msg, 'lock_sticker', a, b)
		end
		
		-- lock audio and voice
		if LockName == 'صدا' or LockName == 'ویس' or LockName == 'وویس' or LockName:lower() == 'voice' or LockName:lower() == 'audio' then
			a = [[✅ قفل صدا در گروه فعال شد!
↩️ از هم اکنون ، صدا های ارسالی در گروه (صدا و ویس) حذف خواهند شد.]]
			b = [[⏺ قفل صدا در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock audio*]]
			return lock(msg, 'lock_audio', a, b)
		end
		
		-- lock photo
		if LockName == 'عکس' or LockName == 'تصاویر' or LockName == 'تصویر' or LockName:lower() == 'photo' or LockName:lower() == 'pic' then
			a = [[✅ قفل عکس(تصاویر) در گروه فعال شد!
↩️ از هم اکنون ، تصاویر ارسالی توسط کاربران حذف خواهند شد.]]
			b = [[⏺ قفل عکس(تصاویر) در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock photo*]]
			return lock(msg, 'lock_photo', a, b)
		end
		
		-- lock video
		if LockName == 'ویدیو' or LockName == 'فیلم' or LockName:lower() == 'video' or LockName:lower() == 'movie' then
			a = [[✅ قفل ویدیو در گروه فعال شد!
↩️ از هم اکنون ، ویدیو های ارسالی توسط کاربران حذف خواهند شد.]]
			b = [[⏺ قفل ویدیو در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock video*]]
			return lock(msg, 'lock_video', a, b)
		end
		
		-- lock text
		if LockName == 'متن' or LockName == 'تکست' or LockName:lower() == 'text' then
			a = [[✅ قفل متن در گروه فعال شد!
↩️ از هم اکنون ، هر گونه متن ارسالی در گروه پاک خواهد شد.]]
			b = [[⏺ قفل متن در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock text*]]
			return lock(msg, 'lock_text', a, b)
		end
		
		-- lock document
		if LockName == 'فایل' or LockName == 'داکیومنت' or LockName:lower() == 'document' or LockName:lower() == 'file' then
			a = [[✅ قفل فایل(*Document*) در گروه فعال شد!
↩️ از هم اکنون ، فایل های ارسالی توسط کاربران در گروه حذف خواهند شد.]]
			b = [[⏺ قفل فایل در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock file*]]
			return lock(msg, 'lock_document', a, b)
		end
		
		-- lock gif
		if LockName == 'گیف' or LockName == 'انیمیشن' or LockName:lower() == 'gif' or LockName:lower() == 'gifs' or LockName:lower() == 'animation' then
			a = [[✅ قفل گیف(*Gif*) در گروه فعال شد!
↩️ از هم اکنون ، گیف های ارسالی توسط کاربران در گروه حذف خواهند شد.]]
			b = [[⏺ قفل گیف در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock gif*]]
			return lock(msg, 'lock_gif', a, b)
		end
		
		-- lock contact
		if LockName == 'مخاطب' or LockName:lower() == 'contact' or LockName:lower() == 'contacts' then
			a = [[✅ قفل مخاطب(*Contact*) در گروه فعال شد!
↩️ از هم اکنون ، مخاطب های ارسالی توسط کاربران در گروه حذف خواهند شد.]]
			b = [[⏺ قفل مخاطب در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock contact*]]
			return lock(msg, 'lock_contact', a, b)
		end
		
		-- lock strict
		if LockName == 'سخت' or LockName:lower() == 'strict' or LockName:lower() == 'stricts' then
			a = [[✅ قفل سخت(*Strict*) در گروه فعال شد!
↩️ از هم اکنون ، در صورت فعال بودن قفل لینک در گروه :
هر کاربری که لینکی ارسال کند از گروه اخراج خواهد شد.]]
			b = [[⏺ قفل سخت در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock strict*]]
			return lock(msg, 'lock_strict', a, b)
		end
		
		-- lock all
		if LockName == 'چت' or LockName == 'همگانی' or LockName:lower() == 'all' or LockName:lower() == 'chat' then
			a = [[✅ قفل چت(همگانی) در گروه فعال شد!
↩️ از هم اکنون ، هرگونه مطلب ارسالی اعم از پیام متنی و رسانه در گروه توسط کاربران ، حذف خواهند شد. به عبارتی چت بسته شد !]]
			b = [[⏺ قفل چت(همگانی) در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock chat*]]
			return lock(msg, 'lock_all', a, b)
		end
		
		-- lock wlc
		if LockName == 'خوش آمد' or LockName == 'خوشامد' or LockName == 'خوش امد' or LockName:lower() == 'welcome' or LockName:lower() == 'wlc' then
			a = [[✅ پیام خوش آمد گویی در گروه فعال شد!
↩️ از هم اکنون ، ربات به هرکس که وارد گروه شود خوش آمد میگوید.]]
			b = [[⏺ پیام خوش آمد گویی در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock wlc*]]
			return lock(msg, 'lock_wlc', a, b)
		end
		
		-- lock bye
		if LockName == 'خداحافظی' or LockName == 'بدرود' or LockName == 'بای' or LockName:lower() == 'bye' then
			a = [[✅ پیام خداحافظی در گروه فعال شد!
↩️ از هم اکنون ، ربات از هر کسی که از گروه خارج شود خداحافظی میکند.]]
			b = [[⏺ پیام خداحافظی در حال حاضر فعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را غیرفعال کنید :
*/unlock bye*]]
			return lock(msg, 'lock_bye', a, b)
		end
	---------------------------------------------------------------------------------------
	elseif (CmdLower:match("^[/!#](unlock) (.*)$") or Cmd:match("^(بازکردن) (.*)$") or Cmd:match("^(باز کردن) (.*)$")) and isMod(msg.chat_id_, msg.sender_user_id_) then -- lock options
		MatchesEN = {CmdLower:match("^[/!#](unlock) (.*)$")}; MatchesFA1 = {Cmd:match("^(بازکردن) (.*)$")}; MatchesFA2 = {Cmd:match("^(باز کردن) (.*)$")}
		LockName = MatchesEN[2] or MatchesFA1[2] or MatchesFA2[2]
		
		-- unlock link
		if LockName == 'لینک' or LockName:lower() == 'link' or LockName:lower() == 'links' then
			a = [[❌ قفل لینک غیرفعال شد!
↩️ لینک های ارسالی در گروه پاک نخواهند شد.]]
			b = [[❌ قفل لینک در حال حاضر غیرفعال میباشد.
↩️ _نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock link*]]
			return unlock(msg, 'lock_link', a, b)
		end
		
		-- unlock edit
		if LockName == 'ادیت' or LockName == 'ویرایش' or LockName:lower() == 'edit' then
			a = [[❌ قفل اِدیت(ویرایش پیام) غیرفعال شد!
↩️ دیگر پیام های اِدیت شده پاک نخواهند شد.]]
			b = [[❌ قفل اِدیت(ویرایش پیام) در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock edit*]]
			return unlock(msg, 'lock_edit', a, b)
		end
		
		-- unlock fwd
		if LockName == 'فروارد' or LockName == 'فوروارد' or LockName:lower() == 'fwd' or LockName:lower() == 'forward' then
			a = [[❌ قفل فروارد(*Forward*) غیرفعال شد!
↩️ دیگر پیام های فروارد شده پاک نخواهند شد.]]
			b = [[❌ قفل فروارد(*Forward*) در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock forward*]]
			return unlock(msg, 'lock_forward', a, b)
		end
		
		-- unlock inline
		if LockName == 'کیبورد' or LockName == 'کیبورد شیشه ای' or LockName:lower() == 'inline' or LockName:lower() == 'keyboard' then
			a = [[❌ قفل کیبورد شیشه ای غیرفعال شد!
↩️ دیگر کیبورد های شیشه ای پاک نخواهند شد.]]
			b = [[❌ قفل کیبورد شیشه ای در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock inline*]]
			return unlock(msg, 'lock_inline', a, b)
		end
		
		-- unlock cmd
		if LockName == 'دستورات' or LockName == 'دستورات ربات' or LockName:lower() == 'cmd' or LockName:lower() == 'commands' then
			a = [[❌ قفل دستورات غیرفعال شد!
↩️ از هم اکنون ، ربات به کاربران عادی در گروه پاسخ میدهد.]]
			b = [[❌ قفل دستورات در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock cmd*]]
			return unlock(msg, 'lock_cmd', a, b)
		end
		
		-- unlock english
		if LockName == 'متن انگلیسی' or LockName == 'انگلیسی' or LockName:lower() == 'english' or LockName:lower() == 'english text' then
			a = [[❌ قفل انگلیسی نویسی در گروه غیرفعال شد!
↩️ از هم اکنون ، متن های انگلیسی پاک نخواهند شد.]]
			b = [[❌ قفل انگلیسی نویسی در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock english*]]
			return unlock(msg, 'lock_english', a, b)
		end
		
		-- unlock arabic
		if LockName == 'فارسی' or LockName == 'پارسی' or LockName == 'عربی' or LockName:lower() == 'arabic' or LockName:lower() == 'persian' then
			a = [[❌ قفل عربی/پارسی نویسی در گروه غیرفعال شد!
↩️ از هم اکنون ، متن های عربی/پارسی پاک نخواهند شد.]]
			b = [[❌ قفل عربی/پارسی نویسی در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock arabic*]]
			return unlock(msg, 'lock_arabic', a, b)
		end
		
		-- unlock username (@)
		if LockName == 'یوزرنیم' or LockName == 'نام کاربری' or LockName:lower() == 'username' or LockName:lower() == '@' then
			a = [[❌ قفل نام کاربری(@) در گروه غیرفعال شد.]]
			b = [[❌ قفل نام کاربری(@) در حال حاضر غیرفعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock username*]]
			return unlock(msg, 'lock_username', a, b)
		end
		
		-- unlock tag (#)
		if LockName == 'تگ' or LockName == 'هشتگ' or LockName:lower() == 'tag' or LockName:lower() == '#' then
			a = [[❌ قفل تگ(#) در گروه غیرفعال شد.]]
			b = [[❌ قفل تگ(#) در حال حاضر غیرفعال میباشد.
_نیازی به فعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock tag*]]
			return unlock(msg, 'lock_tag', a, b)
		end
		
		-- unlock spam
		if LockName == 'اسپم' or LockName == 'پیام طولانی' or LockName:lower() == 'spam' then
			a = [[❌ قفل پیام های طولانی غیرفعال شد!
↩️ از هم اکنون ، ربات پیام های طولانی را حذف نخواهد کرد.]]
			b = [[❌ قفل پیام های طولانی در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock spam*]]
			return unlock(msg, 'lock_spam', a, b)
		end
		
		-- unlock bot
		if LockName == 'ربات' or LockName == 'بات' or LockName:lower() == 'bot' or LockName:lower() == 'bots' then
			a = [[❌ قفل ربات ها غیرفعال شد!
↩️ از هم اکنون ، ربات های معمولی از گروه اخراج نخواهند شد.]]
			b = [[❌ قفل ربات ها در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock bot*]]
			return unlock(msg, 'lock_bot', a, b)
		end
		
		-- unlock flood
		if LockName == 'رگباری' or LockName == 'مکرر' or LockName:lower() == 'flood' or LockName:lower() == 'floods' then
			a = [[❌ قفل پیام های رگباری غیرفعال شد!
↩️ از هم اکنون ، کاربرانی که پیام رگباری ارسال کنند اخراج نخواهند شد.]]
			b = [[❌ قفل پیام های رگباری در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock flood*]]
			return unlock(msg, 'lock_flood', a, b)
		end
		
		-- unlock tgservice
		if LockName == 'خدمات' or LockName:lower() == 'service' or LockName:lower() == 'tg' or LockName:lower() == 'tgservice' then
			a = [[❌ حذف پیام های ورود و خروج غیرفعال شد!
↩️ از هم اکنون ، پیام ورود و خروج کاربران در گروه حذف نخواهد شد.]]
			b = [[❌حذف پیام های ورود و خروج در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock tg*]]
			return unlock(msg, 'lock_tgservice', a, b)
		end
		
		-- unlock abuse
		if LockName == 'فحش' or LockName == 'ناسزا' or LockName:lower() == 'abuse' then
			a = [[❌ قفل فحش غیرفعال شد!]]
			b = [[❌قفل فحش در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock abuse*]]
			return unlock(msg, 'lock_abuse', a, b)
		end
		
		-- unlock sticker
		if LockName == 'استیکر' or LockName:lower() == 'sticker' or LockName:lower() == 'stick' then
			a = [[❌ قفل استیکر غیرفعال شد!
↩️ از هم اکنون ، استیکر های ارسالی پاک نخواهند شد.]]
			b = [[❌قفل استیکر در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock sticker*]]
			return unlock(msg, 'lock_sticker', a, b)
		end
		
		-- unlock audio and voice
		if LockName == 'صدا' or LockName == 'ویس' or LockName == 'وویس' or LockName:lower() == 'voice' or LockName:lower() == 'audio' then
			a = [[❌ قفل صدا غیرفعال شد!
↩️ از هم اکنون ، صدا های ارسالی پاک نخواهند شد.]]
			b = [[❌قفل صدا در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock audio*]]
			return unlock(msg, 'lock_audio', a, b)
		end
		
		-- unlock photo
		if LockName == 'عکس' or LockName == 'تصاویر' or LockName == 'تصویر' or LockName:lower() == 'photo' or LockName:lower() == 'pic' then
			a = [[❌ قفل عکس(تصاویر) غیرفعال شد!
↩️ از هم اکنون ، تصاویر ارسالی پاک نخواهند شد.]]
			b = [[❌قفل عکس(تصویر) در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock photo*]]
			return unlock(msg, 'lock_photo', a, b)
		end
		
		-- unlock video
		if LockName == 'ویدیو' or LockName == 'فیلم' or LockName:lower() == 'video' or LockName:lower() == 'movie' then
			a = [[❌ قفل ویدیو غیرفعال شد!
↩️ از هم اکنون ، ویدیو های ارسالی پاک نخواهند شد.]]
			b = [[❌قفل ویدیو در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock video*]]
			return unlock(msg, 'lock_video', a, b)
		end
		
		-- unlock text
		if LockName == 'متن' or LockName == 'تکست' or LockName:lower() == 'text' then
			a = [[❌ قفل متن غیرفعال شد!
↩️ از هم اکنون ، متن های ارسالی پاک نخواهند شد.]]
			b = [[❌ قفل متن در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock text*]]
			return unlock(msg, 'lock_text', a, b)
		end
		
		-- unlock document
		if LockName == 'فایل' or LockName == 'داکیومنت' or LockName:lower() == 'document' or LockName:lower() == 'file' then
			a = [[❌ قفل فایل غیرفعال شد!
↩️ از هم اکنون ، فایل های ارسالی پاک نخواهند شد.]]
			b = [[❌قفل فایل در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock file*]]
			return unlock(msg, 'lock_document', a, b)
		end
		
		-- unlock gif
		if LockName == 'گیف' or LockName == 'انیمیشن' or LockName:lower() == 'gif' or LockName:lower() == 'gifs' or LockName:lower() == 'animation' then
			a = [[❌ قفل گیف غیرفعال شد!
↩️ از هم اکنون ، گیف های ارسالی پاک نخواهند شد.]]
			b = [[❌قفل گیف در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock gif*]]
			return unlock(msg, 'lock_gif', a, b)
		end
		
		-- unlock contact
		if LockName == 'مخاطب' or LockName:lower() == 'contact' or LockName:lower() == 'contacts' then
			a = [[❌ قفل مخاطب غیرفعال شد!
↩️ از هم اکنون ، مخاطب های ارسالی پاک نخواهند شد.]]
			b = [[❌قفل مخاطب در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock contact*]]
			return unlock(msg, 'lock_contact', a, b)
		end
		
		-- unlock strict
		if LockName == 'سخت' or LockName:lower() == 'strict' or LockName:lower() == 'stricts' then
			a = [[❌ قفل سخت غیرفعال شد!
↩️ از هم اکنون ، اگر کسی لینکی ارسال کند اخراج نخواهد شد.]]
			b = [[❌قفل سخت در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock strict*]]
			return unlock(msg, 'lock_strict', a, b)
		end
		
		-- unlock all
		if LockName == 'چت' or LockName == 'همگانی' or LockName:lower() == 'all' or LockName:lower() == 'chat' then
			return unlock_group_all(msg)
		end
		
		-- unlock wlc
		if LockName == 'خوش آمد' or LockName == 'خوشامد' or LockName == 'خوش امد' or LockName:lower() == 'welcome' or LockName:lower() == 'wlc' then
			a = [[❌ پیام خوش آمد گویی غیرفعال شد!
↩️ از هم اکنون ، به افرادی که وارد گروه میشوند خوش آمد گفته نمیشود.]]
			b = [[❌پیام خوش آمد گویی در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock wlc*]]
			return unlock(msg, 'lock_wlc', a, b)
		end
		
		-- unlock bye
		if LockName == 'خداحافظی' or LockName == 'بدرود' or LockName == 'بای' or LockName:lower() == 'bye' then
			a = [[❌ پیام خداحافظی غیرفعال شد!
↩️ از هم اکنون ، ربات دیگر خداحافظی نمیکند.]]
			b = [[❌پیام خداحافظی در حال حاضر غیرفعال میباشد.
_نیازی به غیرفعال کردن مجدد آن نیست._
〰 اگر میخواهید آن را فعال کنید :
*/lock bye*]]
			return unlock(msg, 'lock_bye', a, b)
		end
		
	end -- end locks and unlocks
	
	--> CMD => /show edit | Showing Edited Messages ...
	if (CmdLower:match("^[/!#](show) (.*)$") or Cmd:match("^(نمایش) (.*)$")) and isMod(msg.chat_id_, msg.sender_user_id_) then
		MatchesEN = {CmdLower:match("^[/!#](show) (.*)$")}; MatchesFA = {Cmd:match("^(نمایش) (.*)$")}
		Ptrn = MatchesEN[2] or MatchesFA[2]	
		if Ptrn == "ادیت" or Ptrn == "ویرایش" or Ptrn:lower() == "edit" then
			Data = loadJson(Config.ModFile)
			if Data[tostring(msg.chat_id_)]['settings'] then
				if Data[tostring(msg.chat_id_)]['settings']['show_edit'] then
					if Data[tostring(msg.chat_id_)]['settings']['show_edit'] == "yes" then
						Data[tostring(msg.chat_id_)]['settings']['show_edit'] = "no"
						saveJson(Config.ModFile, Data)
						Text = [[❌ نمایش اِدیت(ویرایش پیام) غیرفعال شد.
`>` فعال کردن این قابلیت :
*/show edit*]]
						sendText(msg.chat_id_, Text, msg.id_, 'md')
					else
						Data[tostring(msg.chat_id_)]['settings']['show_edit'] = "yes"
						saveJson(Config.ModFile, Data)
						Text = [[✅ نمایش اِدیت(ویرایش پیام) فعال شد.
◀️ از این به بعد هر کاربری که پیام ارسالی خود را ویرایش کند ربات آن را نشان خواهد داد.
`>` غیرفعال کردن این قابلیت :
*/show edit*]]
						sendText(msg.chat_id_, Text, msg.id_, 'md')
					end
				else
					Data[tostring(msg.chat_id_)]['settings']['show_edit'] = "yes"
					saveJson(Config.ModFile, Data)
					Text = [[✅ نمایش اِدیت(ویرایش پیام) فعال شد.
◀️ از این به بعد هر کاربری که پیام ارسالی خود را ویرایش کند ربات آن را نشان خواهد داد.
`>` غیرفعال کردن این قابلیت :
*/show edit*]]
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				end
			end
		end
	end
	------------------------------------------->
	
	--> CMD => /setflood | set flood max and stats
	if (CmdLower:match("^[/!#](setflood) (.*)$") or Cmd:match("^(تنظیم رگباری) (.*)$")) then
		Data = loadJson(Config.ModFile)
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Owners Only !
		MatchesEN = {CmdLower:match("^[/!#](setflood) (.*)$")}; MatchesFA = {Cmd:match("^(تنظیم رگباری) (.*)$")}
		Ptrn = MatchesEN[2] or MatchesFA[2]
		if Ptrn:match("^%d+$") then
			if tonumber(Ptrn) < 5 or tonumber(Ptrn) > 20 then
				sendText(msg.chat_id_, "`>` عدد انتخاب شده باید بین 5 تا 20 باشد، خارج از آن مجاز نمیباشد.", msg.id_, 'md')
				return
			end
			local FloodMax = tostring(Ptrn)
			Data[tostring(msg.chat_id_)]['settings']['flood_num'] = FloodMax 
			saveJson(Config.ModFile, Data)
			sendText(msg.chat_id_, "`>` حساسیت رگباری به *"..FloodMax.."* پیام در *2* ثانیه تنظیم شد.", msg.id_, 'md')
			return
		else
			FloodStatsHash = "enigma:cli:flood_stats:"..msg.chat_id_
			if (Ptrn:lower() == "kick" or Ptrn == "اخراج") then
				if redis:get(FloodStatsHash) == "kick_user" then
					Text = "🔹عملکرد رگباری هم اکنون روی 'اخراج کاربر' قرار دارد."
					sendText(msg.chat_id_, Text, msg.id_)
					return
				end
				redis:set(FloodStatsHash, "kick_user")
				Text = [[🔹عملکرد رگباری به 'اخراج کاربر' تغییر یافت!
_از هم اکنون اگر کسی در گروه بصورت رگباری پیام ارسال کند ، ربات او را اخراج خواهد کرد._

〰 برگشت به حالت عادی :
*/setflood delmsg*]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			elseif (Ptrn:lower() == "delmsg" or Ptrn == "حذف پیام") then
				if redis:get(FloodStatsHash) == "del_msg" then
					Text = "🔹عملکرد رگباری هم اکنون روی 'حذف پیام ها' قرار دارد."
					sendText(msg.chat_id_, Text, msg.id_)
					return
				end
				redis:set(FloodStatsHash, "del_msg")
				Text = [[🔹عملکرد رگباری به 'حذف پیام' تغییر یافت!
_هم اکنون اگر کسی در گروه بصورت رگباری پیام ارسال کند، ربات تمامی پیام های او را حذف خواهد کرد اما او را اخراج نمیکند._

〰 تنظیم برای اخراج کاربر در صورت رگباری :
*/setflood kick*]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end -- end Ptrn:match("^%d+$")
	end
	------------------------------------------->
	
	--> CMD => /setting | Get settings and locks status of group ...
	if (CmdLower:match("^[/!#](settings)$") or CmdLower:match("^[/!#](setting)$") or Cmd:match("^(تنظیمات)$")) 
	and isMod(msg.chat_id_, msg.sender_user_id_) then
		Data = loadJson(Config.ModFile)
		local Settings = Data[tostring(msg.chat_id_)]['settings']
		
		if redis:get("enigma:cli:charge:"..msg.chat_id_) then --> Group Charge
			ChargeStats = tostring(redis:get("enigma:cli:charge:"..msg.chat_id_)):lower()
			if ChargeStats == "unlimit" then
				GroupCharge = "نامحدود 🔃"
			elseif ChargeStats == "true" then
				GroupCharge = math.floor(redis:ttl("enigma:cli:charge:"..msg.chat_id_)/86400).."روز ✅"
			else
				GroupCharge = "نامعلوم ❌"
			end
		else
			GroupCharge = "تمام شده ⛔️"
		end
		
		FloodStats = redis:get("enigma:cli:flood_stats:"..msg.chat_id_) or "none" --> Flood Stats
		if FloodStats == "kick_user" then
			FloodJob = "اخراج کاربر"
		else
			FloodJob = "حذف پیام کاربر"
		end
		
		local settings_text = "> شناسه گروه : <code>"..msg.chat_id_.."</code>"
		.."\n\nقفل های اصلی :\n________"
		.."\n🔗 قفل لینک : "..(Settings.lock_link or 'no')
		.."\n🏷 قفل ادیت(ویرایش) : "..(Settings.lock_edit or 'no')
		.."\n👁 نمایش ادیت : "..(Settings.show_edit or 'no')
		.."\n➡️ قفل فروارد : "..(Settings.lock_forward or 'no')
		.."\n⌨ قفل کیبورد شیشه ای : "..(Settings.lock_inline or 'no')
		.."\n🖥 قفل دستورات : "..(Settings.lock_cmd or 'no')
		.."\n🔹قفل متن انگلیسی : "..(Settings.lock_english or 'no')
		.."\n🔸قفل متن عربی/پارسی : "..(Settings.lock_arabic or 'no')
		.."\n🔖 قفل پیام های طولانی : "..(Settings.lock_spam or 'no')
		.."\n🔂 قفل پیام های رگباری : "..(Settings.lock_flood or 'no')..
		"\nحساسیت رگباری : <b>"..(Settings.flood_num or '----').."</b>"
		.."\nعملکرد رگباری : "..(FloodJob or 'no')
		.."\n🤖 قفل ورود بات : "..(Settings.lock_bot or 'no')
		.."\n💼 حذف پیام ورود و خروج : "..(Settings.lock_tgservice or 'no')
		.."\n________\n"
		.."\nقفل های معمولی :\n________"
		.."\n⛔️ قفل فحش : "..(Settings.lock_abuse or 'no')
		.."\n#️⃣ قفل تگ(#) : "..(Settings.lock_tag or 'no')
		.."\n👤 قفل یوزرنیم(@) : "..(Settings.lock_username or 'no')
		.."\n________"
		.."\n\nقفل های رسانه :\n________"
		.."\n🔊 قفل صدا : "..(Settings.lock_audio or 'no')
		.."\n🌅 قفل تصاویر : "..(Settings.lock_photo or 'no')
		.."\n🎥 قفل ویدیو : "..(Settings.lock_video or 'no')
		.."\n📥 قفل فایل ها : "..(Settings.lock_document or 'no')
		.."\n☂ قفل گیف ها : "..(Settings.lock_gif or 'no')
		.."\n🚏 قفل استیکر : "..(Settings.lock_sticker or 'no')
		.."\n📍 قفل ارسال مخاطب : "..(Settings.lock_contact or 'no')
		.."\n_________\n\n\nقفل های مهم :\n________"
		.."\n♨️ شرایط سخت : "..(Settings.lock_strict or 'no')
		.."\n🚫 قفل چت : "..(Settings.lock_all or 'no')
		.."\n________\n📬 پیام خوش آمد گویی :"..(Settings.lock_wlc or 'no')
		.."\n📫 پیام خداحافظی : "..(Settings.lock_bye or 'no')
		.."\n________\n🔃انقضا : "..GroupCharge
		settings_text = settings_text:gsub("yes", "✅")
		settings_text = settings_text:gsub("no", "❌")
		sendText(msg.chat_id_, settings_text, msg.id_, 'html')
	end
	
end -- END LOCKS.LUA !

--[[

	Powered By :
		 _____       _  ____
		| ____|_ __ (_)/ ___|_ __ ___   __ _ TM
		|  _| | '_ \| | |  _| '_ ` _ \ / _` |
		| |___| | | | | |_| | | | | | | (_| |
		|_____|_| |_|_|\____|_| |_| |_|\__,_|
	
	****************************
	*  >> By : Reza Mehdipour  *
	*  > Channel : @EnigmaTM   *
	****************************
	
]]

function chatModPlugin(msg) --> CHAT_MOD.LUA !
	
	Cmd = msg.content_.text_
	CmdLower = msg.content_.text_:lower()
	Data = loadJson(Config.ModFile)
	if not Data[tostring(msg.chat_id_)] then
		return
	end
	
	-- LOCK CMD -----------
	if Data[tostring(msg.chat_id_)]["settings"] then
		if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] then
			if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] == "yes" and not isMod(msg.chat_id_, msg.sender_user_id_) then
				return
			end
		end
	end
	-----------------------
	
	--> CMD = /id | Getting ID of User or Group ...
	if CmdLower:match("^[/!#](id)$") or Cmd:match("^(آیدی)$") or Cmd:match("^(ایدی)$") then
		if msg.reply_to_message_id_ then
			if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end
			local function idByReply(Ex, Res)
				local msg = Ex.msg
				Text = '`>` شناسه کاربر : `'..Res.sender_user_id_..'`'
				..'\n`>` شناسه پیام : `'..msg.reply_to_message_id_..'`'
				sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'md')
			end
			getMessage(msg.chat_id_, msg.reply_to_message_id_, idByReply, {msg = msg})
		else
			local function getIdAndProfilePhoto(Ex, Res)
				local msg = Ex.msg
				if Res.photos_[0] then
					Caption = '> شناسه گروه : '..msg.chat_id_
					..'\n> شناسه شما : '..msg.sender_user_id_
					..'\n> تعداد تصاویر پروفایل شما : '..Res.total_count_
					PhotoId = Res.photos_[0].sizes_[1].photo_.persistent_id_
					tdcli.sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, PhotoId, Caption, dl_cb, nil)
				else
					Text = '`>` شناسه گروه : `'..msg.chat_id_..'`'
					..'\n`>` شناسه شما : `'..msg.sender_user_id_..'`'
					..'\n`>` شناسه پیام : `'..msg.id_..'`'
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				end
			end
			getUserProfilePhotos(msg.sender_user_id_, getIdAndProfilePhoto, {msg = msg})
		end
	end
	
	--> CMD = /who | Getting a User Info by id and username ...
	if CmdLower:match("^[/!#](who) (.*)$") or Cmd:match("^(کیست) (.*)$") then
		MatchesEN = {CmdLower:match("^[/!#](who) (.*)$")}; MatchesFA = {Cmd:match("^(کیست) (.*)$")}
		Ptrn = MatchesEN[2] or MatchesFA[2]
		if msg.reply_to_message_id_ then notReply(msg) return end 
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Mods Only !
		if Ptrn:match("@[%a%d]") then --> Get User Info By Username
			Username = Ptrn:gsub("@","")
			resolveUsername(Username, 
				function (Extra, Res)
					local msg = Extra.msg
					if Res.ID == "Error" then
						sendText(msg.chat_id_, "🚫کاربری با این نام کاربری یافت نشد.", msg.id_)
						return
					end
					UserId = Res.type_.user_.id_ or "----"
					UserFullName = Res.title_ or "----"
					UserUsername = (Res.type_.user_.username_ or "----")
					Text = "» اطلاعات کاربر با نام کاربری @"..UserUsername.." :"
					.."\n"
					.."\n<code>></code> نام کامل : <b>"..UserFullName.."</b>"
					.."\n<code>></code> شناسه کاربری : <code>"..UserId.."</code>"
					sendText(msg.chat_id_, Text, msg.id_, 'html')
				end
			, {msg = msg})
		elseif Ptrn:match("^%d+$") then --> Get User Info By id
			UserId = tonumber(Ptrn)
			getUser(UserId, 
				function (Ex, Res)
					local msg = Ex.msg
					if Res.ID == "Error" then
						Text = "🚫 _کاربر مورد نظر یافت نشد !_"
						sendText(msg.chat_id_, Text, msg.id_, 'md')
						return false
					end
					UserFullName = (Res.user_.first_name_ or "").." "..(Res.user_.last_name_ or "")
					Text = "> نام کامل : "..UserFullName
					.."\n» جهت مشاهده پروفایل این کاربر روی مربع زیر کلیک کنید :"
					..[[<user>
█████████
█████████
█████████
█████████</user>]]
					sendText(msg.chat_id_, Text, msg.id_, false, Res.user_.id_)
				end
			, {msg = msg})
		end
	end
	------------------------------------------->
	
	--> CMD = /pin | Pin a message in a chat ...
	if CmdLower:match("^[/!#](pin)$") or Cmd:match("^(پین)$") or Cmd:match("^(سنجاق)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Mods Only !
		if msg.reply_to_message_id_ then 
			pinMessage(msg.chat_id_, msg.reply_to_message_id_)
			Text = "`>` این پیام با شناسه `"..msg.reply_to_message_id_..'` در گفتگو سنجاق(*Pin*) شد.'
			sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'md')
		else
			Text = "`>` این عملیات نیازمند ریپلای(*Reply*) میباشد."
			..'\n_روی یک پیام ریپلای کرده و سپس دستور سنجاق را تایپ کنید._'
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		end 
	end
	--> CMD = /unpin | UnPin a message in a chat ...
	if CmdLower:match("^[/!#](unpin)$") or Cmd:match("^(آنپین)$") or Cmd:match("^(انپین)$") or Cmd:match("^(حذف سنجاق)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end
		unpinMessage(msg.chat_id_)
		Text = "`>` پیام سنجاق شده *UnPin* شد."
		sendText(msg.chat_id_, Text, msg.id_, 'md')
	end
	------------------------------------------->
	
	--> CMD = /config | Promote Chat Administrators to Bot Moderator and Set the Creator to Owner ...
	if CmdLower:match("^[/!#](config)$") or Cmd:match("^(پیکربندی)$") then
		if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owners Only !
		tdcli.getChannelMembers(msg.chat_id_, 0, 'Administrators' , 200,
			function (Ex, Res)
				Data = loadJson(Config.ModFile)
				local msg = Ex.msg
				for i=0, #Res.members_ do
					if Res.members_[i].status_.ID == "ChatMemberStatusEditor" and not isBot(Res.members_[i].user_id_) then
						Data[tostring(msg.chat_id_)]["moderators"][tostring(Res.members_[i].user_id_)] = "None"
						saveJson(Config.ModFile, Data)
					end
					if Res.members_[i].status_.ID == "ChatMemberStatusCreator" and not isBot(Res.members_[i].user_id_) then
						Data[tostring(msg.chat_id_)]["set_owner"] = tostring(Res.members_[i].user_id_)
						saveJson(Config.ModFile, Data)
					end
				end
				Text = "`>` تمامی مدیران گروه به عنوان مدیر فرعی ربات در گروه تنظیم شدند، همچنین سازنده گروه به عنوان مدیر اصلی ربات در گروه تنظیم شد."
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		, {msg = msg})
	end
	------------------------------------------->
	
	--> CMD = /promote [By Username and ID] | Promote a user to Bot Moderator in Group ...
	if CmdLower:match("^[/!#](promote) (.*)$") or Cmd:match("^(ترفیع) (.*)$") then
		if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owners Only !
		if not msg.reply_to_message_id_ then
			MatchesEN = {CmdLower:match("^[/!#](promote) (.*)$")}; MatchesFA = {Cmd:match("^(ترفیع) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn:match("^%d+$") then
				UserId = tonumber(Ptrn)
				if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را ترفیع دهید.", msg.id_, 'md') return end
				if isOwner(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` کاربر با شناسه `"..UserId.."` نیازی به ترفیع ندارد.\n_او در حال حاضر مقام بالاتری از مدیر فرعی ربات در گروه دارد._", msg.id_, 'md') return end
				Data = loadJson(Config.ModFile)
				if isMod(msg.chat_id_, UserId) then
					Data[tostring(msg.chat_id_)]["moderators"][tostring(UserId)] = nil
					saveJson(Config.ModFile, Data)
					Text = "⏬ کاربر با شناسه `"..UserId.."` از مدیریت گروه برکنار شد."
					.."\n_او دیگر مدیر فرعی ربات در گروه نمیباشد._"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				else
					Data[tostring(msg.chat_id_)]["moderators"][tostring(UserId)] = "None"
					saveJson(Config.ModFile, Data)
					Text = "⏫ کاربر با شناسه `"..UserId.."` ترفیع یافت."
					.."\n_او هم‌اکنون مدیر جزو مدیران فرعی ربات در گروه قرار گرفت._"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				end
			elseif Ptrn:match("^@[%a%d]") then
				Username = Ptrn:gsub("@","")
				resolveUsername(Username,
					function(Ex, Res)
						local msg = Ex.msg
						if Res.ID:lower() == "error" then --> if Error then Return
							sendText(msg.chat_id_, "`>` این نام کاربری اشتباه میباشد.", msg.id_, 'md')
							return
						end
						if not Res.type_.user_ then
							sendText(msg.chat_id_, "`>` این نام کاربری یک شخص نمیباشد.", msg.id_, 'md')
							return
						end
						UserFullName = Res.title_ or "----"
						UserId = Res.type_.user_.id_ or "----"
						UserUsername = Res.type_.user_.username_ or "None"
						if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را ترفیع دهید.", msg.id_, 'md') return end
						if isOwner(msg.chat_id_, UserId) then sendText(msg.chat_id_, "<code>></code> کاربر با نام کاربری @"..UserUsername.." و شناسه <code>"..UserId.."</code> نیازی به ترفیع ندارد.\n<i>او در حال حاضر مقام بالاتری از مدیر فرعی ربات در گروه دارد.</i>", msg.id_, 'html') return end
						if isMod(msg.chat_id_, UserId) then
							Data[tostring(msg.chat_id_)]["moderators"][tostring(UserId)] = nil
							saveJson(Config.ModFile, Data)
							Text = "⏬ کاربر با نام کاربری @"..UserUsername.." از مدیریت گروه برکنار شد."
							.."\n<i>او دیگر مدیر فرعی ربات در گروه نمیباشد.</i>"
							sendText(msg.chat_id_, Text, msg.id_, 'html')
						else
							Data[tostring(msg.chat_id_)]["moderators"][tostring(UserId)] = UserUsername
							saveJson(Config.ModFile, Data)
							Text = "⏫ کاربر با نام کاربری @"..UserUsername.." ترفیع یافت."
							.."\n<i>او هم‌اکنون جزو مدیران فرعی ربات در گروه قرار گرفت.</i>"
							sendText(msg.chat_id_, Text, msg.id_, 'html')
						end
					end
				, {msg = msg})
			end
		end
	end
	--> CMD = /promote [By Reply] | Promote a member to a Moderator in Chat ...
	if CmdLower:match("^[/!#](promote)$") or Cmd:match("^(ترفیع)$") then
		if msg.reply_to_message_id_ then
			if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owners Only !
			getMessage(msg.chat_id_, msg.reply_to_message_id_,
				function (Ex, Res)
					local msg = Ex.msg
					UserId = Res.sender_user_id_
					if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را ترفیع دهید.", msg.id_, 'md') return end
					if isOwner(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` این کاربر با شناسه `"..UserId.."` نیازی به ترفیع ندارد.\n_او در حال حاضر مقام بالاتری از مدیر فرعی ربات در گروه دارد._", msg.reply_to_message_id_, 'md') return end
					if isMod(msg.chat_id_, UserId) then
						Data[tostring(msg.chat_id_)]["moderators"][tostring(UserId)] = nil
						saveJson(Config.ModFile, Data)
						Text = "⏬ این کاربر با شناسه `"..UserId.."` از مدیریت گروه برکنار شد."
						.."\n_او دیگر مدیر فرعی ربات در گروه نمیباشد._"
						sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'md')
					else
						Data[tostring(msg.chat_id_)]["moderators"][tostring(UserId)] = "None"
						saveJson(Config.ModFile, Data)
						Text = "⏫ این کاربر با شناسه `"..UserId.."` ترفیع یافت."
						.."\n_او هم‌اکنون مدیر جزو مدیران فرعی ربات در گروه قرار گرفت._"
						sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'md')
					end
				end
			, {msg = msg})
		end
	end
	
	--> CMD = /modlist | Showing Moderators list ...
	if CmdLower:match("^[/!#](modlist)$") or Cmd:match("^(لیست مدیران فرعی)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Mods Only !
		Data = loadJson(Config.ModFile)
		if next(Data[tostring(msg.chat_id_)]["moderators"]) == nil then sendText(msg.chat_id_, "`>` لیست مدیران فرعی این گروه خالی میباشد.\n_این گروه مدیر فرعی ندارد._", msg.id_, 'md') return end
		Text = '🏷 شناسه گروه : <code>'..msg.chat_id_..'</code>'
		..'\n» لیست مدیران فرعی ربات در گروه :'
		..'\n———————\n'
		i = 0
		for k,v in pairs(Data[tostring(msg.chat_id_)]["moderators"]) do
			i = i + 1
			Text = Text..i..'- <code>'..k..'</code> => (@'..v..')\n'
		end
		Text = Text.."———————"
		.."\n<code>></code> جهت دریافت اطلاعات درباره هر کدام از این کاربران از این دستور استفاده کنید :"
		.."\n/who [شناسه-کاربر]"
		sendText(msg.chat_id_, Text, msg.id_, 'html')
	end
	------------------------------------------->
	
	--> CMD = /setowner [By Username and ID] | Set owner of a Group ...
	if CmdLower:match("^[/!#](setowner) (.*)$") or Cmd:match("^(تنظیم مدیر اصلی) (.*)$") then
		if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owners Only !
		if not msg.reply_to_message_id_ then
			MatchesEN = {CmdLower:match("^[/!#](setowner) (.*)$")}; MatchesFA = {Cmd:match("^(تنظیم مدیر اصلی) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn:match("^%d+$") then
				UserId = tonumber(Ptrn)
				if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را مدیر اصلی کنید.", msg.id_, 'md') return end
				if isSudo(UserId) then sendText(msg.chat_id_, "`>` کاربر با شناسه `"..UserId.."` مدیر کل ربات میباشد. نیازی به تنظیم او به عنوان مدیر اصلی گروه نیست.", msg.id_, 'md') return end
				if isOwner(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` کاربر با شناسه `"..UserId.."` در حال حاضر مدیر اصلی در گروه میباشد.", msg.id_, 'md') return end
				Data = loadJson(Config.ModFile)
				Data[tostring(msg.chat_id_)]["set_owner"] = tostring(UserId)
				saveJson(Config.ModFile, Data)
				Text = "👤 کاربر با شناسه `"..UserId.."` به عنوان مدیر اصلی ربات(*Owner*) در گروه تنظیم شد."
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			elseif Ptrn:match("^@[%a%d]") then
				Username = Ptrn:gsub("@","")
				resolveUsername(Username,
					function(Ex, Res)
						local msg = Ex.msg
						if Res.ID:lower() == "error" then --> if Error then Return
							sendText(msg.chat_id_, "`>` این نام کاربری اشتباه میباشد.", msg.id_, 'md')
							return
						end
						if not Res.type_.user_ then
							sendText(msg.chat_id_, "`>` این نام کاربری یک شخص نمیباشد.", msg.id_, 'md')
							return
						end
						UserFullName = Res.title_ or "----"
						UserId = Res.type_.user_.id_ or "----"
						UserUsername = Res.type_.user_.username_ or "None"
						if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را به عنوان مدیر اصلی گروه تنظیم کنید.", msg.id_, 'md') return end
						if isSudo(UserId) then sendText(msg.chat_id_, "<code>></code> کاربر با نام کاربری @"..UserUsername.." مدیر کل ربات میباشد. نیازی به تنظیم او به عنوان مدیر اصلی گروه نیست.", msg.id_, 'html') return end
						if isOwner(msg.chat_id_, UserId) then sendText(msg.chat_id_, "<code>></code> کاربر با نام کاربری @"..UserId.." در حال حاضر مدیر اصلی ربات در گروه میباشد.", msg.id_, 'html') return end
						Data = loadJson(Config.ModFile)
						Data[tostring(msg.chat_id_)]["set_owner"] = tostring(UserId)
						saveJson(Config.ModFile, Data)
						Text = "👤 کاربر با نام کاربری @"..UserUsername.." به عنوان مدیر اصلی ربات(<b>Owner</b>) در گروه تنظیم شد."
						sendText(msg.chat_id_, Text, msg.id_, 'html')
					end
				, {msg = msg})
			end
		end
	end
	--> CMD = /setowner [By Reply] | Set owner of a Group ...
	if CmdLower:match("^[/!#](setowner)$") or Cmd:match("^(تنظیم مدیر اصلی)$") then
		if msg.reply_to_message_id_ then
			if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owners Only !
			getMessage(msg.chat_id_, msg.reply_to_message_id_,
				function (Ex, Res)
					local msg = Ex.msg
					UserId = Res.sender_user_id_
					if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را به عنوان مدیر اصلی گروه تنظیم کنید.", msg.id_, 'md') return end
					if isSudo(UserId) then sendText(msg.chat_id_, "`>` این کاربر مدیر کل ربات است و نیازی به تنظیم او به عنوان مدیر اصلی گروه نیست.", msg.reply_to_message_id_, 'md') return end
					if isOwner(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` این کاربر با شناسه `"..UserId.."` در حال حاضر مدیر اصلی ربات در گروه میباشد.", msg.reply_to_message_id_, 'md') return end
					Data = loadJson(Config.ModFile)
					Data[tostring(msg.chat_id_)]["set_owner"] = tostring(UserId)
					saveJson(Config.ModFile, Data)
					Text = "👤 این کاربر با شناسه `"..UserId.."` به عنوان مدیر اصلی ربات(*Owner*) در گروه تنظیم شد."
					sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'md')
				end
			, {msg = msg})
		end
	end
	
	--> CMD = /owner | Showing owner of The Group ...
	if CmdLower:match("^[/!#](owner)$") or Cmd:match("^(مدیر اصلی)$") then
		Data = loadJson(Config.ModFile)
		if Data[tostring(msg.chat_id_)]['set_owner'] then
			if Data[tostring(msg.chat_id_)]['set_owner'] ~= "0" then
				OwnerId = tonumber(Data[tostring(msg.chat_id_)]['set_owner'])
				getUser(OwnerId,
					function (Ex, Res)
						local msg = Ex.msg
						local OwnerId = tonumber(Ex.OwnerId)
						if Res.ID == "Error" then
							Text = '> شناسه مدیر اصلی ربات در گروه : '..OwnerId
							.."\n<user>> جهت نمایش پروفایل مدیر اصلی ربات در گروه این متن را لمس کنید.</user>"
							sendText(msg.chat_id_, Text, msg.id_, false, OwnerId)
							return
						end
						OwnerFullName = (Res.user_.first_name_ or "").." "..(Res.user_.last_name_ or "")
						Text = "> نام کامل مدیر اصلی ربات در گروه : "..OwnerFullName
						.."\n> شناسه مدیر اصلی ربات در گروه : "..OwnerId
						..'\n<user>▪️ جهت نمایش پروفایل مدیر اصلی ربات در گروه روی این متن کلیک کنید.</user>'
						sendText(msg.chat_id_, Text, msg.id_, false, OwnerId)
					end
				,{msg = msg, OwnerId = OwnerId})
			else
				Text = "`>` مدیر اصلی ربات در این گروه تنظیم نشده است."
				..'\nجهت تنظیم کردن آن باید با مدیر کل ربات در تماس باشید.'
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
	end
	------------------------------------------->
	
	--> CMD = /setlink , /link | Set and Get Group Link ...
	if CmdLower:match("^[/!#](setlink)$") or Cmd:match("^(تنظیم لینک)$") then
		if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owners Only !
		Data = loadJson(Config.ModFile)
		Data[tostring(msg.chat_id_)]['settings']['set_link'] = "wait"
		saveJson(Config.ModFile, Data)
		Text = "👈 حال برای تنظیم لینک ، لینک گروه را به تنهایی در همینجا ارسال نمایید ..."
		sendText(msg.chat_id_, Text, msg.id_)
	end
	if msg.content_.text_ then
		Data = loadJson(Config.ModFile)
		if Data[tostring(msg.chat_id_)]['settings']['set_link'] then
			if Data[tostring(msg.chat_id_)]['settings']['set_link'] == 'wait' then
				if msg.content_.text_:match("^([https?://w]*.?telegram.me/joinchat/%S+)$") or msg.content_.text_:match("^([https?://w]*.?t.me/joinchat/%S+)$") then
					if isOwner(msg.chat_id_, msg.sender_user_id_) then
						Data[tostring(msg.chat_id_)]['settings']['set_link'] = msg.content_.text_
						saveJson(Config.ModFile, Data)
						Text = "✅ لینک جدید تنظیم شد !"
						.."\nبرای دریافت لینک میتوانید از این دستور استفاده نمایید :"
						.."\n*/link*"
						sendText(msg.chat_id_, Text, msg.id_, 'md')
					end
				end
			end
		end
	end
	if CmdLower:match("^[/!#](link)$") or Cmd:match("^(لینک)$") then --> Get Setted Link
		Data = loadJson(Config.ModFile)
		if Data[tostring(msg.chat_id_)]['settings']['set_link'] then
			if Data[tostring(msg.chat_id_)]['settings']['set_link'] ~= "wait" then
				SettedLink = Data[tostring(msg.chat_id_)]['settings']['set_link']
				Text = "🌟 لینک تنظیم شده برای این گروه :"
				.."\n⏺ "..SettedLink
				sendText(msg.chat_id_, Text, msg.id_)
			else
				Text = "`>` لینک گروه هنوز تنظیم نشده است."
				.."\nدستور تنظیم لینک گروه :"
				.."\n/setlink"
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		else
			Text = "`>` لینک گروه هنوز تنظیم نشده است."
			.."\nدستور تنظیم لینک گروه :"
			.."\n/setlink"
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		end
	end
	------------------------------------------->
	
	--> CMD = /setrules | Set Group Rules ...
	if Cmd:match("^[/!#]([Ss][Ee][Tt][Rr][Uu][Ll][Ee][Ss]) (.*)$") or Cmd:match("^(تنظیم قوانین) (.*)$") then
		if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owners Only !
		MatchesEN = {Cmd:match("^[/!#]([Ss][Ee][Tt][Rr][Uu][Ll][Ee][Ss]) (.*)$")}; MatchesFA = {Cmd:match("^(تنظیم قوانین) (.*)$")}
		RulesText = MatchesEN[2] or MatchesFA[2]
		RulesHash = "enigma:cli:set_rules:"..msg.chat_id_
		--[[if (utf8.len(RulesText) > 500) or (utf8.len(RulesText) < 10) then
			if utf8.len(RulesText) > 500 then
				stats = "_تعداد حروف متن خود را جهت تنظیم قوانین کاهش دهید._"
			else
				stats = "_تعداد حروف متن خود را جهت تنظیم قوانین افزایش دهید._"
			end
			Text = "محدوده تعداد کاراکتر ها برای تنظیم قوانین گروه از `10` تا `500` کاراکتر میباشد!\nتعداد کاراکتر های متن شما : `"..#rules.."`\n"..stats
			sendText(msg.chat_id_, Text, msg.id__, 'md')
			return
		end]]
		redis:set(RulesHash, RulesText)
		Text = "متن قوانین با موفقیت تنظیم گردید !"
		.."\nبرای دریافت قوانین از دستور زیر استفاده کنید :"
		.."\n/rules"
		sendText(msg.chat_id_, Text, msg.id_)
	end
	if CmdLower:match("^[/!#](rules)$") or Cmd:match("^(قوانین)$") then --> Getting Setted Rules ...
		RulesHash = "enigma:cli:set_rules:"..msg.chat_id_
		if redis:get(RulesHash) then
			GettedRules = redis:get(RulesHash)
			sendText(msg.chat_id_, GettedRules, msg.id_)
		else
			Text = "> قوانین این گروه تنظیم نشده است !"
			..'\nجهت تنظیم کردن قوانین از دستور زیر استفاده کنید :'
			..'\n/setrule [متن-قوانین]'
			sendText(msg.chat_id_, Text, msg.id_)
		end
	end
	------------------------------------------->
	
	--> CMD = /botinfo | Getting bot info ...
	if CmdLower:match("^[/!#](botinfo)$") or Cmd:match("^(اطلاعات ربات)$") then
		getMe(
			function (Ex, Res)
				local msg = Ex.msg
				UserFullName = (Res.first_name_ or "").." "..(Res.last_name_ or "")
				UserUsername = "----"
				if Res.username_ then UserUsername = "@"..Res.username_ end
				UserId = Res.id_ or "---"
				Text = "> نام کامل ربات : "..UserFullName
				.."\n> نام کاربری ربات : "..UserUsername
				.."\n> شناسه کاربری ربات : "..UserId
				sendText(msg.chat_id_, Text, msg.id_)
			end
	, {msg = msg})
	end
	
	--> CMD = /ping | Checking Robot Off or On ...
	if CmdLower:match("^[/!#](ping)$") or Cmd:match("^(پینگ)$") then
		Text = "✅ ربات فعال میباشد."
		sendText(msg.chat_id_, Text, msg.id_)
	end
	------------------------------------------->
	
	--> CMD = /Filter | Filtering Words ...
	if CmdLower:match("^[/!#](filter) (.*)$") or CmdLower:match("^(فیلتر) (.*)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Mods Only !
		MatchesEN = {CmdLower:match("^[/!#](filter) (.*)$")}; MatchesFA = {Cmd:match("^(فیلتر) (.*)$")}
		TextForFilter = MatchesEN[2] or MatchesFA[2]
		FilterHash = "enigma:cli:filtered_words:"..msg.chat_id_
		IsFiltered = redis:sismember(FilterHash, TextForFilter)
		if IsFiltered == false then
			redis:sadd(FilterHash, TextForFilter)
			Text = "✅ عبارت '"..TextForFilter.."' به لیست عبارات فیلتر شده در گروه اضافه گردید."
			.."\n> اگر کاربری عادی از این عبارت در پیام خود استفاده کند ، پیامش حذف خواهد شد."
			sendText(msg.chat_id_, Text, msg.id_)
		else
			Text = "عبارت '"..TextForFilter.."' از قبل فیلتر شده است."
			.."\nنیازی به فیلتر مجدد آن نیست."
			.."\n〰 جهت حذف آن از لیست فیلتر از دستور زیر استفاده کنید :"
			.."\n/rf "..TextForFilter
			sendText(msg.chat_id_, Text, msg.id_)
		end
	end
	
	--> CMD = /rf | Remove filtered word from list ...
	if CmdLower:match("^[/!#](rf) (.*)$") or CmdLower:match("^(رفع فیلتر) (.*)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Mods Only !
		MatchesEN = {CmdLower:match("^[/!#](rf) (.*)$")}; MatchesFA = {CmdLower:match("^(رفع فیلتر) (.*)$")}
		TextForUnFilter = MatchesEN[2] or MatchesFA[2]
		FilterHash = "enigma:cli:filtered_words:"..msg.chat_id_
		IsFiltered = redis:sismember(FilterHash, TextForUnFilter)
		if IsFiltered == true then
			redis:srem(FilterHash, TextForUnFilter)
			Text = "عبارت '"..TextForUnFilter.."' از لیست فیلتر عبارات فیلتر شده حذف گردید."
			.."\nهم اکنون استفاده از آن در گروه مجاز است."
			sendText(msg.chat_id_, Text, msg.id_)
		else
			Text = "🚫 عبارت '"..TextForUnFilter.."' تا به حال فیلتر نشده است که بخواهد حذف گردد!"
			sendText(msg.chat_id_, Text, msg.id_)
		end
	end
	
	--> CMD = /filterlist | Getting Filter List ...
	if CmdLower:match("^[/!#](filterlist)$") or CmdLower:match("^(لیست فیلتر)") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Mods Only !
		FilterHash = "enigma:cli:filtered_words:"..msg.chat_id_
		if redis:scard(FilterHash) < 1 then
			Text = "`>` لیست کلمات فیلتر شده خالی میباشد !"
			sendText(msg.chat_id_, Text, msg.id_, 'md')
			return
		end
		FilteredWords = redis:smembers(FilterHash)
		Text = "📝 شناسه گروه : "..msg.chat_id_
		.."\n📛 لیست کلمات فیلتر شده :"
		.."\n—————————"
		.."\n"
		for i=1, #FilteredWords do
			Text = Text..i..'- '..FilteredWords[i]..'\n'
		end
		sendText(msg.chat_id_, Text, msg.id_)
	end
	------------------------------------------->
	
	--> CMD => /del | Delete a Message By Reply ...
	if CmdLower:match("^[/!#](del)$") or Cmd:match("^(حذف پیام)$") then
		if msg.reply_to_message_id_ and isMod(msg.chat_id_, msg.sender_user_id_) then
			deleteMessage(msg.chat_id_, msg.reply_to_message_id_)
			deleteMessage(msg.chat_id_, msg.id_)
		end
	end
	
	--> CMD => /delall | Delete All Message From a User By Reply ...
	if CmdLower:match("^[/!#](delall)$") or Cmd:match("^(حذف همه)$") then
		if isMod(msg.chat_id_, msg.sender_user_id_) then
			if msg.reply_to_message_id_ then
				getMessage(msg.chat_id_, msg.reply_to_message_id_,
					function (Ex, Res)
						local msg = Ex.msg
						UserId = Res.sender_user_id_
						deleteMessagesFromUser(msg.chat_id_, UserId)
						deleteMessage(msg.chat_id_, msg.id_)
					end
				, {msg = msg})
			else
				Text = "`>` جهت حذف کردن تمامی پیام های یک کاربر در گروه باید روی یکی از پیام های او ریپلای(*Reply*) کنید و سپس عبارت 'حذف همه' را تایپ کنید."
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
	end
	------------------------------------------->
	
	--> CMD => /rename | Changing Chat Title ...
	if Cmd:match("^[/!#]([Rr][Ee][Nn][Aa][Mm][Ee]) (.*)$") or Cmd:match("^(تغییر نام) (.*)$") then
		if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owner Only !
		MatchesEN = {Cmd:match("^[/!#]([Rr][Ee][Nn][Aa][Mm][Ee]) (.*)$")}; MatchesFA = {Cmd:match("^(تغییر نام) (.*)$")}
		ChatNewTitle = MatchesEN[2] or MatchesFA[2]
		tdcli_function ({
			ID = "ChangeChatTitle",
			chat_id_ = msg.chat_id_,
			title_ = ChatNewTitle,
		}, 
			function (Ex, Res)
				local msg = Ex.msg
				local ChatNewTitle = Ex.ChatNewTitle
				if Res.ID == "Error" then
					Text = "🚫خطایی در تغییر نام گروه رخ داد."
					if Res.code_ == 3 then
						Text = Text.."\n> دلیل خطا : ربات ادمین(مدیر) گروه نیست."
					end
				elseif Res.ID == "Ok" then
					Text = "✅ نام گروه با موفقیت به"
					.."\n"..ChatNewTitle
					.."\nتغییر یافت."
				end
				sendText(msg.chat_id_, Text, msg.id_)
			end
		, {msg = msg, ChatNewTitle = ChatNewTitle})
	end
	------------------------------------------->
	
	--> CMD => /invite | Invite a user to a group ...
	if CmdLower:match("^[/!#](invite)$") or Cmd:match("^(دعوت)$") then
		if msg.reply_to_message_id_ then
			if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Owners Only !
			local function Result(Ex, Res)
				local msg = Ex.msg
				ID = Res.content_.ID
				if ID == "MessageChatDeleteMember" then
					UserId = Res.content_.user_.id_
				elseif ID == "MessageChatAddMembers" then
					UserId = Res.content_.members_[0].id_
				elseif ID == "MessageChatJoinByLink" then
					UserId = Res.sender_user_id_
				else
					UserId = Res.sender_user_id_
				end
				addUser(msg.chat_id_, UserId)
			end
			getMessage(msg.chat_id_, msg.reply_to_message_id_, Result, {msg = msg})
		end
	end
	if CmdLower:match("^[/!#](invite) (.*)$") or Cmd:match("^(دعوت) (.*)$") then
		MatchesEN = {CmdLower:match("^[/!#](invite) (.*)$")}; MatchesFA = {Cmd:match("^(دعوت) (.*)$")}
		Ptrn = MatchesEN[2] or MatchesFA[2]
		if Ptrn:match("^@[%a%d]") then
			local function invByUsername(Ex, Res)
				local msg = Ex.msg
				if Res.ID:lower() == "error" then --> if Error then Return
					sendText(msg.chat_id_, "`>` این نام کاربری اشتباه میباشد.", msg.id_, 'md')
					return
				end
				if not Res.type_.user_ then
					sendText(msg.chat_id_, "`>` این نام کاربری یک شخص نمیباشد.", msg.id_, 'md')
					return
				end
				UserId = Res.type_.user_.id_
				addUser(msg.chat_id_, UserId)
			end
			Username = Ptrn:gsub("@","")
			resolveUsername(Username, invByUsername, {msg = msg})
		end
	end
	------------------------------------------->
	
	--> CMD => /gpinfo | Get Chat Info ....
	if CmdLower:match("^[/!#](gpinfo)$") or Cmd:match("^(اطلاعات گروه)$") then
		tdcli_function ({
			ID = "GetChannelFull",
			channel_id_ = getChatId(msg.chat_id_).ID
		},
			function (Ex, Res)
				local msg = Ex.msg
				AdminCount = (Res.administrator_count_ or '----')
				BlockedUsersCount = (Res.kicked_count_ or '----')
				MemberCount = (Res.member_count_ or '----')
				Text = "🏷 شناسه گروه : "..msg.chat_id_
				.."\n👥 تعداد مدیران گروه : "..AdminCount
				.."\n🚫 تعداد کاربران بلاک شده : "..BlockedUsersCount
				.."\n⏺ تعداد کاربران : "..MemberCount
				sendText(msg.chat_id_, Text, msg.id_)
			end
		, {msg = msg})
	end
	------------------------------------------->
	
	-- CMD => /setwlc AND /delwlc | Set and Del Welcome Message ...
	if Cmd:match("^[/!#]([Ss][Ee][Tt][Ww][Ll][Cc]) (.*)$") or Cmd:match("^(تنظیم خوشامد) (.*)$") then
		if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owners Only !
		MatchesEN = {Cmd:match("^[/!#]([Ss][Ee][Tt][Ww][Ll][Cc]) (.*)$")}; MatchesFA = {Cmd:match("^(تنظیم خوشامد) (.*)$")}
		WelcomeText = MatchesEN[2] or MatchesFA[2]
		Hash = WelcomeMessageHash..msg.chat_id_
		redis:set(Hash, WelcomeText)
		Text = "`>` متن خوشامد گویی به روزرسانی شد !"
		sendText(msg.chat_id_, Text, msg.id_, 'md')
	end
	----------------------------------------
	
	--> CMD => /clean | clean something ...
	if CmdLower:match("^[/!#](clean) (.*)$") or CmdLower:match("^(پاکسازی) (.*)$") then
		if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owner Only !
		MatchesEN = {CmdLower:match("^[/!#](clean) (.*)$")}; MatchesFA = {Cmd:match("^(پاکسازی) (.*)$")}
		ChizToClean = MatchesEN[2] or MatchesFA[2] -- :)
		
		-- Clean Bots
		if ChizToClean == "bot" or ChizToClean == "bots" or ChizToClean == "robot" or ChizToClean == "robots" or
		ChizToClean == "ربات" or ChizToClean == "بات" or ChizToClean == "ربات ها" or ChizToClean == "بات ها" then
			getChannelMembers(msg.chat_id_, 0, "Bots", 200,
				function (Ex, Res)
					local msg = Ex.msg
					k = 0
					for i=0, #Res.members_ do
						if not isMod(msg.chat_id_, Res.members_[i].user_id_) then
							kickUser(msg.chat_id_, Res.members_[i].user_id_)
							k = k+1
						end
					end
					Text = "*"..k.."* ربات معمولی (*API*) از گروه اخراج شد. ✅"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				end
			, {msg = msg})
		end
		-------------
		
		-- Clean Rules
		if ChizToClean == "rule" or ChizToClean == "rules" or ChizToClean == "قانون" or ChizToClean == "قوانین" then
			RulesHash = "enigma:cli:set_rules:"..msg.chat_id_
			if redis:get(RulesHash) then
				redis:del(RulesHash)
				Text = "❌ قوانین گروه پاکسازی شد."
				sendText(msg.chat_id_, Text, msg.id_)
			else
				Text = "> قوانین تنظیم نشده نشده است که بخواهد حذف گردد !"
				sendText(msg.chat_id_, Text, msg.id_)
			end
		end
		-------------
		
		-- Clean Welcome Message
		if ChizToClean == "welcome" or ChizToClean == "wlc" or ChizToClean == "خوشامد" or ChizToClean == "خوش آمد" or ChizToClean == "خوش امد" then
			Hash = WelcomeMessageHash..msg.chat_id_
			if redis:get(Hash) then
				redis:del(Hash)
				Text = "`>` متن خوشامد گویی تنظیم شده حذف شد !"
				.."\n_متن خوشامد گویی به متن پیشفرض تنظیم شد._"
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			else
				Text = "`>` متن خوشامد گویی جهت حذف وجود ندارد."
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
		-------------
		
		-- Clean BanList
		if ChizToClean == "banlist" or ChizToClean == "لیست مسدود" then
			Hash = BanHash..msg.chat_id_
			if redis:scard(Hash) == 0 then
				Text = [[⛔️ لیست کاربران مسدود این گروه خالی میباشد !
_نیازی به پاکسازی آن نیست._]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			else
				redis:del(Hash)
				Text = [[✅ لیست کاربران مسدود گروه پاکسازی شد.
_کاربران مسدود مجددا اجازه ورود به گروه را پیدا کردند._]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
		----------------

		-- Clean GlobalBanList
		if ChizToClean == "gbanlist" or ChizToClean == "لیست مسدود همگانی" then
			if redis:scard(GBanHash) == 0 then
				Text = [[⛔️ لیست کاربران مسدود همگانی ربات خالی میباشد !
_نیازی به پاکسازی آن نیست._]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			else
				redis:del(GBanHash)
				Text = [[✅ لیست کاربران مسدود همگانی ربات پاکسازی شد.
_کاربران مسدود مجددا اجازه ورود به گروه های تحت مدیریت را پیدا کردند._]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
		----------------
		
		-- Clean SilentList
		if ChizToClean == "silentlist" or ChizToClean == "لیست سایلنت" then
			Hash = SilentHash..msg.chat_id_
			if redis:scard(Hash) == 0 then
				Text = [[🔇 لیست کاربران سایلنت این گروه خالی میباشد !
_نیازی به پاکسازی آن نیست._]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			else
				redis:del(Hash)
				Text = [[✅ لیست کاربران سایلنت گروه پاکسازی شد.
_کاربران سایلنت مجددا اجازه چت در گروه را دریافت کردند._]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
		----------------
		
		-- Clean FilterList
		if ChizToClean == "filters" or ChizToClean == "filterlist" or ChizToClean == "لیست فیلتر" then
			FilterHash = "enigma:cli:filtered_words:"..msg.chat_id_
			if redis:scard(FilterHash) == 0 then
				Text = [[⛔️ هیچ عبارت فیلتر شده ای در این گروه وجود ندارد!
_نیازی به پاکسازی آن نیست._]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			else
				redis:del(FilterHash)
				Text = [[✅ تمامی عبارات فیلتر شده در گروه مجاز شدند!
_لیست عبارات فیلتر شده پاکسازی شد._]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			end
		end
		-------------
		
		-- Clean Deleted Accounts
		if ChizToClean == "deleted" or ChizToClean == "حذف شده ها" or ChizToClean == "حذف شده" then
			tdcli_function({ID = "GetChannelMembers",
				channel_id_ = getChatId(msg.chat_id_).ID,
				offset_ = 0
				,limit_ = 1000
				}, 
					function (Ex, Res)
						local msg = Ex.msg
						for i=1, #Res.members_ do
							getUser(Res.members_[i].user_id_,
								function (Ex, Res)
									local msg = Ex.msg
									if not Res.user_.first_name_ then
										kickUser(msg.chat_id_, Res.user_.id_)
									end
								end
							,{msg = msg})
						end
						Text = '`>` اکانت های غیرفعال (*Deleted Account*) از گروه اخراج شدند. 👞'
						sendText(msg.chat_id_, Text, msg.id_, 'md')
					end
				, {msg = msg})
		end
		--------------------------
		
		-- Clean Group Link
		if ChizToClean == "modlist" or ChizToClean == "لیست مدیران" or ChizToClean == "لیست مدیران فرعی" then
			Data = loadJson(Config.ModFile)
			if next(Data[tostring(msg.chat_id_)]['moderators']) == nil then
				Text = [[🔹هیچ مدیر فرعی انتخاب نشده(لیست مدیران فرعی خالی است.) که لیست مدیران فرعی پاک گردد!
_نیازی به پاکسازی لیست مدیران فرعی نیست._]]
				sendText(msg.chat_id_, Text, msg.id_, 'md')
				return
			end
			Num = 0
			for k,v in pairs(Data[tostring(msg.chat_id_)]['moderators']) do
				Data[tostring(msg.chat_id_)]['moderators'][tostring(k)] = nil
				saveJson(Config.ModFile, Data)
				Num = Num+1
			end
			Text = "✅ لیست مدیران فرعی ربات در گروه با تعداد *"..Num.."*نفر پاکسازی شد."
			.."\n_هم اکنون هیچکس به عنوان مدیر فرعی ربات در گروه قرار ندارد._"
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		end
		-------------------
		
		-- Clean Group Link
		if ChizToClean == "لینک" or ChizToClean == "link" then
			Data = loadJson(Config.ModFile)
			if Data[tostring(msg.chat_id_)]["settings"]["set_link"] then
				if Data[tostring(msg.chat_id_)]["settings"]["set_link"] ~= "wait" and Data[tostring(msg.chat_id_)]["settings"]["set_link"] ~= nil then
					Data[tostring(msg.chat_id_)]["settings"]["set_link"] = nil
					saveJson(Config.ModFile, Data)
					Text = "❌ لینک گروه پاکسازی شد !"
					.."\n> دستور تنظیم مجدد لینک گروه :"
					.."\n/setlink"
				else
					Text = "لینک گروه تنظیم نشده است!\nتنظیم لینک گروه:\n/setlink"
				end
			else
				Text = "لینک گروه تنظیم نشده است!\nتنظیم لینک گروه:\n/setlink"
			end
			sendText(msg.chat_id_, Text, msg.id_)
		end
		-------------------
		
		-- Clean Group Link
		if ChizToClean == "owner" or ChizToClean == "مدیر اصلی" or ChizToClean == "اونر" then
			if not isSudo(msg.sender_user_id_) then notSudo(msg) return end -- Sudo Only !
			Data = loadJson(Config.ModFile)
			if Data[tostring(msg.chat_id_)]['set_owner'] then 
				if tonumber(Data[tostring(msg.chat_id_)]['set_owner']) ~= 0 then
					Data[tostring(msg.chat_id_)]['set_owner'] = "0"
					saveJson(Config.ModFile, Data)
					Text = "`>` مدیر اصلی ربات در گروه خلع مقام شد."
					.."\n_در حال حاضر کسی مدیر اصلی ربات در گروه نمیباشد._"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				else
					Text = "`>` مدیر اصلی این گروه تنظیم نشده است که خلع مقام شود."
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				end
			end
		end
		-------------------
		
		-- Celan Group BlockList
		if ChizToClean == "blocklist" or ChizToClean == "لیست بلاک" then
			getChannelMembers(msg.chat_id_, 0, "Kicked", 200, 
				function(Ex, Res)
					local msg = Ex.msg
					for k,v in pairs(Res.members_) do
						tdcli.addChatMember(msg.chat_id_, v.user_id_, 50, dl_cb, nil)
					end
					Text = "لیست بلاک گروه تا حد ممکن پاکسازی شد و اعضای محروم از گروه به گروه دعوت شدند. ✅"
					sendText(msg.chat_id_, Text, msg.id_)
				end
			, {msg=msg})
		end
		-------------------
	end -- end Clean [STH]
	
	--> CMD => /me | Get the rank of user ...
	if CmdLower:match("^[/!#](me)$") or CmdLower:match("^[/!#](myrank)$") or Cmd:match("^(مقام من)$") then
		if isSudo(msg.sender_user_id_) then
			UserRankFA = "مدیر کل ربات"
			UserRankEN = "*Sudo*"
			Stars = "🎖🎖🎖"
		elseif isOwner(msg.chat_id_, msg.sender_user_id_) then
			UserRankFA = "مدیر اصلی ربات در گروه"
			UserRankEN = "*Owner*"
			Stars = "🎖🎖"
		elseif isMod(msg.chat_id_, msg.sender_user_id_) then
			UserRankFA = "مدیر فرعی ربات در گروه"
			UserRankEN = "*Moderator*"
			Stars = "🎖"
		else
			UserRankFA = "کاربر عادی"
			UserRankEN = "*Member*"
			Stars = ""
		end
		Text = "`>` شناسه شما : `"..msg.sender_user_id_.."`"
		.."\n`>` مقام شما (فارسی) : "..UserRankFA
		.."\n`>` مقام شما (انگلیسی) : "..UserRankEN
		.."\n"..Stars
		sendText(msg.chat_id_, Text, msg.id_, 'md')
	end
	---------------------------------------
	
	--> CMD => /panel | Get inline panel ...
	if CmdLower:match("^[/!#](panel)$") or Cmd:match("^(پنل)$") then
		if not isOwner(msg.chat_id_, msg.sender_user_id_) then notOwner(msg) return end -- Owner Only !
		HelperBotId = tonumber(ApiBotId)
		tdcli_function ({
			ID = "SendBotStartMessage",
			bot_user_id_ = HelperBotId,
			chat_id_ = HelperBotId,
			parameter_ = "new"
		}, dl_cb, nil)
		
		tdcli_function({
			  ID = "GetInlineQueryResults",
			  bot_user_id_ = HelperBotId,
			  chat_id_ = msg.chat_id_,
			  user_location_ = {
				ID = "Location",
				latitude_ = 0,
				longitude_ = 0
			  },
			  query_ = tostring(msg.chat_id_),
			  offset_ = 0
			},
			function (Ex, Res)
				local msg = Ex.msg
				tdcli_function({
					ID = "SendInlineQueryResultMessage",
					chat_id_ = msg.chat_id_,
					reply_to_message_id_ = msg.id_,
					disable_notification_ = 0,
					from_background_ = 1,
					query_id_ = Res.inline_query_id_,
					result_id_ = Res.results_[0].id_
				  }, dl_cb, nil)
			end
		, {msg = msg})
	end
	----------------------------------------
	
end -- END CHAT_MOD.LUA

--[[

	Powered By :
		 _____       _  ____
		| ____|_ __ (_)/ ___|_ __ ___   __ _ TM
		|  _| | '_ \| | |  _| '_ ` _ \ / _` |
		| |___| | | | | |_| | | | | | | (_| |
		|_____|_| |_|_|\____|_| |_| |_|\__,_|
	
	****************************
	*  >> By : Reza Mehdipour  *
	*  > Channel : @EnigmaTM   *
	****************************
	
]]

function banPlugin(msg) -- BAN.LUA

	Cmd = msg.content_.text_
	CmdLower = msg.content_.text_:lower()
	Data = loadJson(Config.ModFile)
	if not Data[tostring(msg.chat_id_)] then
		return
	end
	
	-- LOCK CMD -----------
	if Data[tostring(msg.chat_id_)]["settings"] then
		if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] then
			if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] == "yes" and not isMod(msg.chat_id_, msg.sender_user_id_) then
				return
			end
		end
	end
	-----------------------
	
	--> CMD = /ban [By Username and ID] | Ban and Kick a User From Group ...
	if CmdLower:match("^[/!#](ban) (.*)$") or Cmd:match("^(مسدود) (.*)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Owners Only !
		if not msg.reply_to_message_id_ then
			MatchesEN = {CmdLower:match("^[/!#](ban) (.*)$")}; MatchesFA = {Cmd:match("^(مسدود) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn:match("^%d+$") then
				Hash = BanHash..msg.chat_id_
				UserId = tonumber(Ptrn)
				if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را مسدود نمایید.", msg.id_, 'md') return end
				if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` کاربر با شناسه `"..UserId.."` جزو مدیران میباشد.\n_نمتوانید او را مسدود کنید._", msg.id_, 'md') return end
				if isBannedUser(msg.chat_id_, UserId) then
					redis:srem(Hash, UserId)
					Text = "`>` کاربر با شناسه `"..UserId.."` از لیست کاربران مسدود گروه خارج شد. ✅"
					.."\n_او هم‌اکنون اجازه ورود به گروه را دارد._"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				else
					redis:sadd(Hash, UserId)
					kickUser(msg.chat_id_, UserId)
					Text = "`>` کاربر با شناسه `"..UserId.."` در گروه مسدود شد. 🚫"
					.."\n_در صورت وارد شدن، به سرعت اخراج خواهد شد._"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				end
			elseif Ptrn:match("^@[%a%d]") then
				Username = Ptrn:gsub("@","")
				resolveUsername(Username,
					function(Ex, Res)
						local msg = Ex.msg
						Hash = BanHash..msg.chat_id_
						if Res.ID:lower() == "error" then --> if Error then Return
							sendText(msg.chat_id_, "`>` این نام کاربری اشتباه میباشد.", msg.id_, 'md')
							return
						end
						if not Res.type_.user_ then
							sendText(msg.chat_id_, "`>` این نام کاربری یک شخص نمیباشد.", msg.id_, 'md')
							return
						end
						UserFullName = Res.title_ or "----"
						UserId = Res.type_.user_.id_ or "----"
						UserUsername = Res.type_.user_.username_ or "None"
						if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را از گروه مسدود کنید.", msg.id_, 'md') return end
						if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "<code>></code> کاربر با نام کاربری @"..UserUsername.." و شناسه <code>"..UserId.."</code> یک مدیر است. نمیتوانید او را مسدود کنید.", msg.id_, 'html') return end
						if isBannedUser(msg.chat_id_, UserId) then
							redis:srem(Hash, UserId)
							Text = "<code>></code> کاربر با نام کاربری @"..UserUsername.." از لیست کاربران مسدود گروه خارج شد. ✅"
							.."\n<i>او هم‌اکنون اجازه ورود به گروه را دارد.</i>"
							sendText(msg.chat_id_, Text, msg.id_, 'html')
						else
							redis:sadd(Hash, UserId)
							kickUser(msg.chat_id_, UserId)
							Text = "<code>></code> کاربر با نام کاربری @"..UserUsername.." در گروه مسدود شد. 🚫"
							.."\n<i>در صورت وارد شدن، به سرعت اخراج خواهد شد.</i>"
							sendText(msg.chat_id_, Text, msg.id_, 'html')
						end
					end
				, {msg = msg})
			end
		end
	end
	
	--> CMD = /ban [By Reply] | Ban a User From Group ...
	if CmdLower:match("^[/!#](ban)$") or Cmd:match("^(مسدود)$") then
		if msg.reply_to_message_id_ then
			if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Owners Only !
			getMessage(msg.chat_id_, msg.reply_to_message_id_,
				function (Ex, Res)
					local msg = Ex.msg
					Hash = BanHash..msg.chat_id_
					UserId = Res.sender_user_id_
					if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را از گروه مسدود کنید.", msg.id_, 'md') return end
					if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` این کاربر با شناسه `"..UserId.."` جزو مدیران ربات در گروه است.\n_نمیتوانید او را مسدود کنید._", msg.reply_to_message_id_, 'md') return end
					if isBannedUser(msg.chat_id_, UserId) then
						redis:srem(Hash, UserId)
						Text = "<code>></code> این کاربر با شناسه <code>"..UserId.."</code> از لیست کاربران مسدود گروه خارج شد. ✅"
						.."\n<i>او هم‌اکنون اجازه ورود به گروه را دارد.</i>"
						sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'html')
					else
						redis:sadd(Hash, UserId)
						kickUser(msg.chat_id_, UserId)
						Text = "<code>></code> این کاربر با شناسه <code>"..UserId.."</code> در گروه مسدود شد. 🚫"
						.."\n<i>در صورت وارد شدن، به سرعت اخراج خواهد شد.</i>"
						sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'html')
					end
				end
			, {msg = msg})
		end
	end
	
	if CmdLower:match("^[/!#](banlist)$") or Cmd:match("^(لیست مسدود)$") then
		Hash = BanHash..msg.chat_id_
		BanUsersArray = redis:smembers(Hash)
		if tonumber(redis:scard(Hash)) < 1 then
			local Text = "`>` لیست مسدودی های گروه خالی میباشد."
			.."\n_کسی در گروه مسدود نمیباشد._"
			sendText(msg.chat_id_, Text, msg.id_, 'md')
			return
		end
		Text = "🚫 لیست کاربران مسدود در گروه :"
		.."\n———————"
		.."\n"
		for i=1, #BanUsersArray do
			Text = Text..i.."- `"..BanUsersArray[i].."`\n"
		end
		Text = Text.."———————"
		.."\n`>` جهت دریافت اطلاعات درباره هر کدام از این کاربران از این دستور استفاده کنید :"
		.."\n/who [شناسه-کاربر]"
		.."\n» مثال :"
		.."\n`/who "..BanUsersArray[1].."`"
		sendText(msg.chat_id_, Text, msg.id_, 'md')
	end
	----------------------------------------
	
	--> CMD = /gban [By Username and ID] | Ban a User From All Moderated Groups Of Bot ...
	if CmdLower:match("^[/!#](gban) (.*)$") or Cmd:match("^(مسدود همگانی) (.*)$") then
		if not isSudo(msg.sender_user_id_) then notSudo(msg) return end -- Owners Only !
		if not msg.reply_to_message_id_ then
			MatchesEN = {CmdLower:match("^[/!#](gban) (.*)$")}; MatchesFA = {Cmd:match("^(مسدود همگانی) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn:match("^%d+$") then
				UserId = tonumber(Ptrn)
				if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را مسدود همگانی کنید.", msg.id_, 'md') return end
				if isSudo(UserId) then sendText(msg.chat_id_, "<code>></code> کاربر با شناسه <code>"..UserId.."</code> جزو مدیران کل ربات میباشد.\n_نمیتوانید او را مسدود همگانی کنید._", msg.id_, 'html') return end
				if isGBannedUser(UserId) then
					redis:srem(GBanHash, UserId)
					Text = "`>` کاربر با شناسه `"..UserId.."` از لیست کاربران مسدود همگانی خارج شد. ✅"
					.."\n_او هم‌اکنون اجازه ورود به گروه های تحت مدیریت ربات را دارد._"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				else
					redis:sadd(GBanHash, UserId)
					Text = "`>` کاربر با شناسه `"..UserId.."` از همه گروه های ربات مسدود شد. 🚫"
					.."\n_در صورت وارد شدن به هر کدام از گروه های مدیریت شده ربات، به سرعت اخراج خواهد شد._"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				end
			elseif Ptrn:match("^@[%a%d]") then
				Username = Ptrn:gsub("@","")
				resolveUsername(Username,
					function(Ex, Res)
						local msg = Ex.msg
						if Res.ID:lower() == "error" then --> if Error then Return
							sendText(msg.chat_id_, "`>` این نام کاربری اشتباه میباشد.", msg.id_, 'md')
							return
						end
						if not Res.type_.user_ then
							sendText(msg.chat_id_, "`>` این نام کاربری یک شخص نمیباشد.", msg.id_, 'md')
							return
						end
						UserFullName = Res.title_ or "----"
						UserId = Res.type_.user_.id_ or "----"
						UserUsername = Res.type_.user_.username_ or "None"
						if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را مسدود همگانی کنید.", msg.id_, 'md') return end
						if isSudo(UserId) then sendText(msg.chat_id_, "<code>></code> کاربر با نام کاربری @"..UserUsername.." و شناسه <code>"..UserId.."</code> جزو مدیران کل ربات میباشد.\n_نمیتوانید او را مسدود همگانی کنید._", msg.id_, 'html') return end
						if isGBannedUser(UserId) then
							redis:srem(GBanHash, UserId)
							Text = "<code>></code> کاربر با نام کاربری @"..UserUsername.." از لیست کاربران مسدود همگانی خارج شد. ✅"
							.."\n<i>او هم‌اکنون اجازه ورود به گروه های تحت مدیریت ربات را دارد.</i>"
							sendText(msg.chat_id_, Text, msg.id_, 'html')
						else
							redis:sadd(GBanHash, UserId)
							Text = "<code>></code> کاربر با نام کاربری @"..UserUsername.." از تمامی گروه های مدیریت شده ربات مسدود شد. 🚫"
							.."\n<i>در صورت وارد شدن به هر کدام از آنها، به سرعت اخراج خواهد شد.</i>"
							sendText(msg.chat_id_, Text, msg.id_, 'html')
						end
					end
				, {msg = msg})
			end
		end
	end
	
	--> CMD = /gban [By Reply] | Ban a User From All Moderated Groups ...
	if CmdLower:match("^[/!#](gban)$") or Cmd:match("^(مسدود همگانی)$") then
		if msg.reply_to_message_id_ then
			if not isSudo(msg.sender_user_id_) then notSudo(msg) return end -- Owners Only !
			getMessage(msg.chat_id_, msg.reply_to_message_id_,
				function (Ex, Res)
					local msg = Ex.msg
					UserId = Res.sender_user_id_
					if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را مسدود همگانی کنید", msg.id_, 'md') return end
					if isSudo(UserId) then sendText(msg.chat_id_, "`>` این کاربر با شناسه `"..UserId.."` جزو مدیران ربات کل ربات میباشد.\n_نمیتوانید او را مسدود کنید._", msg.reply_to_message_id_, 'md') return end
					if isGBannedUser(msg.chat_id_, UserId) then
						redis:srem(GBanHash, UserId)
						Text = "<code>></code> این کاربر با شناسه <code>"..UserId.."</code> از لیست کاربران مسدود همگانی خارج شد. ✅"
						.."\n<i>او هم‌اکنون اجازه ورود به گروه های مدیریت شده ربات را دارد.</i>"
						sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'html')
					else
						redis:sadd(GBanHash, UserId)
						Text = "<code>></code> این کاربر با شناسه <code>"..UserId.."</code> از تمامی گروه های مدیریت شده ربات مسدود شد. 🚫"
						.."\n<i>در صورت وارد شدن به هر کدام از گروه های مدیریت شده ربات، به سرعت اخراج خواهد شد.</i>"
						sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'html')
					end
				end
			, {msg = msg})
		end
	end
	
	--> CMD => /gbanlist | Getting GbanList ...
	if CmdLower:match("^[/!#](gbanlist)$") or Cmd:match("^(لیست مسدود همگانی)$") then
		GBanUsersArray = redis:smembers(GBanHash)
		if tonumber(redis:scard(GBanHash)) < 1 then
			local Text = "`>` لیست مسدودی های همگانی خالی میباشد."
			sendText(msg.chat_id_, Text, msg.id_, 'md')
			return
		end
		Text = "🚫 لیست کاربران مسدود از تمامی گروه های تحت مدیریت ربات :"
		.."\n———————"
		.."\n"
		for i=1, #GBanUsersArray do
			Text = Text..i.."- `"..GBanUsersArray[i].."`\n"
		end
		Text = Text.."———————"
		.."\n`>` جهت دریافت اطلاعات درباره هر کدام از این کاربران از این دستور استفاده کنید :"
		.."\n/who [شناسه-کاربر]"
		.."\n» مثال :"
		.."\n`/who "..GBanUsersArray[1].."`"
		sendText(msg.chat_id_, Text, msg.id_, 'md')
	end
	----------------------------------------
	
	--> CMD = /silent [By Username and ID] | Silent a user in a Chat ...
	if CmdLower:match("^[/!#](silent) (.*)$") or Cmd:match("^(سایلنت) (.*)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Owners Only !
		if not msg.reply_to_message_id_ then
			MatchesEN = {CmdLower:match("^[/!#](silent) (.*)$")}; MatchesFA = {Cmd:match("^(سایلنت) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn:match("^%d+$") then
				Hash = SilentHash..msg.chat_id_
				UserId = tonumber(Ptrn)
				if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را سایلنت کنید.", msg.id_, 'md') return end
				if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` کاربر با شناسه `"..UserId.."` جزو مدیران میباشد.\n_نمتوانید او را سایلنت کنید._", msg.id_, 'md') return end
				if isSilentUser(msg.chat_id_, UserId) then
					redis:srem(Hash, UserId)
					Text = "`>` کاربر با شناسه `"..UserId.."` از لیست کاربران سایلنت گروه خارج گردید. 🔉"
					.."\n_او هم‌اکنون اجازه چت در گروه را دارد._"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				else
					redis:sadd(Hash, UserId)
					Text = "`>` کاربر با شناسه `"..UserId.."` در گروه سایلنت شد. 🔇"
					.."\n_هر چتی از طرف این کاربر در گروه پاک خواهد شد._"
					sendText(msg.chat_id_, Text, msg.id_, 'md')
				end
			elseif Ptrn:match("^@[%a%d]") then
				Username = Ptrn:gsub("@","")
				resolveUsername(Username,
					function(Ex, Res)
						local msg = Ex.msg
						Hash = SilentHash..msg.chat_id_
						if Res.ID:lower() == "error" then --> if Error then Return
							sendText(msg.chat_id_, "`>` این نام کاربری اشتباه میباشد.", msg.id_, 'md')
							return
						end
						if not Res.type_.user_ then
							sendText(msg.chat_id_, "`>` این نام کاربری یک شخص نمیباشد.", msg.id_, 'md')
							return
						end
						UserFullName = Res.title_ or "----"
						UserId = Res.type_.user_.id_ or "----"
						UserUsername = Res.type_.user_.username_ or "None"
						if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را در گروه سایلنت کنید.", msg.id_, 'md') return end
						if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "<code>></code> کاربر با نام کاربری @"..UserUsername.." و شناسه <code>"..UserId.."</code> یک مدیر است. نمیتوانید او را سایلنت کنید.", msg.id_, 'html') return end
						if isSilentUser(msg.chat_id_, UserId) then
							redis:srem(Hash, UserId)
							Text = "<code>></code> کاربر با نام کاربری @"..UserUsername.." از لیست کاربران سایلنت خارج شد. 🔉"
							.."\n<i>او هم‌اکنون اجازه چت در گروه را دارد.</i>"
							sendText(msg.chat_id_, Text, msg.id_, 'html')
						else
							redis:sadd(Hash, UserId)
							Text = "<code>></code> کاربر با نام کاربری @"..UserUsername.." در گروه سایلنت شد. 🔇"
							.."\n<i>هر چتی از طرف این کاربر در گروه پاک خواهد شد.</i>"
							sendText(msg.chat_id_, Text, msg.id_, 'html')
						end
					end
				, {msg = msg})
			end
		end
	end
	
	--> CMD = /ban [By Reply] | Ban a User From Group ...
	if CmdLower:match("^[/!#](silent)$") or Cmd:match("^(سایلنت)$") then
		if msg.reply_to_message_id_ then
			if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Owners Only !
			getMessage(msg.chat_id_, msg.reply_to_message_id_,
				function (Ex, Res)
					local msg = Ex.msg
					Hash = SilentHash..msg.chat_id_
					UserId = Res.sender_user_id_
					if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را در گروه سایلنت کنید.", msg.id_, 'md') return end
					if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` این کاربر با شناسه `"..UserId.."` جزو مدیران ربات در گروه است.\n_نمیتوانید او را سایلنت کنید._", msg.reply_to_message_id_, 'md') return end
					if isSilentUser(msg.chat_id_, UserId) then
						redis:srem(Hash, UserId)
						Text = "<code>></code> این کاربر با شناسه <code>"..UserId.."</code> از لیست کاربران سایلنت گروه خارج شد. 🔉"
						.."\n<i>او هم‌اکنون اجازه چت در گروه را دارد.</i>"
						sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'html')
					else
						redis:sadd(Hash, UserId)
						Text = "<code>></code> این کاربر با شناسه <code>"..UserId.."</code> در گروه سایلنت شد. 🔇"
						.."\n<i>هر چتی از طرف این کاربر در گروه پاک خواهد شد.</i>"
						sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'html')
					end
				end
			, {msg = msg})
		end
	end
	
	if CmdLower:match("^[/!#](silentlist)$") or Cmd:match("^(لیست سایلنت)$") then
		Hash = SilentHash..msg.chat_id_
		SilentUsersArray = redis:smembers(Hash)
		if tonumber(redis:scard(Hash)) < 1 then
			local Text = "`>` لیست کاربران سایلنت در گروه خالی میباشد."
			.."\n_کسی در گروه سایلنت نمیباشد._"
			sendText(msg.chat_id_, Text, msg.id_, 'md')
			return
		end
		Text = "🔇 لیست کاربران سایلنت در گروه :"
		.."\n———————"
		.."\n"
		for i=1, #SilentUsersArray do
			Text = Text..i.."- `"..SilentUsersArray[i].."`\n"
		end
		Text = Text.."———————"
		.."\n`>` جهت دریافت اطلاعات درباره هر کدام از این کاربران از این دستور استفاده کنید :"
		.."\n/who [شناسه-کاربر]"
		.."\n» مثال :"
		.."\n`/who "..SilentUsersArray[1].."`"
		sendText(msg.chat_id_, Text, msg.id_, 'md')
	end
	----------------------------------------
	
	--> CMD = /kick [By Username and ID] | Silent a user in a Chat ...
	if CmdLower:match("^[/!#](kick) (.*)$") or Cmd:match("^(اخراج) (.*)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Owners Only !
		if not msg.reply_to_message_id_ then
			MatchesEN = {CmdLower:match("^[/!#](kick) (.*)$")}; MatchesFA = {Cmd:match("^(اخراج) (.*)$")}
			Ptrn = MatchesEN[2] or MatchesFA[2]
			if Ptrn:match("^%d+$") then
				UserId = tonumber(Ptrn)
				if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را از گروه اخراج کنید.", msg.id_, 'md') return end
				if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` کاربر با شناسه `"..UserId.."` جزو مدیران میباشد.\n_نمیتوانید او را اخراج کنید._", msg.id_, 'md') return end
				kickUser(msg.chat_id_, UserId)
				Text = "`>` کاربر با شناسه `"..UserId.."` از گروه اخراج شد. 👞"
				sendText(msg.chat_id_, Text, msg.id_, 'md')
			elseif Ptrn:match("^@[%a%d]") then
				Username = Ptrn:gsub("@","")
				resolveUsername(Username,
					function(Ex, Res)
						local msg = Ex.msg
						if Res.ID:lower() == "error" then --> if Error then Return
							sendText(msg.chat_id_, "`>` این نام کاربری اشتباه میباشد.", msg.id_, 'md')
							return
						end
						if not Res.type_.user_ then
							sendText(msg.chat_id_, "`>` این نام کاربری یک شخص نمیباشد.", msg.id_, 'md')
							return
						end
						UserFullName = Res.title_ or "----"
						UserId = Res.type_.user_.id_ or "----"
						UserUsername = Res.type_.user_.username_ or "None"
						if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را از گروه اخراج نمایید.", msg.id_, 'md') return end
						if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "<code>></code> کاربر با نام کاربری @"..UserUsername.." و شناسه <code>"..UserId.."</code> یک مدیر است. نمیتوانید او را اخراج کنید.", msg.id_, 'html') return end
						kickUser(msg.chat_id_, UserId)
						Text = "<code>></code> کاربر با نام کاربری @"..UserUsername.." از گروه اخراج شد. 👞"
						sendText(msg.chat_id_, Text, msg.id_, 'md')
					end
				, {msg = msg})
			end
		end
	end
	
	--> CMD = /kick [By Reply] | Ban a User From Group ...
	if CmdLower:match("^[/!#](kick)$") or Cmd:match("^(اخراج)$") then
		if msg.reply_to_message_id_ then
			if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Owners Only !
			getMessage(msg.chat_id_, msg.reply_to_message_id_,
				function (Ex, Res)
					local msg = Ex.msg
					UserId = Res.sender_user_id_
					if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را از گروه اخراج کنید.", msg.id_, 'md') return end
					if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` این کاربر با شناسه `"..UserId.."` جزو مدیران ربات در گروه است.\n_نمیتوانید او را اخراج کنید._", msg.reply_to_message_id_, 'md') return end
					kickUser(msg.chat_id_, UserId)
					Text = "`>` این کاربر با شناسه `"..UserId.."` از گروه اخراج شد. 👞"
					sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'md')
				end
			, {msg = msg})
		end
	end
	----------------------------------------
	
	--> CMD = /report [By Reply] | Ban a User From Group ...
	if CmdLower:match("^[/!#](report)$") or Cmd:match("^(ریپورت)$") then
		if msg.reply_to_message_id_ then
			if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Owners Only !
			getMessage(msg.chat_id_, msg.reply_to_message_id_,
				function (Ex, Res)
					local msg = Ex.msg
					UserId = Res.sender_user_id_
					if isBot(UserId) then sendText(msg.chat_id_, "`>` نمیتوانید خود ربات را ریپورت کنید !", msg.id_, 'md') return end
					if isMod(msg.chat_id_, UserId) then sendText(msg.chat_id_, "`>` این کاربر با شناسه `"..UserId.."` جزو مدیران ربات در گروه است.\n_نمیتوانید او را ریپورت کنید._", msg.reply_to_message_id_, 'md') return end
					tdcli.reportChannelSpam(msg.chat_id_, UserId, {[0] = msg.reply_to_message_id_})
					Text = "`>` این کاربر با شناسه `"..UserId.."` در گروه ریپورت شد. 📛"
					sendText(msg.chat_id_, Text, msg.reply_to_message_id_, 'md')
				end
			, {msg = msg})
		end
	end
	----------------------------------------

end -- END BAN.LUA


--[[

	Powered By :
		 _____       _  ____
		| ____|_ __ (_)/ ___|_ __ ___   __ _ TM
		|  _| | '_ \| | |  _| '_ ` _ \ / _` |
		| |___| | | | | |_| | | | | | | (_| |
		|_____|_| |_|_|\____|_| |_| |_|\__,_|
	
	****************************
	*  >> By : Reza Mehdipour  *
	*  > Channel : @EnigmaTM   *
	****************************
	
]]

function rmsgPlugin(msg) --> RMSG.LUA !
	
	Cmd = msg.content_.text_
	CmdLower = msg.content_.text_:lower()
	Data = loadJson(Config.ModFile)
	if not Data[tostring(msg.chat_id_)] then
		return
	end
	
	-- LOCK CMD -----------
	if Data[tostring(msg.chat_id_)]["settings"] then
		if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] then
			if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] == "yes" and not isMod(msg.chat_id_, msg.sender_user_id_) then
				return
			end
		end
	end
	-----------------------
	
	if CmdLower:match("^[/!#](rmsg) (%d+)$") or Cmd:match("^(حذف پیام) (%d+)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Mods Only !
		MatchesEN = {CmdLower:match("^[/!#](rmsg) (%d+)$")}; MatchesFA = {Cmd:match("^(حذف پیام) (%d+)$")}
		Ptrn = MatchesEN[2] or MatchesFA[2]
		MessageNumToDelete = tonumber(Ptrn)
		if (MessageNumToDelete > 100) or (MessageNumToDelete < 1) then
			Text = "`>` محدوده حذف آخرین پیام های گروه از *1* تا *100* میباشد !"
			sendText(msg.chat_id_, Text, msg.id_, 'md')
			return
		end
		tdcli.getChatHistory(msg.chat_id_, msg.id_, 0, MessageNumToDelete,
			function (Ex, Res)
				local msg = Ex.msg
				local MessageNumToDelete = Ex.MessageNumToDelete
				y = 0
				for k,v in pairs(Res.messages_) do
					deleteMessage(v.chat_id_, v.id_)
					y=y+1
				end
				sendText(msg.chat_id_, "🚮 `"..y.."` پیام آخر سوپرگروه پاکسازی شد !", msg.id_, "md")
			end
		,{msg = msg, MessageNumToDelete = MessageNumToDelete})
	end
	
	
	if CmdLower:match("^[/!#](cleanall)$") or Cmd:match("^(پاکسازی همه)$") then
		if not isMod(msg.chat_id_, msg.sender_user_id_) then notMod(msg) return end -- Mods Only !
		local function delete_msgs_pro(Ex, Res)
			local msg = Ex.msg
			k = 0
			for i=1, #Res.members_ do
				deleteMessagesFromUser(msg.chat_id_, Res.members_[k].user_id_)
				k=k+1
			end
			sendText(msg.chat_id_, 'پیام های گروه تا حد ممکن پاکسازی شدند. 🗑')
		end
		local function delete_msgs_normally(Ex, Res)
			local msg = Ex.msg
			for k,v in pairs(Res.messages_) do
				deleteMessage(msg.chat_id_, v.id_)
			end
		end
		tdcli.getChatHistory(msg.chat_id_, msg.id_, 0, 100, delete_msgs_normally, {msg = msg})  
		tdcli_function ({ID = "GetChannelMembers",channel_id_ = getChatId(msg.chat_id_).ID,offset_ = 0, limit_ = 5000}, delete_msgs_pro, {msg = msg})    
	end

end -- END RMSG.LUA

--[[

	Powered By :
		 _____       _  ____
		| ____|_ __ (_)/ ___|_ __ ___   __ _ TM
		|  _| | '_ \| | |  _| '_ ` _ \ / _` |
		| |___| | | | | |_| | | | | | | (_| |
		|_____|_| |_|_|\____|_| |_| |_|\__,_|
	
	****************************
	*  >> By : Reza Mehdipour  *
	*  > Channel : @EnigmaTM   *
	****************************
	
]]

function funPlugin(msg) --> FUN.LUA !
	
	Cmd = msg.content_.text_
	CmdLower = msg.content_.text_:lower()
	Data = loadJson(Config.ModFile)
	if not Data[tostring(msg.chat_id_)] then
		return
	end
	
	-- LOCK CMD -----------
	if Data[tostring(msg.chat_id_)]["settings"] then
		if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] then
			if Data[tostring(msg.chat_id_)]["settings"]["lock_cmd"] == "yes" and not isMod(msg.chat_id_, msg.sender_user_id_) then
				return
			end
		end
	end
	-----------------------
	
	--> CMD => /time | get the time ...
	if CmdLower:match("^[/!#](time)$") or Cmd:match("^(زمان)$") then
		local url , res = https.request('https://enigma-dev.ir/api/time/')
		if res ~= 200 then return end
		local jd = json:decode(url)
		Text = "🗓 امروز : "..jd.FaDate.WordTwo
		.."\n⏰ ساعت : "..jd.FaTime.Number
		.."\n"
		.."\n🗓*Today* : *"..jd.EnDate.WordOne.."*"
		.."\n⏰ *Time* : *"..jd.EnTime.Number.."*"
		sendText(msg.chat_id_, Text, msg.id_, 'md')
	end
	-----------------------------------
	
	--> CMD => /time | get the date ...
	if CmdLower:match("^[/!#](date)$") or Cmd:match("^(تاریخ)$") then
		url , res = https.request('https://enigma-dev.ir/api/date/')
		j = json:decode(url)
		Text = "☀ _منطقه ی زمانی_ : `"..j.ZoneName
		.."`\n\n⚜ قرن (شمسی) : `"..j.Century
		.."` اُم\n⚜ سال شمسی : `"..j.Year.Number
		.."`\n⚜ فصل : `"..j.Season.Name
		.."`\n⚜ ماه : `"..j.Month.Number.."` اُم ( `"..j.Month.Name.."` )"
		.."\n⚜ روز از ماه : `"..j.Day.Number
		.."`\n⚜ روز هفته : `"..j.Day.Name
		.."`\n\n⚡️ نام سال : `"..j.Year.Name
		.."`\n⚡️ نام ماه : `"..j.Month.Name
		.."`\n\n〽 تعداد روز های گذشته از سال : `"..j.DaysPassed.Number.."` ( `"..j.DaysPassed.Percent.."%` )"
		.."\n〽 روز های باقیمانده از سال : `"..j.DaysLeft.Number.."` ( `"..j.DaysLeft.Percent.."%` )\n\n"
		sendText(msg.chat_id_, Text, msg.id_, 'md')
	end
	---------------------------------
	
	--> CMD => /sticker [text] | Making Sticker using www.flamingtext.com ...
	if Cmd:match("^[/!#]([Ss][Tt][Ii][Cc][Kk][Ee][Rr]) (.*)$") or Cmd:match("^(استیکر) (.*)$") then
		MatchesEN = {Cmd:match("^[/!#]([Ss][Tt][Ii][Cc][Kk][Ee][Rr]) (.*)$")}; MatchesFA = {Cmd:match("^(استیکر) (.*)$")}
		Ptrn = MatchesEN[2] or MatchesFA[2]
		Modes = {'comics-logo','water-logo','3d-logo','blackbird-logo','runner-logo','graffiti-burn-logo','electric','standing3d-logo','style-logo','steel-logo','fluffy-logo','surfboard-logo','orlando-logo','fire-logo','clan-logo','chrominium-logo','harry-potter-logo','amped-logo','inferno-logo','uprise-logo','winner-logo','star-wars-logo','silver-logo','Design-Dance'}
		TextToSticker = URL.escape(Ptrn)
		url = 'http://www.flamingtext.com/net-fu/image_output.cgi?_comBuyRedirect=false&script='..Modes[math.random(#Modes)]..'&text='..TextToSticker..'&symbol_tagname=popular&fontsize=70&fontname=futura_poster&fontname_tagname=cool&textBorder=15&growSize=0&antialias=on&hinting=on&justify=2&letterSpacing=0&lineSpacing=0&textSlant=0&textVerticalSlant=0&textAngle=0&textOutline=off&textOutline=false&textOutlineSize=2&textColor=%230000CC&angle=0&blueFlame=on&blueFlame=false&framerate=75&frames=5&pframes=5&oframes=4&distance=2&transparent=off&transparent=false&extAnim=gif&animLoop=on&animLoop=false&defaultFrameRate=75&doScale=off&scaleWidth=240&scaleHeight=120&&_=1469943010141'
		title , res = http.request(url)
		jdat = json:decode(title)
		Sticker = jdat.src
		Address = "./data/photo"
		downloadToFile(Sticker, "t2s.png", Address)
		tdcli.sendSticker(msg.chat_id_, 0, 0, 0, nil, "./data/photo/t2s.png", dl_cb, nil)
		Text = "> درخواست ساخت استیکر توسط <user>"..msg.sender_user_id_.."</user> ارسال شد."
		sendText(msg.chat_id_, Text, false, false, msg.sender_user_id_)
	end
	------------------------------------------------------------------------
	
	--> CMD => /short [link] | Make links Short ...
	if CmdLower:match("^[/!#](short) (.*)$") or Cmd:match("^(کوتاه) (.*)$") then
		MatchesEN = {CmdLower:match("^[/!#](short) (.*)$")}; MatchesFA = {Cmd:match("^(کوتاه) (.*)$")}
		Ptrn = MatchesEN[2] or MatchesFA[2]:lower()
		if string.match(Ptrn,"^https://") or string.match(Ptrn,"^http://") then
			local Opizo = http.request('http://enigma-dev.ir/api/opizo/?url='..URL.escape(Ptrn))
			Opizo = json:decode(Opizo)
			Text = '🔗 لینک مورد نظر :'
			.."\n<code>"..Ptrn.."</code>"
			.."\n————————"
			.."\n🔂 لینک کوتاه شده با <b>Opizo</b> :"
			.."\n"..(Opizo.result or Opizo.description)
			sendText(msg.chat_id_, Text, msg.id_, 'html')
		else
			Text = "فرمت لینک شما صحیح نمیباشد !\nلینک شما باید یکی از پیشوند های زیر را در ابتدای خود دارا باشد :\n`http://`\n`https://`"
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		end
	end
	------------------------------------------------------------------------
	
	--> CMD => /tr [Word] | Translate a Word ...
	-- دریافت معنی یک کلمه
	if Cmd:match("^[/!#]([Tt][Rr]) (.*)$") or Cmd:match("^(ترجمه) (.*)$") then 
		MatchesEN = {Cmd:match("^[/!#]([Tt][Rr]) (.*)$")}; MatchesFA = {Cmd:match("^(ترجمه) (.*)$")}
		Ptrn = MatchesEN[2] or MatchesFA[2]
		url = https.request('https://translate.yandex.net/api/v1.5/tr.json/translate?key=trnsl.1.1.20160119T111342Z.fd6bf13b3590838f.6ce9d8cca4672f0ed24f649c1b502789c9f4687a&format=plain&lang=fa&text='..URL.escape(Ptrn)) 
		data = json:decode(url)
		Text = '🏷 عبارت اولیه : '..Ptrn..'\n🎙 زبان ترجمه : '..data.lang..'\n\n📝 ترجمه : '..data.text[1].."\n——————"
		.."\nدرخواست کننده: [<user>"..msg.sender_user_id_.."</user>]"
		sendText(msg.chat_id_, Text, msg.id_, false, msg.sender_user_id_)
	end
	--------------------------------------------
	
	--> CMD => /logo [word] | Create Logo ...
	if Cmd:match("^[/!#]([Ll][Oo][Gg][Oo]) (%d+) (.*)$") or Cmd:match("^(لوگو) (%d+) (.*)$") then
		MatchesEN = {Cmd:match("^[/!#]([Ll][Oo][Gg][Oo]) (%d+) (.*)$")}; MatchesFA = {Cmd:match("^(لوگو) (%d+) (.*)$")}
		LogoNum = MatchesEN[2] or MatchesFA[2]
		Text = MatchesEN[3] or MatchesFA[3]
		if tonumber(LogoNum) > 30 then
			sendText(msg.chat_id_, "عدد لوگو باید بین 1 تا 30 باشد.")
		else
			Url = "http://irapi.ir/logo/index.php?text="..Text.."&effect="..LogoNum
			Address = "./data/photo"
			downloadToFile(Url, 'logo.jpg', Address)
			tdcli.sendPhoto(msg.chat_id_, 0, 0, 1, nil, Address.."/logo.jpg", dl_cb, nil)
		end
	end
	-----------------------------------------
	
	--> CMD => /gif [style] [word] | Create Gif ...
	if Cmd:match("^[/!#]([Gg][Ii][Ff]) (%a+) (.*)$") or Cmd:match("^(گیف) (%a+) (.*)$") then
		MatchesEN = {Cmd:match("^[/!#]([Gg][Ii][Ff]) (%a+) (.*)$")}; MatchesFA = {Cmd:match("^(گیف) (%a+) (.*)$")}
		Style = MatchesEN[2] or MatchesFA[2]
		TextToGif = MatchesEN[3] or MatchesFA[3]
		if Style:lower() == "blue" then
			text = URL.escape(TextToGif)
			url2 = 'http://www.flamingtext.com/net-fu/image_output.cgi?_comBuyRedirect=false&script=blue-fire&text='..text..'&symbol_tagname=popular&fontsize=70&fontname=futura_poster&fontname_tagname=cool&textBorder=15&growSize=0&antialias=on&hinting=on&justify=2&letterSpacing=0&lineSpacing=0&textSlant=0&textVerticalSlant=0&textAngle=0&textOutline=off&textOutline=false&textOutlineSize=2&textColor=%230000CC&angle=0&blueFlame=on&blueFlame=false&framerate=75&frames=5&pframes=5&oframes=4&distance=2&transparent=off&transparent=false&extAnim=gif&animLoop=on&animLoop=false&defaultFrameRate=75&doScale=off&scaleWidth=240&scaleHeight=120&&_=1469943010141'
			title , res = http.request(url2)
			jdat = json:decode(title)
			gif = jdat.src
			address = "./data/photo"
			downloadToFile(gif, 't2g.gif', address)
			tdcli.sendAnimation(msg.chat_id_, msg.id_, 0, 0, nil, address.."/t2g.gif", 0, 0, "", dl_cb, nil)
			rep_text = "کاربر <user>"..msg.sender_user_id_.."</user> در خواست ساخت گیف را ارسال کرد."
			sendText(msg.chat_id_, rep_text, 0, false, msg.sender_user_id_)
			return
		elseif Style:lower() == "random" then
			local modes = {'memories-anim-logo','alien-glow-anim-logo','flash-anim-logo','flaming-logo','whirl-anim-logo','highlight-anim-logo','burn-in-anim-logo','shake-anim-logo','inner-fire-anim-logo','jump-anim-logo'}
			local text = URL.escape(TextToGif)
			local url = 'http://www.flamingtext.com/net-fu/image_output.cgi?_comBuyRedirect=false&script='..modes[math.random(#modes)]..'&text='..text..'&symbol_tagname=popular&fontsize=70&fontname=futura_poster&fontname_tagname=cool&textBorder=15&growSize=0&antialias=on&hinting=on&justify=2&letterSpacing=0&lineSpacing=0&textSlant=0&textVerticalSlant=0&textAngle=0&textOutline=off&textOutline=false&textOutlineSize=2&textColor=%230000CC&angle=0&blueFlame=on&blueFlame=false&framerate=75&frames=5&pframes=5&oframes=4&distance=2&transparent=off&transparent=false&extAnim=gif&animLoop=on&animLoop=false&defaultFrameRate=75&doScale=off&scaleWidth=240&scaleHeight=120&&_=1469943010141'
			local title , res = http.request(url)
			local jdat = json:decode(title)
			local gif = jdat.src
			address = "./data/photo"
			downloadToFile(gif, 't2g.gif', address)
			tdcli.sendAnimation(msg.chat_id_, msg.id_, 0, 0, nil, address.."/t2g.gif", 0, 0, "", dl_cb, nil)
			rep_text = "کاربر <user>"..msg.sender_user_id_.."</user> در خواست ساخت گیف را ارسال کرد."
			sendText(msg.chat_id_, rep_text, 0, false, msg.sender_user_id_)
			return
		elseif Style:lower() == 'text' then
			set = 'Blinking+Text'
		elseif Style:lower() == 'dazzle' then
			set = 'Dazzle+Text'
		elseif Style:lower() == 'prohibited' then
			set = 'No+Button'
		elseif Style:lower() == 'star' then
			set = 'Walk+of+Fame+Animated'
		elseif Style:lower() == 'wag' then
			set = 'Wag+Finger'
		elseif Style:lower() == 'glitter' then
			set = 'Glitter+Text'
		elseif Style:lower() == 'bliss' then
			set = 'Bliss'
		elseif Style:lower() == 'flasher' then
			set = 'Flasher'
		elseif Style:lower() == 'roman' then
			set = 'Roman+Temple+Animated'
		else
			set = 'Roman+Temple+Animated'
		end
		text = URL.escape(TextToGif)
		colors = {'00FF00','6699FF','CC99CC','CC66FF','0066FF','000000','CC0066','FF33CC','FF0000','FFCCCC','FF66CC','33FF00','FFFFFF','00FF00'}
		bc = colors[math.random(#colors)]
		colorss = {'00FF00','6699FF','CC99CC','CC66FF','0066FF','000000','CC0066','FF33CC','FFF200','FF0000','FFCCCC','FF66CC','33FF00','FFFFFF','00FF00'}
		tc = colorss[math.random(#colorss)]
		url2 = 'http://www.imagechef.com/ic/maker.jsp?filter=&jitter=0&tid='..set..'&color0='..bc..'&color1='..tc..'&color2=000000&customimg=&0='..text
		title , res = http.request(url2)
		jdat = json:decode(title)
		gif = jdat.resImage
		address = "./data/photo"
		downloadToFile(gif, "t2g.gif", address)
		tdcli.sendAnimation(msg.chat_id_, msg.id_, 0, 0, nil, address.."/t2g.gif", 0, 0, "", dl_cb, nil)
		rep_text = "کاربر <user>"..msg.sender_user_id_.."</user> در خواست ساخت گیف را ارسال کرد."
		sendText(msg.chat_id_, rep_text, 0, false, msg.sender_user_id_)
	end
	-----------------------------------------
	
	--> CMD => /voice [word] | Create voice ...
	if Cmd:match("^[/!#]([Vv][Oo][Ii][Cc][Ee]) (.*)$") or Cmd:match("^(صدا) (.*)$") then 
		MatchesEN = {Cmd:match("^[/!#]([Vv][Oo][Ii][Cc][Ee]) (.*)$")}; MatchesFA = {Cmd:match("^(صدا) (.*)$")}
		TextToVoice = MatchesEN[2] or MatchesFA[2]
		Url = "http://irapi.ir/farsireader/?text="..URL.escape(TextToVoice)
		Address = "./data/photo"
		downloadToFile(Url, 'voice.mp3', Address)
		tdcli.sendVoice(msg.chat_id_, msg.id_, 0, 1, nil, Address.."/voice.mp3", nil, nil, "", dl_cb, nil)
	end
	-------------------------------------------
	
	--> CMD => /weather [cityName] | Get the Stats of a City's weather ...
	if Cmd:match("^[/!#]([Ww][Ee][Aa][Tt][Hh][Ee][Rr]) (.*)$") or Cmd:match("^(هوا) (.*)$") then
		MatchesEN = {Cmd:match("^[/!#]([Ww][Ee][Aa][Tt][Hh][Ee][Rr]) (.*)$")}; MatchesFA = {Cmd:match("^(هوا) (.*)$")}
		Ptrn = MatchesEN[2] or MatchesFA[2]
		local function temps(K)
			local F = (K*1.8)-459.67
			local C = K-273.15
			return F,C
		end
		
		local res = http.request("http://api.openweathermap.org/data/2.5/weather?q="..URL.escape(Ptrn).."&appid=269ed82391822cc692c9afd59f4aabba")
		local jtab = json:decode(res)
		if jtab.name then
			if jtab.weather[1].main == "Thunderstorm" then
				status = "⛈طوفاني"
			elseif jtab.weather[1].main == "Drizzle" then
				status = "🌦نمنم باران"
			elseif jtab.weather[1].main == "Rain" then
				status = "🌧باراني"
			elseif jtab.weather[1].main == "Snow" then
				status = "🌨برفي"
			elseif jtab.weather[1].main == "Atmosphere" then
				status = "🌫مه - غباز آلود"
			elseif jtab.weather[1].main == "Clear" then
				status = "🌤️صاف"
			elseif jtab.weather[1].main == "Clouds" then
				status = "☁️ابري"
			elseif jtab.weather[1].main == "Extreme" then
					status = "-------"
			elseif jtab.weather[1].main == "Additional" then
				status = "-------"
			else
				status = "-------"
			end
			local F1,C1 = temps(jtab.main.temp)
			local F2,C2 = temps(jtab.main.temp_min)
			local F3,C3 = temps(jtab.main.temp_max)
			if jtab.rain then
				rain = jtab.rain["3h"].." ميليمتر"
			else
				rain = "-----"
			end
			if jtab.snow then
				snow = jtab.snow["3h"].." ميليمتر"
			else
				snow = "-----"
			end
			today = "نام شهر : *"..jtab.name.."*\n"
			.."کشور : *"..(jtab.sys.country or "----").."*\n"
			.."وضعیت هوا :\n"
			.."   `"..C1.."° درجه سانتيگراد (سلسيوس)`\n"
			.."   `"..F1.."° فارنهايت`\n"
			.."   `"..jtab.main.temp.."° کلوين`\n"
			.."هوا "..status.." ميباشد\n\n"
			.."حداقل دماي امروز: `C"..C2.."°   F"..F2.."°   K"..jtab.main.temp_min.."°`\n"
			.."حداکثر دماي امروز: `C"..C3.."°   F"..F3.."°   K"..jtab.main.temp_max.."°`\n"
			.."رطوبت هوا: `"..jtab.main.humidity.."%`\n"
			.."مقدار ابر آسمان: `"..jtab.clouds.all.."%`\n"
			.."سرعت باد: `"..(jtab.wind.speed or "------").." متر بر ثانیه`\n"
			.."جهت باد: `"..(jtab.wind.deg or "------").."° درجه`\n"
			.."فشار هوا: `"..(jtab.main.pressure/1000).." بار(اتمسفر)`\n"
			.."بارندگي 3ساعت اخير: `"..rain.."`\n"
			.."بارش برف 3ساعت اخير: `"..snow.."`\n\n"
			after = ""
			local res = http.request("http://api.openweathermap.org/data/2.5/forecast?q="..URL.escape(Ptrn).."&appid=269ed82391822cc692c9afd59f4aabba")
			local jtab = json:decode(res)
			for i=1,5 do
				local F1,C1 = temps(jtab.list[i].main.temp_min)
				local F2,C2 = temps(jtab.list[i].main.temp_max)
				if jtab.list[i].weather[1].main == "Thunderstorm" then
					status = "⛈طوفانی"
				elseif jtab.list[i].weather[1].main == "Drizzle" then
					status = "🌦نمنم باران"
				elseif jtab.list[i].weather[1].main == "Rain" then
					status = "🌧بارانی"
				elseif jtab.list[i].weather[1].main == "Snow" then
					status = "🌨برفی"
				elseif jtab.list[i].weather[1].main == "Atmosphere" then
					status = "🌫مه - غباز آلود"
				elseif jtab.list[i].weather[1].main == "Clear" then
					status = "🌤️صاف"
				elseif jtab.list[i].weather[1].main == "Clouds" then
					status = "☁️ابری"
				elseif jtab.list[i].weather[1].main == "Extreme" then
					status = "-------"
				elseif jtab.list[i].weather[1].main == "Additional" then
					status = "-------"
				else
					status = "-------"
				end
				if i == 1 then
					day = "فردا هوا "
				elseif i == 2 then
					day = "پس فردا هوا "
				elseif i == 3 then
					day = "3 روز بعد هوا "
				elseif i == 4 then
					day ="4 روز بعد هوا "
				elseif i == 5 then
					day = "5 روز بعد هوا "
				end
				after = after.."- "..day..status.." ميباشد. \n🔺`C"..C2.."°`  *-*  `F"..F2.."°`\n🔻`C"..C1.."°`  *-*  `F"..F1.."°`\n"
			end
			Text = today.."وضعيت آب و هوا در پنج روز آينده:\n"..after
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		else
			Text = "مکان وارد شده صحیح نمیباشد."
			sendText(msg.chat_id_, Text, msg.id_, 'md')
		end
	end
	------------------------------------------------------------------------
	
	--> CMD => /beauty [Word] | Beauty a Text ...
	if Cmd:match("^[/!#]([Bb][Ee][Aa][Uu][Tt][Yy]) (.*)$") or Cmd:match("^(زیباسازی) (.*)$") then
		MatchesEN = {Cmd:match("^[/!#]([Bb][Ee][Aa][Uu][Tt][Yy]) (.*)$")}; MatchesFA = {Cmd:match("^(زیباسازی) (.*)$")}
		TextToBeauty = MatchesEN[2] or MatchesFA[2]
		if TextToBeauty:len() > 20 then
			sendText(msg.chat_id_, "> تعداد حروف متن جهت زیباسازی باید کمتر از 20 تا باشد.\nمتن شما دارای "..TextToBeauty:len().." کاراکتر است.", msg.id_)
			return
		end
		local font_base = "A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,0,9,8,7,6,5,4,3,2,1,.,_"
		local font_hash = "z,y,x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,Z,Y,X,W,V,U,T,S,R,Q,P,O,N,M,L,K,J,I,H,G,F,E,D,C,B,A,0,1,2,3,4,5,6,7,8,9,.,_"
		local fonts = {
			"ⓐ,ⓑ,ⓒ,ⓓ,ⓔ,ⓕ,ⓖ,ⓗ,ⓘ,ⓙ,ⓚ,ⓛ,ⓜ,ⓝ,ⓞ,ⓟ,ⓠ,ⓡ,ⓢ,ⓣ,ⓤ,ⓥ,ⓦ,ⓧ,ⓨ,ⓩ,ⓐ,ⓑ,ⓒ,ⓓ,ⓔ,ⓕ,ⓖ,ⓗ,ⓘ,ⓙ,ⓚ,ⓛ,ⓜ,ⓝ,ⓞ,ⓟ,ⓠ,ⓡ,ⓢ,ⓣ,ⓤ,ⓥ,ⓦ,ⓧ,ⓨ,ⓩ,⓪,➈,➇,➆,➅,➄,➃,➂,➁,➀,●,_",
			"⒜,⒝,⒞,⒟,⒠,⒡,⒢,⒣,⒤,⒥,⒦,⒧,⒨,⒩,⒪,⒫,⒬,⒭,⒮,⒯,⒰,⒱,⒲,⒳,⒴,⒵,⒜,⒝,⒞,⒟,⒠,⒡,⒢,⒣,⒤,⒥,⒦,⒧,⒨,⒩,⒪,⒫,⒬,⒭,⒮,⒯,⒰,⒱,⒲,⒳,⒴,⒵,⓪,⑼,⑻,⑺,⑹,⑸,⑷,⑶,⑵,⑴,.,_",
			"α,в,c,∂,є,ƒ,g,н,ι,נ,к,ℓ,м,η,σ,ρ,q,я,ѕ,т,υ,ν,ω,χ,у,z,α,в,c,∂,є,ƒ,g,н,ι,נ,к,ℓ,м,η,σ,ρ,q,я,ѕ,т,υ,ν,ω,χ,у,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"α,в,c,d,e,ғ,ɢ,н,ι,j,ĸ,l,м,ɴ,o,p,q,r,ѕ,т,υ,v,w,х,y,z,α,в,c,d,e,ғ,ɢ,н,ι,j,ĸ,l,м,ɴ,o,p,q,r,ѕ,т,υ,v,w,х,y,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"α,в,¢,đ,e,f,g,ħ,ı,נ,κ,ł,м,и,ø,ρ,q,я,š,т,υ,ν,ω,χ,ч,z,α,в,¢,đ,e,f,g,ħ,ı,נ,κ,ł,м,и,ø,ρ,q,я,š,т,υ,ν,ω,χ,ч,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ą,ҍ,ç,ժ,ҽ,ƒ,ց,հ,ì,ʝ,ҟ,Ӏ,ʍ,ղ,օ,ք,զ,ɾ,ʂ,է,մ,ѵ,ա,×,վ,Հ,ą,ҍ,ç,ժ,ҽ,ƒ,ց,հ,ì,ʝ,ҟ,Ӏ,ʍ,ղ,օ,ք,զ,ɾ,ʂ,է,մ,ѵ,ա,×,վ,Հ,⊘,९,𝟠,7,Ϭ,Ƽ,५,Ӡ,ϩ,𝟙,.,_",		"ค,ც,८,ძ,૯,Բ,૭,Һ,ɿ,ʆ,қ,Ն,ɱ,Ո,૦,ƿ,ҩ,Ր,ς,੮,υ,౮,ω,૪,ע,ઽ,ค,ც,८,ძ,૯,Բ,૭,Һ,ɿ,ʆ,қ,Ն,ɱ,Ո,૦,ƿ,ҩ,Ր,ς,੮,υ,౮,ω,૪,ע,ઽ,0,9,8,7,6,5,4,3,2,1,.,_",
			"α,ß,ς,d,ε,ƒ,g,h,ï,յ,κ,ﾚ,m,η,⊕,p,Ω,r,š,†,u,∀,ω,x,ψ,z,α,ß,ς,d,ε,ƒ,g,h,ï,յ,κ,ﾚ,m,η,⊕,p,Ω,r,š,†,u,∀,ω,x,ψ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ค,๒,ς,๔,є,Ŧ,ɠ,ђ,เ,ן,к,l,๓,ภ,๏,թ,ợ,г,ร,t,ย,v,ฬ,x,ץ,z,ค,๒,ς,๔,є,Ŧ,ɠ,ђ,เ,ן,к,l,๓,ภ,๏,թ,ợ,г,ร,t,ย,v,ฬ,x,ץ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ﾑ,乃,ζ,Ð,乇,ｷ,Ǥ,ん,ﾉ,ﾌ,ズ,ﾚ,ᄊ,刀,Ծ,ｱ,Q,尺,ㄎ,ｲ,Ц,Џ,Щ,ﾒ,ﾘ,乙,ﾑ,乃,ζ,Ð,乇,ｷ,Ǥ,ん,ﾉ,ﾌ,ズ,ﾚ,ᄊ,刀,Ծ,ｱ,q,尺,ㄎ,ｲ,Ц,Џ,Щ,ﾒ,ﾘ,乙,ᅙ,9,8,ᆨ,6,5,4,3,ᆯ,1,.,_",
			"α,β,c,δ,ε,Ŧ,ĝ,h,ι,j,κ,l,ʍ,π,ø,ρ,φ,Ʀ,$,†,u,υ,ω,χ,ψ,z,α,β,c,δ,ε,Ŧ,ĝ,h,ι,j,κ,l,ʍ,π,ø,ρ,φ,Ʀ,$,†,u,υ,ω,χ,ψ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ձ,ъ,ƈ,ժ,ε,բ,ց,հ,ﻨ,յ,ĸ,l,ო,ռ,օ,թ,զ,г,ร,է,ս,ν,ա,×,ყ,২,ձ,ъ,ƈ,ժ,ε,բ,ց,հ,ﻨ,յ,ĸ,l,ო,ռ,օ,թ,զ,г,ร,է,ս,ν,ա,×,ყ,২,0,9,8,7,6,5,4,3,2,1,.,_",
			"Λ,ɓ,¢,Ɗ,£,ƒ,ɢ,ɦ,ĩ,ʝ,Қ,Ł,ɱ,ה,ø,Ṗ,Ҩ,Ŕ,Ş,Ŧ,Ū,Ɣ,ω,Ж,¥,Ẑ,Λ,ɓ,¢,Ɗ,£,ƒ,ɢ,ɦ,ĩ,ʝ,Қ,Ł,ɱ,ה,ø,Ṗ,Ҩ,Ŕ,Ş,Ŧ,Ū,Ɣ,ω,Ж,¥,Ẑ,0,9,8,7,6,5,4,3,2,1,.,_",
			"Λ,Б,Ͼ,Ð,Ξ,Ŧ,G,H,ł,J,К,Ł,M,Л,Ф,P,Ǫ,Я,S,T,U,V,Ш,Ж,Џ,Z,Λ,Б,Ͼ,Ð,Ξ,Ŧ,g,h,ł,j,К,Ł,m,Л,Ф,p,Ǫ,Я,s,t,u,v,Ш,Ж,Џ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ɐ,q,ɔ,p,ǝ,ɟ,ɓ,ɥ,ı,ſ,ʞ,ๅ,ɯ,u,o,d,b,ɹ,s,ʇ,n,ʌ,ʍ,x,ʎ,z,ɐ,q,ɔ,p,ǝ,ɟ,ɓ,ɥ,ı,ſ,ʞ,ๅ,ɯ,u,o,d,b,ɹ,s,ʇ,n,ʌ,ʍ,x,ʎ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ɒ,d,ɔ,b,ɘ,ʇ,ϱ,н,i,į,ʞ,l,м,и,o,q,p,я,ƨ,т,υ,v,w,x,γ,z,ɒ,d,ɔ,b,ɘ,ʇ,ϱ,н,i,į,ʞ,l,м,и,o,q,p,я,ƨ,т,υ,v,w,x,γ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"A̴,̴B̴,̴C̴,̴D̴,̴E̴,̴F̴,̴G̴,̴H̴,̴I̴,̴J̴,̴K̴,̴L̴,̴M̴,̴N̴,̴O̴,̴P̴,̴Q̴,̴R̴,̴S̴,̴T̴,̴U̴,̴V̴,̴W̴,̴X̴,̴Y̴,̴Z̴,̴a̴,̴b̴,̴c̴,̴d̴,̴e̴,̴f̴,̴g̴,̴h̴,̴i̴,̴j̴,̴k̴,̴l̴,̴m̴,̴n̴,̴o̴,̴p̴,̴q̴,̴r̴,̴s̴,̴t̴,̴u̴,̴v̴,̴w̴,̴x̴,̴y̴,̴z̴,̴0̴,̴9̴,̴8̴,̴7̴,̴6̴,̴5̴,̴4̴,̴3̴,̴2̴,̴1̴,̴.̴,̴_̴",
			"ⓐ,ⓑ,ⓒ,ⓓ,ⓔ,ⓕ,ⓖ,ⓗ,ⓘ,ⓙ,ⓚ,ⓛ,ⓜ,ⓝ,ⓞ,ⓟ,ⓠ,ⓡ,ⓢ,ⓣ,ⓤ,ⓥ,ⓦ,ⓧ,ⓨ,ⓩ,ⓐ,ⓑ,ⓒ,ⓓ,ⓔ,ⓕ,ⓖ,ⓗ,ⓘ,ⓙ,ⓚ,ⓛ,ⓜ,ⓝ,ⓞ,ⓟ,ⓠ,ⓡ,ⓢ,ⓣ,ⓤ,ⓥ,ⓦ,ⓧ,ⓨ,ⓩ,⓪,➈,➇,➆,➅,➄,➃,➂,➁,➀,●,_",
			"⒜,⒝,⒞,⒟,⒠,⒡,⒢,⒣,⒤,⒥,⒦,⒧,⒨,⒩,⒪,⒫,⒬,⒭,⒮,⒯,⒰,⒱,⒲,⒳,⒴,⒵,⒜,⒝,⒞,⒟,⒠,⒡,⒢,⒣,⒤,⒥,⒦,⒧,⒨,⒩,⒪,⒫,⒬,⒭,⒮,⒯,⒰,⒱,⒲,⒳,⒴,⒵,⓪,⑼,⑻,⑺,⑹,⑸,⑷,⑶,⑵,⑴,.,_",
			"α,в,c,∂,є,ƒ,g,н,ι,נ,к,ℓ,м,η,σ,ρ,q,я,ѕ,т,υ,ν,ω,χ,у,z,α,в,c,∂,є,ƒ,g,н,ι,נ,к,ℓ,м,η,σ,ρ,q,я,ѕ,т,υ,ν,ω,χ,у,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"α,в,c,ɗ,є,f,g,н,ι,נ,к,Ɩ,м,η,σ,ρ,q,я,ѕ,т,υ,ν,ω,x,у,z,α,в,c,ɗ,є,f,g,н,ι,נ,к,Ɩ,м,η,σ,ρ,q,я,ѕ,т,υ,ν,ω,x,у,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"α,в,c,d,e,ғ,ɢ,н,ι,j,ĸ,l,м,ɴ,o,p,q,r,ѕ,т,υ,v,w,х,y,z,α,в,c,d,e,ғ,ɢ,н,ι,j,ĸ,l,м,ɴ,o,p,q,r,ѕ,т,υ,v,w,х,y,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"α,Ⴆ,ƈ,ԃ,ҽ,ϝ,ɠ,ԋ,ι,ʝ,ƙ,ʅ,ɱ,ɳ,σ,ρ,ϙ,ɾ,ʂ,ƚ,υ,ʋ,ɯ,x,ყ,ȥ,α,Ⴆ,ƈ,ԃ,ҽ,ϝ,ɠ,ԋ,ι,ʝ,ƙ,ʅ,ɱ,ɳ,σ,ρ,ϙ,ɾ,ʂ,ƚ,υ,ʋ,ɯ,x,ყ,ȥ,0,9,8,7,6,5,4,3,2,1,.,_",
			"α,в,¢,đ,e,f,g,ħ,ı,נ,κ,ł,м,и,ø,ρ,q,я,š,т,υ,ν,ω,χ,ч,z,α,в,¢,đ,e,f,g,ħ,ı,נ,κ,ł,м,и,ø,ρ,q,я,š,т,υ,ν,ω,χ,ч,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ą,ɓ,ƈ,đ,ε,∱,ɠ,ɧ,ï,ʆ,ҡ,ℓ,ɱ,ŋ,σ,þ,ҩ,ŗ,ş,ŧ,ų,√,щ,х,γ,ẕ,ą,ɓ,ƈ,đ,ε,∱,ɠ,ɧ,ï,ʆ,ҡ,ℓ,ɱ,ŋ,σ,þ,ҩ,ŗ,ş,ŧ,ų,√,щ,х,γ,ẕ,0,9,8,7,6,5,4,3,2,1,.,_",
			"ą,ҍ,ç,ժ,ҽ,ƒ,ց,հ,ì,ʝ,ҟ,Ӏ,ʍ,ղ,օ,ք,զ,ɾ,ʂ,է,մ,ѵ,ա,×,վ,Հ,ą,ҍ,ç,ժ,ҽ,ƒ,ց,հ,ì,ʝ,ҟ,Ӏ,ʍ,ղ,օ,ք,զ,ɾ,ʂ,է,մ,ѵ,ա,×,վ,Հ,⊘,९,𝟠,7,Ϭ,Ƽ,५,Ӡ,ϩ,𝟙,.,_",
			"მ,ჩ,ƈ,ძ,ε,բ,ց,հ,ἶ,ʝ,ƙ,l,ო,ղ,օ,ր,գ,ɾ,ʂ,է,մ,ν,ω,ჯ,ყ,z,მ,ჩ,ƈ,ძ,ε,բ,ց,հ,ἶ,ʝ,ƙ,l,ო,ղ,օ,ր,գ,ɾ,ʂ,է,մ,ν,ω,ჯ,ყ,z,0,Գ,Ց,Դ,6,5,Վ,Յ,Զ,1,.,_",
			"ค,ც,८,ძ,૯,Բ,૭,Һ,ɿ,ʆ,қ,Ն,ɱ,Ո,૦,ƿ,ҩ,Ր,ς,੮,υ,౮,ω,૪,ע,ઽ,ค,ც,८,ძ,૯,Բ,૭,Һ,ɿ,ʆ,қ,Ն,ɱ,Ո,૦,ƿ,ҩ,Ր,ς,੮,υ,౮,ω,૪,ע,ઽ,0,9,8,7,6,5,4,3,2,1,.,_",
			"α,ß,ς,d,ε,ƒ,g,h,ï,յ,κ,ﾚ,m,η,⊕,p,Ω,r,š,†,u,∀,ω,x,ψ,z,α,ß,ς,d,ε,ƒ,g,h,ï,յ,κ,ﾚ,m,η,⊕,p,Ω,r,š,†,u,∀,ω,x,ψ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ª,b,¢,Þ,È,F,૬,ɧ,Î,j,Κ,Ļ,м,η,◊,Ƿ,ƍ,r,S,⊥,µ,√,w,×,ý,z,ª,b,¢,Þ,È,F,૬,ɧ,Î,j,Κ,Ļ,м,η,◊,Ƿ,ƍ,r,S,⊥,µ,√,w,×,ý,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"Δ,Ɓ,C,D,Σ,F,G,H,I,J,Ƙ,L,Μ,∏,Θ,Ƥ,Ⴓ,Γ,Ѕ,Ƭ,Ʊ,Ʋ,Ш,Ж,Ψ,Z,λ,ϐ,ς,d,ε,ғ,ɢ,н,ι,ϳ,κ,l,ϻ,π,σ,ρ,φ,г,s,τ,υ,v,ш,ϰ,ψ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ค,๒,ς,๔,є,Ŧ,ɠ,ђ,เ,ן,к,l,๓,ภ,๏,թ,ợ,г,ร,t,ย,v,ฬ,x,ץ,z,ค,๒,ς,๔,є,Ŧ,ɠ,ђ,เ,ן,к,l,๓,ภ,๏,թ,ợ,г,ร,t,ย,v,ฬ,x,ץ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"Λ,ß,Ƈ,D,Ɛ,F,Ɠ,Ĥ,Ī,Ĵ,Ҡ,Ŀ,M,И,♡,Ṗ,Ҩ,Ŕ,S,Ƭ,Ʊ,Ѵ,Ѡ,Ӿ,Y,Z,Λ,ß,Ƈ,D,Ɛ,F,Ɠ,Ĥ,Ī,Ĵ,Ҡ,Ŀ,M,И,♡,Ṗ,Ҩ,Ŕ,S,Ƭ,Ʊ,Ѵ,Ѡ,Ӿ,Y,Z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ﾑ,乃,ζ,Ð,乇,ｷ,Ǥ,ん,ﾉ,ﾌ,ズ,ﾚ,ᄊ,刀,Ծ,ｱ,Q,尺,ㄎ,ｲ,Ц,Џ,Щ,ﾒ,ﾘ,乙,ﾑ,乃,ζ,Ð,乇,ｷ,Ǥ,ん,ﾉ,ﾌ,ズ,ﾚ,ᄊ,刀,Ծ,ｱ,q,尺,ㄎ,ｲ,Ц,Џ,Щ,ﾒ,ﾘ,乙,ᅙ,9,8,ᆨ,6,5,4,3,ᆯ,1,.,_",
			"α,β,c,δ,ε,Ŧ,ĝ,h,ι,j,κ,l,ʍ,π,ø,ρ,φ,Ʀ,$,†,u,υ,ω,χ,ψ,z,α,β,c,δ,ε,Ŧ,ĝ,h,ι,j,κ,l,ʍ,π,ø,ρ,φ,Ʀ,$,†,u,υ,ω,χ,ψ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ค,๖,¢,໓,ē,f,ງ,h,i,ว,k,l,๓,ຖ,໐,p,๑,r,Ş,t,น,ง,ຟ,x,ฯ,ຊ,ค,๖,¢,໓,ē,f,ງ,h,i,ว,k,l,๓,ຖ,໐,p,๑,r,Ş,t,น,ง,ຟ,x,ฯ,ຊ,0,9,8,7,6,5,4,3,2,1,.,_",
			"ձ,ъ,ƈ,ժ,ε,բ,ց,հ,ﻨ,յ,ĸ,l,ო,ռ,օ,թ,զ,г,ร,է,ս,ν,ա,×,ყ,২,ձ,ъ,ƈ,ժ,ε,բ,ց,հ,ﻨ,յ,ĸ,l,ო,ռ,օ,թ,զ,г,ร,է,ս,ν,ա,×,ყ,২,0,9,8,7,6,5,4,3,2,1,.,_",
			"Â,ß,Ĉ,Ð,Є,Ŧ,Ǥ,Ħ,Ī,ʖ,Қ,Ŀ,♏,И,Ø,P,Ҩ,R,$,ƚ,Ц,V,Щ,X,￥,Ẕ,Â,ß,Ĉ,Ð,Є,Ŧ,Ǥ,Ħ,Ī,ʖ,Қ,Ŀ,♏,И,Ø,P,Ҩ,R,$,ƚ,Ц,V,Щ,X,￥,Ẕ,0,9,8,7,6,5,4,3,2,1,.,_",
			"Λ,ɓ,¢,Ɗ,£,ƒ,ɢ,ɦ,ĩ,ʝ,Қ,Ł,ɱ,ה,ø,Ṗ,Ҩ,Ŕ,Ş,Ŧ,Ū,Ɣ,ω,Ж,¥,Ẑ,Λ,ɓ,¢,Ɗ,£,ƒ,ɢ,ɦ,ĩ,ʝ,Қ,Ł,ɱ,ה,ø,Ṗ,Ҩ,Ŕ,Ş,Ŧ,Ū,Ɣ,ω,Ж,¥,Ẑ,0,9,8,7,6,5,4,3,2,1,.,_",
			"Λ,Б,Ͼ,Ð,Ξ,Ŧ,G,H,ł,J,К,Ł,M,Л,Ф,P,Ǫ,Я,S,T,U,V,Ш,Ж,Џ,Z,Λ,Б,Ͼ,Ð,Ξ,Ŧ,g,h,ł,j,К,Ł,m,Л,Ф,p,Ǫ,Я,s,t,u,v,Ш,Ж,Џ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"Թ,Յ,Շ,Ժ,ȝ,Բ,Գ,ɧ,ɿ,ʝ,ƙ,ʅ,ʍ,Ռ,Ծ,ρ,φ,Ր,Տ,Ե,Մ,ע,ա,Ճ,Վ,Հ,Թ,Յ,Շ,Ժ,ȝ,Բ,Գ,ɧ,ɿ,ʝ,ƙ,ʅ,ʍ,Ռ,Ծ,ρ,φ,Ր,Տ,Ե,Մ,ע,ա,Ճ,Վ,Հ,0,9,8,7,6,5,4,3,2,1,.,_",
			"Æ,þ,©,Ð,E,F,ζ,Ħ,Ї,¿,ズ,ᄂ,M,Ñ,Θ,Ƿ,Ø,Ґ,Š,τ,υ,¥,w,χ,y,շ,Æ,þ,©,Ð,E,F,ζ,Ħ,Ї,¿,ズ,ᄂ,M,Ñ,Θ,Ƿ,Ø,Ґ,Š,τ,υ,¥,w,χ,y,շ,0,9,8,7,6,5,4,3,2,1,.,_",
			"ɐ,q,ɔ,p,ǝ,ɟ,ɓ,ɥ,ı,ſ,ʞ,ๅ,ɯ,u,o,d,b,ɹ,s,ʇ,n,ʌ,ʍ,x,ʎ,z,ɐ,q,ɔ,p,ǝ,ɟ,ɓ,ɥ,ı,ſ,ʞ,ๅ,ɯ,u,o,d,b,ɹ,s,ʇ,n,ʌ,ʍ,x,ʎ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"ɒ,d,ɔ,b,ɘ,ʇ,ϱ,н,i,į,ʞ,l,м,и,o,q,p,я,ƨ,т,υ,v,w,x,γ,z,ɒ,d,ɔ,b,ɘ,ʇ,ϱ,н,i,į,ʞ,l,м,и,o,q,p,я,ƨ,т,υ,v,w,x,γ,z,0,9,8,7,6,5,4,3,2,1,.,_",
			"4,8,C,D,3,F,9,H,!,J,K,1,M,N,0,P,Q,R,5,7,U,V,W,X,Y,2,4,8,C,D,3,F,9,H,!,J,K,1,M,N,0,P,Q,R,5,7,U,V,W,X,Y,2,0,9,8,7,6,5,4,3,2,1,.,_",
			"Λ,M,X,ʎ,Z,ɐ,q,ɔ,p,ǝ,ɟ,ƃ,ɥ,ı,ɾ,ʞ,l,ա,u,o,d,b,ɹ,s,ʇ,n,ʌ,ʍ,x,ʎ,z,Λ,M,X,ʎ,Z,ɐ,q,ɔ,p,ǝ,ɟ,ƃ,ɥ,ı,ɾ,ʞ,l,ա,u,o,d,b,ɹ,s,ʇ,n,ʌ,ʍ,x,ʎ,z,0,9,8,7,6,5,4,3,2,1,.,‾",
			"A̴,̴B̴,̴C̴,̴D̴,̴E̴,̴F̴,̴G̴,̴H̴,̴I̴,̴J̴,̴K̴,̴L̴,̴M̴,̴N̴,̴O̴,̴P̴,̴Q̴,̴R̴,̴S̴,̴T̴,̴U̴,̴V̴,̴W̴,̴X̴,̴Y̴,̴Z̴,̴a̴,̴b̴,̴c̴,̴d̴,̴e̴,̴f̴,̴g̴,̴h̴,̴i̴,̴j̴,̴k̴,̴l̴,̴m̴,̴n̴,̴o̴,̴p̴,̴q̴,̴r̴,̴s̴,̴t̴,̴u̴,̴v̴,̴w̴,̴x̴,̴y̴,̴z̴,̴0̴,̴9̴,̴8̴,̴7̴,̴6̴,̴5̴,̴4̴,̴3̴,̴2̴,̴1̴,̴.̴,̴_̴",
			"A̱,̱Ḇ,̱C̱,̱Ḏ,̱E̱,̱F̱,̱G̱,̱H̱,̱I̱,̱J̱,̱Ḵ,̱Ḻ,̱M̱,̱Ṉ,̱O̱,̱P̱,̱Q̱,̱Ṟ,̱S̱,̱Ṯ,̱U̱,̱V̱,̱W̱,̱X̱,̱Y̱,̱Ẕ,̱a̱,̱ḇ,̱c̱,̱ḏ,̱e̱,̱f̱,̱g̱,̱ẖ,̱i̱,̱j̱,̱ḵ,̱ḻ,̱m̱,̱ṉ,̱o̱,̱p̱,̱q̱,̱ṟ,̱s̱,̱ṯ,̱u̱,̱v̱,̱w̱,̱x̱,̱y̱,̱ẕ,̱0̱,̱9̱,̱8̱,̱7̱,̱6̱,̱5̱,̱4̱,̱3̱,̱2̱,̱1̱,̱.̱,̱_̱",
			"A̲,̲B̲,̲C̲,̲D̲,̲E̲,̲F̲,̲G̲,̲H̲,̲I̲,̲J̲,̲K̲,̲L̲,̲M̲,̲N̲,̲O̲,̲P̲,̲Q̲,̲R̲,̲S̲,̲T̲,̲U̲,̲V̲,̲W̲,̲X̲,̲Y̲,̲Z̲,̲a̲,̲b̲,̲c̲,̲d̲,̲e̲,̲f̲,̲g̲,̲h̲,̲i̲,̲j̲,̲k̲,̲l̲,̲m̲,̲n̲,̲o̲,̲p̲,̲q̲,̲r̲,̲s̲,̲t̲,̲u̲,̲v̲,̲w̲,̲x̲,̲y̲,̲z̲,̲0̲,̲9̲,̲8̲,̲7̲,̲6̲,̲5̲,̲4̲,̲3̲,̲2̲,̲1̲,̲.̲,̲_̲",
			"Ā,̄B̄,̄C̄,̄D̄,̄Ē,̄F̄,̄Ḡ,̄H̄,̄Ī,̄J̄,̄K̄,̄L̄,̄M̄,̄N̄,̄Ō,̄P̄,̄Q̄,̄R̄,̄S̄,̄T̄,̄Ū,̄V̄,̄W̄,̄X̄,̄Ȳ,̄Z̄,̄ā,̄b̄,̄c̄,̄d̄,̄ē,̄f̄,̄ḡ,̄h̄,̄ī,̄j̄,̄k̄,̄l̄,̄m̄,̄n̄,̄ō,̄p̄,̄q̄,̄r̄,̄s̄,̄t̄,̄ū,̄v̄,̄w̄,̄x̄,̄ȳ,̄z̄,̄0̄,̄9̄,̄8̄,̄7̄,̄6̄,̄5̄,̄4̄,̄3̄,̄2̄,̄1̄,̄.̄,̄_̄",
			"A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,0,9,8,7,6,5,4,3,2,1,.,_",
			"a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,0,9,8,7,6,5,4,3,2,1,.,_",
		}
		local result = {}
		i=0
		for k=1,#fonts do
			i=i+1
			local tar_font = fonts[i]:split(",")
			local text = TextToBeauty
			local text = text:gsub("A",tar_font[1])
			local text = text:gsub("B",tar_font[2])
			local text = text:gsub("C",tar_font[3])
			local text = text:gsub("D",tar_font[4])
			local text = text:gsub("E",tar_font[5])
			local text = text:gsub("F",tar_font[6])
			local text = text:gsub("G",tar_font[7])
			local text = text:gsub("H",tar_font[8])
			local text = text:gsub("I",tar_font[9])
			local text = text:gsub("J",tar_font[10])
			local text = text:gsub("K",tar_font[11])
			local text = text:gsub("L",tar_font[12])
			local text = text:gsub("M",tar_font[13])
			local text = text:gsub("N",tar_font[14])
			local text = text:gsub("O",tar_font[15])
			local text = text:gsub("P",tar_font[16])
			local text = text:gsub("Q",tar_font[17])
			local text = text:gsub("R",tar_font[18])
			local text = text:gsub("S",tar_font[19])
			local text = text:gsub("T",tar_font[20])
			local text = text:gsub("U",tar_font[21])
			local text = text:gsub("V",tar_font[22])
			local text = text:gsub("W",tar_font[23])
			local text = text:gsub("X",tar_font[24])
			local text = text:gsub("Y",tar_font[25])
			local text = text:gsub("Z",tar_font[26])
			local text = text:gsub("a",tar_font[27])
			local text = text:gsub("b",tar_font[28])
			local text = text:gsub("c",tar_font[29])
			local text = text:gsub("d",tar_font[30])
			local text = text:gsub("e",tar_font[31])
			local text = text:gsub("f",tar_font[32])
			local text = text:gsub("g",tar_font[33])
			local text = text:gsub("h",tar_font[34])
			local text = text:gsub("i",tar_font[35])
			local text = text:gsub("j",tar_font[36])
			local text = text:gsub("k",tar_font[37])
			local text = text:gsub("l",tar_font[38])
			local text = text:gsub("m",tar_font[39])
			local text = text:gsub("n",tar_font[40])
			local text = text:gsub("o",tar_font[41])
			local text = text:gsub("p",tar_font[42])
			local text = text:gsub("q",tar_font[43])
			local text = text:gsub("r",tar_font[44])
			local text = text:gsub("s",tar_font[45])
			local text = text:gsub("t",tar_font[46])
			local text = text:gsub("u",tar_font[47])
			local text = text:gsub("v",tar_font[48])
			local text = text:gsub("w",tar_font[49])
			local text = text:gsub("x",tar_font[50])
			local text = text:gsub("y",tar_font[51])
			local text = text:gsub("z",tar_font[52])
			local text = text:gsub("0",tar_font[53])
			local text = text:gsub("9",tar_font[54])
			local text = text:gsub("8",tar_font[55])
			local text = text:gsub("7",tar_font[56])
			local text = text:gsub("6",tar_font[57])
			local text = text:gsub("5",tar_font[58])
			local text = text:gsub("4",tar_font[59])
			local text = text:gsub("3",tar_font[60])
			local text = text:gsub("2",tar_font[61])
			local text = text:gsub("1",tar_font[62])
			table.insert(result, text)
		end
		
		local result_text = "〰کلمه ی اولیه: "..TextToBeauty.."\nطراحی با "..tostring(#fonts).." فونت:\n___________________\n"
		for v=1,#result do
			redis:hset("enigma:cli:beauty_text:"..msg.chat_id_, v, result[v])
			result_text = result_text..v.."- "..result[v].."\n"
		end
		result_text = result_text.."___________________\n=> برای دریافت متن مورد نظر ، ابتدا دستور دریافت متن را تایپ کرده و سپس با قید یک فاصله(Space) شماره آن را بنویسید.\nمثال :\nدریافت متن "..(#result - 5)
		sendText(msg.chat_id_, result_text, msg.id_)
	end
	
	if Cmd:match("^[/!#]([Gg][Ee][Tt] [Tt][Ee][Xx][Tt]) (%d+)$") or Cmd:match("^(دریافت متن) (%d+)$") then
		MatchesEN = {Cmd:match("^[/!#]([Gg][Ee][Tt] [Tt][Ee][Xx][Tt]) (%d+)$")}; MatchesFA = {Cmd:match("^(دریافت متن) (%d+)$")}
		TextNum = MatchesEN[2] or MatchesFA[2]
		Num = tonumber(TextNum)
		Hash = "enigma:cli:beauty_text:"..msg.chat_id_
		if not redis:hget("enigma:cli:beauty_text:"..msg.chat_id_, Num) then
			sendText(msg.chat_id_, "متن زیبا سازی شده با شماره مورد نظر شما یعنی "..Num.." بافت نشد!", msg.id_)
			return
		end
		Word = redis:hget("enigma:cli:beauty_text:"..msg.chat_id_, Num)
		sendText(msg.chat_id_, Word)
	end
	---------------------------------------------
	
end -- END FUN.LUA

--[[

	Powered By :
		 _____       _  ____
		| ____|_ __ (_)/ ___|_ __ ___   __ _ TM
		|  _| | '_ \| | |  _| '_ ` _ \ / _` |
		| |___| | | | | |_| | | | | | | (_| |
		|_____|_| |_|_|\____|_| |_| |_|\__,_|
	
	****************************
	*  >> By : Reza Mehdipour  *
	*  > Channel : @EnigmaTM   *
	****************************
	
]]

function editProcessPlugin(msg) --> EDIT_PROCESS.LUA !
	
	local function isLink(text) --> Finding Link in a Message Function
		if text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Mm][Ee]/")
		or text:match("[Tt][Ll][Gg][Rr][Mm].[Mm][Ee]/")
		or text:match("[Tt].[Mm][Ee]/")
		or text:match("[Hh][Tt][Tt][Pp][Ss]://") 
		or text:match("[Hh][Tt][Tt][Pp]://")
		or text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Oo][Rr][Gg]")
		or text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Dd][Oo][Gg]")
		or text:match("[Ww][Ww][Ww].")
		or text:match(".[Cc][Oo][Mm]")
		or text:match(".[Ii][Rr]")
		or text:match(".[Oo][Rr][Gg]")
		or text:match(".[Nn][Ee][Tt]") then
			return true
		end
	 return false
	end
	
	local function isAbuse(text) --> Finding Abuse in a Message Function
		if text:match("کیر")
		or text:match("کون")
		or text:match("فاک") 
		or text:lower():match("fuck")
		or text:lower():match("pussy")
		or text:lower():match("sex")
		or text:match("عوضی")
		or text:match("آشغال")
		or text:match("جنده")
		or text:match("سیکتیر")
		or text:match("سکس")
		or text:lower():match("siktir")
		or text:match("دیوث") then
			return true
		end
	  return false
	end
	
	Data = loadJson(Config.ModFile)
	if not Data[tostring(msg.chat.id)] then
		return
	end
	
	if msg.edit then
		if Data[tostring(msg.chat.id)]['settings'] then
		
			-- Lock Link [On Edit]
			if Data[tostring(msg.chat.id)]['settings']['lock_link'] then
				if Data[tostring(msg.chat.id)]['settings']['lock_link'] == "yes" then
					if isLink(msg.new_content) and not isMod(msg.chat.id, msg.from.id) then
						deleteMessage(msg.chat.id, msg.id)
					end
				end
			end
			----------------------
			
			-- Lock Abuse [On Edit]
			if Data[tostring(msg.chat.id)]['settings']['lock_abuse'] then
				if Data[tostring(msg.chat.id)]['settings']['lock_abuse'] == "yes" then
					if isAbuse(msg.new_content) and not isMod(msg.chat.id, msg.from.id) then
						deleteMessage(msg.chat.id, msg.id)
					end
				end
			end
			----------------------
			
			-- Lock Edit
			if Data[tostring(msg.chat.id)]['settings']['lock_edit'] then
				if Data[tostring(msg.chat.id)]['settings']['lock_edit'] == "yes" then
					if not isMod(msg.chat.id, msg.from.id) then
						deleteMessage(msg.chat.id, msg.id)
					end
				end
			end
			-------------
			
			-- Lock English [On Edit]
			if Data[tostring(msg.chat.id)]['settings']['lock_english'] then
				if Data[tostring(msg.chat.id)]['settings']['lock_english'] == "yes" then
					if (msg.new_content:match("[A-Z]") or msg.new_content:match("[a-z]")) then
						if not isMod(msg.chat.id, msg.from.id) then
							deleteMessage(msg.chat.id, msg.id)
						end
					end
				end
			end
			------------------------
			
			-- Lock Persian/Arabic [On Edit]
			if Data[tostring(msg.chat.id)]['settings']['lock_arabic'] then
				if Data[tostring(msg.chat.id)]['settings']['lock_arabic'] == "yes" then
					if msg.new_content:match("[\216-\219][\128-\191]") then
						if not isMod(msg.chat.id, msg.from.id) then
							deleteMessage(msg.chat.id, msg.id)
						end
					end
				end
			end
			-------------------------------
			
			-- Lock Username (@)
			if Data[tostring(msg.chat.id)]['settings']['lock_username'] then
				if Data[tostring(msg.chat.id)]['settings']['lock_username'] == "yes" then
					if msg.new_content:match("@[%a%d]") then
						if not isMod(msg.chat.id, msg.from.id) then
							deleteMessage(msg.chat.id, msg.id)
						end
					end
				end
			end
			--------------------
			
			-- Lock Tag (#)
			if Data[tostring(msg.chat.id)]['settings']['lock_tag'] then
				if Data[tostring(msg.chat.id)]['settings']['lock_tag'] == "yes" then
					if msg.new_content:match("#") then
						if not isMod(msg.chat.id, msg.from.id) then
							deleteMessage(msg.chat.id, msg.id)
						end
					end
				end
			end
			--------------
			
			-- Show Edit
			if Data[tostring(msg.chat.id)]['settings']['show_edit'] then
				if Data[tostring(msg.chat.id)]['settings']['show_edit'] == "yes" then
					if not isApiBot(msg.from.id) then
						if msg.old_content then
							redis:hset(ShowEditHash, msg.chat.id..":"..msg.id, msg.new_content)
							Text = "» این پیام ویرایش(Edit) شد !"
							.."\nمتن پیام قبل از ویرایش :"
							.."\n"..msg.old_content
							sendText(msg.chat.id, Text, msg.id)
						else
							redis:hset(ShowEditHash, msg.chat.id..":"..msg.id, msg.new_content)
							Text = "» این پیام ویرایش(*Edit*) شد !"
							sendText(msg.chat.id, Text, msg.id, 'md')
						end
					end
				end
			end
			------------
			
		end -- end Data[tostring(msg.chat.id)]['settings']
	end -- end msg.edit
end -- End EDIT_PROCESS.LUA !
-------------------------------------

--[[

	Powered By :
		 _____       _  ____
		| ____|_ __ (_)/ ___|_ __ ___   __ _ TM
		|  _| | '_ \| | |  _| '_ ` _ \ / _` |
		| |___| | | | | |_| | | | | | | (_| |
		|_____|_| |_|_|\____|_| |_| |_|\__,_|
	
	****************************
	*  >> By : Reza Mehdipour  *
	*  > Channel : @EnigmaTM   *
	****************************
	
]]

function tdcli_update_callback(data)
	
	if data.ID == "UpdateNewMessage" then --> Normal Message Proccess
		msg = data.message_
		
		-- Message Valid ...
		if msg.sender_user_id_ == BotId then
			print(Color.Red..'    ERROR => This Message is From Us.'..Color.Reset)
			return
		end
		if msg.sender_user_id_ == 777000 then
			print(Color.Red.."   ERROR => This Message if from Telegram-General-User. Bot will send it To GeneralSudo"..Color.Reset)
			forwardMessage(GeneralSudoUserId, msg.chat_id_, msg.id_)
			return
		end
		if msg.date_ < (os.time() - 120) then
			print(Color.Red.."   ERROR => This Message is *Old*. Bot ignores that!"..Color.Reset)
			return
		end
		openChat(msg.chat_id_)
		if redis:get(MarkreadStatusHash) then -- View Messages if MARKREAD was On !
			viewMessage(msg.chat_id_, msg.id_)
		end
		--------------------
		
		if data.message_.content_.ID == "MessagePhoto" or data.message_.content_.ID == "MessageVideo" or data.message_.content_.ID == "MessageAnimation"
		or data.message_.content_.ID == "MessageVoice" or data.message_.content_.ID == "MessageAudio" or data.message_.content_.ID == "MessageSticker"
		or data.message_.content_.ID == "MessageContact" or data.message_.content_.ID == "MessageDocument" or data.message_.content_.ID == "MessageLocation"
		or data.message_.content_.ID == "MessageGame" or (data.message_.reply_markup_ and data.message_.reply_markup_.ID == "ReplyMarkupInlineKeyboard") then
			msg.media_ = true
		end
		if data.message_.content_.ID == "MessagePinMessage" or data.message_.content_.ID == "MessageChatJoinByLink"
		or data.message_.content_.ID == "MessageChatDeleteMember" or data.message_.content_.ID == "MessageChatAddMembers" then
			msg.service_ = true
		end
		if (not msg.reply_to_message_id_) or (msg.reply_to_message_id_ == 0) then
			msg.reply_to_message_id_ = false
		end
		msg.chat_type_ = getChatType(msg.chat_id_)
		botModPlugin(msg) --> CALLING BOT_MOD.LUA PLUGIN !
		helpPlugin(msg) --> CALLING HELP.LUA PLUGIN !
		if msg.chat_type_ == "supergroup" then
			antiFloodPlugin(msg) --> CALLING SEC.LUA PLUGIN !
			secPlugin(msg, data) --> CALLING SEC.LUA PLUGIN !
			chargePlugin(msg) --> CALLING CHARGE.LUA PLUGIN !
			if msg.content_.text_ then
				locksPlugin(msg) --> CALLING LOCKS.LUA PLUGIN !
				chatModPlugin(msg) --> CALLING CHAT_MOD.LUA PLUGIN !
				banPlugin(msg) --> CALLING BAN.LUA PLUGIN !
				rmsgPlugin(msg) --> CALLING RMSG.LUA PLUGIN !
				funPlugin(msg) --> CALLING FUN.LUA PLUGIN !
			end
		end
		
	elseif data.ID == "UpdateMessageContent" then --> Edit Message Proccess
		if messageValid(data) then
			getMessage(data.chat_id_, data.message_id_,
				function (Ex, Res)
					local data = Ex.data
					data.user_info = {}
					data.user_info.user_id = Res.sender_user_id_
					data.message_info = {}
					data.message_info.date = Res.date_
					data.message_info.edit_date = Res.edit_date_
					data.message_info.new_content = data.new_content_.text_ or data.new_content_.caption_
					msg = makeSimpleDataToMsg(data)
					if tonumber(Res.edit_date_) then
						if tonumber(msg.edit_date) < (os.time() - 120) then
							print(Color.Red.."    ERROR => This Message is *Old*, Bot Will ignores That !"..Color.Reset)
							return
						end
					end
					if msg.from.id == BotId then
						print(Color.Red.."    ERROR => This Message is From Us. !"..Color.Reset)
						return
					end
					if msg.chat.type == "supergroup" then
						editProcessPlugin(msg) --> CALLING EDIT_PROCESS.LUA PLUGIN !
					end
				end
			, {data = data})
		end
	elseif data.ID == "UpdateOption" and data.name_ == "my_id" then
		tdcli_function({ID = "GetChats",offset_order_ = "9223372036854775807",offset_chat_id_ = 0,limit_ = 20}, dl_cb, nil)
	end
end