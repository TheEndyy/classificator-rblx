
-- Pre-declare local functions for faster access


local PROTECTED_PREFIX = "_"
local PRIVATE_PREFIX = "__"
local CALL_METHOD = "__call__"

local function getFunction(level: number) -- gets the current function at the given stack level
	local fn = debug.info(level or 2, "f")
	return fn
end

-- 	 Private DON'T TOUCH!!!
local Classes = {} -- All classes created within this module
local ClassProtected = {} -- key: Class, value: table of protected properties
local ClassPrivate = {} -- key: Class, value: table of private properties
local ClassSuperiors = {} -- key: class, value: class or table of classes
local ClassKeyCache = {} -- stores a shared table between a class and it's subclasses that contains all the existing keys of the class and it's superiors

local Classificator = {}
local property

--[[
Classificator.IsClass(value: any)
Returns true if the given value is a class
]]
function Classificator.IsClass(value)
	return typeof(value) == "table" and rawget(value, "__clsname__")
end

--[[
Classificator.IsObject(value: any)
Returns true if the given value is an object
]]
function Classificator.IsObject(value)
	return typeof(value) == "table" and Classificator.IsClass(rawget(value, "__class__"))
end

--[[
Classificator.measureTime(fn: function, precision: number, ...) -> number
- fn: Function to be executed
- precision: Number of decimal places to round to (default is 0)
- ...: Additional arguments to pass to the function
Returns: number (Time in milliseconds it took for the function to execute)

Executes a given function and returns the time it took to execute in milliseconds
Make sure the function is in class scope if it's a class/object method
]]

function Classificator.measureTime(fn: () -> (), precision: number, ...)
	local precision = if type(precision) == "number" then precision else 0
	local start = tick()
	fn(...)
	return math.round((tick()-start)*(1000*10^precision))/(10^precision)
end

-- class structured metatable without inheritance, encapsulation and defined methods/metamethods. For internal use only
local function featurelessClass<Super>(ClassName: string)
	if type(ClassName) ~= "string" then error(`ClassName must be a string. {type(ClassName)} provided instead.`) end
	if not ClassName then error(`ClassName can't be omitted.`) end
	if Classes[ClassName] then error(`Class with name {ClassName} already exists.`) end

	local Class = setmetatable({
		__dict__ = {},
		__clsname__ = ClassName,
	}, {

	})
	Class.__class__ = Class

	Classes[ClassName] = Class

	return Class
end


--[[
Property class is a special class, that allows you to define custom getter, setter and deleter for an attribute
Properties can only be defined in Class scope
trying to get a class property will result in invoking property's getter
trying to set a class property will result in invoking property's setter
trying to set a class property to nil will result in invoking property's deleter
(upper rules only work if the current value is a property)
]] 
local property = featurelessClass("property")
property = setmetatable(property, {
	__call = function(self, getter: (self) -> any, setter: (self) -> any, deleter: (self) -> any)
		local object = setmetatable({
			getter = if type(getter) == "function" then getter else function() return getter end,
			setter = if type(setter) == "function" then setter else function() return setter end,
			deleter = if type(deleter) == "function" then deleter else function() return deleter end,
			__clsname__ = property.__clsname__,
			__class__ = self,
			__dict__ = {}
		}, {
			__tostring = function(self)
				return `<{self.__clsname__} object>` 
			end,
		})

		table.freeze(object)
		table.freeze(object.__dict__)
		return object
	end,
	__tostring = function(self)
		return `<class '{self.__clsname__}'>`
	end,
})

table.freeze(property)
table.freeze(property.__dict__)

export type Property = {
	getter: () -> (),
	setter: () -> (),
	deleter: () -> (),
	__clsname__: string,
	__class__: typeof(property),
	__dict__: {}
}



local function any(class, tbl)
	if not tbl then return false end
	if rawget(tbl, "__class__") then
		return rawequal(class, tbl) or any(class, ClassSuperiors[tbl])
	end

	for _, v in pairs(tbl) do
		return any(class, v)
	end
	return false
end

--[[
Classificator.isinstance(object: Object, class: Class|{Class})
- object: any object
- class: Class or a table of Classes
Returns true if object is an instance of the given class or any of the given classes
]]
function Classificator.isinstance(object: Class, class: Class|{Class})
	-- to be optimized/reworked
	if not (typeof(object) == "table" and Classificator.IsClass(rawget(object, "__class__"))) then return false end
	if type(class) == "string" then
		class = Classes[class]
		if not class then error("Invalid class") return end
	end
	local objclass = rawget(object, "__class__")

	if type(class) == "table" and not rawget(class, "__class__") then
		for _,v in class do
			if not (typeof(v) == "table" and rawget(v, "__clsname__")) then
				error("Not a class") return
			end
		end

		for _, v in pairs(class) do
			if rawequal(objclass, v) then
				return true
			end

			return any(v, ClassSuperiors[objclass])
		end
	elseif type(class) == "table" then
		if rawequal(objclass, class) then
			return true
		end

		return any(class, ClassSuperiors[objclass])
	else
		error("Not a class") return
	end
