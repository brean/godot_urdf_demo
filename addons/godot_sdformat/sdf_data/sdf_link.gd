class_name SDFLink
# see https://sdformat.org/spec/1.12/link/
extends SDFElement

@export var gravity: bool = true
@export var enable_wind: bool = false
@export var self_collide: bool = false
@export var kinematic: bool = false
@export var must_be_base_link: bool = false
@export var velocity_decay_linear: float = 0
@export var velocity_decay_angular: float = 0
@export var inertial: Dictionary = {}
@export var collision: Array = []
@export var visual: Array = []
# TODO: sensor
# TODO: projector
# TODO: battery
# TODO: light
# TODO: particle_emitter

