class_name State
extends Node
## FSM 状态基类（TDD §4.1）：所有玩家状态继承本类。
## 每个状态 = StateMachine 下的一个子节点 + 一个脚本。

var player: Player  ## 由 StateMachine 注入
var state_machine: StateMachine  ## 由 StateMachine 注入

## 进入状态时调用，msg 为可选的传参（如冲刺方向）
func enter(_msg: Dictionary = {}) -> void:
	pass

## 退出状态时调用
func exit() -> void:
	pass

## 每物理帧调用（由 StateMachine 转发）
func physics_update(_delta: float) -> void:
	pass

## 未处理输入时调用（由 StateMachine 转发）
func handle_input(_event: InputEvent) -> void:
	pass