end

--[[
Classificator.issubclass(cls: Class, class: Class|{Class})
- cls: any class
- class: Class or a table of Classes
Returns true if cls is a subclass of the given class or any of the given classes
]]
function Classificator.issubclass(cls: Class, class: Class|{Class})
	-- to be optimized/reworked
	if not Classificator.IsClass(cls) then return false end
	if type(class) == "string" then
		class = Classes[class]
		if not class then error("Invalid class") return end
	end

	if type(class) == "table" and not rawget(class, "__class__") then
		for _,v in class do
			if not Classificator.IsClass(v) then
				error("Not a class") return
			end
		end

		for _, v in pairs(class) do
			if rawequal(cls, v) then
				return true
			end
			return any(cls, ClassSuperiors[v])
		end
	elseif type(class) == "table" then
		if rawequal(cls, class) then
			return true
		end
		return any(cls, ClassSuperiors[class])
	else
		error("Not a class") return
	end
end

-- Getter functions
-- To get attributes from subclasses
local defaultMethods = nil

local function g(class, index)
	local method = defaultMethods[index]
	local value = class.__dict__[index]
	if value ~= nil then 
		return value
	elseif class.__issubclass__ then
		local super = ClassSuperiors[class]
		if super then
			if super.__clsname__ then
				local value = g(super, index)
				if value ~= nil then
					return value 
				end
				return
			else
				for _, k in pairs(super) do
					local value = g(k, index)
					if value ~= nil then 
						return value 
					end
				end
				return
			end

		end
	elseif method then
		return method
	end
end

local function get(class, index)
	local value = g(class, index)
	if type(value) == "table" and rawequal(value.__class__, property) then 
		return value.getter()
	end
	return value
end

local function getprot(cls, index)
	local value = ClassProtected[cls][index]
	if value ~= nil then
		return value
	elseif cls.__issubclass__ then
		local super = ClassSuperiors[cls]
		if super and super ~= BaseClass then
			if super.__clsname__ then
				local value = getprot(super, index)
				if value ~= nil then
					return value
				end
				return nil
			else
				for _, k in pairs(super) do
					local value = getprot(k, index)
					if value ~= nil then
						return value
					end
				end
				return value
			end
		end
	end
end

local function getProtected(class, index)
	local value = getprot(class, index)
	if type(value) == "table" and rawequal(value.__class__, property) then 
		return value.getter()
	end
	return value 
end

local function getPrivate(class, index)
	local value = ClassPrivate[class][index]
	if type(value) == "table" and rawequal(value.__class__, property) then
		return value.getter()
	end
	return value 
end

-- Protected/Private checks + caching
-- string operations are expensive

local isprotectedcache = {}
local isprivatecache = {}

local function isProtected(index: string)
	local cache = rawget(isprotectedcache, index)
	if cache ~= nil then return cache end

	local start = index:sub(1, 1)
	local endd = index:sub(-1)
	local isProtected = start == PROTECTED_PREFIX and endd ~= PROTECTED_PREFIX

	isprotectedcache[index] = isProtected

	return isProtected
end

local function isPrivate(index: string)
	local cache = rawget(isprivatecache, index)
	if cache ~= nil then return cache end

	local start = index:sub(1, 2)
	local endd = index:sub(-1)
	local isPrivate = start == PRIVATE_PREFIX and endd ~= PROTECTED_PREFIX

	isprivatecache[index] = isPrivate

	return isPrivate
end

--[[
Scope control functions
Scope is used for encapsulation to determine if you can access protected/private attributes/method at specific execution point or not

To be added:
- Last classes/objects caching to get rid of Classificator.getFunction() need and providing self argument for async functions (will make usage simple)
]]

local ClassIntScopes = {} -- class internal scopes where keys are classes and values are their internal scopes
local ObjectIntScopes = setmetatable({}, {__mode = "k"}) -- object internal scopes where keys are objects and values are their internal scopes. weak keys because objects can be garbage collected

-- Checks if a function is in the scope of a class
local function isInScope(cls, fn)
	local scope = ClassIntScopes[cls]
	if not scope then
		return
	end
	return scope.fnInScope(fn)
end

-- Checks if a function is in the private scope of a class
local function isInPrivateScope(cls, fn)
	local scope = ClassIntScopes[cls]
	if not scope then
		return
	end
	return scope.fnInPrivateScope(fn)
end

