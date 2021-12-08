FLAGS=-O0 -Wall
CC=gcc

rolled.out: rolled.c
	${CC} ${FLAGS} -o $@ $^

unrolled1.out: rolled.c
	${CC} ${FLAGS} -funroll-loops -o $@ $^

unrolled2.out: unroll2.c
	${CC} ${FLAGS} -o $@ $^

unrolled3.s: rolled.c
	${CC} ${FLAGS} -S -o $@ $^

unrolled3.out: unrolled3.s
	${CC} ${FLAGS} -o $@ $^

clean: 
	rm -r -f *.o *.out
