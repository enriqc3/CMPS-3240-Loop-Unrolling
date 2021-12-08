# 3240-Loop-Unrolling
CMPS 3240 Lab on loop unrolling

## Objectives

* Observe improvement with loop unrolling
* Familiarity with `gcc`'s automatic loop unrolling
* Explicit loop unrolling at the C-level
* Explicit loop unrolling at the x86-level

## Prerequisites

* Basic understanding of loop unrolling

## Requirements

### General 

No general requirements

### Software and OS

This lab is designed for `gcc` version 6.3.0 and Debian version 6.3.0

### Hardware

This lab requires a processor on x86-64 ISA.

## Background

Instruction-level parallelism is a method for parallelism that enables the processor to execute many instructions at once. First, consider a baseline system, a simple pipelined MIPS architecture that has five stages: IF, ID, EXE, MEM and WB. Pipelining allows the processor to accomodate many instructions at once by segmenting the pipeline into many stages. Considering our simple MIPS processor, it enables something like this:

```
IF  ID  EXE MEM WB
    IF  ID  EXE MEM WB
        IF  ID  EXE MEM WB
            IF  ID  EXE MEM WB
                IF  ID  EXE MEM WB
```

With multi-issue processors take that pipeline (which has many stages) and repeat it many times. In practice, this means that pipeline stages can accommodate more than one instruction at once. Considering a two-issue MIPS pipeline, it would like look so:

```
IF  ID  EXE MEM WB
IF  ID  EXE MEM WB
    IF  ID  EXE MEM WB
    IF  ID  EXE MEM WB
        IF  ID  EXE MEM WB
        IF  ID  EXE MEM WB
            IF  ID  EXE MEM WB
            IF  ID  EXE MEM WB
```

And so on. Multi-issue processors fall into one of two categories: static multi-issue and dynamic multi-issue. Modern microprocessors are dynamic-multi issue processors. That is, there are many pipelines in the processor and the processor is responsible for arranging given instructions into issue packets that do not have hazards. Processors may even go so far as to hold back certain instructions and execute them out of order to prevent hazards. The alternative is called static multi-issue processors, where the responsibility for generating issue packets is on the compiler and the coder.

Thus, with current x86 processors, your chip has possibly been executing multiple instructions at once in a given cycle, perhaps without your knowledge. Dynamic multi-issue processors go hand in hand with a technique called instruction level parallelism, or loop unrolling. With knowledge that the processor may have many many pipelines, it makes sense to saturate these pipelines. With loop unrolling, if there is a linear load of work (such as a for loop), repeat the loop body a certain amount of times. This has two benefits:

* Given that the processor is multi-issue, it will saturate unused pipelines, increasing throughput. This is a linear improvement based on the number of times you unroll the loop body, limited by the number of pipes in the processor.
* As a secondary benefit, it will decrease the number of pre- or post-test operations for the loop. E.g., If your loop body is doing two units of work, there are half as many tests to check if you should exit the loop. This reduces the penalty for incorrect guesses during branch speculation. However, due to modern processor's branch table buffer, this will likely be super neglible.

### Automatic loop unrolling with `gcc`

Consider the code in `rolled.c` in this repo. The algorithm should be familiar to you at this point:

```c
for( int i = 0; i < length; i++ ) {
	c[i] = a[i] * b[i];
}
```

On the departmental server execute the following commands to respectively compile the code and generate assembly code:

```shell
$ gcc -Wall -O0 -o rolled.out rolled.c
```

This skips our intermediate step of compiling an unlinked binary. The makefile target `make rolled.out` will handle this for you. When timing this on Odin I get an average of 0.043 seconds.

`gcc` has an option to unroll loops and recursive functions automatically for us. The flag is `-funroll-all-loops`. For example:

```shell
$ gcc -O0 -Wall -funroll-loops -o unrolled1.out rolled.c
```

On Odin, this benchmark takes a user time of 0.042 seconds--not even an improvement. There are compiler specific pragmas that can provide hints to the compiler for when to attempt to unroll a loop. For example, if you want the compiler to unroll the loop the pragma:

```c
#pragma GCC unroll n
```

