-- Holds temperature and wind
--[[-------------------------------------------------------------------------
Temperature is not universal. A few contries cling on to fahrenheit, 
so we need another function to display the temperature correctly.

StormFox runs on celsius, but can convert the temperature to whatever you wish.

Clients have to use these functions:
	StormFox2.Temperature.GetDisplay() 			-- Returns the temperature in what their setting is set to.
	StormFox2.Temperature.GetDisplaySymbol() 	-- Returns the temperature symbol for their setting.
	StormFox2.Temperature.GetDisplayDefault() 	-- Returns the default temperature setting for their country.
	StormFox2.Temperature.GetDisplayType() 		-- Returns the temperature setting clients have set to.

Fun facts:
	At -90C, we need specialized air or our brain "forgets" to breathe.
	You'll be unconscious in an hour in 10C water. Dead in 3.
	At -180C oxygen will liquidfy.
	Coldest recorded temp on Earth is -90C

---------------------------------------------------------------------------]]
StormFox2.Temperature = {}
local convert_from,convert_to = {},{}
local p1,p2,p3,p4,p5 = 3 / 2, 33 / 100, 4 / 5, 21 / 40,240 / 54
	convert_to["fahrenheit"] = function(nC) return nC * 1.8 + 32 end
	convert_to["kelvin"] = function(nC) return nC + 273.15  end
	convert_to["rankine"] = function(nC) return (nC + 273.15) * 1.8 end
	convert_to["delisle"] = function(nC) return (100 - nC) * p1 end
	convert_to["newton"] = function(nC) return nC * p2 end
	convert_to["réaumur"] = function(nC) return nC * p3 end
	convert_to["rømer"] = function(nC) return nC * p4 + 7.5 end
	convert_to["wedgwood"] = function(nC) return (nC - 580.8) * p5 end
	convert_to["gas_mark"] = function(nC)
		if nC >= 135 then
			return 1 + (nC - 135) / 13.9
		else
			return 1 / ((135 - nC) / 13.9 * 2)
		end
	end
	convert_to["banana"] = function(nC) -- 380 kJ of energy in an average size banana. Takes about 344,49kJ to heat up an avage room by 10c. 1 banana = 1.1c
		return 10 * (nC - 10) / 11
	end
local p1,p2,p3,p4,p5,p6 = 5 / 9, 2 / 3, 100 / 33, 5 / 4, 40 / 21,54 / 240
	convert_from["fahrenheit"] = function(nF) return (nF - 32) / 1.8 end
	convert_from["kelvin"] = function(nK) return nK - 273.15 end
	convert_from["rankine"] = function(nR) return (nR - 491.67) * p1 end
	convert_from["delisle"] = function(nD) return 100 - nD * p2 end
	convert_from["newton"] = function(nN) return nN * p3 end
	convert_from["réaumur"] = function(nR) return nR * p4 end
	convert_from["rømer"] = function(nR) return (nR - 7.5) * p5 end
	convert_from["wedgwood"] = function(nW) return (nW * p6) + 580.8 end
	convert_from["gas_mark"] = function(nG)
		if nG >= 1 then
			return 0.1 * (139 * nG + 1211)
		else
			return 135 - 6.95 / nG
		end
	end
	convert_from["banana"] = function(nB)
		return 1.1 * nB + 10
	end
local symbol = {
	["celsius"] = "°C",
	["fahrenheit"] = "°F",
	["rankine"] = "°R",
	["delisle"] = "°D",
	["newton"] = "°N",
	["réaumur"] = "°Ré",
	["rømer"] = "°Rø",
	["wedgwood"] = "°W",
	["gas_mark"] = "°G",
	["banana"] = "°B",
	["kelvin"] = "K"
}
--[[<Shared>------------------------------------------------------------------
Returns the current temperature. Valid temperatures:
	- celsius : default
	- fahrenheit
	- kelvin
	- rankine
	- delisle
	- newton
	- réaumur
	- rømer
---------------------------------------------------------------------------]]
local tempOverwrite

---Returns the current temperature. sType can be "celsius" (default), "fahrenheit", "kelvin" .. ect
---@param sType? string
---@return Color
---@shared
function StormFox2.Temperature.Get(sType)
	local n = tempOverwrite or StormFox2.Data.Get( "Temp", 20 )
	if not sType or sType == "celsius" then return n end
	if not convert_to[sType] then
		StormFox2.Warning("Invalid temperature type [" .. tostring(sType) .. "].", true)
	end
	return convert_to[sType](n)
end
--[[<Shared>-----------------------------------------------------------------
Returns the list of valid temperatures.
	- celsius : default
	- fahrenheit
	- kelvin
	- rankine
	- delisle
	- newton
	- réaumur
	- rømer
---------------------------------------------------------------------------]]

---Returns all temperature units supported.
---@return table
---@shared
function StormFox2.Temperature.GetTypes()
	local t = table.GetKeys(convert_to)
	table.insert(t,"celsius")
	return t