-- Class scope setup (for encapsulation)
local function setupInternalScope()
	local scopeFns = setmetatable({}, {__mode = "kv"}) -- functions that are in scope
	local personalOnly = setmetatable({}, {__mode = "kv"}) -- for private modifier
	local runningFns = {} -- in-scope functions that are currently running
	local runningCount = 0
	local personalRunning = 0
	local pausedFns = {} -- yielded functions
	local threadToFunction = setmetatable({}, {__mode = "kv"}) -- returns function if the key is a thread that runs the function
	local runningThreads = setmetatable({}, {__mode = "kv"}) -- Async stuff
	
	local function inScope()
		for _, _ in pairs(runningFns) do
			return true
		end
		return false
	end
	
	local self = {}
	self.runningCount = 0
	self.personalRunning = 0
	function self.add(fn)
		scopeFns[fn] = fn
	end
	function self.addPrivate(fn)
		scopeFns[fn] = fn
		personalOnly[fn] = fn
	end
	function self.start(fn)
		if rawget(runningFns, fn) or not rawget(scopeFns, fn) then return end
		if rawget(pausedFns, fn) then
			rawset(pausedFns, fn, nil)
		end
		rawset(runningFns, fn, true)
		runningCount += 1
		self.runningCount += 1
		if rawget(personalOnly, fn) then
			personalRunning += 1
			self.personalRunning += 1
		end
	end
	function self.finish(fn)
		if not rawget(scopeFns, fn) then 
			return
		end
		if rawget(runningFns, fn) then
			rawset(runningFns, fn, nil)
			runningCount -= 1
			self.runningCount -= 1
			if rawget(personalOnly, fn) then
				personalRunning -= 1
				self.personalRunning -= 1
			end
		end
	end
	local function isInScope()
		if runningCount > 0 then
			return true
		end
		for level = 3, 5 do
			local info = debug.info(level, "f")
			if not info then break end
			if scopeFns[info] then return true end
		end
		return false
	end
	self.isInScope = isInScope
	function self.inPrivateScope()
		if personalRunning > 0 then
			return true
		end
		for level = 3, 5 do
			local info = debug.info(level, "f")
			if not info then break end
			if personalOnly[info] then return true end
		end
		return false
	end
	function self.fnInScope(fn)
		return scopeFns[fn]
	end
	function self.fnInPrivateScope(fn)
		return personalOnly[fn]
	end
	function self.isRunning(fn)
		return runningFns[fn]
	end
	function self.pause(fn)
		if runningFns[fn] then
			runningFns[fn] = nil
			pausedFns[fn] = fn
		end
	end
	function self.addTask(t: thread, fn)
		if runningThreads[t] then
			return
		end
		runningThreads[t] = t
		threadToFunction[t] = fn
	end
	function self.closeTask(t: thread)
		if not runningThreads[t] then
			return
		end
		runningThreads[t] = nil
		threadToFunction[t] = nil
	end
	return self
end

-- Object scope setup
local function setupInternalScopeObject(obj)
	local cls = obj.__class__
	local scopeFns = setmetatable({}, {__mode = "kv"}) -- functions that are in scope
	local personalOnly = {}
	local runningFns = {} -- in-scope functions that are currently running
	local runningCount = 0
	local personalRunning = 0
	local pausedFns = {} -- yielded functions
	local threadToFunction = setmetatable({}, {__mode = "kv"}) -- returns function if the key is a thread that runs the function
	local runningThreads = setmetatable({}, {__mode = "kv"}) -- Async stuff

	local function inScope()
		for _, _ in pairs(runningFns) do
			return true
		end
		return false
	end
	
	local self = {}
	self.runningCount = 0
	self.personalRunning = 0
	self.lastFn = nil
	function self.add(fn)
		scopeFns[fn] = fn
	end
	function self.addPrivate(fn)
		scopeFns[fn] = fn
		personalOnly[fn] = fn
	end
	function self.start(fn)
		if rawget(runningFns, fn) or not rawget(scopeFns, fn) then return end
		if rawget(pausedFns, fn) then
			rawset(pausedFns, fn, nil)
		end
		rawset(runningFns, fn, true)
		runningCount += 1
		self.runningCount += 1
		if rawget(personalOnly, fn) then
			personalRunning += 1
			self.personalRunning += 1
		end
	end
	function self.finish(fn)
		if not rawget(scopeFns, fn) then 
			return
		end
		if rawget(runningFns, fn) then
			rawset(runningFns, fn, nil)
			runningCount -= 1
			self.runningCount -= 1
			if rawget(personalOnly, fn) then
				personalRunning -= 1
				self.personalRunning -= 1
			end
		end
	end
	function self.isInScope()
		if runningCount > 0 then
			return true
		end
		for level = 3, 5 do
			local info = debug.info(level, "f")
			if not info then break end
			if scopeFns[info] or isInScope(cls, info) then return true end
		end
		return false
	end
	function self.inPrivateScope()
		if personalRunning > 0 then
			return true
		end
		for level = 3, 5 do
			local info = debug.info(level, "f")
			if not info then break end
			if personalOnly[info] or isInPrivateScope(cls, info) then return true end
		end
		return false
	end
	function self.isRunning(fn)
		return runningFns[fn]
	end
	function self.pause(fn)
		if runningFns[fn] then
			runningFns[fn] = nil
			pausedFns[fn] = fn
		end
	end
	function self.addTask(t: thread, fn)
		if runningThreads[t] then
			return
		end
		runningThreads[t] = t
		threadToFunction[t] = fn
	end
	function self.closeTask(t: thread)
		if not runningThreads[t] then
			return
		end
		runningThreads[t] = nil
		threadToFunction[t] = nil
	end
	return self
