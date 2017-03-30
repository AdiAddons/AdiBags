
--[[

globals.lua (FindGlobals), a useful script to find global variable access in
.lua files, placed in the public domain by Mikk in 2009.

HOW TO INVOKE:
  luac -l MyFile.lua | lua globals.lua MyFile.lua
or:
  c:\path\to\luac.exe -l MyFile.lua | c:\path\to\lua.exe c:\path\to\globals.lua MyFile.lua

Directives in the file:

-- GLOBALS: SomeGlobal, SomeOtherGlobal
  The script will never complain about these. There may be multiple lines of these anywhere in the file, taking effect globally (for now). There is no way to un-GLOBAL an already declared global.

-- SETGLOBALFILE [ON/OFF]
  Enable/disable SETGLOBAL checks in the global scope
  Default: ON

-- SETGLOBALFUNC [ON/OFF]
  Enable/disable SETGLOBAL checks in functions. This setting affects the whole file (for now)
  Default: ON

-- GETGLOBALFILE [ON/OFF]
  Default: OFF

-- GETGLOBALFUNC [ON/OFF]
  Default: ON

--]]

local strmatch=string.match
local strgmatch=string.gmatch
local print=print
local gsub = string.gsub
local tonumber=tonumber
local stdin=io.input()

local source=assert(io.open(arg[1]))


-- First we parse the source file

local funcNames={}
local GLOBALS={}
local SETGLOBALfile = true
local SETGLOBALfunc = true
local GETGLOBALfile = false
local GETGLOBALfunc = true

local n=0

while true do
	local lin = source:read()
	if not lin then break end
	n=n+1

	-- Lamely try to find all function headers and remember the line they were on. Yes, you can fool this. You can also shoot yourself in the foot. Either way it doesn't matter hugely, it's just to prettify the output.

	local func = strmatch(lin, "%f[%a_][%a0-9_.:]+%s*=%s*function%s*%([^)]*") or  -- blah=function(...)
		strmatch(lin, "%f[%a_]function%s*%([^)]*") or -- function(...)
		strmatch(lin, "%f[%a_]function%s+[%a0-9_.:]+%s*%([^)]*")  -- function blah(...)

	if func then
		func=func..")"
		funcNames[n]=func
	end

	if strmatch(lin, "^%s*%-%-") then
		local args = strmatch(lin, "^%s*%-%-%s*GLOBALS:%s*(.*)")
		if args then
			for name in strgmatch(args, "[%a0-9_]+") do
				GLOBALS[name]=true
			end
		end

		local args = strmatch(lin, "^%s*%-%-%s*SETGLOBALFILE%s+(%u+)")
		if args=="ON" then
			SETGLOBALfile=true
		elseif args=="OFF" then
			SETGLOBALfile=false
		end

		local args = strmatch(lin, "^%s*%-%-%s*GETGLOBALFILE%s+(%u+)")
		if args=="ON" then
			GETGLOBALfile=true
		elseif args=="OFF" then
			GETGLOBALfile=false
		end

		local args = strmatch(lin, "^%s*%-%-%s*SETGLOBALFUNC%s+(%u+)")
		if args=="ON" then
			SETGLOBALfunc=true
		elseif args=="OFF" then
			SETGLOBALfunc=false
		end

		local args = strmatch(lin, "^%s*%-%-%s*GETGLOBALFUNC%s+(%u+)")
		if args=="ON" then
			GETGLOBALfunc=true
		elseif args=="OFF" then
			GETGLOBALfunc=false
		end
	end
end

-- Helper function that prints a line along with which function it is in.

local curfunc
local lastfuncprinted
local found = 0

local function printone(lin)
	local globalName = strmatch(lin, "\t; (.+)%s*")
	if globalName and GLOBALS[globalName] then
		return
	end

	if curfunc~=lastfuncprinted then
		local from,to = strmatch(curfunc, "function <[^:]*:(%d+),(%d+)")
		from=tonumber(from)
		if from and funcNames[from] then
			print(funcNames[from],strmatch(curfunc, "<.*"))
		else
			print(curfunc)
		end
		lastfuncprinted = curfunc
	end
	lin=gsub(lin, "%d+\t(%[%d+%])", "%1")	-- "23 [234]"  -> "[234]"   (strip the byte offset, we're not interested in it)
	print(lin)
	found = 1
end


-- Loop the compiled output, looking for GETGLOBAL, SETGLOBAL, etc..

local nSource=0
local funcScope = false

while true do
	local lin = stdin:read()
	if not lin then break end

	if strmatch(lin,"^main <") then
		curfunc=lin
		funcScope = false
	elseif strmatch(lin,"^function <") then
		curfunc=lin
		funcScope = true
	elseif strmatch(lin,"SETGLOBAL\t") then
		if funcScope and SETGLOBALfunc then
			printone(lin)
		elseif not funcScope and SETGLOBALfile then
			printone(lin)
		end
	elseif strmatch(lin,"GETGLOBAL\t") then
		if funcScope and GETGLOBALfunc then
			printone(lin)
		elseif not funcScope and GETGLOBALfile then
			printone(lin)
		end
	end
end

os.exit(found)
