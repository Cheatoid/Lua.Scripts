-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Import all collections
local BiMap = require "BiMap"
local CircularBuffer = require "CircularBuffer"
local Deque = require "Deque"
local FastDeque = require "FastDeque"
local Heap = require "Heap"
local LinkedList = require "LinkedList"
local MonoStack = require "MonoStack"
local ObjectPool = require "ObjectPool"
local PriorityQueue = require "PriorityQueue"
local Queue = require "Queue"
local RingQueue = require "RingQueue"
local Set = require "Set"
local SlotMap = require "SlotMap"
local SparseArray = require "SparseArray"
local SparseMap = require "SparseMap"
local Stack = require "Stack"

-- Export
return {
	BiMap = BiMap,
	CircularBuffer = CircularBuffer,
	Deque = Deque,
	FastDeque = FastDeque,
	Heap = Heap,
	LinkedList = LinkedList,
	MonoStack = MonoStack,
	ObjectPool = ObjectPool,
	PriorityQueue = PriorityQueue,
	Queue = Queue,
	RingQueue = RingQueue,
	Set = Set,
	SlotMap = SlotMap,
	SparseArray = SparseArray,
	SparseMap = SparseMap,
	Stack = Stack,
}
