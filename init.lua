local TweenService = game:GetService("TweenService")

local module = {}
module.Styles = {}

local Style = {}
Style.__index = Style

--[=[
    @class Style
    A class representing a style that can be applied to Roblox instances.
]=]

--[=[
    @prop Styles table<string, Style>
    @within Style
    A table storing all named styles.
]=]

-- Local function to cleanup all connections and functions from a table
local function cleanupConnections(connectionTable)
	for _, connections in pairs(connectionTable) do
		for _, connection in ipairs(connections) do
			if typeof(connection) == 'RBXScriptConnection' then
				connection:Disconnect()
			end
		end
	end
end

--[=[
    @function new
    @within Style
    @param name string? -- The name of the style.
    @return Style -- The new style instance.
    Creates a new style.
]=]
function Style.new(name: string?)
	local self = setmetatable({
		name = name,
		connections = {},
		fnconnections = {},
		applied = {},
		initialProperties = {}
	}, Style)

	if name then
		assert(not module.Styles[name], 'A style with this name already exists')
		module.Styles[name] = self
	end

	return self
end

--[=[
    @function ChangeName
    @within Style
    @param name string -- The new name for the style.
    @return Style -- The style instance.
    Changes the name of the style.
]=]
function Style:ChangeName(name: string)
	assert(not module.Styles[name], 'This name is already taken')

	if self.name then
		module.Styles[self.name] = nil
	end

	self.name = name
	module.Styles[name] = self

	return self
end

--[=[
    @function SetInitialProperties
    @within Style
    @param properties table -- The initial properties to set.
    @return Style -- The style instance.
    Sets the initial properties for the style.
]=]
function Style:SetInitialProperties(properties: {})
	assert(type(properties) == 'table', 'Initial properties must be a table')
	self.initialProperties = properties

	return self
end

--[=[
    @function Connect
    @within Style
    @param eventName string -- The event name to connect to.
    @param tweenInfo TweenInfo -- The tween info for the animation.
    @param properties table -- The properties to tween.
    @param startCallback function? -- The callback to call when the tween starts.
    @param stopCallback function? -- The callback to call when the tween stops.
    @return Style -- The style instance.
    Connects an event with tweening and optional callbacks.
]=]
function Style:Connect(eventName: string, tweenInfo: TweenInfo, properties: {}, startCallback: (() -> ())?, stopCallback: (() -> ())?)
	assert(type(eventName) == 'string', 'Invalid event name')
	assert(typeof(tweenInfo) == 'TweenInfo', 'Invalid TweenInfo')
	assert(type(properties) == 'table', 'Invalid Properties table')

	local connection = {
		tweenInfo = tweenInfo,
		properties = properties,
		startCallback = startCallback,
		stopCallback = stopCallback
	}

	if not self.connections[eventName] then
		self.connections[eventName] = {}
	end

	table.insert(self.connections[eventName], connection)

	return self
end

--[=[
    @function ConnectFn
    @within Style
    @param eventName string -- The event name to connect to.
    @param fn function -- The callback function to connect.
    @return Style -- The style instance.
    Connects an event with a callback function.
]=]
function Style:ConnectFn(eventName: string, fn: () -> ())
	assert(type(fn) == 'function', 'Missing event callback function')

	if not self.fnconnections[eventName] then
		self.fnconnections[eventName] = {}
	end

	table.insert(self.fnconnections[eventName], fn)

	return self
end

--[=[
    @function DisconnectAll
    @within Style
    @param eventName string -- The event name to disconnect all connections from.
    Disconnects all connections for a given event name.
]=]
function Style:DisconnectAll(eventName: string)
	if self.connections and self.connections[eventName] then
		cleanupConnections(self.connections[eventName])
		self.connections[eventName] = nil
	end
end

--[=[
    @function DisconnectAllFn
    @within Style
    @param eventName string -- The event name to disconnect all function connections from.
    Disconnects all function connections for a given event name.
]=]
function Style:DisconnectAllFn(eventName: string)
	if self.fnconnections and self.fnconnections[eventName] then
		cleanupConnections(self.fnconnections[eventName])
		self.fnconnections[eventName] = nil
	end
end

--[=[
    @function Apply
    @within Style
    @param instances Instance | {Instance} -- The instances to apply the style to.
    @return Style -- The style instance.
    Applies the style to one or more instances.
]=]
function Style:Apply(instances: Instance | {Instance})
	if typeof(instances) ~= 'table' then
		instances = {instances}
	end

	for _, instance in ipairs(instances) do
		if not self.applied[instance] then
			self.applied[instance] = {}
		end

		if self.initialProperties then
			for property, value in pairs(self.initialProperties) do
				instance[property] = value
			end
		end

		for eventName, connections in pairs(self.connections) do
			for _, connection in ipairs(connections) do
				local application
				if typeof(connection) == 'function' then
					application = instance[eventName]:Connect(connection)
				else
					local tween = TweenService:Create(instance, connection.tweenInfo, connection.properties)
					local stopConnection

					application = instance[eventName]:Connect(function()
						if stopConnection then
							stopConnection:Disconnect()
						end

						tween:Play()

						if connection.startCallback then
							connection.startCallback(tween)
						end

						if connection.stopCallback then
							stopConnection = tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
								if playbackState == Enum.PlaybackState.Completed then
									connection.stopCallback(tween)
									stopConnection:Disconnect()
								end
							end)
						end
					end)
				end

				if not self.applied[instance][eventName] then
					self.applied[instance][eventName] = {}
				end
				table.insert(self.applied[instance][eventName], application)
			end
		end

		for eventName, fns in pairs(self.fnconnections) do
			for _, fn in ipairs(fns) do
				local application = instance[eventName]:Connect(fn)
				if not self.applied[instance][eventName] then
					self.applied[instance][eventName] = {}
				end
				table.insert(self.applied[instance][eventName], application)
			end
		end
	end

	return self
end

--[=[
    @function Unapply
    @within Style
    @param instance Instance -- The instance to unapply the style from.
    @return Style -- The style instance.
    Unapplies the style from an instance.
]=]
function Style:Unapply(instance: Instance)
	if self.applied[instance] then
		cleanupConnections(self.applied[instance])
		self.applied[instance] = nil
	end

	return self
end

--[=[
    @function Destroy
    @within Style
    Destroys the style, disconnecting all applied connections.
]=]
function Style:Destroy()
	for instance, applications in pairs(self.applied) do
		cleanupConnections(applications)
	end

	if self.name then
		module.Styles[self.name] = nil
	end

	setmetatable(self, nil)
end

module.new = Style.new

return module