end

-- adds a function to the class scope
local function addToClassScope(tbl, fn, privateAdded)
	local ClsScope = rawget(ClassIntScopes, tbl)
	if ClsScope then
		if privateAdded then
			ClsScope.add(fn)
		else
			ClsScope.addPrivate(fn)
			privateAdded = true
		end
	end
	if tbl.__issubclass__ then
		local super =  rawget(ClassSuperiors, tbl)
		if rawget(super, "__clsname__") then
			addToClassScope(super, fn, privateAdded)
		else
			for _, k in pairs(super) do
				addToClassScope(k, fn, privateAdded)
			end
		end
	end

end

--[[
Classificator.addToScope(self: Class|Object, fn: function)
- self: Class or Object
- fn: function to be added to the scope of the given Class or Object

Adds a function to the scope of the given Class or Object. Only works if you're in Class scope
]]
Classificator.addToScope = function(tbl, fn, IntScope)
	local IntScope = IntScope or rawget(ObjectIntScopes, tbl) or rawget(ClassIntScopes, tbl)
	if not IntScope then 
		error("couldn't find internal scope for given table") return 
	end
	if not (IntScope.runningCount > 0 or IntScope.isInScope()) then
		error("not in class scope")
	end
	local isclass = rawget(tbl, "__clsname__")
	local start = IntScope.start
	local finish = IntScope.finish
	
	if isclass then
		local function fn1(...)	
			start(fn)
			local result = table.pack(fn(...))
			finish(fn)
			return table.unpack(result)
		end
		addToClassScope(tbl, fn)
		return fn1
	else
		local function fn1(...)
			start(fn)
			local result = table.pack(fn(...))
			finish(fn)
			return table.unpack(result)
		end
		IntScope.addPrivate(fn)
		addToClassScope(tbl.__class__, fn)
		return fn1
	end
end

-- Returns the function that called Classificator.getFunction()
Classificator.getFunction = function(): () -> ()
	return debug.info(2, "f")
end

--[[
Asynchronous Classificator functions
Only use these functions for Class scope functions and methods

Parameter self must be a class/object, and it must be the first argument
]]
local wait = task.wait
local delay = task.delay
local defer = task.defer
local spawn = task.spawn
local cancel = task.cancel


--[[
Classificator.Wait(self: Class|Object, t: number, fn: function) -> number
- self: Class or Object that the given function belongs to
- t: Time to wait in seconds
- fn: Function to be paused (exit scope) for the given time, if omitted, the current function is used
Returns: number (elapsed time in seconds)

Classificator's task.wait function analog. Pauses the given function's execution for the given time, and resumes it after the time has passed.
]]
Classificator.Wait = function(self: Class, t: number, fn: () -> ())
	if type(fn) ~= "function" then
		fn = getFunction(3) -- function that called wait function
	end
	local IntScope = rawget(ObjectIntScopes, self) or rawget(ClassIntScopes, self)
	if not IntScope then 
		error("couldn't find internal scope for given table") return 
	end
	if not IntScope.isInScope() then
		error("not in class scope")
	end
	
	IntScope.pause(fn)
	local time = wait(t)
	IntScope.start(fn)
	
	return time
end

--[[
Classificator.Spawn(self: Class|Object, fnOrThr: function|thread, ...) -> thread
- self: Class or Object that the given function belongs to
- fnOrThr: Function or thread to be called/resumed immediately
- ...: Arguments to pass to the function
Returns: thread

Classificator's analog of task.spawn. 
If a function is given, it is immediately spawned as a task. If a thread is given, it is resumed.
]]
Classificator.Spawn = function(self: Class, fnOrThr, ...)
	local IntScope = rawget(ObjectIntScopes, self) or rawget(ClassIntScopes, self)
	if not IntScope then 
		error("couldn't find internal scope for given table") return 
	end
	if not IntScope.isInScope() then
		error("not in class scope")
	end
	
	local valuetype = type(fnOrThr)
	if valuetype == "thread" then
		local thread = spawn(fnOrThr, ...)
		return thread
	elseif valuetype == "function" then
		local thread = spawn(fnOrThr, ...)
		IntScope.addTask(thread, fnOrThr)

		return thread
	end

end

