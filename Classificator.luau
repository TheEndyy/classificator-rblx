--[[
	Classificator by @TheEndyy0
	Version 1.0.0
	Released under the MIT license
	
	Classificator is a class creation utility module that creates classes with attributes and methods. Inspired by Python classes
	Classificator supports such things as:
	• Multiple inheritance
	• Object initializer
	• Properties
	• Object Properties' and Class Attributes' changes tracking
	• ClassName checking
	• Object's Identifier checking
	• Custom getters, setters, deleters and metamethods
	• And more!
	
	
	
	
	
	  BaseClass
	- ClassName: string - The class's name
	- Methods: table - A table of functions that will be used as class methods
	- Attributes: table - A table of values that will be used as class attributes
	- AttributeChanged: BindableEvent - An event that fires when an attribute is changed
	
	BaseClass.super() - Returns the super class of the subclass that called it
	-> Class that the class inherits from (nil if called by BaseClass)
	
	BaseClass:IsSubclass(classname) - Return true if the class is a subclass of a class called {classname}
	@param classname: string - Name of the class that the class could be a subclass of
	-> boolean
	
	BaseClass.new() - Creates and returns a new Object of the class that called it
	-> Object of the class that called it
	* To define an object initializer, define a Class function called 'init'. It will be called when BaseClass.new() is called.
	* To define an object property, simply set Object's index to a value. Properties can be accessed by indexing Object or Object.Properties.
	* To define an object method, simply set Object's index to a function. Methods can be accessed by indexing Object or Object.Methods.

	BaseClass.init(object, ...) - Initializes the object. Called when BaseClass.new() is called.
	@param object (self): Object - Object of the class that called it
	@param ...: any - Any number of arguments
	* This function can be used to define properties and bind methods to the object.
	* All default Object properties must be defined within the object initializer.
	* All default Object methods must be defined within the initializer.
	* If needed, the super class' initializer can be called by calling Class.super().init(object)
	* This function is optional.
	
	
	
	
	
	  BaseObject
	- Class: BaseClass - The object's class
	- Identifier: number - The object's identifier
	- Properties: table - A table of Object's properties
	- Methods: table - A table of Object's methods
	- PropertyChanged: BindableEvent - An event that fires when a property is changed
	
	BaseObject.propSetter(index, value) - Property setter for Object. Sets property to value by default.
	@param index: string|number - Property index
	@param value: any - Property value
	* !!!Must always index BaseObject.Properties inside this function
	* This method only works if indexing BaseObject, not BaseObject.Properties
	
	BaseObject.propGetter(index) - Property getter for Object. Gets property's value by default.
	@param index: string|number - Property index
	-> any - Property value (by default)
	* !!!Must always index BaseObject.Properties inside this function
	* This method only works if indexing BaseObject, not BaseObject.Properties
	
	BaseObject.propDeleter(index) - Property deleter for Object. Sets property's value to nil by default. Is called when trying to set a property to nil.
	@param index: string|number - Property index
	-> nil
	* !!!Must always index BaseObject.Properties inside this function
	* This method only works if indexing BaseObject, not BaseObject.Properties
		
	BaseObject.objectEqual(value) - Is called when trying to use == operator on Object and value. Returns nil by default. If returns nil then checks if value is the same Object and returns a boolean.
	@param value: any - Value to compare Object to
	-> nil|boolean
			
	BaseObject.objectAdd(value) - Is called when trying to use + operator on Object and value. Returns nil by default.
	@param value: any - Value to add to Object
	-> nil|any
	
	BaseObject.objectSub(value) - Is called when trying to use - operator on Object and value. Returns nil by default.
	@param value: any - Value to subtract from Object
	-> nil|any
				
	BaseObject.objectMul(value) - Is called when trying to use * operator on Object and value. Returns nil by default.
	@param value: any - Value to multiply Object by
	-> nil|any
	
	BaseObject.objectDiv(value) - Is called when trying to use / operator on Object and value. Returns nil by default.
	@param value: any - Value to divide Object by
	-> nil|any
		
	BaseObject.objectIdiv(value) - Is called when trying to use // operator on Object and value. Returns nil by default.
	@param value: any - Value to divide Object by
	-> nil|any
		
	BaseObject.objectMod(value) - Is called when trying to use % operator on Object and value. Returns nil by default.
	@param value: any - Value to divide Object by
	-> nil
		
	BaseObject.objectPow(value) - Is called when trying to use ^ operator on Object and value. Returns nil by default.
	@param value: any - Value (exponent)
	-> nil
		
	BaseObject.objectLT(value) - Is called when trying to use < operator on Object and value. Returns nil by default.
	@param value: any - Value to compare Object with
	-> nil
		
	BaseObject.objectLE(value) - Is called when trying to use <= operator on Object and value. Returns nil by default.
	@param value: any - Value to compare Object with
	-> nil
	
	
	
	
	
	Classificator.new(ClassName, super) - Creates a new class with the name {ClassName} that inherits from {super}
	@param ClassName: string - Name of the class to create
	@param super: BaseClass - Class that the class will inherit from. Can be nil.
	-> BaseClass
	* To define an object initializer, define a Class function called 'init'. It will be called when Class.new() is called.
	* To define a class attribute, simply set Class' index to a value. Attributes can be accessed by indexing Class or Class.Attributes.
	* To define a class method, simply set Class' index to a function. Methods can be accessed by indexing Class or Class.Methods.
]]

