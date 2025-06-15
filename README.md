# Classificator - New Roblox OOP posibilities
==========================================================

Classificator is an OOP based module, providing similar experience to Python's OOP. Classificator includes classes, subclasses, objects and has next features:
- Simple process of defining classes
- Inheritance and manual initialization of super classes
- Opportunity to define custom initializers and metamethods
- Using proxy tables to bypass __newindex restrictions

==========================================================
# How does it work?
- Classificator starts from defining a class. To do that you use Classificator.new(name: string, super: Class). Omitting super parameter inherits from BaseClass instead. Note that you can't define 2 classes with same name.
- After defining a class, we can define an initializer by defining Class.init(tbl: Object, ...) function. Inside initializer we put properties and methods that we can use later. Providing parameters is optional, but parameters define behavior of your objects. Inside initializer we can also define custom metamethods. For example we can define Object.propSetter(index: string, value: any) to create a custom setter for an Object.
- To create an object of a class we use Class:new(...), where ... is a tuple of parameters for initializer, returns an Object. To access an Object's properties we can index either the Object or Object.Properties (Note that methods are stored in Object.Methods).
- If you want to have shared properties or methods for all objects of a class you can use class Attributes. To access a Class' attributes we can index either Class or Class.Attributes (Note that class methods are stored in Class.Methods), but note that indexing an Object works too if the Object.Properties doesn't have a specified index.