--[[
Classificator.Delay(self: Class|Object, duration: number, fnOrThr: function|thread, ...) -> thread
- self: Class or Object that the given function belongs to
- duration: Time to wait in seconds before resuming the given function or thread
- fnOrThr: Function or thread to be called/resumed
- ...: Arguments to pass to the function
Returns: thread

Classificator's analog of task.delay.
]]
Classificator.Delay = function(self: Class, duration: number, fnOrThr, ...)
	local IntScope = rawget(ObjectIntScopes, self) or rawget(ClassIntScopes, self)
	if not IntScope then 
		error("couldn't find internal scope for given table") return 
	end
	if not IntScope.isInScope() then
		error("not in class scope")
	end
	
	local valuetype = type(fnOrThr)
	if valuetype == "thread" then
		local thread = delay(duration, fnOrThr, ...)
		
		return thread
	elseif valuetype == "function" then
		local thread = delay(duration, fnOrThr, ...)
		IntScope.addTask(thread, fnOrThr)

		return thread
	end
end

--[[
Classificator.Defer(self: Class|Object, fnOrThr: function|thread, ...) -> thread
- self: Class or Object that the given function belongs to
- duration: Time to wait in seconds before resuming the given function or thread
- fnOrThr: Function or thread to be called/resumed
- ...: Arguments to pass to the function
Returns: thread

Classificator's analog of task.defer. 
Unlike Classificator.Spawn, Classificator.Defer resumes the given function or thread until the end of the current frame.
]]
Classificator.Defer = function(self: Class, fnOrThr, ...)
	local IntScope = rawget(ObjectIntScopes, self) or rawget(ClassIntScopes, self)
	if not IntScope then 
		error("couldn't find internal scope for given table") return 
	end
	if not IntScope.isInScope() then
		error("not in class scope")
	end
	
	local valuetype = type(fnOrThr)
	if valuetype == "thread" then
		local thread = defer(fnOrThr, ...)
		return thread
	elseif valuetype == "function" then
		local thread = defer(fnOrThr, ...)
		IntScope.addTask(thread, fnOrThr)
		return thread
	end
end

--[[
Classificator.Cancel(self: Class|Object, fnOrThr: function|thread)
- self: Class or Object that the given function belongs to
- thread: thread to be cancelled

Classificator's analog of task.cancel. 
]]
Classificator.Cancel = function(self: Class, thread: thread)
	if type(thread) ~= "thread" then
		error("thread must be thread type") return
	end
	
	local IntScope = rawget(ObjectIntScopes, self) or rawget(ClassIntScopes, self)
	if not IntScope then 
		error("couldn't find internal scope for given table") return 
	end
	if not IntScope.isInScope() then
		error("not in class scope")
	end
	
	IntScope.closeTask(thread)
	cancel(thread)
end


--[[
Classificator class creating

This block is responsible for creating classes
]]

