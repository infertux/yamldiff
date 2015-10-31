.PHONY: all
.PHONY: watch
.PHONY: debug
.PHONY: objdump
.PHONY: clean

NAME=yamldiff
ARGS=a.yml b.yml
AS=nasm
LD=ld

O           = .o
ASM         = .asm
LST         = .lst

ASFLAGS     = -f elf64
LDFLAGS     = --strip-all -m elf_x86_64

OBJS = $(NAME)$(O)

$(NAME): $(OBJS)
	$(LD) $(LDFLAGS) -o $(NAME) $(OBJS) $(LIBS)

$(NAME)$(O): $(NAME)$(ASM)
	$(AS) $(ASFLAGS) $(NAME)$(ASM) -l $(NAME)$(LST) -o $(NAME)$(O)
all:
	$(MAKE) $(NAME)
watch:
	while true; do $(MAKE) $(NAME) 2>&1 | grep -q "up to date" || $(MAKE) $(NAME) 2>&1 | grep "error:" || (date && ./$(NAME) $(ARGS); echo "exit $$?"); sleep 2; done
debug:
	touch $(NAME)$(ASM)
	$(MAKE) $(NAME) ASFLAGS="$(ASFLAGS) -g -F stabs" LDFLAGS="-m elf_x86_64"
	valgrind --tool=callgrind --dump-instr=yes --collect-jumps=yes ./$(NAME) $(ARGS)
objdump: $(NAME)
	objdump -d -M intel $(NAME)
clean:
	rm -vf *.out.* $(NAME) $(NAME)$(LST) $(NAME)$(O)