end

--[[<Shared>-----------------------------------------------------------------
Converts temperature between two types
Valid temperatures:
	- celsius : default
	- fahrenheit
	- kelvin
	- rankine
	- delisle
	- newton
	- réaumur
	- rømer
	- wedgwood
---------------------------------------------------------------------------]]

---Converts temperature from one unit to another. E.g StormFox2.Temperature.Convert("celsius","fahrenheit",0) -> 32.
---@param sTypeFrom string
---@param sTypeTo string
---@param nNumber number
---@return number
---@shared
function StormFox2.Temperature.Convert(sTypeFrom,sTypeTo,nNumber)
	if sTypeFrom and sTypeFrom ~= "celsius" then
		if not convert_from[sTypeFrom] then
			error("Invalid temperature type [" .. sTypeFrom .. "].")
		end
		nNumber = convert_from[sTypeFrom](nNumber)
	end
	if sTypeTo and sTypeTo ~= "celsius" then
		if not convert_to[sTypeTo] then
			error("Invalid temperature type [" .. sTypeTo .. "].")
		end
		nNumber = convert_to[sTypeTo](nNumber)
	end
	return nNumber
end

if SERVER then
	---Sets the temperature in ceilsius. Second argument is the lerp time in seconds (default: 2).
	---@param nCelsius number
	---@param nLerpTime? number
	---@server
	function StormFox2.Temperature.Set(nCelsius,nLerpTime)
		if nCelsius < -273.15 then --  ( In space, there are 270.45 C )
			nCelsius = -273.15
		end
		StormFox2.Network.Set("Temp",nCelsius,nLerpTime or 2 * StormFox2.Time.GetSpeed_RAW())
	end
else
	local country = system.GetCountry() or "UK"
	local fahrenheit_countries = {"BS","PW","BZ","KY","FM","MH","US","PR","VI","GU"}
	--[[Bahamas, Palau, Belize, the Cayman Islands, the Federated States of Micronesia, the Marshall Islands, 
	and the United States and its territories such as Puerto Rico, the U.S. Virgin Islands, and Guam.
	]]
	local default_temp = table.HasValue(fahrenheit_countries, country) and "fahrenheit" or "celsius"
	local temp_type = default_temp
	--[[<Client>------------------------------------------------------------------
	Sets the display temperature. Returns true if given a valid temperature-type.
	Valid temperatures:
		- celsius : default
		- fahrenheit
		- kelvin
		- rankine
		- delisle
		- newton
		- réaumur
		- rømer
	---------------------------------------------------------------------------]]

	---Sets the display temperature.
	---@param sType string
	---@return boolean success
	---@client
	function StormFox2.Temperature.SetDisplayType(sType)
		StormFox2.Setting.Set("display_temperature",convert_to[sType] and sType or "celsius")
		if convert_to[sType] then
			return true
		end
		return sType == "celsius"
	end

	---Returns the current display temperature type.
	---@return string
	---@client
	function StormFox2.Temperature.GetDisplayType()
		return temp_type
	end
	
	---Converts the current (or given) temperature to the clients temperature-unit. Ideal for displays.
	---@param nCelcius number
	---@return number
	---@client
	function StormFox2.Temperature.GetDisplay(nCelcius)
		if nCelcius then
			return StormFox2.Temperature.Convert(nil,temp_type,nCelcius)
		end
		return StormFox2.Temperature.Get(temp_type)
	end
	
	---Returns the clients temperature-unit symbol. ("°C", "°F" ..)
	---@return string
	---@client
	function StormFox2.Temperature.GetDisplaySymbol()
		return symbol[temp_type] or "°C"
	end
	
	---Returns the default temperature, based on client-country.
	---@return string
	---@client
	function StormFox2.Temperature.GetDisplayDefault()
		return default_temp
	end
	-- Load the temperature settings.
	-- Setup setting
	StormFox2.Setting.AddCL("display_temperature",default_temp)
	local t = {}
	for k, v in pairs(symbol) do
		if t[k] then continue end
		t[k] = string.upper(k[1]) .. string.sub(k, 2) .. " " .. v
	end
	StormFox2.Setting.SetType( "display_temperature", t, {"celsius", "fahrenheit", "kelvin"} )
	StormFox2.Setting.Callback("display_temperature",function(sType)
		temp_type = convert_to[sType] and sType or "celsius"
	end,"StormFox2.temp.type")
	-- Load setting
	local sType = StormFox2.Setting.Get("display_temperature",default_temp)
	temp_type = convert_to[sType] and sType or "celsius"

	hook.Remove("stormfox2.postlib", "StormFox2.TemperatureSettings")

	---Sets the "local" temperature. This will override the server variable until called again with 'nil'.
	---@param nCelcius? number
	---@client
	function StormFox2.Temperature.SetLocal( nCelcius )
		tempOverwrite = nCelcius
	end
	
end