local Classificator = {}
local TableUtils = require(script.TableUtils)

-- Defining types
export type BaseClass<Super> = {
	ClassName: string, Attributes: {}, Methods: {}, AttributeChanged: BindableEvent,
	super: () -> Super, IsSubclass: ({}, string) -> boolean, new: (class: BaseClass<Super>, any, any, any, any, any, any, any, any, any, any, any) -> BaseObject<(BaseClass<Super>)>,
	init: (BaseObject<BaseClass<Super>>) -> nil
} & Super
export type BaseObject<classtype> = {
	Class: classtype, Identifier: number, Properties: {}, Methods: {}, PropertyChanged: BindableEvent,
	propSetter: (index: string|number, value: any) -> nil, propGetter: (index: string|number) -> any,
	propDeleter: (index: string|number) -> nil, objectEqual: (value: any) -> nil|any, objectLT: (value: any) -> nil|any,
	objectLE: (value: any) -> nil|any, objectAdd: (value: any) -> nil|any, objectSub: (value: any) -> nil|any, objectMul: (value: any) -> nil|any,
	objectDiv: (value: any) -> nil|any, objectIdiv: (value: any) -> nil|any, objectMod: (value: any) -> nil|any,
	objectPow: (value: any) -> nil|any, objectCall: (arg1: any, arg2: any, arg3: any, arg4: any, arg5: any) -> nil|any
}
local BaseClass: BaseClass<nil>

-- 	 Private
-- OVERRIDE_WARN: boolean - If true, warns if an object's method gets overriden
-- ReservedFunctions: table - DON'T TOUCH!!!
-- LockedClasses: table - DON'T TOUCH!!! Stores keys of locked classes. Locked class is a class that's attributes and methods can't be changed.
-- lastId: number - DON'T TOUCH!!! Used to identify objects. 
-- Classes: table - DON'T TOUCH!!! Stores all classes. To get a needed class prefer using a ModuleScript that returns the specific class.
local OVERRIDE_WARN = true
local ReservedFunctions = {
	"init", "propSetter", "propGetter", "propDeleter", "objectLE", "objectLT", "objectPow", "objectMod", "objectIdiv", "objectDiv",
	"objectMul", "objectSub", "objectAdd", "objectEqual", "objectCall"
}
local LockedClasses = {"BaseClass"}
local lastId = 1
local Classes = {}

