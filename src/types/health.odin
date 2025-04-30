package types

DEFAULT_MAX_HEALTH :: 100
DEFAULT_CURRENT_HEALTH :: DEFAULT_MAX_HEALTH


DEFAULT_HEALTH: Health : {max = DEFAULT_MAX_HEALTH, current = DEFAULT_CURRENT_HEALTH}

Health :: struct {
	max:     u32,
	current: u32,
}