will cause `gcc` to do it for you. This pragma must be inserted just before the loop. Insert this line of code above line 11. However, we have a quandry with the lab. Using `#pragma GCC unroll n` requires an optimization flag of `-O2` or higher and we are using `-O0`. If you enable `-O2` `gcc` will realize you are not doing any real work on the arrays and opt to not run your `for` loop at all. So, we cannot really demonstrate it for the purposes of this lab. We will not be content with letting the compiler do it for us, because we should be getting a much better improvement.

## Unroll by hand at the C-level

The easiest way to do this is to just cut-and-paste the loop body multiple times in a high-level language. Look at `unroll2.c`. It literally cuts and pastes the work of the loop body:

```c
for( int i = 0; i < length; i+=2 ) {
	c[i] = a[i] * b[i];
	c[i+1] = a[i+1] * b[i+1];
}
```

This seems like it won't improve things. But, remember, that under the hood the processor has multiple issue paths. The work for `i` and `i+1` are separate workloads that get processed in parallel by our dynamic multi-issue processor. Compile this with:

```shell
$ gcc -O0 -Wall -o unrolled2.out unroll2.c
```

or use the `make unrolled2.out` target. On my machine I get an average of 0.033 seconds, compared to the baseline of 0.043, which is a roughly 30% improvement. This point is most likely where you would use unrolling in production. However, since this is an assembly class we will want to see if we can do even better.

## Approach

Before we get started we need to confirm the list of registers that are unsaved. Unrolling assembly requires a lot of registers, and you need to know which ones you can use. You cannot use just any register because of the concept of a register being saved or unsaved. The list of unsaved registers in x86-64 System V ABI are: 

* RAX
* RCX
* RDX
* RSI
* RDI
* R8
* R9
* R10
* R11

The R registers are weird. Referencing the whole register refers to the 64-bit version of the register. Usually, changing the R to an E refers to the lower 32-bits of the 64-bit register--what you need for integer. For example `%eax` vs. `%rax`. However, with R8 and beyond, you put a suffix lower case D at the end to indicate you are using the 32-bit version of the register. For example `%r8` vs. `%r8d`. I don't know why they did this, it's just the way it is.

### Getting started

As a first step, create assembly source for your approach. You should start with `rolled.c`:

```shell
$ gcc -O0 -Wall -S -o unrolled3.s rolled.c
```

or use the `make unrolled3.s` target. Be careful to not run this target again over the course of this lab it may destroy your work. *Do not use the C-side code for this. You must restart at rolled.c*  In the following, we step through `unrolled3.s` and implement a second iteration of the loop body. A major flaw of the C-side implementation is that the pointer math is recalculated. That is, `a[i] = b[i] * b[i];` is fully executed pointer math and all, then `a[i+1] = b[i+1] * b[i+1];`. Yet, when calculating the pointer for `a[i]`, you could also calculate `a[i+1]` by adding 4 bytes to the pointer to `a[i]`, and so on with the other pointer, without needing to reload `i`, promote it with `clt`, etc. 

The general goals of what we will do are to:

* Locate where [i] is dereferenced and dereference [i+1].
* Add additional arithmetic for the [i+1] operations.
* Change the counter to increment `i+=2` since the loop body does two loads of work instead of one.

### Dereferencing `a[i+1]`

First, look at lines 22 through 34. These calls to `malloc` are performed in order, so `a` should be in `-16(%rbp)`. `b` should be in `-24(%rbp)`. `c` should be in `-32(%rbp)`. Consider this code, roughly at about line 32:

```x86
movl	-4(%rbp), %eax
cltq
leaq	0(,%rax,4), %rdx
movq	-16(%rbp), %rax
addq	%rdx, %rax
movl	(%rax), %ecx
```

`-4(%rbp)` is `i`.  Recall the way the compiler performs pointer math is to calculate `*(x + 4 * i)` to get the exact byte offset needed to find element `i`. In `leaq	0(,%rax,4), %rdx`, `0(,%rax,4)` evaluates to `%rax * 4` and stores the result in `%rdx`. `movq	-16(%rbp), %rax` then adds `-16(%rbp)` to the result of the previous calculation, which causes `%rax` to point to `x[i]`. Finally, `movl	(%rax), %ecx` dereferences the pointer to get the value of `x[i]`. 

