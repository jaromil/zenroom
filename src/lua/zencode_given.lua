-- This file is part of Zenroom (https://zenroom.dyne.org)
--
-- Copyright (C) 2018-2019 Dyne.org foundation
-- designed, written and maintained by Denis Roio <jaromil@dyne.org>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

-- TODO: use strict table
-- https://stevedonovan.github.io/Penlight/api/libraries/pl.strict.html

-- the main security concern in this Zencode module is that no data
-- passes without validation from IN to ACK or from inline input.

-- GIVEN
local function gc()
   TMP = { }
   collectgarbage'collect'
end

---
-- Pick a generic data structure from the <b>IN</b> memory
-- space. Looks for named data on the first and second level and makes
-- it ready in TMP for @{validate} or @{ack}.
--
-- @function pick(name, data, encoding)
-- @param what string descriptor of the data object
-- @param conv[opt] optional encoding spec (default CONF.input.encoding)
-- @return true or false
local function pick(what, conv)
   local guess
   local got
   got = IN.KEYS[what] or IN[what]
   ZEN.assert(got, "Cannot find '"..what.."' anywhere")
   -- if not conv and ZEN.schemas[what] then conv = what end
   TMP.guess = guess_conversion(luatype(got), conv or what)
   ZEN.assert(TMP.guess, "Cannot guess any conversion for: "..
				  luatype(got).." "..(conv or "(nil)"))
   TMP.root = nil
   TMP.data = operate_conversion(got, TMP.guess)
   TMP.schema = TMP.guess.name
   assert(ZEN.OK)
   if DEBUG > 1 then ZEN:ftrace("pick found "..what) end
end

---
-- Pick a data structure named 'what' contained under a 'section' key
-- of the at the root of the <b>IN</b> memory space. Looks for named
-- data at the first and second level underneath IN[section] and moves
-- it to TMP[what][section], ready for @{validate} or @{ack}. If
-- TMP[what] exists already, every new entry is added as a key/value
--
-- @function pickin(section, name)
-- @param section string descriptor of the section containing the data
-- @param what string descriptor of the data object
-- @param conv string explicit conversion or schema to use
-- @param fail bool bail out or continue on error
-- @return true or false
local function pickin(section, what, conv, fail)
   ZEN.assert(section, "No section specified")
   local root -- section
   local got  -- what
   local bail -- fail
   root = IN.KEYS[section]
   if root then
	  got = root[what]
	  if got then goto found end
   end
   root = IN[section]
   if root then
	  got = root [what]
	  if got then goto found end
   end
   if got then goto found end -- success condition
   if bail then
	  ZEN.assert(got, "Cannot find '"..what.."' inside '"..section.."'")
   else return false end
   -- TODO: check all corner cases to make sure TMP[what] is a k/v map
   ::found::
   -- conv = conv or what
   root = nil
   -- if not conv and ZEN.schemas[what] then conv = what end
   -- if no encoding provided then conversion is same as name (schemas etc.)
   TMP.guess = guess_conversion(luatype(got), conv or what )
   TMP.root = section
   TMP.data = operate_conversion(got, TMP.guess)
   TMP.schema = TMP.guess.name
   assert(ZEN.OK)
   if DEBUG > 1 then ZEN:ftrace("pickin found "..what.." in "..section) end
end

local function ack_table(key,val)
   ZEN.assert(type(key) == 'string',"ZEN:table_add arg #1 is not a string")
   ZEN.assert(type(val) == 'string',"ZEN:table_add arg #2 is not a string")
   if not ACK[key] then ACK[key] = { } end
   ACK[key][val] = TMP.data
end


---
-- Final step inside the <b>Given</b> block towards the <b>When</b>:
-- pass on a data structure into the ACK memory space, ready for
-- processing.  It requires the data to be present in TMP[name] and
-- typically follows a @{pick}. In some restricted cases it is used
-- inside a <b>When</b> block following the inline insertion of data
-- from zencode.
--
-- @function ack(name)
-- @param name string key of the data object in TMP[name]
local function ack(name)
   ZEN.assert(TMP.data, "No valid object found: ".. name)
   -- CODEC[what] = CODEC[what] or {
   --    name = guess.name,
   --    istable = guess.istable,
   --    isschema = guess.isschema }
   assert(ZEN.OK)
   local t = type(ACK[name])
   if not ACK[name] then -- assign in ACK the single object
	  ACK[name] = TMP.data
	  goto done
   end
   -- ACK[name] already holds an object
   -- not a table?
   if t ~= 'table' then -- convert single object to array
	  ACK[name] = { ACK[name] }
	  table.insert(ACK[name], TMP.data)
	  goto done
   end
   -- it is a table already
   if isarray(ACK[name]) then -- plain array
	  table.insert(ACK[name], TMP.data)
	  goto done
   else -- associative map
	  table.insert(ACK[name], TMP.data) -- TODO: associative map insertion
	  goto done
   end
   ::done::
   assert(ZEN.OK)
end

Given("nothing", function()
		 ZEN.assert(not DATA and not KEYS, "Undesired data passed as input")
end)

-- maybe TODO: Given all valid data
-- convert and import data only when is known by schema and passes validation
-- ignore all other data structures that are not known by schema or don't pass validation

Given("am ''", function(name) Iam(name) end)

-- variable names:
-- s = schema of variable (or encoding)
-- n = name of variable
-- t = table containing the variable

-- TODO: I have a '' as ''
Given("have a ''", function(n)
		 pick(n)
		 ack(n)
		 gc()
end)

Given("have a '' in ''", function(s, t)
		 pickin(t, s)
		 ack(s) -- save it in ACK.obj
		 gc()
end)

-- public keys for keyring arrays (scenario ecdh)
-- supports bot ways in from given
-- public_key : { name : value }
-- or
-- name : { public_key : value }
Given("have a '' from ''", function(s, t)
		 -- if not pickin(t, s, nil, false) then
		 -- 	pickin(s, t)
		 -- end
		 pickin(t, s, nil, false)
		 ack_table(s, t)
		 gc()
end)

Given("have a '' named ''", function(s, n)
		 -- ZEN.assert(encoder, "Invalid input encoding for '"..n.."': "..s)
		 pick(n, s)
		 ack(n)
		 gc()
end)

Given("have a '' named '' in ''", function(s,n,t)
		 pickin(t, n, s)
		 ack(n) -- save it in ACK.name
		 gc()
end)

Given("have my ''", function(n)
		 ZEN.assert(WHO, "No identity specified, use: Given I am ...")
		 pickin(WHO, n)
		 ack(n)
		 gc()
end)
Given("the '' is valid", function(n)
		 pick(n)
		 gc()
end)
Given("my '' is valid", function(n)
		 pickin(WHO, n)
		 gc()
end)