local function newClass<Super>(ClassName: string, super: Super): BaseClass<Super>
	if type(ClassName) ~= "string" then error(`ClassName must be a string. {type(ClassName)} provided instead.`) end
	if not ClassName then error(`ClassName can't be omitted.`) end
	if Classes[ClassName] then error(`Class with name {ClassName} already exists.`) end
	if super and not super.ClassName then error(`Super is not a class.`) end
	type Super = Super | typeof(super)
	-- If super is omitted, super is set to BaseClass
	local inheritFrom = super or BaseClass or nil
	local newClass = {}
	newClass.ClassName = ClassName
	newClass.Attributes = {}
	newClass.Methods = {}
	newClass.AttributeChanged = Instance.new("BindableEvent")
	
	local function BaseInit<type1>(tbl: type1, ...)
		if not tbl then error("tbl cannot be nil") return end
		if type(tbl) ~= "table" then error("tbl must be an Object.") return end
		if not tbl.Class then error("tbl is a class") return end
		newClass.init(tbl, ...)
	end
	
	function newClass:new(...: any): BaseObject<typeof(self)>
		local object: BaseObject<typeof(self)> = {
			Class = self,
			Identifier = lastId+1,
			Properties = {},
			Methods = {},
			PropertyChanged = Instance.new("BindableEvent")
		} 

		lastId+=1
		
		local function BaseEqual(value)
			if type(value) ~= "table" then return false end
			if not object.Identifier or not value.Identifier then return false end
			return object.Identifier == value.Identifier
		end
		
		object = setmetatable(object, {
			__metatable = object,
			__newindex = function(tbl, index, value)
				if type(value) == "function" then
					if not table.find(ReservedFunctions, index) and tbl.Methods[index] and OVERRIDE_WARN then warn(`{index} is an overriden method`) end
					rawset(tbl.Methods, index, value)
					return
				end
				if tbl.Methods[index] then 
					if table.find(ReservedFunctions, index) then
						error(`{index} must be a function. {type(value)} provided instead`)
					end
					rawset(tbl.Methods, index, nil) 
				end
				if value ~= nil then tbl.propSetter(index, value) else tbl.propDeleter(index) end
				tbl = tbl :: typeof(tbl)
				tbl.PropertyChanged:Fire(index)
			end,
			__index = function(tbl, index)
				local self: BaseClass = tbl
				local methods = rawget(tbl, "Methods")
				local class = rawget(tbl, "Class")
				if table.find({"Properties", "Methods"}, index) then
					return rawget(tbl, index)
				end
				return rawget(tbl, index) or 
					rawget(methods, index) or 
					rawget(methods, "propGetter")(index) or 
					class[index]
			end,
			__eq = function(tbl, value)
				return tbl.objectEqual(value) or BaseEqual(value)
			end,
			__tostring = function(tbl)
				return `Instance of {rawget(tbl, "Class")} ID {rawget(tbl, "Identifier")}`
			end,
			__add = function(tbl, value)
				return tbl.objectAdd(value)
			end,
			__sub = function(tbl, value)
				return tbl.objectSub(value)
			end,
			__mul = function(tbl, value)
				return tbl.objectMul(value)
			end,
			__div = function(tbl, value)
				return tbl.objectDiv(value)
			end,
			__idiv = function(tbl, value)
				return tbl.objectIdiv(value)
			end,
			__mod = function(tbl, value)
				return tbl.objectMod(value)
			end,
			__pow = function(tbl, value)
				return tbl.objectPow(value)
			end,
			__lt = function(tbl, value)
				return tbl.objectLT(value)
			end,
			__le = function(tbl, value)
				return tbl.objectLE(value)
			end,
			__call = function(tbl, ...)
				return tbl.objectCall(...)
			end,
		})
		
		function object.propGetter(index)
			return rawget(rawget(object, "Properties"), index)
		end
		
		function object.propSetter(index, value)
			rawset(rawget(object, "Properties"), index, value)
		end
		
		function object.propDeleter(index)
			rawset(rawget(object, "Properties"), index, nil)
		end
		
		function object.objectEqual(value)
			return
		end
		
		function object.objectAdd(value)
			return
		end
		
		function object.objectSub(value)
			return
		end
		
		function object.objectMul(value)
			return
		end
		
		function object.objectDiv(value)
			return
		end
		
		function object.objectIdiv(value)
			return
		end
		
		function object.objectMod(value)
			return
		end
		
		function object.objectPow(value)
			return
		end
		
		function object.objectLT(value)
			return
		end
		
		function object.objectLE(value)
			return
		end
		
		function object.objectCall(...)
			return
		end
		
		BaseInit(object, ...)
		return object :: BaseObject<typeof(self)>
	end
	
	newClass = setmetatable(newClass, {
		__newindex = function(tbl, index, value)
			if type(value) == "function" then
				rawset(tbl.Methods, index, value)
				return
			end
			if tbl.Methods[index] then 
				if table.find(ReservedFunctions, index) then
					error(`{index} must be a function. {type(value)} provided instead.`) return
				end
				rawset(tbl.Methods, index, nil) 
			end
			rawset(tbl.Attributes, index, value)
			tbl.AttributeChanged:Fire(index)
		end,
		__index = function(tbl, index)
			return rawget(tbl, index) or rawget(tbl.Methods, index) or rawget(tbl.Attributes, index) or (if tbl.super() then tbl.super()[index] else nil)
		end,
		__call = function(tbl, ...): BaseObject
			return tbl.new(...) :: BaseObject
		end,
		__eq = function(tbl: BaseClass, value: BaseClass)
			if type(value) ~= "table" then return false end
			if not tbl.ClassName or not value.ClassName then return false end
			return tbl.ClassName == value.ClassName
		end,
		__tostring = function(tbl)
			return tbl.ClassName
		end
	}
	)
	
	function newClass.super(): Super
		return inheritFrom :: Super
	end

	function newClass:IsSubclass(ClassName: string)
		local self: BaseClass = self
		local super: Super|BaseClass|nil = self:super()
		return if super then (self.ClassName == ClassName or super:IsSubclass(ClassName)) else self.ClassName == ClassName
	end
	
	function newClass.init<type1>(tbl: type1)
		return
	end
	
	newClass = setmetatable(newClass, {
		__metatable = newClass,
		__newindex = function(tbl, index, value)
			if table.find(LockedClasses, tbl.ClassName) then
				error(`Can't set attribute {index} to {value}: {tbl.ClassName} is locked and can't be modified.`)
			end
			if type(value) == "function" then
				rawset(tbl.Methods, index, value)
				return
			end
			if tbl.Methods[index] then 
				if table.find(ReservedFunctions, index) then
					error(`{index} must be a function. {type(value)} provided instead.`) return
				end
				rawset(tbl.Methods, index, nil) 
			end
			rawset(tbl.Attributes, index, value)
			tbl.AttributeChanged:Fire(index)
		end,
		__index = function(tbl, index)
			return rawget(tbl, index) or rawget(tbl.Methods, index) or rawget(tbl.Attributes, index) or (if tbl.super() then tbl.super()[index] else nil)
		end,
		__call = function(tbl, ...): BaseObject
			return tbl.new(...) :: BaseObject
		end,
		__eq = function(tbl: BaseClass, value: BaseClass)
			if type(value) ~= "table" then return false end
			if not tbl.ClassName or not value.ClassName then return false end
			return tbl.ClassName == value.ClassName
		end,
		__tostring = function(tbl)
			return tbl.ClassName
		end
	}
	)
	
	Classes[ClassName] = newClass
	
	return newClass :: BaseClass<Super> & typeof(newClass)