This is the point where we need to also dereference `x[i+1]`. We can add four bytes to `(%rax)` to get `i+1` by simply adding four: `4(%rax)`. Change this chunk to:

```x86
movl	-4(%rbp), %eax
cltq
leaq	0(,%rax,4), %rdx
movq	-16(%rbp), %rax
addq	%rdx, %rax
movl	(%rax), %ecx
movl	4(%rax), %r8d # This is new.
```

`movl	4(%rax), %r8d` dereferences `x[i+1]` and places the result into `%r8d`. Why `%r8`, you might ask? If you look forward, it looks like the compiler is already using `%rax`, `%rcx`, `%rdx`, and `%rsi` for scratch work. We will not want to interfere with this logic and had to select a register not being used by any existing code.

### Dereferencing `b[i+1]`

The code to calculate and dereference `y[i+1]` is:

```x86
movl	-4(%rbp), %eax
cltq
leaq	0(,%rax,4), %rdx
movq	-24(%rbp), %rax
addq	%rdx, %rax
movl	(%rax), %eax
```

This does the same thing as the previous section, except `-24(%rbp)` is the pointer to `b`. Go ahead and dereference `i+1` on `b` as we did with the previous section. Remember to place it in another register.

```x86
movl	-4(%rbp), %eax
cltq
leaq	0(,%rax,4), %rdx
movq	-24(%rbp), %rax
addq	%rdx, %rax
movl	4(%rax), %r9d # This is new.
movl	(%rax), %eax
```

Note that We put it ahead of `movl	(%rax), %eax`. The compiler seems to have chosen `%eax` to hold the dereferenced value of `b[i]`. If you tried to dereference `%rax` the lower half would contain the value of `b[i]` and it would cause a segmentation fault. So, we need to insert our code before the clobbering happens.

### Add and store in `c[i+1]`

The final step is to calculate the pointer to `c`, do the math of adding `a` and `b`, then store the result in `c`. 

```x86
movl	-4(%rbp), %edx
movslq	%edx, %rdx
leaq	0(,%rdx,4), %rsi
movq	-32(%rbp), %rdx
addq	%rsi, %rdx # Pointer to c in %rdx
imull	%ecx, %eax
movl	%eax, (%rdx)
```

The first half of the code, up to where I have inserted the comment in the snippet calculate the pointer to `c[i]`. Note that since this is an assignment, we do not need to dereference it's value. We intend to save into it, or clobber it. Reading it is not required to do this. 

`imull	%ecx, %eax` multiplies `a[i]` and `b[i]`. If you look back to previous work the compiler was careful to not clobber the values in `%ecx` and `%eax`. It then stores the result into `c[i]` with `movl	%eax, (%rdx)`.

So too have we been careful to not reuse `%r8d` and `%r9d` for some other purpose. It should hold `a[i+1]` and `b[i+1]` respectively. So, we need to multiply `%r8d` and `%r9d` then store the result in `4(%rdx)`:

```x86
movl	-4(%rbp), %edx
movslq	%edx, %rdx
leaq	0(,%rdx,4), %rsi
movq	-32(%rbp), %rdx
addq	%rsi, %rdx
imull	%ecx, %eax
movl	%eax, (%rdx)
imull	%r8d, %r9d # New
movl	%r9d, 4(%rdx) # New
```

### `i += 2`

Just as with SIMD, each loop body is doing N workloads. The original version of the code increments the counter by one with `i++`. This is:

```x86
addl	$1, -4(%rbp)
```

If we want to do `i+=2` just change the literal to `$2`:

```x86
addl	$2, -4(%rbp)
```

Forgetting to do this is a common mistake. It will prevent you from seeing any performance improvement.


### Bringing it together

After implementing all of the above changes, you can create the unrolled solution with:

```shell
$ gcc -O0 -Wall -o unrolled3.out unrolled3.s
```

or use the `make unrolled3.out` target. When I run this benchmark it takes 0.009 seconds, compared to the 0.043 seconds for the baseline, it is a ~400% improvement. We expected x2 faster due to unrolling. We had even more computational savings due to avoiding recalculation of the pointer math. You should at least see *some* improvement. If you did not, check to make sure you're incrementing `i` by the correct amount.

## Check-off

Implement the code above and submit your modified `unrolled3.s` file.
