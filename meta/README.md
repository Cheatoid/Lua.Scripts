# LuaMeta Documentation

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
    - [The luameta Global](#the-luameta-global)
    - [Registry](#registry)
    - [Global Registration](#global-registration)
    - [Class Descriptor Versus Class Table](#class-descriptor-versus-class-table)
    - [Snapshot Composition](#snapshot-composition)
- [Module Reference](#module-reference)
    - [init.lua](#initlua)
    - [trait.lua](#traitlua)
    - [class.lua](#classlua)
    - [namespace.lua](#namespacelua)
    - [trait_utils.lua](#trait_utilslua)
- [Traits](#traits)
    - [Creating Traits](#creating-traits)
    - [Trait Methods, Statics, and Metas](#trait-methods-statics-and-metas)
    - [Trait Composition](#trait-composition)
    - [Implementing Traits in Classes](#implementing-traits-in-classes)
    - [Filtering and Aliasing](#filtering-and-aliasing)
- [Classes](#classes)
    - [Creating Classes](#creating-classes)
    - [Constructors](#constructors)
    - [Methods](#methods)
    - [Statics](#statics)
    - [Metamethods](#metamethods)
    - [Inheritance](#inheritance)
    - [Abstract Classes](#abstract-classes)
    - [Final Classes and Final Methods](#final-classes-and-final-methods)
    - [Properties](#properties)
    - [Destructors](#destructors)
    - [Anonymous Classes](#anonymous-classes)
- [Namespaces](#namespaces)
    - [Creating Namespaces](#creating-namespaces)
    - [Including Objects in Namespaces](#including-objects-in-namespaces)
    - [Nested Namespaces](#nested-namespaces)
    - [Namespace Resolution](#namespace-resolution)
- [Instance Runtime Features](#instance-runtime-features)
    - [clone](#clone)
    - [class](#class)
    - [isA](#isa)
    - [super](#super)
    - [private](#private)
- [Resolution Rules](#resolution-rules)
- [Conflict and Priority Rules](#conflict-and-priority-rules)
- [Protected and Reserved Fields](#protected-and-reserved-fields)
- [Error Reference](#error-reference)
- [Examples](#examples)
- [Compatibility and Limitations](#compatibility-and-limitations)
- [License](#license)

---

## Overview

LuaMeta is a Lua library that provides a structured object model built on top of metatables. It adds support for classes, traits, namespaces, inheritance, abstract classes, final methods, properties, private state, constructors, destructors, and trait based composition.

The library is organized into five files:

| File              | Purpose                                                                                 |
| ----------------- | --------------------------------------------------------------------------------------- |
| `init.lua`        | Entry point. Loads all modules and creates the global `luameta` object.                 |
| `class.lua`       | Class creation, inheritance, methods, statics, properties, abstract and final behavior. |
| `trait.lua`       | Trait creation, trait composition, and trait implementation.                            |
| `namespace.lua`   | Namespace creation, nested namespaces, and object inclusion.                            |
| `trait_utils.lua` | Internal helpers for trait collection, matching, and namespace resolution.              |

The entry point is `init.lua`. Individual modules expect the global `luameta` object to already exist, so they should not be required directly before `init.lua`.

---

## Features

- Class creation with a fluent builder style API
- Single inheritance with `extends`
- Multiple constructors per class
- Constructor chaining from ancestor to descendant
- Static members on classes
- Instance methods
- Metamethod control
- Abstract classes and abstract methods
- Final classes and final methods
- Traits as reusable method, static, and metamethod containers
- Trait composition
- Trait filtering with `only` and `except`
- Trait method aliasing
- Namespaces and nested namespaces
- Instance cloning
- Instance type checking with `isA`
- Controlled parent access with `super`
- Per instance private storage
- Property getters and setters
- Optional global registration
- Central registry for classes, traits, and namespaces

---

## Naming Convention

Canonical API names use `camelCase`. Deprecated `snake_case` aliases are kept for
compatibility and delegate to the `camelCase` implementation. New code should use
`camelCase` (e.g. `pushGlobal` not `push_global`, `popGlobal` not `pop_global`,
`newEntity` not `new_entity`, `addComponent` not `add_component`, `isClass` not
`is_class`).

---

## Requirements

LuaMeta is written for Lua environments that support standard metatables.

The code includes fallbacks for environments where `table.pack` and `table.unpack` are not available.

Destructors use the `__gc` metamethod. Full destructor support requires a Lua runtime that calls `__gc` for tables, such as Lua 5.4 or a compatible runtime.

---

## Installation

Place the following files in a directory that is visible to your Lua `package.path`:

```text
init.lua
class.lua
trait.lua
namespace.lua
trait_utils.lua
```

Then require the entry point:

```lua
local luameta = require "init"
```

You can then access the main factories:

```lua
local class = luameta.class
local trait = luameta.trait
local namespace = luameta.namespace
```

---

## Quick Start

```lua
local luameta = require "init"

local class = luameta.class
local trait = luameta.trait

trait "Timestamped"
    :method {
        touch = function(self)
            self.updated_at = os.time()
            return self
        end,
    }

local Post = class "Post"
    :implements("Timestamped")
    :constructor(function(self, title)
        self.title = title
        self:touch()
    end)
    :method {
        display = function(self)
            return string.format("%s updated at %s", self.title, tostring(self.updated_at))
        end,
    }

local post = Post("Hello World")

print(post:display())
```

---

## Core Concepts

### The luameta Global

When `init.lua` is required, it creates or reuses a global table named `luameta`.

```lua
_G.luameta = {
    config = {
        registerGlobally = true,
    },
    registry = {
        classes = {},
        traits = {},
        namespaces = {},
    },
}
```

After loading, `luameta` contains:

```lua
luameta.class
luameta.trait
luameta.namespace
luameta.config
luameta.registry
```

### Registry

LuaMeta keeps named objects in a central registry.

```lua
luameta.registry.classes
luameta.registry.traits
luameta.registry.namespaces
```

These tables map names to registered objects.

You can retrieve registered objects with:

```lua
luameta.class.get("MyClass")
luameta.trait.get("MyTrait")
luameta.namespace.get("MyNamespace")
```

Nested namespaces are registered by full path:

```lua
luameta.namespace.get("App.Models")
```

### Global Registration

By default, named classes, traits, and namespaces are registered globally.

```lua
luameta.config.registerGlobally = true
```

When enabled:

```lua
class("User")
trait("Timestamped")
namespace("Models")
```

creates global variables:

```lua
_G.User
_G.Timestamped
_G.Models
```

If you disable global registration:

```lua
luameta.config.registerGlobally = false
```

then you must keep references locally or use the registry.

```lua
local User = class("User")
local Timestamped = trait("Timestamped")
local Models = namespace("Models")
```

Anonymous classes are not registered globally.

Including a class, trait, or namespace into a namespace removes its global variable when global registration is enabled.

### Class Descriptor Versus Class Table

Calling `class("Name")` returns a class descriptor.

```lua
local User = class("User")
```

The descriptor is used for building the class:

```lua
User:constructor(function(self) end)
User:method { hello = function(self) end }
```

The class table is the public class object. It holds statics and is used for instantiation.

When global registration is enabled:

```lua
class("User")
```

creates a global class table named `User`.

Both the descriptor and the class table can usually be used to create instances:

```lua
local User = class("User")

local a = User()
local b = _G.User()
```

The class table has an `origin` field that points back to the descriptor.

```lua
local descriptor = User.origin
```

The descriptor has a `class` field that points to the class table.

```lua
local classTable = User.class
```

### Snapshot Composition

When a class implements a trait, or when a trait implements another trait, members are copied into the target.

This is a snapshot operation.

If the trait changes later, classes and traits that already implemented it are not automatically updated.

---

## Module Reference

### init.lua

`init.lua` is the required entry point.

```lua
local luameta = require "init"
```

It returns the `luameta` table.

Returned fields:

| Field                     | Type           | Description                                           |
| ------------------------- | -------------- | ----------------------------------------------------- |
| `config`                  | table          | Configuration values.                                 |
| `config.registerGlobally` | boolean        | Controls global registration. Default is `true`.      |
| `registry`                | table          | Central registry for classes, traits, and namespaces. |
| `class`                   | callable table | Class factory.                                        |
| `trait`                   | callable table | Trait factory.                                        |
| `namespace`               | callable table | Namespace factory.                                    |

### trait.lua

The trait module returns a callable trait factory.

```lua
local trait = luameta.trait
```

Main API:

| API               | Description                             |
| ----------------- | --------------------------------------- |
| `trait(name)`     | Creates and registers a new trait.      |
| `trait.is(value)` | Returns `true` if the value is a trait. |
| `trait.get(name)` | Returns a registered trait by name.     |

Trait object API:

| Method                   | Description                             |
| ------------------------ | --------------------------------------- |
| `trait:method(map)`      | Adds methods to the trait.              |
| `trait:static(map)`      | Adds static values to the trait.        |
| `trait:meta(map)`        | Adds metamethods to the trait.          |
| `trait:implements(spec)` | Composes another trait into this trait. |

Trait objects expose their static values through indexing:

```lua
local MyTrait = trait("MyTrait")

MyTrait:static {
    version = "1.0.0",
}

print(MyTrait.version)
```

### class.lua

The class module returns a callable class factory.

```lua
local class = luameta.class
```

Main API:

| API                          | Description                                                               |
| ---------------------------- | ------------------------------------------------------------------------- |
| `class(name)`                | Creates and registers a named class.                                      |
| `class()`                    | Creates an anonymous class.                                               |
| `class.is(instance, target)` | Checks whether an object is an instance of a class or implements a trait. |
| `class.get(name)`            | Returns a class descriptor by name.                                       |
| `class.isClass(value)`       | Returns `true` if the value is a class table.                             |

Class descriptor builder API:

| Method                   | Description                              |
| ------------------------ | ---------------------------------------- |
| `class:constructor(fn)`  | Adds a constructor.                      |
| `class:extends(parent)`  | Sets the parent class.                   |
| `class:static(map)`      | Adds static members to the class table.  |
| `class:method(map)`      | Adds instance methods.                   |
| `class:meta(map)`        | Adds metamethods to the class metatable. |
| `class:implements(spec)` | Implements a trait.                      |
| `class:abstract(spec)`   | Marks the class as abstract.             |
| `class:final()`          | Marks the class as final.                |
| `class:finalMethod(map)` | Adds final methods.                      |
| `class:destructor(fn)`   | Sets a destructor.                       |
| `class:property(map)`    | Defines property getters and setters.    |

### namespace.lua

The namespace module returns a callable namespace factory.

```lua
local namespace = luameta.namespace
```

Main API:

| API                            | Description                                 |
| ------------------------------ | ------------------------------------------- |
| `namespace(name)`              | Creates and registers a namespace.          |
| `namespace.get(name)`          | Returns a namespace by name or full path.   |
| `namespace.isNamespace(value)` | Returns `true` if the value is a namespace. |

Namespace object API:

| Method                     | Description                                      |
| -------------------------- | ------------------------------------------------ |
| `namespace:include(table)` | Includes classes, traits, namespaces, or values. |
| `namespace:nested(path)`   | Creates or retrieves a nested namespace.         |

### trait_utils.lua

This module contains internal helper functions used by the class and trait systems.

```lua
local traitUtils = require "trait_utils"
```

Exported functions:

| Function                                             | Description                                                  |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| `collectTraitMethods(trait, seen)`                   | Collects methods from a trait and its composed traits.       |
| `collectTraitStatics(trait, seen)`                   | Collects statics from a trait and its composed traits.       |
| `collectTraitMetas(trait, seen)`                     | Collects metamethods from a trait and its composed traits.   |
| `traitMatches(trait, target, seen)`                  | Checks whether a trait matches a target trait or trait name. |
| `resolveFromNamespaces(name, validator, namespaces)` | Resolves a name from registered namespaces.                  |

These utilities are mostly internal, but they are useful for tooling and debugging.

---

## Traits

### Creating Traits

```lua
local trait = luameta.trait

local Serializable = trait("Serializable")
```

A trait has the following internal member tables:

```lua
Serializable.methods
Serializable.statics
Serializable.metas
Serializable.traits
Serializable.name
```

### Trait Methods, Statics, and Metas

Traits can contain methods, static values, and metamethods.

```lua
local Serializable = trait("Serializable")

Serializable:method {
    serialize = function(self)
        return "serialized:" .. tostring(self)
    end,
}

Serializable:static {
    serializationVersion = "1.0.0",
}

Serializable:meta {
    __tostring = function(self)
        return "SerializableObject"
    end,
}
```

Methods are intended for instances of classes that implement the trait.

Statics are copied to the class table when a class implements the trait.

Metas are copied to the class metatable when a class implements the trait, with some core metamethods excluded.

### Trait Composition

A trait can implement another trait.

```lua
local Eq = trait("Eq")

Eq:method {
    equals = function(self, other)
        return self.value == other.value
    end,
}

local Inspect = trait("Inspect")

Inspect:implements(Eq)

Inspect:method {
    inspect = function(self)
        return "value: " .. tostring(self.value)
    end,
}
```

A class implementing `Inspect` receives both `inspect` and `equals`.

### Implementing Traits in Classes

```lua
local class = luameta.class
local trait = luameta.trait

local Timestamped = trait("Timestamped")

Timestamped:method {
    touch = function(self)
        self.updated_at = os.time()
        return self
    end,
}

local Post = class("Post")

Post:implements(Timestamped)
```

The trait may be provided as:

```lua
Post:implements(Timestamped)
```

or by name:

```lua
Post:implements("Timestamped")
```

or through a specification table:

```lua
Post:implements {
    trait = Timestamped,
}
```

### Filtering and Aliasing

Trait implementation supports `only`, `except`, and `alias`.

#### only

Include only selected methods:

```lua
Post:implements {
    trait = Timestamped,
    only = {"touch"},
}
```

#### except

Exclude selected methods:

```lua
Post:implements {
    trait = Timestamped,
    except = {"touch"},
}
```

#### alias

Rename methods during implementation:

```lua
Post:implements {
    trait = Timestamped,
    alias = {
        touch = "timestampTouch",
    },
}
```

Aliasing applies to methods. It does not rename statics or metamethods.

---

## Classes

### Creating Classes

```lua
local class = luameta.class

local User = class("User")
```

You can also create a class and keep only the local descriptor:

```lua
local User = class("User")
```

If global registration is enabled, a global class table named `User` is also created.

### Constructors

A class may have one or more constructors.

```lua
local User = class("User")

User:constructor(function(self, name)
    self.name = name
end)

User:constructor(function(self, name)
    self.createdAt = os.time()
end)
```

Constructors are called in the order they are defined.

When inheritance is used, constructors run from the top ancestor down to the final class.

```lua
local Base = class("Base")

Base:constructor(function(self, x)
    self.x = x
end)

local Child = class("Child")

Child:extends(Base)

Child:constructor(function(self, x, y)
    self.y = y
end)

local obj = Child(1, 2)
```

In this example, the `Base` constructor runs first, then the `Child` constructor.

All constructors receive the same arguments passed during instantiation.

### Methods

Methods are added with `method`.

```lua
local User = class("User")

User:method {
    getName = function(self)
        return self.name
    end,

    setName = function(self, name)
        self.name = name
        return self
    end,
}
```

Methods are stored in the class descriptor and resolved through the inheritance chain.

### Statics

Statics are added with `static`.

```lua
local MathUtil = class("MathUtil")

MathUtil:static {
    PI = 3.14159,

    add = function(a, b)
        return a + b
    end,
}

print(MathUtil.PI)
print(MathUtil.add(2, 3))
```

Statics live on the class table.

Static members are inherited through the class table lookup chain.

### Metamethods

Metamethods can be added with `meta`.

```lua
local Vector = class("Vector")

Vector:constructor(function(self, x, y)
    self.x = x
    self.y = y
end)

Vector:meta {
    __add = function(a, b)
        return Vector(a.x + b.x, a.y + b.y)
    end,

    __tostring = function(self)
        return string.format("Vector(%s, %s)", self.x, self.y)
    end,
}
```

Some metamethods are reserved and cannot be set through `meta`:

```text
__index
__newindex
__call
__gc
__classdesc
__metatable
__mode
```

Use `destructor` for `__gc`.

### Inheritance

Use `extends` to inherit from another class.

```lua
local Animal = class("Animal")

Animal:constructor(function(self, name)
    self.name = name
end)

Animal:method {
    speak = function(self)
        return self.name .. " makes a sound"
    end,
}

local Dog = class("Dog")

Dog:extends(Animal)

Dog:method {
    speak = function(self)
        return self.name .. " barks"
    end,
}
```

A class can extend only one parent.

The parent may be passed as:

```lua
Dog:extends(Animal)
```

or by name:

```lua
Dog:extends("Animal")
```

Inheritance cannot be changed after instances have been created.

### Abstract Classes

Use `abstract` to mark a class as abstract.

```lua
local Shape = class("Shape")

Shape:abstract {
    "area",
}

Shape:method {
    describe = function(self)
        return "area: " .. tostring(self:area())
    end,
}
```

Abstract classes cannot be instantiated until their abstract methods are implemented in the class or in a descendant.

```lua
local Square = class("Square")

Square:extends(Shape)

Square:constructor(function(self, side)
    self.side = side
end)

Square:method {
    area = function(self)
        return self.side * self.side
    end,
}
```

Now:

```lua
local square = Square(4)
print(square:describe())
```

This works, while:

```lua
Shape()
```

raises an error.

You can also mark a class as explicitly abstract without listing method names:

```lua
local Base = class("Base")

Base:abstract()
```

An explicit abstract class without abstract method names cannot be instantiated directly, but descendants may become instantiable if no unresolved abstract methods remain.

### Final Classes and Final Methods

A final class cannot be extended.

```lua
local Point = class("Point")

Point:final()
```

A final method cannot be overridden by child classes or trait implementation.

```lua
local Base = class("Base")

Base:finalMethod {
    identity = function(self)
        return "base-identity"
    end,
}
```

Child classes cannot redefine `identity`.

### Properties

Properties define controlled getters and setters.

```lua
local Person = class("Person")

Person:property {
    name = {
        get = function(self)
            return rawget(self, "_name")
        end,

        set = function(self, value)
            rawset(self, "_name", tostring(value))
        end,
    },
}
```

Usage:

```lua
local person = Person()

person.name = "Alice"
print(person.name)
```

Property getters are consulted only when the instance does not already have a raw field with that key.

To create a read only property, provide a setter that raises an error:

```lua
Person:property {
    id = {
        get = function(self)
            return rawget(self, "_id")
        end,

        set = function(self, value)
            error("id is read only", 2)
        end,
    },
}
```

Avoid giving a property the same name as a method. Method lookup happens before property getter lookup during reads.

### Destructors

A destructor is set with `destructor`.

```lua
local Resource = class("Resource")

Resource:destructor(function(self)
    print("Resource is being collected")
end)
```

This sets the `__gc` metamethod.

Destructors must be defined before instances are created.

Destructor behavior depends on the Lua runtime supporting `__gc` for tables.

### Anonymous Classes

A class can be created without a name:

```lua
local Anonymous = class()
```

Anonymous classes receive generated internal names such as:

```text
anon1
anon2
anon3
```

They are not registered as global variables.

They are still stored in the class registry.

---

## Namespaces

### Creating Namespaces

```lua
local namespace = luameta.namespace

local Models = namespace("Models")
```

If global registration is enabled, this creates:

```lua
_G.Models
```

### Including Objects in Namespaces

Use `include` to move classes, traits, namespaces, or plain values into a namespace.

```lua
local Models = namespace("Models")

local User = class("User")

Models:include {
    User,
}
```

After inclusion, the class is available as:

```lua
Models.User
```

If global registration was enabled, the global `User` is removed.

You can include multiple objects:

```lua
local Post = class("Post")
local Comment = class("Comment")

Models:include {
    User,
    Post,
    Comment,
}
```

You can also include named values:

```lua
Models:include {
    version = "1.0.0",
}
```

### Nested Namespaces

Use `nested` to create nested namespaces.

```lua
local App = namespace("App")

local Models = App:nested("Models")
```

This creates:

```lua
App.Models
```

Nested namespaces are registered by full path:

```lua
luameta.namespace.get("App.Models")
```

You can create deeper paths:

```lua
local Admin = App:nested("Areas.Admin")
```

This creates:

```lua
App.Areas
App.Areas.Admin
```

### Namespace Resolution

Classes and traits can resolve names through their assigned namespace chain.

If a class belongs to a namespace, string based lookups such as `extends` and `implements` search that namespace and its parent namespaces before searching globals.

---

## Instance Runtime Features

Instances created from LuaMeta classes have several built in helpers.

### clone

Creates a shallow copy of an instance.

```lua
local copy = obj:clone()
```

Behavior:

- Copies raw instance fields.
- Copies the private store shallowly.
- Does not rerun constructors.
- Does not copy the internal `super_host` field.

### class

Returns the class table of the instance.

```lua
local classTable = obj.class
```

### isA

Checks whether an instance belongs to a class, inherits from a class, or implements a trait.

```lua
obj:isA(Dog)
obj:isA("Animal")
obj:isA(SomeTrait)
```

The target may be:

- A class table
- A class descriptor
- A class name
- A trait
- A trait name

### super

Provides access to parent methods.

```lua
local Base = class("Base")

Base:method {
    greet = function(self)
        return "base greeting"
    end,
}

local Child = class("Child")

Child:extends(Base)

Child:method {
    greet = function(self)
        return self:super():greet() .. " and child greeting"
    end,
}
```

The `super` helper returns a proxy object that resolves methods from the parent chain.

### private

Returns a private storage table for the instance.

```lua
local Counter = class("Counter")

Counter:method {
    increment = function(self)
        local priv = self:private()
        priv.count = (priv.count or 0) + 1
        return priv.count
    end,
}
```

The private store is kept in a weak keyed table. The store is associated with the instance object.

Private state is not truly enforced by the language, but it is kept out of normal instance fields.

---

## Resolution Rules

### Trait Resolution for implements

When `implements` receives a string, LuaMeta searches in this order:

1. The current namespace chain of the class or trait.
2. The global table `_G`.
3. All registered namespaces, sorted by namespace key.
4. The trait registry `luameta.registry.traits`.

### Class Resolution for extends

When `extends` receives a string, LuaMeta searches in this order:

1. The current namespace chain of the class.
2. The global table `_G`.
3. All registered namespaces, sorted by namespace key.
4. The class registry `luameta.registry.classes`.

### Instance Read Resolution

When reading a key from an instance, LuaMeta checks:

1. Raw fields stored directly on the instance.
2. Methods from the class descriptor and its parent chain.
3. Property getters from the class descriptor and its parent chain.
4. Built in helpers:
    - `clone`
    - `class`
    - `isA`
    - `super`
    - `private`

### Instance Write Resolution

When writing a key to an instance, LuaMeta checks:

1. Protected fields.
2. Property setters in the class descriptor and its parent chain.
3. Raw assignment using `rawset`.

### Class Table Read Resolution

When reading from a class table, LuaMeta checks:

1. Raw fields on the class table.
2. Static fields from ancestor class tables.

---

## Conflict and Priority Rules

### Trait Member Collection

When collecting members from a trait and its composed traits:

1. Members defined directly on the trait take priority.
2. If a member is missing, composed traits are searched.
3. Earlier composed traits take priority over later composed traits for the same key.

### Trait Implementation Conflicts

When implementing a trait into a class:

- Static members conflict if the class table already has that key.
- Methods conflict if the class or its parent chain already defines that method.
- Metamethods conflict if the class metatable already defines that key.
- Final methods cannot be overridden.
- Core metamethods such as `__index` and `__newindex` are not copied from traits into classes.

Use `only`, `except`, or `alias` to resolve conflicts.

### Class Method Conflicts

Adding a method with `method` silently replaces a method on the same class.

However, you cannot override a final method from a parent class.

### Trait Composition Conflicts

When a trait implements another trait:

- Static conflicts raise an error.
- Method conflicts raise an error.
- Meta conflicts raise an error.

Use filtering or aliasing in the specification table to avoid conflicts.

---

## Protected and Reserved Fields

### Class Descriptor Protected Fields

The following fields cannot be assigned directly on a class descriptor:

```text
origin
name
```

### Class Table and Instance Protected Fields

The following fields are protected during assignment:

```text
class
super_host
```

For class tables, the following class fields are also protected:

```text
origin
name
```

### Static Reserved Fields

The following fields cannot be set through `static`:

```text
origin
name
class
metatable
parent
methods
traits
hasAbstracts
abstractMethods
isFinal
finalMethods
inherited
properties
namespace
constructors
```

### Meta Reserved Fields

The following metamethods cannot be set through `meta`:

```text
__index
__newindex
__call
__gc
__classdesc
__metatable
__mode
```

---

## Error Reference

The following table lists common error conditions.

| Condition                            | Typical Cause                                                                           |
| ------------------------------------ | --------------------------------------------------------------------------------------- |
| Trait name must be a string          | `trait()` was called with a non string name.                                            |
| Trait already registered             | A trait with the same name already exists in `luameta.registry.traits`.                 |
| Global already declared              | A global variable with the same name already exists and global registration is enabled. |
| Not a trait                          | `implements` received a value that is not a trait.                                      |
| Circular trait dependency            | A trait attempted to implement itself or a trait that already contains it.              |
| Static conflict                      | A trait static member collides with an existing static member.                          |
| Method conflict                      | A trait method collides with an existing method.                                        |
| Meta conflict                        | A trait metamethod collides with an existing metamethod.                                |
| Class name is not valid              | `class()` received an invalid name.                                                     |
| Class already registered             | A class with the same name already exists in `luameta.registry.classes`.                |
| Cannot extend after instantiation    | `extends` was called after an instance of the class was created.                        |
| Class already inherited              | `extends` was called more than once on the same class.                                  |
| Circular inheritance                 | A class attempted to extend itself or one of its descendants.                           |
| Cannot inherit from final class      | The parent class is marked final.                                                       |
| Cannot override final method         | A method or trait attempted to override a final method.                                 |
| Cannot set protected field           | Assignment attempted to write a protected field.                                        |
| Cannot redeclare reserved metamethod | `meta` attempted to set a reserved metamethod.                                          |
| Cannot instantiate abstract class    | Instantiation was attempted on a class with unresolved abstract requirements.           |
| Destructor after instantiation       | `destructor` was called after instances were already created.                           |
| Property spec invalid                | A property definition is not a table or lacks `get` and `set`.                          |

---

## Examples

### Basic Class

```lua
local luameta = require "init"
local class = luameta.class

local User = class("User")

User:constructor(function(self, name)
    self.name = name
end)

User:method {
    greet = function(self)
        return "Hello, " .. self.name
    end,
}

local user = User("Alice")

print(user:greet())
```

### Inheritance and super

```lua
local luameta = require "init"
local class = luameta.class

local Entity = class("Entity")

Entity:constructor(function(self, id)
    self.id = id
end)

Entity:method {
    describe = function(self)
        return "Entity " .. tostring(self.id)
    end,
}

local Player = class("Player")

Player:extends(Entity)

Player:constructor(function(self, id, name)
    self.name = name
end)

Player:method {
    describe = function(self)
        return self:super():describe() .. ", Player " .. self.name
    end,
}

local player = Player(1, "Alice")

print(player:describe())
```

### Trait Composition

```lua
local luameta = require "init"
local class = luameta.class
local trait = luameta.trait

local Eq = trait("Eq")

Eq:method {
    equals = function(self, other)
        return self.id == other.id
    end,
}

local Timestamped = trait("Timestamped")

Timestamped:method {
    touch = function(self)
        self.updatedAt = os.time()
        return self
    end,
}

local Record = trait("Record")

Record:implements(Eq)
Record:implements(Timestamped)

local User = class("User")

User:implements(Record)

User:constructor(function(self, id)
    self.id = id
    self:touch()
end)

local a = User(1)
local b = User(1)

print(a:equals(b))
```

### Trait Aliasing

```lua
local luameta = require "init"
local class = luameta.class
local trait = luameta.trait

local Logger = trait("Logger")

Logger:method {
    log = function(self, message)
        print("[LOG]", message)
    end,
}

local Service = class("Service")

Service:implements {
    trait = Logger,
    alias = {
        log = "serviceLog",
    },
}

Service:method {
    run = function(self)
        self:serviceLog("service running")
    end,
}

local service = Service()

service:run()
```

### Abstract Class

```lua
local luameta = require "init"
local class = luameta.class

local Shape = class("Shape")

Shape:abstract {
    "area",
}

Shape:method {
    describe = function(self)
        return "Area is " .. tostring(self:area())
    end,
}

local Circle = class("Circle")

Circle:extends(Shape)

Circle:constructor(function(self, radius)
    self.radius = radius
end)

Circle:method {
    area = function(self)
        return math.pi * self.radius * self.radius
    end,
}

local circle = Circle(2)

print(circle:describe())
```

### Final Class

```lua
local luameta = require "init"
local class = luameta.class

local SingletonConfig = class("SingletonConfig")

SingletonConfig:final()

local ExtendedConfig = class("ExtendedConfig")

-- This raises an error:
-- ExtendedConfig:extends(SingletonConfig)
```

### Properties

```lua
local luameta = require "init"
local class = luameta.class

local Account = class("Account")

Account:property {
    balance = {
        get = function(self)
            return rawget(self, "_balance") or 0
        end,

        set = function(self, value)
            assert(type(value) == "number", "balance must be a number")
            rawset(self, "_balance", value)
        end,
    },
}

local account = Account()

account.balance = 100

print(account.balance)
```

### Private State

```lua
local luameta = require "init"
local class = luameta.class

local Token = class("Token")

Token:method {
    refresh = function(self)
        local priv = self:private()
        priv.counter = (priv.counter or 0) + 1
        return "token-" .. tostring(priv.counter)
    end,
}

local token = Token()

print(token:refresh())
print(token:refresh())
```

### Namespaces

```lua
local luameta = require "init"
local class = luameta.class
local namespace = luameta.namespace

local Models = namespace("Models")

local User = class("User")
local Post = class("Post")

Models:include {
    User,
    Post,
}

local user = Models.User()
local post = Models.Post()
```

### Nested Namespaces

```lua
local luameta = require "init"
local namespace = luameta.namespace

local App = namespace("App")

local Models = App:nested("Models")
local Services = App:nested("Services")

Models.name
Services.name
```

### Destructor

```lua
local luameta = require "init"
local class = luameta.class

local FileHandle = class("FileHandle")

FileHandle:constructor(function(self, path)
    self.path = path
end)

FileHandle:destructor(function(self)
    print("Closing handle for " .. tostring(self.path))
end)

local handle = FileHandle("example.txt")
```

### Clone

```lua
local luameta = require "init"
local class = luameta.class

local Document = class("Document")

Document:constructor(function(self, title)
    self.title = title
end)

local original = Document("Report")
local copy = original:clone()

copy.title = "Report Copy"

print(original.title)
print(copy.title)
```

### Type Checking

```lua
local luameta = require "init"
local class = luameta.class
local trait = luameta.trait

local Serializable = trait("Serializable")

local Animal = class("Animal")
local Dog = class("Dog")

Dog:extends(Animal)
Dog:implements(Serializable)

local dog = Dog()

print(dog:isA(Dog))
print(dog:isA(Animal))
print(dog:isA("Animal"))
print(dog:isA(Serializable))
```

---

## Compatibility and Limitations

- LuaMeta uses metatables extensively. Behavior may depend on the Lua runtime.
- Destructors require a runtime that supports `__gc` for tables.
- In standard Lua 5.1, `__gc` is not normally invoked for tables.
- The library includes fallbacks for `table.pack` and `table.unpack`.
- Classes support single inheritance only.
- Traits provide horizontal composition.
- Trait implementation copies members. It does not create a live link.
- A class can call `extends` only once.
- A class cannot change its parent after instances have been created.
- Destructors must be defined before instantiation.
- Private state is hidden, but not cryptographically secure or language enforced.
- Property getters are not called if the instance already has a raw field with the same key.
- Methods take priority over property getters during reads.
- Global registration can be disabled, but disabling it does not remove globals that were already created.
- Including an object into a namespace removes its global variable when global registration is enabled.

---

## License

LuaMeta is licensed under the MIT License.
