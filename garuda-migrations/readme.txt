Apply system configuration and package migrations over multiple versions without changing user preferences.

Developer notes:
1. Always provide a way to revert the change in a future garuda-migrations version. This can be done with a comment or a custom file name (for drop in configs).
2. Only apply every change once. You don't want to overwrite the setting again if the user already changed it.