end

-- public
function Classificator.new<Super>(ClassName: string, super: Super): BaseClass<Super>
	return newClass(ClassName, super) :: BaseClass<Super>
end

-- Returns an object of BaseClass. Use tbl arguments to pass methods and functions within it
function Classificator.newObject<incoming>(tbl: incoming|nil): BaseObject<typeof(BaseClass)> & incoming
	local object = BaseClass:new()
	local methods = {}
	if tbl then
		if type(tbl) ~= "table" then
			error("tbl must be a table.")
			return
		end
	end
	local function popFunctions(tbl)
		for i, k in pairs(tbl) do
			if type(k) == "function" then
				methods[i] = k
				tbl[i] = nil
			elseif type(k) == "table" then
				popFunctions(k)
			end
		end
	end
	if methods then 
		for i, k in methods do
			object[i] = k
		end
	end
	if tbl then 
		for i, k in pairs(tbl) do
			if type(k) == "table" then
				object[i] = TableUtils.Copy(k, true)
			else
				object[i] = k
			end
		end
	end
	return object :: BaseObject<typeof(BaseClass)> & incoming
end

function Classificator.IsClass(value)
	return typeof(value) == "table" and rawget(value, "ClassName")
end

function Classificator.IsObject(value)
	return typeof(value) == "table" and value.Identifier and value.Class and not Classificator.IsClass(value)
end

function Classificator.IsObjectOfClass(value, classname: string)
	return Classificator.IsObject(value) and Classes[classname] == value.Class
end

-- Locks class from adding and modifying attributes and methods normally
-- Using rawset() however still works
function Classificator.LockClass(class: BaseClass)
	if not Classificator.IsClass(class) then error(`Can't lock non-class value. {type(class)} provided instead.`) return end
	if table.find(LockedClasses, class.ClassName) then error(`Class {class} is already locked. This can't be undone`) return end
	table.insert(LockedClasses, class.ClassName)
end

-- defining base class
BaseClass = Classificator.new("BaseClass")
Classificator.newObject({a = 1, b = 2, e = 3})

table.freeze(Classificator)
return Classificator
