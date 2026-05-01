local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")

local Tools = ServerStorage:WaitForChild("Tools")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DataService = require(Framework:WaitForChild("DataServiceV2"))
local console = require(Framework:WaitForChild("console"))

task.spawn(function()
	require(script.Nametags).Init(script.Nametags)
end)

function onGamestart()
	local Teams = require(Framework:WaitForChild("assets"):WaitForChild("playerTeams"))
	Teams = Teams.default
end
coroutine.wrap(onGamestart)()

local loadedPrevCars = {}

Players.PlayerAdded:Connect(function(player)
	local success, data = DataService:LoadData(player)
	if success then
		print("Loaded data for", player.Name)
		local new = Instance.new("Configuration", player)
		new.Name = "Data"
		local wanted = Instance.new("BoolValue", new)
		wanted.Name = "Wanted"
		wanted.Value = data.Wanted
		local money = Instance.new("NumberValue", new)
		money.Name = "Money"
		money.Value = data.Money
		local wantedTimer = Instance.new("NumberValue", new)
		wantedTimer.Name = "WantedTimer"
		wantedTimer.Value = data.WantedTimer
		local WantedLevel = Instance.new("NumberValue", new)
		WantedLevel.Name = "WantedLevel"
		
	else
		warn("Failed to load data for", player.Name)
	end
	
	local debit = Tools:WaitForChild("Debit Card"):Clone()
	debit.Parent = player.Backpack
	local group = player:IsInGroupAsync(35770156)
	if group then
		local loy = Tools:WaitForChild("Loyalty Card"):Clone()
		loy.Parent = player.Backpack
	end
	local rank = player:GetRankInGroupAsync(35770156)
	if  rank >= 150 then
		local ad1 = Tools:WaitForChild("Operator Login Card"):Clone()
		ad1.Parent = player.Backpack
	elseif rank >= 200 then
		local ad2 = Tools:WaitForChild("Operator Login Card"):Clone()
		ad2["JSM | Operator Barcode"]:SetAttribute("AccountID", 2)
		ad2.Parent = player.Backpack
	elseif rank >= 255 then
		local ad3 = Tools:WaitForChild("Operator Login Card"):Clone()
		ad3["JSM | Operator Barcode"]:SetAttribute("AccountID", 3)
		ad3.Parent = player.Backpack
	end
	
end)

function getRandomSpawn()
	return workspace.Game.Spawns:GetChildren()[math.random(1, #workspace.Game.Spawns:GetChildren())]
end

Remotes:WaitForChild("D-62e9ca54-e732-419f-8bb0-a215744ce9c8").OnServerInvoke = function(player, typ, data)
	if typ == "GenerateModel" then
		-- FIX: Use :Destroy() instead of deprecated :Remove()
		if loadedPrevCars[player.UserId] then
			loadedPrevCars[player.UserId]:Destroy()
		end

		local a = game.InsertService:LoadAsset(data)
		local model = a:FindFirstChildOfClass("Model")
		
		--game.ContentProvider:PreloadAsync(a:GetDescendants())
		a:PivotTo(CFrame.new(0, 1000,0))
		if not model then
			a:Destroy()
			return nil
		end

		-- FIX: Nil check before destroying A-Chassis Tune
		local tune = model:FindFirstChild("A-Chassis Tune")
		if tune then
			tune:Destroy()
		end

		model.Parent = workspace
		model.Name = game.HttpService:GenerateGUID(false)
		a:Destroy()

		loadedPrevCars[player.UserId] = model
		return model
		
	elseif typ == "ModifyPlaceholder" then
		local prev = loadedPrevCars[player.UserId]
		if not prev then return false end
		prev:SetAttribute("Color", data)
		
		return true

	elseif typ == "CAR" then
		local plrData = DataService:GetData(player)
		if not plrData then return "ERROR", "No player data found." end

		local carData = require(Framework.assets.carData)

		-- FIX: Guard against invalid data.Type before indexing into carData
		if not data.Type or not carData[data.Type] then
			return "ERROR", "Invalid car type."
		end

		local carEntry = carData[data.Type][data.Name]
		if not carEntry then return "ERROR", "Car not found." end

		if plrData.Money < carEntry.Price then return "ERROR", "Not enough money." end

		if not plrData[data.Type] then
			return "ERROR", "Category not found in player data."
		end

		if plrData[data.Type][data.Name] then
			-- Player already owns it — spawn it
			for _, v in CollectionService:GetTagged("CAR_" .. player.UserId) do
				-- FIX: Use :Destroy() instead of deprecated :Remove()
				v:Destroy()
			end

			local new = game.InsertService:LoadAsset(carEntry.ID)
			local car = new:FindFirstChildOfClass("Model")

			if not car then
				new:Destroy()
				return "ERROR", "Failed to load car model."
			end

			-- FIX: Remove A-Chassis Tune in the spawn branch too
			--local tune = car:FindFirstChild("A-Chassis Tune")
			--if tune then tune:Destroy() end

			car.Parent = workspace.Game.Cars
			car.Name = "CAR_" .. player.Name
			car:SetAttribute("Owner", player.Name)
			car:SetAttribute("Name", carEntry.Name)
			car:SetAttribute("Locked", false)
			car:PivotTo(getRandomSpawn().CFrame)

			-- FIX: Apply the CollectionService tag so future cleanup actually works
			CollectionService:AddTag(car, "CAR_" .. player.UserId)

			new:Destroy()
			task.delay(3, function()
				car:SetAttribute("Color", data.Color)
				player.Character:PivotTo(car.PrimaryPart.OUT.WorldCFrame)
			end)
			return "Success", "Car Spawned."
		else
			-- FIX: Use dictionary assignment instead of table.insert for a keyed table
			if carEntry.Gamepass ~= nil then
				if not MarketplaceService:UserOwnsGamePassAsync(player.UserId, carEntry.Gamepass) then
					local bypasses = require(Framework:WaitForChild("Game"):WaitForChild("GamepassGrants"))
					if bypasses[player.UserId] and bypasses[player.UserId][carEntry.Gamepass] then
						console.log("Player does not own the gamepass, but has a bypass. [SERVER CHECKED]")
					else
						return "ERROR", "You do not own the required gamepass."
					end
				end
			end
			plrData[data.Type][data.Name] = true
			plrData.Money -= carEntry.Price
			DataService:UpdateData(player, plrData)
			return "Success", "Car purchased."
		end
	end
end
