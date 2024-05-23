BUILD ?= build
MKDIR ?= mkdir
RM ?= rm -f
ZIG := zig

out := $(BUILD)/trsp
main := src/main.zig

.PHONY: all
all: clean $(out)

clean:
	$(RM) -r $(BUILD)

$(out): $(main)
	@$(MKDIR) -p $(@D)
	$(ZIG) build-exe -femit-bin="$@" $^