--[[
BaseClass methods, such as __new__, __init__, etc.
]]
local __new__
__new__ = function(self, ...): Object
	local cls = self
	if not Classificator.IsClass(cls) then error(`self must be a class`) return end
	local object
	local InternalScope = nil
	local isInScope = nil
	local inPrivateScope = nil
	local addToScope = nil

	local __dict__ = {}
	local protected = {}
	local private = {}

	local clsdict = cls.__dict__
	local basedict = BaseClass.__dict__
	local getter = clsdict.__getattr__
	local deleter = clsdict.__delattr__
	local setter = clsdict.__setattr__

	object = setmetatable({
		__dict__ = __dict__,
		__class__ = cls
	}, {
		__index = function(self, index)
			local isprivatecached = rawget(isprivatecache, index)
			if isprivatecached ~= false then
				if isprivatecached or isPrivate(index) then
					if InternalScope.personalRunning > 0 or inPrivateScope() then
						local privval = rawget(private, index)
						if type(privval) == "table" and rawequal(privval.__class__, property) then
							return privval.getter()
						elseif privval ~= nil then
							return privval
						end
						return getPrivate(cls, index)
					else
						error(`{self}: Tried getting a private attribute {index} outside Class scope`) return
					end
				end
			end
			local isprotectedcached = rawget(isprotectedcache, index)
			if isprotectedcached ~= false then
				if isprotectedcached or isProtected(index) then
					if InternalScope.runningCount > 0 or isInScope() then
						local protval = rawget(protected, index)
						if type(protval) == "table" and rawequal(protval.__class__, property) then
							return protval.getter()
						elseif protval ~= nil then
							return protval
						end
						return getProtected(cls, index)
					else
						error(`{self}: Tried getting a protected attribute {index} outside Class/Subclass scope`) return
					end
				end
			end

			local value = getter and getter(self, index) or rawget(__dict__, index)
			-- if the index is a property (or index is __call__)

			if type(value) == "table" and rawequal(value.__class__, property) then
				return value.getter()
			elseif value ~= nil then
				return value
			end
			return get(cls, index)

		end,
		__newindex = function(self, index, value)
			index = tostring(index)
			if typeof(value) == "function" and (InternalScope.runningCount > 0 or isInScope()) then
				value = addToScope(self, value, InternalScope)
			end

			local isprivatecached = rawget(isprivatecache, index)
			if isprivatecached ~= false then
				if isprivatecached or isPrivate(index) then
					if InternalScope.personalRunning > 0 or inPrivateScope() then
						local privval = rawget(private, index)
						if type(privval) == "table" and rawequal(privval.__class__, property) then return if value ~= nil then privval.setter(value) else privval.deleter() end
						rawset(private, index, value)
						return
					else
						error(`{self}: Tried setting a private attribute {index} outside Class scope`) return
					end
				end
			end
			local isprotectedcached = rawget(isprotectedcache, index)
			if isprotectedcached ~= false then
				if isprotectedcached or isProtected(index) then
					if InternalScope.runningCount > 0 or isInScope() then
						local protval = rawget(protected, index)
						if type(protval) == "table" and rawequal(protval.__class__, property) then return if value ~= nil then protval.setter(value) else protval.deleter() end
						rawset(protected, index, value)
						return
					else
						error(`{self}: Tried setting a protected attribute {index} outside Class/Subclass scope`) return
					end
				end
			end
			
			if type(value) == "table" and rawequal(value.__class__, property) then
				if not inPrivateScope() then
					error(`{self}: Tried setting a property {index} outside Class scope`) return
				end
			end

			local cvalue = getter and getter(self, index) or rawget(__dict__, index)
			if type(cvalue) == "table" and rawequal(cvalue.__class__, property) then
				return value ~= nil and cvalue.setter(value) or cvalue.deleter()
			end
			
			if not rawequal(value, nil) then 
				if setter then setter(self, index, value) return end 
			else
				if deleter then deleter(self, index, value) return end
			end
			rawset(__dict__, index, value)

		end,
		__tostring = function(self)
			local str = cls.__str__
			if type(str) == "function" then return str(self) else return BaseClass.__str__(self) end
		end,
		__eq = function(self, value)
			return if type(self.__eq__) == "function" then self:__eq__(value) else nil
		end,
		__lt = function(self, value)
			return if type(self.__lt__) == "function" then self:__lt__(value) else nil
		end,
		__le = function(self, value)
			return if type(self.__le__) == "function" then self:__le__(value) else nil
		end,
		__add = function(self, value)
			return if type(self.__add__) == "function" then self:__add__(value) else nil
		end,
		__sub = function(self, value)
			return if type(self.__sub__) == "function" then self:__sub__(value) else nil
		end,
		__mul = function(self, value)
			return if type(self.__mul__) == "function" then self:__mul__(value) else nil
		end,
		__div = function(self, value)
			return if type(self.__div__) == "function" then self:__div__(value) else nil
		end,
		__idiv = function(self, value)
			return if type(self.__idiv__) == "function" then self:__idiv__(value) else nil
		end,
		__mod = function(self, value)
			return if type(self.__mod__) == "function" then self:__mod__(value) else nil
		end,
		__pow = function(self, value)
			return if type(self.__pow__) == "function" then self:__pow__(value) else nil
		end,
		__len = function(self)
			return if type(self.__len__) == "function" then self:__len__() else nil
		end,
		__unm = function(self)
			return if type(self.__unm__) == "function" then self:__unm__() else nil
		end,
		__call = function(self, ...)
			return if type(self.__call__) == "function" then self:__call__(...) else nil
		end,
	})
	InternalScope = setupInternalScopeObject(object)
	InternalScope.add(__new__)
	InternalScope.start(__new__)
	isInScope = InternalScope.isInScope
	inPrivateScope = InternalScope.inPrivateScope
	addToScope = Classificator.addToScope
	ObjectIntScopes[object] = InternalScope

	table.freeze(object)

	local __init__ = cls.__init__
	if __init__ and type(__init__) == "function" then 
		__init__ = addToScope(object, __init__, InternalScope)
		__init__(object, ...)
	end
	InternalScope.finish(__new__)
	return object :: Object
end
defaultMethods = {
	__getattr__ = function(self, index)
		if type(self) ~= "table" then error("must a table") return end
		local dict = self.__dict__
		if not dict then return nil end
		return dict[index]
	end,
	__setattr__ = function(self, index, value)
		if type(self) ~= "table" then error("must a table") return end
		local dict = self.__dict__
		if not dict then return nil end
		dict[index] = value
	end,
	__delattr__ = function(self, index)
		if type(self) ~= "table" then error("must a table") return end
		local dict = self.__dict__
		if not dict then return nil end
		dict[index] = nil
	end,
	__new__ = __new__,
	__init__ = function(self, ...)

	end,
	__init_subclass__ = function(self, ...)

	end,
	__call__ = function(self, ...)
		return BaseClass.__new__(self, ...)
	end,
	__str__ = function(self)
		local isobject = Classificator.IsObject(self)
		if not isobject then error(`self must be a class or an object`) return end
		return `<{self.__class__.__clsname__} object>` 
	end,
	__add__ = function(self, value)

	end,
	__sub__ = function(self, value)

	end,
	__mul__ = function(self, value)

	end,
	__div__ = function(self, value)

	end,
	__idiv__ = function(self, value)

	end,
	__mod__ = function(self, value)

	end,
	__pow__ = function(self, value)

	end,
	__eq__ = function(self, value)

	end,
	__lt__ = function(self, value)

	end,
	__le__ = function(self, value)

	end,
	__lock__ = function(self, deep: boolean)
		if not (Classificator.IsObject(self) or Classificator.IsClass(self)) then error(`self must be a class or an object`) return end

		local function deepfreeze(tbl)
			if not table.isfrozen(tbl) then table.freeze(tbl) end
			for i, k in pairs(tbl) do
				if type(k) == "table" then deepfreeze(k) end
			end
		end

		if deep then deepfreeze(self.__dict__) else if not table.isfrozen(self.__dict__) then table.freeze(self.__dict__) end end
	end
}

