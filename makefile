FLAGS=-O0 -Wall
CC=gcc

all: rolled.out

rolled.out: rolled.c
	${CC} ${FLAGS} -o $@ $^
