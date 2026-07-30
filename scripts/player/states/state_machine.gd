class_name StateMachine
extends Node
## 通用节点式状态机（TDD §4.1）：非玩家专用，任何需要 FSM 的节点都可复用。
## 用法：作为子节点挂载，各 State 子节点按名字切换。

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.player = get_parent()
	if initial_state == null:
		push_warning("StateMachine 未设置 initial_state")
		return
	current_state = initial_state
	current_state.enter()

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

## 切换状态的唯一入口；状态间不允许直接引用（TDD §4.1）
func transition_to(state_name: String, msg: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_error("StateMachine: 状态不存在 -> " + state_name)
		return
	var next: State = states[state_name]
	if next == current_state:
		return
	current_state.exit()
	current_state = next
	current_state.enter(msg)