--[[
Class creator function
]]
local function newClass(clsname: string, super: {Class}|Class|nil, body:((cls: Class) -> ())?)
	clsname = tostring(clsname)
	if not clsname then error(`clsname can't be omitted.`) end
	if Classes[clsname] and clsname == "Class" then error("Reserved name") end
	if Classes[clsname] then error(`Class with name {clsname} already exists.`) return end
	local checked = {}
	if super then
		if type(super) == "table" and not rawget(super, "__class__") then -- checking if all items are classes
			for i, k in pairs(super) do
				if not Classificator.IsClass(k) then
					error("Super is not a class")
				end
				if checked[k] then
					error("Provided same class twice")
				end
				checked[k] = true
			end
		elseif type(super) == "table" and rawget(super, "__class__") then
			-- nothing here
		else
			error("Super is not a class") return
		end
	else

	end

	local InternalScope = nil
	local isInScope = nil
	local inPrivateScope = nil
	local addToScope = nil
	local issubclass = not (super == BaseClass or table.find(checked, BaseClass)) or not not super
	local __dict__ = {}
	local protected = {}
	local private = {}

	local Class
	
	Class = setmetatable({
		__dict__ = __dict__,
		__clsname__ = clsname,
		__issubclass__ = issubclass,
		__isclassinherited__ = super == BaseClass or table.find(checked, BaseClass) or not super
	},{
		__index = function(self, index)
			--index = tostring(index)

			local isprivatecached = rawget(isprivatecache, index)
			if isprivatecached ~= false then
				if isprivatecached or isPrivate(index) then
					if InternalScope.personalRunning > 0 or inPrivateScope() then
						local value = private[index]
						if type(value) == "table" and rawequal(value.__class__, property) then
							return value.getter()
						end
						if value ~= nil then
							return value
						end
						return
					else
						error(`{self}: Tried getting a private attribute {index} outside Class scope`) return
					end
				end
			end
			local isprotectedcached = rawget(isprotectedcache, index)
			if isprotectedcached ~= false then
				if isprotectedcached or isProtected(index) then
					if InternalScope.runningCount > 0 or isInScope() then
						local value = protected[index]
						if type(value) == "table" and rawequal(value.__class__, property) then
							return value.getter()
						end
						if value ~= nil then
							return value
						end
						if issubclass then
							return getProtected(ClassSuperiors[self], index)
						end
						return
					else
						error(`{self}: Tried getting a protected attribute {index} outside Class/Subclass scope`) return
					end
				end
			end

			if index == "__call__" then
				return BaseClass.__dict__[index]
			end
			
			local value = rawget(__dict__, index)
			if type(value) == "table" and rawequal(value.__class__, property) then
				return value.getter()
			end
			if value ~= nil then
				return value
			end
			
			return get(ClassSuperiors[self], index)

		end,
		__newindex = function(self, index, value)
			index = tostring(index)

			if typeof(value) == "function" and (InternalScope.runningCount > 0 or isInScope()) then
				value = addToScope(self, value)
			end
			
			local isprivatecached = rawget(isprivatecache, index)
			if isprivatecached ~= false then
				if isprivatecached or isPrivate(index) then
					if InternalScope.personalRunning > 0 or inPrivateScope() then
						local privval = rawget(private, index)
						if type(privval) == "table" and rawequal(privval.__class__, property) then return if value ~= nil then privval.setter(value) else privval.deleter() end
						rawset(private, index, value)
						return
					else
						error(`{self}: Tried setting a private attribute {index} outside Class scope`) return
					end
				end
			end
			local isprotectedcached = rawget(isprotectedcache, index)
			if isprotectedcached ~= false then
				if isprotectedcached or isProtected(index) then
					if InternalScope.runningCount > 0 or isInScope() then
						local protval = rawget(protected, index)
						if type(protval) == "table" and rawequal(protval.__class__, property) then return if value ~= nil then protval.setter(value) else protval.deleter() end
						rawset(protected, index, value)
						return
					else
						error(`{self}: Tried setting a protected attribute {index} outside Class/Subclass scope`) return
					end
				end
			end

			if type(value) == "table" and rawequal(value.__class__, property) then
				if not inPrivateScope() then
					error(`{self}: Tried setting a property {index} outside Class scope`) return
				end
			end

			local cvalue = rawget(__dict__, index)
			if type(cvalue) == "table" and rawequal(cvalue.__class__, property) then
				return value ~= nil and cvalue.setter(value) or cvalue.deleter()
			end
			rawset(__dict__, index, value)
		end,
		__tostring = function(self)
			return `<class '{self.__clsname__}'>` 
		end,
		__call = function(self, ...)
			return if type(self.__call__) == "function" then self:__call__(...) else nil
		end,
	})
	rawset(Class, "__class__", Class)
	InternalScope = setupInternalScope()
	InternalScope.add(newClass)
	InternalScope.start(newClass)
	isInScope = InternalScope.isInScope
	inPrivateScope = InternalScope.inPrivateScope
	addToScope = Classificator.addToScope
	ClassIntScopes[Class] = InternalScope
	
	Classes[clsname] = Class
	ClassProtected[Class] = protected
	ClassPrivate[Class] = private
	
	if clsname == "Class" then
		Class.__getattr__ = defaultMethods.__getattr__
		Class.__setattr__ = defaultMethods.__setattr__
		Class.__delattr__ = defaultMethods.__delattr__
		Class.__new__ = defaultMethods.__new__
		Class.__init__ = defaultMethods.__init__
		Class.__init_subclass__ = defaultMethods.__init_subclass__
		Class.__call__ = defaultMethods.__call__
		Class.__str__ = defaultMethods.__str__
		Class.__add__ = defaultMethods.__add__
		Class.__sub__ = defaultMethods.__sub__
		Class.__mul__ = defaultMethods.__mul__
		Class.__div__ = defaultMethods.__div__
		Class.__idiv__ = defaultMethods.__idiv__
		Class.__mod__ = defaultMethods.__mod__
		Class.__eq__ = defaultMethods.__eq__
		Class.__lt__ = defaultMethods.__lt__
		Class.__le__ = defaultMethods.__le__
		Class.__pow__ = defaultMethods.__pow__
		Class.__lock__ = defaultMethods.__lock__
		Class:__lock__()
	end

	table.freeze(Class)

	if super then 
		ClassSuperiors[Class] = super 
	elseif clsname ~= "Class" then
		ClassSuperiors[Class] = BaseClass
	end	
	
	InternalScope.finish(newClass)
	
	local super = ClassSuperiors[Class]
	if super and not super.__clsname__ then
		for _, k in pairs(super) do
			local initsubclass = k.__init_subclass__
			if type(initsubclass) == "function" then
				--initsubclass = Classificator.addToScope(Class, initsubclass)
				initsubclass(Class)
			end
		end
	elseif super then
		local initsubclass = super.__init_subclass__
		if type(initsubclass) == "function" then
			--initsubclass = Classificator.addToScope(Class, initsubclass)
			initsubclass(Class)
		end
	end

	if type(body) == "function" then
		body = Classificator.addToScope(Class, body)
		body(Class)
	end

	return Class
end



--[[
Classificator.new(clsname: string, super: {Class}|Class|nil, body: function(cls: Class)) -> Class
- clsname: Name of the class. If there is a class with the same name, it will be overriden.
- super: Class or a table or classes to inherit from. If nil, the class will inherit from the base class.
- body: Class body function. It receives the class as an argument and it's the only function that is always in Class scope. It's used to define attributes, methods, etc.
Returns: Class

Constructs a class with the given name, superclasses and class body. Class is a frozen metatable that has next attributes:
- __dict__: A dictionary of public class attributes and methods. It can be used to get and set public attributes and methods without invoking __getattr__ or __setattr__ methods.
- __clsname__: The name of this class

Indexing class without an access modifier will result in getting an attribute from the __dict__ table. Indexing with a protected (_protected) or private (__private) modifier will result in indexing the class' internal table if in class scope currently or will throw an error if out of class scope. If the index is nil, inheritance will be used to find the attribute.
Previous rules are applied for setting attributes too, but it's setting instead of getting attributes.
To create an instance (object) of class, call the class as a function or call Class:__new__(), arguments are optional
Read the docs for more info...
]]
function Classificator.new<Super>(ClassName: string, super: Super?, body: ((cls: Class) -> ())?): Class
	return newClass(ClassName, super, body)
end

BaseClass = Classificator.new("Class", nil)
export type Class = typeof(BaseClass)
Classificator.BaseClass = BaseClass

-- Creates new property object with given getter, setter and deleter functions
Classificator.property = function(getter: () -> any, setter: (value: any) -> any, deleter: () -> any)
	return property(getter, setter, deleter) :: Property
end

table.freeze(Classificator)

return Classificator
